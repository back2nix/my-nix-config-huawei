{pkgs, config, lib, ...}:
let
  cfg = config.services.dns-setup;

  # Конфигурация upstream серверов
  upstreamServers = {
    doh = [ "127.0.0.1:5335" ];  # cloudflared
    dot = [
      "1.1.1.1:853"              # Cloudflare DoT
      "8.8.8.8:853"              # Google DoT
      "1.0.0.1:853"              # Cloudflare DoT
      "8.8.4.4:853"              # Google DoT
    ];
    plain = [
      "1.1.1.1:53"
      "8.8.8.8:53"
    ];
  };

  # Общие блэклисты
  commonBlacklists = [
    "https://adaway.org/hosts.txt"
    "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt"
    "https://v.firebog.net/hosts/AdguardDNS.txt"
    "https://v.firebog.net/hosts/Admiral.txt"
    "https://v.firebog.net/hosts/Easylist.txt"
    "https://v.firebog.net/hosts/Easyprivacy.txt"
    "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt"
    "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
    "https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts"
    "https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt"
    "https://urlhaus.abuse.ch/downloads/hostfile/"
  ];

  # Расширенные блэклисты (опционально)
  extendedBlacklists = [
    "https://bitbucket.org/ethanr/dns-blacklists/raw/8575c9f96e5b4a1308f2f12394abd86d0927a4a0/bad_lists/Mandiant_APT1_Report_Appendix_D.txt"
    "https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt"
    "https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt"
    "https://osint.digitalside.it/Threat-Intel/lists/latestdomains.txt"
    "https://phishing.army/download/phishing_army_blocklist_extended.txt"
    "https://raw.githubusercontent.com/AssoEchap/stalkerware-indicators/master/generated/hosts"
    "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt"
    "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts"
    "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts"
    "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts"
    "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts"
    "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt"
    "https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt"
    "https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt"
    "https://v.firebog.net/hosts/Prigent-Ads.txt"
    "https://v.firebog.net/hosts/Prigent-Crypto.txt"
    "https://v.firebog.net/hosts/RPiList-Malware.txt"
    "https://v.firebog.net/hosts/RPiList-Phishing.txt"
    "https://v.firebog.net/hosts/static/w3kbl.txt"
    "https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser"
  ];
in
{
  options.services.dns-setup = {
    enable = lib.mkEnableOption "DNS filtering setup with blocky";

    mode = lib.mkOption {
      type = lib.types.enum [ "doh" "dot" "plain" ];
      default = "dot";
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
    systemd.services.cloudflared-doh = lib.mkIf (cfg.mode == "doh") {
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
      settings = {
        upstream.default = upstreamServers.${cfg.mode};
        startVerifyUpstream = true;

        blocking = {
          blackLists.default = commonBlacklists ++ (lib.optionals cfg.extendedFiltering extendedBlacklists);
          whiteLists.default = [
            (pkgs.writeText "whitelist.txt" cfg.customWhitelist)
          ];
          clientGroupsBlock.default = [ "default" ];
        };

        caching = {
          maxTime = "30m";
          maxItemsCount = 0;
          prefetching = true;
        };

        port = "127.0.0.1:53";
        httpPort = 4000;
        bootstrapDns = "tcp+udp:1.1.1.1";

        queryLog = {
          type = "console";
        };

        ede.enable = true;
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
