source environment/shell/sh.env
source $LIB/image/pull.sh


# 自己做的映像檔，development環境所要抓的
dev(){
  importOnly "${DEV_IMAGES[@]}"
}
# 自己做的映像檔，production環境所要抓的
production(){
  importProductionOnly "${PROD_IMAGES[@]}"
}
# 抓取官方各種外部的映像檔，事先用docker載下來，再給k3s 使用就不會報錯了。k3s 的自動抓取就不會抓不到
online(){
  pull "${DOKCER_IMAGES[@]}"
}
help() {
  echo "抓取k3s啟動時所需要的映像檔"
  echo "Commands:"
  echo "dev    - 自己做的映像檔，development環境所要抓的"
  echo "production - 自己做的映像檔，production環境所要抓的"
  echo "online - 官方所做的映像檔"
}
main(){
  local command="${1:-}"
  shift || true
  
  for arg in "$@"; do
    case $arg in
      --host=*) export REGISTRY_HOST="${arg#*=}" ;;
      --port=*) export REGISTRY_PORT="${arg#*=}" ;;
    esac
  done

  case "$command" in
    dev) dev "$@" ;;
    production) production "$@" ;;
    online) online "$@" ;;
    *) help "$@" ;;
  esac
}

main "$@"