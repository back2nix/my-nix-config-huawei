#!/usr/bin/env bash
# usage: [D=корень] [BOOT=efi] finalize.sh IP NAME LUKS_UUID SYSTEM_PATH
set -euxo pipefail
IP=$1 NAME=$2 U=$3 SYS=$4 D=${D:-/dev/nvme0n1p2} BOOT=${BOOT:-/dev/nvme0n1p1}
S="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$IP"
$S "grep -q ENC_DONE /root/enc.log"
$S "set -e; D=$D
  cryptsetup luksUUID -q --uuid $U \$D
  [ \$(cryptsetup luksUUID \$D) = $U ]
  rm -f /root/luks-header-$NAME.img
  cryptsetup luksHeaderBackup \$D --header-backup-file /root/luks-header-$NAME.img
  cryptsetup status cryptroot >/dev/null 2>&1 || cryptsetup open --key-file /root/pw \$D cryptroot
  mountpoint -q /mnt || mount /dev/mapper/cryptroot /mnt
  mountpoint -q /mnt/boot || mount $BOOT /mnt/boot
  df -h /mnt /mnt/boot"
$S "cat /root/luks-header-$NAME.img" > ~/luks-headers/luks-header-$NAME.img
ls -la ~/luks-headers/luks-header-$NAME.img
NIX_SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
  nix copy --no-check-sigs --to "ssh://root@$IP?remote-store=local?root=/mnt" "$SYS"
$S "set -e; nixos-install --no-root-passwd --no-channel-copy --system $SYS
  ls /mnt/boot/loader/entries | tail -3
  grep -l $U /mnt/boot/EFI/nixos/* >/dev/null 2>&1 || true
  sync; umount -R /mnt; cryptsetup close cryptroot; echo FINAL_OK"
