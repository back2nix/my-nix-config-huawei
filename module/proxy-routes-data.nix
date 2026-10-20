# Dedicated consumers. Legacy 1082/1088/1090 selectors remain independent.
let
  tunnels = ["ssh-out1" "ssh-usa-2" "ssh-usa-2-via-casino" "ssh-out1-via-casino" "ssh-ps-kz-via-casino" "ssh-frankfurt" "ssh-frankfurt-via-casino" "ssh-astana" "ssh-ru-beget"];
in {
  selectors = [
    # ssh/деплой на Франкфурт (~/.ssh/config: ProxyCommand nc -x 127.0.0.1:1124).
    # Без ssh-frankfurt* (петля через сам Франкфурт). Выход с IP beget —
    # двумя путями: ssh-casino-relay (seoul-relay, admin-VPN) и ssh-ru-beget
    # (ru-exit, Personal VPN); оба пускают direct-tcpip на 5.252.179.162:22.
    {
      name = "fra-deploy";
      default = "direct-out";
      outbounds = ["direct-out" "ssh-casino-relay" "ssh-ru-beget" "ssh-out1-via-casino" "ssh-usa-2-via-casino" "ssh-ps-kz-via-casino" "ssh-out1" "ssh-usa-2" "ssh-astana"];
    }
    {
      name = "antigravity";
      default = "ssh-out1";
      outbounds = tunnels ++ ["isp-kazakhstan"];
    }
    {
      name = "claude";
      default = "ssh-astana";
      outbounds = tunnels ++ ["isp-kazakhstan"];
    }
    {
      name = "codex";
      default = "ssh-out1";
      outbounds = tunnels ++ ["isp-kazakhstan"];
    }
    {
      name = "telegram";
      default = "ssh-astana";
      outbounds = tunnels ++ ["isp-kazakhstan"];
    }
    {
      name = "git";
      default = "ssh-out1";
      outbounds = tunnels ++ ["direct-out"];
    }
    {
      name = "nix";
      default = "ssh-out1";
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
    {
      name = "browser-kz";
      default = "ssh-astana";
      outbounds = tunnels ++ ["direct-out"];
    }
  ];
  routes = [
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
    {
      name = "browser-kz";
      httpPort = 1115;
      socksPort = 1114;
      outbound = "browser-kz-select";
    }
  ];
}
