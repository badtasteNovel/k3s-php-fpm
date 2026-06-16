#!/bin/bash
ENV_PATH=
NAMESPACE=
parse_args() {
  for arg in "$@"; do
    case $arg in
      --env-path=*)  ENV_PATH="${arg#*=}" ;;
      --namespace=*)  NAMESPACE="${arg#*=}" ;;
    esac
  done
}
validate() {
  local missing=()
  [ -z "$ENV_PATH" ]  && missing+=("--env-path")
  [ -z "$NAMESPACE" ]  && missing+=("--namespace")

  if [ ${#missing[@]} -gt 0 ]; then
    echo "缺少必要參數: ${missing[*]}"
    exit 1
  fi
}

main() {
  local secretName="${1:-}"
  shift || true

  [ -z "$secretName" ] && echo "缺少 secret name" && exit 1

  parse_args "$@"
  validate
  
  kubectl create secret generic $secretName --from-env-file=$ENV_PATH -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
}

main "$@"