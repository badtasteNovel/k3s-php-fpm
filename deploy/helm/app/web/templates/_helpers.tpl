
{{- define "affinity.excludeControlPlane"}}
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: node-role.kubernetes.io/control-plane # 這裡是node的標籤(包含 control-plane 化名 server 以及 node 化名 kubelet或agent)
        operator: DoesNotExist
{{- end -}}
{{- define "db-backup.podTemplate" -}}
template:
  metadata:
    labels:
      io.kompose.network/web-app-network: "true"
  spec:
    initContainers:
      - name: wait-for-db
        image: busybox:1.28
        # 1. Port 從 3306 改成 5432
        command: ['sh', '-c', "until nc -zv database 5432; do sleep 2; done;"]
    
    {{- if not .Values.singleNode }}
    affinity:
      {{- include "affinity.excludeControlPlane" . | nindent 6 }}
    {{- end }}

    containers:
      - name: backup
        # 2. 映像檔改成 postgres (推薦 alpine 版更輕量)
        image: postgres:17-alpine
        command: ["/scripts/entrypoint.sh"]

        env:
          - name: TZ
            value: Asia/Taipei
          - name: PROJECT_NAME
            valueFrom:
              secretKeyRef:
                name: app-env-secret
                key: PROJECT_NAME
                
          - name: DB_BACKUP_PASSWORD
            valueFrom:
              secretKeyRef:
                name: app-env-database-secret
                key: DB_BACKUP_PASSWORD 

          - name: DB_BACKUP_USERNAME
            valueFrom:
              secretKeyRef:
                name: app-env-database-secret
                key: DB_BACKUP_USERNAME 

          - name: DB_DATABASE
            valueFrom:
              secretKeyRef:
                name: app-env-database-secret
                key: POSTGRES_DB
        volumeMounts:
          - name: backup-storage
            mountPath: /backups
          - name: database-backup-shell
            mountPath: /scripts/entrypoint.sh
            subPath: database-backup.sh 

    volumes:
      - name: backup-storage
        persistentVolumeClaim:
          claimName: database-backup-claim
      - name: database-backup-shell
        configMap:
          name: database-backup-shell
          defaultMode: 0555
    restartPolicy: OnFailure

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
