{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.attic;
  atticd = lib.getExe cfg.package;
  settingsFormat = pkgs.formats.toml { };

  # Генерируем конфиг из settings
  generatedConfigFile = settingsFormat.generate "attic.toml" cfg.settings;
in
{
  options.services.attic = {
    enable = lib.mkEnableOption "attic";

    package = lib.mkPackageOption pkgs "attic-server" { };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = settingsFormat.type;
        options = {
          storage = {
            type = lib.mkOption {
              type = lib.types.enum [ "local" "s3" ];
            };
            path = lib.mkOption { type = lib.types.str; };
          };
        };
      };
      default = {};
      description = "Configuration for attic.toml";
    };

    credentialsFile = lib.mkOption {
      description = ''
        Path to a file containing the server's secret token.
        Can be generated via `openssl rand 64 | base64 -w0`.
      '';
      type = lib.types.str;
      default = "";
    };
  };

  config = lib.mkIf cfg.enable {
    # Создаем пользователя и группу
    users.groups.atticd = {};
    users.users.atticd = {
      isSystemUser = true;
      group = "atticd";
      description = "Atticd service user";
      home = "/var/lib/atticd";
      createHome = true;
    };

    # Systemd сервис (аналог init.services из чужого конфига)
    systemd.services.atticd = {
      description = "Attic Binary Cache Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        User = "atticd";
        Group = "atticd";
        # Создаем директорию, если хранилище локальное
        StateDirectory = "atticd";

        # Скрипт запуска, который подтягивает секреты, как в оригинале
        ExecStart = pkgs.writeShellScript "attic-run" ''
          if [ -n "${cfg.credentialsFile}" ] && [ -f "${cfg.credentialsFile}" ]; then
            export ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64="$(<"${cfg.credentialsFile}")"
          fi

          # Если директория хранения локальная и совпадает с путем StateDirectory, systemd её уже создал.
          # Если путь другой, обеспечим права (только если это локальный путь)
          if [ "${cfg.settings.storage.type}" = "local" ]; then
             mkdir -p "${cfg.settings.storage.path}"
          fi

          exec ${atticd} --config ${generatedConfigFile}
        '';

        Restart = "always";
        RestartSec = "5s";
      };
    };

    environment.systemPackages = [ cfg.package ];
  };
}
