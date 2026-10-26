#!/usr/bin/env bash
set -Eeuo pipefail

APP_USER="reactapp"
APP_DIR="/opt/react-app"
NODE_MAJOR="24"

trap 'echo "ERROR: setup-web.sh failed at line $LINENO." >&2' ERR

log() {
    echo "[setup-web] $*"
}

validate() {
    if [[ $# -ne 0 ]]; then
        echo "Usage: sudo bash setup-web.sh" >&2
        exit 2
    fi

    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: Run this script with sudo." >&2
        exit 1
    fi

    case "$(hostname)" in
        web-01|web-02)
            ;;
        *)
            echo "ERROR: Run this on web-01 or web-02 only." >&2
            exit 1
            ;;
    esac
}

install_dependencies() {
    log "Installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y curl ca-certificates build-essential

    if command -v node >/dev/null && command -v npm >/dev/null &&
       [[ "$(node -p 'process.versions.node.split(".")[0]')" == "$NODE_MAJOR" ]]; then
        log "Node.js $NODE_MAJOR and npm are already installed."
    else
        local setup_file
        setup_file="$(mktemp)"

        curl --retry 3 -fsSL \
            "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" \
            -o "$setup_file"

        bash "$setup_file"
        rm -f "$setup_file"

        apt-get install -y nodejs
    fi

    log "Installed Node.js: $(node --version)"
    log "Installed npm: $(npm --version)"
}

prepare_user() {
    if id "$APP_USER" >/dev/null 2>&1; then
        log "User $APP_USER already exists."
    else
        log "Creating dedicated application user..."

        useradd \
            --system \
            --user-group \
            --create-home \
            --home-dir /home/reactapp \
            --shell /usr/sbin/nologin \
            "$APP_USER"
    fi
}

prepare_directories() {
    log "Preparing application directories..."

    install -d \
        -o "$APP_USER" \
        -g "$APP_USER" \
        -m 0755 \
        "$APP_DIR" \
        "$APP_DIR/source" \
        "$APP_DIR/dist"
}

main() {
    validate "$@"
    install_dependencies
    prepare_user
    prepare_directories

    log "Setup completed on $(hostname)."
}

main "$@"
