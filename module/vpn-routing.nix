{
  pkgs,
  lib,
  ...
}: let
  vpnRoute = pkgs.writeShellApplication {
    name = "vpn-route";
    runtimeInputs = [pkgs.curl pkgs.jq];
    text = ''
      api=''${VPN_ROUTE_API:-http://127.0.0.1:9090}
      group=''${1:-}
      case "$group" in
        claude|codex|nix) ;;
        *) echo 'Usage: vpn-route claude|codex|nix [usa|casino|fra|kz|direct|status]' >&2; exit 2 ;;
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
            ssh-out1-via-casino) echo casino ;;
            ssh-frankfurt) echo fra ;;
            ssh-astana) echo kz ;;
            direct-out) echo direct ;;
            *) echo "Unknown route: $current" >&2; exit 1 ;;
          esac
          ;;
        *)
          case "$mode" in
            usa|seoul|1082|1083) tag=ssh-out1 ;;
            casino|usa-casino) tag=ssh-out1-via-casino ;;
            fra|frankfurt|1088|1089) tag=ssh-frankfurt ;;
            kz|kz-astana|astana|1090|1091) tag=ssh-astana ;;
            direct)
              if [ "$group" != nix ]; then
                echo 'Direct is available only for Nix; agents must use a tunnel.' >&2
                exit 2
              fi
              tag=direct-out
              ;;
            *) echo "Unknown route: $mode" >&2; exit 2 ;;
          esac
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
