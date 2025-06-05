{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.services.dns-setup;

  my-blocky-v0262 = pkgs.callPackage ../pkgs/blocky-v0.26.2.nix {};

  # Твои upstreamServers
  upstreamServers = {
    doh = ["127.0.0.1:5335"];
    dot = [
      "tcp-tls:1.1.1.1:853"
      "tcp-tls:8.8.8.8:853"
      "tcp-tls:1.0.0.1:853"
      "tcp-tls:8.8.4.4:853"
    ];
    plain = [
      "1.1.1.1:53"
      "8.8.8.8:53"
    ];
    dot-doh = [
      "127.0.0.1:5335"
      "https://8.8.8.8/dns-query"
      "https://dns.quad9.net/dns-query"
      "tcp-tls:1.1.1.1:853"
      "tcp-tls:8.8.8.8:853"
      "tcp-tls:9.9.9.9:853"
    ];
  };

  commonBlacklists = [
    # Твой список остается тем же
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

  extendedBlacklists = [];
in {
  options.services.dns-setup = {
    enable = lib.mkEnableOption "DNS filtering setup with blocky";

    mode = lib.mkOption {
      type = lib.types.enum ["doh" "dot" "plain" "dot-doh"];
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

    # НАСТРОЙКА POSTGRESQL
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "blocky" ];
      ensureUsers = [
        {
          name = "blocky";
          ensureDBOwnership = true;
        }
        {
          name = "grafana";
        }
      ];

  # Добавляем настройки для TCP подключений
  settings = {
    listen_addresses = "localhost";
    port = 5432;
  };

  # Настройка аутентификации для локальных TCP подключений
  authentication = lib.mkOverride 10 ''
    local all all trust
    host all all 127.0.0.1/32 trust
    host all all ::1/128 trust
  '';
};

    # Настраиваем права для grafana на чтение данных
    systemd.services.postgresql.postStart = lib.mkAfter ''
      $PSQL -tAc 'GRANT CONNECT ON DATABASE blocky TO grafana'
      $PSQL -d blocky -tAc 'GRANT USAGE ON SCHEMA public TO grafana'
      $PSQL -d blocky -tAc 'GRANT SELECT ON ALL TABLES IN SCHEMA public TO grafana'
      $PSQL -d blocky -tAc 'ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO grafana'
    '';

    # СОЗДАЕМ ПОЛЬЗОВАТЕЛЯ BLOCKY
    users.users.blocky = {
      group = "blocky";
      isSystemUser = true;
    };
    users.groups.blocky = {};

    # CloudFlared для DoH режима
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

    # ОСНОВНАЯ КОНФИГУРАЦИЯ BLOCKY С POSTGRESQL
    services.blocky = {
      enable = true;
      package = my-blocky-v0262;
      settings = {
        upstreams = {
          groups.default = upstreamServers.${cfg.mode};
          init.strategy = "blocking";
        };

        blocking = {
          denylists.default = commonBlacklists ++ (lib.optionals cfg.extendedFiltering extendedBlacklists);
          allowlists.default = [
            (pkgs.writeText "whitelist.txt" cfg.customWhitelist)
          ];
          clientGroupsBlock.default = ["default"];
        };

        caching = {
          maxTime = "30m";
          maxItemsCount = 0;
          prefetching = true;
        };

        ports = {
          dns = "127.0.0.1:53";
          http = "0.0.0.0:4000";
        };

        # ВКЛЮЧАЕМ PROMETHEUS МЕТРИКИ
        prometheus = {
          enable = true;
          path = "/metrics";
        };

        # НАСТРАИВАЕМ POSTGRESQL ЛОГИРОВАНИЕ
        queryLog = {
          type = "postgresql";
          target = "postgres://blocky@localhost/blocky";  # Заменили на TCP
          logRetentionDays = 90;
        };

        bootstrapDns = [
          "tcp+udp:1.1.1.1"
          "https://1.1.1.1/dns-query"
          "tcp+udp:8.8.8.8"
        ];

        ede.enable = true;
      };
    };

    # НАСТРОЙКА СЕРВИСА BLOCKY
    systemd.services.blocky = {
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "blocky";
        Group = "blocky";
        Restart = "on-failure";
        RestartSec = "1";
      };
    };

    # Открываем порты
    networking.firewall.allowedTCPPorts = [ 4000 ];

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
