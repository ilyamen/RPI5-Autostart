#!/usr/bin/env bash
set -euo pipefail

echo "[11] Установка k3s (worker / agent)..."

if [[ -z "${K3S_URL:-}" || -z "${K3S_TOKEN:-}" ]]; then
  echo "[11] ❌ Нужно задать переменные окружения K3S_URL и K3S_TOKEN."
  echo "    Пример:"
  echo "    K3S_URL=https://MASTER_IP:6443 \\"
  echo "    K3S_TOKEN=xxx \\"
  echo "      ./run.sh worker"
  exit 1
fi

if systemctl is-active --quiet k3s-agent; then
  echo "[11] ✅ k3s-agent уже запущен, пропускаю."
  exit 0
fi

echo ""
echo "======================================"
echo "  📦 Загрузка K3s Worker"
echo "======================================"
echo "Размер: ~70MB"
echo "Время: 1-3 минуты (зависит от интернета)"
echo ""
echo "⚠️  Пожалуйста подождите, не прерывайте процесс..."
echo "======================================"
echo ""
echo "[11] Master URL: $K3S_URL"
echo "[11] Токен: ${K3S_TOKEN:0:20}... (скрыт)"
echo ""

# Определяем версию K3s (такую же как на мастере)
K3S_VERSION="v1.33.5+k3s1"
echo "[11] Определение версии K3s..."
LATEST_VERSION=$(curl -s https://update.k3s.io/v1-release/channels/stable | grep -oP '(?<="latest":")[^"]*' || echo "$K3S_VERSION")
if [[ -n "$LATEST_VERSION" && "$LATEST_VERSION" != "null" ]]; then
  K3S_VERSION="$LATEST_VERSION"
fi
echo "[11] Версия: $K3S_VERSION"
echo ""

# Загружаем k3s binary с прогресс-баром
K3S_URL_DOWNLOAD="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-arm64"
echo "[11] Загрузка k3s binary..."
echo "[11] URL: $K3S_URL_DOWNLOAD"
echo ""

# Используем wget для загрузки с прогресс-баром
if ! wget --progress=bar:force -O /tmp/k3s-download "$K3S_URL_DOWNLOAD"; then
  echo ""
  echo "[11] ❌ Ошибка загрузки k3s binary"
  echo "[11] Попробуйте позже или проверьте интернет-соединение"
  exit 1
fi

echo ""
echo "[11] ✓ K3s binary загружен"
echo ""

# Устанавливаем загруженный binary
sudo install -o root -g root -m 0755 /tmp/k3s-download /usr/local/bin/k3s
rm -f /tmp/k3s-download

echo "[11] Запуск установщика k3s agent..."
echo ""

# Запускаем установщик с уже загруженным binary
curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_DOWNLOAD=true K3S_URL="$K3S_URL" K3S_TOKEN="$K3S_TOKEN" sh -

# Даем время на запуск
echo "[11] Ожидаю запуска k3s-agent..."
sleep 5

# Проверяем статус сервиса
if systemctl is-active --quiet k3s-agent; then
  echo "[11] ✅ k3s-agent успешно запущен"
else
  echo "[11] ⚠️  k3s-agent не запустился, проверяю логи..."
  journalctl -u k3s-agent -n 20 --no-pager
  exit 1
fi

echo ""
echo "======================================"
echo "  ✅ Worker подключен к кластеру!"
echo "======================================"
echo ""
echo "[11] Проверка подключения к мастеру..."

# Даем еще время на регистрацию в кластере
sleep 3

# Проверяем что нода видна в кластере (если kubectl доступен)
if command -v kubectl >/dev/null 2>&1; then
  HOSTNAME=$(hostname)
  echo "[11] Этот узел: $HOSTNAME"
  echo ""
  echo "[11] Статус ноды в кластере:"
  kubectl get nodes 2>/dev/null || echo "[11] kubectl недоступен, проверьте на мастере"
else
  echo "[11] kubectl не установлен (это нормально для worker-ноды)"
  echo "[11] Проверьте подключение на мастере командой: kubectl get nodes"
fi

echo ""
echo "======================================"
echo "  💡 Полезные команды"
echo "======================================"
echo "Проверить статус:"
echo "  sudo systemctl status k3s-agent"
echo ""
echo "Просмотр логов:"
echo "  sudo journalctl -u k3s-agent -f"
echo ""
echo "На мастере проверить:"
echo "  kubectl get nodes"
echo "  kubectl get pods --all-namespaces"
echo "======================================"
