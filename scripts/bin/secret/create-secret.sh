#!/bin/bash
CERT_PATH=
KEY_PATH=
NAMESPACE=
TYPE=

parse_args() {
  for arg in "$@"; do
    case $arg in
      --cert-path=*)  CERT_PATH="${arg#*=}" ;;
      --key-path=*)   KEY_PATH="${arg#*=}" ;;
      --namespace=*)  NAMESPACE="${arg#*=}" ;;
      --type=*)       TYPE="${arg#*=}" ;;
    esac
  done
}
validate() {
  local missing=()
  [ -z "$CERT_PATH" ]  && missing+=("--cert-path")
  [ -z "$KEY_PATH" ]   && missing+=("--key-path")
  [ -z "$NAMESPACE" ]  && missing+=("--namespace")

  if [ ${#missing[@]} -gt 0 ]; then
    echo "缺少必要參數: ${missing[*]}"
    exit 1
  fi
}

_createTls() {
  kubectl create secret tls "$1" \
    --cert="$CERT_PATH" \
    --key="$KEY_PATH" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -
}

_createGeneric() {
  kubectl create secret generic "$1" \
    --from-file=cert.pem="$CERT_PATH" \
    --from-file=key.pem="$KEY_PATH" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -
}
main() {
  local secretName="${1:-}"
  shift || true

  [ -z "$secretName" ] && echo "缺少 secret name" && exit 1

  parse_args "$@"
  validate

  if [ -z "$TYPE" ]; then
    TYPE=$(printf 'generic\ntls' | gum choose --header "選擇 secret 類型：")
    [ -z "$TYPE" ] && echo "已取消" && exit 0
  fi

  case $TYPE in
    tls)     _createTls "$secretName" ;;
    generic) _createGeneric "$secretName" ;;
    *)       echo "不支援的類型: $TYPE"; exit 1 ;;
  esac
}

main "$@"