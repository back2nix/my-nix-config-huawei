{
  lib,
  config,
  ...
}: let
  domainNameServers = ["127.0.0.53" "1.1.1.1" "1.0.0.1" "8.8.8.8" "8.8.4.4"];
in {
  systemd.network = {
    enable = true;
    wait-online.enable = lib.mkForce false; # handled by my custom service
  };

  environment.etc."resolv.conf".mode = "direct-symlink";
  services.resolved = {
    enable = true;
    fallbackDns = domainNameServers;
  };

  networking = {
    nameservers = domainNameServers;
    networkmanager.enable = true;
    wireless.enable = lib.mkForce false; # this enabled 'wpa_supplicant', use networkmanager instead

    nat = {
      enable = true;
      internalInterfaces = ["ve-+"];
      # externalInterface = "tornet";
      # Lazy IPv6 connectivity for the container
      enableIPv6 = true;
    };

    extraHosts = ''
      127.0.0.1 kafka
      127.0.0.1 locahost
      127.0.0.1 host.docker.internal
      # 127.0.0.1 ibigfish.ru
      # 127.0.0.1 model.ibigfish.ru
    '';

    nftables.enable = true;
    # Open ports in the firewall.
    firewall = {
      enable = false;
      allowedTCPPorts = [18082 18081];
      allowedUDPPorts = [18082 18081];
      extraCommands = ''
        iptables -t nat -A PREROUTING -i wlp0s20f3 -p tcp --dport 80 -j REDIRECT --to-port 1081
        iptables -t nat -A PREROUTING -i wlp0s20f3 -p tcp --dport 443 -j REDIRECT --to-port 1081
        ip6tables -t nat -A PREROUTING -i wlp0s20f3 -p tcp --dport 80 -j REDIRECT --to-port 1081
        ip6tables -t nat -A PREROUTING -i wlp0s20f3 -p tcp --dport 443 -j REDIRECT --to-port 1081
      '';
    };
  };
}
