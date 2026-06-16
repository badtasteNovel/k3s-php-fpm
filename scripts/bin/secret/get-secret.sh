#!/bin/bash
NAMESPACE=

parse_args() {
  for arg in "$@"; do
    case $arg in
      --namespace=*)  NAMESPACE="${arg#*=}" ;;
    esac
  done
}
main() {
  local secretName="${1:-}"
  shift || true
  parse_args
  kubectl get secret $secretName  -n $NAMESPACE -o json | jq '.data | map_values(@base64d)'
}

main "$@"