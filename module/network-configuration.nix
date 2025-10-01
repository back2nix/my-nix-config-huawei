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
          udp dport 1024-65535 drop
        }
      }

      table ip nat {
        chain prerouting {
          type nat hook prerouting priority 0; policy accept;

          iifname "wlp0s20f3" tcp dport 80 redirect to :1081
          iifname "wlp0s20f3" tcp dport 443 redirect to :1081
        }
      }

      table ip6 nat {
        chain prerouting {
          type nat hook prerouting priority 0; policy accept;

          iifname "wlp0s20f3" tcp dport 80 redirect to :1081
          iifname "wlp0s20f3" tcp dport 443 redirect to :1081
        }
      }
      '';
    };

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
