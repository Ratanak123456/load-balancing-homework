#!/usr/bin/env bash
set -Eeuo pipefail

SERVICE="react-app"

usage() {
    echo "Usage: $0 {start|stop|restart|status}" >&2
}

main() {
    if [[ $# -ne 1 ]]; then
        usage
        exit 2
    fi

    case "$1" in
        start|stop|restart)
            if [[ $EUID -ne 0 ]]; then
                echo "ERROR: Use sudo for $1." >&2
                exit 1
            fi

            if ! systemctl "$1" "$SERVICE"; then
                echo "ERROR: Failed to $1 $SERVICE." >&2
                exit 1
            fi

            echo "$SERVICE: $1 completed."
            ;;
        status)
            exec systemctl status "$SERVICE" --no-pager
            ;;
        *)
            usage
            exit 2
            ;;
    esac
}

main "$@"
