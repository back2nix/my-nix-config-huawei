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

      bootstrapDns = [
        "8.8.8.8"
        "9.9.9.9"
        "1.1.1.1"
      ];

      upstreams = {
        groups = {
          default = [
            "8.8.8.8"
            "9.9.9.9"
            "1.1.1.1"
            "https://dns.quad9.net/dns-query"
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
