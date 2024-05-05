{ config, lib, pkgs, ... }:
# https://github.com/TaiBa131/dotfiles/blob/ec8c98b6fc7e53777e64e2ec1599fee0315f8e5d/users/users.nix

let
  inherit (import ../../variables.nix) mainUser;
  home-manager = import (builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz") { };
in

{
  imports = [ home-manager.nixos ];

  home-manager.users.${mainUser} = import ./bg/home.nix;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # users.extraGroups.docker.members = ["username-with-access-to-socket"];
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${mainUser} = {
    isNormalUser = true;
    description = "${mainUser}";
    extraGroups = [ "networkmanager" "wheel" "docker" "podman" "input" "audio" ]; #
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
      shadowsocks-libev
    ];
  };

  # Enable automatic login for the user.
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "${mainUser}";

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # services.privoxy = {
  #   enable = true;
  #   enableTor = true;
  # };
  #
  # services.tor = {
  #   enable = true;
  #   client.enable = true;
  #   client.dns.enable = true;
  #   settings = {
  #     # ExitNodes = "{ua}, {nl}, {gb}";
  #     # ExcludeNodes = "{ru},{by},{kz}";
  #     UseBridges = true;
  #     ClientTransportPlugin = "obfs4 exec ${pkgs.obfs4}/bin/obfs4proxy";
  #     # Bridge = builtins.readFile /home/${user}/.ssh/nix/tor.obfs4.1;
  #     Bridge = builtins.readFile /home/${user}/.ssh/nix/tor.obfs4.2;
  #   };
  # };

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
}
