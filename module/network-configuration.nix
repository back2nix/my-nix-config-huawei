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
        chain output {
          type filter hook output priority 0; policy accept;
          # Блокируем исходящий UDP на высокие порты
          # udp dport 1024-65535 drop
          udp dport { 3478, 19302-19309, 6384-32768, 49152-65535} drop

          udp dport 443 ip daddr { 1.1.1.1, 1.0.0.1, 8.8.8.8, 8.8.4.4 } accept
          udp dport 443 ip6 daddr { 2606:4700:4700::1111, 2606:4700:4700::1001 } accept
          udp dport 443 drop
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
