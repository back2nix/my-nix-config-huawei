{ config, pkgs, lib, ... }:

{
  # Открываем порты в фаерволе для DNS
  networking.firewall.allowedUDPPorts = [ 53 ];
  networking.firewall.allowedTCPPorts = [ 53 ];

  services.blocky = {
    enable = true;
    settings = {
      ports = {
        dns = 53;
        http = 4000;
      };

      # bootstrapDns нужен, чтобы зарезолвить hostname'ы DoH/DoT upstream'ов.
      # Только plain IP и только напрямую (без прокси) — иначе курица/яйцо.
      bootstrapDns = [
        "9.9.9.9"
        "1.1.1.1"
      ];

      upstreams = {
        # strict = строгий порядок с откатом: сначала защищённый DNS (DoH→DoT),
        # и только если оба недоступны — откат на plain. Это honest secure-first
        # с failover внутри blocky. Если же сам blocky умрёт — отдельный plain
        # fallback живёт в /etc/resolv.conf (network-configuration.nix).
        strategy = "strict";
        # blocky всегда стартует, даже если upstream'ы недоступны (init в фоне) —
        # критично, чтобы DNS не падал намертво. В blocky v0.26 это ключ
        # upstreams.init.strategy, а НЕ верхнеуровневый startStrategy.
        init.strategy = "fast";
        groups = {
          default = [
            # secure через proxy: dnscrypt-proxy → socks5 1082 → ssh-out1 → Quad9 DoH
            # (module/dnscrypt-proxy.nix). Обходит цензуру/отравление DNS под GFW.
            "127.0.0.1:5300"
            # если dnscrypt-proxy/тоннель недоступны — strict откатывается на plain.
            "9.9.9.9"
            "149.112.112.112"
          ];
        };
      };

      blocking = {
        denylists = {
          ads = [
            "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
            "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.txt"
            "https://raw.githubusercontent.com/back2nix/blocky/refs/heads/master/hosts"
          ];
          fakenews = [ "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-only/hosts" ];
          gambling = [ "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/gambling-only/hosts" ];
          adult = [ "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts" ];
        };
        clientGroupsBlock = {
          default = [ "ads" "fakenews" "gambling" "adult" ];
        };
      };

      caching = {
        minTime = "5m";
        maxTime = "30m";
        prefetching = true;
      };
    };
  };
}
