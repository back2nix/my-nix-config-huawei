{
  config,
  pkgs,
  lib,
  ...
}: {

  # # Останови libvirtd если он запущен
# sudo systemctl stop libvirtd

# # Выгрузи модули KVM
# sudo modprobe -r kvm_intel  # для Intel
# sudo modprobe -r kvm_amd    # для AMD
# sudo modprobe -r kvm

# # Загрузи модули VirtualBox
# sudo modprobe vboxdrv
# sudo modprobe vboxnetflt
# sudo modprobe vboxnetadp

  # Отключаем KVM для работы VirtualBox
  # boot.blacklistedKernelModules = [ "kvm" "kvm_intel" "kvm_amd" ];

  # Отключаем libvirtd (конфликтует с VirtualBox)
  # virtualisation.libvirtd.enable = lib.mkForce false;

  # Включаем VirtualBox
  # boot.blacklistedKernelModules = [ "kvm" "kvm_intel" ];
  # boot.blacklistedKernelModules = [ "kvm" "kvm_intel" ];

  virtualisation.virtualbox = {
    host = {
      enable = true;
      enableExtensionPack = true;
      # enableKvm = true;
      addNetworkInterface = true;
    };

    guest = {
      enable = false;
    };
  };

  # Убедимся что пользователь в группе vboxusers
  # (у тебя уже добавлено в users.nix, но для полноты)
  # users.users.bg.extraGroups = [ "vboxusers" ];
}
