{
  pkgs,
  lib,
  ...
}: let
  vpnRoute = pkgs.writeShellApplication {
    name = "vpn-route";
    runtimeInputs = [pkgs.curl pkgs.jq pkgs.system-vpn];
    text = ''
      api=''${VPN_ROUTE_API:-http://127.0.0.1:9090}
      group=''${1:-}
      case "$group" in
        system|antigravity|claude|codex|telegram|git|nix|voicestudio|browser-usa|browser-fra|fra-deploy|paris-deploy) ;;
        *) echo 'Usage: vpn-route system|antigravity|claude|codex|telegram|git|nix|voicestudio|browser-usa|browser-fra|fra-deploy|paris-deploy [usa|usa-2|usa-2-casino|casino|usa-fra|usa-2-fra|fra|fra-casino|france|france-relay|wg-paris|wg-fra|direct|status]' >&2; exit 2 ;;
      esac
      if [ "$#" -gt 2 ]; then
        echo 'Too many arguments' >&2
        exit 2
      fi
      mode=''${2:-status}
      case "$mode" in
        status|show)
          current=$(curl --noproxy '*' -fsS --max-time 3 "$api/proxies/$group-select" | jq -er '.now')
          case "$current" in
            ssh-out1) echo usa ;;
            ssh-usa-2) echo usa-2 ;;
            ssh-usa-2-via-casino) echo usa-2-casino ;;
            ssh-out1-via-casino) echo casino ;;
            ssh-out1-via-fra) echo usa-fra ;;
            ssh-usa-2-via-fra) echo usa-2-fra ;;
            ssh-frankfurt) echo fra ;;
            ssh-frankfurt-via-casino) echo fra-casino ;;
            ssh-france) echo france ;;
            ssh-casino-relay) echo france-relay ;;
            direct-out) echo direct ;;
            wg-paris) echo wg-paris ;;
            wg-fra) echo wg-fra ;;
            *) echo "Unknown route: $current" >&2; exit 1 ;;
          esac
          ;;
        *)
          case "$mode" in
            usa|seoul|1082|1083) tag=ssh-out1 ;;
            usa-2) tag=ssh-usa-2 ;;
            usa-2-casino|usa-2-paris) tag=ssh-usa-2-via-casino ;;
            casino|usa-casino|usa-paris) tag=ssh-out1-via-casino ;;
            usa-fra) tag=ssh-out1-via-fra ;;
            usa-2-fra) tag=ssh-usa-2-via-fra ;;
            fra-casino|fra-ru) tag=ssh-frankfurt-via-casino ;;
            fra|frankfurt|1088|1089) tag=ssh-frankfurt ;;
            france|ru) tag=ssh-france ;;
            france-relay)
              if [[ "$group" != fra-deploy ]]; then
                echo 'france-relay is available only for fra-deploy (seoul-relay permits only fixed ssh targets).' >&2
                exit 2
              fi
              tag=ssh-casino-relay
              ;;
            wg-paris|wg-fra)
              if [[ "$group" != system ]]; then
                echo "$mode is available only for system" >&2
                exit 2
              fi
              tag=$mode
              ;;
            direct)
              if [[ "$group" != system && "$group" != git && "$group" != nix && "$group" != browser-* && "$group" != fra-deploy && "$group" != paris-deploy ]]; then
                echo 'Direct is available only for Git, Nix, browsers, fra-deploy and paris-deploy.' >&2
                exit 2
              fi
              tag=direct-out
              ;;
            *) echo "Unknown route: $mode" >&2; exit 2 ;;
          esac
          if [[ "$group" == system ]]; then
            # Не просто selector: поднять/опустить TUN или AmneziaWG.
            system-vpn set "$tag"
            echo "$group: $mode"
            exit 0
          fi
          body=$(jq -nc --arg name "$tag" '{name: $name}')
          curl --noproxy '*' -fsS --max-time 3 -X PUT \
            -H 'Content-Type: application/json' --data "$body" \
            "$api/proxies/$group-select" >/dev/null
          echo "$group: $mode"
          ;;
      esac
    '';
  };
in {
  nixpkgs.overlays = [(final: prev: {vpn-route = vpnRoute;})];
  environment.systemPackages = [vpnRoute];
}
