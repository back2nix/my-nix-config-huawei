{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    # ./powersave.nix
  ];

  nix.settings = {
    substituters = lib.mkAfter [
      "https://cuda-maintainers.cachix.org"
    ];
    trusted-public-keys = lib.mkAfter [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  networking.hostName = "desktop";

  # boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPackages = pkgs.linuxPackages;

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
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  boot.kernelModules = ["nvidia-uvm" "v4l2loopback"];
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];

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

  # --- K3s Agent Configuration (Slave) ---
  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://192.168.3.18:6443";
    token = "K104caae4ecc48a34d39454d4c8b3e4e27577b2a31eb1a5ce0cb15250eb2f7d5dfc::server:3cabe09aba6d084178da21b8b6b8cce6";
  };
}
