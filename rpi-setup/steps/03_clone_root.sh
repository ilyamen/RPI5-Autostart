#!/usr/bin/env bash
set -euo pipefail

DISK="/dev/nvme0n1"
PART="${DISK}p1"
SSD_MOUNT="/mnt/ssd"

echo "[03] Копирование rootfs на $PART"

if [[ ! -b "$PART" ]]; then
  echo "[03] ❌ Раздел $PART не найден, сначала запусти шаг 02."
  exit 1
fi

# Проверяем доступное место
echo "[03] Проверка дискового пространства..."
SOURCE_SIZE=$(df -h / | tail -1 | awk '{print $3}')
TARGET_SIZE=$(df -h "$PART" | tail -1 | awk '{print $2}')
echo "[03] Размер источника (/): $SOURCE_SIZE"
echo "[03] Размер назначения ($PART): $TARGET_SIZE"

mkdir -p "$SSD_MOUNT"
if ! mount | grep -q " $SSD_MOUNT "; then
  echo "[03] Монтирую $PART в $SSD_MOUNT..."
  mount "$PART" "$SSD_MOUNT"
fi

echo ""
echo "======================================"
echo "  Начинаю копирование rootfs"
echo "======================================"
echo "[03] Это может занять 5-15 минут в зависимости от размера данных"
echo "[03] Прогресс копирования:"
echo ""

START_TIME=$(date +%s)

# Rsync с прогрессом
rsync -aHAX \
  --info=progress2 \
  --info=name0 \
  --exclude='/boot/*' \
  --exclude='/dev/*' \
  --exclude='/proc/*' \
  --exclude='/sys/*' \
  --exclude='/run/*' \
  --exclude='/tmp/*' \
  --exclude='/mnt/*' \
  --exclude='/lost+found' \
  / "$SSD_MOUNT"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "======================================"
echo "  ✅ Копирование завершено успешно!"
echo "======================================"
echo "[03] Время выполнения: ${MINUTES}м ${SECONDS}с"
echo ""

# Проверяем что основные директории скопированы
echo "[03] Проверка целостности копирования..."
CRITICAL_DIRS=("/etc" "/usr" "/var" "/home")
ALL_OK=true

for dir in "${CRITICAL_DIRS[@]}"; do
  if [[ -d "${SSD_MOUNT}${dir}" ]]; then
    SIZE=$(du -sh "${SSD_MOUNT}${dir}" 2>/dev/null | awk '{print $1}')
    echo "[03] ✓ ${dir}: ${SIZE}"
  else
    echo "[03] ❌ ${dir}: НЕ НАЙДЕН!"
    ALL_OK=false
  fi
done

echo ""
if [[ "$ALL_OK" == "true" ]]; then
  echo "[03] ✅ Все критичные директории скопированы корректно"
  echo "[03] SSD готов к переключению на следующем шаге"
else
  echo "[03] ⚠️  Обнаружены проблемы при копировании!"
  exit 1
fi
