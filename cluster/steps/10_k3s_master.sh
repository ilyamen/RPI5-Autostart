#!/usr/bin/env bash
set -euo pipefail

echo "[10] Установка k3s (master / server)..."

if systemctl is-active --quiet k3s; then
  echo "[10] k3s уже запущен, пропускаю."
  exit 0
fi

# Оптимизированная установка k3s server для RPI5 8GB
# Отключаем traefik и servicelb (можем установить свои позже)
# Включаем metrics-server для мониторинга
echo "[10] Установка k3s с оптимизациями для RPI5..."

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=" \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644 \
  --kube-apiserver-arg=default-not-ready-toleration-seconds=30 \
  --kube-apiserver-arg=default-unreachable-toleration-seconds=30 \
  --kube-controller-arg=node-monitor-period=20s \
  --kube-controller-arg=node-monitor-grace-period=20s \
  --kubelet-arg=max-pods=110 \
  --kubelet-arg=eviction-hard=memory.available<500Mi \
  --kubelet-arg=eviction-soft=memory.available<1Gi \
  --kubelet-arg=eviction-soft-grace-period=memory.available=1m30s" sh -

echo "[10] ✓ k3s master установлен с оптимизациями"

# Настраиваем kubectl для root пользователя
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chmod 600 ~/.kube/config

# Добавляем алиас для kubectl
if ! grep -q "alias k=" /root/.bashrc 2>/dev/null; then
  echo "alias k='kubectl'" >> /root/.bashrc
  echo "[10] ✓ Добавлен алиас 'k' для kubectl"
fi

echo ""
echo "======================================"
echo "  K3s Master установлен!"
echo "======================================"
echo ""
echo "📋 kubeconfig: /etc/rancher/k3s/k3s.yaml"
echo "   Также скопирован в: ~/.kube/config"
echo ""
echo "🔑 Node token для воркеров:"
cat /var/lib/rancher/k3s/server/node-token || true
echo ""
echo "🌐 IP мастера для воркеров:"
MASTER_IP=$(hostname -I | awk '{print $1}')
echo "   $MASTER_IP"
echo ""
echo "📝 K3S_URL для воркеров: https://${MASTER_IP}:6443"
echo ""
echo "💡 Полезные команды:"
echo "   kubectl get nodes          - список нод"
echo "   kubectl get pods -A        - все поды"
echo "   kubectl top nodes          - использование ресурсов"
echo "   k                          - алиас для kubectl"
echo ""
echo "⚠️  Traefik и ServiceLB отключены для гибкости настройки"
echo "   Можно установить позже через Helm"
echo "======================================"
