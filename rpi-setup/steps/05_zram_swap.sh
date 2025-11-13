#!/usr/bin/env bash
set -euo pipefail

echo "[05] Настройка ZRAM swap..."
echo ""

# Получаем общий объем RAM в MB
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
TOTAL_RAM_GB=$(echo "scale=2; $TOTAL_RAM_MB/1024" | bc)
echo "[05] Обнаружено RAM: ${TOTAL_RAM_MB}MB (${TOTAL_RAM_GB}GB)"

# Вычисляем рекомендуемый размер ZRAM
# Логика:
# - До 2GB RAM: 50% от RAM
# - 2-4GB RAM: 100% от RAM
# - 4-8GB RAM: 50% от RAM (т.е. 2-4GB)
# - 8GB+ RAM: 50% от RAM

if [[ $TOTAL_RAM_MB -lt 2048 ]]; then
  RECOMMENDED_ZRAM_MB=$((TOTAL_RAM_MB / 2))
elif [[ $TOTAL_RAM_MB -lt 4096 ]]; then
  RECOMMENDED_ZRAM_MB=$TOTAL_RAM_MB
else
  RECOMMENDED_ZRAM_MB=$((TOTAL_RAM_MB / 2))
fi

RECOMMENDED_ZRAM_GB=$(echo "scale=2; $RECOMMENDED_ZRAM_MB/1024" | bc)

echo ""
echo "======================================"
echo "  Выбор размера ZRAM"
echo "======================================"
echo "[05] Рекомендуемый размер: ${RECOMMENDED_ZRAM_MB}MB (${RECOMMENDED_ZRAM_GB}GB)"
echo ""
echo "Варианты:"
echo "  1) Автоматический (рекомендуется) - ${RECOMMENDED_ZRAM_GB}GB"
echo "  2) Ввести свой размер в MB"
echo "  3) Ввести свой размер в GB"
echo ""

# Интерактивный выбор
read -p "[05] Выберите вариант [1-3] (Enter = 1): " CHOICE

# Если пустой ввод - используем автоматический
if [[ -z "$CHOICE" ]]; then
  CHOICE=1
fi

case $CHOICE in
  1)
    ZRAM_SIZE_MB=$RECOMMENDED_ZRAM_MB
    echo "[05] ✓ Используется автоматический размер: ${ZRAM_SIZE_MB}MB"
    ;;
  2)
    read -p "[05] Введите размер ZRAM в MB (например, 4096): " CUSTOM_MB
    if [[ "$CUSTOM_MB" =~ ^[0-9]+$ ]] && [[ $CUSTOM_MB -gt 0 ]] && [[ $CUSTOM_MB -le $((TOTAL_RAM_MB * 2)) ]]; then
      ZRAM_SIZE_MB=$CUSTOM_MB
      echo "[05] ✓ Установлен пользовательский размер: ${ZRAM_SIZE_MB}MB"
    else
      echo "[05] ⚠️  Некорректное значение, используется автоматический размер"
      ZRAM_SIZE_MB=$RECOMMENDED_ZRAM_MB
    fi
    ;;
  3)
    read -p "[05] Введите размер ZRAM в GB (например, 4): " CUSTOM_GB
    if [[ "$CUSTOM_GB" =~ ^[0-9]+\.?[0-9]*$ ]] && (( $(echo "$CUSTOM_GB > 0" | bc -l) )); then
      ZRAM_SIZE_MB=$(echo "$CUSTOM_GB * 1024" | bc | cut -d. -f1)
      if [[ $ZRAM_SIZE_MB -le $((TOTAL_RAM_MB * 2)) ]]; then
        echo "[05] ✓ Установлен пользовательский размер: ${ZRAM_SIZE_MB}MB (${CUSTOM_GB}GB)"
      else
        echo "[05] ⚠️  Слишком большой размер, используется автоматический"
        ZRAM_SIZE_MB=$RECOMMENDED_ZRAM_MB
      fi
    else
      echo "[05] ⚠️  Некорректное значение, используется автоматический размер"
      ZRAM_SIZE_MB=$RECOMMENDED_ZRAM_MB
    fi
    ;;
  *)
    echo "[05] ⚠️  Неверный выбор, используется автоматический размер"
    ZRAM_SIZE_MB=$RECOMMENDED_ZRAM_MB
    ;;
esac

FINAL_ZRAM_GB=$(echo "scale=2; $ZRAM_SIZE_MB/1024" | bc)
echo ""
echo "[05] Итоговый размер ZRAM: ${ZRAM_SIZE_MB}MB (${FINAL_ZRAM_GB}GB)"

cat >/usr/local/sbin/zram-start <<EOF
#!/bin/sh
# Отключаем существующий swap если есть
swapoff /dev/zram0 2>/dev/null || true

# Загружаем модуль zram
modprobe zram num_devices=1 2>/dev/null || true

# Проверяем что устройство создано
if [ ! -b /dev/zram0 ]; then
  echo "ZRAM устройство не найдено"
  exit 1
fi

# Сбрасываем устройство если оно уже инициализировано
if [ -e /sys/block/zram0/disksize ]; then
  echo 1 > /sys/block/zram0/reset 2>/dev/null || true
fi

# Автоматически вычисленный размер ZRAM: ${ZRAM_SIZE_MB}MB
SIZE_BYTES=\$(($ZRAM_SIZE_MB * 1024 * 1024))

# Устанавливаем алгоритм сжатия
echo zstd > /sys/block/zram0/comp_algorithm 2>/dev/null || echo lzo > /sys/block/zram0/comp_algorithm

# Устанавливаем размер
echo "\${SIZE_BYTES}" > /sys/block/zram0/disksize

# Создаем swap
mkswap /dev/zram0
swapon --priority 100 /dev/zram0
EOF

chmod +x /usr/local/sbin/zram-start

cat >/usr/local/sbin/zram-stop <<'EOF'
#!/bin/sh
swapoff /dev/zram0 2>/dev/null || true
EOF

chmod +x /usr/local/sbin/zram-stop

cat >/etc/systemd/system/zram.service <<'EOF'
[Unit]
Description=ZRAM swap setup
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/zram-start
ExecStop=/usr/local/sbin/zram-stop

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zram.service
# Запускаем сервис (используем start вместо restart для первого запуска)
systemctl start zram.service 2>/dev/null || systemctl restart zram.service 2>/dev/null || true

echo "[05] ZRAM настроен:"
swapon --show || true
