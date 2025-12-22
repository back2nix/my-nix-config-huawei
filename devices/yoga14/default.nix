{
  config,
  inputs,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-yoga-7-14ILL10

    (modulesPath + "/installer/scan/not-detected.nix")
    ./hardware-configuration.nix
  ];

  networking.hostName = "yoga14";

  boot = {
    # kernelPackages = pkgs.linuxPackages_zen;
    kernelPackages = pkgs.linuxPackages_latest;

    kernelModules = [
      "kvm-intel"
      "hid_multitouch"
      "wacom"
      "i2c_hid"
      "i2c_hid_acpi"
      "hid_sensor_hub"
      "bluetooth"
      "btusb"
      "btintel"
      "tun"
      "tap"
    ];

    initrd.kernelModules = [
      "hid_multitouch"
      "wacom"
      "i2c_hid"
      "i2c_hid_acpi"
      "hid_sensor_hub"
    ];

    extraModulePackages = [];

    # ПРАВИЛЬНЫЕ параметры ядра для Lunar Lake
    kernelParams = [
      "systemd.unified_cgroup_hierarchy=1"
      "cgroup_enable=cpuset"
      "cgroup_enable=memory"
      "cgroup_memory=1"
      # Lunar Lake специфичные параметры
      "intel_pstate=active"
      "intel_iommu=on"
      "iommu=pt"
    ];

    extraModprobeConfig = ''
      # Bluetooth настройки
      options btusb reset=1 enable_autosuspend=0
      options bluetooth disable_ertm=1

      # ИСПРАВЛЕНИЯ ДЛЯ INTEL AX211 WIFI
      options iwlwifi power_save=0 disable_11ax=0 disable_11ac=0 11n_disable=0
      options iwlmvm power_scheme=1
      options iwlwifi swcrypto=0 led_mode=1
    '';
  };

  # ПРАВИЛЬНАЯ настройка Intel GPU для Lunar Lake
  hardware.intelgpu = {
    driver = "xe"; # Используем xe драйвер для Lunar Lake
    vaapiDriver = "intel-media-driver";
  };

  # Включаем графику
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # VA-API драйвер для видео
      intel-vaapi-driver
      libva-vdpau-driver
      libvdpau-va-gl
      intel-compute-runtime # OpenCL драйвер
      mesa
      libva
      libva-utils
    ];
  };

  # Переменные среды для стабильной работы графики
  environment.variables = {
    LIBVA_DRIVER_NAME = "iHD";
    MOZ_DISABLE_RDD_SANDBOX = "1";
    MOZ_X11_EGL = "1";
  };

  services.udev.extraRules = ''
    # Предотвращение автосуспенда Intel AX211
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="8087", ATTRS{idProduct}=="0033", ATTR{power/autosuspend}="-1"

    # Отключение power management после подключения
    ACTION=="add", SUBSYSTEM=="ieee80211", KERNEL=="phy*", RUN+="${pkgs.bash}/bin/bash -c 'sleep 2 && ${pkgs.iw}/bin/iw dev wlp0s20f3 set power_save off'"

    # Правила для Intel Bluetooth
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="8087", ATTRS{idProduct}=="0037", TAG+="systemd", ENV{SYSTEMD_WANTS}="bluetooth.service"
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="8087", ATTRS{idProduct}=="0037", RUN+="${pkgs.bluez}/bin/bluetoothctl power on"

    # Камера
    ACTION=="add", SUBSYSTEM=="video4linux", ATTR{name}=="*Camera*", TAG+="systemd", ENV{SYSTEMD_WANTS}="howdy.service"

    ACTION=="add", SUBSYSTEM=="backlight", ATTR{brightness}="73"

    SUBSYSTEM=="net", KERNEL=="tun", GROUP="kvm", MODE="0660"
  '';

  systemd.services.iwlwifi-reload = {
    description = "Reload iwlwifi module after suspend";
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.bash}/bin/bash -c '${pkgs.kmod}/bin/rmmod iwlmvm iwlwifi || true'";
      ExecStart = "${pkgs.bash}/bin/bash -c 'sleep 3 && ${pkgs.kmod}/bin/modprobe iwlwifi'";
      ExecStartPost = "${pkgs.bash}/bin/bash -c 'sleep 2 && ${pkgs.iw}/bin/iw dev wlp0s20f3 set power_save off || true'";
      RemainAfterExit = true;
    };
  };

  # Bluetooth конфигурация для Yoga14
  systemd.services.bluetooth = {
    serviceConfig = {
      ExecStart = [
        ""
        "${pkgs.bluez}/libexec/bluetooth/bluetoothd -f /etc/bluetooth/main.conf"
      ];
      ExecStartPost = "${pkgs.bash}/bin/bash -c 'sleep 2 && ${pkgs.bluez}/bin/bluetoothctl power on'";
      RestartSec = "5";
      Restart = "on-failure";
    };
    wantedBy = ["bluetooth.target"];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/bluetooth 0755 root root - -"
  ];

  # Включаем поддержку IIO сенсоров для автоповорота
  hardware.sensor.iio.enable = true;
  services.autorandr.enable = true;
  hardware.enableAllFirmware = true;

  # Диагностические пакеты для Yoga14
  environment.systemPackages = with pkgs; [
    alsa-utils
    alsa-tools
    alsa-ucm-conf
    pamixer
    pulseaudio
    bluez
    bluez-tools
    blueman
    usbutils
    pciutils
    lshw
    v4l-utils
    iwd # ВАЖНО: для лучшей работы с Intel AX211
    nvtopPackages.intel
    mesa-demos
    vulkan-tools
    intel-gpu-tools
  ];

  networking.useDHCP = lib.mkDefault true;
  networking.nat.externalInterface = "wlp0s20f3";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Audio конфигурация
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # Bluetooth audio конфигурация для wireplumber
  environment.etc."wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
    bluez_monitor.properties = {
      ["bluez5.enable-sbc-xq"] = true,
      ["bluez5.enable-msbc"] = true,
      ["bluez5.enable-hw-volume"] = true,
      ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
    }

    bluez_monitor.rules = {
      {
        matches = {
          {
            { "device.name", "matches", "bluez_card.*" },
          },
        },
        apply_properties = {
          ["bluez5.reconnect-profiles"] = "[ hfp_hf hsp_hs a2dp_sink ]",
          ["bluez5.msbc-support"] = true,
          ["bluez5.sbc-xq-support"] = true,
        },
      },
      {
        matches = {
          {
            { "node.name", "matches", "bluez_input.*" },
          },
        },
        apply_properties = {
          ["node.pause-on-idle"] = false,
        },
      },
      {
        matches = {
          {
            { "node.name", "matches", "bluez_output.*" },
          },
        },
        apply_properties = {
          ["node.pause-on-idle"] = false,
        },
      },
    }
  '';

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
