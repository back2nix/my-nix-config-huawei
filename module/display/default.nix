# Единая точка настройки графики: GNOME + режим Wayland/XWayland + флаги Chrome.
#
# Выбор профиля:  my.display.profile = "xwayland-vulkan";  (по умолчанию)
#
# Профили (module/display/profiles/*):
#   xwayland-vulkan — текущая рабочая конфигурация: GNOME-сессия Wayland,
#                     Chrome через XWayland (--ozone-platform=x11) + ANGLE-Vulkan
#                     → HW-композитинг на Intel Lunar Lake. X11-хвосты для Wacom
#                     (inputClassSections, xinput) и автоповорот через xinput.
#   wayland-native  — Chrome на нативном Wayland (без Vulkan: под wayland
#                     Chromium не умеет VK_KHR_wayland_surface → soft-compositing),
#                     Wacom через libinput/udev.
#
# Флаги Chrome профиль кладёт в my.display.chrome.args, а home-manager
# забирает их через osConfig (см. programs.google-chrome в users/bg/home.nix).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.display;
in {
  imports = [
    ./profiles/xwayland-vulkan.nix
    ./profiles/wayland-native.nix
  ];

  options.my.display = {
    profile = lib.mkOption {
      type = lib.types.enum ["xwayland-vulkan" "wayland-native"];
      default = "xwayland-vulkan";
      description = "Профиль графики: режим сессии/XWayland и флаги Chrome.";
    };

    chrome.args = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Флаги Chrome (programs.google-chrome.commandLineArgs). Заполняются
        профилем + общими флагами ниже. ВАЖНО: --enable-features должен быть
        ровно ОДИН — Chrome берёт только последний и затирает предыдущие.
      '';
    };
  };

  config = {
    # Общие для всех профилей флаги Chrome.
    my.display.chrome.args = [
      "--disable-features=GlobalMediaControls"
      # WebGPU на Linux — отдельный switch, НЕ второй --enable-features
      # (второй затёр бы список фич профиля, см. ece7c8a/5a90d96).
      "--enable-unsafe-webgpu"
      "--remote-debugging-port=9222"
    ];

    services.xserver = {
      enable = true;
      videoDrivers = ["modesetting"];
      xkb = {
        layout = "us,ru";
        options = "grp:caps_toggle,grp_led:caps,compose:ralt";
      };
      wacom.enable = true;
    };

    services.displayManager.gdm.enable = true;
    # gdm.wayland больше не поддерживается в GNOME 50 — Wayland по умолчанию
    services.desktopManager.gnome.enable = true;
    programs.xwayland.enable = true;

    # Модуль GNOME по умолчанию включает i18n.inputMethod (ibus). Нам он не нужен:
    # раскладки us/ru идут через xkb (см. services.xserver.xkb выше), IME-движков
    # с composition (CJK) нет — gsettings input-sources = [(xkb,us),(xkb,ru)].
    #
    # При этом ibus активно ВРЕДИЛ: он выставляет XMODIFIERS=@im=ibus, из-за чего
    # XWayland-клиенты (Chrome с --ozone-platform=x11, Obsidian) ходят к ibus-x11
    # по легаси-протоколу XIM. XIM синхронный, и Ctrl+V в Chrome залипал ~10с на
    # каждой вставке. Замерено: сам буфер обмена ни при чём — XWayland-мост Mutter
    # и kitty отвечают на все таргеты (TARGETS/text-plain/SAVE_TARGETS) за 12-17мс.
    # Проверено: запуск Chrome с XMODIFIERS=@im=none убирает задержку полностью.
    i18n.inputMethod.enable = false;

    # Отключаем файловый индексатор GNOME (localsearch/tinysparql, бывший tracker).
    # Он жрёт CPU, сканируя home. Нам не нужен.
    services.gnome.localsearch.enable = false;
    services.gnome.tinysparql.enable = false;

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

    environment.systemPackages = with pkgs; [
      iio-sensor-proxy
      glib # для gdbus
    ];

    hardware.sensor.iio.enable = true;
    services.udev.extraRules = ''
      SUBSYSTEM=="iio", ACTION=="add", ATTR{name}=="accel_3d", TAG+="systemd", ENV{SYSTEMD_WANTS}="iio-sensor-proxy.service"
    '';
  };
}
