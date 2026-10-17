#!/usr/bin/env bash
# Desktop (NVIDIA): выгрузить nvidia и iwlwifi, затем kexec. Запускать через systemd-run (см. docs/LUKS-MIGRATION.md 5.1a).
set -x
mkdir -p /run/modprobe.d
printf 'install nvidia /bin/false\ninstall nvidia_drm /bin/false\ninstall nvidia_modeset /bin/false\ninstall nvidia_uvm /bin/false\n' > /run/modprobe.d/no-nvidia.conf
systemctl stop display-manager k3s docker
loginctl terminate-user bg
sleep 5
for i in 1 2 3 4 5; do modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia && break; sleep 3; done
if lsmod | grep -q '^nvidia'; then echo NVIDIA_STILL_LOADED; lsmod | grep nvidia; exit 1; fi
echo NVIDIA_UNLOADED
/tmp/kxi/kexec/run
sleep 1
modprobe -r iwlmvm iwlwifi; lsmod | grep -c iwl
sleep 60
