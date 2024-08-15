{
  config,
  pkgs,
  ...
}: {
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "low-power";
      PLATFORM_PROFILE_ON_AC = "performance";
      START_CHARGE_THRESH_BAT0 = "75";
      STOP_CHARGE_THRESH_BAT0 = "80";
    };
  };

  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "lock";
    extraConfig = ''
      HandlePowerKey=suspend
      IdleAction=suspend
      IdleActionSec=15min
    '';
  };

  services.power-profiles-daemon.enable = false;

  services.xserver.desktopManager.gnome = {
    extraGSettingsOverrides = ''
      [org.gnome.settings-daemon.plugins.power]
      sleep-inactive-ac-type='suspend'
      sleep-inactive-ac-timeout=3600
      sleep-inactive-battery-type='suspend'
      sleep-inactive-battery-timeout=1800
    '';
  };

  services.thermald.enable = true;

  boot.kernelParams = [
    "intel_pstate=active"
    "processor.max_cstate=5"
    "intel_idle.max_cstate=5"
  ];

  powerManagement.powertop.enable = true;
}
