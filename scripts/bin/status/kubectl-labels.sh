#!/bin/bash
source environment/shell/sh.env
source $LIB/interactive/kubectl-choose.sh
podLabels(){
  chooseNamespace
  removeNamespaceContext
  kubectl get pods -n $NS --show-labels
}
nodeLabels(){
  kubectl get nodes --show-labels
}
namespaceLabels(){
  kubectl get namespace --show-labels
}
help() {
  echo "查看kubernets的各種狀態"
  echo "Commands:"
  echo "  podLabels    - 查看svc 和 endpoint"
  echo "  nodeLabels - 查看kubernets 的pods 狀態"
}
main() {
  local command="${1:-}"
  shift || true

  case "$command" in
    podLabels) podLabels "$@" ;;
    nodeLabels) nodeLabels "$@" ;;
    namespaceLabels) namespaceLabels "$@" ;; 
    *) help "$@" ;;
  esac
}

main "$@"