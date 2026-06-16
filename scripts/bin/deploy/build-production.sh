#!/bin/bash


# 2. 載入 Lib
source "$(dirname "$0")/lib/build.sh"
source "$(dirname "$0")/lib/build-main.sh"
main() {
    local command="${1:-}"
    shift || true

    case "$command" in
        rebuildBase) rebuildBase "$@" ;;
        rebuildVendor)        rebuildVendor "$@" ;;
        fastBuild)   fastBuild "$@" ;;
        build)                build "$@" ;;
        skipBaseBuild)        skipBaseBuild "$@" ;;
    esac
    _buildPhp
    _buildNginxNoCache
    _buildOpsToolbox
    _buildOpsPHP
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi