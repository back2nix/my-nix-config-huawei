{
  config,
  pkgs,
  ...
}: {
  # enable powertop auto tuning on startup.
  powerManagement = {
    powertop.enable = true;
    cpuFreqGovernor = "powersave"; # Явное указание governor'а
  };

  # Better scheduling for CPU cycles - thanks System76!!!
  services.system76-scheduler.settings.cfsProfiles.enable = true;
  # Enable thermald, the temperature management daemon. (only necessary if on Intel CPUs)
  services.thermald.enable = true;
  # Disable GNOMEs power management
  services.power-profiles-daemon.enable = false;
  # Enable TLP (better than gnomes internal power manager)

  # sudo tlp-stat -b
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power"; # Изменено на более агрессивное энергосбережение
      PLATFORM_PROFILE_ON_BAT = "low-power";
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance-power";
      PLATFORM_PROFILE_ON_AC = "low-power";
      USB_AUTOSUSPEND = 0;

      # Добавленные настройки для лучшего контроля температуры
      CPU_MAX_PERF_ON_BAT =
        60; # Ограничение максимальной производительности на батарее
      CPU_MAX_PERF_ON_AC =
        60; # Ограничение максимальной производительности при питании
      CPU_BOOST_ON_BAT = 0; # Отключение турбо-буста на батарее
      CPU_BOOST_ON_AC = 1; # Включение турбо-буста при питании

      # Настройки для Intel P-state
      INTEL_PSTATE_ON_BAT = "powersave";
      INTEL_PSTATE_ON_AC = "powersave";

      # Дополнительные настройки энергосбережения
      RUNTIME_PM_ON_BAT = "auto";
      RUNTIME_PM_ON_AC = "auto";

      NATACPI_ENABLE = 1;
      TPACPI_ENABLE = 1;
      TPSMAPI_ENABLE = 1;
    };
  };

  # Остальные настройки без изменений
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

  boot.kernelParams = [
    "intel_pstate=active"
    "processor.max_cstate=5"
    "intel_idle.max_cstate=5"
    "workqueue.power_efficient=y"
    "pcie_aspm=powersave" # Добавлен параметр для энергосбережения PCIe
    "intel_pstate=no_hwp" # Отключение аппаратного управления производительностью
  ];
}
