{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: let
  # «Весь трафик» ноутбука: один список в трее (группа system), а не тумблеры.
  #
  #   direct      — ничего не поднято, система ходит напрямую;
  #   wg-paris    — amneziawg-personal-full (AmneziaWG, весь IPv4/UDP через Paris);
  #   wg-fra      — amneziawg-fra-full     (AmneziaWG, весь IPv4/UDP через Франкфурт);
  #   любой ssh-выход (usa, usa-2, через Париж/Франкфурт, fra...) — sing-box-tun:
  #     TUN-интерфейс ловит весь трафик и отдаёт его в socks 127.0.0.1:1128
  #     основного sing-box, где selector system-select выбирает выход.
  #     SSH не умеет UDP: UDP (кроме DNS) и IPv6 отклоняются, а не идут мимо.
  #
  # Источник истины — selector system-select (переживает ребут через cache_file);
  # system-vpn-apply.service при загрузке поднимает соответствующий юнит.
  units = {
    tun = "sing-box-tun.service";
    wg-paris = "amneziawg-personal-full.service";
    wg-fra = "amneziawg-fra-full.service";
  };

  # Адреса, которые TUN обязан пропускать мимо себя: серверы, к которым
  # основной sing-box сам открывает ssh (иначе петля), Paris (admin-VPN,
  # Personal VPN) и частные сети (LAN, awg-туннели, k3s).
  ph = config.sops.placeholder;

  tunConfig = builtins.toJSON {
    log.level = "warn";
    dns = {
      # Ответы DNS — от локального резолвера (blocky -> dnscrypt), он и так
      # ходит шифрованно; провайдер DNS-запросов не видит.
      servers = [
        {
          type = "udp";
          tag = "local";
          server = "127.0.0.1";
          server_port = 53;
        }
      ];
    };
    inbounds = [
      {
        type = "tun";
        tag = "tun-in";
        interface_name = "sbtun0";
        address = ["172.19.0.1/30" "fdfe:dcba:9876::1/126"];
        mtu = 9000;
        auto_route = true;
        # strict_route: без него часть трафика (в т.ч. IPv6) может уйти мимо.
        strict_route = true;
        stack = "system";
        # Адреса серверов зафиксированы в casino-vps (seoul-relay.nix,
        # usa-relay.nix, flake.nix) — не секрет. Без исключения ssh основного
        # sing-box к ним завернулся бы в этот же TUN (петля).
        route_exclude_address = [
          "35.212.30.39/32" # USA (google-seoul-proxy)
          "35.208.120.183/32" # USA 2
          "5.252.179.162/32" # Франкфурт
          "194.180.174.137/32" # Paris (admin-VPN, Personal VPN, seoul-relay)
          "${ph."hosts/casino_ip"}/32"
          "10.0.0.0/8"
          "172.16.0.0/12"
          "192.168.0.0/16"
          "100.64.0.0/10"
          "169.254.0.0/16"
        ];
      }
    ];
    outbounds = [
      {
        type = "socks";
        tag = "main";
        server = "127.0.0.1";
        server_port = 1128;
        version = "5";
        network = "tcp";
      }
    ];
    route = {
      rules = [
        {action = "sniff";}
        {
          protocol = "dns";
          action = "hijack-dns";
        }
        {
          ip_version = 6;
          action = "reject";
        }
        {
          network = "udp";
          action = "reject";
        }
      ];
      final = "main";
    };
  };

  allUnits = lib.attrValues units;
  sctl = "${pkgs.systemd}/bin/systemctl";

  systemVpn = pkgs.writeShellApplication {
    name = "system-vpn";
    runtimeInputs = [pkgs.curl pkgs.jq pkgs.systemd];
    text = ''
      api=''${VPN_ROUTE_API:-http://127.0.0.1:9090}
      sel="$api/proxies/system-select"
      get() { curl --noproxy '*' -fsS --max-time 3 "$sel" | jq -er '.now'; }
      put() {
        curl --noproxy '*' -fsS --max-time 3 -X PUT -H 'Content-Type: application/json' \
          --data "$(jq -nc --arg n "$1" '{name: $n}')" "$sel" >/dev/null
      }
      stop_all_except() {
        for u in ${lib.concatStringsSep " " allUnits}; do
          [ "$u" = "$1" ] && continue
          systemctl --no-ask-password stop "$u" || true
        done
      }
      # Привести систему к состоянию из selector'а.
      apply() {
        tag=$(get)
        case "$tag" in
          direct-out) stop_all_except none; return 0 ;;
          wg-paris) unit=${units.wg-paris} ;;
          wg-fra) unit=${units.wg-fra} ;;
          *) unit=${units.tun} ;;
        esac
        stop_all_except "$unit"
        if ! systemctl --no-ask-password restart "$unit"; then
          # Не оставляем меню врать: не поднялось — значит Direct.
          systemctl --no-ask-password stop "$unit" || true
          put direct-out || true
          echo "system-vpn: $unit не поднялся, режим сброшен в Direct" >&2
          return 1
        fi
      }
      case "''${1:-apply}" in
        apply) apply ;;
        set)
          put "$2"
          apply
          ;;
        *) echo 'usage: system-vpn apply | set <outbound-tag>' >&2; exit 2 ;;
      esac
    '';
  };
