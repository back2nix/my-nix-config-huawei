{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  networking.hostName = "asus-ux3405m";

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
    loader.grub.extraFiles = {"ssdt-csc3551.aml" = "${./ssdt-csc3551.aml}";};
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

  # hardware.pulseaudio.enable = false;

  # environment.etc."modprobe.d/alsa-base.conf".text = ''
  #   options snd-hda-intel index=0 model=alc294-asus-zenbook
  #   options snd-hda-intel position_fix=1 bdl_pos_adj=32
  # '';

  # environment.etc."asound.conf".text = ''
  #   defaults.pcm.!card PCH
  #   defaults.pcm.!device 0
  #   defaults.pcm.!ctl PCH
  # '';

  # services.pipewire = {
  #   enable = true;
  #   alsa = {
  #     enable = true;
  #     support32Bit = true;
  #   };
  #   pulse.enable = true;
  #   jack.enable = true;
  #   wireplumber = {
  #     enable = true;
  #     configPackages = [
  #       (pkgs.writeTextDir "share/wireplumber/main.lua.d/51-alsa-custom.lua" ''
  #         rule = {
  #         matches = {
  #         {
  #           { "node.name", "matches", "alsa_output.pci-*" },
  #         },
  #         },
  #         apply_properties = {
  #         ["audio.format"] = "S32LE",
  #         ["audio.rate"] = 48000,
  #         ["api.alsa.period-size"] = 512,
  #         ["api.alsa.periods"] = 4,
  #         ["api.alsa.headroom"] = 1024,
  #         },
  #         }
  #         table.insert(alsa_monitor.rules, rule)
  #       '')
  #     ];
  #   };
  # };

  environment.systemPackages = with pkgs; [
    alsa-utils
    alsa-tools
    alsa-ucm-conf
    pamixer
    pulseaudio  # для некоторых утилит
    asusctl
  ];

    # sudo tlp-stat -b
  services.supergfxd.enable = true;
  services.asusd.enable = true;

  services.thermald.enable = true;

  # services.udev.extraRules = ''
  # # Realtek ALC294
  #   SUBSYSTEM=="sound", ACTION=="change", KERNEL=="card*", ATTRS{id}=="PCH", RUN+="${pkgs.alsa-utils}/bin/alsactl restore"
  #   SUBSYSTEM=="sound", ACTION=="add", KERNEL=="controlC*", ATTRS{id}=="PCH", RUN+="${pkgs.alsa-utils}/bin/alsactl restore"
  # # CS35L41 amp
  #   SUBSYSTEM=="sound", ACTION=="change", KERNEL=="card*", ATTRS{id}=="cs35l41*", RUN+="${pkgs.alsa-utils}/bin/alsactl restore"
  # '';

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/de59dbfa-9be2-44cf-af53-777940bdd226";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/6B62-26C3";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  swapDevices = [{device = "/dev/disk/by-uuid/e2c52285-0430-4b2d-9a09-ce90c536311f";}];

  networking.useDHCP = lib.mkDefault true;
  networking.nat.externalInterface = "wlo1";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {};

  hardware = {
    cpu.intel.updateMicrocode =
      lib.mkDefault config.hardware.enableRedistributableFirmware;
    graphics = {
      enable = true;
      # driSupport = true;
      # driSupport32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        intel-compute-runtime # OpenCL support
        vaapiIntel # LIBVA_DRIVER_NAME=i965
        vaapiVdpau
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
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "powersave";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      };
    };
    hardware.bolt.enable = true;
  };

  services.xserver.displayManager.sessionCommands = ''
    ${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --scale 1.2x1.2
  '';
}
