{{- define "base.metadata.labels.managed_by" -}}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end -}}

{{- define "base.metadata.annotations.release" -}}
meta.helm.sh/release-name: {{ .Release.Name | quote }}
meta.helm.sh/release-namespace: {{ .Release.Namespace | quote }}
{{- end -}}

{{/* 用途：防止 Helm 在 uninstall 時刪除特定資源*/}}
{{- define "base.metadata.annotations.keepOnDelete" -}}
helm.sh/resource-policy: keep
{{- end -}}