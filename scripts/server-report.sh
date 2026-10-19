#!/usr/bin/env bash
set -Eeuo pipefail

trap 'echo "ERROR: Report failed at line $LINENO." >&2' ERR

section() {
    printf '\n=== %s ===\n' "$1"
}

main() {
    if [[ $# -ne 0 ]]; then
        echo "Usage: $0" >&2
        exit 2
    fi

    section "Hostname"
    hostname

    section "IPv4 Addresses"
    ip -br -4 addr

    section "Uptime"
    uptime -p

    section "RAM Usage"
    free -h

    section "CPU Information"
    LC_ALL=C lscpu | awk \
        '/^Architecture:|^CPU\(s\):|^Model name:/'

    section "CPU Usage over One Second"
    LC_ALL=C vmstat 1 2 | awk \
        'END { printf "Non-idle CPU: %.1f%%\n", 100 - $15 }'

    section "Disk Usage"
    df -h -x tmpfs -x devtmpfs
}

main "$@"
