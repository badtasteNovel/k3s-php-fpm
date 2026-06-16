#!/bin/bash
set -euo pipefail

# --- 全域變數 ---
CONF_DIR="/etc/systemd/system/k3s.service.d"
CONF_FILE="addl.conf"
# addl 代表 additional 的意思，因為我們是要額外添加一些 ExecStartPre 的指令到 k3s 的 systemd 服務裡面
K3S_SYSTEM_SHELL_DIR="/usr/local/lib/k3s"

SCRIPT_NAME="k3s-pre-script.sh"

# 建立一個dns proxy 給 本機連結core dns 讓cilium 能夠track 到回來的ip
# --- 函式定義 ---
cleanup_wsl() {
    for resource in "${RESOURCES[@]}"; do
        local resource_file="${resource##*:}"
        [ -f "$RESOURCE_DIR/$resource_file" ] && sudo rm "$RESOURCE_DIR/$resource_file"
    done
    [ -f "$CONF_DIR/$CONF_FILE" ] && sudo rm "$CONF_DIR/$CONF_FILE"
    [ -f "$K3S_SYSTEM_SHELL_DIR/$SCRIPT_NAME" ] && sudo rm "$K3S_SYSTEM_SHELL_DIR/$SCRIPT_NAME"
}

setup_wsl() {
    # 建立並設定 shell 目錄
    local resources=(
    )
    sudo mkdir -p /opt/cni/bin
    wget https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgzwget https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgzwget https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgzwget https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgz || true
    sudo tar -zxvf cni-plugins-linux-amd64-v1.4.0.tgz -C /opt/cni/bin || true
    sudo mkdir -p "$K3S_SYSTEM_SHELL_DIR"
    sudo chown root:root "$K3S_SYSTEM_SHELL_DIR"
    sudo chmod 700 "$K3S_SYSTEM_SHELL_DIR"

    # 複製腳本到系統目錄
    sudo cp -f "$(dirname "$0")/$SCRIPT_NAME" "$K3S_SYSTEM_SHELL_DIR/$SCRIPT_NAME"
    sudo chown root:root "$K3S_SYSTEM_SHELL_DIR/$SCRIPT_NAME"
    sudo chmod 700 "$K3S_SYSTEM_SHELL_DIR/$SCRIPT_NAME"

    # 建立 wsl.conf
    sudo mkdir -p "$CONF_DIR"
    echo "[Service]" | sudo tee "$CONF_DIR/$CONF_FILE" >/dev/null

    # 用迴圈 append 每個 ExecStartPre
    for resource in "${resources[@]}"; do
        local func_name="${resource%%:*}"
        local resource_file="${resource##*:}"
    done
    echo "ExecStartPre=/bin/bash $K3S_SYSTEM_SHELL_DIR/$SCRIPT_NAME mirrorRegistry --resource-dir=/etc/rancher/k3s --resource-file-name=registries.yaml" |
        sudo tee -a "$CONF_DIR/$CONF_FILE" >/dev/null

    mkdir -p "/usr/local/bin"
    sudo tee /usr/local/bin/k3s-port-forward.sh >/dev/null <<'EOF'
#!/bin/bash
HOST_PORT=30500

while true; do
    if ! ss -tuln | grep -q ":$HOST_PORT "; then
        SVC_INFO=$(kubectl get svc -A -o jsonpath='{range .items[?(@.spec.ports[*].nodePort=='$HOST_PORT')]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.spec.ports[0].port}{"\n"}{end}' | head -n 1)

        if [ ! -z "$SVC_INFO" ]; then
            NS=$(echo $SVC_INFO | awk '{print $1}')
            NAME=$(echo $SVC_INFO | awk '{print $2}')
            REAL_PORT=$(echo $SVC_INFO | awk '{print $3}')

            nohup kubectl port-forward -n "$NS" svc/"$NAME" "$HOST_PORT":"$REAL_PORT" --address localhost > /dev/null 2>&1 &
        fi
    fi
    sleep 10
done
EOF
    sudo chmod +x /usr/local/bin/k3s-port-forward.sh

    # --- 重要：下方的 EOF 必須頂格 ---
    sudo tee /etc/systemd/system/k3s-proxy.service >/dev/null <<'EOF'
[Unit]
Description=K3s NodePort Forwarding Service
After=network.target
Wants=k3s.service

[Service]
Type=simple
ExecStart=/usr/local/bin/k3s-port-forward.sh
Restart=always
RestartSec=10
Environment=KUBECONFIG=/etc/rancher/k3s/k3s.yaml
StandardOutput=null
StandardError=null
User=root

[Install]
WantedBy=multi-user.target
EOF
    sudo chown root:root "$CONF_DIR/$CONF_FILE"
    sudo chmod 600 "$CONF_DIR/$CONF_FILE"
}

setup() {
    # 建立並設定 shell 目錄
    local resources=(
        "mirrorRegistry:registry-lrp.yaml"
    )
    local resource_dir='/var/lib/rancher/k3s/server/manifests'

    sudo mkdir -p "$K3S_SYSTEM_SHELL_DIR"
    sudo chown root:root "$K3S_SYSTEM_SHELL_DIR"
    sudo chmod 700 "$K3S_SYSTEM_SHELL_DIR"

    # 複製腳本到系統目錄
    sudo cp -f "$(dirname "$0")/$SCRIPT_NAME" "$K3S_SYSTEM_SHELL_DIR/$SCRIPT_NAME"
    sudo chown root:root "$K3S_SYSTEM_SHELL_DIR/$SCRIPT_NAME"
    sudo chmod 700 "$K3S_SYSTEM_SHELL_DIR/$SCRIPT_NAME"

    # 建立 wsl.conf
    sudo mkdir -p "$CONF_DIR"
    echo "[Service]" | sudo tee "$CONF_DIR/$CONF_FILE" >/dev/null

    # 用迴圈 append 每個 ExecStartPre
    for resource in "${resources[@]}"; do
        local func_name="${resource%%:*}"
        local resource_file="${resource##*:}"
        # echo "ExecStartPre=/bin/bash $K3S_SYSTEM_SHELL_DIR/$SCRIPT_NAME $func_name --resource-dir=$resource_dir --resource-file-name=$resource_file" \
        #   | sudo tee -a "$CONF_DIR/$CONF_FILE" > /dev/null
    done
    echo "ExecStartPre=/bin/bash $K3S_SYSTEM_SHELL_DIR/$SCRIPT_NAME devMirrorRegistry --resource-dir=/etc/rancher/k3s --resource-file-name=registries.yaml" |
        sudo tee -a "$CONF_DIR/$CONF_FILE" >/dev/null
    sudo chown root:root "$CONF_DIR/$CONF_FILE"
    sudo chmod 600 "$CONF_DIR/$CONF_FILE"
}

usage() {
    echo "Usage: $0 <command>"
    echo "Commands:"
    echo "  setup     - 建立 wsl 的 exec pre 腳本"
    echo "  uninstall - 刪除 wsl 的 exec pre 腳本"
}

# --- Entry Point ---
main() {
    local command="${1:-}"
    shift || true

    case "$command" in
    setup) setup "$@" ;;
    setup_wsl) setup_wsl "$@" ;;
    uninstall) cleanup_wsl "$@" ;;
    *)
        usage
        exit 1
        ;;
    esac
}

main "$@"
