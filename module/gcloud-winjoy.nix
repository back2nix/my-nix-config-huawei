# Управление GCE-инстансами проекта winjoy-games (https://console.cloud.google.com/compute?project=winjoy-games)
#
# Креды — service account winjoy-gce@winjoy-games.iam.gserviceaccount.com
# (roles/compute.admin + roles/iam.serviceAccountUser), JSON-ключ лежит
# зашифрованным в secrets/secrets.yaml под gcloud/winjoy_sa_key и
# расшифровывается sops-nix в /run/secrets/gcloud/winjoy_sa_key (0400, bg).
#
# Команда gcloud-winjoy — единственная точка входа: ходит через china-прокси
# (http://127.0.0.1:1083, см. mkChinaWrapper в overlays/default.nix), держит
# отдельный CLOUDSDK_CONFIG, чтобы не трогать личный ~/.config/gcloud
# (back2nix@gmail.com), и всегда подставляет --project=winjoy-games.
{
  config,
  pkgs,
  lib,
  ...
}: let
  project = "winjoy-games";
  keyPath = config.sops.secrets."gcloud/winjoy_sa_key".path;

  gcloud-winjoy = pkgs.writeShellScriptBin "gcloud-winjoy" ''
    set -eu

    export HTTP_PROXY="http://127.0.0.1:1083"
    export HTTPS_PROXY="http://127.0.0.1:1083"
    export NO_PROXY="localhost,127.0.0.1,::1"

    # Свой CLOUDSDK_CONFIG: личная авторизация в ~/.config/gcloud не затирается.
    export CLOUDSDK_CONFIG="''${XDG_STATE_HOME:-$HOME/.local/state}/gcloud-winjoy"
    export CLOUDSDK_CORE_PROJECT="${project}"
    export CLOUDSDK_CORE_DISABLE_USAGE_REPORTING=True
    mkdir -p "$CLOUDSDK_CONFIG"
    chmod 700 "$CLOUDSDK_CONFIG"

    gcloud=${pkgs.google-cloud-sdk}/bin/gcloud

    # Активируем SA один раз: повторный activate на каждый вызов стоит ~секунду.
    if ! "$gcloud" auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null \
      | ${pkgs.gnugrep}/bin/grep -q '^winjoy-gce@'; then
      "$gcloud" auth activate-service-account \
        --key-file=${keyPath} --project=${project} >/dev/null
    fi

    exec "$gcloud" "$@"
  '';
in {
  sops.secrets."gcloud/winjoy_sa_key" = {
    owner = config.users.users.bg.name;
    mode = "0400";
  };

  environment.systemPackages = [gcloud-winjoy];
}
