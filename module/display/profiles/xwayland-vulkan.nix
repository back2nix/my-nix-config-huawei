# Профиль "xwayland-vulkan" — текущая рабочая конфигурация.
# GNOME-сессия Wayland, Chrome через XWayland + ANGLE-Vulkan, Wacom через X11-драйвер.
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (config.my.display.profile == "xwayland-vulkan") {
  # GPU-композитинг на этом Intel Lunar Lake + Mesa:
  #   - ANGLE-GL вообще не инициализируется → всё software.
  #   - ANGLE-Vulkan даёт HW растеризацию/WebGL/видео, НО под нативным
  #     --ozone-platform=wayland Chromium не умеет VK_KHR_wayland_surface
  #     для display-композитора → "Compositing: Software only" (весь
  #     backbuffer композитится на CPU, GPU-процесс жрёт ~30мс/кадр).
  # Решение: Vulkan + --ozone-platform=x11 (XWayland) — там композитор
  # использует VK_KHR_xcb_surface, который поддержан → "Compositing:
  # Hardware accelerated" + WebGL без "reduced performance". Проверено на
  # chrome://gpu. Размен: XWayland вместо нативного Wayland.
  # См. brave/brave-browser#55345 (DefaultANGLEVulkan + Wayland = soft-composite).
  # --disable-gpu-video-decode убран: на Vulkan-пути Video Decode встаёт на HW.
  my.display.chrome.args = [
    "--ozone-platform=x11"
    # RawDraw / TreesInViz — экспериментальные GPU-фичи, держатся в ОДНОМ
    # --enable-features (второй такой флаг затёр бы Vulkan-список → soft-compositing).
    # Проверено chrome://gpu: "Raw Draw: Enabled" - не даёт запустить chrome, белый экран.
    # Vulkan/WebGPU/Compositing остались Hardware accelerated.
    "--enable-features=Vulkan,DefaultANGLEVulkan,VulkanFromANGLE,WebRTCPipeWireCapturer,TreesInViz"
    "--use-angle=vulkan"
    "--ignore-gpu-blocklist"
    "--enable-gpu-rasterization"
    "--enable-zero-copy"
  ];

  services.xserver = {
    displayManager = {
      sessionCommands = ''
        # Настройка автоповорота для X11 через GNOME DisplayConfig API
        ${pkgs.iio-sensor-proxy}/bin/monitor-sensor | while read line; do
          SERIAL=$(${pkgs.glib}/bin/gdbus call --session \
            --dest org.gnome.Mutter.DisplayConfig \
            --object-path /org/gnome/Mutter/DisplayConfig \
            --method org.gnome.Mutter.DisplayConfig.GetCurrentState | \
            ${pkgs.gawk}/bin/awk '{print $2}' | ${pkgs.coreutils}/bin/tr -d ',')

          case "$line" in
            *"orientation changed"*"left"*)
              ${pkgs.glib}/bin/gdbus call --session \
                --dest org.gnome.Mutter.DisplayConfig \
                --object-path /org/gnome/Mutter/DisplayConfig \
                --method org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig \
                $SERIAL 1 \
                "[(0, 0, 1.25, uint32 1, true, [('eDP-1', '2880x1800@60.000', {})])]" \
                "{}"
              ${pkgs.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" 0 -1 1 1 0 0 0 0 1
              ;;
            *"orientation changed"*"right"*)
              ${pkgs.glib}/bin/gdbus call --session \
                --dest org.gnome.Mutter.DisplayConfig \
                --object-path /org/gnome/Mutter/DisplayConfig \
                --method org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig \
                $SERIAL 1 \
                "[(0, 0, 1.25, uint32 3, true, [('eDP-1', '2880x1800@60.000', {})])]" \
                "{}"
              ${pkgs.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1
              ;;
            *"orientation changed"*"normal"*)
              ${pkgs.glib}/bin/gdbus call --session \
                --dest org.gnome.Mutter.DisplayConfig \
                --object-path /org/gnome/Mutter/DisplayConfig \
                --method org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig \
                $SERIAL 1 \
                "[(0, 0, 1.25, uint32 0, true, [('eDP-1', '2880x1800@60.000', {})])]" \
                "{}"
              ${pkgs.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1
              ;;
            *"orientation changed"*"inverted"*)
              ${pkgs.glib}/bin/gdbus call --session \
                --dest org.gnome.Mutter.DisplayConfig \
                --object-path /org/gnome/Mutter/DisplayConfig \
                --method org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig \
                $SERIAL 1 \
                "[(0, 0, 1.25, uint32 2, true, [('eDP-1', '2880x1800@60.000', {})])]" \
                "{}"
              ${pkgs.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1
              ;;
          esac
        done &
      '';
    };

    inputClassSections = [
      ''
        Identifier "Wacom Touchscreen"
        MatchProduct "Wacom HID 53FD Finger"
        MatchDevicePath "/dev/input/event*"
        Driver "wacom"
        Option "Touch" "on"
      ''

      ''
        Identifier "Wacom Pen"
        MatchProduct "Wacom HID 53FD Pen"
        MatchDevicePath "/dev/input/event*"
        Driver "wacom"
      ''
    ];
  };

  environment.systemPackages = with pkgs; [
    xf86_input_wacom
    xinput
    xf86-input-libinput
    onboard

    (pkgs.writeShellScriptBin "toggle-flip" ''
      export PATH="${
        pkgs.lib.makeBinPath [
          pkgs.glib
          pkgs.xinput
          pkgs.libnotify
          pkgs.coreutils
          pkgs.util-linux
          pkgs.procps
          pkgs.gawk
          pkgs.xset
        ]
      }:$PATH"
      ${builtins.readFile ../toggle-flip-x11.sh}
    '')
  ];
}
