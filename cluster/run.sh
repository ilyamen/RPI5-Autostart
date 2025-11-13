#!/usr/bin/env bash
set -euo pipefail

STEPS_DIR="$(dirname "$0")/steps"

usage() {
  cat <<EOF
Usage: $0 [master | worker | dashboard]

  master      - установить k3s server (мастер)
  worker      - установить k3s agent (воркер, требует K3S_URL и K3S_TOKEN)
  dashboard   - установить Kubernetes Dashboard (только на мастере)
EOF
}

show_menu() {
  echo ""
  echo "=============================="
  echo "  Установка k3s кластера"
  echo "=============================="
  echo "1) master    - установить k3s server (мастер-нода)"
  echo "2) worker    - установить k3s agent (воркер-нода)"
  echo "3) dashboard - установить Kubernetes Dashboard"
  echo "0) exit      - выход"
  echo "=============================="
  read -r -p "Выберите действие [1-3,0]: " choice
  
  case "$choice" in
    1)
      echo "master"
      ;;
    2)
      echo "worker"
      ;;
    3)
      echo "dashboard"
      ;;
    0)
      echo ""
      exit 0
      ;;
    *)
      echo "Неверный выбор: $choice"
      exit 1
      ;;
  esac
}

ask_worker_credentials() {
  echo ""
  echo "Для подключения воркера к кластеру необходимы:"
  echo "1. K3S_URL - адрес мастера (например: https://192.168.1.100:6443)"
  echo "2. K3S_TOKEN - токен из /var/lib/rancher/k3s/server/node-token на мастере"
  echo ""
  
  read -r -p "Введите K3S_URL: " k3s_url
  if [[ -z "$k3s_url" ]]; then
    echo "Ошибка: K3S_URL не может быть пустым"
    exit 1
  fi
  
  read -r -p "Введите K3S_TOKEN: " k3s_token
  if [[ -z "$k3s_token" ]]; then
    echo "Ошибка: K3S_TOKEN не может быть пустым"
    exit 1
  fi
  
  export K3S_URL="$k3s_url"
  export K3S_TOKEN="$k3s_token"
}

# Если запущено без аргументов - показываем меню
if [[ $# -eq 0 ]]; then
  ROLE=$(show_menu)
else
  ROLE="$1"
fi

case "$ROLE" in
  master)
    bash "${STEPS_DIR}/10_k3s_master.sh"
    ;;
  worker)
    # Если переменные не заданы - запрашиваем интерактивно
    if [[ -z "${K3S_URL:-}" || -z "${K3S_TOKEN:-}" ]]; then
      ask_worker_credentials
    fi
    bash "${STEPS_DIR}/11_k3s_worker.sh"
    ;;
  dashboard)
    bash "${STEPS_DIR}/12_dashboard.sh"
    ;;
  *)
    usage
    exit 1
    ;;
esac
