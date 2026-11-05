{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # Личный VPN до Windows и других машин bg (10.101.0.0/24).
    ../../module/wireguard-personal-peer.nix
    # Admin-VPN до casino-VPS, как на yoga14, но свой пир: 10.100.0.6,
    # ключ wireguard/eggventure_huawei_private (сервер: casino-vps/modules/wireguard.nix).
    # Через него же ходит sing-box (socks-nix: ssh на 10.100.0.1).
    ../../module/wireguard-eggventure.nix
  ];

  my.eggventureVpn = {
    address = "10.100.0.6";
    secret = "wireguard/eggventure_huawei_private";
  };

  my.personalVpn.address = "10.101.0.7";

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

  # Корень зашифрован in-place (docs/LUKS-MIGRATION.md); ext4 UUID внутри не изменился.
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/147792bf-43b0-4af3-bc2a-ece050eb5fc7";
    allowDiscards = true;
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
  # Swap шифруется случайным ключом при каждой загрузке (без гибернации).
  swapDevices = lib.mkForce [
    {
      device = "/dev/disk/by-partuuid/4e0ce2bb-1893-4cf1-8303-5c7e6d846dc5";
      randomEncryption.enable = true;
    }
  ];

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
