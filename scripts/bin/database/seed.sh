DATABASE_CONNECTION="migrate_runner"
readonly DATABASE_CONNECTION

# ---------------------------------------------------------
# 私有穿透函式 (The "Safe" Tunnel)
# ---------------------------------------------------------
_kexec() {
    local seed_mode="$1"
    shift
    kubectl exec -i deployment/php-fpm-nginx -n web -c php-fpm -- \
        env SESSION_DRIVER=array SEED_MODE="$seed_mode" "$@"
}

deviceNameSeed() {
    gum style \
        --border rounded \
        --border-foreground 212 \
        --padding "1 2" \
        "🗄️  DeviceName Seeder"

    local mode
    mode=$(gum choose \
        --header "請選擇執行模式：" \
        "append  － 保留現有資料，僅新增" \
        "overwrite － 清空資料表後重新寫入" \
        "取消")

    case "$mode" in
    append*)
        gum confirm "確認以 append 模式執行？" || {
            gum style --foreground 240 "操作已取消。"
            return
        }
        _kexec append php artisan db:seed --class=DeviceNameSeeder --database="$DATABASE_CONNECTION" --force
        gum style --foreground 118 "✅ Append 完成！"
        ;;
    overwrite*)
        gum style --foreground 214 "⚠️  此操作將清空 device_names 資料表！"
        gum confirm "確定要覆蓋嗎？" || {
            gum style --foreground 240 "操作已取消。"
            return
        }
        _kexec overwrite php artisan db:seed --class=DeviceNameSeeder --database="$DATABASE_CONNECTION" --force
        gum style --foreground 118 "✅ Overwrite 完成！"
        ;;
    *)
        gum style --foreground 240 "操作已取消。"
        ;;
    esac
}

permissionRefresh() {
    gum style \
        --border rounded \
        --border-foreground 212 \
        --padding "1 2" \
        "🗄️  Permission Seeder"

    local mode
    mode=$(gum choose \
        --header "請選擇執行模式：" \
        "append  － 保留現有資料，僅新增" \
        "overwrite － 清空資料表後重新寫入" \
        "取消")

    case "$mode" in
    append*)
        gum confirm "確認以 append 模式執行？" || {
            gum style --foreground 240 "操作已取消。"
            return
        }
        _kexec append php artisan db:seed --class=PermissionSeeder --database="$DATABASE_CONNECTION" --force
        gum style --foreground 118 "✅ Append 完成！"
        ;;
    overwrite*)
        gum style --foreground 214 "⚠️  此操作將清空 admin_group_permissions 資料表！"
        gum confirm "確定要覆蓋嗎？" || {
            gum style --foreground 240 "操作已取消。"
            return
        }
        _kexec overwrite php artisan db:seed --class=PermissionSeeder --database="$DATABASE_CONNECTION" --force
        gum style --foreground 118 "✅ Overwrite 完成！"
        ;;
    *)
        gum style --foreground 240 "操作已取消。"
        ;;
    esac
}
main() {
    local command="${1:-}"
    shift || true
    case "$command" in
    deviceNameSeed) deviceNameSeed "$@" ;;
    permissionRefresh) permissionRefresh "$@" ;;
    *) help "$@" ;;
    esac
}

main "$@"
