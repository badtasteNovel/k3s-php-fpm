#!/bin/bash
set -euo pipefail

# --- 全域配置 (統一變數) ---
# registry 的k3s dns 位置。
REGISTRY_NAME="registry.local"
REGISTRY_PORT="5000"
NODE_PORT="30500"
REGISTRY_FULL_ADDR="${REGISTRY_NAME}:${REGISTRY_PORT}"

RESOURCE_DIR=""
RESOURCE_FILE_NAME=""

# --- 參數解析 ---
parse_args() {
    for arg in "$@"; do
        case $arg in
        --resource-dir=*) RESOURCE_DIR="${arg#*=}" ;;
        --resource-file-name=*) RESOURCE_FILE_NAME="${arg#*=}" ;;
        esac
    done
}

# --- 函式定義 ---

# 生成 K3s 的基礎設施設定 (用於 /etc/rancher/k3s/registries.yaml)
mirrorRegistry() {
    parse_args "$@"
    mkdir -p "$RESOURCE_DIR"
    cat <<EOF >"$RESOURCE_DIR/$RESOURCE_FILE_NAME"
mirrors:
  "$REGISTRY_FULL_ADDR":
    endpoint:
      - "http://localhost:$NODE_PORT"
EOF
}
ciliumlocalRedirectPolicy() {
    parse_args "$@"
    mkdir -p "$RESOURCE_DIR"
    # registry-lrp.yaml
    cat <<EOF >"$RESOURCE_DIR/$RESOURCE_FILE_NAME"
apiVersion: "cilium.io/v2"
kind: CiliumLocalRedirectPolicy
metadata:
  name: "registry-redirect"
  namespace: default
spec:
  redirectFrontend:
    addressMatcher:
      ip: "169.254.42.1"
      toPorts:
        - port: "5000"
          protocol: TCP
  redirectBackend:
    localEndpointSelector:
      matchLabels:
        app: my-local-registry
    toPorts:
      - port: "5000"
        protocol: TCP
EOF
}
devMirrorRegistry() {
    parse_args "$@"
    mkdir -p "$RESOURCE_DIR"
    cat <<EOF >"$RESOURCE_DIR/$RESOURCE_FILE_NAME"
mirrors:
  "$REGISTRY_FULL_ADDR":
    endpoint:
      - "http://localhost:$NODE_PORT"
EOF
}
# 生成 K8s 的網路資源 (用於 .../server/manifests)
localRegistry() {
    parse_args "$@"
    mkdir -p "$RESOURCE_DIR"
    cat <<EOF >"$RESOURCE_DIR/$RESOURCE_FILE_NAME"
apiVersion: v1
kind: Service
metadata:
  name: $REGISTRY_NAME
  namespace: default
spec:
  type: ExternalName
  externalName: host.docker.internal
EOF
}

usage() {
    echo "Usage: $0 {localRegistry|mirrorRegistry} [options]"
}

# --- Entry Point ---
main() {
    local command="${1:-}"
    shift || true

    case "$command" in
    localRegistry) localRegistry "$@" ;;
    mirrorRegistry) mirrorRegistry "$@" ;;
    *)
        usage
        exit 1
        ;;
    esac
}

main "$@"
