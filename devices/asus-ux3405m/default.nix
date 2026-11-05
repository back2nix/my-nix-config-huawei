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
    # Admin-VPN до casino-VPS, как на yoga14, но свой пир: 10.100.0.7,
    # ключ wireguard/eggventure_asus_private (сервер: casino-vps/modules/wireguard.nix).
    # Через него же ходит sing-box (socks-nix: ssh на 10.100.0.1).
    ../../module/wireguard-eggventure.nix
  ];

  my.eggventureVpn = {
    address = "10.100.0.7";
    secret = "wireguard/eggventure_asus_private";
  };

  my.personalVpn.address = "10.101.0.9";

  networking.hostName = "asus-ux3405m";

  # Чтобы попробовать COSMIC вместо GNOME, раскомментировать (см. module/display/default.nix).
  # my.display.desktop = "cosmic";

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;

    kernelParams = [
      "i915.force_probe=7d55"
      "snd-intel-dspcfg.dsp_driver=3"
      # "snd_hda_intel.single_cmd=1"
      # "snd_hda_intel.probe_mask=1"
      # "snd_hda_intel.dmic_detect=0"

      "systemd.unified_cgroup_hierarchy=1"
      "cgroup_enable=cpuset"
      "cgroup_enable=memory"
      "cgroup_memory=1"
    ];
    extraModprobeConfig = ''
      options snd-hda-intel model=alc294-asus-zenbook power_save=0 position_fix=1 enable_msi=1
      options snd-hda-intel index=0 model=alc294-asus-zenbook
      options snd-hda-intel index=1 model=auto
    '';
    loader.grub.extraFiles = {
      "ssdt-csc3551.aml" = "${./ssdt-csc3551.aml}";
    };
    loader.grub.extraConfig = ''
      acpi /ssdt-csc3551.aml
    '';
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "thunderbolt"
      "vmd"
      "usb_storage"
      "nvme"
      "rtsx_usb_sdmmc"
      "uas"
      "sd_mod"
    ];
    initrd.kernelModules = [
      # "snd_hda_intel"
      # "snd_hda_codec"
      # "snd_hda_codec_generic"
      # "snd_hda_codec_realtek"
      # "snd_hda_codec_hdmi"
    ];
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];
  };

  hardware.enableAllFirmware = true;

  environment.systemPackages = with pkgs; [
    alsa-utils
    alsa-tools
    alsa-ucm-conf
    pamixer
    pulseaudio # для некоторых утилит
    asusctl
  ];

  # sudo tlp-stat -b
  services.supergfxd.enable = true;
  services.asusd.enable = true;

  services.thermald.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/de59dbfa-9be2-44cf-af53-777940bdd226";
    fsType = "ext4";
  };

  # Корень зашифрован in-place (docs/LUKS-MIGRATION.md); ext4 UUID внутри не изменился.
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/3fc531bf-5b47-4f32-95d9-322a6957beff";
    allowDiscards = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/6B62-26C3";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  # Swap шифруется случайным ключом при каждой загрузке (без гибернации).
  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/457656af-841c-42d8-addf-d932b0e123e1";
      randomEncryption.enable = true;
    }
  ];

  networking.useDHCP = lib.mkDefault true;
  networking.nat.externalInterface = "wlo1";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    # Добавление специальной конфигурации Bluetooth для Wireplumber
    wireplumber.extraConfig."10-bluez" = {
      "monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;
        "bluez5.headset-roles" = [
          "hsp_hs"
          "hsp_ag"
          "hfp_hf"
          "hfp_ag"
        ];
        "bluez5.codecs" = [
          "sbc_xq"
          "aac"
          "ldac"
        ];
      };
    };
  };

  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    graphics = {
      enable = true;
      # driSupport = true;
      # driSupport32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        intel-compute-runtime # OpenCL support
        intel-vaapi-driver # LIBVA_DRIVER_NAME=i965
        libva-vdpau-driver
        libvdpau-va-gl
      ];
    };
  };

  environment.variables = {
    LIBVA_DRIVER_NAME = "iHD";
    MOZ_DISABLE_RDD_SANDBOX = "1"; # Может помочь с некоторыми проблемами рендеринга
  };

  services = {
    fstrim.enable = true;
    # tlp = {
    #   enable = true;
    #   settings = {
    #     CPU_SCALING_GOVERNOR_ON_AC = "powersave";
    #     CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    #   };
    # };
    hardware.bolt.enable = true;
  };

  services.xserver.displayManager.sessionCommands = ''
    ${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --scale 1.2x1.2
  '';
}
