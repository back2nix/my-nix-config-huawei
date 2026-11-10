{
  config,
  pkgs,
  lib,
  ...
}: {
  services.blocky = {
    enable = true;
    settings = {
      ports = {
        # Только loopback: резолвер и API (/api/blocking/disable) не видны из LAN.
        dns = "127.0.0.1:53,[::1]:53";
        http = "127.0.0.1:4000";
      };

      # ☢️ ЗДЕСЬ ОПИСАН СТРОГИЙ ВАРИАНТ: ни одного открытого резолвера.
      # Вариант с откатом на plain (9.9.9.9 и т.д.) собирается из этого же
      # конфига в module/dns-fallback.nix и включается только тумблером
      # «Открытый DNS (откат)». Не добавлять сюда plain-адреса.
      #
      # bootstrapDns резолвит hostname'ы блок-листов. Тоже через dnscrypt-proxy:
      # иначе при каждом старте blocky эти имена уходили бы открытым текстом.
      bootstrapDns = [
        "tcp+udp:127.0.0.1:5300"
      ];

      upstreams = {
        # strict = строгий порядок. В строгом варианте upstream один; в варианте
        # с откатом (module/dns-fallback.nix) после него дописываются plain.
        strategy = "strict";
        # blocky всегда стартует, даже если upstream'ы недоступны (init в фоне) —
        # критично, чтобы DNS не падал намертво. В blocky v0.26 это ключ
        # upstreams.init.strategy, а НЕ верхнеуровневый startStrategy.
        init.strategy = "fast";
        groups = {
          default = [
            # secure через proxy: dnscrypt-proxy → socks5 1082 → ssh-out1-via-casino → Quad9 DoH
            # (module/dnscrypt-proxy.nix). Обходит цензуру/отравление DNS под GFW.
            "127.0.0.1:5300"
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
          fakenews = ["https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-only/hosts"];
          gambling = ["https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/gambling-only/hosts"];
          adult = ["https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts"];
        };
        clientGroupsBlock = {
          default = ["ads" "fakenews" "gambling" "adult"];
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
