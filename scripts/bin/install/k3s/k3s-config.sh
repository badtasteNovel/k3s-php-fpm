#!/bin/bash
source .env.task
K3S_SYSTEM_DIR=/etc/systemd/system/k3s.service.d
# disable=servicelb 讓cilium 做 loadbalancer
K3S_ARGS="--kubelet-arg=pod-max-pids=1000 \
  --kubelet-arg=image-gc-high-threshold=60 \
  --kubelet-arg=image-gc-low-threshold=40 \
  --prefer-bundled-bin \
  --flannel-backend=none \
  --disable-network-policy \
  --disable-kube-proxy \
  --disable servicelb \
  --disable traefik \
  --token=${K3S_TOKEN:-devtoken} \
  --cluster-init \
  --secrets-encryption \
  --data-dir=/var/lib/rancher/k3s"
set -euo pipefail

# --- 函式定義 ---
systemConfig() {
    sudo mkdir -p "$K3S_SYSTEM_DIR"
    sudo tee "$K3S_SYSTEM_DIR/override.conf" >/dev/null <<EOF
  [Service]
  IOSchedulingClass=realtime
  IOSchedulingPriority=0
  ExecStart=
  ExecStart=/bin/bash -c "\
  NODE_IP=\$(ip route get 1 | awk '{for(i=1;i<=NF;i++) if(\$i==\"src\") print \$(i+1)}'); \
  exec /usr/local/bin/k3s server $K3S_ARGS --node-ip=\$NODE_IP --tls-san=\$NODE_IP --tls-san=127.0.0.1 --secrets-encryption"
EOF
    sudo chmod 600 $K3S_SYSTEM_DIR/override.conf
    sudo chown root:root $K3S_SYSTEM_DIR/override.conf
}
cleanupSystemConfig() {
    sudo rm $K3S_SYSTEM_DIR/override.conf
}
installation() {
    local IS_DYNAMIC_IP="0"
    local NODE_IP
    NODE_IP=$(ip route get 1 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')

    for arg in "$@"; do
        case $arg in
        --is-dynamic-ip=*) IS_DYNAMIC_IP="${arg#*=}" ;;
        esac
    done

    if [ "$IS_DYNAMIC_IP" = "1" ]; then
        echo "以浮動 IP 環境安裝 k3s"
        INSTALLATION_PARAMETERS="$K3S_ARGS --node-ip=$NODE_IP --tls-san=$NODE_IP --tls-san=127.0.0.1"
    fi

    export INSTALL_K3S_EXEC="$INSTALLATION_PARAMETERS"
    export INSTALL_K3S_VERSION="v1.34.5+k3s1"
    curl -sfL https://get.k3s.io | sh -s -
}
usage() {
    echo "Usage: $0 <command> [options]"
    echo "Commands:"
    echo "  systemConfig        - 幫助浮動ip 建立自定義的systemctl Exec"
    echo "  cleanupSystemConfig - 刪除systemctl 對於浮動ip的設定"
    echo "  installation        - 第一次安裝 k3s 時所寫的shell"
}
# --- Entry Point ---
main() {
    local command="${1:-}"
    shift || true

    case "$command" in
    systemConfig) systemConfig "$@" ;; # 幫助浮動ip 建立自定義的systemctl Exec
    cleanupSystemConfig) cleanupSystemConfig "$@" ;;
    installation) installation "$@" ;; # 第一次安裝 k3s 時所寫的shell
    *)
        usage
        exit 1
        ;;
    esac
}

main "$@"
