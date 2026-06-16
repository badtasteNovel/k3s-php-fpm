#!/bin/bash
_chooseNamespace() {
  local namespace
  namespace=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | gum filter --header "選擇 Namespace..." --placeholder="")
  if [ -z "$namespace" ]; then exit 1; fi
  echo "$namespace"
}
chooseJob() {
  local namespace
  local jobs
  local selected_job
  namespace=$(_chooseNamespace)
  jobs=$(kubectl get job -n $namespace  --no-headers -o custom-columns=":metadata.name")
  selected_job=$(echo "$jobs" | gum choose --header "選擇目標 Job ($namespace)")
  echo "NS=$namespace" > .job_context
  echo "JOB=$selected_job" >> .job_context
}
choosePod() {
  local namespace
  local pods
  local selected_pod
  local containers
  namespace=$(_chooseNamespace)
  pods=$(kubectl get pods -n $namespace --field-selector=status.phase=Running --no-headers | grep -v "Terminating" | awk '{print $1}')
  if [ -z "$pods" ]; then
    gum style --foreground 196 "❌ 空間 '$namespace' 內沒有正在運行的 Pod。"
    exit 1
  fi
  selected_pod=$(echo "$pods" | gum choose --header "選擇目標 Pod ($namespace)")
  if [ -z "$selected_pod" ]; then exit 1; fi
  containers=$(kubectl get pod $selected_pod -n $namespace -o jsonpath='{.spec.containers[*].name}')
  count=$(echo $containers | wc -w)
   if [ $count -gt 1 ]; then
    container=$(echo $containers | tr ' ' '\n' | gum choose --header "選擇容器：")
  else
    container=$containers
  fi
  echo "NS=$namespace" > .pod_context
  echo "POD=$selected_pod" >> .pod_context
  echo "CONTAINER=$container" >> .pod_context
}

chooseAnyPod() {
  local namespace
  local pods_with_status
  local selected_line
  local selected_pod
  local containers
  local container

  # 1. 取得 Namespace
  namespace=$(_chooseNamespace)

  # 2. 取得所有 Pod 及其狀態 (排除 Terminating)
  # 格式會變成: pod-name status
  pods_with_status=$(kubectl get pods -n "$namespace" --no-headers | grep -v "Terminating" | awk '{print $1 "  [" $3 "]" }')

  if [ -z "$pods_with_status" ]; then
    gum style --foreground 196 "❌ 空間 '$namespace' 內沒有任何 Pod。"
    exit 1
  fi

  # 3. 讓使用者選擇 (顯示名稱與狀態)
  selected_line=$(echo "$pods_with_status" | gum choose --header "選擇目標 Pod ($namespace) - 顯示所有狀態")
  if [ -z "$selected_line" ]; then exit 1; fi

  # 提取真正的 Pod 名稱 (取第一欄)
  selected_pod=$(echo "$selected_line" | awk '{print $1}')

  # 4. 取得容器列表
  containers=$(kubectl get pod "$selected_pod" -n "$namespace" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
  
  # 防呆：如果 Pod 處於 ImagePullBackOff 或尚未建立容器
  if [ -z "$containers" ]; then
    gum style --foreground 214 "⚠️  警告：Pod '$selected_pod' 目前狀態無法取得容器資訊。"
    exit 1
  fi

  count=$(echo "$containers" | wc -w)
  if [ "$count" -gt 1 ]; then
    container=$(echo "$containers" | tr ' ' '\n' | gum choose --header "選擇容器：")
  else
    container=$containers
  fi

  # 5. 存入上下文
  echo "NS=$namespace" > .pod_context
  echo "POD=$selected_pod" >> .pod_context
  echo "CONTAINER=$container" >> .pod_context
  
  gum style --foreground 82 "✅ 已選取: $namespace / $selected_pod ($container)"
}
chooseNamespace(){
  local namespace
  namespace=$(_chooseNamespace)
  echo "NS=$namespace" > .ns_context
}
removePodContext(){
  source .pod_context && rm .pod_context
}
removeJobContext(){
  source .job_context && rm .job_context
}
removeNamespaceContext(){
  source .ns_context && rm .ns_context
}
usage() {
  echo "互動式腳本"
  echo "Usage: $0 <command>"
  echo "Commands:"
  echo "  chooseNamespace    - 選擇kubernets namespace"
  echo "  choosePod - 選擇kubernets Pod"
  echo "  chooseJob - 選擇kubernets Job"
}
# --- Entry Point ---
main() {
  local command="${1:-}"
  shift || true

  case "$command" in
    chooseNamespace)   chooseNamespace"$@" ;; # 幫助浮動ip 建立自定義的systemctl Exec
    choosePod) choosePod "$@" ;;
    chooseJob) chooseJob "$@" ;;
    removePodContext) removePodContext "$@" ;;
    removeJobContext) removeJobContext "$@" ;;
    removeNamespaceContext) removeNamespaceContext "$@" ;;
    *)       usage; exit 1 ;;
  esac
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi