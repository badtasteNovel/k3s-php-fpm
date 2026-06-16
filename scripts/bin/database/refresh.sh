DATABASE_CONNECTION="migrate_runner"
readonly DATABASE_CONNECTION

# ---------------------------------------------------------
# 調整後的私有穿透函式 (移除 seed_mode)
# ---------------------------------------------------------
_kexec() {
    kubectl exec -i deployment/php-fpm-nginx -n web -c php-fpm -- \
        env SESSION_DRIVER=array "$@"
}

refreshProduct() {
    gum style \
        --border double \
        --border-foreground 196 \
        --foreground 196 \
        --padding "1 2" \
        --bold \
        "🚨 終極警告：PRODUCT REFRESH 🚨" \
        "此操作將會重置生產資料！"

    # 第一重防線：二選一確認
    gum confirm "你真的、真的確定要執行 ProductSeeder 嗎？" --affirmative "是，我願意承擔責任" --negative "不，我按錯了" || {
        gum style --foreground 240 "呼... 差點出事。操作已取消。"
        return
    }

    # 第二重防線：隨機驗證碼 (防止肌肉記憶連續按 Enter)
    local code=$((RANDOM % 9000 + 1000))
    gum style --foreground 214 "請輸入驗證碼以證明你現在是清醒的：$code"
    local input_code
    input_code=$(gum input --placeholder "在此輸入上方數字")

    if [ "$input_code" != "$code" ]; then
        gum style --foreground 196 "❌ 驗證碼錯誤！操作已緊急終止。"
        return
    fi

    # 第三重防線：最後的死亡倒數
    gum spin --spinner dot --title "最後思考機會 (5秒後執行)..." -- sleep 5

    # 執行指令
    gum style --foreground 212 "🚀 正在發射指令到 Kubernetes 叢集..."
    _kexec php artisan db:seed --class=ProductSeeder --database="$DATABASE_CONNECTION" --force

    gum style --border rounded --border-foreground 118 --padding "1 2" --foreground 118 "✅ Product 資料表已完成重新整理。"
}
refreshProductV2() {
    gum style \
        --border double \
        --border-foreground 196 \
        --foreground 196 \
        --padding "1 2" \
        --bold \
        "🚨 終極警告：PRODUCT REFRESH V2 🚨" \
        "此操作將會重置生產資料（V2 版本）！"

    # 第一重防線：二選一確認
    gum confirm "你真的、真的確定要執行 ProductSeederV2 嗎？" --affirmative "是，我願意承擔責任" --negative "不，我按錯了" || {
        gum style --foreground 240 "呼... 差點出事。操作已取消。"
        return
    }

    # 第二重防線：隨機驗證碼
    local code=$((RANDOM % 9000 + 1000))
    gum style --foreground 214 "請輸入驗證碼以證明你現在是清醒的：$code"
    local input_code
    input_code=$(gum input --placeholder "在此輸入上方數字")

    if [ "$input_code" != "$code" ]; then
        gum style --foreground 196 "❌ 驗證碼錯誤！操作已緊急終止。"
        return
    fi

    # 第三重防線：最後的死亡倒數
    gum spin --spinner dot --title "最後思考機會 (5秒後執行)..." -- sleep 5

    # 執行指令 (Seeder 名稱已更新為 ProductSeederV2)
    gum style --foreground 212 "🚀 正在發射指令到 Kubernetes 叢集..."
    _kexec php artisan db:seed --class=ProductSeederV2 --database="$DATABASE_CONNECTION" --force

    gum style --border rounded --border-foreground 118 --padding "1 2" --foreground 118 "✅ Product V2 資料表已完成重新整理。"
}
refreshProductV3() {
    gum style \
        --border double \
        --border-foreground 196 \
        --foreground 196 \
        --padding "1 2" \
        --bold \
        "🚨 終極警告：PRODUCT REFRESH V3 🚨" \
        "此操作將會重置生產資料（V3 版本）！"

    # 第一重防線：二選一確認
    gum confirm "你真的、真的確定要執行 ProductSeederV3 嗎？" --affirmative "是，我願意承擔責任" --negative "不，我按錯了" || {
        gum style --foreground 240 "呼... 差點出事。操作已取消。"
        return
    }

    # 第二重防線：隨機驗證碼
    local code=$((RANDOM % 9000 + 1000))
    gum style --foreground 214 "請輸入驗證碼以證明你現在是清醒的：$code"
    local input_code
    input_code=$(gum input --placeholder "在此輸入上方數字")

    if [ "$input_code" != "$code" ]; then
        gum style --foreground 196 "❌ 驗證碼錯誤！操作已緊急終止。"
        return
    fi

    # 第三重防線：最後的死亡倒數
    gum spin --spinner dot --title "最後思考機會 (5秒後執行)..." -- sleep 5

    # 執行指令 (Seeder 名稱已更新為 ProductSeederV2)
    gum style --foreground 212 "🚀 正在發射指令到 Kubernetes 叢集..."
    _kexec php artisan db:seed --class=ProductSeederV3 --database="$DATABASE_CONNECTION" --force

    gum style --border rounded --border-foreground 118 --padding "1 2" --foreground 118 "✅ Product V3 資料表已完成重新整理。"
}
main() {
    local command="${1:-}"
    shift || true

    case "$command" in
    refreshProduct) refreshProduct "$@" ;;
    refreshProductV2) refreshProductV2 "$@" ;; # 1. 加入 case 匹配
    refreshProductV3) refreshProductV3 "$@" ;;
    *)
        local choice
        # 2. 在 gum choose 中加入 "refreshProductV2" 選項
        choice=$(gum choose "refreshProduct" "refreshProductV2" "refreshProductV3" "取消退出")

        # 3. 根據選擇執行對應函式
        case "$choice" in
        "refreshProduct") refreshProduct ;;
        "refreshProductV2") refreshProductV2 ;;
        "refreshProductV3") refreshProductV3 ;;
        *) exit 0 ;;
        esac
        ;;
    esac
}

main "$@"
