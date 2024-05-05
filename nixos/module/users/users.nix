{ config, lib, pkgs, ... }:
# https://github.com/TaiBa131/dotfiles/blob/ec8c98b6fc7e53777e64e2ec1599fee0315f8e5d/users/users.nix

let
  inherit (import ../variables.nix) mainUser;
  home-manager = import (builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz") { };
in

{
  imports = [ home-manager.nixos ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  #Iheb
  # users.users.${mainUser} = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" "networkmanager" "input" "video" ];
  #   shell = pkgs.zsh;
  # };
  home-manager.users.${mainUser} = import ./bg/home.nix;
}
