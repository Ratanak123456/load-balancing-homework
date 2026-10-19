#!/usr/bin/env bash
set -eu

# Fail if HAProxy is stopped.
if ! /usr/bin/systemctl is-active --quiet haproxy; then
    exit 1
fi

# Check that HTTP traffic can pass through the local HAProxy.
exec /usr/bin/curl \
    --fail \
    --silent \
    --show-error \
    --max-time 2 \
    http://127.0.0.1/health >/dev/null
