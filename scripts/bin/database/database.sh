
source environment/shell/sh.env
source $BIN/debug.sh

databaseInit(){
    choosePod
    removePodContext
    kubectl exec -it $POD -n $NS -c $CONTAINER -- bash -c "bash /docker-entrypoint-initdb.d/setup.sh"
}

main() {
    local command="${1:-}"
    shift || true

    case "$command" in
        databaseInit)         databaseInit "$@" ;;
        *) help "$@" ;;
    esac
}
