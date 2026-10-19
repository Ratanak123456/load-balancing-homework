#!/usr/bin/env bash
set -Eeuo pipefail

APP_USER="reactapp"
APP_DIR="/opt/react-app"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

SOURCE_DIR="$PROJECT_DIR/react-app"
SERVICE_FILE="$PROJECT_DIR/systemd/react-app.service"

trap 'echo "ERROR: Deployment failed at line $LINENO." >&2' ERR

log() {
    echo "[deploy-react] $*"
}

validate() {
    if [[ $# -ne 0 ]]; then
        echo "Usage: sudo bash deploy-react.sh" >&2
        exit 2
    fi

    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: Run this script with sudo." >&2
        exit 1
    fi

    case "$(hostname)" in
        web-01|web-02) ;;
        *)
            echo "ERROR: Run this on web-01 or web-02 only." >&2
            exit 1
            ;;
    esac

    for file in \
        "$SOURCE_DIR/package.json" \
        "$SOURCE_DIR/package-lock.json" \
        "$SOURCE_DIR/server.mjs" \
        "$SERVICE_FILE"
    do
        if [[ ! -f "$file" ]]; then
            echo "ERROR: Required file missing: $file" >&2
            exit 1
        fi
    done

    if ! id "$APP_USER" >/dev/null 2>&1; then
        echo "ERROR: Run setup-web.sh first." >&2
        exit 1
    fi
}

deploy() {
    local release_dir server_name

    server_name="$(hostname | tr '[:lower:]' '[:upper:]')"

    install -d -m 0755 "$APP_DIR/releases"

    release_dir="$(mktemp -d "$APP_DIR/releases/release-XXXXXXXX")"

    log "Copying application source..."

    tar \
        --exclude='./node_modules' \
        --exclude='./dist' \
        --exclude='./.git' \
        -C "$SOURCE_DIR" -cf - . |
        tar -C "$release_dir" -xf -

    chown -R "$APP_USER:$APP_USER" "$release_dir"
    chmod 0755 "$release_dir"

    log "Installing dependencies..."

    runuser -u "$APP_USER" -- \
        env HOME=/home/reactapp \
        npm --prefix "$release_dir" ci --include=dev

    log "Building React for $server_name..."

    runuser -u "$APP_USER" -- \
        env HOME=/home/reactapp \
        npm --prefix "$release_dir" run build

    if [[ ! -s "$release_dir/dist/index.html" ]]; then
        echo "ERROR: Build did not produce dist/index.html." >&2
        exit 1
    fi

    log "Installing the systemd service..."

    install -m 0644 "$SERVICE_FILE" \
        /etc/systemd/system/react-app.service

    # Activate the release only after its build succeeds.
    ln -s "$release_dir" "$release_dir.link"
    mv -Tf "$release_dir.link" "$APP_DIR/current"

    systemctl daemon-reload
    systemctl enable react-app
    systemctl restart react-app

    log "Checking application health..."

    curl --fail --silent --show-error \
        --retry 10 \
        --retry-connrefused \
        --retry-delay 1 \
        --max-time 3 \
        http://127.0.0.1:3000/health

    log "Deployment completed on $server_name."
}

main() {
    validate "$@"
    deploy
}

main "$@"
