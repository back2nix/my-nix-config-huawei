# WARN: this file will get overwritten by $ cachix use <name>
{
  pkgs,
  lib,
  ...
}: let
  folder = ./cachix;
  toImport = name: value: folder + ("/" + name);
  filterCaches = key: value: value == "regular" && lib.hasSuffix ".nix" key;
  imports = lib.mapAttrsToList toImport (lib.filterAttrs filterCaches (builtins.readDir folder));
in {
  inherit imports;
  nix.settings = {
    substituters = [
      "https://cache.garnix.io/"
      "https://cache.nixos.org/"
      # "https://cache.flox.dev"
      "https://robotnix.cachix.org"
      "https://nix-community.cachix.org"

      "https://nixpkgs-wayland.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
      "https://cache.nixos-cuda.org"
      "http://127.0.0.1:8080/system"
    ];

    trusted-substituters = [
      "cache.nixos.org"
      "nix-community.cachix.org"
      "http://127.0.0.1:8080/system"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      # "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "system:Pq0rLW2CHR7DK6bnqoNlpfbjVf6AA1rCbBgf3zaPiCE="
    ];
  };

  systemd.services.nix-daemon.serviceConfig = {
    # socks5h означает, что DNS-запросы также будут идти через прокси (рекомендуется)
    # Если нужно резолвить DNS локально, используйте просто socks5
    Environment = [
      "http_proxy=http://127.0.0.1:1083"
      "https_proxy=http://127.0.0.1:1083"
      "ALL_PROXY=http://127.0.0.1:1083"
    ];
  };
}
