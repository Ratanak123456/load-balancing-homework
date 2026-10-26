#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "ERROR: provision.sh failed at line $LINENO." >&2' ERR

if [[ $# -ne 0 || $EUID -ne 0 ]]; then
    echo "Usage: sudo bash provision.sh" >&2
    exit 2
fi

PROJECT_DIR="/vagrant"

case "$(hostname)" in
    lb-01|lb-02) role="load-balancer" ;;
    web-01|web-02) role="web" ;;
    *) echo "ERROR: Unknown lab hostname: $(hostname)" >&2; exit 1 ;;
esac

echo "[provision] Preparing $(hostname) ($role)..."
export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::Retries=3 update
apt-get -o Acquire::Retries=3 install -y curl ca-certificates iputils-ping

case "$role" in
    load-balancer)
        bash "$PROJECT_DIR/scripts/setup-lb.sh"
        ;;
    web)
        bash "$PROJECT_DIR/scripts/setup-web.sh"
        bash "$PROJECT_DIR/scripts/deploy-react.sh"
        ;;
esac

echo "[provision] $(hostname) completed."
