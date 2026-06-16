#!/bin/bash
set -euo pipefail

REGISTRY_NAME="registry"
REGISTRY_PORT="5000"
STORAGE_PATH="/var/lib/docker-registry"
IMAGE_VERSION="registry:2"
UI_PORT="9081"

log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1"; }

parse_args() {
  for arg in "$@"; do
    case $arg in
      --ui-port=*) UI_PORT="${arg#*=}" ;;
    esac
  done
}

check_health() {
    curl -s -m 2 "http://localhost:${REGISTRY_PORT}/v2/" > /dev/null
}

setup_gui() {
    if docker ps -a --format '{{.Names}}' | grep -q "^registry-ui$"; then
        if docker ps --format '{{.Names}}' | grep -q "^registry-ui$"; then
            log "docker-gui 已經啟動，請訪問 http://localhost:${UI_PORT}"
            return 0
        else
            docker start registry-ui
            return 0
        fi
    fi

    docker run -d \
        --name registry-ui \
        -p ${UI_PORT}:80 \
        --restart=always \
        -e REGISTRY_URL=http://localhost:${REGISTRY_PORT} \
        -e SINGLE_REGISTRY=true \
        -e DELETE_IMAGES=true \
        -e CATALOG_ELEMENTS_LIMIT=100 \
        joxit/docker-registry-ui:latest
}
uninstall_gui() {
    docker rm -f registry-ui 2>/dev/null || true
}

setup_registry() {
    log "Checking infrastructure..."

    if [ ! -d "$STORAGE_PATH" ]; then
        mkdir -p "$STORAGE_PATH"
        log "Created storage: $STORAGE_PATH"
    fi

    if [ "$(docker ps -aq -f name=^${REGISTRY_NAME}$)" ]; then
        if [ -z "$(docker ps -q -f name=^${REGISTRY_NAME}$)" ]; then
            log "Container exists but stopped. Restarting..."
            docker start "$REGISTRY_NAME"
        else
            log "Service is already running."
        fi
    else
        log "Deploying new registry container..."
        docker run -d \
            -p "${REGISTRY_PORT}:5000" \
            --restart=always \
            --name "$REGISTRY_NAME" \
            -v "${STORAGE_PATH}:/var/lib/registry" \
            -e "REGISTRY_HTTP_HEADERS_Access-Control-Allow-Origin=[\"http://localhost:${UI_PORT}\"]" \
            -e "REGISTRY_HTTP_HEADERS_Access-Control-Allow-Methods=[\"HEAD\",\"GET\",\"OPTIONS\",\"DELETE\"]" \
            -e "REGISTRY_HTTP_HEADERS_Access-Control-Allow-Headers=[\"Authorization\",\"Accept\",\"Cache-Control\"]" \
            -e "REGISTRY_HTTP_HEADERS_Access-Control-Expose-Headers=[\"Docker-Content-Digest\"]" \
            "$IMAGE_VERSION"
    fi
}
setup_server_registry(){
    log "Checking infrastructure..."

    if [ ! -d "$STORAGE_PATH" ]; then
        mkdir -p "$STORAGE_PATH"
        log "Created storage: $STORAGE_PATH"
    fi

    if [ "$(docker ps -aq -f name=^${REGISTRY_NAME}$)" ]; then
        if [ -z "$(docker ps -q -f name=^${REGISTRY_NAME}$)" ]; then
            log "Container exists but stopped. Restarting..."
            docker start "$REGISTRY_NAME"
        else
            log "Service is already running."
        fi
    else
        log "Deploying new registry container..."
        docker run -d \
            -p "${REGISTRY_PORT}:5000" \
            --restart=always \
            --name "$REGISTRY_NAME" \
            -v "${STORAGE_PATH}:/var/lib/registry" \
            "$IMAGE_VERSION"
    fi
}
cleanup_registry() {
    log "Removing container..."
    docker stop "$REGISTRY_NAME" 2>/dev/null || true
    docker rm "$REGISTRY_NAME" 2>/dev/null || true
    log "Cleanup complete. Data at $STORAGE_PATH preserved."
}

parse_args "$@"
# server-setup 用於正式，請勿用錯。
case "${1:-}" in
    setup)         setup_registry ;;
    server-setup)    setup_server_registry ;;
    gui)           setup_gui ;;
    uninstall-gui) uninstall_gui ;;
    uninstall)     cleanup_registry ;;
    check)         check_health ;;
    *)             echo "Usage: $0 {setup|gui|uninstall-gui|uninstall|check} [--ui-port=<port>]"; exit 1 ;;
esac