{{- $protocol := ternary "https" "http" .Values.forgejo.ssl -}}
{{- $repoURL := printf "%s://%s:%v/%s/%s.git" $protocol .Values.forgejo.host .Values.forgejo.port .Values.forgejo.org .Values.forgejo.repo -}}
{{- $hook := "post-install,post-upgrade" -}}

# ── web ───────────────────────────────────────────────────────────────────────
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web-database
  namespace: argocd
  annotations:
    "helm.sh/hook": {{ $hook }}
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  project: default
  source:
    repoURL: {{ $repoURL }}
    targetRevision: HEAD
    path: deploy/helm/app/web-database
    helm:
      valueFiles:
        - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: web
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: redis
  namespace: argocd
  annotations:
    "helm.sh/hook": {{ $hook }}
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  project: default
  source:
    repoURL: {{ $repoURL }}
    targetRevision: HEAD
    path: deploy/helm/app/redis
    helm:
      valueFiles:
        - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: web
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web
  namespace: argocd
  labels:
    type: git-ops
  annotations:
    "helm.sh/hook": {{ $hook }}
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  project: default
  source:
    repoURL: {{ $repoURL }}
    targetRevision: HEAD
    path: deploy/helm/app/web
    helm:
      valueFiles:
        - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: web
  syncPolicy:
    automated:
      prune: false
      selfHeal: false

# ── service ───────────────────────────────────────────────────────────────────
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: workflow-database
  namespace: argocd
  annotations:
    "helm.sh/hook": {{ $hook }}
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  project: default
  source:
    repoURL: {{ $repoURL }}
    targetRevision: HEAD
    path: deploy/helm/app/workflow-database
    helm:
      valueFiles:
        - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: service
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: service
  namespace: argocd
  labels:
    type: git-ops
  annotations:
    "helm.sh/hook": {{ $hook }}
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  project: default
  source:
    repoURL: {{ $repoURL }}
    targetRevision: HEAD
    path: deploy/helm/app/services
    helm:
      valueFiles:
        - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: service
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
