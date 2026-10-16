# Профиль "wayland-native" — всё на нативном Wayland, включая Chrome.
# Размен: без Vulkan-композитинга (Chromium не умеет VK_KHR_wayland_surface),
# зато без XWayland/XIM и с дробным масштабированием.
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (config.my.display.profile == "wayland-native") {
  my.display.chrome.args = [
    "--ozone-platform=wayland"
    "--enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer"
    "--ignore-gpu-blocklist"
    "--enable-gpu-rasterization"
    "--enable-zero-copy"
  ];

  environment.systemPackages = with pkgs; [
    wl-clipboard
    libinput
    # Виртуальная клавиатура: в GNOME используется штатная OSK
    # (squeekboard тут не подхватывается — он для Phosh).
    libwacom

    (pkgs.writeShellScriptBin "toggle-flip" ''
      export PATH="${
        pkgs.lib.makeBinPath [
          pkgs.glib # Для gdbus
          pkgs.libnotify
          pkgs.coreutils
          pkgs.gawk
        ]
      }:$PATH"
      ${builtins.readFile ../toggle-flip-wayland.sh}
    '')
  ];

  # Wacom тачскрин/перо через libinput (замена inputClassSections из X11)
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="event*", ATTRS{name}=="Wacom HID 53FD Finger", ENV{LIBINPUT_CALIBRATION_MATRIX}="1 0 0 0 1 0"
    ACTION=="add|change", KERNEL=="event*", ATTRS{name}=="Wacom HID 53FD Pen", ENV{LIBINPUT_CALIBRATION_MATRIX}="1 0 0 0 1 0"
  '';
}
