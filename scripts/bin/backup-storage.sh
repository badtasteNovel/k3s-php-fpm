#!/bin/bash
backupStorageInstall(){

}
backupStorageRelease(){
    kubectl patch pv nas-backup-pv -p '{"spec":{"claimRef":null}}'
}
backupStorageUninstall(){

}
main() {
  local command="${1:-}"
  shift || true

  case "$command" in
    backupStorageInstall)     backupStorageInstall "$@" ;;
    podStatus) podStatus "$@" ;;
    *) help "$@" ;;
  esac
}

main "$@"