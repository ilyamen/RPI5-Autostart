#!/usr/bin/env bash
set -euo pipefail

DISK="/dev/nvme0n1"
PART="${DISK}p1"
SSD_MOUNT="/mnt/ssd"
CMDLINE="/boot/firmware/cmdline.txt"

echo "[04] Переключение root на NVMe"

if [[ ! -b "$PART" ]]; then
  echo "[04] Раздел $PART не найден."
  exit 1
fi

mkdir -p "$SSD_MOUNT"
mount | grep -q " $SSD_MOUNT " || mount "$PART" "$SSD_MOUNT"

SSD_UUID=$(blkid -s UUID -o value "$PART")
SSD_PARTUUID=$(blkid -s PARTUUID -o value "$PART")

if [[ -z "${SSD_UUID:-}" || -z "${SSD_PARTUUID:-}" ]]; then
  echo "[04] Не смог получить UUID/PARTUUID для $PART"
  exit 1
fi

echo "[04] SSD UUID: $SSD_UUID"
echo "[04] SSD PARTUUID: $SSD_PARTUUID"

# --- cmdline.txt ---
if [[ ! -f "$CMDLINE" ]]; then
  echo "[04] $CMDLINE не найден"
  exit 1
fi

cp "$CMDLINE" "${CMDLINE}.bak.$(date +%s)"

if grep -q "root=PARTUUID=" "$CMDLINE"; then
  sed -i "s#root=PARTUUID=[^ ]*#root=PARTUUID=${SSD_PARTUUID}#g" "$CMDLINE"
elif grep -q "root=UUID=" "$CMDLINE"; then
  sed -i "s#root=UUID=[^ ]*#root=UUID=${SSD_UUID}#g" "$CMDLINE"
else
  line=$(cat "$CMDLINE")
  echo "root=PARTUUID=${SSD_PARTUUID} ${line}" > "$CMDLINE"
fi

echo "[04] Новый cmdline.txt:"
cat "$CMDLINE"

# --- fstab на SSD ---
FSTAB_SSD="${SSD_MOUNT}/etc/fstab"

if [[ ! -f "$FSTAB_SSD" ]]; then
  echo "[04] fstab на SSD не найден: $FSTAB_SSD"
  exit 1
fi

cp "$FSTAB_SSD" "${FSTAB_SSD}.bak.$(date +%s)"

awk -v uuid="$SSD_UUID" '
  $2 == "/" {
    print "UUID=" uuid "  /  ext4  defaults,noatime  0 1"
    next
  }
  { print }
' "$FSTAB_SSD" > "${FSTAB_SSD}.new"

mv "${FSTAB_SSD}.new" "$FSTAB_SSD"

echo "[04] Новый fstab на SSD:"
cat "$FSTAB_SSD"

echo "[04] Готово. Теперь можно будет перезагружаться в root с NVMe."
