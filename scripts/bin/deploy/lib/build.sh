#!/bin/bash
PHP_BASE_IMAGE_NAME=my-php-base:8.4
PHP_BUILDER_IMAGE_NAME=my-php-builder:8.4
PHP_BASE_IMAGE_PATH=./docker/web/app/php-fpm/base.Dockerfile
PHP_BUILDER_IMAGE_PATH=./docker/web/app/php-fpm/builder.Dockerfile
PHP_RELEASE_IMAGE_PATH=./docker/web/app/php-fpm/release.Dockerfile
# start base
_skipBuildBase(){
    if docker image inspect $PHP_BASE_IMAGE_NAME > /dev/null 2>&1; then
        echo "✅ $PHP_BASE_IMAGE_NAME 已存在，跳過建置"
    else
       _buildBase
    fi
}
_buildBase(){
    ionice -c 3 docker build -f $PHP_BASE_IMAGE_PATH -t $PHP_BASE_IMAGE_NAME .
}
_rebuildBase(){ 
    ionice -c 3 docker build --no-cache -f $PHP_BASE_IMAGE_PATH -t $PHP_BASE_IMAGE_NAME .
}
# end base
# start builder
_skipBuildBuilder(){
    if docker image inspect $PHP_BUILDER_IMAGE_NAME > /dev/null 2>&1; then
        echo "✅ $PHP_BUILDER_IMAGE_NAME 已存在，跳過建置"
    else
       _buildBuilder
    fi
}
_buildBuilder(){
    # 確保 \ 後面直接換行，沒有隱藏空格
    ionice -c 3 docker build --target main \
        -f "$PHP_BUILDER_IMAGE_PATH" \
        -t "$PHP_BUILDER_IMAGE_NAME" \
        --secret id=build_env,src=.env \
        .
}

_rebuildBuilder(){
    # 注意：--no-cache 應該放在 build 後面
    ionice -c 3 docker build --no-cache --target main \
        -f "$PHP_BUILDER_IMAGE_PATH" \
        -t "$PHP_BUILDER_IMAGE_NAME" \
        --secret id=build_env,src=.env \
        .
}
# end release
# start 各種主程序。
rebuildBase(){
    _rebuildBase
    _buildBuilder
}
rebuildVendor(){
    _skipBuildBase
    _rebuildBuilder
}

fastBuild(){
    _skipBuildBase
    _skipBuildBuilder
}
build(){
    _buildBase
    _buildBuilder
}
skipBaseBuild(){
    _skipBuildBase
    _buildBuilder
}
