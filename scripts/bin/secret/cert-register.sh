#!/bin/bash

IP=""
DNS=""
SECRET_NAME=""
NAMESPACE="default"  # 預設值

for arg in "$@"; do
  case $arg in
    --ip=*) IP="${arg#*=}" ;;
    --dns=*) DNS="${arg#*=}" ;;
    --secret-name=*) SECRET_NAME="${arg#*=}" ;;
    --namespace=*) NAMESPACE="${arg#*=}" ;;
  esac
done

if [ -z "$IP" ]; then
  echo "請提供 IP 位址，例如：$0 --ip=192.168.0.241"
  exit 1
fi

if [ -z "$DNS" ]; then
  echo "請提供 DNS，例如：$0 --dns=registry.local"
  exit 1
fi

if [ -z "$SECRET_NAME" ]; then
  echo "請提供 Secret 名稱，例如：$0 --secret-name=local-registry-tls-secret"
  exit 1
fi

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
spec:
  secretName: ${SECRET_NAME}
  issuerRef:
    name: local-ca-issuer
    kind: ClusterIssuer
  ipAddresses:
    - ${IP}
  dnsNames:
    - ${DNS}
EOF