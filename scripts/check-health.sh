#!/usr/bin/env bash
set -uo pipefail

if [[ $# -ne 0 ]]; then
    echo "Usage: ./check-health.sh" >&2
    exit 2
fi

check_server() {
    local name="$1"
    local address="$2"
    local code

    if code="$(curl --noproxy '*' --silent --show-error \
        --connect-timeout 2 --max-time 5 \
        --output /dev/null --write-out '%{http_code}' \
        "http://$address:3000/health")"
    then
        if [[ "$code" == "200" ]]; then
            echo "$name ($address): HEALTHY"
            return 0
        fi

        echo "$name ($address): UNHEALTHY — HTTP $code"
    else
        echo "$name ($address): UNREACHABLE"
    fi

    return 1
}

main() {
    local result=0
    local entry name address

    for entry in \
        "WEB-01 192.168.56.20" \
        "WEB-02 192.168.56.21"
    do
        read -r name address <<< "$entry"

        if ! check_server "$name" "$address"; then
            result=1
        fi
    done

    return "$result"
}

main
