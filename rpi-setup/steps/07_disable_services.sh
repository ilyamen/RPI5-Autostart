#!/usr/bin/env bash
set -euo pipefail

echo "[07] Отключение ненужных сервисов..."
echo ""

# Определяем сервисы с описаниями
declare -A SERVICE_DESCRIPTIONS
SERVICE_DESCRIPTIONS=(
  ["bluetooth.service"]="Bluetooth (уже отключен в config.txt)"
  ["hciuart.service"]="Bluetooth UART"
  ["bluealsa.service"]="Bluetooth Audio"
  ["triggerhappy.service"]="Hotkey daemon (не нужен на сервере)"
  ["avahi-daemon.service"]="mDNS/DNS-SD (локальное обнаружение сети)"
  ["ModemManager.service"]="Modem Manager (управление модемами)"
  ["wpa_supplicant.service"]="WiFi (отключи если используешь только Ethernet)"
)

# Список рекомендуемых для отключения
RECOMMENDED_SERVICES=(
  "bluetooth.service"
  "hciuart.service"
  "bluealsa.service"
  "triggerhappy.service"
  "avahi-daemon.service"
  "ModemManager.service"
)

# Опциональные (требуют подтверждения)
OPTIONAL_SERVICES=(
  "wpa_supplicant.service"
)

echo "======================================"
echo "  Выбор сервисов для отключения"
echo "======================================"
echo ""
echo "Варианты:"
echo "  1) Автоматический (рекомендуется) - отключить все ненужные"
echo "  2) Выборочное отключение - выбрать что отключать"
echo "  3) Пропустить этот шаг"
echo ""

read -p "[07] Выберите вариант [1-3] (Enter = 1): " CHOICE

if [[ -z "$CHOICE" ]]; then
  CHOICE=1
fi

SERVICES_TO_DISABLE=()

case $CHOICE in
  1)
    # Автоматический режим - отключаем все рекомендуемые
    SERVICES_TO_DISABLE=("${RECOMMENDED_SERVICES[@]}")
    echo "[07] ✓ Автоматический режим: отключаются все рекомендуемые сервисы"
    ;;
    
  2)
    # Выборочный режим
    echo ""
    echo "[07] Выберите сервисы для отключения (y/n для каждого):"
    echo ""
    
    # Показываем рекомендуемые
    echo "Рекомендуемые к отключению:"
    for service in "${RECOMMENDED_SERVICES[@]}"; do
      if systemctl list-unit-files | grep -q "^${service}"; then
        STATUS=$(systemctl is-enabled "$service" 2>/dev/null || echo "disabled")
        echo "  • $service - ${SERVICE_DESCRIPTIONS[$service]}"
        echo "    Текущий статус: $STATUS"
        read -p "    Отключить? [Y/n]: " CONFIRM
        if [[ -z "$CONFIRM" ]] || [[ "$CONFIRM" =~ ^[Yy] ]]; then
          SERVICES_TO_DISABLE+=("$service")
          echo "    ✓ Будет отключен"
        else
          echo "    - Пропущен"
        fi
        echo ""
      fi
    done
    
    # Показываем опциональные
    echo "Опциональные (требуют внимания):"
    for service in "${OPTIONAL_SERVICES[@]}"; do
      if systemctl list-unit-files | grep -q "^${service}"; then
        STATUS=$(systemctl is-enabled "$service" 2>/dev/null || echo "disabled")
        echo "  • $service - ${SERVICE_DESCRIPTIONS[$service]}"
        echo "    Текущий статус: $STATUS"
        read -p "    Отключить? [y/N]: " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy] ]]; then
          SERVICES_TO_DISABLE+=("$service")
          echo "    ✓ Будет отключен"
        else
          echo "    - Пропущен"
        fi
        echo ""
      fi
    done
    ;;
    
  3)
    echo "[07] Пропуск отключения сервисов"
    exit 0
    ;;
    
  *)
    echo "[07] ⚠️  Неверный выбор, используется автоматический режим"
    SERVICES_TO_DISABLE=("${RECOMMENDED_SERVICES[@]}")
    ;;
esac

if [[ ${#SERVICES_TO_DISABLE[@]} -eq 0 ]]; then
  echo "[07] Нет сервисов для отключения"
  exit 0
fi

echo ""
echo "======================================"
echo "  Отключение выбранных сервисов"
echo "======================================"
echo ""

DISABLED_COUNT=0

for service in "${SERVICES_TO_DISABLE[@]}"; do
  if systemctl list-unit-files | grep -q "^${service}"; then
    echo "[07] Отключаю $service..."
    set +e
    systemctl disable "$service" >/dev/null 2>&1
    systemctl stop "$service" >/dev/null 2>&1
    set -e
    echo "[07] ✓ $service отключен"
    DISABLED_COUNT=$((DISABLED_COUNT + 1))
  else
    echo "[07] - $service не найден, пропускаю"
  fi
done

# Маскируем некоторые сервисы чтобы они точно не запустились
SERVICES_TO_MASK=(
  "bluetooth.service"
  "hciuart.service"
)

MASKED_COUNT=0

for service in "${SERVICES_TO_MASK[@]}"; do
  if systemctl list-unit-files | grep -q "^${service}"; then
    echo "[07] Маскирую $service..."
    set +e
    systemctl mask "$service" >/dev/null 2>&1
    set -e
    echo "[07] ✓ $service замаскирован"
    MASKED_COUNT=$((MASKED_COUNT + 1))
  fi
done

echo ""
echo "======================================"
echo "  ✅ Оптимизация сервисов завершена"
echo "======================================"
echo "[07] Результаты:"
echo "  • Отключено сервисов: $DISABLED_COUNT"
echo "  • Замаскировано: $MASKED_COUNT"
echo ""
echo "[07] Освобождены ресурсы для k3s кластера"
echo "======================================"
