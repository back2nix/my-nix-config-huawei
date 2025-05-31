{
  config,
  lib,
  pkgs,
  ...
}: {
  services.xserver = {
    enable = true;
    videoDrivers = ["modesetting"];

    xkb = {
      layout = "us,ru";
      options = "grp:caps_toggle,grp_led:caps,compose:ralt";
    };

    displayManager = {
      gdm = {
        enable = true;
        wayland = false; # Принудительно X11
      };
    };

    desktopManager.gnome.enable = true;

    # Включаем поддержку Wacom для X11
    wacom.enable = true;

    # Настройки libinput для X11
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

    # Конфигурация для устройств ввода в X11
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

    # Команды для сессии X11
    displayManager.sessionCommands = ''
      ${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --scale 1.2x1.2
      # Настройка автоповорота для X11
      ${pkgs.iio-sensor-proxy}/bin/monitor-sensor | while read line; do
        case "$line" in
          *"orientation changed"*"left"*)
            ${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --rotate left
            ${pkgs.xorg.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" 0 -1 1 1 0 0 0 0 1
            ;;
          *"orientation changed"*"right"*)
            ${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --rotate right
            ${pkgs.xorg.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1
            ;;
          *"orientation changed"*"normal"*)
            ${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --rotate normal
            ${pkgs.xorg.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1
            ;;
          *"orientation changed"*"inverted"*)
            ${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --rotate inverted
            ${pkgs.xorg.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1
            ;;
        esac
      done &
    '';
  };

  # X11-специфичные пакеты
  environment.systemPackages = with pkgs; [
    xf86_input_wacom # Драйвер Wacom для X11
    xorg.xinput # Утилиты для настройки устройств ввода
    xorg.xf86inputlibinput # Драйвер libinput для X11
    xorg.xrandr # Управление разрешением и поворотом
    iio-sensor-proxy # Для автоповорота экрана
    onboard # Виртуальная клавиатура для планшетного режима

    (pkgs.writeShellScriptBin "toggle-flip" ''
      export PATH="${
        pkgs.lib.makeBinPath [
          pkgs.xorg.xrandr
          pkgs.xorg.xinput
          pkgs.xorg.xkbcomp
          pkgs.libnotify
          pkgs.coreutils
          pkgs.util-linux
          pkgs.procps
          pkgs.sudo
          pkgs.binutils
          pkgs.gawk
          pkgs.xorg.xset
          pkgs.evtest
          pkgs.xxd
        ]
      }:$PATH"
      ${builtins.readFile ./toggle-flip.sh}
    '')
  ];

  # Включаем автоповорот экрана для X11
  hardware.sensor.iio.enable = true;
  services.udev.extraRules = ''
    SUBSYSTEM=="iio", ACTION=="add", ATTR{name}=="accel_3d", TAG+="systemd", ENV{SYSTEMD_WANTS}="iio-sensor-proxy.service"
  '';
}
