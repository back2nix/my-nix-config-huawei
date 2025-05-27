{ config, lib, pkgs, ... }:

{
  services.xserver = {
    enable = true;  # Нужен для совместимости
    videoDrivers = ["modesetting"];

    displayManager = {
      gdm = {
        enable = true;
        wayland = true;  # Включаем Wayland
      };
    };

    desktopManager.gnome.enable = true;
  };

  # Отключаем X11, предпочитаем Wayland
  programs.xwayland.enable = true;

  # Wayland-совместимые настройки libinput
  services.libinput = {
    enable = true;
    touchpad = {
      naturalScrolling = true;
      tapping = true;
      tappingDragLock = false;
      middleEmulation = true;
      disableWhileTyping = true;
    };
  };

  # Wayland-специфичные пакеты
  environment.systemPackages = with pkgs; [
    # Wayland утилиты
    wl-clipboard              # Clipboard для Wayland
    wlr-randr                 # Управление мониторами в Wayland
    libinput                  # Библиотека для обработки ввода
    iio-sensor-proxy          # Для автоповорота экрана

    # Виртуальная клавиатура для Wayland
    squeekboard

    # Wacom поддержка для Wayland
    libwacom


    (pkgs.writeShellScriptBin "toggle-flip" ''
    export PATH="${pkgs.lib.makeBinPath [
      pkgs.xorg.xrandr pkgs.xorg.xinput pkgs.xorg.xkbcomp
      pkgs.libnotify pkgs.coreutils pkgs.util-linux
      pkgs.procps pkgs.sudo pkgs.binutils pkgs.gawk
      pkgs.xorg.xset pkgs.evtest pkgs.xxd pkgs.gnome-randr pkgs.dconf
    ]}:$PATH"
    ${builtins.readFile ./toggle-flip-wayland.sh}
    '')
  ];

  # Настройки для Wayland
  environment.sessionVariables = {
    # Принудительно использовать Wayland
    GDK_BACKEND = "wayland,x11";
    QT_QPA_PLATFORM = "wayland;xcb";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";

    # Настройки для Qt в Wayland
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

    # Для корректного масштабирования
    GDK_SCALE = "1.2";
    GDK_DPI_SCALE = "0.8";
  };

  # Включаем поддержку автоповорота в Wayland
  hardware.sensor.iio.enable = true;

  # Настройка udev правил для тачскрина в Wayland
  services.udev.extraRules = ''
    # Правила для Wacom тачскрина в Wayland
    ACTION=="add|change", KERNEL=="event*", ATTRS{name}=="Wacom HID 53FD Finger", ENV{LIBINPUT_CALIBRATION_MATRIX}="1 0 0 0 1 0"
    ACTION=="add|change", KERNEL=="event*", ATTRS{name}=="Wacom HID 53FD Pen", ENV{LIBINPUT_CALIBRATION_MATRIX}="1 0 0 0 1 0"

    # Автоповорот для Wayland
    SUBSYSTEM=="iio", ACTION=="add", ATTR{name}=="accel_3d", TAG+="systemd", ENV{SYSTEMD_WANTS}="iio-sensor-proxy.service"
  '';
}
