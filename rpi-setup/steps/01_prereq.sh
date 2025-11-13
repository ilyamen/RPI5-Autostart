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

PACKAGES=(
  parted rsync curl wget git
  htop iotop iftop ncdu vim
  net-tools dnsutils lm-sensors
  smartmontools ntp bc
)

echo "[01] Обновление списка пакетов..."
apt-get update -y

echo "[01] Установка ${#PACKAGES[@]} пакетов..."
apt-get install -y "${PACKAGES[@]}"

echo "[01] ✅ Установлено пакетов: ${#PACKAGES[@]}"

# Включаем и запускаем NTP для синхронизации времени
systemctl enable --now systemd-timesyncd
echo "[01] NTP синхронизация включена."

# Обновление EEPROM (важно для RPI5 - новые фичи, исправления, стабильность)
echo "[01] Проверка и обновление EEPROM..."
if command -v rpi-eeprom-update >/dev/null 2>&1; then
  CURRENT_EEPROM=$(rpi-eeprom-update 2>&1)
  echo "[01] Текущая версия EEPROM:"
  echo "$CURRENT_EEPROM" | head -5
  
  if echo "$CURRENT_EEPROM" | grep -q "UPDATE AVAILABLE"; then
    echo "[01] Доступно обновление EEPROM, устанавливаю..."
    rpi-eeprom-update -d -a
    echo "[01] ⚠️  EEPROM обновлен, потребуется перезагрузка после всех шагов"
  else
    echo "[01] ✓ EEPROM уже актуальной версии"
  fi
else
  echo "[01] rpi-eeprom-update не найден, пропускаю обновление EEPROM"
fi

# Проверяем температуру (важно для RPI5)
echo ""
echo "[01] Проверка системы..."
if command -v vcgencmd >/dev/null 2>&1; then
  TEMP=$(vcgencmd measure_temp | cut -d= -f2)
  echo "[01] Температура CPU: $TEMP"
fi

# Проверяем доступность NVMe
if [[ -b /dev/nvme0n1 ]]; then
  NVME_SIZE=$(lsblk -no SIZE /dev/nvme0n1 | head -1)
  NVME_MODEL=$(lsblk -no MODEL /dev/nvme0n1 | head -1 | xargs)
  echo "[01] NVMe: $NVME_MODEL ($NVME_SIZE)"
fi

echo ""
echo "======================================"
echo "  ✅ Предварительная настройка завершена"
echo "======================================"
echo "[01] Выполнено:"
echo "  • Проверка окружения: OK"
echo "  • Установлено пакетов: ${#PACKAGES[@]}"
echo "  • NTP синхронизация: включена"
echo "  • EEPROM: проверен и обновлён"
echo ""
echo "[01] Система готова к следующим шагам"
echo "======================================"
