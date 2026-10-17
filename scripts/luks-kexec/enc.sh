#!/usr/bin/env bash
set -euxo pipefail
# Запускается на целевой машине внутри kexec-образа. Env: ROOT_FS_UUID, TEMP_PASS, NAME, [D].
: "${ROOT_FS_UUID:?}" "${TEMP_PASS:?}" "${NAME:?}"
D=${D:-/dev/nvme0n1p2}
exec > >(tee -a /root/enc.log) 2>&1
blkid $D | grep -q "$ROOT_FS_UUID"
printf %s "$TEMP_PASS" > /root/pw
rc=0; e2fsck -fy $D || rc=$?; echo "e2fsck rc=$rc"; [ $rc -le 1 ]
e2fsck -fn $D
BS=$(dumpe2fs -h $D 2>/dev/null | awk -F: "/^Block size/{print \$2}" | tr -d " ")
BC=$(dumpe2fs -h $D 2>/dev/null | awk -F: "/^Block count/{print \$2}" | tr -d " ")
resize2fs $D $(( BC - 64*1024*1024/BS ))
cryptsetup reencrypt --encrypt --type luks2 --reduce-device-size 32M --batch-mode --key-file /root/pw $D
cryptsetup open --key-file /root/pw $D cryptroot
e2fsck -fy /dev/mapper/cryptroot || [ $? -le 1 ]
resize2fs /dev/mapper/cryptroot
cryptsetup luksHeaderBackup $D --header-backup-file /root/luks-header-$NAME.img
cryptsetup luksUUID $D > /root/luks-uuid
echo ENC_DONE
