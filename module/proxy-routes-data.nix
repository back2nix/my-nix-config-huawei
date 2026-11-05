# Dedicated consumers. Legacy 1082/1088 selectors remain independent.
let
  tunnels = ["ssh-out1" "ssh-usa-2" "ssh-usa-2-via-casino" "ssh-out1-via-casino" "ssh-usa-2-via-fra" "ssh-out1-via-fra" "ssh-frankfurt" "ssh-frankfurt-via-casino" "ssh-france"];
in {
  selectors = [
    # ssh/деплой на Франкфурт (~/.ssh/config: ProxyCommand nc -x 127.0.0.1:1124).
    # Без ssh-frankfurt* (петля через сам Франкфурт). Выход с IP французского хоста —
    # двумя путями: ssh-casino-relay (seoul-relay, admin-VPN) и ssh-france
    # (ru-exit, Personal VPN); оба пускают direct-tcpip на 5.252.179.162:22.
    {
      name = "fra-deploy";
      default = "direct-out";
      outbounds = ["direct-out" "ssh-casino-relay" "ssh-france" "ssh-out1-via-casino" "ssh-usa-2-via-casino" "ssh-out1" "ssh-usa-2"];
    }
    # ssh/деплой на Париж (новый home, 194.180.174.137; ~/.ssh/config:
    # ProxyCommand nc -x 127.0.0.1:1126). Без ssh-casino-relay: seoul-relay
    # пускает только фиксированные ssh-цели. По умолчанию Франкфурт: трафик бесплатный.
    {
      name = "paris-deploy";
      default = "ssh-frankfurt";
      outbounds = ["ssh-frankfurt" "direct-out" "ssh-france" "ssh-frankfurt-via-casino" "ssh-out1" "ssh-usa-2" "ssh-out1-via-casino" "ssh-usa-2-via-casino" "ssh-out1-via-fra" "ssh-usa-2-via-fra"];
    }
    # Системный VPN (module/system-vpn.nix): selector = желаемое состояние
    # «весь трафик». direct-out = выключено; wg-paris/wg-fra — заглушки (block),
    # означают «поднят полный AmneziaWG-туннель», трафик через них не идёт.
    {
      name = "system";
      default = "direct-out";
      outbounds = ["direct-out" "wg-paris" "wg-fra"] ++ tunnels;
    }
    {
      name = "antigravity";
      default = "ssh-out1";
      outbounds = tunnels;
    }
    {
      name = "claude";
      default = "ssh-usa-2";
      outbounds = tunnels;
    }
    {
      name = "codex";
      default = "ssh-out1";
      outbounds = tunnels;
    }
    {
      name = "telegram";
      default = "ssh-out1";
      outbounds = tunnels;
    }
    {
      name = "git";
      default = "ssh-out1";
      outbounds = tunnels ++ ["direct-out"];
    }
    {
      name = "nix";
      # Франкфурт: трафик бесплатный (USA — платный).
      default = "ssh-frankfurt";
      outbounds = tunnels ++ ["direct-out"];
    }
    {
      name = "voicestudio";
      default = "ssh-out1";
      outbounds = tunnels ++ ["direct-out"];
    }
    {
      name = "browser-usa";
      default = "ssh-out1";
      outbounds = tunnels ++ ["direct-out"];
    }
    {
      name = "browser-fra";
      default = "ssh-frankfurt";
      outbounds = tunnels ++ ["direct-out"];
    }
  ];
  routes = [
    # Вход для TUN-инстанса sing-box-tun (только 127.0.0.1).
    {
      name = "system";
      httpPort = 1129;
      socksPort = 1128;
      outbound = "system-select";
    }
    {
      name = "paris-deploy";
      httpPort = 1127;
      socksPort = 1126;
      outbound = "paris-deploy-select";
    }
    {
      name = "fra-deploy";
      httpPort = 1125;
      socksPort = 1124;
      outbound = "fra-deploy-select";
    }
    {
      name = "antigravity";
      httpPort = 1121;
      outbound = "antigravity-select";
    }
    {
      name = "claude";
      httpPort = 1101;
      outbound = "claude-select";
    }
    {
      name = "codex";
      httpPort = 1103;
      outbound = "codex-select";
    }
    {
      name = "telegram";
      httpPort = 1107;
      socksPort = 1106;
      outbound = "telegram-select";
    }
    {
      name = "git";
      httpPort = 1119;
      socksPort = 1118;
      outbound = "git-select";
    }
    {
      name = "nix";
      httpPort = 1105;
      socksPort = 1104;
      outbound = "nix-select";
    }
    {
      name = "voicestudio";
      httpPort = 1123;
      socksPort = 1122;
      outbound = "voicestudio-select";
    }
    {
      name = "browser-usa";
      httpPort = 1111;
      socksPort = 1110;
      outbound = "browser-usa-select";
    }
    {
      name = "browser-casino";
      httpPort = 1117;
      socksPort = 1116;
      outbound = "ssh-out1-via-casino";
    }
    {
      name = "browser-fra";
      httpPort = 1113;
      socksPort = 1112;
      outbound = "browser-fra-select";
    }
  ];
}
