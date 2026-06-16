
{{- define "affinity.excludeControlPlane"}}
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: node-role.kubernetes.io/control-plane # 這裡是node的標籤(包含 control-plane 化名 server 以及 node 化名 kubelet或agent)
        operator: DoesNotExist
{{- end -}}

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
