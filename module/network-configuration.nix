{
  lib,
  config,
  ...
}: {
  # Отключаем systemd.network при использовании NetworkManager
  systemd.network.enable = lib.mkForce false;

  environment.etc."resolv.conf".mode = "direct-symlink";

  # Настройка NetworkManager для WiFi без power management
  environment.etc."NetworkManager/conf.d/99-wifi-no-powersave.conf".text = ''
    [connection]
    wifi.powersave = 2
    wifi.cloned-mac-address = preserve
    ethernet.cloned-mac-address = preserve

    [device]
    wifi.backend = iwd
    wifi.scan-rand-mac-address = false
  '';

  networking = {
    # ПРАВИЛЬНЫЙ СИНТАКСИС для iwd в NixOS
    wireless.iwd.enable = true;

    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
    };

    wireless.enable = lib.mkForce false;

    nat = {
      enable = true;
      internalInterfaces = ["ve-+"];
      enableIPv6 = true;
    };

    extraHosts = ''
      127.0.0.1 kafka
      127.0.0.1 localhost
      127.0.0.1 host.docker.internal
    '';

    nftables = {
      enable = true;
      ruleset = ''
        table inet filter {
          # Разрешённые UDP порты для системных сервисов
          set system_udp {
            type inet_service
            flags interval
            elements = {
              53,      # DNS
              67-68,   # DHCP
              123,     # NTP
              500,     # IPsec/VPN
              4500,    # IPsec NAT-T
              5353,    # mDNS
              51820    # WireGuard (если используешь)
            }
          }

          # Известные STUN/TURN серверы Google (IP адреса)
          set google_stun_ipv4 {
            type ipv4_addr
            flags interval
            elements = {
              142.250.0.0/15,    # Основной диапазон Google
              172.217.0.0/16,    # Google services
              216.58.192.0/19,   # YouTube/Meet
              74.125.0.0/16,      # Google infrastructure
              # 213.180.204.242/16    # Yandex STUN
            }
          }

          set google_stun_ipv6 {
            type ipv6_addr
            flags interval
            elements = {
              2607:f8b0::/32,    # Google IPv6
              2800:3f0::/32,     # Google IPv6 alt
              2a00:1450::/32,    # Google IPv6 EU
              2404:6800::/32     # Google IPv6 APAC
            }
          }

          chain output {
            type filter hook output priority 0; policy accept;

            # Разрешаем системные UDP сервисы
            udp dport @system_udp accept

            # Блокируем WebRTC STUN/TURN трафик Google по IP
            ip daddr @google_stun_ipv4 udp dport 19302-19309 drop
            ip6 daddr @google_stun_ipv6 udp dport 19302-19309 drop

            # Блокируем стандартный STUN порт для Google
            ip daddr @google_stun_ipv4 udp dport 3478 drop
            ip6 daddr @google_stun_ipv6 udp dport 3478 drop

            # Блокируем высокие порты для Google (используются для media)
            ip daddr @google_stun_ipv4 udp dport 49152-65535 drop
            ip6 daddr @google_stun_ipv6 udp dport 49152-65535 drop

            # Всё остальное UDP разрешаем (для других сервисов)
          }
        }
      '';
    };

    # nftables = {
    #   enable = true;
    #   ruleset = ''
    #     table inet filter {
    #       set allowed_udp {
    #         type inet_service
    #         flags interval
    #         elements = { 53, 67-68, 123, 500, }  # DNS, DHCP, NTP, VPN, mDNS
    #       }

    #       chain input {
    #         type filter hook input priority 0; policy accept;
    #         # Блокируем весь входящий UDP
    #         # udp dport 1024-65535 drop
    #       }

    #       chain output {
    #         type filter hook output priority 0; policy accept;

    #         # Разрешаем стандартные UDP сервисы
    #         # udp dport @allowed_udp accept

    #         # Блокируем всё остальное UDP выше 1024
    #         # udp dport 1024-65535 drop
    #         # udp dport 443 drop
    #       }
    #     }
    #   '';
    # };

    firewall = {
      enable = false;
      allowedTCPPorts = [
        18082
        18081
      ];
      allowedUDPPorts = [
        18082
        18081
      ];
      extraCommands = ''
        iptables -t nat -A PREROUTING -i wlp0s20f3 -p tcp --dport 80 -j REDIRECT --to-port 1081
        iptables -t nat -A PREROUTING -i wlp0s20f3 -p tcp --dport 443 -j REDIRECT --to-port 1081
        ip6tables -t nat -A PREROUTING -i wlp0s20f3 -p tcp --dport 80 -j REDIRECT --to-port 1081
        ip6tables -t nat -A PREROUTING -i wlp0s20f3 -p tcp --dport 443 -j REDIRECT --to-port 1081
        iptables -A OUTPUT -p udp --dport 1024:65535 -j DROP
      '';
    };
  };
}
