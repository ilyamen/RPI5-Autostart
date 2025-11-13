#!/usr/bin/env bash
set -euo pipefail

echo "[12] Установка Web UI для Kubernetes..."
echo ""

# выбираем kubectl
if command -v kubectl >/dev/null 2>&1; then
  KUBECTL=kubectl
elif command -v k3s >/dev/null 2>&1; then
  KUBECTL="k3s kubectl"
else
  echo "[12] Не найден kubectl или k3s. Убедись, что k3s master установлен."
  exit 1
fi

echo "====================================="
echo "  Выбор Web UI для кластера"
echo "====================================="
echo ""
echo "Варианты:"
echo "  1) Kubernetes Dashboard (официальный)"
echo "     - Официальный UI от Kubernetes"
echo "     - Минималистичный интерфейс"
echo "     - Доступ через токен"
echo ""
echo "  2) Portainer (рекомендуется)"
echo "     - Удобный современный интерфейс"
echo "     - Поддержка Docker + Kubernetes"
echo "     - Простая авторизация"
echo ""
echo "  3) Оба (Dashboard + Portainer)"
echo "     - Установить оба интерфейса"
echo ""

read -p "[12] Выберите вариант [1-3] (Enter = 2): " UI_CHOICE

if [[ -z "$UI_CHOICE" ]]; then
  UI_CHOICE=2
fi

echo ""
echo "[12] Проверка доступа к кластеру..."
$KUBECTL get nodes
echo ""

# Функция установки Kubernetes Dashboard
install_k8s_dashboard() {
  echo "[12] Установка Kubernetes Dashboard..."
  
  $KUBECTL apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
  
  echo "[12] Создание admin-пользователя для Dashboard..."
  
  cat <<EOF | $KUBECTL apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
  
  echo "[12] ✓ Kubernetes Dashboard установлен"
}

# Функция установки Portainer
install_portainer() {
  echo "[12] Установка Portainer..."
  
  # Создаем namespace
  $KUBECTL create namespace portainer 2>/dev/null || true
  
  # Применяем манифест Portainer
  $KUBECTL apply -n portainer -f https://downloads.portainer.io/ce2-19/portainer.yaml
  
  # Ждем пока поднимется
  echo "[12] Ожидание запуска Portainer..."
  sleep 5
  
  # Изменяем тип сервиса на NodePort с фиксированным портом
  $KUBECTL patch svc portainer -n portainer -p '{"spec":{"type":"NodePort","ports":[{"port":9443,"targetPort":9443,"nodePort":30777,"protocol":"TCP","name":"https"},{"port":9000,"targetPort":9000,"nodePort":30776,"protocol":"TCP","name":"http"},{"port":8000,"targetPort":8000,"nodePort":30778,"protocol":"TCP","name":"edge"}]}}'
  
  echo "[12] ✓ Portainer установлен"
}

# Выполняем установку в зависимости от выбора
case $UI_CHOICE in
  1)
    echo "[12] ✓ Выбран: Kubernetes Dashboard"
    echo ""
    install_k8s_dashboard
    ;;
  2)
    echo "[12] ✓ Выбран: Portainer"
    echo ""
    install_portainer
    ;;
  3)
    echo "[12] ✓ Выбран: Оба (Dashboard + Portainer)"
    echo ""
    install_k8s_dashboard
    echo ""
    install_portainer
    ;;
  *)
    echo "[12] ❌ Неверный выбор"
    exit 1
    ;;
esac

echo ""
echo "====================================="
echo "  ✅ Web UI установлен!"
echo "====================================="
echo ""

# Получаем IP мастера
MASTER_IP=$(hostname -I | awk '{print $1}')

# Показываем инструкции в зависимости от выбора
if [[ "$UI_CHOICE" == "1" || "$UI_CHOICE" == "3" ]]; then
  echo "📊 Kubernetes Dashboard:"
  echo ""
  echo "🔑 Получить токен:"
  echo "  kubectl -n kubernetes-dashboard create token admin-user"
  echo ""
  echo "🌐 Доступ (через port-forward):"
  echo "  kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard 8443:443 --address=0.0.0.0"
  echo "  Затем: https://${MASTER_IP}:8443"
  echo ""
  echo "💡 Совет: Запустите скрипт 13 для публикации через NodePort"
  echo "====================================="
fi

if [[ "$UI_CHOICE" == "2" || "$UI_CHOICE" == "3" ]]; then
  if [[ "$UI_CHOICE" == "3" ]]; then
    echo ""
  fi
  echo "🐳 Portainer:"
  echo ""
  echo "🌐 Доступ:"
  echo "  HTTPS: https://${MASTER_IP}:30777"
  echo "  HTTP:  http://${MASTER_IP}:30776"
  echo ""
  echo "👤 Первый вход:"
  echo "  1. Откройте https://${MASTER_IP}:30777 в браузере"
  echo "  2. Создайте admin пользователя (username + password)"
  echo "  3. Выберите 'Get Started' для локального кластера"
  echo ""
  echo "⚠️  При первом посещении:"
  echo "  - Браузер покажет предупреждение о сертификате"
  echo "  - Нажмите 'Advanced' -> 'Proceed' или 'Продолжить'"
  echo "====================================="
fi

echo ""
echo "💡 Полезные команды:"
echo "  kubectl get pods -A              - все поды"
echo "  kubectl get svc -A               - все сервисы"
echo "  kubectl -n portainer get pods    - статус Portainer (если установлен)"
echo "  kubectl -n kubernetes-dashboard get pods  - статус Dashboard (если установлен)"
echo ""
