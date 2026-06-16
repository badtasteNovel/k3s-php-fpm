{{- define "common.gateway.content" -}}
X-Frame-Options: "SAMEORIGIN"
X-XSS-Protection: "1; mode=block"
X-Content-Type-Options: "nosniff"
Referrer-Policy: "strict-origin-when-cross-origin"
{{- end -}}


{{- define "common.gateway.metadata.labels.managed_by" -}}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end -}}

{{- define "common.gateway.metadata.annotations.release" -}}
meta.helm.sh/release-name: {{ .Release.Name | quote }}
meta.helm.sh/release-namespace: {{ .Release.Namespace | quote }}
{{- end -}}
