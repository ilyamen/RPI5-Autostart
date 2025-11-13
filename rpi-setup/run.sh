#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/rpi-setup.log"
STATE_DIR="/var/local/rpi-setup"
STEPS_DIR="$(dirname "$0")/steps"

mkdir -p "$(dirname "$LOG_FILE")" "$STATE_DIR"

# логируем всё
exec > >(tee -a "$LOG_FILE") 2>&1

usage() {
  cat <<EOF
Usage: $0 [all | STEP... | --from N]

  all         - выполнить все шаги по порядку
  N ...       - выполнить только указанные шаги (например: 02 05)
  --from N    - выполнить шаги начиная с N до конца (например: --from 03)
EOF
}

ALL_STEPS=("01" "02" "03" "04" "05" "06")

run_step() {
  local step="$1"
  local script
  script=$(ls "${STEPS_DIR}/${step}_"*.sh 2>/dev/null || true)
  local state_file="${STATE_DIR}/${step}.ok"

  if [[ -z "$script" ]]; then
    echo "[STEP $step] Скрипт не найден (${STEPS_DIR}/${step}_*.sh)"
    return 1
  fi

  echo "=============================="
  echo "[STEP $step] Запуск $script"
  echo "=============================="

  bash "$script"
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    echo "[STEP $step] ✅ OK"
    touch "$state_file"
  else
    echo "[STEP $step] ❌ FAILED (код $rc)"
  fi

  return $rc
}

main() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  local steps_to_run=()

  if [[ "$1" == "all" ]]; then
    steps_to_run=("${ALL_STEPS[@]}")
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
    run_step "$s" || {
      echo "Остановка на шаге $s (см. лог: $LOG_FILE)"
      exit 1
    }
  done
}

main "$@"
