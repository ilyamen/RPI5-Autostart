#!/usr/bin/env bash
set -euo pipefail

DISK="/dev/nvme0n1"
PART="${DISK}p1"
SSD_MOUNT="/mnt/ssd"

echo "[03] Копирование rootfs на $PART"

if [[ ! -b "$PART" ]]; then
  echo "[03] Раздел $PART не найден, сначала запусти шаг 02."
  exit 1
fi

mkdir -p "$SSD_MOUNT"
mount | grep -q " $SSD_MOUNT " || mount "$PART" "$SSD_MOUNT"

echo "[03] Rsync корня на SSD..."
rsync -aHAX \
  --exclude='/boot/*' \
  --exclude='/dev/*' \
  --exclude='/proc/*' \
  --exclude='/sys/*' \
  --exclude='/run/*' \
  --exclude='/tmp/*' \
  --exclude='/mnt/*' \
  --exclude='/lost+found' \
  / "$SSD_MOUNT"

echo "[03] Копирование завершено."
