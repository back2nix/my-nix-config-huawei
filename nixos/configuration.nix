# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{ config
, pkgs
, ...
}:
let
in
{
  imports = [
    # Include the results of the hardware scan.
    #<home-manager/nixos>
    ./hardware-configuration.nix
    ./cachix.nix
    # ./module/wordpress.nix
    "/etc/nixos/module/shadowsocks.nix"
    "/etc/nixos/module/vpn/vpn.nix"
    ./module/users/users.nix
    ./module/change.mac.nix
  ];

  services.change-mac = {
    enable = false;
    interface = "wlp0s20f3";
    macAddress = "00:11:22:33:44:55";
  };

  boot.loader.systemd-boot.enable = true;

  boot.supportedFilesystems = [ "ntfs" ];



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

  programs.gnupg.agent.pinentryFlavor = "gnome3";
  programs.dconf.enable = true;


  # Enable the X11 windowing system.
  services = {
    dbus.packages = [ pkgs.dconf ];
    udev.packages = [ pkgs.gnome3.gnome-settings-daemon ];
    xserver = {
      # gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Alt>Shift_L']"
      # gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
      # gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Open Terminal'
      # gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'kgx'
      # gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'kitty'
      # gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Primary><Alt>T'
      enable = true;
      videoDrivers = [ "modesetting" ];
      layout = "us,ru";
      # xkbVariant = "workman,";
      #xkbOptions = "grp:win_space_toggle";
      # xkbOptions = "grp:ctrl_shift_toggle";
      displayManager.gdm.enable = true;
      displayManager.gdm.wayland = false;
      # desktopManager.gnome.enable = true;
      desktopManager.gnome.enable = true;
      libinput.enable = true;

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
  };

  # Enable the GNOME Desktop Environment.

  # Configure keymap in X11
  # Enable CUPS to print documents.
  services.printing.enable = true;


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

  # nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # sudo ss-local -v -c ./shadowsocks.json
  # sudo ss-local -v -c /etc/shadowsocks-libev/config.json
  # services.shadowsocks = {
  #   enable = true;
  # mode = "tcp_and_udp";
  # port = 8388;
  # passwordFile = "/home/bg/Documents/code/store/ssh/shadowsocks";
  # localAddress = 1080;
  # encryptionMethod = "chacha20-ietf-poly1305";
  # timeout = 60;
  # pluginOpts = "server;host=80.209.243.215";
  # extraConfig = ''{
  #     "server":["::1", "80.209.243.215"],
  #     "mode":"tcp_and_udp",
  #     "server_port":8388,
  #     "local_port":1080,
  #     "password":"",
  #     "timeout":60,
  #     "method":"chacha20-ietf-poly1305"
  #   }'';
  # };

  environment.shells = with pkgs; [ zsh ];
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
  # environment.binsh = "${pkgs.dash}/bin/dash";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
  systemd.tmpfiles.rules = [
    "d /var/lib/bluetooth 700 root root - -"
    # "d /var/lib/wordpress/localhost 0750 wordpress wwwrun - -"
    # "d /var/lib/wordpress/localhost/wp-content 0750 wordpress wwwrun - -"
    # "d /var/lib/wordpress/localhost/wp-content/plugins 0750 wordpress wwwrun - -"
    # "d /var/lib/wordpress/localhost/wp-content/themes 0750 wordpress wwwrun - -"
    # "d /var/lib/wordpress/localhost/wp-content/upgrade 0750 wordpress wwwrun - -"
  ];
  systemd.targets."bluetooth".after = [ "systemd-tmpfiles-setup.service" ];

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
    virtualbox
    direnv
    tcpdump

    # hyprland
    # waybar
    # eww
    # dunst
    # swww
    # kitty
  ];


  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  programs.ssh.setXAuthLocation = true;
  services.openssh.settings.X11Forwarding = true;

  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-+" ];
    externalInterface = "wlp0s20f3";
    # Lazy IPv6 connectivity for the container
    enableIPv6 = true;
  };

  networking.extraHosts = ''
    127.0.0.1 kafka
  '';

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
    # ssh -L 0.0.0.0:1081:localhost:1080 bg@localhost -N
    # socks5 192.168.0.5 1081
    socks5 127.0.0.1 1080
    # socks5 192.168.100.3 1080
    # socks5 127.0.0.1 8118
    # socks5 127.0.0.1 9063
  '';


  # programs.hyprland.enable = true;

  services.flatpak.enable = true;
  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
  services.blueman.enable = true;

  hardware.bluetooth.settings = {
    General = {
      Enable = "Source,Sink,Media,Socket";
      Experimental = true;
    };
  };

  # hardware.pulseaudio.configFile = pkgs.writeText "default.pa" ''
  #       load-module module-bluetooth-policy
  #       load-module module-bluetooth-discover
  #   ## module fails to load with
  #   ##   module-bluez5-device.c: Failed to get device path from module arguments
  #   ##   module.c: Failed to load module "module-bluez5-device" (argument: ""): initialization failed.
  #   # load-module module-bluez5-device
  #   # load-module module-bluez5-discover
  # '';
  #
  # hardware.pulseaudio.extraConfig = "
  #   load-module module-switch-on-connect
  # ";

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

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  programs.nix-ld.enable = true;
  nix.settings.trusted-users = [ "root" "bg" ];

  boot.tmpOnTmpfs = true;
  boot.tmpOnTmpfsSize = "25%";

  services.logind.extraConfig = ''
    RuntimeDirectorySize=16G
  '';
  # services.logind.extraConfig = "RuntimeDirectorySize=50%";

  virtualisation.virtualbox.host.enable = true;

  networking = {
    hostName = "nixos"; # Define your hostname.
  };
}
