#!/bin/bash
TARGET="$1"
shift

if [ -z "$TARGET" ] || [ ! -f "$TARGET" ]; then
  echo "用法: $0 <script.sh> [args...]"
  exit 1
fi

FUNCS=$(grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$TARGET" \
  | sed 's/().*//' \
  | grep -Ev '^(main|_)')

if [ -z "$FUNCS" ]; then
  echo "找不到可用函數"
  exit 1
fi

CHOICE=$(echo "$FUNCS" | gum choose --header "選擇要執行的函數 ($TARGET)：")

[ -z "$CHOICE" ] && echo "已取消" && exit 0

bash "$TARGET" "$CHOICE" "$@"