{
  config,
  pkgs,
  lib,
  ...
}: let
  # Flag to toggle between performance and economy mode on battery
  # Set to true for economy mode, false for performance mode
  batteryEconomyMode = false;

  # Flag to toggle between performance and economy mode on AC power
  # Set to true for economy mode, false for performance mode
  acEconomyMode = true;
in {
  # enable powertop auto tuning on startup.
  powerManagement = {
    powertop.enable = true;
    cpuFreqGovernor = "powersave";
  };

  # Better scheduling for CPU cycles - thanks System76!!!
  services.system76-scheduler.settings.cfsProfiles.enable = true;

  # Enable thermald, the temperature management daemon (only necessary if on Intel CPUs)
  services.thermald.enable = true;

  # Disable GNOMEs power management
  services.power-profiles-daemon.enable = false;

  # Enable TLP (better than gnomes internal power manager)
  services.tlp = {
    enable = true;
    settings = {
      # AC power settings (for when plugged in)
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC =
        if acEconomyMode
        then "balance-power"
        else "balance-performance";
      PLATFORM_PROFILE_ON_AC =
        if acEconomyMode
        then "low-power"
        else "balanced";
      CPU_MAX_PERF_ON_AC =
        if acEconomyMode
        then 60
        else 100;
      CPU_BOOST_ON_AC =
        if acEconomyMode
        then 0
        else 1;
      INTEL_PSTATE_ON_AC = "powersave";

      # Battery power settings
      CPU_SCALING_GOVERNOR_ON_BAT =
        if batteryEconomyMode
        then "powersave"
        else "powersave";
      CPU_ENERGY_PERF_POLICY_ON_BAT =
        if batteryEconomyMode
        then "power"
        else "balance-power";
      PLATFORM_PROFILE_ON_BAT =
        if batteryEconomyMode
        then "low-power"
        else "balanced";
      CPU_MAX_PERF_ON_BAT =
        if batteryEconomyMode
        then 40
        else 80;
      CPU_BOOST_ON_BAT =
        if batteryEconomyMode
        then 0
        else 1;
      INTEL_PSTATE_ON_BAT = "powersave";

      # USB settings
      USB_AUTOSUSPEND = 0;

      # Additional power saving settings
      RUNTIME_PM_ON_BAT = "auto";
      RUNTIME_PM_ON_AC = "auto";
      NATACPI_ENABLE = 1;
      TPACPI_ENABLE = 1;
      TPSMAPI_ENABLE = 1;
    };
  };

  # Sleep and hibernate settings
  systemd.targets.sleep.enable = true;
  systemd.targets.suspend.enable = true;
  systemd.targets.hibernate.enable = true;
  systemd.targets.hybrid-sleep.enable = true;

  security.pam.services.gdm.enableGnomeKeyring = true;

  services.logind = {
    lidSwitch = "suspend";
    extraConfig = ''
      HandleSuspendKey=suspend
      HandleLidSwitch=suspend
      HandleLidSwitchExternalPower=suspend
    '';
  };

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

  boot.kernelParams =
    [
      "intel_pstate=active"
      "processor.max_cstate=5"
      "intel_idle.max_cstate=5"
      "workqueue.power_efficient=y"
      "pcie_aspm=powersave"
    ]
    # Add conditional kernel parameters based on power modes
    ++ lib.optional batteryEconomyMode "intel_pstate=no_hwp"
    ++ lib.optional (!batteryEconomyMode) "intel_pstate=hwp_only"
    ++ lib.optional acEconomyMode "intel_pstate=no_hwp";
}
