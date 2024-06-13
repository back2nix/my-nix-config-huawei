{
  config,
  pkgs,
  lib,
  ...
}: {
  # best anonim
  # curl --socks5-hostname 127.0.0.1:8118 ifconfig.me
  # curl --proxy 127.0.0.1:8118 ifconfig.me
  # low anonim
  # curl --socks5-hostname 127.0.0.1:9060 http://ifconfig.me
  # curl --proxy 127.0.0.1:9060 http://ifconfig.me
  services.tor = {
    enable = true;
    torsocks.enable = true;
    tsocks.enable = true;
    client = {
      enable = true;
      # SOCKSPort = "127.0.0.1:9060";
      dns.enable = true;
    };
    settings = {
      UseBridges = true;
      # ClientTransportPlugin = "obfs4 exec ${pkgs.obfs4}/bin/lyrebird";
      ClientTransportPlugin = "obfs4 exec ${pkgs.obfs4}/bin/obfs4proxy";
      Bridge = "obfs4 185.177.207.158:8443 B9E39FA01A5C72F0774A840F91BC72C2860954E5 cert=WA1P+AQj7sAZV9terWaYV6ZmhBUcj89Ev8ropu/IED4OAtqFm7AdPHB168BPoW3RrN0NfA iat-mode=0";
      # Bridge = "obfs4 194.36.189.17:52342 424F07C143B56102F4D53C47D073E8C362A558D7 cert=QnnjtxM30h1ja5YtZ5QqALffAJcdofVctyeqE43MPV40NkdttsxZpLC2NjMviqqkZNCkbw iat-mode=0";
      # obfs4 185.177.207.158:8443 B9E39FA01A5C72F0774A840F91BC72C2860954E5 cert=WA1P+AQj7sAZV9terWaYV6ZmhBUcj89Ev8ropu/IED4OAtqFm7AdPHB168BPoW3RrN0NfA iat-mode=0
      # obfs4 94.34.128.178:60256 9EFCE13C79DFC417FE03CB560455292CD04A67C8 cert=4vkRoWxSTUcAE8QxuKvDsCa+NzZLqQawf/a49s2urT1j2RcuPfa85fpjrKjnx6PVZBY0Gg iat-mode=0
      # Bridge = builtins.readFile /home/${user}/.ssh/nix/tor.obfs4.1;
      TransPort = [9060];
      # DNSPort = [
      #   {
      #     addr = "127.0.0.1";
      #     port = 9053;
      #   }
      # ];
      # VirtualAddrNetworkIPv4 = "172.30.0.0/16";
    };
  };

  services.privoxy = {
    enable = true;
    enableTor = true;
  };

  #services.networkd-dispatcher = {
  #  enable = true;
  #  rules."restart-tor" = {
  #    onState = ["routable" "off"];
  #    script = ''
  #      #!${pkgs.runtimeShell}
  #      if [[ $IFACE == "${bridgeName}" && $AdministrativeState == "configured" ]]; then
  #        echo "Restarting Tor ..."
  #        systemctl restart tor
  #      fi
  #      exit 0
  #    '';
  #  };
  #};

  # networking = {
  # useNetworkd = true;
  # bridges."tornet".interfaces = [];
  # nftables = {
  #   enable = true;
  #   ruleset = ''
  #     table ip nat {
  #       chain PREROUTING {
  #         type nat hook prerouting priority dstnat; policy accept;
  #         iifname "tornet" meta l4proto tcp dnat to 127.0.0.1:9040
  #         iifname "tornet" udp dport 53 dnat to 127.0.0.1:9053
  #       }
  #     }
  #   '';
  # };
  # nat = {
  #   internalInterfaces = ["tornet"];
  #   forwardPorts = [
  #     {
  #       destination = "127.0.0.1:9053";
  #       proto = "udp";
  #       sourcePort = 53;
  #     }
  #   ];
  # };
  # firewall = {
  #   enable = true;
  #   interfaces.tornet = {
  #     allowedTCPPorts = [9040];
  #     allowedUDPPorts = [9053];
  #   };
  # };
  # };

  # systemd.network = {
  #   enable = true;
  #   networks.tornet = {
  #     matchConfig.Name = "tornet";
  #     DHCP = "no";
  #     networkConfig = {
  #       ConfigureWithoutCarrier = true;
  #       Address = "10.100.100.1/24";
  #     };
  #     linkConfig.ActivationPolicy = "always-up";
  #   };
  # };

  # boot.kernel.sysctl = {
  #   "net.ipv4.conf.tornet.route_localnet" = 1;
  # };

  # sudo nixos-container start anonim
  # sudo nixos-container root-login anonim
  # nix-channel --update
  # nixos-rebuild switch

  containers.anonim = {
    autoStart = false;
    privateNetwork = true;
    # hostBridge = "wlp0s20f3";
    hostAddress = "192.168.7.10";
    localAddress = "192.168.7.11";
    config = {
      config,
      pkgs,
      ...
    }: {
      users.extraUsers.anonim = {
        isNormalUser = true;
        home = "/home/anonim";
      };

      system.stateVersion = "24.05";

      networking = {
        firewall = {
          enable = false;
          allowedTCPPorts = [53 80 433 1080 9040 9053];
        };
        nat = {
          enable = true;
          internalInterfaces = ["ve-anonim"];
          externalInterface = "wlp0s20f3";
          # externalInterface = "tornet";
        };
        # useHostResolvConf = lib.mkForce false;
      };
      # services.resolved.enable = true;
    };
  };
}
