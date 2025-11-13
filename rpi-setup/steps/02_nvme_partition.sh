#!/usr/bin/env bash
set -euo pipefail

DISK="/dev/nvme0n1"

echo "[02] Разметка и форматирование $DISK"

if [[ ! -b "$DISK" ]]; then
  echo "[02] Диск $DISK не найден"
  exit 1
fi

echo "[02] ВНИМАНИЕ: все данные на $DISK будут уничтожены."
lsblk "$DISK" || true
read -r -p "[02] Напиши ПРОПИСНЫМИ YES чтобы продолжить: " CONFIRM

if [[ "$CONFIRM" != "YES" ]]; then
  echo "[02] Отмена."
  exit 1
fi

echo "[02] Создаю GPT разметку..."
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary ext4 1MiB 100%

sleep 2

PART="${DISK}p1"
echo "[02] Форматирую $PART в ext4..."
mkfs.ext4 -F "$PART"

# Получаем информацию о разделе
PART_UUID=$(blkid -s UUID -o value "$PART")
PART_SIZE=$(lsblk -no SIZE "$PART")

echo ""
echo "======================================"
echo "  ✅ Разметка NVMe завершена"
echo "======================================"
echo "[02] Диск: $DISK"
echo "[02] Раздел: $PART"
echo "[02] Размер: $PART_SIZE"
echo "[02] UUID: $PART_UUID"
echo "[02] Файловая система: ext4"
echo ""
echo "[02] ✅ Раздел готов к копированию данных"
echo "======================================"
