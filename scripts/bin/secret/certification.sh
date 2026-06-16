#!/bin/bash
webCert() {
  local servers
  local mainCn
  mkdir -p /certs
  mainCn="lg-laravel.local"
  servers="DNS:lg-laravel.local,DNS:sql.local,DNS:sureway.local,DNS:portainer.local,DNS:grafana.local,DNS:temporal.local,DNS:forgejo.local,DNS:argo.local"
  openssl req -x509 -newkey rsa:4096 \
      -keyout "./certs/key.pem" \
      -out "./certs/cert.pem" \
      -sha256 \
      -days 365 \
      -nodes \
      -subj "/CN=$mainCn" \
      -addext "subjectAltName = $servers"
  chmod 600 "./certs/key.pem" "./certs/cert.pem"
}
printerCert() {
  sudo mkdir -p /storage/app/qztray-public
  sudo mkdir -p /storage/app/qztray-private
  printf '*\n!.gitignore\n' | tee storage/app/qztray-public/.gitignore storage/app/qztray-private/.gitignore
  openssl req -x509 -newkey rsa:2048 -keyout ./storage/app/qztray-private/key.pem -out ./storage/app/qztray-public/cert.pem -days 3650 -nodes \
  -subj "/C=TW/ST=Taiwan/L=Taichung/O=Sureway/OU=IT/CN=sureway.local"
}

help() {
  echo "建立憑證腳本"
  echo "Usage: $0 <command>"
  echo "Commands:"
  echo "  webCert    - 建立ssl憑證"
  echo "  printerCert - 建立印表機憑證"
}
main() {
  local command="${1:-}"
  shift || true

  case "$command" in
    webCert)     webCert "$@" ;;
    printerCert) printerCert "$@" ;;
    *)         help; exit 1 ;;
  esac
}

main "$@"