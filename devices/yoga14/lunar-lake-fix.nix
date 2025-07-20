{
  config,
  lib,
  pkgs,
  ...
}: {
  # Исправления для Intel Lunar Lake + xe драйвера
  boot.kernelParams = [
    "xe.force_probe=*"
    "xe.enable_display=1"
    "i915.force_probe=!7d45"
    "intel_iommu=igfx_off"
    "iommu=pt"
  ];

  # Минимальная конфигурация графики
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      mesa.drivers
      intel-media-driver
      libva
      libva-utils
    ];
  };

  # Переменные окружения для стабильности
  environment.variables = lib.mkForce {
    LIBVA_DRIVER_NAME = "iHD";
    MOZ_DISABLE_RDD_SANDBOX = "1";
    MOZ_X11_EGL = "1";

    # Отключаем аппаратное ускорение в Chrome временно
    CHROME_FLAGS = "--disable-gpu --disable-software-rasterizer --disable-gpu-compositing";
  };

  # Добавляем диагностические инструменты
  environment.systemPackages = with pkgs; [
    mesa-demos
    vulkan-tools
    intel-gpu-tools

    # Скрипт для запуска Chrome без GPU ускорения
    (pkgs.writeShellScriptBin "chrome-safe" ''
      exec ${pkgs.google-chrome}/bin/google-chrome-stable \
        --disable-gpu \
        --disable-software-rasterizer \
        --disable-gpu-compositing \
        --disable-gpu-sandbox \
        --disable-features=VaapiVideoDecoder \
        "$@"
    '')
  ];
}
