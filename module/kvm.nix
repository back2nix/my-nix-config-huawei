{ config, pkgs, ... }:

{
  boot.kernelModules = [ "kvm-intel" ];
  # Включаем демон виртуализации
  virtualisation.libvirtd.enable = true;

  # Включаем GUI (virt-manager)
  programs.virt-manager.enable = true;

  # Добавляем тебя в группу, чтобы работало без sudo
  users.users.bg.extraGroups = [ "libvirtd" ];

  # Пакеты, которые нужны только когда включен этот модуль
  environment.systemPackages = with pkgs; [
    qemu
    OVMF
    swtpm
  ];
}
