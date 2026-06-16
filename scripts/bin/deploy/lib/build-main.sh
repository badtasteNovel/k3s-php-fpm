#!/bin/bash

# 最後會發布的映像檔，包含nginx 和php

_buildPhp() {
    local imageName="my-php-release:debian-bookworm"
    local imagePath="./docker/web/app/php-fpm/release.Dockerfile"
    ionice -c 3 docker build -f $imagePath -t $imageName .
}
_buildNginx() {
    local imageName="my-inner-unprivileged-nginx:alpine"
    local imagePath="./docker/web/app/nginx/Dockerfile.nginx"
    ionice -c 3 docker build -f $imagePath -t $imageName .
}
_buildNginxNoCache() {
    local imageName="my-inner-unprivileged-nginx:alpine"
    local imagePath="./docker/web/app/nginx/Dockerfile.nginx"
    ionice -c 3 docker build --pull -f $imagePath -t $imageName .
}
_staticImageExistsInRegistry() {
    local repoName="$1"
    local nodeIp
    nodeIp=$(kubectl get nodes -o wide 2>/dev/null | awk 'NR>1 {print $6}' | head -n 1) || return 1
    [ -z "$nodeIp" ] && return 1
    curl -sk "https://${nodeIp}:30500/v2/${repoName}/tags/list" 2>/dev/null | grep -q '"latest"'
}
_buildOpsToolbox() {
    local imageName="my-ops-toolbox:latest"
    local imagePath="./docker/ops/toolbox.Dockerfile"
    if _staticImageExistsInRegistry "my-ops-toolbox"; then
        echo "✅ my-ops-toolbox:latest 已在 registry，跳過 build"
        return 0
    fi
    ionice -c 3 docker build -f $imagePath -t $imageName .
}
_buildOpsPHP() {
    local imageName="my-ops-php:latest"
    local imagePath="./docker/ops/ops.Dockerfile"
    ionice -c 3 docker build -f $imagePath -t $imageName .
}
