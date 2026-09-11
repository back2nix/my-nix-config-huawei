{config, ...}: {
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/home/bg/.config/sops/age/keys.txt";
    age.generateKey = true;

    secrets = {
      # vpn1 = google-seoul-proxy (35.212.30.39)
      "vpn1/ip" = {};
      "vpn1/user" = {};
      "vpn1/private_key_path" = {};

      # vpn2 = germany-1 (178.215.236.246)
      "vpn2/ip" = {};
      "vpn2/user" = {};
      "vpn2/private_key_path" = {};

      "vault/root_token" = {};
      "autossh/ip" = {};

      "mutter/hide_keywords_list" = {
        owner = config.users.users.bg.name;
        mode = "0400";
      };

      "mutter/mutter_always_on_top_by_title" = {
        owner = config.users.users.bg.name;
        mode = "0400";
      };

      "surfshark" = {
        mode = "0440";
        owner = config.users.users.nobody.name;
        group = config.users.users.nobody.group;
      };
      example-key = {
        mode = "0440";
        owner = config.users.users.nobody.name;
        group = config.users.users.nobody.group;
      };
      "myservice/my_subdir/my_secret" = {};
      "xray/server" = {};
      "xray/privateKey" = {};
      "xray/publicKey" = {};
      "xray/uuid" = {};
      "attic/env" = {
        restartUnits = ["atticd.service"];
      };
    };

    # sops/sops.nix - templates."sing-box-config.json"
    templates."sing-box-config.json" = {
      content = builtins.toJSON {
        log.level = "info";

        # IPv4-only: у ssh-out1 нет IPv6-маршрута, любая AAAA-цель даёт
        # "dial tcp [...]: connect: network is unreachable".
        #
        # DNS берём у локального dnscrypt-proxy (module/dnscrypt-proxy.nix):
        # 127.0.0.1:5300 -> socks5 1082 -> ssh-out1-via-casino -> Quad9 DoH.
        # Прямой 1.1.1.1:53 из этой сети отравляется и даёт NXDOMAIN.
        dns.servers = [
          {
            tag = "dns-dnscrypt";
            type = "udp";
            server = "127.0.0.1";
            server_port = 5300;
          }
        ];

        inbounds = [
          # 1082/1083 — основной прокси: google-seoul через casino-VPS
          # (awg-egg -> seoul-relay -> ssh до Сеула), см. outbound ssh-out1-via-casino.
          {
            type = "socks";
            tag = "socks-casino";
            listen = "0.0.0.0";
            listen_port = 1082;
          }
          {
            type = "http";
            tag = "http-casino";
            listen = "0.0.0.0";
            listen_port = 1083;
          }
          {
            type = "socks";
            tag = "socks-china";
            listen = "0.0.0.0";
            listen_port = 1084;
          }
          {
            type = "http";
            tag = "http-china";
            listen = "0.0.0.0";
            listen_port = 1085;
          }
          # 1086/1087 — прежняя схема: прямой ssh до google-seoul (ssh-out1).
          # Только localhost, наружу не светим.
          {
            type = "socks";
            tag = "socks-usa";
            listen = "127.0.0.1";
            listen_port = 1086;
          }
          {
            type = "http";
            tag = "http-usa";
            listen = "127.0.0.1";
            listen_port = 1087;
          }
        ];

        outbounds = [
          {
            type = "ssh";
            tag = "ssh-out1";
            server = "${config.sops.placeholder."vpn1/ip"}";
            server_port = 2222;
            user = "${config.sops.placeholder."vpn1/user"}";
            private_key_path = "${config.sops.placeholder."vpn1/private_key_path"}";
            domain_resolver = {
              server = "dns-dnscrypt";
              strategy = "ipv4_only";
            };
          }
          {
            type = "http";
            tag = "vpn3-proxy";
            domain_resolver = {
              server = "dns-dnscrypt";
              strategy = "ipv4_only";
            };
            # server = "192.168.43.1"; # mobile-china
            # server = "192.168.1.5"; # wifi-china
            server = "192.168.3.6"; # wifi-home
            server_port = 8080;
          }
          {
            type = "ssh";
            tag = "ssh-out1-via-vpn3";
            server = "${config.sops.placeholder."vpn1/ip"}";
            server_port = 2222;
            user = "${config.sops.placeholder."vpn1/user"}";
            private_key_path = "${config.sops.placeholder."vpn1/private_key_path"}";
            detour = "vpn3-proxy";
            domain_resolver = {
              server = "dns-dnscrypt";
              strategy = "ipv4_only";
            };
          }
          # Хоп 1: ssh до casino-VPS ТОЛЬКО через admin-VPN awg-egg
          # (module/wireguard-eggventure.nix), публичного входа нет.
          # Пользователь seoul-relay на сервере умеет лишь direct-tcpip на
          # 35.212.30.39:2222 (casino-vps/modules/seoul-relay.nix).
          {
            type = "ssh";
            tag = "ssh-casino-relay";
            server = "10.100.0.1";
            server_port = 22;
            user = "seoul-relay";
            private_key_path = "/home/bg/.ssh/id_ed25519_seoul_relay";
            host_key = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINoyAUaGwTNIW5pZZB+nHxRaH6QJDOkyCPSJ15iKXKYa"];
            # Без этого клиент sing-box договаривается на ssh-rsa, сервер отдаёт
            # RSA-ключ и пин ed25519 даёт "host key mismatch".
            host_key_algorithms = ["ssh-ed25519"];
          }
          # Хоп 2: ssh до google-seoul поверх хопа 1. Ключ от Сеула не покидает
          # ноутбук, casino видит только зашифрованный поток.
          {
            type = "ssh";
            tag = "ssh-out1-via-casino";
            server = "${config.sops.placeholder."vpn1/ip"}";
            server_port = 2222;
            user = "${config.sops.placeholder."vpn1/user"}";
            private_key_path = "${config.sops.placeholder."vpn1/private_key_path"}";
            detour = "ssh-casino-relay";
          }
        ];

        route.rules = [
          # 1. Достаём домен из TLS SNI / HTTP Host.
          {action = "sniff";}
          # 2. Домен -> только A-записи.
          {
            action = "resolve";
            server = "dns-dnscrypt";
            strategy = "ipv4_only";
          }
          # 3. Клиент (Telegram) сам резолвит AAAA и отдаёт нам голый
          #    IPv6-литерал — resolve тут бессилен, домена нет. Рвём соединение,
          #    клиент по happy-eyeballs уходит на IPv4.
          {
            ip_version = 6;
            action = "reject";
          }
          {
            inbound = ["socks-usa" "http-usa"];
            outbound = "ssh-out1";
          }
          {
            inbound = ["socks-china" "http-china"];
            outbound = "ssh-out1-via-vpn3";
          }
          {
            inbound = ["socks-casino" "http-casino"];
            outbound = "ssh-out1-via-casino";
          }
        ];
      };
    };
  };
}
