

configK3sNetwork(){

cat <<EOF | sudo tee /etc/modules-load.d/k3s.conf
    overlay
    br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k3s.conf
    net.bridge.bridge-nf-call-iptables = 1
    net.bridge.bridge-nf-call-arptables = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

}
configWsl() {
    echo "🔍 檢查 WSL 設定狀態..."
    local NEEDS_RESTART=false

    # 1. 檢查 /etc/wsl.conf
    if ! grep -q "systemd = true" /etc/wsl.conf 2>/dev/null || \
       ! grep -q "generateResolvConf = false" /etc/wsl.conf 2>/dev/null; then
        echo "📝 更新 /etc/wsl.conf..."
        sudo bash -c 'cat <<EOF > /etc/wsl.conf
[boot]
systemd = true
[network]
generateResolvConf = false
EOF'
        NEEDS_RESTART=true
    fi

    # 2. 檢查 /etc/resolv.conf (檢查是否為我們設定的內容，避免重複寫入)
    if ! grep -q "168.95.1.1" /etc/resolv.conf 2>/dev/null; then
        echo "🌐 更新 /etc/resolv.conf..."
        sudo rm -f /etc/resolv.conf
        sudo bash -c 'cat <<EOF > /etc/resolv.conf
nameserver 168.95.1.1
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF'
    fi

    # 3. 檢查 /etc/docker/daemon.json
    sudo mkdir -p /etc/docker
    if [ ! -f /etc/docker/daemon.json ] || ! grep -q "mtu.*1400" /etc/docker/daemon.json 2>/dev/null; then
        echo "🐳 更新 Docker daemon.json..."
        sudo bash -c 'cat <<EOF > /etc/docker/daemon.json
{
  "dns": ["168.95.1.1", "8.8.8.8", "1.1.1.1"],
  "mtu": 1400,
  "iptables": true
}
EOF'
        # 如果 Docker 正在跑，提醒或自動重啟
        # sudo systemctl restart docker || true
    fi

    # 4. 檢查 APT IPv4 強制設定
    if [ ! -f /etc/apt/apt.conf.d/99force-ipv4 ]; then
        echo "📦 設定 APT 強制 IPv4..."
        echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4
    fi

    # 5. 關閉 systemd-resolved
    if systemctl is-active --quiet systemd-resolved; then
        echo "🛑 關閉 systemd-resolved..."
        sudo systemctl disable systemd-resolved --now || true
    fi

    # 最後根據是否有變動提醒重啟
    if [ "$NEEDS_RESTART" = true ]; then
        echo "⚠️  偵測到核心配置變更，請在 Windows 執行: 'wsl --shutdown' 以確保生效。"
    else
        echo "✅ 所有設定已是最新，無需更動。"
    fi
}
main() {
    if ! command -v gum &> /dev/null; then
        echo "❌ 錯誤：請先安裝 gum (sudo apt install gum)"
        exit 1
    fi

    # 1. 讓使用者選擇環境
    local choice
    choice=$(gum choose --header "🚀 請選擇目前的運行環境" "Ubuntu (Native/VM)" "WSL2 (Windows Subsystem)")

    local tasks=()
    case "$choice" in
        "Ubuntu (Native/VM)")
            tasks=("configK3sNetwork")
            ;;
        "WSL2 (Windows Subsystem)")
            tasks=("configK3sNetwork" "configWsl")
            ;;
        *)
            echo "取消操作"; exit 0 ;;
    esac

    echo "開始執行環境初始化：$choice"
    echo "------------------------------------------"
    for task in "${tasks[@]}"; do
        $task  # 動態呼叫函數
    done
    echo "------------------------------------------"
    echo "✅ 初始化完成！"
}

main "$@"