{pkgs, ...}: let
  user = "bg";
in {
  containers.wasabi = {
    # https://nixos.wiki/wiki/NixOS_Containers
    # sudo nixos-container root-login wasabi
    # sudo nixos-container stop wasabi
    bindMounts = {
      "/home/${user}/.ssh/wireguard-keys" = {
        hostPath = "/etc/nixos/module/vpn";
        isReadOnly = true;
      };
    };

    # ephemeral = true;
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.100.2";
    localAddress = "192.168.100.3";
    hostAddress6 = "fc00::1";
    localAddress6 = "fc00::2";
    config = {
      config,
      pkgs,
      ...
    }: {
      # environment.systemPackages = with pkgs; [
      #   dante
      #  ];
      services._3proxy = {
        # https://nixos.wiki/wiki/3proxy
        # https://github.com/3proxy/3proxy/wiki/How-To-(incomplete)#BIND
        enable = true;
        services = [
          {
            type = "socks";
            auth = ["none"];
            acl = [
              {
                rule = "allow";
                users = ["test1"];
              }
            ];
          }
        ];
        usersFile = "/etc/3proxy.passwd";
      };

      environment.etc = {
        "3proxy.passwd".text = ''
          test1:CL:password1
          test2:CR:$1$rkpibm5J$Aq1.9VtYAn0JrqZ8M.1ME.
        '';
      };

      networking.wg-quick.interfaces = {
        wg0 = {
          address = ["10.8.0.8/24"];
          dns = ["1.1.1.1"];
          privateKeyFile = "/home/${user}/.ssh/wireguard-keys/private";

          peers = [
            {
              publicKey = "7BAuUi2uyh7jpyeezvgsRo5Seh4GF8L5/QF8WqdPB24=";
              presharedKeyFile = "/home/${user}/.ssh/wireguard-keys/presharedKeyFile";
              allowedIPs = ["0.0.0.0/0" "::/0"];
              endpoint = "208.115.223.40:51820";
              persistentKeepalive = 0;
            }
          ];
        };
      };

      system.stateVersion = "23.11";

      networking.firewall = {
        # enable = true;
        allowedTCPPorts = [53 80 433 1080 51820];
      };
      # environment.etc."resolv.conf".text = "nameserver 8.8.8.8";
    };
  };
}
