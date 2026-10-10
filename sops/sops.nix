{
  config,
  lib,
  ...
}: let
  consumers = import ../module/proxy-routes-data.nix;
  consumerInbounds = lib.concatMap (r: ["http-${r.name}"] ++ lib.optional (r ? socksPort) "socks-${r.name}") consumers.routes;
  agentInbounds = ["http-antigravity" "http-claude" "http-codex" "http-claude-safe" "http-safe-1088" "http-safe-1090"];
  # Keep exact aliases in sync with extraHosts; do not bypass all *.local names.
  localServiceDomains = lib.unique (lib.concatMap (line: let
    fields = lib.filter (field: field != "") (lib.splitString " " (lib.replaceStrings ["\t"] [" "] (builtins.head (lib.splitString "#" line))));
  in
    if fields != [] && builtins.head fields == "10.0.0.1"
    then builtins.tail fields
    else []) (lib.splitString "\n" config.networking.extraHosts));
in {
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

      "isp_kazakhstan/server" = {};
      "isp_kazakhstan/port" = {};
      "isp_kazakhstan/username" = {};
      "isp_kazakhstan/password" = {};

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
      restartUnits = ["sing-box.service"];
      # Render the encrypted port as a JSON number, rather than a string.
      content = lib.replaceStrings
        [ (builtins.toJSON config.sops.placeholder."isp_kazakhstan/port") ]
        [ config.sops.placeholder."isp_kazakhstan/port" ]
        (builtins.toJSON {
        log.level = "info";

        # Clash-API — рулевое управление селектором usa-select на лету
        # (см. module/proxy-mode.nix и тумблеры в module/users/bg/dconf.nix).
        # Только 127.0.0.1: у API нет авторизации, наружу светить нельзя.
        # cache_file + store_selected — выбор переживает рестарт sing-box
        # и ребут, иначе после каждого падения юнита молча возвращался бы
        # default, и это выглядело бы как «VPN опять отвалился».
        experimental = {
          clash_api.external_controller = "127.0.0.1:9090";
          # Выбор selector'а sing-box сохраняет в cache.db сам, как только
          # cache_file включён (отдельного store_selected с 1.13 уже нет).
          cache_file = {
            enabled = true;
            path = "/var/lib/sing-box/cache.db";
          };
        };

        # IPv4-only: у ssh-out1 нет IPv6-маршрута, любая AAAA-цель даёт
        # "dial tcp [...]: connect: network is unreachable".
        #
        # DNS целевых доменов идёт через тот же выход, что и входящая пара.
        # IP Quad9 задан явно: bootstrap DNS и рекурсия через SOCKS не нужны.
        dns = {
          # Fail promptly on an unavailable selected tunnel. The SSH outbound
          # is patched in module/sign-box.nix to honor this cancellation.
          timeout = "5s";
          servers =
            [
              {
                tag = "dns-dnscrypt";
                type = "udp";
                server = "127.0.0.1";
                server_port = 5300;
              }
            ]
            ++ map (entry: {
              type = "https";
              tag = entry.tag;
              server = "9.9.9.9";
              server_port = 443;
              path = "/dns-query";
              tls = {
                enabled = true;
                server_name = "dns.quad9.net";
              };
              detour = entry.outbound;
            }) ([
                {
                  tag = "dns-1082";
                  outbound = "usa-select";
                }
                {
                  tag = "dns-1084";
                  outbound = "ssh-out1-via-vpn3";
                }
                {
                  tag = "dns-1086";
                  outbound = "ssh-out1-via-casino";
                }
                {
                  tag = "dns-1088";
                  outbound = "frankfurt-select";
                }
                {
                  tag = "dns-1090";
                  outbound = "astana-select";
                }
                {
                  tag = "dns-claude-safe";
                  outbound = "ssh-out1";
                }
                {
                  tag = "dns-safe-1088";
                  outbound = "ssh-frankfurt";
                }
                {
                  tag = "dns-safe-1090";
                  outbound = "ssh-astana";
                }
              ]
              ++ map (r: {
                tag = "dns-${r.name}";
                outbound = r.outbound;
              })
              consumers.routes);
          final = "dns-dnscrypt";
          independent_cache = true;
        };

        inbounds =
          [
            {
              type = "http";
              tag = "http-safe-1088";
              listen = "127.0.0.1";
              listen_port = 1095;
            }
            {
              type = "http";
              tag = "http-safe-1090";
              listen = "127.0.0.1";
              listen_port = 1097;
            }
            {
              type = "http";
              tag = "http-claude-safe";
              listen = "127.0.0.1";
              listen_port = 1093;
            }
            # 1082/1083 — основной прокси. Маршрут не прибит гвоздями: правило
            # ведёт на selector usa-select, переключаемый через proxy-mode
            # (seoul | casino | vpn3 | direct). По умолчанию — прямой ssh до
            # google-seoul (ssh-out1).
            {
              type = "socks";
              tag = "socks-usa";
              listen = "127.0.0.1";
              listen_port = 1082;
            }
            {
              type = "http";
              tag = "http-usa";
              listen = "127.0.0.1";
              listen_port = 1083;
            }
            {
              type = "socks";
              tag = "socks-1084";
              listen = "127.0.0.1";
              listen_port = 1084;
            }
            {
              type = "http";
              tag = "http-1085";
              listen = "127.0.0.1";
              listen_port = 1085;
            }
            # 1088/1089 — второй переключаемый вход, свой selector
            # frankfurt-select (по умолчанию ssh-frankfurt), независимый от
            # usa-select: proxy-mode --1088 <режим> или плитка «Прокси 1088».
            {
              type = "socks";
              tag = "socks-frankfurt";
              listen = "127.0.0.1";
              listen_port = 1088;
            }
            {
              type = "http";
              tag = "http-frankfurt";
              listen = "127.0.0.1";
              listen_port = 1089;
            }
            # Astana: прямой SSH по ключу, независимый выбор маршрута.
            {
              type = "socks";
              tag = "socks-astana";
              listen = "127.0.0.1";
              listen_port = 1090;
            }
            {
              type = "http";
              tag = "http-astana";
              listen = "127.0.0.1";
              listen_port = 1091;
            }
            # 1086/1087 — прежняя схема: прямой ssh до google-seoul (ssh-out1).
            # Только localhost, наружу не светим.
            {
              type = "socks";
              tag = "socks-casino";
              listen = "127.0.0.1";
              listen_port = 1086;
            }
            {
              type = "http";
              tag = "http-casino";
              listen = "127.0.0.1";
              listen_port = 1087;
            }
          ]
          ++ lib.concatMap (r:
            [
              {
                type = "http";
                tag = "http-${r.name}";
                listen = "127.0.0.1";
                listen_port = r.httpPort;
              }
            ]
            ++ lib.optional (r ? socksPort) {
              type = "socks";
              tag = "socks-${r.name}";
              listen = "127.0.0.1";
              listen_port = r.socksPort;
            })
          consumers.routes;

        outbounds =
          [
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
              # server = "192.168.43.1"; # mobile-proxy
              # server = "192.168.1.5"; # wifi-proxy
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
            # Выход через Франкфурт (winjoy-mivocloud-frankfurt): публичный ssh,
            # без обходных путей и VPN — ходим напрямую.
            {
              type = "ssh";
              tag = "ssh-frankfurt";
              server = "5.252.179.162";
              server_port = 22;
              user = "root";
              private_key_path = "/home/bg/.ssh/id_ed25519_eggventure_main";
              host_key = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE8XlR6wxvsc1d58OuiBU9IrYu/NZUozOjjKgUNBrRZ3"];
              host_key_algorithms = ["ssh-ed25519"];
              domain_resolver = {
                server = "dns-dnscrypt";
                strategy = "ipv4_only";
              };
            }
            # FRA через Beget: end-to-end SSH поверх ограниченного релея.
            {
              type = "ssh";
              tag = "ssh-frankfurt-via-casino";
              server = "5.252.179.162";
              server_port = 22;
              user = "root";
              private_key_path = "/home/bg/.ssh/id_ed25519_eggventure_main";
              host_key = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE8XlR6wxvsc1d58OuiBU9IrYu/NZUozOjjKgUNBrRZ3"];
              host_key_algorithms = ["ssh-ed25519"];
              detour = "ssh-casino-relay";
            }
            {
              type = "socks";
              tag = "isp-kazakhstan";
              # The ISP only accepts connections originating from kz-astana.
              detour = "ssh-astana";
              version = "5";
              server = config.sops.placeholder."isp_kazakhstan/server";
              server_port = config.sops.placeholder."isp_kazakhstan/port";
              username = config.sops.placeholder."isp_kazakhstan/username";
              password = config.sops.placeholder."isp_kazakhstan/password";
            }
            # kz-astana: без промежуточных хопов, только SSH с ключом.
            {
              type = "ssh";
              tag = "ssh-astana";
              server = "89.126.194.91";
              server_port = 22;
              user = "root";
              private_key_path = "/home/bg/.ssh/id_ed25519_kz_astana";
              host_key = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFTgmCxYZ/QB3mXySwKA0666IzFfNFxi/3+3x6Kt+ciM"];
              host_key_algorithms = ["ssh-ed25519"];
              domain_resolver = {
                server = "dns-dnscrypt";
                strategy = "ipv4_only";
              };
            }
            # Хоп 1: ssh до casino-VPS ТОЛЬКО через admin-VPN awg-egg
            # (module/wireguard-eggventure.nix), публичного входа нет.
            # Пользователь seoul-relay разрешает direct-tcpip только к USA, ps-kz и FRA:
            # 35.212.30.39:2222, 91.147.105.59:22 и 5.252.179.162:22 (casino-vps/modules/seoul-relay.nix).
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
            # ps-kz: end-to-end SSH through the same restricted Casino relay.
            {
              type = "ssh";
              tag = "ssh-ps-kz-via-casino";
              server = "91.147.105.59";
              server_port = 22;
              user = "ubuntu";
              private_key_path = "/home/bg/.ssh/id_ed25519_kz_astana";
              host_key = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID79o+sZFPQQeE28XTWI/6qs+kljTJW3Uhv4R8+SPj7i"];
              host_key_algorithms = ["ssh-ed25519"];
              detour = "ssh-casino-relay";
            }
            # Выход без проксирования: трафик уходит с самого ноутбука.
            # Раньше ради этого режима 1082/1083 слушали 0.0.0.0 — телефон/планшет
            # тогда ходят «как через мой компьютер», без VPN вообще.
            {
              type = "direct";
              tag = "direct-out";
              domain_resolver = {
                server = "dns-dnscrypt";
                strategy = "ipv4_only";
              };
            }
            # Переключатель для 1082/1083. Менять на лету: proxy-mode <режим>
            # или тумблеры в Quick Settings. interrupt_exist_connections —
            # иначе уже открытые сессии продолжают висеть в старом тоннеле,
            # и после переключения кажется, что ничего не изменилось.
            {
              type = "selector";
              tag = "usa-select";
              outbounds = [
                "ssh-out1"
                "ssh-out1-via-casino"
                "ssh-ps-kz-via-casino"
                "ssh-out1-via-vpn3"
                "ssh-frankfurt"
                "ssh-frankfurt-via-casino"
                "ssh-astana"
                "direct-out"
              ];
              default = "ssh-out1";
              interrupt_exist_connections = true;
            }
            # Переключатель для 1088/1089: тот же набор выходов, но свой выбор.
            {
              type = "selector";
              tag = "frankfurt-select";
              outbounds = [
                "ssh-out1"
                "ssh-out1-via-casino"
                "ssh-ps-kz-via-casino"
                "ssh-out1-via-vpn3"
                "ssh-frankfurt"
                "ssh-frankfurt-via-casino"
                "ssh-astana"
                "direct-out"
              ];
              default = "ssh-frankfurt";
              interrupt_exist_connections = true;
            }
            {
              type = "selector";
              tag = "astana-select";
              outbounds = [
                "ssh-out1"
                "ssh-out1-via-casino"
                "ssh-ps-kz-via-casino"
                "ssh-out1-via-vpn3"
                "ssh-frankfurt"
                "ssh-frankfurt-via-casino"
                "ssh-astana"
                "direct-out"
              ];
              default = "ssh-astana";
              interrupt_exist_connections = true;
            }
          ]
          ++ map (s: {
            type = "selector";
            tag = "${s.name}-select";
            inherit (s) outbounds default;
            interrupt_exist_connections = true;
          })
          consumers.selectors;

        route.rules =
          [
            # Local web services remain reachable through the agent's proxy.
            # Route before sniff/remote DNS, preserving HTTP Host and TLS SNI.
            {
              inbound = agentInbounds;
              ip_cidr = ["10.0.0.1/32"];
              action = "route";
              outbound = "direct-out";
            }
          ]
          ++ lib.optional (localServiceDomains != []) {
            inbound = agentInbounds;
            domain = localServiceDomains;
            action = "route";
            outbound = "direct-out";
            override_address = "10.0.0.1";
          }
          ++ [
            # 1. Достаём домен из TLS SNI / HTTP Host.
            {action = "sniff";}
          ]
          ++ map (r: {
            inbound = ["http-${r.name}"] ++ lib.optional (r ? socksPort) "socks-${r.name}";
            action = "resolve";
            server = "dns-${r.name}";
            strategy = "ipv4_only";
            disable_cache = false;
          })
          consumers.routes
          ++ [
            {
              inbound = ["http-safe-1088"];
              action = "resolve";
              server = "dns-safe-1088";
              strategy = "ipv4_only";
              disable_cache = false;
            }
            {
              inbound = ["http-safe-1090"];
              action = "resolve";
              server = "dns-safe-1090";
              strategy = "ipv4_only";
              disable_cache = false;
            }
            {
              inbound = ["http-claude-safe"];
              action = "resolve";
              server = "dns-claude-safe";
              strategy = "ipv4_only";
              disable_cache = false;
            }
            # 2. Resolve через соответствующий selector, с кэшем по DNS-серверу.
            # Патч selector в module/sign-box.nix сбрасывает кэш при смене выхода.
            {
              inbound = ["socks-usa" "http-usa"];
              action = "resolve";
              server = "dns-1082";
              strategy = "ipv4_only";
              disable_cache = false;
            }
            {
              inbound = ["socks-frankfurt" "http-frankfurt"];
              action = "resolve";
              server = "dns-1088";
              strategy = "ipv4_only";
              disable_cache = false;
            }
            {
              inbound = ["socks-1084" "http-1085"];
              action = "resolve";
              server = "dns-1084";
              strategy = "ipv4_only";
              disable_cache = false;
            }
            {
              inbound = ["socks-casino" "http-casino"];
              action = "resolve";
              server = "dns-1086";
              strategy = "ipv4_only";
              disable_cache = false;
            }
            {
              inbound = ["socks-astana" "http-astana"];
              action = "resolve";
              server = "dns-1090";
              strategy = "ipv4_only";
              disable_cache = false;
            }
            {
              inbound = ["socks-usa" "http-usa" "socks-1084" "http-1085" "socks-casino" "http-casino" "socks-frankfurt" "http-frankfurt" "socks-astana" "http-astana" "http-claude-safe" "http-safe-1088" "http-safe-1090"] ++ consumerInbounds;
              invert = true;
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
              inbound = ["http-claude-safe"];
              outbound = "ssh-out1";
            }
            {
              inbound = ["http-safe-1088"];
              outbound = "ssh-frankfurt";
            }
            {
              inbound = ["http-safe-1090"];
              outbound = "ssh-astana";
            }
            {
              inbound = ["socks-usa" "http-usa"];
              outbound = "usa-select";
            }
            {
              inbound = ["socks-1084" "http-1085"];
              outbound = "ssh-out1-via-vpn3";
            }
            {
              inbound = ["socks-frankfurt" "http-frankfurt"];
              outbound = "frankfurt-select";
            }
            {
              inbound = ["socks-astana" "http-astana"];
              outbound = "astana-select";
            }
            {
              inbound = ["socks-casino" "http-casino"];
              outbound = "ssh-out1-via-casino";
            }
          ]
          ++ map (r: {
            inbound = ["http-${r.name}"] ++ lib.optional (r ? socksPort) "socks-${r.name}";
            outbound = r.outbound;
          })
          consumers.routes;
      });
    };
  };
}
