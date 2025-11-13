#!/usr/bin/env bash
set -euo pipefail

echo "[05] Настройка ZRAM swap..."

cat >/usr/local/sbin/zram-start <<'EOF'
#!/bin/sh
modprobe zram || exit 1

SIZE_BYTES=$((2 * 1024 * 1024 * 1024)) # 2GB
echo zstd > /sys/block/zram0/comp_algorithm 2>/dev/null || true
echo "${SIZE_BYTES}" > /sys/block/zram0/disksize

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
systemctl restart zram.service

echo "[05] ZRAM настроен:"
swapon --show || true
