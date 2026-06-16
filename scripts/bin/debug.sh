#!/bin/bash
source environment/shell/sh.env
source $LIB/interactive/kubectl-choose.sh

# =============================================================
# 腳本名稱: k8s-sniff-tool.sh
# 功能: 跨節點網路抓包與連線測試工具
# =============================================================

# 取得節點列表並選擇
_selectNodes() {
    # 1. 選擇來源節點
    SOURCE_NODE=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | gum choose --header "1. 選擇發起請求的 Node (Server)")
    [[ -z "$SOURCE_NODE" ]] && echo "取消操作" && exit 0

    # 2. 選擇目標節點
    TARGET_NODE=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | gum choose --header "2. 選擇目標接收的 Node (Target)")
    [[ -z "$TARGET_NODE" ]] && echo "取消操作" && exit 0

    # 3. 取得目標 Internal IP
    TARGET_IP=$(kubectl get node "$TARGET_NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    [[ -z "$TARGET_IP" ]] && echo "❌ 錯誤: 無法取得目標 IP" && exit 1
}

# 執行偵錯 Pod
debugNodeNetwork() {
    _selectNodes
    local sniffer_name="sniffer-$(date +%s)"
    local sniff_cmd="tcpdump -i any -nn host $TARGET_IP and not port 22"
    local test_cmd="nc -zv $TARGET_IP 10250"

    clear
    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 60 --margin "1 2" --padding "1 2" \
        "🚀 跨節點偵錯：從 $SOURCE_NODE 到 $TARGET_NODE" "" \
        "目標 IP: $TARGET_IP" \
        "" \
        "👉 輸入 'go'   : 開始乾淨抓包 (排除 SSH)" \
        "👉 輸入 'test' : 直接測試目標 10250 Port"

    # 啟動 Pod 並釘在 SOURCE_NODE
    # 加入 enableServiceLinks: false 防止環境變數過多導致啟動緩慢
    kubectl run "$sniffer_name" --rm -it \
        --image=nicolaka/netshoot -n default \
        --overrides='{
            "spec": {
                "nodeName": "'"$SOURCE_NODE"'",
                "hostNetwork": true,
                "enableServiceLinks": false
            }
        }' -- bash -c "
            echo 'alias go=\"$sniff_cmd\"' > /tmp/.debug_rc
            echo 'alias test=\"$test_cmd\"' >> /tmp/.debug_rc
            echo 'echo \"✅ 準備就緒！已自動鎖定目標 IP: $TARGET_IP\"' >> /tmp/.debug_rc
            echo 'echo \"👉 輸入 go 抓包，輸入 test 測試連線\"' >> /tmp/.debug_rc
            bash --rcfile /tmp/.debug_rc
        "
}
# 針對pod
debugShell() {
    choosePod
    removePodContext
    gum style --foreground 212 "🛠️ 正在啟動除錯容器 ($POD)..."

    kubectl debug -it $POD -n $NS -q \
        --image=alpine:latest \
        --target=$CONTAINER \
        --profile=general \
        -- sh -c "echo '🚀 除錯環境就緒 (Alpine)'; echo '📂 已切換至主容器根目錄 (/proc/1/root)'; cd /proc/1/root && sh"
}
debugNetwork() {
    choosePod
    removePodContext
    SNIFF_CMD="tcpdump -i any udp -nn"
    CONFIG_READ="cat /etc/resolv.conf"

    clear
    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 50 --margin "1 2" --padding "1 2" \
        "🛠️  網路調試準備就緒" "目標容器: $CONTAINER" "" "進去後請輸入: go" "指令內容: $SNIFF_CMD" \
        "🔍  網路config" "" "進去後請輸入: read" "指令內容: $CONFIG_READ"

    echo "🚀 正在連線至容器 [$CONTAINER]..."

    # --- 進入 Pod 階段 ---
    kubectl debug -it $POD -n $NS -q \
        --image=nicolaka/netshoot \
        --target=$CONTAINER \
        --profile=sysadmin \
        -- bash -c "
            echo 'cd /proc/1/root' > /tmp/.debug_rc
            echo 'alias go=\"$SNIFF_CMD\"' >> /tmp/.debug_rc
            echo 'alias read=\"$CONFIG_READ\"' >> /tmp/.debug_rc
            echo 'echo \"👉 已自動載入指令，請輸入 go 開始抓包\"' >> /tmp/.debug_rc
            bash --rcfile /tmp/.debug_rc
          "
}
shellAsRoot() {
    # 1. 呼叫你之前的選擇 Pod 函數
    choosePod
    removePodContext
    # 從 .pod_context 讀取變數 (假設你的 choosePod 有寫入此檔案)

    echo "🚀 正在嘗試進入：$NS / $POD ($CONTAINER)"

    kubectl exec -it $POD -n $NS -c $CONTAINER --user root -- /bin/bash ||
        kubectl exec -it $POD -n $NS -c $CONTAINER --user root -- /bin/sh
}
shell() {
    choosePod
    removePodContext
    echo "🚀 正在嘗試進入：$NS / $POD ($CONTAINER)"
    kubectl exec -it $POD -n $NS -c $CONTAINER -- /bin/bash ||
        kubectl exec -it $POD -n $NS -c $CONTAINER -- /bin/sh
}
shellSql() {
    local POD="database-0"
    local NS="web"
    local CONTAINER="postgres-db"

    local POSTGRES_USER POSTGRES_DB
    POSTGRES_USER=$(grep '^APP_POSTGRES_USER=' environment/.env | cut -d= -f2)
    POSTGRES_DB=$(grep '^APP_POSTGRES_DB=' environment/.env | cut -d= -f2)

    echo "🚀 正在連線至 $NS/$POD..."

    kubectl exec -it $POD -n $NS -- psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
    # \d tablename 查看資料表結構
}
shellTemporalSql() {
    local POD="dapr-workflow-database-0"
    local NS="service"
    local CONTAINER="temporal-postgre-db"

    local POSTGRES_USER POSTGRES_DB
    POSTGRES_USER=$(grep '^POSTGRES_USER=' environment/postgresql/dapr-workflow/dapr-workflow.env | cut -d= -f2)
    POSTGRES_DB=$(grep '^POSTGRES_DB=' environment/postgresql/dapr-workflow/dapr-workflow.env | cut -d= -f2)

    echo "🚀 正在連線至 $NS/$POD..."
    kubectl exec -it $POD -n $NS -- psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
}
debugImage() {
    # 使用 gum input 取得 Image 名稱，並提供預設值
    local SELECTED_IMAGE=$(gum input \
        --placeholder "輸入要 debug 的 Image 名稱 (例如: my-dev-php-fpm:debian-bookworm)" \
        --value "my-dev-php-fpm:debian-bookworm" \
        --header "🔍 進入臨時容器進行檢查")

    # 如果使用者直接按下 Esc 或沒輸入，就跳出
    if [ -z "$SELECTED_IMAGE" ]; then
        echo "已取消操作。"
        return 1
    fi

    echo "🚀 正在啟動臨時容器: $SELECTED_IMAGE ..."

    docker run --rm -it --entrypoint "" "$SELECTED_IMAGE" sh -c "if [ -x /bin/bash ]; then exec /bin/bash; else exec sh; fi"
}
# 程式主入口
main() {
    local command="${1:-}"
    shift || true

    case "$command" in
    debugNodeNetwork) debugNodeNetwork "$@" ;;
    debugNetwork) debugNetwork "$@" ;;
    debugShell) debugShell "$@" ;;
    shellAsRoot) shellAsRoot "$@" ;;
    shell) shell "$@" ;;
    shellSql) shellSql "$@" ;;
    shellTemporalSql) shellTemporalSql "$@" ;;
    debugImage) debugImage "$@" ;;
    *) help "$@" ;;
    esac
}

# 啟動程式
main "$@"
