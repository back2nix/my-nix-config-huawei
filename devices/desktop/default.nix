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
      "https://cache.nixos-cuda.org"
    ];
    trusted-public-keys = lib.mkAfter [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
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

  # --- K3s standalone server ---
  services.k3s = {
    enable = true;
    role = "server";
  };
}
