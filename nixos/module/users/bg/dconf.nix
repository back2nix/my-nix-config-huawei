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
  };
}
