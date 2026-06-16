#!/bin/bash
source environment/shell/sh.env
source $LIB/interactive/kubectl-choose.sh

# 新增：通用的 Owner 獲取邏輯
# 會回傳兩個值：資源名稱 ($1) 與 資源類型 ($2)
_getOwner() {
    local -n _name=$1
    local -n _kind=$2
    choosePod
    removePodContext

    local firstOwnerName
    local firstOwnerKind
    firstOwnerName=$(kubectl get pod $POD -n $NS -o jsonpath='{.metadata.ownerReferences[0].name}')
    firstOwnerKind=$(kubectl get pod $POD -n $NS -o jsonpath='{.metadata.ownerReferences[0].kind}')

    if [ "$firstOwnerKind" == "ReplicaSet" ]; then
        # Deployment 流程：往上找一層
        _kind="deployment"
        _name=$(kubectl get rs "$firstOwnerName" -n $NS -o jsonpath='{.metadata.ownerReferences[0].name}')
    elif [ "$firstOwnerKind" == "StatefulSet" ]; then
        # StatefulSet 流程：直接就是它
        _kind="statefulset"
        _name="$firstOwnerName"
    else
        # 備援：如果找不到 Owner (例如獨立 Pod)，就回傳 Pod 本身
        _kind="pod"
        _name="$POD"
    fi
}
_getAnyPodOwner() {
    local -n _name=$1
    local -n _kind=$2
    chooseAnyPod
    removePodContext

    local firstOwnerName
    local firstOwnerKind
    firstOwnerName=$(kubectl get pod $POD -n $NS -o jsonpath='{.metadata.ownerReferences[0].name}')
    firstOwnerKind=$(kubectl get pod $POD -n $NS -o jsonpath='{.metadata.ownerReferences[0].kind}')

    if [ "$firstOwnerKind" == "ReplicaSet" ]; then
        # Deployment 流程：往上找一層
        _kind="deployment"
        _name=$(kubectl get rs "$firstOwnerName" -n $NS -o jsonpath='{.metadata.ownerReferences[0].name}')
    elif [ "$firstOwnerKind" == "StatefulSet" ]; then
        # StatefulSet 流程：直接就是它
        _kind="statefulset"
        _name="$firstOwnerName"
    else
        # 備援：如果找不到 Owner (例如獨立 Pod)，就回傳 Pod 本身
        _kind="pod"
        _name="$POD"
    fi
}
restart(){
  local name kind
  _getOwner name kind
  # 雖然你原本寫 delete deployment，但建議用 rollout restart 比較安全
  # 這裡照你的舊邏輯寫 delete，但加上類別判斷
  kubectl delete "$kind" "$name" -n $NS
}

rollout(){
  local name kind
  _getOwner name kind
  echo "🚀 Rolling out $kind/$name..."
  kubectl rollout restart "$kind/$name" -n $NS
  kubectl rollout status "$kind/$name" -n $NS
}

stop(){
  local name kind
  _getOwner name kind
  echo "🛑 Stopping $kind/$name..."
  kubectl scale "$kind" "$name" --replicas=0 -n $NS 
}
forceDelete() {
  local name kind
  # 取得當前選定 Pod 的 Owner 資訊
  _getAnyPodOwner name kind

  echo "⚠️  Force deleting $kind/$name in namespace $NS..."
  
  # 1. 先嘗試正常刪除其控制器 (Deployment/StatefulSet)
  # 如果控制器還在，光刪 Pod 是沒用的，它會一直重啟
  kubectl delete "$kind" "$name" -n "$NS" --ignore-not-found=true

  # 2. 強制刪除該控制器關聯的所有 Pod
  # 使用 Label Selector 或是直接針對目前的 $POD 進行暴力清理
  # 這裡建議直接針對 $POD 執行，因為它是最直接卡住的地方
  kubectl delete pod "$POD" -n "$NS" --force --grace-period=0
  
  echo "✅ Force delete command sent."
}
help() {
    echo "Usage: $0 {restart|rollout|rolloutStateful|stop}"
}

main() {
  local command="${1:-}"
  shift || true
  case "$command" in
    restart) restart "$@" ;;
    rollout) rollout "$@" ;;
    rolloutStateful) rolloutStateful "$@" ;;
    forceDelete) forceDelete "$@" ;;
    stop) stop "$@" ;;
    *) help "$@" ;;
  esac
}

main "$@"