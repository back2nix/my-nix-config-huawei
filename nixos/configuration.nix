# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  ...
}: let
  user = "bg";
in {
  imports = [
    # Include the results of the hardware scan.
    #<home-manager/nixos>
    ./hardware-configuration.nix
    ./cachix.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;

  boot.supportedFilesystems = ["ntfs"];

  services.xserver.videoDrivers = ["modesetting"];

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Moscow";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
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

  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };
  environment.sessionVariables = rec {
    GTK_THEME = "Adwaita:dark";
  };

  # Enable the X11 windowing system.
  services.xserver = {
    # gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Alt>Shift_L']"
    # gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
    # gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Open Terminal'
    # gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'kgx'
    # gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'kitty'
    # gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Primary><Alt>T'
    enable = true;
    layout = "us,ru";
    # xkbVariant = "workman,";
    #xkbOptions = "grp:win_space_toggle";
    # xkbOptions = "grp:ctrl_shift_toggle";
    displayManager.gdm.enable = true;
    displayManager.gdm.wayland = false;
    desktopManager.gnome.enable = true;

    # desktopManager.gnome = {
    #   extraGSettingsOverridePackages = with pkgs; [ gnome.gnome-settings-daemon ];
    #   extraGSettingsOverrides = ''
    #     # switch language
    #     [org.gnome.desktop.wm.keybindings]
    #     switch-input-source="['<Alt>Shift_L']"
    #
    #     # Favorite apps in gnome-shell
    #     # [org.gnome.settings-daemon.plugins.media-keys]
    #     # custom-keybindings = "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']";
    #       [org.gnome.settings-daemon.plugins.media-keys.custom-keybindings.custom0]
    #       binding='<Primary><Alt>T'
    #       command='kgx'
    #       name='Open terminal'
    #   '';
    # };

    # Настройка пользовательских клавишных комбинаций
    # displayManager.sessionCommands = ''
    #   gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Open Terminal'
    #   gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'kgx'
    #   gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Primary><Alt>T'
    # '';
  };

  # Enable the GNOME Desktop Environment.

  # Configure keymap in X11
  # Enable CUPS to print documents.
  services.printing.enable = true;

  services.lorri.enable = true; # replace default nix-shell

  # Enable sound with pipewire.
  sound.enable = true;
  # pavucontol for settings loop back "Monitor of Alder Lake PCH-P High Definition Audio Controller HDMI / DisplayPort 3 Output"
  hardware.pulseaudio.enable = true;
  # hardware.pulseaudio.extraConfig = "load-module module-loopback"; # module-combine-sink
  security.rtkit.enable = true;
  # services.pipewire = {
  #   enable = true;
  #   alsa.enable = true;
  #   alsa.support32Bit = true;
  #   pulse.enable = true;
  #   # If you want to use JACK applications, uncomment this
  #   #jack.enable = true;
  #
  #   # use the example session manager (no others are packaged yet so this is enabled by default,
  #   # no need to redefine it in your config for now)
  #   #media-session.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # users.extraGroups.docker.members = ["username-with-access-to-socket"];
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${user} = {
    isNormalUser = true;
    description = "${user}";
    extraGroups = ["networkmanager" "wheel" "docker" "podman" "input" "audio"]; #
    # openssh = {
    #   authorizedKeys.keys = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnLD+dQsKPhCV3eY0lMUP4fDrECI1Boe6PbnSHY+eqRpkA/Nd5okdyXvynWETivWsKdDRlT3gIVgEHqEv8s4lzxyZx9G2fAgQVVpBLk18G9wkH0ARJcJ0+RStXLy9mwYl8Bw8J6kl1+t0FE9Aa9RNtqKzpPCNJ1Uzg2VxeNIdUXawh77kIPk/6sKyT/QTNb5ruHBcd9WYyusUcOSavC9rZpfEIFF6ZhXv2FFklAwn4ggWzYzzSLJlMHzsCGmkKmTdwKijkGFR5JQ3UVY64r3SSYw09RY1TYN/vQFqTDw8RoGZVTeJ6Er/F/4xiVBlzMvxtBxkjJA9HLd8djzSKs8yf amnesia@amnesia"];
    # };
    packages = with pkgs; [
      neovim
      fzf
      fd
      lazygit
      gdu
      bottom
      nodejs_18

      obfs4
      vim
      ripgrep
      git
      wget
      htop
      curl
      tmux
      wget
      direnv
      kitty
      gnome.gnome-shell
    ];
  };

  environment.shells = with pkgs; [zsh];
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
  # environment.binsh = "${pkgs.dash}/bin/dash";

  # Enable automatic login for the user.
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "${user}";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
  systemd.tmpfiles.rules = [
    "d /var/lib/bluetooth 700 root root - -"
  ];
  systemd.targets."bluetooth".after = ["systemd-tmpfiles-setup.service"];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    # arion
    # docker-client
    lm_sensors

    # hyprland
    # waybar
    # eww
    # dunst
    # swww
    # kitty
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  programs.ssh.setXAuthLocation = true;
  services.openssh.settings.X11Forwarding = true;

  networking.nat = {
    enable = true;
    internalInterfaces = ["ve-+"];
    externalInterface = "wlp0s20f3";
    # Lazy IPv6 connectivity for the container
    enableIPv6 = true;
  };

  networking.extraHosts = ''
    127.0.0.1 kafka
  '';

  containers.wasabi = {
    # https://nixos.wiki/wiki/NixOS_Containers
    # sudo nixos-container root-login wasabi
    bindMounts = {
      "/home/${user}/.ssh/wireguard-keys" = {
        hostPath = "/home/${user}/.ssh/wireguard-keys";
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
          address = ["10.8.0.12/24"];
          dns = ["1.1.1.1"];
          privateKeyFile = "/home/${user}/.ssh/wireguard-keys/private";

          peers = [
            {
              publicKey = "HiSr0nPcBXkTzYpySK7B0rJwGM0LLXbehwTncBCPYhI=";
              presharedKeyFile = "/home/${user}/.ssh/wireguard-keys/presharedKeyFile";
              allowedIPs = ["0.0.0.0/0"];
              endpoint = "166.1.160.225:51820";
              persistentKeepalive = 0;
            }
          ];
        };
      };

      system.stateVersion = "23.05";

      networking.firewall = {
        # enable = true;
        allowedTCPPorts = [53 80 433 1080 51820];
      };
      # environment.etc."resolv.conf".text = "nameserver 8.8.8.8";
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = "experimental-features = nix-command flakes";
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  virtualisation = {
    podman = {
      enable = true;
      #dockerCompat = true;
      defaultNetwork.settings = {
        dns_enabled = true;
      };
    };
  };

  environment.etc."proxychains.conf".text = ''
    strict_chain
    proxy_dns

    remote_dns_subnet 224

    tcp_read_time_out 15000
    tcp_connect_time_out 8000

    localnet 127.0.0.0/255.0.0.0

    [ProxyList]
    socks5 192.168.100.3 1080
    # socks5 127.0.0.1 8118
    # socks5 127.0.0.1 9063
  '';

  services.privoxy = {
    enable = true;
    enableTor = true;
  };

  services.tor = {
    enable = true;
    client.enable = true;
    client.dns.enable = true;
    settings = {
      # ExitNodes = "{ua}, {nl}, {gb}";
      # ExcludeNodes = "{ru},{by},{kz}";
      UseBridges = true;
      ClientTransportPlugin = "obfs4 exec ${pkgs.obfs4}/bin/obfs4proxy";
      # Bridge = builtins.readFile /home/${user}/.ssh/nix/tor.obfs4.1;
      Bridge = builtins.readFile /home/${user}/.ssh/nix/tor.obfs4.2;
    };
  };

  # programs.hyprland.enable = true;

  # xremap
  # hardware.uinput.enable = true;
  # users.groups.uinput.members = [ "${user}" ];
  # users.groups.input.members = [ "${user}" ];

  # not work
  # services.udev.extraRules = ''
  #   # KERNEL=="event[0-9]*", GROUP="${user}", MODE:="0660"
  # KERNEL=="uinput", GROUP = "${user}", MODE:="0660"
  #   SUBSYSTEM=="input", GROUP="input", MODE="0666"
  # '';

  services.flatpak.enable = true;
}
