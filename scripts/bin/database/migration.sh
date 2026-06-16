DATABASE_CONNECTION="migrate_runner"
readonly DATABASE_CONNECTION
# ---------------------------------------------------------
# 私有穿透函式 (The "Safe" Tunnel)
# ---------------------------------------------------------
_kexec() {
    # 使用 env 強制注入臨時變數，這不會改變 Pod 內的持久設定
    # 只會影響這一次透過 kubectl 執行的 php 指令
    kubectl exec -i deployment/php-fpm-nginx -n web -c php-fpm -- \
        env SESSION_DRIVER=array "$@"
}

# ---------------------------------------------------------
# 常用指令封裝
# ---------------------------------------------------------

# 開啟容器一定要開migrate 否則 php 指令無法送出。
migrate() {
    if gum confirm "確認要在 [web] 執行 migrate 嗎？"; then

        _kexec php artisan migrate --database="$DATABASE_CONNECTION" --force

        gum style --foreground 118 "✅ 資料庫遷移成功！"
    else
        gum style --foreground 240 "操作已取消。"
    fi

}
rollback() {
    if gum confirm "確認要在 [web] 執行 rollback 嗎？"; then
        _kexec php artisan migrate:rollback --database="$DATABASE_CONNECTION" --force

        gum style --foreground 118 "✅ 資料庫遷移成功！"
    else
        gum style --foreground 240 "操作已取消。"
    fi
}
# 2. 危險重置 (會刪除所有資料表)
fresh() {
    gum style --foreground 196 --border double --align center --width 50 "危險操作警告" "這將會刪除所有資料表並重新執行 Seed！"

    # 2. 確認攔截
    if gum confirm "你確定要對 [web] 命名空間執行 migrate:fresh 嗎？" \
        --selected.background 196 \
        --unselected.background 240 \
        --affirmative "是的，我確定" \
        --negative "不，快取消" \
        --default=false; then
        gum style --foreground 212 "🚀 正在執行資料庫重置..."

        # 3. 簡化後的指令：直接執行 php artisan
        _kexec php artisan migrate:fresh --seed --database="$DATABASE_CONNECTION" --force

        gum style --foreground 118 "✅ 資料庫重置與 Seed 執行完成！"
    else
        gum style --foreground 240 "已取消操作。"
        exit 0
    fi
}
freshPanel() {
    if gum confirm "你要增加 queue time panel 的設定嗎？" \
        --selected.background 196 \
        --unselected.background 240 \
        --affirmative "是的，我確定" \
        --negative "不，快取消" \
        --default=false; then
        gum style --foreground 212 "🚀 正在執行資料庫重置..."

        # 3. 簡化後的指令：直接執行 php artisan
        _kexec php artisan db:seed --class=QueueTimePanelSeeder --database="$DATABASE_CONNECTION" --force

        gum style --foreground 118 "✅ Queue Time Panel seed 執行完成！"
    else
        gum style --foreground 240 "已取消操作。"
        exit 0
    fi
}
mock() {
    gum style --foreground 196 --border double --align center --width 50 "危險操作警告" "這將會刪除所有資料表並重新執行 Seed（含 MockData）！"

    if gum confirm "你確定要對 [web] 命名空間執行 mock fresh 嗎？" \
        --selected.background 196 \
        --unselected.background 240 \
        --affirmative "是的，我確定" \
        --negative "不，快取消" \
        --default=false; then
        gum style --foreground 212 "🚀 正在執行資料庫重置（含 MockData）..."

        _kexec MOCK_DATA=true php artisan migrate:fresh --seed --database="$DATABASE_CONNECTION" --force

        gum style --foreground 118 "✅ 資料庫重置與 MockData Seed 執行完成！"
    else
        gum style --foreground 240 "已取消操作。"
        exit 0
    fi
}
freshApproval() {
    if gum confirm "你要增加 產品核准 的設定嗎？" \
        --selected.background 196 \
        --unselected.background 240 \
        --affirmative "是的，我確定" \
        --negative "不，快取消" \
        --default=false; then
        gum style --foreground 212 "🚀 正在執行資料庫重置..."

        # 3. 簡化後的指令：直接執行 php artisan
        _kexec php artisan db:seed --class=ApprovalSeeder --database="$DATABASE_CONNECTION" --force

        gum style --foreground 118 "✅ Product Approval Control seed 執行完成！"
    else
        gum style --foreground 240 "已取消操作。"
        exit 0
    fi
}
main() {
    local command="${1:-}"
    shift || true
    case "$command" in
    migrate) migrate "$@" ;;
    fresh) fresh "$@" ;;
    mock) mock "$@" ;;
    freshPanel) freshPanel "$@" ;;
    freshApproval) freshApproval "$@" ;;
    rollback) rollback "$@" ;;
    *) help "$@" ;;
    esac
}

main "$@"
