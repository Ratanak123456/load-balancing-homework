#!/usr/bin/env bash
set -eu

# Fail if HAProxy is stopped.
if ! /usr/bin/systemctl is-active --quiet haproxy; then
    exit 1
fi

# Check HAProxy's listener independently of backend health-check delays.
code="$(/usr/bin/curl \
    --noproxy '*' \
    --silent \
    --show-error \
    --max-time 2 \
    --output /dev/null \
    --write-out '%{http_code}' \
    http://127.0.0.1/haproxy-health)" || exit 1

[[ "$code" == "200" ]]
