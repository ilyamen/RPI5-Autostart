#!/usr/bin/env bash
set -euo pipefail

echo "[11] Установка k3s (worker / agent)..."

if [[ -z "${K3S_URL:-}" || -z "${K3S_TOKEN:-}" ]]; then
  echo "[11] Нужно задать переменные окружения K3S_URL и K3S_TOKEN."
  echo "    Пример:"
  echo "    K3S_URL=https://MASTER_IP:6443 \\"
  echo "    K3S_TOKEN=xxx \\"
  echo "      ./run.sh worker"
  exit 1
fi

if systemctl is-active --quiet k3s-agent; then
  echo "[11] k3s-agent уже запущен, пропускаю."
  exit 0
fi

curl -sfL https://get.k3s.io | K3S_URL="$K3S_URL" K3S_TOKEN="$K3S_TOKEN" sh -

echo "[11] k3s worker установлен и подключён к кластеру."
