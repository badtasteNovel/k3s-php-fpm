  # 當你裝 external 時，metadata.name = external-gateway-http-security-headers
  # 當你裝 internal 時，metadata.name = internal-gateway-http-security-headers
{{- define "common.gateway.http.headers.configmap" -}}
metadata:
  name: {{ .Release.Name }}-http-security-headers
  namespace: {{ .Release.Namespace }}
  labels:
    {{ include "common.gateway.metadata.labels.managed_by" . | nindent 4}}
  annotations:
    {{ include "common.gateway.metadata.annotations.release" . | nindent 4 }}
data:
  {{ include "common.gateway.content" . | nindent 2 }}
{{- end -}}
