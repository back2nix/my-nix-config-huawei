{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "desktop";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # --- CUDA and NVIDIA Configuration ---
  # Опции `opengl` были переименованы в `graphics`
  hardware.graphics = {
    enable = true;
    # Явно добавляем 32-битные библиотеки NVIDIA для совместимости
  };

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  boot.kernelModules = ["nvidia-uvm"];

  # --- Virtualisation with NVIDIA support (Manual Configuration) ---
  # Мы настраиваем это вручную, чтобы обойти ошибку в nixos-25.05,
  # где `enableNvidia` содержит сломанную проверку.
  hardware.nvidia-container-toolkit.enable = true;

  # Для Docker: вручную определяем рантайм NVIDIA
  virtualisation.docker.daemon.settings.runtimes = {
    nvidia = {
      path = "${config.hardware.nvidia-container-toolkit.package}/bin/nvidia-container-runtime";
    };
  };

  # Примечание: опции `virtualisation.docker.enableNvidia` и `virtualisation.podman.enableNvidia`
  # были удалены, чтобы избежать сломанной проверки.
  # Для Podman достаточно включения `nvidia-container-toolkit`.

  # --- Desktop-specific packages ---
  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    #nvtop # Исправлено имя пакета
  ];
}
