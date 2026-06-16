_installGitCz() {
    sudo apt update
    sudo apt install nodejs npm
    sudo npm install -g commitizen cz-conventional-changelog
}
_configGitCz() {
    echo '{ "path": "cz-conventional-changelog" }' >~/.czrc
}
_installKrew() {
    set -x
    cd "$(mktemp -d)" &&
        OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
        ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
        KREW="krew-${OS}_${ARCH}" &&
        curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
        tar zxvf "${KREW}.tar.gz" &&
        ./"${KREW}" install krew
}
_configKrew() {
    # 檢查是否已經在 PATH 中，避免重複寫入 .bashrc
    if ! grep -q ".krew/bin" ~/.bashrc; then
        echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >>~/.bashrc
        echo "✅ Krew path added to .bashrc"
    fi
    # 讓當前 shell 立即生效
    export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
}
installKrew() {
    _installKrew
    _configKrew
}
installGum() {
    sudo mkdir -p /etc/apt/keyrings

    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg

    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list

    sudo apt update && sudo apt install gum
}
installGitCz() {
    _installGitCz
    _configGitCz
}
installKubectl() {
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

    chmod +x ./kubectl

    sudo mv ./kubectl /usr/local/bin/kubectl
}
installTilt() {
    curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | DESTDIR=/tmp bash
    sudo mv /tmp/bin/tilt /usr/local/bin/
    rm -rf /tmp/bin
}
installCiliumCli() {
    CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
    CLI_ARCH=amd64
    if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
    curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
    sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
    rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
}
installHelm() {
    mkdir -p /tmp/helm-install && cd /tmp/helm-install

    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

    chmod 700 get_helm.sh

    ./get_helm.sh

    cd - && rm -rf /tmp/helm-install
}
installDistrobox() {
    sudo apt update && sudo apt install distrobox
}
installPhp() {
    export DBX_CONTAINER_MANAGER=docker
    local CONTAINER_NAME="php-dev"
    local IMAGE_NAME="my-php-release:debian-bookworm"
    local EXPORT_PATH="$HOME/.local/bin"

    # 1. 永久變數
    grep -q "DBX_CONTAINER_MANAGER=docker" "$HOME/.bashrc" ||
        echo 'export DBX_CONTAINER_MANAGER=docker' >>"$HOME/.bashrc"

    # 2. WSL2 掛載修復
    sudo mount --make-rshared / >/dev/null 2>&1 || true

    # 3. 確認本地 Image 存在
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        echo "❌ 找不到 $IMAGE_NAME，請先 build"
        return 1
    fi

    # 4. 健康檢查函數：容器是否真的可用
    _container_healthy() {
        # 條件一：容器正在跑
        docker inspect "$CONTAINER_NAME" --format '{{.State.Status}}' 2>/dev/null | grep -q "running" || return 1
        # 條件二：容器內有當前用戶
        docker exec "$CONTAINER_NAME" id "$USER" >/dev/null 2>&1 || return 1
        # 條件三：distrobox enter 可以正常進入
        distrobox enter "$CONTAINER_NAME" -- true >/dev/null 2>&1 || return 1
        return 0
    }

    # 5. 核心邏輯：不健康就摧毀重建
    was_rebuilt="false"
    if _container_healthy; then
        echo "✅ 容器健康，直接使用"
    else
        echo "🔧 容器狀態異常，強制重建..."
        # 先清乾淨
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        distrobox rm "$CONTAINER_NAME" --force >/dev/null 2>&1 || true
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true

        # 建立新容器
        echo "📦 建立 Distrobox 容器..."
        distrobox create -n "$CONTAINER_NAME" --image "$IMAGE_NAME" --yes

        # ⚠️ 關鍵：第一次 enter 才會真正初始化用戶
        echo "👤 初始化容器用戶..."
        distrobox enter "$CONTAINER_NAME" -- true

        # 再次確認
        if ! _container_healthy; then
            echo "❌ 容器重建後仍異常，請手動檢查"
            return 1
        fi
        was_rebuilt="true" # ← 加這行
    fi

    # 6. 注入 Composer（冪等：有就跳過）
    if ! distrobox enter "$CONTAINER_NAME" -- which composer >/dev/null 2>&1; then
        echo "📥 注入 Composer..."
        docker run --rm -v /usr/local/bin:/target composer:2 cp /usr/bin/composer /target/composer
        docker cp /usr/local/bin/composer "$CONTAINER_NAME":/usr/bin/composer
        docker exec -u root "$CONTAINER_NAME" chmod +x /usr/bin/composer
    else
        echo "✅ Composer 已存在，跳過"
    fi

    # 7. 導出 PHP 和 Composer（冪等：有就跳過）
    mkdir -p "$EXPORT_PATH"

    if [[ ! -f "$EXPORT_PATH/php" ]] || [[ "$was_rebuilt" == "true" ]]; then
        echo "🚀 導出 PHP..."
        rm -f "$EXPORT_PATH/php" # 確保舊的被清掉
        distrobox enter "$CONTAINER_NAME" -- distrobox-export --bin /usr/local/bin/php --export-path "$EXPORT_PATH"
    else
        echo "✅ PHP 已導出，跳過"
    fi

    if [[ ! -f "$EXPORT_PATH/composer" ]] || [[ "$was_rebuilt" == "true" ]]; then
        echo "📦 導出 Composer..."
        rm -f "$EXPORT_PATH/composer"
        distrobox enter "$CONTAINER_NAME" -- distrobox-export --bin /usr/bin/composer --export-path "$EXPORT_PATH"
    else
        echo "✅ Composer 已導出，跳過"
    fi

    # 8. PATH
    if [[ ":$PATH:" != *":$EXPORT_PATH:"* ]]; then
        export PATH="$EXPORT_PATH:$PATH"
        grep -q "$EXPORT_PATH" "$HOME/.bashrc" ||
            echo "export PATH=\"$EXPORT_PATH:\$PATH\"" >>"$HOME/.bashrc"
    fi

    hash -r

    # 9. 最終驗證
    echo "✨ 完成！驗證版本："
    echo "請輸入 source ~/.bashrc 以確保環境變數生效"
    "$EXPORT_PATH/php" -v && "$EXPORT_PATH/composer" -V
}

