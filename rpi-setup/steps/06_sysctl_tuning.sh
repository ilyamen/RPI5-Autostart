#!/usr/bin/env bash
set -euo pipefail

echo "[06] Настройка sysctl..."

cat >/etc/sysctl.d/99-swap-and-containers.conf <<'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512
net.core.somaxconn=1024
EOF

sysctl --system || true

echo "[06] sysctl применён."
