{
  inputs,
  config,
  pkgs,
  pkgs-master,
  pkgs-unstable,
  lib,
  ...
}: let
  my-yandex-browser-stable = pkgs.callPackage ./pkgs/yandex-browser-updates.nix {
    edition = "stable";
  };
in {
  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions = lib.optionalString (
      config.nix.package == pkgs.nixVersions.stable
    ) "experimental-features = nix-command flakes";
  };

  nixpkgs.config.allowUnfree = true;

  imports = [
    ./cachix.nix
    ./module/change.mac.nix
    ./module/users/users.nix
    ./module/autossh.nix
    ./sops/sops.nix

    # DNS настройки
    # ./module/dns-dot-tls.nix
    # ./module/dns-doh-https.nix
    ./module/dns-blocky.nix

    # Сеть и контейнеры
    ./module/network-configuration.nix
    ./module/docker.nix
    ./module/wireshark.nix

    # Выберите один из модулей дисплейного сервера:
    ./module/x11.nix # Раскомментируйте для X11
    # ./module/wayland.nix   # Раскомментируйте для Wayland
    ./module/monitoring.nix
    ./module/sign-box.nix
    ./module/vault.nix
  ];

  services.monitoring-stack.enable = true;

  boot = {
    # asus специфичные настройки
    # extraModprobeConfig = ''
    #   options bluetooth disable_ertm=1
    #   options snd-hda-intel model=asus-zenbook
    # '';
    # loader.grub.extraFiles = {
    #   "ssdt-csc3551.aml" = "${./ssdt-csc3551.aml}";
    # };
    # loader.grub.extraConfig = ''
    #   acpi /ssdt-csc3551.aml
    # '';

    loader.systemd-boot.enable = true;
    supportedFilesystems = ["ntfs"];

    kernel.sysctl = {
      "net.ipv4.ip_forward" = "1";
      "net.ipv6.conf.all.forwarding" = "1";
      "net.ipv4.conf.all.send_redirects" = "0";
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    package = pkgs.bluez;
    settings = {
      General = {
        Name = "Computer";
        ControllerMode = "dual";
        FastConnectable = "true";
        Experimental = "true";
        Enable = "Source,Sink,Media,Socket";
        MultiProfile = "multiple";
      };
      Policy = {
        AutoEnable = "true";
      };
    };
  };

  time.timeZone = "Europe/Moscow";

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

  security.rtkit.enable = true;

  security.sudo.extraConfig = ''
    bg ALL=(ALL) NOPASSWD: ${pkgs.colmena}/bin/colmena
  '';

  environment = {
    sessionVariables = rec {
      GTK_THEME = "Adwaita:dark";
    };
    shells = with pkgs; [fish];

    systemPackages = with pkgs; [
      # Базовые системные утилиты
      direnv
      tcpdump
      tshark
      pavucontrol
      xclip
      sops
      sshs
      libcap
      docker-compose
      git
      lsof
      pciutils

      # Пакеты из unstable/master
      pkgs-master.serpl
      pkgs-master.transmission_4-qt
      pkgs-master.openvpn3
      pkgs-master.gemini-cli

      # Контейнеры и кластеры
      docker
      docker-compose
      minikube
      kubectl
      kubernetes-helm
      k9s
      buildah
      skopeo

      # Виртуализация
      virt-manager
      qemu
      OVMF
      swtpm

      # Bluetooth
      bluez
      bluez-tools

      # Утилиты системы
      nixos-generators
      usbutils
      pciutils
      bluez-tools
      gnome-settings-daemon
      my-yandex-browser-stable
      age

      # Мультимедиа
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
      gst_all_1.gst-vaapi
      gst_all_1.gst-libav
      libva
      libva-utils
      intel-media-driver
      mesa
      vlc
      mpv

      # Кодеки
      x264
      x265
      libvpx
      libaom
      dav1d
      rav1e
      svt-av1
      libdvdcss
      libdvdread
      libdvdnav

      iw
      iptables
      nettools
      dnsutils
      nmap
      colmena
      vault

      gnirehtet

      # (pkgs.writeShellScriptBin "claude-desktop-proxy" ''
      # export HTTP_PROXY="http://127.0.0.1:1083"
      # export HTTPS_PROXY="http://127.0.0.1:1083"
      # export NO_PROXY="localhost,127.0.0.1,::1"
      # exec ${inputs.claude-desktop.packages.${system}.claude-desktop}/bin/claude-desktop "$@"
      # '')

      # inputs.claude-desktop.packages.${system}.claude-desktop
      # claude-desktop-proxy
      gemini-proxy
      android-udev-rules
      appimage-run
    ];

    etc."proxychains.conf".text = ''
      strict_chain
      proxy_dns
      remote_dns_subnet 224
      tcp_read_time_out 15000
      tcp_connect_time_out 8000
      localnet 127.0.0.0/255.0.0.0

      [ProxyList]
        socks5 127.0.0.1 1082
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
      libraries = with pkgs; [
        gcc
        icu
        libcxx
        stdenv.cc.cc.lib
        zlib
      ];
    };
    dconf.enable = true;
  };

  users.defaultUserShell = pkgs.fish;

  systemd = {
    services = {
      "getty@tty1".enable = false;
      "autovt@tty1".enable = false;
      NetworkManager-wait-online.enable = false;
    };

    tmpfiles.rules = [
      "d /var/lib/bluetooth 700 root root - -"
    ];
    targets."bluetooth".after = ["systemd-tmpfiles-setup.service"];
    user.services.pipewire-pulse.path = [pkgs.pulseaudio];
  };

  services = {
    transmission = {
      enable = true;
      package = pkgs-master.transmission_4;
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

    dbus.packages = [pkgs.dconf];
    udev.packages = [pkgs.gnome-settings-daemon];

    udev = {
      extraRules = ''
        KERNEL=="event*", SUBSYSTEM=="input", MODE="0664", GROUP="input"
        ACTION=="add|change", KERNEL=="event*", ATTRS{name}=="*keyboard*", GROUP="input", MODE="0664"

        SUBSYSTEM=="usbmon", GROUP="wireshark", MODE="0640"
        SUBSYSTEM=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", MODE="0660", GROUP="wireshark"

        SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="adbusers"
        SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="adbusers"
      '';
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

    physlock.enable = false;

    logind = {
      powerKey = "ignore";
      lidSwitch = "suspend";
      lidSwitchExternalPower = "suspend";
      extraConfig = ''
        HandlePowerKey=ignore
      '';
    };

    triggerhappy = {
      enable = true;
      user = "bg";
      bindings = [
        {
          keys = ["POWER"];
          event = "press";
          cmd = "/run/current-system/sw/bin/toggle-flip";
        }
      ];
    };
  };

  nixpkgs.config.permittedInsecurePackages = [
    "my-yandex-browser-stable-25.8.1.844-1"
  ];

  users.users.bg.extraGroups = ["input"];

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  fonts.packages = with pkgs; [times-newer-roman];

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    settings.trusted-users = [
      "root"
      "bg"
    ];
  };

  services.dns-setup = {
    enable = true;
    mode = "dot"; # Можно легко переключить на "doh" или "plain" "dot-doh"
    extendedFiltering = true;
    customWhitelist = ''
      github.com
      mixpanel.com
      cdn.mxpnl.com
      api-js.mixpanel.com
    '';
  };

  system.stateVersion = "23.11";

  # services.vault-secrets = {
  #   enable = true;
  #   address = "http://127.0.0.1:8200";

  #   # Используем правильное имя секрета, которое соответствует пути в YAML
  #   tokenPath = config.sops.secrets."vault/root_token".path;

  #   secrets = {
  #     "/run/secrets/my-api-key" = {
  #       path = "secret/data/apps/my-app";
  #       key = "api-key";
  #       owner = "bg";
  #       group = "users";
  #       mode = "0400";
  #     };
  #   };
  # };

  # services.vault = {
  #   enable = true;
  #   package = pkgs.vault;
  #   address = "127.0.0.1:8200";
  #   dev = false;
  #   # devRootTokenID = config.sops.placeholder."vault/root_token";

  #   extraConfig = ''
  #   api_addr = "http://127.0.0.1:8200"

  #   storage "file" {
  #     path = "/var/lib/vault/data"
  #   }

  #   listener "tcp" {
  #     address = "127.0.0.1:8200"
  #     tls_disable = true
  #   }

  #   '';
  # };

}
