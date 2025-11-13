#!/usr/bin/env bash
set -euo pipefail

echo "[10] Установка k3s (master / server)..."

if systemctl is-active --quiet k3s; then
  echo "[10] k3s уже запущен, пропускаю."
  exit 0
fi

# Оптимизированная установка k3s server для RPI5 8GB
echo ""
echo "======================================"
echo "  📦 Загрузка K3s"
echo "======================================"
echo "Размер: ~70MB"
echo "Время: 1-3 минуты (зависит от интернета)"
echo ""
echo "⚠️  Пожалуйста подождите, не прерывайте процесс..."
echo "======================================"
echo ""

# Определяем версию K3s
K3S_VERSION="v1.33.5+k3s1"
echo "[10] Определение последней стабильной версии K3s..."
LATEST_VERSION=$(curl -s https://update.k3s.io/v1-release/channels/stable | grep -oP '(?<=\"latest\":\")[^\"]*' || echo "$K3S_VERSION")
if [[ -n "$LATEST_VERSION" ]]; then
  K3S_VERSION="$LATEST_VERSION"
fi
echo "[10] Версия: $K3S_VERSION"
echo ""

# Загружаем k3s binary с прогресс-баром
K3S_URL="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-arm64"
echo "[10] Загрузка k3s binary..."
echo "[10] URL: $K3S_URL"
echo ""

# Используем wget для загрузки с прогресс-баром
if ! wget --progress=bar:force:noscroll -O /tmp/k3s-download "$K3S_URL" 2>&1 | stdbuf -oL tr '\r' '\n' | grep --line-buffered -oP '[0-9]+%|[0-9.]+ [KM]B/s'; then
  echo "[10] ❌ Ошибка загрузки k3s binary"
  echo "[10] Попробуйте позже или проверьте интернет-соединение"
  exit 1
fi

echo ""
echo "[10] ✓ K3s binary загружен"
echo ""

# Устанавливаем загруженный binary
sudo install -o root -g root -m 0755 /tmp/k3s-download /usr/local/bin/k3s
rm -f /tmp/k3s-download

echo "[10] Запуск установщика k3s..."
echo ""

# Запускаем установщик с уже загруженным binary
curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_EXEC=" \
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

echo ""

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
