{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    # ./powersave.nix
    ./power-profiles.nix
    # Admin-VPN до casino-VPS, как на yoga14, но свой пир: 10.100.0.5,
    # ключ wireguard/eggventure_desktop_private (сервер: casino-vps/modules/wireguard.nix).
    ../../module/wireguard-eggventure.nix
  ];

  my.eggventureVpn = {
    address = "10.100.0.5";
    secret = "wireguard/eggventure_desktop_private";
  };

  nix.settings = {
    substituters = lib.mkAfter [
      "https://cache.nixos-cuda.org"
    ];
    trusted-public-keys = lib.mkAfter [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

  networking.hostName = "desktop";

  # boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # --- CUDA and NVIDIA Configuration ---
  hardware.graphics = {
    enable = true;
  };

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    # 595.71.05 из nixpkgs не собирается под ядро 7.2 (там удалён strncpy),
    # см. https://github.com/NixOS/nixpkgs/issues/554125 — вернуть .stable, когда обновят
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "595.99.02";
      sha256_64bit = "sha256-6HR3lYv3YwcFSTJL1a1slI66btIQ5EAFs+/4SUD24ew=";
      openSha256 = "sha256-T36x/jx8yQ8l3LFp1rZIrTfcSwbGy8YSAvXOUSptpb4=";
      settingsSha256 = "sha256-GYCcnxfKPrTCrsmd25sMyzfC5cqJQJx0c31haooyTYM=";
      persistencedSha256 = "sha256-VyKtF/HdHPQrHHK6opSO69M72LmnGZtauuchj9uuje8=";
    };
  };

  boot.kernelModules = ["nvidia-uvm" "v4l2loopback"];
  boot.extraModulePackages = [config.boot.kernelPackages.v4l2loopback];

  # --- Virtualisation with NVIDIA support ---
  hardware.nvidia-container-toolkit.enable = true;

  virtualisation.docker.daemon.settings.runtimes = {
    nvidia = {
      path = "${config.hardware.nvidia-container-toolkit.package}/bin/nvidia-container-runtime";
    };
  };

  # --- Desktop-specific packages ---
  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
  ];

  # --- K3s standalone server ---
  services.k3s = {
    enable = true;
    role = "server";
  };
}
