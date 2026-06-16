#!/bin/bash
# 從 .env 讀取特定 key 然後建成 literal secret

ENV_FILE=
NAMESPACE=service

parse_args() {
  for arg in "$@"; do
    case $arg in
      --env-path=*)  ENV_FILE="${arg#*=}" ;;
      --namespace=*) NAMESPACE="${arg#*=}" ;;
    esac
  done
}

validate() {
  local missing=()
  [ -z "$ENV_FILE" ]  && missing+=("--env-path")
  [ -z "$NAMESPACE" ] && missing+=("--namespace")

  if [ ${#missing[@]} -gt 0 ]; then
    echo "缺少必要參數: ${missing[*]}"
    echo "用法: $0 --env-path=<path> --namespace=<namespace>"
    exit 1
  fi

  if [ ! -f "$ENV_FILE" ]; then
    echo "找不到 env 檔案: $ENV_FILE"
    exit 1
  fi
}

main() {
  local secretName="${1:-}"
  shift || true

  [ -z "$secretName" ] && echo "缺少 secret name" && exit 1

  parse_args "$@"
  validate
  local userName
  local password
  userName=$(grep "^DB_USER=" "$ENV_FILE" | cut -d'=' -f2-)
  password=$(grep "^DB_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2-)
  kubectl create secret generic "$secretName" \
    --from-literal=password="${password}" \
    --from-literal=user="${userName}" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

}

main "$@"