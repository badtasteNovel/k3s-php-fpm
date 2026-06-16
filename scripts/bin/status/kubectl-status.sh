#!/bin/bash
source environment/shell/sh.env
source $LIB/interactive/kubectl-choose.sh
svcIp() {
  chooseNamespace
  removeNamespaceContext
  kubectl get svc,ep -n $NS
}
podStatus(){
  kubectl get pods -A
  kubectl get ing -A
}
podHistory(){
  choosePod
  removePodContext
  kubectl get pod $POD -n $NS -o wide
}
help() {
  echo "查看kubernets的各種狀態"
  echo "Commands:"
  echo "  svcIp    - 查看svc 和 endpoint"
  echo "  podStatus - 查看kubernets 的pods 狀態"
}
main() {
  local command="${1:-}"
  shift || true

  case "$command" in
    svcIp)     svcIp "$@" ;;
    podStatus) podStatus "$@" ;;
    podHistory) podHistory "$@" ;;
    *) help "$@" ;;
  esac
}

main "$@"