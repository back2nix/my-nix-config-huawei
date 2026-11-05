{
  config,
  lib,
  pkgs,
  ...
}: {
  # Устанавливаем дополнительные пакеты для диагностики
  environment.systemPackages = with pkgs; [
    usbutils # для lsusb
    pciutils # для lspci
    bluez-tools # дополнительные инструменты bluez
  ];

  # Исправляем проблемы с правами доступа
  systemd.tmpfiles.rules = [
    "d /var/lib/bluetooth 0755 root root - -"
  ];

  # Более полная конфигурация bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    package = pkgs.bluez;
    settings = {
      General = {
        Name = "Computer";
        ControllerMode = "dual";
        FastConnectable = "true";
        Experimental = "true";
        Enable = "Source,Sink,Media,Socket";
        MultiProfile = "multiple";
        # Добавляем явное включение адаптера
        AutoEnable = "true";
      };
      Policy = {
        AutoEnable = "true";
      };
    };
  };

  # Добавляем правила udev для корректной работы Bluetooth
  services.udev.extraRules = ''
    # Сброс адаптера Bluetooth при загрузке системы
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="*", ATTRS{idProduct}=="*", ATTR{bInterfaceClass}=="e0", ATTR{bInterfaceSubClass}=="01", ATTR{bInterfaceProtocol}=="01", RUN+="${pkgs.bluez}/bin/hciconfig %k reset"
  '';

  # Обеспечиваем загрузку модулей ядра
  boot.extraModprobeConfig = ''
    options btusb reset=1
  '';

  # Явно добавляем bluetooth в systemd сервисы
  systemd.services.bluetooth = {
    serviceConfig = {
      ExecStart = [
        ""
        "${pkgs.bluez}/libexec/bluetooth/bluetoothd -f /etc/bluetooth/main.conf"
      ];
      RestartSec = "5";
      Restart = "on-failure";
    };
    wantedBy = ["bluetooth.target"];
  };
}
