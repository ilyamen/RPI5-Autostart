#!/usr/bin/env bash
set -euo pipefail

echo "[10] Установка k3s (master / server)..."

if systemctl is-active --quiet k3s; then
  echo "[10] k3s уже запущен, пропускаю."
  exit 0
fi

# Базовая установка k3s server
curl -sfL https://get.k3s.io | sh -

echo "[10] k3s master установлен."
echo "[10] kubeconfig на этой машине: /etc/rancher/k3s/k3s.yaml"
echo "[10] node-token для воркеров:"
cat /var/lib/rancher/k3s/server/node-token || true

echo
echo "[10] IP мастера для воркеров: "
hostname -I | awk '{print $1}'
echo "[10] Этот IP будешь использовать как K3S_URL, вида: https://IP:6443"
