{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
  (modulesPath + "/installer/scan/not-detected.nix")
  ./hardware-configuration.nix
  # ./fix-bluetooth.nix
  ];

  networking.hostName = "yoga14";

  boot = {
    # Используем последнее стабильное ядро для лучшей поддержки оборудования
    kernelPackages = pkgs.linuxPackages_latest;

    # Базовые модули ядра для поддержки тачскрина и bluetooth
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
    ];

    initrd.kernelModules = [
      "hid_multitouch"
      "wacom"
      "i2c_hid"
      "i2c_hid_acpi"
      "hid_sensor_hub"
    ];

    extraModulePackages = [];

    # Параметры ядра для улучшения поддержки оборудования
    kernelParams = [
      "systemd.unified_cgroup_hierarchy=1"
      "cgroup_enable=cpuset"
      "cgroup_enable=memory"
      "cgroup_memory=1"
      "i915.force_probe=7d55"
      "i915.enable_guc=2"  # для лучшей работы Intel GPU
    ];

    # Настройка модуля btusb для Intel Bluetooth
    extraModprobeConfig = ''
      options btusb reset=1 enable_autosuspend=0
      options bluetooth disable_ertm=1
    '';
  };

  # Добавляем правила udev для Bluetooth Intel (8087:0037)
  services.udev.extraRules = ''
    # Правила для Wacom тачскрина
    ACTION=="add|change", KERNEL=="event*", ATTRS{name}=="Wacom HID 53FD Finger", ENV{LIBINPUT_CALIBRATION_MATRIX}="1 0 0 0 1 0"
    ACTION=="add|change", KERNEL=="event*", ATTRS{name}=="Wacom HID 53FD Pen", ENV{LIBINPUT_CALIBRATION_MATRIX}="1 0 0 0 1 0"


    SUBSYSTEM=="iio", ACTION=="add", ATTR{name}=="accel_3d", TAG+="systemd", ENV{SYSTEMD_WANTS}="iio-sensor-proxy.service"
    # Правила для Intel Bluetooth
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="8087", ATTRS{idProduct}=="0037", TAG+="systemd", ENV{SYSTEMD_WANTS}="bluetooth.service"
    # Сброс Bluetooth адаптера при загрузке
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="8087", ATTRS{idProduct}=="0037", RUN+="${pkgs.bluez}/bin/bluetoothctl power on"
    ACTION=="add", SUBSYSTEM=="video4linux", ATTR{name}=="*Camera*", TAG+="systemd", ENV{SYSTEMD_WANTS}="howdy.service"
  '';

  # Явно настраиваем службу Bluetooth
  systemd.services.bluetooth = {
    serviceConfig = {
      ExecStart = ["" "${pkgs.bluez}/libexec/bluetooth/bluetoothd -f /etc/bluetooth/main.conf"];
      ExecStartPost = "${pkgs.bash}/bin/bash -c 'sleep 2 && ${pkgs.bluez}/bin/bluetoothctl power on'";
      RestartSec = "5";
      Restart = "on-failure";
    };
    wantedBy = [ "bluetooth.target" ];
  };

  # Убеждаемся, что директория Bluetooth существует и имеет правильные права
  systemd.tmpfiles.rules = [
    "d /var/lib/bluetooth 0755 root root - -"
  ];

  # Конфигурация для тачскрина и тачпада
  services.xserver = {
    enable = true;
    videoDrivers = ["modesetting"];

    # Включаем поддержку Wacom
    wacom.enable = true;

    # Включаем поддержку libinput
    libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = true;
        tapping = true;
        tappingDragLock = false;
        middleEmulation = true;
        disableWhileTyping = true;
      };
    };

    # Конфигурация для устройств ввода
    inputClassSections = [
      # Настройка для сенсорного экрана (Wacom HID 53FD Finger)
      ''
        Identifier "Wacom Touchscreen"
        MatchProduct "Wacom HID 53FD Finger"
        MatchDevicePath "/dev/input/event*"
        Driver "wacom"
        Option "Touch" "on"
      ''

      # Настройка для пера (Wacom HID 53FD Pen)
      ''
        Identifier "Wacom Pen"
        MatchProduct "Wacom HID 53FD Pen"
        MatchDevicePath "/dev/input/event*"
        Driver "wacom"
      ''
    ];
  };

  # Дополнительные настройки для корректного определения поворота экрана
  hardware.sensor.iio.enable = true;  # Включаем поддержку IIO сенсоров

  # Автоматический поворот экрана
  services.autorandr.enable = true;

  # Включаем прошивки, включая Intel Bluetooth
  hardware.enableAllFirmware = true;

  hardware.opengl = {
    enable = true;
    # driSupport = true;
    driSupport32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
      intel-compute-runtime  # OpenCL поддержка для Intel
    ];
  };

  # Настройка Bluetooth
  # hardware.bluetooth = {
  #   enable = true;
  #   powerOnBoot = true;
  #   package = pkgs.bluez;
  #   settings = {
  #     General = {
  #       Name = "Yoga14";
  #       ControllerMode = "dual";
  #       FastConnectable = "true";
  #       Experimental = "true";
  #       Enable = "Source,Sink,Media,Socket";
  #       MultiProfile = "multiple";
  #       AutoEnable = "true";
  #     };
  #     Policy = {
  #       AutoEnable = "true";
  #     };
  #   };
  # };

  # Убеждаемся, что blueman запущен для удобного управления Bluetooth
  services.blueman.enable = true;

  environment.systemPackages = with pkgs; [
    alsa-utils
    alsa-tools
    alsa-ucm-conf
    pamixer
    pulseaudio  # для некоторых утилит
    xf86_input_wacom     # Драйвер Wacom для X11
    libinput             # Библиотека для обработки ввода
    xorg.xinput          # Утилиты для настройки устройств ввода
    xorg.xf86inputlibinput  # Драйвер libinput для X11

    # Инструменты для Bluetooth
    bluez
    bluez-tools
    blueman

    # Инструменты для диагностики
    usbutils  # lsusb
    pciutils  # lspci
    lshw      # подробная информация об оборудовании

    v4l-utils  # для настройки камеры
  ];

  networking.useDHCP = lib.mkDefault true;
  # Замените на имя вашего интерфейса WiFi после определения
  networking.nat.externalInterface = "wlp0s20f3";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;


  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;

    # Настройка Bluetooth аудио через wireplumber вместо media-session
    # Вместо прямой конфигурации wireplumber, используем его конфигурационные файлы
  };

  # Добавляем конфигурацию wireplumber для Bluetooth
  environment.etc."wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
    bluez_monitor.properties = {
      ["bluez5.enable-sbc-xq"] = true,
      ["bluez5.enable-msbc"] = true,
      ["bluez5.enable-hw-volume"] = true,
      ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
    }

    bluez_monitor.rules = {
      -- Auto-connect device profiles on start up or when only partial
      -- routing is available. Disabled by default if the property
      -- device.autoconnect is false.
      {
        matches = {
          {
            -- Matches all cards
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
            -- Matches all bluetooth sinks
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
            -- Matches all bluetooth sources
            { "node.name", "matches", "bluez_output.*" },
          },
        },
        apply_properties = {
          ["node.pause-on-idle"] = false,
        },
      },
    }
  '';

  hardware = {
    cpu.intel.updateMicrocode =
      lib.mkDefault config.hardware.enableRedistributableFirmware;
    graphics = {
      enable = true;
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

  services.xserver.displayManager.sessionCommands = ''
    ${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --scale 1.2x1.2
  '';
}
