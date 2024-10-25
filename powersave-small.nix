{
  config,
  pkgs,
  ...
}: {
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "power";
      PLATFORM_PROFILE_ON_BAT = "low-power";
      PLATFORM_PROFILE_ON_AC = "low-power";
      # START_CHARGE_THRESH_BAT0 = "75";
      # STOP_CHARGE_THRESH_BAT0 = "80";
      USB_AUTOSUSPEND = 0; # Отключаем автоприостановку USB-устройств
    };
  };

  systemd.targets.sleep.enable = true;
  systemd.targets.suspend.enable = true;
  systemd.targets.hibernate.enable = true;
  systemd.targets.hybrid-sleep.enable = true;

  security.pam.services.gdm.enableGnomeKeyring = true;

  services.logind = {
    lidSwitch = "suspend";
    # lidSwitchExternalPower = "suspend";
    # lidSwitchExternalPower = "lock";
    extraConfig = ''
      HandleSuspendKey=suspend
      HandleLidSwitch=suspend
      HandleLidSwitchExternalPower=suspend
    '';
  };

  # services.acpid = {
  #   enable = true;
  #   handlers = {
  #     lid-close = {
  #       event = "button/lid.*";
  #       action = ''
  #         echo "Lid closed at $(date)" >> /tmp/lid.log
  #         systemctl suspend
  #       '';
  #     };
  #   };
  # };

  services.power-profiles-daemon.enable = false;

  services.xserver.desktopManager.gnome = {
    extraGSettingsOverrides = ''
      [org.gnome.settings-daemon.plugins.power]
      sleep-inactive-ac-type='suspend'
      sleep-inactive-ac-timeout=3600
      sleep-inactive-battery-type='suspend'
      sleep-inactive-battery-timeout=600
      power-button-action='suspend'
      lid-close-ac-action='suspend'
      lid-close-battery-action='suspend'
    '';
  };

  services.thermald.enable = true;

  boot.kernelParams = [
    "intel_pstate=active"
    "processor.max_cstate=5"
    "intel_idle.max_cstate=5"
  ];

  # Отключаем powertop, так как он может агрессивно управлять энергопотреблением
  powerManagement.powertop.enable = false;
}
