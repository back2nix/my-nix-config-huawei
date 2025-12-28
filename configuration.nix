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
    # nixPath = [ "nixpkgs=flake:nixpkgs" ];
    # registry.nixpkgs = {
    #   from = {
    #     id = "nixpkgs";
    #     type = "indirect";
    #   };
    #   to = {
    #     type = "github";
    #     owner = "NixOS";
    #     repo = "nixpkgs";
    #     ref = "nixos-25.05";
    #   };
    # };
    package = pkgs.nixVersions.stable;
    extraOptions = lib.optionalString (
      config.nix.package == pkgs.nixVersions.stable
    ) "experimental-features = nix-command flakes";
  };

  nixpkgs.config.allowUnfree = true;
  # nixpkgs.config.cudaSupport = true;
  nixpkgs.config.allowUnfreePredicate =
    p:
    builtins.all (
      license:
      license.free
      || builtins.elem license.shortName [
        "CUDA EULA"
        "cuDNN EULA"
        "cuTENSOR EULA"
        "NVidia OptiX EULA"
      ]
    ) (if builtins.isList p.meta.license then p.meta.license else [ p.meta.license ]);

  imports = [
    ./cachix.nix
    ./module/change.mac.nix
    ./module/users/users.nix
    # ./module/autossh.nix
    ./sops/sops.nix

    # ./module/kvm.nix
    ./module/virtualbox.nix
    ./module/k3s.nix

    # DNS настройки
    # ./module/dns-dot-tls.nix
    # ./module/dns-doh-https.nix
    # ./module/dns-blocky.nix
    ./module/blocky/default.nix

    # Сеть и контейнеры
    ./module/network-configuration.nix
    ./module/docker.nix
    ./module/wireshark.nix

    # Выберите один из модулей дисплейного сервера:
    ./module/x11.nix # Раскомментируйте для X11
    # ./module/wayland.nix   # Раскомментируйте для Wayland
    # ./module/monitoring.nix
    ./module/sign-box.nix
    # ./module/vault.nix
    # ./module/tor.nix
    ./module/attic.nix
  ];


  # ==========================================
  # Настройки Attic (взято из examples/attic)
  # ==========================================
  services.attic = {
    enable = true;

    settings = {
      listen = "[::]:8080";
      database.url = "sqlite:///var/lib/atticd/server.db?mode=rwc";

      # УДАЛЯЕМ блок jwt.signing отсюда.
      # Он будет подтянут автоматически из переменной окружения.

      storage = {
        type = "local";
        path = "/var/lib/atticd/storage";
      };

      chunking = {
        nar-size-threshold = 64 * 1024;
        min-size = 16 * 1024;
        avg-size = 64 * 1024;
        max-size = 256 * 1024;
      };
    };
  };

  # Подключаем файл с секретами к сервису atticd
  # Сервис в systemd называется "atticd", даже если модуль называется "services.attic"
  systemd.services.atticd.serviceConfig.EnvironmentFile = config.sops.secrets."attic/env".path;

  # services.monitoring-stack.enable = true;

  boot = {
    binfmt.emulatedSystems = [ "aarch64-linux" ];
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
      MUTTER_HIDE_WINDOWS_BY_TITLE = "$(cat ${config.sops.secrets."mutter/hide_keywords_list".path})";
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
      mktorrent

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
      # gnome-settings-daemon
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
      # iptables
      nettools
      dnsutils
      nmap
      colmena
      # vault

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
      appimage-run
      dbeaver-bin
      claude-code-proxy
      # claude-code
      xdotool
      xorg.xwininfo
      wl-clipboard
      gnome-screenshot

      gnome-shell
      gnome-shell-extensions
      gnomeExtensions.always-indicator

      iotop
      sysstat
      iftop
      mtr

      stdenv.cc.cc.lib
      zlib
      gcc

      uv
      attic-client


      (writeShellScriptBin "virt-switch" ''
        # ЖЕСТКО ЗАДАЕМ PATH, ЧТОБЫ КОМАНДЫ БЫЛИ ВИДНЫ
        export PATH="${lib.makeBinPath [
          kmod          # modprobe, lsmod, rmmod
          procps        # pkill
          gnugrep       # grep
          systemd       # systemctl
          coreutils     # echo, sleep и т.д.
          util-linux    # на всякий случай
        ]}:$PATH"

        # Теперь вставляем код из файла
        ${builtins.readFile ./scripts/virt-switch.sh}
      '')
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
    # transmission = {
    #   enable = true;
    #   package = pkgs-master.transmission_4;
    # };

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
      # Custom config moved to settings.Login to avoid deprecation warnings
      settings.Login = {
        HandlePowerKey = "ignore";
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "suspend";
      };
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
    "my-yandex-browser-stable-25.10.1.1173-1"
    "claude-code"
    "mbedtls-2.28.10"
  ];

  users.users.bg.extraGroups = ["input" "docker" "k3s"];

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

  # blocky = {
  #   enable = true;
  #   openFirewall = true;
  #   enableMonitoring = false;
  # # serviceDomain = "stop-pub.${config.homelab.domain}";
  # };

  # services.dns-setup = {
  #   enable = false;
  #   mode = "dot"; # Можно легко переключить на "doh" или "plain" "dot-doh"
  #   extendedFiltering = true;
  #   customWhitelist = ''
  #     github.com
  #     mixpanel.com
  #     cdn.mxpnl.com
  #     api-js.mixpanel.com
  #   '';
  # };

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

  programs.obs-studio = {
    enable = true;

    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-gstreamer
      obs-vkcapture

      # Для эффектов плохой картинки:
      obs-shaderfilter # Кастомные шейдеры и эффекты
      obs-composite-blur # Дополнительные эффекты размытия
    ];
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    config.common.default = [ "gnome" "gtk" ];
  };
}
