{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.xwayland.enable = true;
  environment.sessionVariables = {
    GDK_BACKEND = "wayland,x11";  # Fallback на x11
    NIXOS_OZONE_WL = "1";
  };
  services.xserver = {
    enable = true;
    videoDrivers = ["modesetting"];



    xkb = {
      layout = "us,ru";
      options = "grp:caps_toggle,grp_led:caps,compose:ralt";
    };

    displayManager = {
      # sessionCommands остается здесь, так как это относится к X-серверу
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
              ${pkgs.xorg.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" 0 -1 1 1 0 0 0 0 1
              ;;
            *"orientation changed"*"right"*)
              ${pkgs.glib}/bin/gdbus call --session \
                --dest org.gnome.Mutter.DisplayConfig \
                --object-path /org/gnome/Mutter/DisplayConfig \
                --method org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig \
                $SERIAL 1 \
                "[(0, 0, 1.25, uint32 3, true, [('eDP-1', '2880x1800@60.000', {})])]" \
                "{}"
              ${pkgs.xorg.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1
              ;;
            *"orientation changed"*"normal"*)
              ${pkgs.glib}/bin/gdbus call --session \
                --dest org.gnome.Mutter.DisplayConfig \
                --object-path /org/gnome/Mutter/DisplayConfig \
                --method org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig \
                $SERIAL 1 \
                "[(0, 0, 1.25, uint32 0, true, [('eDP-1', '2880x1800@60.000', {})])]" \
                "{}"
              ${pkgs.xorg.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1
              ;;
            *"orientation changed"*"inverted"*)
              ${pkgs.glib}/bin/gdbus call --session \
                --dest org.gnome.Mutter.DisplayConfig \
                --object-path /org/gnome/Mutter/DisplayConfig \
                --method org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig \
                $SERIAL 1 \
                "[(0, 0, 1.25, uint32 2, true, [('eDP-1', '2880x1800@60.000', {})])]" \
                "{}"
              ${pkgs.xorg.xinput}/bin/xinput set-prop "Wacom HID 53FD Finger" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1
              ;;
          esac
        done &
      '';
    };

    wacom.enable = true;

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

  # Эти опции действительно переехали в корень services
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  services.desktopManager.gnome.enable = true;

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