installNode() {
    export DBX_CONTAINER_MANAGER=docker
    local CONTAINER_NAME="node-dev"
    local NODE_IMAGE="node:20-slim"
    local EXPORT_PATH="$HOME/.local/bin"

    # 1. 容器健康檢查 (略)
    _node_healthy() {
        docker inspect "$CONTAINER_NAME" --format '{{.State.Status}}' 2>/dev/null | grep -q "running" || return 1
        return 0
    }
    if ! _node_healthy; then
        distrobox create -n "$CONTAINER_NAME" --image "$NODE_IMAGE" --yes
    fi

    # 2. 容器內只負責「裝軟體」
    echo "🛠️ 正在整備容器內工具..."
    distrobox enter "$CONTAINER_NAME" -- sudo apt-get update
    distrobox enter "$CONTAINER_NAME" -- sudo apt-get install -y git
    distrobox enter "$CONTAINER_NAME" -- sudo npm install -g commitizen cz-conventional-changelog

    # 3. 在宿主機（WSL）直接寫入設定檔
    # 既然 Distrobox 共享 $HOME，我們直接在 WSL 寫入 ~/.czrc
    # 容器內的 git-cz 自然就讀得到，且絕對不會有引號轉義問題
    echo "📄 更新 Commitizen 配置..."
    cat <<EOF >"$HOME/.czrc"
{
  "path": "cz-conventional-changelog"
}
EOF

    # 4. 導出 Node & NPM
    mkdir -p "$EXPORT_PATH"
    distrobox enter "$CONTAINER_NAME" -- distrobox-export --bin /usr/local/bin/node --export-path "$EXPORT_PATH"
    distrobox enter "$CONTAINER_NAME" -- distrobox-export --bin /usr/local/bin/npm --export-path "$EXPORT_PATH"

    # 5. 清理與設定 Git Alias
    unalias git-cz 2>/dev/null || true
    sed -i '/alias git-cz/d' "$HOME/.bashrc"

    # 使用 git config 建立別名，確保執行時環境變數正確
    git config --global alias.cz "!distrobox enter $CONTAINER_NAME -- git -c safe.directory=\$(pwd) cz"

    echo "✨ Node.js 環境配置完成！"
}
installHelmDiff() {
    if [ -n "$SUDO_USER" ]; then
        echo "正在為使用者 $SUDO_USER 安裝 helm-diff..."
        sudo -u "$SUDO_USER" helm plugin install https://github.com/databus23/helm-diff || echo "使用者 $SUDO_USER 的插件已存在或安裝跳過"
    fi

    # 2. 幫 root 使用者安裝 (這解決了 sudo helmfile 找不到指令的問題)
    echo "正在為 root 安裝 helm-diff..."
    sudo helm plugin install https://github.com/databus23/helm-diff || echo "root 的插件已存在或安裝跳過"

    # 3. 驗證結果
    echo "--- 驗證安裝結果 ---"
    echo '當前使用者插件:'
    helm plugin list | grep diff || echo '無'
    echo 'Root 使用者插件:'
    sudo helm plugin list | grep diff || echo '無'
}
installHelmFile() {
    mkdir -p /tmp/helmfile-install && cd /tmp/helmfile-install

    curl -LO https://github.com/helmfile/helmfile/releases/download/v0.169.1/helmfile_0.169.1_linux_amd64.tar.gz

    tar -xvzf helmfile_0.169.1_linux_amd64.tar.gz

    sudo mv helmfile /usr/local/bin/helmfile
    sudo chmod +x /usr/local/bin/helmfile

    cd - && rm -rf /tmp/helmfile-install
}
installJq() {
    sudo apt update && sudo apt install -y jq
}
installskopeo() {
    sudo apt update && sudo apt install -y skopeo
}
installTcpDump() {
    sudo apt update && sudo apt install -y tcpdump
}

