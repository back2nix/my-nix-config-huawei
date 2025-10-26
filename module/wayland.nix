# File: module/wayland.nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Включаем X-сервер для XWayland и GDM
  services.xserver = {
    enable = true;
    videoDrivers = ["modesetting"];

    displayManager.gdm = {
      enable = true;
      wayland = true; # Явно включаем Wayland-сессию по умолчанию
    };

    desktopManager.gnome.enable = true;

    # Добавляем для лучшей интеграции Wacom в GNOME Control Center
    wacom.enable = true;
  };

  # Включаем слой совместимости XWayland
  programs.xwayland.enable = true;

  # Настройки libinput (одинаковы для X11 и Wayland)
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

  # Пакеты, необходимые для окружения Wayland
  environment.systemPackages = with pkgs; [
    # Wayland утилиты
    wl-clipboard      # Утилита для буфера обмена
    # wlr-randr         # Аналог xrandr для композиторов на wlroots (может быть полезен)
    libinput          # Библиотека для обработки ввода
    iio-sensor-proxy  # Для автоповорота экрана

    # Виртуальная клавиатура для Wayland
    squeekboard

    # Пакет для поддержки планшетов Wacom
    libwacom

    # Ваш кастомный скрипт для переключения ориентации
    (pkgs.writeShellScriptBin "toggle-flip" ''
      # Убедитесь, что этот путь к скрипту правильный
      # и сам скрипт адаптирован для Wayland (использует D-Bus)!
      export PATH="${
        pkgs.lib.makeBinPath [
          pkgs.glib # Для gdbus
          pkgs.libnotify
          pkgs.coreutils
          pkgs.gawk
        ]
      }:$PATH"
      ${builtins.readFile ./toggle-flip-wayland.sh}
    '')
  ];

  # Переменные окружения для Wayland-сессии
  environment.sessionVariables = {
    # "Подсказываем" приложениям использовать Wayland
    # GDK_BACKEND = "wayland,x11";
    # QT_QPA_PLATFORM = "wayland;xcb";
    # SDL_VIDEODRIVER = "wayland";
    # CLUTTER_BACKEND = "wayland";

    # Рекомендуется убрать, чтобы не конфликтовать с настройками GNOME
    # GDK_SCALE = "1.2";
    # GDK_DPI_SCALE = "0.8";
  };

  # Включаем поддержку сенсоров для автоповорота
  hardware.sensor.iio.enable = true;

  # Udev-правила для Wayland/libinput
  services.udev.extraRules = ''
    # Правила для Wacom тачскрина и пера (замена inputClassSections из X11)
    ACTION=="add|change", KERNEL=="event*", ATTRS{name}=="Wacom HID 53FD Finger", ENV{LIBINPUT_CALIBRATION_MATRIX}="1 0 0 0 1 0"
    ACTION=="add|change", KERNEL=="event*", ATTRS{name}=="Wacom HID 53FD Pen", ENV{LIBINPUT_CALIBRATION_MATRIX}="1 0 0 0 1 0"

    # Правило для iio-sensor-proxy
    SUBSYSTEM=="iio", ACTION=="add", ATTR{name}=="accel_3d", TAG+="systemd", ENV{SYSTEMD_WANTS}="iio-sensor-proxy.service"
  '';
}
