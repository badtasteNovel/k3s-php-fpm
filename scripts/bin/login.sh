#!/bin/bash
source .env.task
dockerLogin(){
    local username="${DOCKER_USERNAME}"
    local pat="${DOCKER_PAT}"
    # 如果是 Docker Hub，Registry 網址通常對應到 index.docker.io 或 https://index.docker.io/v1/
    local registry="index.docker.io"

    # 1. 安全性檢查
    if [ -z "$username" ] || [ -z "$pat" ]; then
        echo "Error: DOCKER_USERNAME or DOCKER_PAT is not set."
        exit 1
    fi

    # 2. 檢查是否已經登入過
    # 檢查 config.json 是否存在且包含該 registry 的 auth 資訊
    if [ -f "$HOME/.docker/config.json" ] && grep -q "$registry" "$HOME/.docker/config.json"; then
        echo "[INFO] Docker 已經登入過 $registry，跳過重複登入。"
        return 0
    fi

    # 3. 執行登入
    echo "Starting login to Docker Hub..."
    echo "$pat" | docker login -u "$username" --password-stdin
    
    if [ $? -eq 0 ]; then
        echo "[SUCCESS] Docker login completed."
    else
        echo "[FAILED] Docker login failed."
        exit 1
    fi
}
main() {
  local command="${1:-}"
  shift || true
  case "$command" in
    dockerLogin) dockerLogin "$@" ;;
    *) help "$@" ;;
  esac
}

main "$@"