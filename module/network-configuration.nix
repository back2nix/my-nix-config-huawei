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
      192.168.3.78 app.local grafana.local pyroscope.local prometheus.local
    '';

    nftables = {
      enable = true;
      ruleset = ''
        table inet filter {
          set allowed_tcp {
            type inet_service
            flags interval
            elements = {
              22,      # SSH
              5555,    # Camera streaming
              6443,    # K3S API Server
              8080,    # Gateway
              8081,    # Landing
              8082,    # Chat
              8085,    # Notification
              9002,    # Shell
              9901,    # Envoy metrics
              4240,    # Cilium Health
              4244,    # Cilium Hubble Server
              4245     # Cilium Hubble Relay
            }
          }

          set system_udp {
            type inet_service
            flags interval
            elements = {
              53, 67-68, 123, 500, 4500, 5353, 51820,
              8472     # K3S Flannel VXLAN (оставляем на случай если нужно)
            }
          }

          set google_stun_ipv4 {
            type ipv4_addr
            flags interval
            elements = {
              142.250.0.0/15,
              172.217.0.0/16,
              216.58.192.0/19,
              74.125.0.0/16
            }
          }

          set google_stun_ipv6 {
            type ipv6_addr
            flags interval
            elements = {
              2607:f8b0::/32,
              2800:3f0::/32,
              2a00:1450::/32,
              2404:6800::/32
            }
          }

          chain input {
            type filter hook input priority filter; policy drop;

            iif "lo" accept comment "Allow loopback"

            # Docker
            ip saddr 172.16.0.0/12 accept comment "Allow Docker subnets"
            ip saddr 172.17.0.0/16 accept comment "Allow docker0 bridge"
            ip saddr 172.27.0.0/16 accept comment "Allow docker-compose network"

            # K3s
            ip saddr 10.42.0.0/16 accept comment "Allow K3s Pods"
            ip saddr 10.43.0.0/16 accept comment "Allow K3s Services"

            # Cilium - разрешаем inter-node communication
            # Cilium использует VXLAN (по умолчанию порт 8472) для overlay network
            udp dport 8472 accept comment "Allow Cilium VXLAN"

            # Cilium Health checks между нодами
            tcp dport 4240 accept comment "Allow Cilium Health checks"

            # ВАЖНО: Разрешаем localhost доступ к портам сервисов
            ip saddr 127.0.0.0/8 tcp dport { 8080, 8081, 8082, 8085, 9002, 9901 } accept comment "Allow localhost to services"

            ct state vmap {
              invalid : drop,
              established : accept,
              related : accept
            }

            ip protocol icmp accept comment "Allow ICMP"
            ip6 nexthdr ipv6-icmp accept comment "Allow ICMPv6"

            tcp dport @allowed_tcp accept comment "Allow specified TCP ports"
          }

          chain output {
            type filter hook output priority filter; policy accept;

            udp dport @system_udp accept

            # Блокируем Google STUN
            ip daddr @google_stun_ipv4 udp dport 19302-19309 drop
            ip6 daddr @google_stun_ipv6 udp dport 19302-19309 drop
            ip daddr @google_stun_ipv4 udp dport 3478 drop
            ip6 daddr @google_stun_ipv6 udp dport 3478 drop
            ip daddr @google_stun_ipv4 udp dport 49152-65535 drop
            ip6 daddr @google_stun_ipv6 udp dport 49152-65535 drop
          }

          chain forward {
            type filter hook forward priority filter; policy accept;

            # Разрешаем forward для Cilium overlay network
            ip saddr 10.42.0.0/16 accept comment "Allow K3s Pod forwarding"
            ip daddr 10.42.0.0/16 accept comment "Allow K3s Pod forwarding"
          }
        }
      '';
    };

    firewall.enable = false;
  };
}
