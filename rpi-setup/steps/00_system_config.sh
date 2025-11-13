#!/usr/bin/env bash
set -euo pipefail

echo "[00] Настройка системных параметров для RPI5 + k3s..."

CONFIG_FILE="/boot/firmware/config.txt"
CMDLINE_FILE="/boot/firmware/cmdline.txt"

# Проверяем наличие файлов
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[00] ОШИБКА: $CONFIG_FILE не найден"
  exit 1
fi

if [[ ! -f "$CMDLINE_FILE" ]]; then
  echo "[00] ОШИБКА: $CMDLINE_FILE не найден"
  exit 1
fi

# === config.txt ===
echo "[00] Настройка $CONFIG_FILE..."
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%s)"

# GPU Memory для Lite версии (минимум для серверной работы)
if ! grep -q "^gpu_mem=" "$CONFIG_FILE"; then
  echo "gpu_mem=16" >> "$CONFIG_FILE"
  echo "[00] Установлено gpu_mem=16"
else
  sed -i 's/^gpu_mem=.*/gpu_mem=16/' "$CONFIG_FILE"
  echo "[00] Обновлено gpu_mem=16"
fi

# Отключаем Bluetooth (экономим ресурсы)
if ! grep -q "^dtoverlay=disable-bt" "$CONFIG_FILE"; then
  echo "dtoverlay=disable-bt" >> "$CONFIG_FILE"
  echo "[00] Отключен Bluetooth"
fi

# Отключаем WiFi (если используется Ethernet)
# Раскомментируй следующие строки если нужно:
# if ! grep -q "^dtoverlay=disable-wifi" "$CONFIG_FILE"; then
#   echo "dtoverlay=disable-wifi" >> "$CONFIG_FILE"
#   echo "[00] Отключен WiFi"
# fi

echo "[00] ✓ config.txt настроен"

# === cmdline.txt ===
echo ""
echo "[00] Настройка $CMDLINE_FILE для k3s..."
CMDLINE_BACKUP="${CMDLINE_FILE}.bak.$(date +%s)"
cp "$CMDLINE_FILE" "$CMDLINE_BACKUP"
echo "[00] Backup: $CMDLINE_BACKUP"

# Читаем текущую строку
CMDLINE=$(cat "$CMDLINE_FILE")

# Добавляем cgroup параметры для k3s
NEED_UPDATE=0

if ! echo "$CMDLINE" | grep -q "cgroup_memory=1"; then
  CMDLINE="$CMDLINE cgroup_memory=1"
  NEED_UPDATE=1
  echo "[00] Добавлено cgroup_memory=1"
fi

if ! echo "$CMDLINE" | grep -q "cgroup_enable=memory"; then
  CMDLINE="$CMDLINE cgroup_enable=memory"
  NEED_UPDATE=1
  echo "[00] Добавлено cgroup_enable=memory"
fi

if ! echo "$CMDLINE" | grep -q "cgroup_enable=cpuset"; then
  CMDLINE="$CMDLINE cgroup_enable=cpuset"
  NEED_UPDATE=1
  echo "[00] Добавлено cgroup_enable=cpuset"
fi

# Записываем обратно если были изменения
if [[ $NEED_UPDATE -eq 1 ]]; then
  echo "$CMDLINE" > "$CMDLINE_FILE"
  echo "[00] ✓ cmdline.txt обновлён"
else
  echo "[00] ✓ cmdline.txt уже содержит необходимые параметры"
fi

echo ""
echo "======================================"
echo "  ✅ Системная конфигурация завершена"
echo "======================================"
echo "[00] Применённые настройки:"
echo "  • GPU Memory: 16MB (минимум для сервера)"
echo "  • Bluetooth: отключен"
echo "  • cgroup memory: включен (для k3s)"
echo "  • cgroup cpuset: включен (для k3s)"
echo ""
echo "[00] Backup файлы:"
echo "  • ${CONFIG_FILE}.bak.*"
echo "  • $CMDLINE_BACKUP"
echo ""
if [[ $NEED_UPDATE -eq 1 ]]; then
  echo "[00] ⚠️  ТРЕБУЕТСЯ ПЕРЕЗАГРУЗКА для применения изменений!"
  echo "[00] После reboot запустите: sudo ./run.sh"
else
  echo "[00] ✅ Все параметры уже применены"
fi
echo "======================================"
