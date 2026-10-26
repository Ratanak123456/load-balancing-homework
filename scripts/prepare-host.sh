#!/usr/bin/env bash
set -Eeuo pipefail

# Runs on the host through Vagrant's before-up trigger, never inside a guest.
if [[ $# -ne 0 ]]; then
    echo "Usage: bash scripts/prepare-host.sh" >&2
    exit 2
fi
command -v VBoxManage >/dev/null || { echo "ERROR: Install VirtualBox first." >&2; exit 1; }

records="$(VBoxManage list dhcpservers | awk '
    /^NetworkName:/ { sub(/^NetworkName:[[:space:]]*/, ""); network=$0 }
    /^Dhcpd IP:/ { address=$3 }
    /^LowerIPAddress:/ { lower=$2 }
    /^UpperIPAddress:/ { upper=$2 }
    /^NetworkMask:/ { mask=$2 }
    /^Enabled:/ { print network "|" address "|" lower "|" upper "|" mask "|" $2 }
')"

while IFS='|' read -r network address lower upper mask enabled; do
    [[ "$network" == HostInterfaceNetworking-* && "$mask" == 255.255.255.0 ]] || continue
    [[ "$address" == 192.168.56.* ]] || continue

    conflict=0
    if [[ "$address" == 192.168.56.100 ]]; then
        conflict=1
    elif [[ "$lower" == 192.168.56.* && "$upper" == 192.168.56.* ]]; then
        first="${lower##*.}"
        last="${upper##*.}"
        if [[ "$first" =~ ^[0-9]+$ && "$last" =~ ^[0-9]+$ ]] &&
           (( 10#$first <= 100 && 10#$last >= 100 )); then
            conflict=1
        fi
    fi

    if [[ $conflict -eq 1 ]]; then
        if [[ "$enabled" == Yes ]]; then
            echo "[prepare-host] Disabling VIP-conflicting DHCP server on $network."
            VBoxManage dhcpserver modify --network="$network" --disable
        fi
        # Also stop a stale process left after DHCP was disabled previously.
        VBoxManage dhcpserver stop --network="$network"
    fi
done <<< "$records"

echo "[prepare-host] Lab DHCP check completed; unrelated networks left unchanged."
