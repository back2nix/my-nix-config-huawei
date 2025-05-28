{pkgs, config, lib, ...}:
let
  cfg = config.services.dns-setup;

  my-blocky-v0262 = pkgs.callPackage ../pkgs/blocky-v0.26.2.nix {};

  # Конфигурация upstream серверов
  upstreamServers = {
    doh = [ "127.0.0.1:5335" ];  # cloudflared
    dot = [
      "tcp-tls:1.1.1.1:853"      # Cloudflare DoT
      "tcp-tls:8.8.8.8:853"      # Google DoT
      "tcp-tls:1.0.0.1:853"      # Cloudflare DoT
      "tcp-tls:8.8.4.4:853"      # Google DoT
    ];
    plain = [
      "1.1.1.1:53"
      "8.8.8.8:53"
    ];
    dot-doh = [
      "127.0.0.1:5335"
      # DoH серверы
      # "https://1.1.1.1/dns-query"           # Cloudflare DoH
      "https://8.8.8.8/dns-query"           # Google DoH
      "https://dns.quad9.net/dns-query"     # Quad9 DoH
      # DoT серверы
      "tcp-tls:1.1.1.1:853"                # Cloudflare DoT
      "tcp-tls:8.8.8.8:853"                # Google DoT
      "tcp-tls:9.9.9.9:853"                # Quad9 DoT
    ];
  };

  commonBlacklists = [
    "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt"
    "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts"
    "https://v.firebog.net/hosts/static/w3kbl.txt"
    "https://adaway.org/hosts.txt"
    "https://v.firebog.net/hosts/AdguardDNS.txt"
    "https://v.firebog.net/hosts/Admiral.txt"
    "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt"
    "https://v.firebog.net/hosts/Easylist.txt"
    "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
    "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts"
    "https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts"
    "https://v.firebog.net/hosts/Easyprivacy.txt"
    "https://v.firebog.net/hosts/Prigent-Ads.txt"
    "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts"
    "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt"
    "https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt"
    "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt"
    "https://v.firebog.net/hosts/Prigent-Crypto.txt"
    "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts"
    "https://bitbucket.org/ethanr/dns-blacklists/raw/8575c9f96e5b4a1308f2f12394abd86d0927a4a0/bad_lists/Mandiant_APT1_Report_Appendix_D.txt"
    "https://phishing.army/download/phishing_army_blocklist_extended.txt"
    "https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt"
    "https://v.firebog.net/hosts/RPiList-Malware.txt"
    "https://v.firebog.net/hosts/RPiList-Phishing.txt"
    "https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt"
    "https://raw.githubusercontent.com/AssoEchap/stalkerware-indicators/master/generated/hosts"
    "https://urlhaus.abuse.ch/downloads/hostfile/"
    "https://lists.cyberhost.uk/malware.txt"
    "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
    "https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt"
    "https://osint.digitalside.it/Threat-Intel/lists/latestdomains.txt"
    "https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt"
    "https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser"
  ];

  # Расширенные блэклисты (опционально)
  extendedBlacklists = [
  ];
in
  {
    options.services.dns-setup = {
      enable = lib.mkEnableOption "DNS filtering setup with blocky";

      mode = lib.mkOption {
        type = lib.types.enum [ "doh" "dot" "plain" "dot-doh" ];
        description = "DNS upstream mode: DoH, DoT, or plain DNS";
      };

      extendedFiltering = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable extended malware/phishing filtering lists";
      };

      customWhitelist = lib.mkOption {
        type = lib.types.lines;
        default = ''
          www.t.co
          t.co
        '';
        description = "Custom whitelist domains";
      };
    };

    config = lib.mkIf cfg.enable {
    # Отключаем systemd-resolved
    services.resolved.enable = false;

    # CloudFlared только для DoH режима
    systemd.services.cloudflared-doh = lib.mkIf (cfg.mode == "doh" || cfg.mode == "dot-doh") {
      enable = true;
      description = "DNS over HTTPS (DoH) proxy client";
      wants = ["network-online.target"];
      before = ["blocky.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
        DynamicUser = "yes";
        ExecStart = "${pkgs.cloudflared}/bin/cloudflared proxy-dns --port 5335";
      };
    };

    # Основная конфигурация blocky
services.blocky = {
  enable = true;
  package = my-blocky-v0262;
  settings = {
    upstreams = {
      groups.default = upstreamServers.${cfg.mode}; # Использует "dot", если cfg.mode = "dot"
      init.strategy = "blocking"; # ИСПРАВЛЕНО
      # strategy = "random_healthy"; # Можно добавить: выбирать случайный работающий сервер
    };

    blocking = {
      denylists.default = commonBlacklists ++ (lib.optionals cfg.extendedFiltering extendedBlacklists);
      allowlists.default = [
        (pkgs.writeText "whitelist.txt" cfg.customWhitelist)
      ];
      clientGroupsBlock.default = [ "default" ];
    };

    caching = {
      maxTime = "30m";
      maxItemsCount = 0;
      prefetching = true;
      # minTime = "1m";
      # prefetchExpires = "2h";
      # prefetchThreshold = 5;
    };

    ports = {
      dns = "127.0.0.1:53";
      http = "127.0.0.1:4000";
    };

    # bootstrapDns = [ "tcp:1.1.1.1" "udp:8.8.8.8" ];
    # bootstrapDns = "tcp+udp:1.1.1.1";
    bootstrapDns = [
      "tcp+udp:1.1.1.1"
      "https://1.1.1.1/dns-query"
      "tcp+udp:8.8.8.8"
      ];

    queryLog = {
      type = "console";
    };

    ede.enable = true;

    # Если проблемы с DNS, раскомментируйте для более подробных логов:
    # logLevel = "debug";
  };
};

    # Сетевые настройки
    networking = {
      resolvconf.useLocalResolver = true;
      networkmanager.dns = lib.mkForce "none";
      nameservers = ["127.0.0.1"];
      dhcpcd.extraConfig = "nohook resolv.conf";
    };

    environment.etc."resolv.conf".text = lib.mkForce ''
      nameserver 127.0.0.1
      options edns0 trust-ad
    '';
  };
}
