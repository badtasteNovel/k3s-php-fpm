#!/bin/bash
set -euo pipefail

openFireWallForK3s() {
    sudo ufw allow from 10.42.0.0/16
    sudo ufw allow from 10.43.0.0/16
    sudo ufw reload
}

# 為了讓 sudoer 可以直接免密碼執行某些指令
# 在ci/cd 沒有辦法手動輸入密碼，所以只能開放特定指令的免密碼權限
# 其實ci/cd 的服務有些會推出 rootless 版本服務，但是因為 k3s 目前並沒有發布 rootless 版本。
# 在2026/4/1 k3s rootless 版本尚在實驗階段， 因此只能使用sudoer 下去執行。
openSudoerNounPassword(){
    local TARGET_USER="${SUDO_USER:-$USER}"
    local SUDOERS_FILE="/etc/sudoers.d/devops-nopasswd"

    if [ "$EUID" -ne 0 ]; then
        echo "請用 sudo 執行此腳本"
        exit 1
    fi

    cat > "$SUDOERS_FILE" << EOF
# DevOps 免密碼設定 - 由腳本自動生成
# 生成時間: $(date)

${TARGET_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/k3s
EOF

    if visudo -cf "$SUDOERS_FILE"; then
        chmod 440 "$SUDOERS_FILE"
        echo "✅ 設定完成：$SUDOERS_FILE"
        echo "✅ 使用者 ${TARGET_USER} 已可免密碼執行 k3s / docker"
    else
        echo "❌ sudoers 語法錯誤，已回滾"
        rm -f "$SUDOERS_FILE"
        exit 1
    fi
}

main() {
    case "${1:-}" in
        firewall)  openFireWallForK3s ;;
        open)    openSudoerNounPassword ;;
        *)         echo "Usage: $0 {firewall|open}"; exit 1 ;;
    esac
}

main "$@"