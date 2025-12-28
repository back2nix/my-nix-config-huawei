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
  generatedConfigFile = settingsFormat.generate "attic.toml" cfg.settings;
in
{
  options.services.attic = {
    # ... твои опции без изменений ...
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
      description = "Path to token file";
      type = lib.types.str;
      default = "";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.atticd = {};
    users.users.atticd = {
      isSystemUser = true;
      group = "atticd";
      description = "Atticd service user";
      home = "/var/lib/atticd";
      createHome = true;
    };

    # === ДОБАВЬ ВОТ ЭТОТ БЛОК ===
    # d = создать директорию, если нет
    # Z = рекурсивно исправить права (владельца), если они неправильные
    systemd.tmpfiles.rules = [
      "d /var/lib/atticd 0700 atticd atticd - -"
      "Z /var/lib/atticd 0700 atticd atticd - -"
    ];
    # ============================

    systemd.services.atticd = {
      description = "Attic Binary Cache Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        User = "atticd";
        Group = "atticd";
        # StateDirectory создаст папку, но tmpfiles надежнее для исправления прав
        StateDirectory = "atticd";

        # Скрипт запуска
        ExecStart = pkgs.writeShellScript "attic-run" ''
          if [ -n "${cfg.credentialsFile}" ] && [ -f "${cfg.credentialsFile}" ]; then
            export ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64="$(<"${cfg.credentialsFile}")"
          fi

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
