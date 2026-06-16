#!/bin/bash

# 定義想要安裝的插件清單
# 你可以隨時在這個陣列中增加新的插件名稱，例如 "ctx" "ns" "neat"
KREW_PLUGINS=(
    "exec-as"
)

main() {

    for plugin in "${KREW_PLUGINS[@]}"; do
        if kubectl krew list | grep -q "^$plugin$"; then
            echo "--- 插件 [$plugin] 已經安裝，跳過。"
        else
            echo "--- 正在安裝插件: [$plugin]..."
            kubectl krew install "$plugin"
        fi
    done
}

main "$@"