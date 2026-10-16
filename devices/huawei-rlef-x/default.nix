{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  networking.hostName = "huawei-rlef-x";

  boot = {
    # Свежее ядро — важно для нового Intel xe-iGPU (как на asus/yoga14).
    kernelPackages = pkgs.linuxPackages_latest;

    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    initrd.kernelModules = [];
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];
    # Fix for system freezes during high network load (SSH sync) and audio latency
    kernelParams = [
      "intel_pstate=active"
      "processor.max_cstate=3"
      "intel_idle.max_cstate=3"
    ];
    extraModprobeConfig = ''
      options iwlwifi power_save=0
      options iwlmvm power_scheme=1
    '';
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/eb9ec726-ac0f-489a-b1b9-9fb690338bd5";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/2E62-5274";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  # Только swap-раздел. mkForce отменяет 16 GB swapfile из общего
  # configuration.nix — иначе на huawei было бы двойное перекрытие свопа.
  swapDevices = lib.mkForce [{device = "/dev/disk/by-uuid/61e8160b-42b0-428f-8aef-1b993654838d";}];

  # zram — быстрый сжатый своп в RAM для отзывчивости (как у yoga14).
  zramSwap.enable = true;

  networking.useDHCP = lib.mkDefault true;
  networking.nat.externalInterface = "wlo1";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    graphics = {
      enable = true;
      # driSupport = true;
      # driSupport32Bit = true;
      # VAAPI-драйверы для аппаратного декодирования видео. Здесь, а не в
      # environment.systemPackages — иначе libva их не подхватывает и декод
      # идёт на CPU (лишний нагрев и разряд батареи).
      extraPackages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
        libva-vdpau-driver
        libvdpau-va-gl
        mesa
        libva
        libva-utils
      ];
    };
  };

  # Указываем libva использовать современный iHD-драйвер (intel-media-driver).
  environment.variables.LIBVA_DRIVER_NAME = "iHD";

  # thermald — управление троттлингом для Intel (asus/yoga14 уже включают).
  services.thermald.enable = true;

  services = {
    fstrim.enable = true;
    # GNOME тянет power-profiles-daemon, который конфликтует с tlp.
    power-profiles-daemon.enable = false;
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "powersave";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        # Disable WiFi power saving to prevent freezes
        WIFI_PWR_ON_AC = "off";
        WIFI_PWR_ON_BAT = "off";
        # Runtime PM can cause issues with some devices
        RUNTIME_PM_ON_AC = "on";
        RUNTIME_PM_ON_BAT = "auto";
      };
    };
  };

  # Здесь можно добавить дополнительные специфические настройки для Huawei RLef-X,
  # если они потребуются в будущем
}