in {
  sops.templates."sing-box-tun.json" = {
    content = tunConfig;
    restartUnits = [];
  };

  systemd.services.sing-box-tun = {
    description = "sing-box TUN: весь трафик системы через выбранный ssh-выход";
    after = ["sing-box.service" "network-online.target"];
    requires = ["sing-box.service"];
    conflicts = [units.wg-paris units.wg-fra];
    # Без автостарта: поднимает system-vpn-apply / меню.
    serviceConfig = {
      ExecStart = "${pkgs-unstable.sing-box}/bin/sing-box run -c ${config.sops.templates."sing-box-tun.json".path}";
      Restart = "on-failure";
      RestartSec = "3s";
      CapabilityBoundingSet = ["CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_NET_BIND_SERVICE"];
      AmbientCapabilities = ["CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_NET_BIND_SERVICE"];
      DynamicUser = false;
      ProtectHome = true;
      ProtectSystem = "strict";
      RuntimeDirectory = "sing-box-tun";
      StateDirectory = "sing-box-tun";
      WorkingDirectory = "/var/lib/sing-box-tun";
    };
  };

  # Полные AmneziaWG-туннели тоже взаимоисключающие с TUN.
  systemd.services.amneziawg-personal-full.conflicts = [units.tun];
  systemd.services.amneziawg-fra-full.conflicts = [units.tun];

  # Восстановление выбора после загрузки.
  systemd.services.system-vpn-apply = {
    description = "Применить выбранный режим «весь трафик» (system-select)";
    after = ["sing-box.service" "network-online.target" "sops-nix.service"];
    wants = ["sing-box.service" "network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      # Clash-API поднимается не мгновенно.
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in $(seq 30); do ${pkgs.curl}/bin/curl --noproxy \"*\" -fsS --max-time 1 http://127.0.0.1:9090/ >/dev/null && exit 0; sleep 1; done; exit 1'";
      ExecStart = "${systemVpn}/bin/system-vpn apply";
    };
  };

  environment.systemPackages = [systemVpn];
  nixpkgs.overlays = [(final: prev: {system-vpn = systemVpn;})];

  # bg может стартовать/останавливать ТОЛЬКО эти юниты, локально и в активной сессии.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var units = ${builtins.toJSON [units.tun]};
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          units.indexOf(action.lookup("unit")) >= 0 &&
          (action.lookup("verb") == "start" ||
           action.lookup("verb") == "stop"  ||
           action.lookup("verb") == "restart") &&
          subject.user == "bg" && subject.local && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';
}
