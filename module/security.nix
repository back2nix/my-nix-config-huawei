{pkgs, ...}: {
  imports = [
    # ./modules/spectre_and_meltdown.nix
  ];

  environment.systemPackages = with pkgs; [
    # pinentry-gnome
    gnupg
  ];

  # TODO: add firejails.
  # networking.firewall.allowedTCPPorts = [22000];
  networking.firewall.allowPing = true; # allow to be pinged.

  # security.mitigations.iWantPerformanceRatherThanSecurity = true; # indeed.

  boot.kernel.sysctl = {
    "kernel.dmesg_restrict" = true; # prevent dmesg extraction from non-privileged users
    "kernel.yama.ptrace_scope" = 1; # prevent ptracing
  };

  # GPG
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = false;
    # pinentryFlavor = "qt";
  };

  # DNS
  networking = {
    nameservers = [
      "::1" # DNSCrypt-Proxy
      "127.0.0.1" # DNSCrypt-Proxy
      "1.1.1.1"
      "9.9.9.9"
      "8.8.8.8"
      "1.0.0.1" # CloudFlare, Google, Quad-9
      "2620:119:35::35" # OpenDNS
      "2620:119:53::53" # OpenDNS
    ];
    dhcpcd.extraConfig = "nohook resolv.conf";
    # If using NetworkManager:
    networkmanager.dns = "none";
  };

  services.dnscrypt-proxy2 = {
    enable = true;
    settings = {
      ipv6_servers = true;
      require_dnssec = true;
      require_nolog = true;

      listen_addresses = ["127.0.0.1:53" "[::1]:53"];

      sources.public-resolvers = {
        urls = [
          "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v2/public-resolvers.md"
          "https://download.dnscrypt.info/resolvers-list/v2/public-resolvers.md"
        ];
        cache_file = "/var/lib/dnscrypt-proxy2/public-resolvers.md";
        minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
        refresh_delay = 72;
      };
    };
  };

  networking.firewall.extraCommands = ''
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-port 53
    iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-port 53
  '';
}
