{{- define "affinity.excludeControlPlane"}}
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: node-role.kubernetes.io/control-plane
        operator: DoesNotExist
{{- end -}}

{{- define "base.metadata.labels.managed_by" -}}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end -}}

{{- define "base.metadata.annotations.release" -}}
meta.helm.sh/release-name: {{ .Release.Name | quote }}
meta.helm.sh/release-namespace: {{ .Release.Namespace | quote }}
{{- end -}}

{{- define "base.metadata.annotations.keepOnDelete" -}}
helm.sh/resource-policy: keep
{{- end -}}

{{- define "db-backup.podTemplate" -}}
template:
  metadata:
    labels:
      io.kompose.network/forgejo-network: "true"
  spec:
    initContainers:
      - name: wait-for-db
        image: busybox:1.28
        command: ['sh', '-c', "until nc -zv forgejo-database 5432; do sleep 2; done;"]

    {{- if not .Values.singleNode }}
    affinity:
      {{- include "affinity.excludeControlPlane" . | nindent 6 }}
    {{- end }}

    containers:
      - name: backup
        image: postgres:17-alpine
        command: ["/scripts/entrypoint.sh"]
        env:
          - name: TZ
            value: Asia/Taipei
          - name: PROJECT_NAME
            value: forgejo
          - name: DB_BACKUP_PASSWORD
            valueFrom:
              secretKeyRef:
                name: forgejo-db-secret
                key: DB_BACKUP_PASSWORD
          - name: DB_BACKUP_USERNAME
            valueFrom:
              secretKeyRef:
                name: forgejo-db-secret
                key: DB_BACKUP_USERNAME
          - name: DB_DATABASE
            valueFrom:
              secretKeyRef:
                name: forgejo-db-secret
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
          claimName: forgejo-backup-claim
      - name: database-backup-shell
        configMap:
          name: forgejo-backup-shell
          defaultMode: 0555
    restartPolicy: OnFailure
{{- end -}}
