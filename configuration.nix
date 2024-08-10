{
  inputs,
  config,
  pkgs,
  pkgs-master,
  pkgs-unstable,
  lib,
  ...
}:
# let
# masterPkg = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/master.tar.gz") {
#   nixpkgs.config = {
#     allowUnfree = true;
#   };
# };
# in
{
  nix = {
    package = pkgs.nixFlakes;
    extraOptions =
      lib.optionalString (config.nix.package == pkgs.nixFlakes)
      "experimental-features = nix-command flakes";
  };

  nixpkgs.config.allowUnfree = true;
  # nixpkgs-unstable.config.allowUnfree = true;

  imports = [
    ./hardware-configuration.nix
    ./cachix.nix
    ./module/change.mac.nix
    ./module/users/users.nix
    # ./module/miredo.nix
    ./sops/sops.nix
    # ./module/dns.nix
    ./module/security.nix
    # ./module/shadowsocks.nix
    # ./module/vpn/wireguard.nix
    # ./module/tor.nix
    ./module/xray/xray.nix

    # ./module/podman.nix
    # or
    ./module/docker.nix

    # ./module/arion.nix
    # ./module/wine.nix
    # ./hyperland.nix
    # ./module/wordpress.nix
  ];

  services.spoofdpi.enable = true;
  services.spoofdpi_with_proxy.enable = true;

  boot = {
    # kernelPackages = pkgs.linuxPackages_latest;
    loader.systemd-boot.enable = true;

    supportedFilesystems = ["ntfs"];

    # tmp = {
    #   useTmpfs = true;
    #   tmpfsSize = "95%";
    # };

    kernel.sysctl = {
      "net.ipv4.ip_forward" = "1";
      "net.ipv6.conf.all.forwarding" = "1";
      "net.ipv4.conf.all.send_redirects" = "0";
    };
  };

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    # pulseaudio = {
    #   enable = true;
    #   systemWide = true;
    #   support32Bit = true;
    #   tcp = {
    #     enable = true;
    #     anonymousClients = {allowedIpRanges = ["127.0.0.1" "192.168.7.0/24"];};
    #   };
    # };
    pulseaudio.enable = false;

    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
        MultiProfile = "multiple";
        FastConnectable = true;
      };
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/Moscow";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";

    extraLocaleSettings = {
      LC_ADDRESS = "ru_RU.UTF-8";
      LC_IDENTIFICATION = "ru_RU.UTF-8";
      LC_MEASUREMENT = "ru_RU.UTF-8";
      LC_MONETARY = "ru_RU.UTF-8";
      LC_NAME = "ru_RU.UTF-8";
      LC_NUMERIC = "ru_RU.UTF-8";
      LC_PAPER = "ru_RU.UTF-8";
      LC_TELEPHONE = "ru_RU.UTF-8";
      LC_TIME = "ru_RU.UTF-8";
    };
  };

  # Enable sound with pipewire.
  sound.enable = true;
  # pavucontol for settings loop back "Monitor of Alder Lake PCH-P High Definition Audio Controller HDMI / DisplayPort 3 Output"
  security.rtkit.enable = true;

  environment = {
    # etc."modprobe.d/alsa-base.conf".text = ''
    #   options snd-hda-intel position fix=1
    #   options snd-hda-intel index=0 model=dell-headset-multi,dell-e7x
    #   '';

    sessionVariables = rec {
      GTK_THEME = "Adwaita:dark";
    };

    shells = with pkgs; [zsh];

    # https://discourse.nixos.org/t/tips-tricks-for-nixos-desktop/28488/2
    # чтобы запускать бинарники на nix
    systemPackages = with pkgs; [
      (let
        base = pkgs.appimageTools.defaultFhsEnvArgs;
      in
        pkgs.buildFHSUserEnv (base
          // {
            name = "fhs";
            targetPkgs = pkgs: (base.targetPkgs pkgs) ++ [pkgs.pkg-config];
            profile = "export FHS=1";
            runScript = "zsh";
            extraOutputsToInstall = ["dev"];
          }))
      lm_sensors
      # virtualbox
      direnv
      tcpdump
      tshark
      pavucontrol
      xclip
      pkgs-master.serpl
      sops
      sshs
      pkgs.libcap
      # pkgs.arion
      # pkgs.docker-client
      # pkgs.arion
      # pkgs.podman-compose
      # pkgs.podman-tui
    ];

    etc."proxychains.conf".text = ''
      strict_chain
      proxy_dns

      remote_dns_subnet 224

      tcp_read_time_out 15000
      tcp_connect_time_out 8000

      localnet 127.0.0.0/255.0.0.0

      [ProxyList]
        # ssh -L 0.0.0.0:1081:localhost:1080 bg@localhost -N
        # socks5 192.168.0.5 18081
        socks5 127.0.0.1 1081
        # socks5 192.168.100.3 1080
        # socks5 127.0.0.1 8118
        # socks5 127.0.0.1 9063
    '';
  };

  programs = {
    zsh.enable = true;
    ssh.setXAuthLocation = true;
    nix-ld = {
      package = inputs.nix-ld-rs;
      enable = true;
      libraries = with pkgs; [
        gcc
        icu
        libcxx
        stdenv.cc.cc.lib
        zlib
      ];
    };
    dconf.enable = true;
    wireshark = {
      enable = true;
      package = pkgs-master.wireshark;
    };
  };

  # system.activationScripts.wireshark-capabilities = ''
  #   ${pkgs.libcap.out}/bin/setcap cap_net_raw,cap_net_admin+ep ${pkgs.wireshark}/bin/dumpcap
  # '';

  users.defaultUserShell = pkgs.zsh;

  systemd = {
    # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
    services = {
      "getty@tty1".enable = false;
      "autovt@tty1".enable = false;
      NetworkManager-wait-online.enable = false;
    };

    targets.sleep.enable = false;
    targets.suspend.enable = false;
    targets.hibernate.enable = false;
    targets.hybrid-sleep.enable = false;
    tmpfiles.rules = [
      "d /var/lib/bluetooth 700 root root - -"
      # "d /var/lib/wordpress/localhost 0750 wordpress wwwrun - -"
      # "d /var/lib/wordpress/localhost/wp-content 0750 wordpress wwwrun - -"
      # "d /var/lib/wordpress/localhost/wp-content/plugins 0750 wordpress wwwrun - -"
      # "d /var/lib/wordpress/localhost/wp-content/themes 0750 wordpress wwwrun - -"
      # "d /var/lib/wordpress/localhost/wp-content/upgrade 0750 wordpress wwwrun - -"
    ];
    targets."bluetooth".after = ["systemd-tmpfiles-setup.service"];
    user.services.pipewire-pulse.path = [pkgs.pulseaudio];
  };

  system.stateVersion = "23.11"; # Did you read the comment?

  virtualisation = {
    # waydroid.enable = true;
    # docker = {
    #   enable = false;
    #   rootless = {
    #     enable = true;
    #     setSocketVariable = true;
    #   };
    #   daemon = {
    #     settings = {
    #       # registry-mirrors = [
    #       #   "https://huecker.io"
    #       # ];
    #     };
    #   };
    # };

    # virtualbox.host.enable = true;

    #podman = {
    #  enable = true;
    #  #dockerCompat = true;
    #  dockerSocket.enable = true;
    #  # defaultNetwork.dnsname.enable = true;
    #  defaultNetwork.settings = {
    #    dns_enabled = true;
    #  };
    #};
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  # https://github.com/gvolpe/nix-config/blob/0ed3d66f228a6d54f1e9f6e1ef4bc8daec30c0af/system/configuration.nix#L161
  fonts.packages = with pkgs; [
    times-newer-roman
  ];

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    settings.trusted-users = ["root" "bg"];
  };

  # Enable networking
  networking = {
    networkmanager.enable = true;

    nat = {
      enable = true;
      internalInterfaces = ["ve-+"];
      externalInterface = "wlp0s20f3";
      # externalInterface = "tornet";
      # Lazy IPv6 connectivity for the container
      enableIPv6 = true;
    };

    extraHosts = ''
      127.0.0.1 kafka
    '';

    hostName = "nixos"; # Define your hostname.

    # Open ports in the firewall.
    firewall = {
      enable = true;
      extraCommands = ''
        iptables -t nat -A PREROUTING -i wlp0s20f3 -p tcp --dport 80 -j REDIRECT --to-port 1081
        iptables -t nat -A PREROUTING -i wlp0s20f3 -p tcp --dport 443 -j REDIRECT --to-port 1081
        ip6tables -t nat -A PREROUTING -i wlp0s20f3 -p tcp --dport 80 -j REDIRECT --to-port 1081
        ip6tables -t nat -A PREROUTING -i wlp0s20f3 -p tcp --dport 443 -j REDIRECT --to-port 1081
      '';
    };
  };

  services = {
    # fprintd = {
    # enable = true;
    # package = pkgs.fprintd-tod;
    # tod = {
    #   enable = true;
    #   # driver = pkgs.libfprint-2-tod1-goodix;
    #   driver = pkgs.libfprint-3-tod1-vfs0090;
    # };
    # }; # $ sudo fprintd-enroll --finger right-index-finger <user>

    lorri.enable = true;
    change-mac = {
      enable = false;
      interface = "wlp0s20f3";
      macAddress = "00:11:22:33:44:55";
    };

    dbus.packages = [pkgs.dconf];

    udev.packages = [pkgs.gnome3.gnome-settings-daemon];

    udev = {
      extraRules = ''
        SUBSYSTEM=="usbmon", GROUP="wireshark", MODE="0640"
      '';
    };

    libinput.enable = true;

    xserver = {
      enable = true;
      videoDrivers = ["modesetting"];
      xkb = {
        layout = "us,ru";
      };
      displayManager = {
        gdm = {
          enable = true;
          wayland = false;
        };
      };
      desktopManager.gnome.enable = true;
    };

    printing.enable = true;

    openssh = {
      enable = true;
      settings.X11Forwarding = true;
    };

    flatpak.enable = true;

    blueman.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
      alsa.support32Bit = true;
      jack.enable = true;
    };

    # homepage-dashboard = {
    #   enable = true;
    #   listenPort = 8082;
    # };

    power-profiles-daemon.enable = false;

    tlp = {
      enable = true;
      settings = {
        # CPU_SCALING_GOVERNOR_ON_AC = "performance";
        # only charge up to 80% of the battery capacity
        # START_CHARGE_THRESH_BAT0 = "75";
        # STOP_CHARGE_THRESH_BAT0 = "80";
      };
    };
    physlock.enable = true;
    logind = {
      lidSwitch = "ignore";
      lidSwitchDocked = "ignore";
      lidSwitchExternalPower = "ignore";
      extraConfig = ''
        RuntimeDirectorySize=36G
        HandlePowerKey=suspend
        HandleSuspendKey=suspend
        HandleHibernateKey=suspend
        PowerKeyIgnoreInhibited=yes
        SuspendKeyIgnoreInhibited=yes
        HibernateKeyIgnoreInhibited=yes
      '';
    };
  };
}
