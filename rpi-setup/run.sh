#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/rpi-setup.log"
STATE_DIR="/var/local/rpi-setup"
STEPS_DIR="$(dirname "$0")/steps"
CURRENT_STEP_FILE="${STATE_DIR}/current_step"

mkdir -p "$(dirname "$LOG_FILE")" "$STATE_DIR"

# логируем всё
exec > >(tee -a "$LOG_FILE") 2>&1

usage() {
  cat <<EOF
Usage: $0 [all | STEP... | --from N | --continue]

  all         - выполнить все шаги по порядку (интерактивно)
  N ...       - выполнить только указанные шаги (например: 02 05)
  --from N    - выполнить шаги начиная с N до конца (например: --from 03)
  --continue  - продолжить с последнего незавершенного шага после reboot
EOF
}

ALL_STEPS=("00" "01" "02" "03" "04" "05" "06" "07" "08")

# Шаги, после которых требуется перезагрузка
REBOOT_AFTER_STEPS=("00" "04")

ask_confirmation() {
  local step="$1"
  local script_name="$2"
  
  echo ""
  echo "=============================="
  echo "[STEP $step] Готов к выполнению: $script_name"
  echo "=============================="
  
  read -r -p "Продолжить? [Y/n/skip]: " answer
  
  case "$answer" in
    [nN]*)
      echo "[STEP $step] Остановка по запросу пользователя."
      exit 0
      ;;
    [sS]*)
      echo "[STEP $step] Пропуск шага."
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

needs_reboot() {
  local step="$1"
  for reboot_step in "${REBOOT_AFTER_STEPS[@]}"; do
    if [[ "$step" == "$reboot_step" ]]; then
      return 0
    fi
  done
  return 1
}

run_step() {
  local step="$1"
  local interactive="${2:-false}"
  local script
  script=$(ls "${STEPS_DIR}/${step}_"*.sh 2>/dev/null || true)
  local state_file="${STATE_DIR}/${step}.ok"

  if [[ -z "$script" ]]; then
    echo "[STEP $step] Скрипт не найден (${STEPS_DIR}/${step}_*.sh)"
    return 1
  fi

  # Проверяем, не выполнен ли уже шаг
  if [[ -f "$state_file" ]]; then
    echo "[STEP $step] ✅ Уже выполнен ранее, пропускаю."
    return 0
  fi

  # Интерактивное подтверждение
  if [[ "$interactive" == "true" ]]; then
    if ! ask_confirmation "$step" "$(basename "$script")"; then
      return 0  # skip
    fi
  fi

  echo "=============================="
  echo "[STEP $step] Запуск $script"
  echo "=============================="

  # Сохраняем текущий шаг
  echo "$step" > "$CURRENT_STEP_FILE"

  bash "$script"
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    echo "[STEP $step] ✅ OK"
    touch "$state_file"
    
    # Проверяем, нужна ли перезагрузка
    if needs_reboot "$step"; then
      echo ""
      echo "⚠️  [STEP $step] Требуется перезагрузка для применения изменений."
      echo "После перезагрузки запустите: $0 --continue"
      echo ""
      read -r -p "Перезагрузить сейчас? [Y/n]: " reboot_answer
      
      case "$reboot_answer" in
        [nN]*)
          echo "Перезагрузка отложена. Не забудьте выполнить reboot и запустить: $0 --continue"
          exit 0
          ;;
        *)
          echo "Перезагрузка через 5 секунд..."
          sleep 5
          reboot
          exit 0
          ;;
      esac
    fi
  else
    echo "[STEP $step] ❌ FAILED (код $rc)"
  fi

  return $rc
}

find_next_step() {
  # Находим первый невыполненный шаг
  for step in "${ALL_STEPS[@]}"; do
    local state_file="${STATE_DIR}/${step}.ok"
    if [[ ! -f "$state_file" ]]; then
      echo "$step"
      return 0
    fi
  done
  return 1
}

main() {
  if [[ $# -eq 0 ]]; then
    # По умолчанию пытаемся продолжить выполнение
    local next_step
    next_step=$(find_next_step)
    if [[ -z "$next_step" ]]; then
      echo "✅ Все шаги уже выполнены!"
      exit 0
    fi
    echo "Продолжаю с шага $next_step"
    set -- "--continue"
  fi

  local steps_to_run=()
  local interactive=false

  if [[ "$1" == "all" ]]; then
    steps_to_run=("${ALL_STEPS[@]}")
    interactive=true
  elif [[ "$1" == "--continue" ]]; then
    # Продолжаем с последнего невыполненного шага
    local next_step
    next_step=$(find_next_step)
    if [[ -z "$next_step" ]]; then
      echo "✅ Все шаги уже выполнены!"
      exit 0
    fi
    echo "Продолжаю с шага $next_step"
    local found=0
    for s in "${ALL_STEPS[@]}"; do
      if [[ $found -eq 0 && "$s" == "$next_step" ]]; then
        found=1
      fi
      if [[ $found -eq 1 ]]; then
        steps_to_run+=("$s")
      fi
    done
    interactive=true
  elif [[ "$1" == "--from" ]]; then
    if [[ $# -lt 2 ]]; then
      echo "--from требует номера шага, например: --from 03"
      exit 1
    fi
    local from="$2"
    local found=0
    for s in "${ALL_STEPS[@]}"; do
      if [[ $found -eq 0 && "$s" == "$from" ]]; then
        found=1
      fi
      if [[ $found -eq 1 ]]; then
        steps_to_run+=("$s")
      fi
    done
  else
    steps_to_run=("$@")
  fi

  echo "Запускаю шаги: ${steps_to_run[*]}"
  for s in "${steps_to_run[@]}"; do
    run_step "$s" "$interactive" || {
      echo "Остановка на шаге $s (см. лог: $LOG_FILE)"
      exit 1
    }
  done
  
  echo ""
  echo "✅ Все запланированные шаги успешно выполнены!"
}

main "$@"
