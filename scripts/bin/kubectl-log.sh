#!/bin/bash
source environment/shell/sh.env
source $LIB/interactive/kubectl-choose.sh

logPod(){
  choosePod
  removePodContext
  kubectl logs -f $POD -n $NS -c $CONTAINER
}
logAnyPod(){
  chooseAnyPod
  removePodContext
  if [ -z "$CONTAINER" ]; then
    kubectl logs -f $POD -n $NS
  else
    kubectl logs -f $POD -n $NS -c $CONTAINER
  fi
}
logJob(){
  chooseJob
  removeJobContext
  local pod
  pod=$(kubectl get pods -n $NS -l job-name=$JOB --no-headers -o custom-columns=":metadata.name" | tail -1)
  
  if [ -z "$pod" ]; then
    gum style --foreground 196 "❌ 找不到與 Job '$JOB' 關聯的 Pod"
    exit 1
  fi

  local containers
  containers=$(kubectl get pod $pod -n $NS -o jsonpath='{.spec.containers[*].name} {.spec.initContainers[*].name}')
  local count
  count=$(echo $containers | wc -w)

  if [ $count -gt 1 ]; then
    local container
    container=$(echo $containers | tr ' ' '\n' | gum choose --header "選擇容器：")
    kubectl logs -f $pod -n $NS -c $container
  else
    kubectl logs -f $pod -n $NS
  fi
}
toYaml(){
  choosePod
  removePodContext
  kubectl get pod $POD -n $NS -o yaml
}
describeAnyPod(){
  chooseAnyPod
  removePodContext
  gum style --foreground 212 "🔍 正在查看 $POD 的詳細狀態..."
  kubectl describe pod $POD -n $NS | less -R -P "操作 (G 到底部 / 搜尋 q 離開)"
}
describePod(){
  choosePod
  removePodContext
  gum style --foreground 212 "🔍 正在查看 $POD 的詳細狀態..."
  kubectl describe pod $POD -n $NS | less -R -P "操作 (G 到底部 / 搜尋 q 離開)"
}
describeJob(){
  chooseJob
  removeJobContext
  gum style --foreground 212 "🔍 正在查看 Job: $JOB_NAME 的詳細狀態..."
  kubectl describe job $JOB -n $NS | less -R -P "操作 (G 到底部 / /搜尋 q 離開)"
}
main() {
  local command="${1:-}"
  shift || true
  case "$command" in
      logPod) logPod "$@" ;;
      logJob) logJob "$@" ;;
      logAnyPod) logAnyPod "$@" ;;
      describeAnyPod) describeAnyPod "$@" ;;
      describeYaml) describeYaml "$@" ;;
      describePod) describePod "$@" ;;
      describeJob) describeJob "$@" ;;
    *) help "$@" ;;
  esac
}

main "$@"