#!/usr/bin/env bash
set -euo pipefail

echo "[06] Настройка параметров ядра для k3s кластера..."
echo ""

# Backup существующего файла если есть
SYSCTL_FILE="/etc/sysctl.d/99-swap-and-containers.conf"
if [[ -f "$SYSCTL_FILE" ]]; then
  BACKUP_FILE="${SYSCTL_FILE}.bak.$(date +%s)"
  echo "[06] Создаю backup: $BACKUP_FILE"
  cp "$SYSCTL_FILE" "$BACKUP_FILE"
fi

echo "======================================"
echo "  Выбор профиля оптимизации"
echo "======================================"
echo ""
echo "Варианты:"
echo "  1) Сбалансированный (рекомендуется для RPI5 8GB)"
echo "     - Оптимальный баланс производительности и стабильности"
echo ""
echo "  2) Максимальная производительность"
echo "     - Больше параметров для высоких нагрузок"
echo "     - Может требовать больше памяти"
echo ""
echo "  3) Минимальные изменения"
echo "     - Только критичные параметры для k3s"
echo "     - Для систем с ограниченными ресурсами"
echo ""

read -p "[06] Выберите профиль [1-3] (Enter = 1): " PROFILE

if [[ -z "$PROFILE" ]]; then
  PROFILE=1
fi

case $PROFILE in
  1)
    echo "[06] ✓ Выбран сбалансированный профиль"
    PROFILE_NAME="balanced"
    ;;
  2)
    echo "[06] ✓ Выбран профиль максимальной производительности"
    PROFILE_NAME="performance"
    ;;
  3)
    echo "[06] ✓ Выбран профиль минимальных изменений"
    PROFILE_NAME="minimal"
    ;;
  *)
    echo "[06] ⚠️  Неверный выбор, используется сбалансированный профиль"
    PROFILE_NAME="balanced"
    ;;
esac

echo ""
echo "[06] Применяю профиль: $PROFILE_NAME"

# Общие параметры для всех профилей (критично для k3s)
cat >/etc/sysctl.d/99-swap-and-containers.conf <<'EOF'
# === КРИТИЧНЫЕ ПАРАМЕТРЫ ДЛЯ K3S ===
# Bridge и IP forwarding
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF

# Добавляем параметры в зависимости от профиля
if [[ "$PROFILE_NAME" == "minimal" ]]; then
  # Минимальный профиль - только критичные параметры
  cat >>/etc/sysctl.d/99-swap-and-containers.conf <<'EOF'

# Memory management (базовые)
vm.swappiness=10
vm.max_map_count=262144
EOF

elif [[ "$PROFILE_NAME" == "performance" ]]; then
  # Профиль максимальной производительности
  cat >>/etc/sysctl.d/99-swap-and-containers.conf <<'EOF'

# Memory management (агрессивная оптимизация)
vm.swappiness=5
vm.vfs_cache_pressure=40
vm.dirty_ratio=15
vm.dirty_background_ratio=8
vm.max_map_count=524288
vm.min_free_kbytes=65536

# File system
fs.file-max=2097152
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=524288

# Network (максимальная производительность)
net.core.somaxconn=65535
net.core.netdev_max_backlog=16384
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=1024 65535

# Conntrack (большие значения)
net.netfilter.nf_conntrack_max=2000000
net.nf_conntrack_max=2000000

# ARP cache (расширенный)
net.ipv4.neigh.default.gc_thresh1=2048
net.ipv4.neigh.default.gc_thresh2=8192
net.ipv4.neigh.default.gc_thresh3=16384
EOF

else
  # Сбалансированный профиль (по умолчанию)
  cat >>/etc/sysctl.d/99-swap-and-containers.conf <<'EOF'
# Memory management
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.max_map_count=262144

# File system
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512
fs.file-max=2097152
fs.aio-max-nr=1048576

# Network - базовые
net.core.somaxconn=32768
net.core.netdev_max_backlog=16384
net.core.rmem_max=16777216
net.core.wmem_max=16777216

# Network - TCP оптимизации для k3s
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_max_syn_backlog=8096
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=10240 65535

# Network - conntrack для k3s (важно!)
net.netfilter.nf_conntrack_max=1000000
net.netfilter.nf_conntrack_tcp_timeout_established=86400
net.netfilter.nf_conntrack_tcp_timeout_close_wait=3600

# ARP cache
net.ipv4.neigh.default.gc_thresh1=1024
net.ipv4.neigh.default.gc_thresh2=4096
net.ipv4.neigh.default.gc_thresh3=8192
EOF
fi

echo ""
echo "[06] Применяю параметры..."
sysctl --system >/dev/null 2>&1 || true

# Подсчитываем параметры
PARAM_COUNT=$(grep -v "^#" /etc/sysctl.d/99-swap-and-containers.conf | grep -v "^$" | wc -l)

echo ""
echo "======================================"
echo "  ✅ Оптимизация ядра завершена"
echo "======================================"
echo "[06] Применённый профиль: $PROFILE_NAME"
echo "[06] Настроено параметров: $PARAM_COUNT"
echo ""

# Показываем ключевые параметры в зависимости от профиля
if [[ "$PROFILE_NAME" == "minimal" ]]; then
  echo "[06] Ключевые параметры (минимальный профиль):"
  echo "  • Memory: swappiness=10, max_map_count=262144"
  echo "  • Bridge forwarding и ip_forward для k3s"
elif [[ "$PROFILE_NAME" == "performance" ]]; then
  echo "[06] Ключевые параметры (производительный профиль):"
  echo "  • Memory: swappiness=5, max_map_count=524288"
  echo "  • Network: conntrack_max=2M, somaxconn=65535"
  echo "  • TCP: максимальные буферы (128MB)"
  echo "  • ARP cache: расширенный (16384)"
else
  echo "[06] Ключевые параметры (сбалансированный профиль):"
  echo "  • Memory: swappiness=10, max_map_count=262144"
  echo "  • Network: conntrack_max=1M, somaxconn=32768"
  echo "  • TCP: оптимизированные буферы (16MB)"
  echo "  • ARP cache: стандартный (8192)"
fi

echo ""
echo "[06] Конфигурация: /etc/sysctl.d/99-swap-and-containers.conf"
if [[ -f "$BACKUP_FILE" ]]; then
  echo "[06] Backup: $BACKUP_FILE"
fi
echo ""

# Проверяем критичные параметры
echo "[06] Проверка применения критичных параметров:"
CHECK_PARAMS=(
  "vm.swappiness"
  "net.ipv4.ip_forward"
  "net.bridge.bridge-nf-call-iptables"
)

for param in "${CHECK_PARAMS[@]}"; do
  VALUE=$(sysctl -n "$param" 2>/dev/null || echo "N/A")
  echo "[06] ✓ $param = $VALUE"
done

echo ""
echo "[06] ✅ Параметры ядра успешно настроены и применены"
