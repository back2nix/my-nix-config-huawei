{
  lib,
  config,
  ...
}: {
  # Отключаем systemd.network при использовании NetworkManager
  systemd.network.enable = lib.mkForce false;

  environment.etc."resolv.conf".text = ''
    nameserver 127.0.0.1
    nameserver 8.8.8.8
    nameserver 1.1.1.1
    options edns0 trust-ad timeout:1 attempts:1
  '';

  networking = {
    networkmanager = {
      enable = true;
      wifi.backend = "wpa_supplicant";
    };

    nat = {
      enable = true;
      # Добавляем интерфейсы cilium и lxc в доверенные для NAT
      internalInterfaces = ["ve-+" "cilium_+" "lxc+"];
      enableIPv6 = true;
    };

    extraHosts = ''
      127.0.0.1 kafka
      127.0.0.1 localhost
      127.0.0.1 host.docker.internal
      # Убедитесь, что IP актуален
      192.168.3.18 app.local grafana.local pyroscope.local prometheus.local postgres.local auth.local grpc.app.local redis.local livekit.local
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
              80,      # HTTP
              853,     # DNS over TLS
              443,     # HTTPS/gRPC-TLS
              5555,    # Camera streaming
              6443,    # K3S API Server
              6379,    # redis
              8080,    # Gateway
              8081,    # Landing
              8082,    # Chat
              8085,    # Notification
              9002,    # Shell
              9901,    # Envoy metrics
              4240,    # Cilium Health
              4244,    # Cilium Hubble Server
              4245,    # Cilium Hubble Relay
              5432,    # postgres
              50051    # auth
            }
          }

          set system_udp {
            type inet_service
            flags interval
            elements = {
              53, 67-68, 123, 500, 4500, 5353, 51820,
              8472,    # Cilium VXLAN
              51871    # Cilium Wireguard
            }
          }

          set google_stun_ipv4 {
            type ipv4_addr
            flags interval
            elements = { 142.250.0.0/15, 172.217.0.0/16, 216.58.192.0/19, 74.125.0.0/16 }
          }

          set google_stun_ipv6 {
            type ipv6_addr
            flags interval
            elements = { 2607:f8b0::/32, 2800:3f0::/32, 2a00:1450::/32, 2404:6800::/32 }
          }

          chain input {
            type filter hook input priority filter; policy drop;

            iif "lo" accept comment "Allow loopback"

            # ВАЖНО: Разрешаем трафик от интерфейсов контейнеров
            iifname "cilium_*" accept comment "Allow Cilium interfaces"
            iifname "lxc*" accept comment "Allow LXC interfaces"
            iifname "docker0" accept comment "Allow Docker bridge"
            iifname "virbr*" accept comment "Allow Libvirt"

            # Docker подсети
            ip saddr 172.16.0.0/12 accept
            ip saddr 172.17.0.0/16 accept
            ip saddr 172.27.0.0/16 accept

            # K3s/Cilium подсети
            ip saddr 10.42.0.0/16 accept
            ip saddr 10.43.0.0/16 accept

            udp dport 8472 accept comment "Allow Cilium VXLAN"
            tcp dport 4240 accept comment "Allow Cilium Health"

            # Разрешаем доступ к сервисам с localhost
            ip saddr 127.0.0.0/8 tcp dport { 8080, 8081, 8082, 8085, 9002, 9901 } accept

            ct state vmap {
              invalid : drop,
              established : accept,
              related : accept
            }

            ip protocol icmp accept
            ip6 nexthdr ipv6-icmp accept

            tcp dport @allowed_tcp accept
          }

          chain output {
            type filter hook output priority filter; policy accept;
            udp dport @system_udp accept

            # Google STUN Block
            ip daddr @google_stun_ipv4 udp dport 19302-19309 drop
            ip6 daddr @google_stun_ipv6 udp dport 19302-19309 drop
            ip daddr @google_stun_ipv4 udp dport 3478 drop
            ip6 daddr @google_stun_ipv6 udp dport 3478 drop
            ip daddr @google_stun_ipv4 udp dport 49152-65535 drop
            ip6 daddr @google_stun_ipv6 udp dport 49152-65535 drop
          }

          chain forward {
            type filter hook forward priority filter; policy accept;

            # Разрешаем форвардинг для контейнеров
            iifname "cilium_*" accept
            oifname "cilium_*" accept
            iifname "lxc*" accept
            oifname "lxc*" accept
            iifname "docker0" accept
            oifname "docker0" accept

            ip saddr 10.42.0.0/16 accept
            ip daddr 10.42.0.0/16 accept
          }
        }
      '';
    };

    firewall.enable = false;
  };
}
