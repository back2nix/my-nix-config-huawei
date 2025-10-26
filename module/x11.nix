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
        # wayland = false;
      };
    };

    desktopManager.gnome = {
      enable = true;
      # --- НАЧАЛО ИЗМЕНЕНИЯ ---
      # Явно заменяем mutter на нашу исправленную версию из оверлея
      # mutter = pkgs.mutter;
      # --- КОНЕЦ ИЗМЕНЕНИЯ ---
    };

    wacom.enable = true;

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

    # Автоповорот через gdbus вместо xrandr
    displayManager.sessionCommands = ''
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
              "[(0, 0, 1.0, uint32 1, true, [('eDP-1', '2880x1800@60.000', {})])]" \
              "{}"
            ${pkgs.xorg.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" 0 -1 1 1 0 0 0 0 1
            ;;
          *"orientation changed"*"right"*)
            ${pkgs.glib}/bin/gdbus call --session \
              --dest org.gnome.Mutter.DisplayConfig \
              --object-path /org/gnome/Mutter/DisplayConfig \
              --method org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig \
              $SERIAL 1 \
              "[(0, 0, 1.0, uint32 3, true, [('eDP-1', '2880x1800@60.000', {})])]" \
              "{}"
            ${pkgs.xorg.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1
            ;;
          *"orientation changed"*"normal"*)
            ${pkgs.glib}/bin/gdbus call --session \
              --dest org.gnome.Mutter.DisplayConfig \
              --object-path /org/gnome/Mutter/DisplayConfig \
              --method org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig \
              $SERIAL 1 \
              "[(0, 0, 1.0, uint32 0, true, [('eDP-1', '2880x1800@60.000', {})])]" \
              "{}"
            ${pkgs.xorg.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1
            ;;
          *"orientation changed"*"inverted"*)
            ${pkgs.glib}/bin/gdbus call --session \
              --dest org.gnome.Mutter.DisplayConfig \
              --object-path /org/gnome/Mutter/DisplayConfig \
              --method org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig \
              $SERIAL 1 \
              "[(0, 0, 1.0, uint32 2, true, [('eDP-1', '2880x1800@60.000', {})])]" \
              "{}"
            ${pkgs.xorg.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1
            ;;
        esac
      done &
    '';
  };

  environment.systemPackages = with pkgs; [
    xf86_input_wacom
    xorg.xinput
    xorg.xf86inputlibinput
    iio-sensor-proxy
    onboard
    glib # для gdbus

    (pkgs.writeShellScriptBin "toggle-flip" ''
      export PATH="${
        pkgs.lib.makeBinPath [
          pkgs.glib
          pkgs.xorg.xinput
          pkgs.libnotify
          pkgs.coreutils
          pkgs.util-linux
          pkgs.procps
          pkgs.gawk
          pkgs.xorg.xset
        ]
      }:$PATH"
      ${builtins.readFile ./toggle-flip.sh}
    '')
  ];

  hardware.sensor.iio.enable = true;
  services.udev.extraRules = ''
    SUBSYSTEM=="iio", ACTION=="add", ATTR{name}=="accel_3d", TAG+="systemd", ENV{SYSTEMD_WANTS}="iio-sensor-proxy.service"
  '';
}
