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
  ];

  networking.hostName = "yoga14";

  boot = {
    # Используем последнее стабильное ядро для лучшей поддержки оборудования
    kernelPackages = pkgs.linuxPackages_latest;

    # Базовые модули ядра для поддержки тачскрина
    kernelModules = [
      "kvm-intel"
      "hid_multitouch"
      "wacom"
      "i2c_hid"
      "i2c_hid_acpi"
      "hid_sensor_hub"
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
    ];
  };

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

  # Настройка udev правил для Wacom устройств
  services.udev.extraRules = ''
    # Правила для Wacom тачскрина
    ACTION=="add|change", KERNEL=="event*", ATTRS{name}=="Wacom HID 53FD Finger", ENV{LIBINPUT_CALIBRATION_MATRIX}="1 0 0 0 1 0"
    ACTION=="add|change", KERNEL=="event*", ATTRS{name}=="Wacom HID 53FD Pen", ENV{LIBINPUT_CALIBRATION_MATRIX}="1 0 0 0 1 0"
  '';

  # Дополнительные настройки для корректного определения поворота экрана
  hardware.sensor.iio.enable = true;  # Включаем поддержку IIO сенсоров

  # Автоматический поворот экрана
  services.autorandr.enable = true;

  hardware.enableAllFirmware = true;

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
  };

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

  # services = {
  #   fstrim.enable = true;
  #   tlp = {
  #     enable = true;
  #     settings = {
  #       CPU_SCALING_GOVERNOR_ON_AC = "powersave";
  #       CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
  #     };
  #   };
  #   hardware.bolt.enable = true;
  #   thermald.enable = true;
  # };
}
