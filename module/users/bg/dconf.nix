{ pkgs, ... }:
let
in
{
  # https://github.com/Corona09/nix-config/blob/b73fa075e4e093025db1cd6628b3dfc84ba15ba0/modules/home/dconf/dconf.nix#L266
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
      ];
      # help = [ ];
      # www = [ "<Alt>c" ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Primary><Alt>T";
      command = "kitty";
      name = "Open Terminal";
    };
    "org/gnome/desktop/wm/keybindings" = {
      # minimize = [ "" ];
      switch-input-source = [ "<Alt>Shift_L" ];
      # switch-input-source-backward = [ "<Shift><Super>t" ];
      # switch-to-workspace-left = [ "<Primary>Left" "<Super>h" ];
      # switch-to-workspace-right = [ "<Primary>Right" "<Super>l" ];
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      natural-scroll = true;
      send-events = "enabled";
      tap-to-click = true;
      two-finger-scrolling-enabled = true;
    };
    "org/gnome/desktop/wm/keybindings" = {
      close = [ "<Alt>q" ];
      cycle-group = [ ];
      cycle-group-backward = [ ];
      cycle-panels = [ ];
      cycle-panels-backward = [ ];
      cycle-windows = [ ];
      cycle-windows-backward = [ ];
      move-to-monitor-down = [ ];
      move-to-monitor-left = [ ];
      move-to-monitor-right = [ ];
      move-to-monitor-up = [ ];
      move-to-workspace-1 = [ ];
      move-to-workspace-last = [ ];
      move-to-workspace-left = [ "<Shift><Control><Alt>Left" ];
      move-to-workspace-right = [ "<Shift><Control><Alt>Right" ];
      switch-panels = [ ];
      switch-panels-backward = [ ];
      switch-to-workspace-1 = [ "<Alt>1" ];
      switch-to-workspace-2 = [ "<Alt>2" ];
      switch-to-workspace-3 = [ "<Alt>3" ];
      switch-to-workspace-4 = [ "<Alt>4" ];
      switch-to-workspace-last = [ ];
    };

    # "system/proxy" = {
    #   mode = "manual";
    # };
    #
    # "system/proxy/http" = {
    #   host = "127.0.0.1";
    #   port = 8080;
    # };
    #
    # "system/proxy/https" = {
    #   host = "127.0.0.1";
    #   port = 8080;
    # };
    #
    # "system/proxy/socks" = {
    #   host = "127.0.0.1";
    #   port = 8080;
    # };
  };
}
