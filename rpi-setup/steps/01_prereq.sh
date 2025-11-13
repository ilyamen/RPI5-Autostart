#!/usr/bin/env bash
set -euo pipefail

echo "[01] Проверка окружения и установка базовых пакетов..."

# Немного sanity-check
if ! uname -m | grep -q "aarch64"; then
  echo "[01] Предупреждение: это не arm64, но продолжаю."
fi

# Проверяем наличие nvme
if [[ ! -b /dev/nvme0n1 ]]; then
  echo "[01] NVMe /dev/nvme0n1 не найден. Подключи SSD перед запуском следующих шагов."
  exit 1
fi

apt-get update -y
apt-get install -y parted rsync curl

echo "[01] prereq OK."
