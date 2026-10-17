{
  description = "nixos-anywhere kexec-installer + Wi-Fi + инструменты для in-place LUKS-миграции";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/b1b875982b17dabde9b4a37f3e229e74913e6db3";
    nixos-images.url = "github:nix-community/nixos-images/50939ddf1a0339f289a9dbd810bdfd4e4fba6df4";
  };

  outputs = {nixpkgs, nixos-images, ...}: let
    system = "x86_64-linux";
    mk = ip: extra:
      (nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nixos-images.nixosModules.kexec-installer
          ({pkgs, lib, ...}: {
            boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
            # Только прошивки iwlwifi + regulatory, чтобы initrd не раздуло.
            hardware.firmware = [
              (pkgs.runCommand "iwlwifi-fw" {} ''
                mkdir -p $out/lib/firmware/intel
                cp -rL ${pkgs.linux-firmware}/lib/firmware/intel/iwlwifi $out/lib/firmware/intel/
                cp -L ${pkgs.linux-firmware}/lib/firmware/{iwlwifi-*,regulatory.db*} $out/lib/firmware/
              '')
            ];
            hardware.enableRedistributableFirmware = lib.mkForce false;

            networking.networkmanager.enable = lib.mkForce false;
            networking.wireless = {
              enable = true;
              # PSK в ./wifi-psk (в .gitignore), сборка через path:, чтобы файл был виден.
              networks."TP-Link_3FB0_5G".psk = lib.removeSuffix "\n" (builtins.readFile ./wifi-psk);
            };
            # restore-network из kexec-installer восстановит адрес по MAC; это запасной путь.
            systemd.network.networks."05-wlan" = {
              matchConfig.Type = "wlan";
              address = ["${ip}/24"];
              gateway = ["192.168.0.1"];
              dns = ["192.168.0.1" "1.1.1.1"];
            };

            # iwlwifi (CNVi) после kexec часто не отвечает (-110): сбросить по PCI и перезагрузить драйвер.
            systemd.services.iwlwifi-kexec-reset = {
              wantedBy = ["multi-user.target"];
              before = ["wpa_supplicant.service"];
              after = ["systemd-udev-settle.service"];
              path = with pkgs; [kmod coreutils iproute2 gnugrep];
              serviceConfig.Type = "oneshot";
              script = ''
                for try in 1 2 3; do
                  sleep 5
                  ip -o link | grep -q ": wl" && exit 0
                  echo "no wlan, PCI reset attempt $try"
                  modprobe -r iwlmvm iwlwifi || true
                  for dev in /sys/bus/pci/devices/*; do
                    [ "$(cat $dev/class)" = 0x028000 ] && echo 1 > $dev/remove
                  done
                  sleep 2
                  echo 1 > /sys/bus/pci/rescan
                  modprobe iwlwifi
                done
              '';
            };

            users.users.root.openssh.authorizedKeys.keyFiles = [./authorized_key.pub];
            environment.systemPackages = with pkgs; [cryptsetup e2fsprogs tmux git rsync];
          })
          extra
        ];
      }).config.system.build.kexecInstallerTarball;
  in {
    packages.${system} = {
      huawei = mk "192.168.0.159" {};
      asus = mk "192.168.0.117" {};
      # NVIDIA: nouveau после проприетарного драйвера вешает kexec-ядро — только текстовая консоль.
      desktop = mk "192.168.0.171" {imports = [{
        boot.blacklistedKernelModules = ["nouveau" "nvidiafb"];
        boot.kernelParams = ["nomodeset"];
        # Тот же MAC, что даёт NetworkManager (macAddress = "stable"), иначе роутер шлёт .171 на старый MAC.
        systemd.network.links."10-wlan" = {
          matchConfig.Type = "wlan";
          linkConfig.MACAddress = "52:1d:7f:c2:7d:3f";
        };
        # restore-network пишет 00-wlp5s0.network (DHCP → другой адрес); 00-wlan идёт раньше по алфавиту.
        systemd.network.networks."00-wlan" = {
          matchConfig.Type = "wlan";
          address = ["192.168.0.171/24"];
          gateway = ["192.168.0.1"];
          dns = ["192.168.0.1" "1.1.1.1"];
        };
      } {
        # Экрана нет: любая неудача должна сама вернуть машину в старую систему и оставить следы.
        boot.kernelParams = ["panic=10" "oops=panic" "softlockup_panic=1" "hung_task_panic=1" "printk.always_kmsg_dump=1" "efi_pstore.pstore_disable=0"];
        boot.kernelModules = ["efi_pstore" "sp5100_tco"];
        systemd.settings.Manager.RuntimeWatchdogSec = "30s";
        # Лог на ESP каждые 5 с; без ssh-сессии через 120 с — принудительная перезагрузка.
        systemd.services.diag = {
          wantedBy = ["sysinit.target"];
          unitConfig.DefaultDependencies = false;
          path = with nixpkgs.legacyPackages.${system}; [iproute2 util-linux coreutils systemd iputils kmod pciutils iw procps];
          script = ''
            set +e
            mkdir -p /esp
            for i in $(seq 30); do
              mount -o sync /dev/disk/by-partuuid/2870008c-ab56-4ce6-8b35-151f5fe6e935 /esp && break
              sleep 1
            done
            t=0
            while :; do
              { echo "=== t=$t $(date)"; uptime; ip a; ip r; iw dev; ping -c1 -W1 192.168.0.1
                ss -tnp; lsmod; lspci -k; dmesg; journalctl -b --no-pager -o short-monotonic
              } > /esp/kexec-diag.new 2>&1
              mv -f /esp/kexec-diag.new /esp/kexec-diag.txt; sync
              if [ $t -ge 120 ] && ! ss -tn state established "( sport = :22 )" | grep -q :22; then
                echo "no ssh by t=$t, rebooting" >> /esp/kexec-diag.txt; sync; umount /esp
                systemctl reboot --force --force
              fi
              sleep 5; t=$((t+5))
            done
          '';
        };
      }];};
    };
  };
}
