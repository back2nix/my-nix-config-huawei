# Доверенный HTTPS для локальных *.local (casino.local, grafana.local, … — весь
# список 10.0.0.1 из networking.extraHosts), которые отдаёт gateway casino-k3s.
#
# Свой УЦ «back2nix Local Dev CA» (EC P-256, 10 лет, pathlen:0, nameConstraints:
# только .local/.remote/localhost/127.0.0.0/8/10.0.0.0/8 — утёкший ключ не
# подпишет ничего публичного). Всё лежит в secrets/secrets.yaml:
#   local_ca/crt, local_ca/key   — УЦ (ключ нужен только для перевыпуска leaf)
#   local_tls/crt, local_tls/key — leaf (fullchain) со всеми SAN, 825 дней
# Leaf же лежит в casino-k3s/ssl/tls.{crt,key} → terraform → gateway-tls-secret.
#
# Публичный серт УЦ закоммичен рядом (certs/local-dev-ca.crt): trust-бандл
# NixOS собирается на eval, а sops расшифровывает только на активации.
#
# Chrome/Brave на Linux системный бандл не читают — им нужен ~/.pki/nssdb,
# Firefox — свой cert9.db в профиле: туда серт кладёт user-сервис ниже.
{
  config,
  pkgs,
  ...
}: let
  caFile = ./certs/local-dev-ca.crt;
  nick = "back2nix Local Dev CA";
  certutil = "${pkgs.nssTools}/bin/certutil";

  importNss = pkgs.writeShellScript "local-dev-ca-nss" ''
    set -eu
    add() {
      ${certutil} -d "sql:$1" -D -n "${nick}" 2>/dev/null || true
      ${certutil} -d "sql:$1" -A -t "C,," -n "${nick}" -i ${caFile}
    }
    mkdir -p "$HOME/.pki/nssdb"
    [ -f "$HOME/.pki/nssdb/cert9.db" ] || ${certutil} -d "sql:$HOME/.pki/nssdb" -N --empty-password
    add "$HOME/.pki/nssdb"
    for p in "$HOME"/.mozilla/firefox/*/cert9.db; do
      [ -f "$p" ] && add "$(dirname "$p")"
    done
  '';
in {
  security.pki.certificateFiles = [caFile];

  sops.secrets = {
    "local_tls/crt" = {
      owner = config.users.users.bg.name;
      mode = "0444";
    };
    "local_tls/key" = {
      owner = config.users.users.bg.name;
      mode = "0400";
    };
  };

  systemd.user.services.local-dev-ca-nss = {
    description = "Import local dev CA into NSS (Chrome/Brave/Firefox)";
    wantedBy = ["default.target"];
    restartTriggers = [caFile];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = importNss;
    };
  };
}
