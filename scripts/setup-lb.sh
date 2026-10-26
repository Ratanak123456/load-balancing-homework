#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "ERROR: setup-lb.sh failed at line $LINENO." >&2' ERR

if [[ $# -ne 0 || $EUID -ne 0 ]]; then
    echo "Usage: sudo bash setup-lb.sh" >&2
    exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

case "$(hostname)" in
    lb-01) config="lb01.conf"; address="192.168.56.10/24" ;;
    lb-02) config="lb02.conf"; address="192.168.56.11/24" ;;
    *) echo "ERROR: Run this on lb-01 or lb-02 only." >&2; exit 1 ;;
esac

if ! ip -o -4 addr show dev enp0s8 | awk '{ print $4 }' | grep -Fxq "$address"; then
    echo "ERROR: Expected $address on enp0s8; refusing to install VRRP configuration." >&2
    exit 1
fi

HA_CONFIG="$PROJECT_DIR/haproxy/haproxy.cfg"
VRRP_CONFIG="$PROJECT_DIR/keepalived/$config"
CHECK_SCRIPT="$PROJECT_DIR/scripts/check-haproxy.sh"
for file in "$HA_CONFIG" "$VRRP_CONFIG" "$CHECK_SCRIPT"; do
    [[ -s "$file" ]] || { echo "ERROR: Missing $file" >&2; exit 1; }
done
bash -n "$CHECK_SCRIPT"

export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::Retries=3 update
apt-get -o Acquire::Retries=3 install -y haproxy keepalived curl

# Validate candidate configuration before replacing installed service configs.
haproxy -c -f "$HA_CONFIG"
# Keepalived validates the root-owned script's existence and permissions too.
install -o root -g root -m 0755 "$CHECK_SCRIPT" /usr/local/sbin/check-haproxy.sh
keepalived -t -f "$VRRP_CONFIG"

keepalived_changed=1
if cmp -s "$VRRP_CONFIG" /etc/keepalived/keepalived.conf; then
    keepalived_changed=0
fi

install -d -o root -g root -m 0755 /etc/haproxy /etc/keepalived
install -o root -g root -m 0644 "$HA_CONFIG" /etc/haproxy/haproxy.cfg
install -o root -g root -m 0644 "$VRRP_CONFIG" /etc/keepalived/keepalived.conf
systemctl enable haproxy keepalived

if systemctl is-active --quiet haproxy; then
    systemctl reload haproxy
else
    systemctl start haproxy
fi
/usr/local/sbin/check-haproxy.sh

if [[ $keepalived_changed -eq 1 ]] && systemctl is-active --quiet keepalived; then
    systemctl restart keepalived
else
    systemctl start keepalived
fi

for service in haproxy keepalived; do
    systemctl is-enabled --quiet "$service"
    systemctl is-active --quiet "$service"
done
echo "[setup-lb] $(hostname): HAProxy and Keepalived configured, enabled, and active."