installDev() {
    # 定義要安裝的函式清單
    local tools=(
        "installGum"
        "installGitCz"
        "installKrew"
        "installTilt"
        "installKubectl"
        "installCiliumCli"
        "installHelm"
        "installHelmDiff"
        "installHelmFile"
        "installJq"
        "installTcpDump"
        "installDistrobox"
        "installPhp"
        "installskopeo"
    )

    echo "📦 Starting Full Installation..."
    for tool in "${tools[@]}"; do
        if declare -f "$tool" >/dev/null; then
            $tool
        else
            echo "❌ Error: Function $tool does not exist."
        fi
    done
    echo "✨ All tools installed!"
}
installProduction() {
    local tools=(
        "installGum"
        "installKubectl"
        "installCiliumCli"
        "installHelm"
        "installHelmDiff"
        "installHelmFile"
        "installJq"
        "installTcpDump"
    )

    echo "📦 Starting Full Installation..."
    for tool in "${tools[@]}"; do
        if declare -f "$tool" >/dev/null; then
            $tool
        else
            echo "❌ Error: Function $tool does not exist."
        fi
    done
    echo "✨ All tools installed!"
}
main() {
    local command="${1:-}"
    shift || true
    case "$command" in
    installNode) installNode "$@" ;;
    installDev) installDev "$@" ;;
    installProduction) installProduction "$@" ;;
    installPhp) installPhp "$@" ;;
    installHelmDiff) installHelmDiff "$@" ;;
    installCiliumCli) installCiliumCli "$@" ;;
    esac
}

main "$@"
