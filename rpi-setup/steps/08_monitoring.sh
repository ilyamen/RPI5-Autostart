#!/usr/bin/env bash
set -euo pipefail

echo "[08] Настройка базового мониторинга для RPI5..."

# Создаем скрипт для мониторинга температуры и throttling
cat >/usr/local/bin/rpi-monitor <<'EOF'
#!/bin/bash
# RPI5 Monitoring Script

print_header() {
  echo "======================================"
  echo "  RPI5 System Monitor"
  echo "  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "======================================"
}

get_temp() {
  if command -v vcgencmd >/dev/null 2>&1; then
    TEMP=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
    echo "CPU Temperature: ${TEMP}°C"
    
    # Предупреждение о перегреве
    TEMP_NUM=$(echo "$TEMP" | cut -d. -f1)
    if [[ $TEMP_NUM -gt 80 ]]; then
      echo "⚠️  WARNING: High temperature! Consider adding cooling."
    fi
  fi
}

get_throttle() {
  if command -v vcgencmd >/dev/null 2>&1; then
    THROTTLE=$(vcgencmd get_throttled)
    echo "Throttle Status: $THROTTLE"
    
    # Расшифровка throttle bits
    THROTTLE_HEX=$(echo "$THROTTLE" | cut -d= -f2)
    if [[ "$THROTTLE_HEX" != "0x0" ]]; then
      echo "⚠️  Throttling detected!"
      echo "   Bit 0: Under-voltage detected"
      echo "   Bit 1: ARM frequency capped"
      echo "   Bit 2: Currently throttled"
      echo "   Bit 16: Under-voltage has occurred since boot"
      echo "   Bit 17: Throttling has occurred since boot"
    fi
  fi
}

get_memory() {
  echo ""
  echo "Memory Usage:"
  free -h | grep -E "Mem|Swap"
}

get_disk() {
  echo ""
  echo "Disk Usage (/):"
  df -h / | tail -1
  
  if mountpoint -q /mnt/ssd 2>/dev/null; then
    echo "Disk Usage (/mnt/ssd):"
    df -h /mnt/ssd | tail -1
  fi
}

get_load() {
  echo ""
  echo "System Load:"
  uptime
}

get_network() {
  echo ""
  echo "Network Interfaces:"
  ip -br addr show | grep -v "lo"
}

# Main
print_header
get_temp
get_throttle
get_load
get_memory
get_disk
get_network

# K3s status if installed
if command -v kubectl >/dev/null 2>&1; then
  echo ""
  echo "K3s Cluster Status:"
  kubectl get nodes 2>/dev/null || echo "kubectl not configured or k3s not running"
fi
EOF

chmod +x /usr/local/bin/rpi-monitor

echo "[08] ✓ Создан скрипт /usr/local/bin/rpi-monitor"

# Создаем алиас для удобства
if ! grep -q "alias monitor=" /root/.bashrc 2>/dev/null; then
  echo "alias monitor='/usr/local/bin/rpi-monitor'" >> /root/.bashrc
  echo "[08] ✓ Добавлен алиас 'monitor' в /root/.bashrc"
fi

# Создаем systemd service для логирования температуры
cat >/etc/systemd/system/rpi-temp-monitor.service <<'EOF'
[Unit]
Description=RPI5 Temperature Monitor
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo "$(date +%%Y-%%m-%%d_%%H:%%M:%%S) $(vcgencmd measure_temp | cut -d= -f2)" >> /var/log/rpi-temperature.log'

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/rpi-temp-monitor.timer <<'EOF'
[Unit]
Description=RPI5 Temperature Monitor Timer
Requires=rpi-temp-monitor.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable rpi-temp-monitor.timer
systemctl start rpi-temp-monitor.timer

echo "[08] ✓ Включен мониторинг температуры каждые 5 минут"
echo "[08] Логи температуры: /var/log/rpi-temperature.log"

# Настройка logrotate для логов температуры
cat >/etc/logrotate.d/rpi-temperature <<'EOF'
/var/log/rpi-temperature.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
EOF

echo "[08] ✓ Настроен logrotate для температурных логов"

# Запускаем мониторинг для проверки
echo ""
echo "[08] Текущее состояние системы:"
/usr/local/bin/rpi-monitor

echo ""
echo "[08] Мониторинг настроен."
echo "[08] Используйте команду 'monitor' для просмотра состояния системы."
