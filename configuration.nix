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
    package = pkgs.nixVersions.stable;  # This is the new version
    extraOptions =
      lib.optionalString (config.nix.package == pkgs.nixVersions.stable)
      "experimental-features = nix-command flakes";
    };

    nixpkgs.config.allowUnfree = true;
  # nixpkgs-unstable.config.allowUnfree = true;

  imports = [
    # ./devices/asus-ux3405m/hardware-configuration.nix
    # ./devices/huawei-rlef-x/hardware-configuration.nix
    ./cachix.nix
    ./module/change.mac.nix
    ./module/users/users.nix
    # ./module/miredo.nix
    ./sops/sops.nix
    # ./module/dns.nix
    # ./module/security.nix
    # ./module/shadowsocks.nix
    # ./module/vpn/wireguard.nix
    # ./module/tor.nix
    # ./module/xray/xray.nix

    ./module/network-configuration.nix
    # ./module/podman.nix
    # or
    ./module/docker.nix
    # ./module/virtualisation-configuration.nix
    # ./powersave.nix
    ./powersave-small.nix
    ./module/wireshark.nix


    # ./module/arion.nix
    # ./module/wine.nix
    # ./hyperland.nix
    # ./module/wordpress.nix

    # ./module/surfshark.nix
  ];

  # surfshark.enable = true;
  # surfshark.alwaysOn = true;  # Optional: Keep VPN always connected
  # surfshark.iptables.enable = true;  # Optional: Enforce VPN usage via iptables
  # surfshark.iptables.enforceForUsers = [ "bg" ];  # Enforce for specific users

  # services.spoofdpi.enable = true;
  # services.spoofdpi_with_proxy.enable = true;

  boot = {
    # asus
    kernelParams = ["i915.force_probe=7d55"];
    extraModprobeConfig = ''
      options bluetooth disable_ertm=1
      options snd-hda-intel model=asus-zenbook
    '';
    loader.grub.extraFiles = {
      "ssdt-csc3551.aml" = "${./ssdt-csc3551.aml}"; # https://github.com/smallcms/asus_zenbook_ux3405ma
    };
    loader.grub.extraConfig = ''
      acpi /ssdt-csc3551.aml
    '';
    # kernelPackages = pkgs.linuxPackages_testing;
    # kernelPackages = pkgs-master.linuxPackages_testing;
    # pkgs.linuxPackages_5_9
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

  # systemctl --user restart pipewire pipewire-pulse wireplumber
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Name = "Computer";
        ControllerMode = "dual";
        FastConnectable = "true";
        Experimental = "true";
        Enable = "Source,Sink,Media,Socket";
        MultiProfile = "multiple";
      };
      Policy = { AutoEnable = "true"; };
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
  # sound.enable = true;
  # pavucontol for settings loop back "Monitor of Alder Lake PCH-P High Definition Audio Controller HDMI / DisplayPort 3 Output"
  security.rtkit.enable = true;

  environment = {
    # etc."modprobe.d/alsa-base.conf".text = ''
    #   options snd-hda-intel position fix=1
    #   options snd-hda-intel index=0 model=dell-headset-multi,dell-e7x
    #   '';

    sessionVariables = rec {GTK_THEME = "Adwaita:dark";};

    shells = with pkgs; [fish];

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
        runScript = "fish";
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
      pkgs.docker-compose
      git
      lsof
      pciutils
      pkgs-master.transmission_4-qt

      # work
      # tpm2-tss
      pkgs-master.openvpn3

      # pkgs.arion
      # pkgs.docker-client
      # pkgs.arion
      # pkgs.podman-compose
      # pkgs.podman-tui

      docker
      docker-compose
      minikube
      kubectl
      kubernetes-helm
      k9s
      buildah
      skopeo

      # Инструменты виртуализации
      virt-manager
      qemu
      OVMF
      swtpm

      bluez
      bluez-tools

      nixos-generators
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
    openvpn3.enable = true;
    zsh.enable = true;
    fish.enable = true;
    ssh.setXAuthLocation = true;
    nix-ld = {
      package = inputs.nix-ld-rs;
      enable = true;
      libraries = with pkgs; [gcc icu libcxx stdenv.cc.cc.lib zlib];
    };
    dconf.enable = true;
    # wireshark = {
    #   enable = true;
    #   package = pkgs-master.wireshark;
    # };
  };

  # system.activationScripts.wireshark-capabilities = ''
  #   ${pkgs.libcap.out}/bin/setcap cap_net_raw,cap_net_admin+ep ${pkgs.wireshark}/bin/dumpcap
  # '';


  users.defaultUserShell = pkgs.fish;

  systemd = {
    # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
    services = {
      "getty@tty1".enable = false;
      "autovt@tty1".enable = false;
      NetworkManager-wait-online.enable = false;
    };


    # targets.sleep.enable = false;
    # targets.suspend.enable = false;
    # targets.hibernate.enable = false;
    # targets.hybrid-sleep.enable = false;

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
  fonts.packages = with pkgs; [times-newer-roman];

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    settings.trusted-users = ["root" "bg"];
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
    transmission = {
      enable = true;
      package = pkgs-master.transmission_4;
      # settings = {
      #   download-dir = "${config.services.transmission.home}/Downloads";
      # };
    };


    lorri = {
      enable = true;
      package = pkgs-master.lorri;
    };
    change-mac = {
      enable = false;
      interface = "wlp0s20f3";
      macAddress = "00:11:22:33:44:55";
    };

    # mkdir -p /etc/openvpn3/configs
    dbus.packages = [pkgs.dconf];

    udev.packages = [pkgs.gnome-settings-daemon];

    udev = {
      extraRules = ''
        SUBSYSTEM=="usbmon", GROUP="wireshark", MODE="0640"
        SUBSYSTEM=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", MODE="0660", GROUP="wireshark"
      '';
    };

    libinput.enable = true;

    xserver = {
      enable = true;
      videoDrivers = ["modesetting"];
      xkb = {layout = "us,ru";};
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

    physlock.enable = true;
    # power-profiles-daemon.enable = false;

    # tlp = {
    #   enable = true;
    #   settings = {
    #     # CPU_SCALING_GOVERNOR_ON_AC = "performance";
    #     # only charge up to 80% of the battery capacity
    #     # START_CHARGE_THRESH_BAT0 = "75";
    #     # STOP_CHARGE_THRESH_BAT0 = "80";
    #   };
    # };
    # logind = {
    #   lidSwitch = "ignore";
    #   lidSwitchDocked = "ignore";
    #   lidSwitchExternalPower = "ignore";
    #   extraConfig = ''
    #     RuntimeDirectorySize=36G
    #     HandlePowerKey=suspend
    #     HandleSuspendKey=suspend
    #     HandleHibernateKey=suspend
    #     PowerKeyIgnoreInhibited=yes
    #     SuspendKeyIgnoreInhibited=yes
    #     HibernateKeyIgnoreInhibited=yes
    #   '';
    # };
  };
}
