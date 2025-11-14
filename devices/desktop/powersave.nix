# devices/desktop/powersave.nix
{
  config,
  pkgs,
  lib,
  ...
}: {
  # 1. Отключаем tlp, чтобы избежать конфликтов
  services.tlp.enable = false;

  # 2. Принудительно переопределяем настройки logind, чтобы решить конфликт
  services.logind = {
    lidSwitch = lib.mkForce "ignore";
    lidSwitchExternalPower = lib.mkForce "ignore";
    extraConfig = lib.mkForce ''
      HandlePowerKey=poweroff
      IdleAction=ignore
      IdleActionSec=0
    '';
  };

  # 3. Отключаем стандартный демон управления питанием
  services.power-profiles-daemon.enable = false;

  # 4. Настраиваем GNOME через GSettings, убрав несуществующую опцию
  services.xserver.desktopManager.gnome = {
    extraGSettingsOverrides = ''
      [org.gnome.settings-daemon.plugins.power]
      sleep-inactive-ac-type='nothing'
      sleep-inactive-battery-type='nothing'
      idle-delay=0
      lid-close-ac-action='nothing'
      lid-close-battery-action='nothing'
    '';
  };
}
