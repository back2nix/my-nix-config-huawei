{
  inputs,
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: let
  inherit (import ../../variables.nix) mainUser;
in {
  users.users.root = {
    shell = pkgs.fish;
  };

  home-manager.backupFileExtension = "backup-$(date +%Y%m%d-%H%M%S)";

  home-manager.users.root = {...}: {
    imports = [
      ./bg/zsh/zsh.nix
      ./bg/fish/fish.nix
      ./bg/nixvim.nix
    ];
    home = {
      stateVersion = "23.11"; # используйте ту же версию, что и в вашем home.nix
      username = "root";
      homeDirectory = "/root";
    };
  };

  users.users.${mainUser} = {
    initialPassword = "1";
    isNormalUser = true;
    description = "${mainUser}";
    extraGroups = [
      "lp"
      "networkmanager"
      "wheel"
      "docker"
      "podman"
      "input"
      "audio"
      "${mainUser}-with-access-to-socket"
      "wireshark"
      "kvm"
      "tss"
      "openvpn"
      "libvirtd"
      "kvm"
      "podman"
      "qemu-libvirtd"
    ];
    openssh = {
      authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/Pm3dni/sg8gvQrO8nZGCYLxlPMwO3RfY92msE3zICVyu0ycCUIiRB1KW4JSOdkwglt2wbrhQcb1FdUKAnNNybp78abA8NXUcM5oSDrq4ZVyKTm/qKENpLg7ajni8BXwV3fr0p55nKc+sfl1/Pqcl0X8yHXm4Nr18z9kwy70yS4+F+6rHaVnOfcE+/2ms8q0eG/hxYuTqt47BMfaD5UqFB0MfS7147GqnHfJfzuUn0TMueFvE9V/zZS/0Ner/Pi/5iz+g8AASRkZQvNhCjWXOqCOSqhkrvo3a9M5V03+1CJ4tefhdHt/HvrHbUaxb6HkD8vqbU6P6p01BrzB6F4awq9VeJ9SfrEEZaLWbtg1nn0NBjdNlMaimaP7uSF2HL4K+V4qbfFV58SXbs1EyHwH0nsWVrgtmPK7KrAUgWyBG2AnGAkrTvUEb465KVNa4YQp9FKD8uy3kkpXIzdumXhWLwKayssEPri2kg36uTFkEjq8jTIeltjyueTK8KuSFfAJ//emBqrZC1FKnwXR+uQ1FB7dfUDKCkhXUpdBLHT1DOrkofMoOFDETP9gJghTza+sfEMU/lQSOnMBsn5aAGKs+62EsM2kTfq0JRicPOyX7m5TlH6Rv7qWSYYy0or7CqVf/rZqS0NC6KILWDo9H3T3ZZ7/EHGrAsHnzhjbFsD+PhQ== bg@nixos"
      ];
    };
    packages = with pkgs; [
      fzf
      fd
      lazygit
      gdu
      bottom
      nodejs_20

      obfs4
      vim
      ripgrep
      git
      wget
      htop
      curl
      tmux
      wget
      kitty
      gnome-shell
      shadowsocks-libev
    ];
  };

  # services = {
  #   displayManager.autoLogin.enable = true;
  #   displayManager.autoLogin.user = "${mainUser}";
  # };
}
