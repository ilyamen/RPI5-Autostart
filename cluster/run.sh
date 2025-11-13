#!/usr/bin/env bash
set -euo pipefail

STEPS_DIR="$(dirname "$0")/steps"

usage() {
  cat <<EOF
Usage: $0 [master | worker]

  master      - установить k3s server (мастер)
  worker      - установить k3s agent (воркер, требует K3S_URL и K3S_TOKEN)
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

ROLE="$1"

case "$ROLE" in
  master)
    bash "${STEPS_DIR}/10_k3s_master.sh"
    ;;
  worker)
    bash "${STEPS_DIR}/11_k3s_worker.sh"
    ;;
  *)
    usage
    exit 1
    ;;
esac
