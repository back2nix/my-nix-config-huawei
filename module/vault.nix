{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.vault-secrets;
in {
  options.services.vault-secrets = {
    enable = lib.mkEnableOption "Enable Vault secret management";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.vault;
      description = "The Vault package to use.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      description = "Address of the Vault server, e.g., 'http://127.0.0.1:8200'.";
      example = "https://vault.example.com";
    };

    tokenPath = lib.mkOption {
      type = lib.types.path;
      description = "Path to a file containing the Vault token for authentication.";
      example = "/etc/nixos/secrets/vault-token";
    };

    secrets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            description = "The path of the secret in Vault's KVv2 store (e.g., 'secret/data/myapp').";
            example = "secret/data/database";
          };
          key = lib.mkOption {
            type = lib.types.str;
            description = "The key within the secret to retrieve.";
            example = "password";
          };
          owner = lib.mkOption {
            type = lib.types.str;
            default = "root";
            description = "The user who should own the secret file.";
          };
          group = lib.mkOption {
            type = lib.types.str;
            default = "root";
            description = "The group who should own the secret file.";
          };
          mode = lib.mkOption {
            type = lib.types.str;
            default = "0400";
            description = "The file mode for the secret file.";
          };
        };
      });
      default = {};
      description = ''
        An attribute set of secrets to fetch from Vault.
        The key of the attribute set is the destination file path for the secret.
      '';
      example = lib.literalExpression ''
        {
          "/run/secrets/db-password" = {
            path = "secret/data/production/database";
            key = "password";
            owner = "postgres";
            group = "postgres";
            mode = "0440";
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [cfg.package];

    systemd.services = lib.mapAttrs' (name: secret:
    lib.nameValuePair "vault-fetch-${lib.strings.sanitizeDerivationName name}" {
      description = "Fetch secret from Vault to ${name}";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "vault.service"];  # Добавлена зависимость на vault.service
      wants = ["network-online.target"];
      requires = ["vault.service"];  # Добавьте эту строку - требует запуска Vault

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;
      # Добавьте Restart для повторных попыток в случае неудачи
      Restart = "on-failure";
      RestartSec = "5s";
    };

    script = ''
      # Ждём пока Vault будет готов
      echo "Waiting for Vault to be ready..."
      while ! ${pkgs.curl}/bin/curl -s "${cfg.address}/v1/sys/health" > /dev/null 2>&1; do
      echo "Vault not ready, waiting..."
      sleep 2
      done

      # Устанавливаем переменные окружения для Vault
      export VAULT_ADDR="${cfg.address}"
      export VAULT_TOKEN=$(cat "${cfg.tokenPath}")

      # Извлекаем данные ключа из секрета и создаем файл
      secret_value=$(${cfg.package}/bin/vault kv get -field=${secret.key} ${secret.path})
      if [ $? -ne 0 ]; then
      echo "Failed to fetch secret ${secret.path} with key ${secret.key}" >&2
      exit 1
      fi

      # Создаем файл секрета с нужными правами
      mkdir -p "$(dirname ${name})"
      echo -n "$secret_value" > "${name}"
      chown ${secret.owner}:${secret.group} "${name}"
      chmod ${secret.mode} "${name}"
      '';
    })
    cfg.secrets;
  };
}
