# k3s / Helm / Task 部署資源

## 安裝 Task（啟動 Taskfile）

```bash
sh -c "$(curl -ssL https://taskfile.dev/install.sh)" -- -d -b /tmp && sudo mv /tmp/task /usr/local/bin/task && task --version
```

## 目錄結構

```
.
├── deploy/
│   ├── helm/         # Helm charts（app / infra / base）
│   ├── k8s/          # Kubernetes namespace manifests
│   ├── ops/          # ops shell pod
│   └── values/       # 各服務的 Helm values
│       ├── argocd/
│       ├── argocd-image-updater/
│       ├── forgejo/
│       ├── monitoring/
│       ├── smb/
│       └── temporal/
├── scripts/
│   ├── tasks/        # Taskfile includes
│   ├── bin/          # Shell scripts（install、deploy、secret、database 等）
│   └── lib/          # Shell library
├── environment/      # 環境變數範本（.example，不含機密）
│   ├── .env.example
│   ├── forgejo/
│   ├── portainer/
│   └── postgresql/
├── Taskfile.yaml
├── .env.task.example
└── .env.example
```

## 快速開始

1. 複製 `.env.task.example` → `.env.task`，填入對應的環境變數
2. 複製 `environment/` 底下各 `.example` 檔並填入機密
3. 執行 `task --list` 查看所有可用指令
