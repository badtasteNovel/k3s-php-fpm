#!/bin/bash
PS_EXE='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'

read -r -d '' PS_CONTENT << 'EOF'
$distro = "Ubuntu"
$backupDir = "D:\wsl_backup"
$backupFile = "$backupDir\wsl_backup_$(Get-Date -Format 'yyyyMMdd').tar"

if (-not (Test-Path $backupDir)) {
    New-Item -Path $backupDir -ItemType Directory | Out-Null
}

Write-Host "========== WSL 通用備份程序 (修正版) ==========" -ForegroundColor Magenta
Write-Host "策略: 使用 --exclude 排除所有潛在問題路徑。" -ForegroundColor Gray
Write-Host "目的地: $backupFile" -ForegroundColor Yellow

# 檢查 D 槽空間
$drive = Get-PSDrive D -ErrorAction SilentlyContinue
if ($drive) {
    $freeGB = [Math]::Round($drive.Free / 1GB, 2)
    Write-Host "D 槽可用空間: $freeGB GB"
    if ($freeGB -lt 60) {
        Write-Error "錯誤：D 槽空間不足 60GB。"
        Read-Host "按任意鍵退出..."
        exit
    }
}

Write-Host "`n[正在執行] 正在打包實際資料 (這會需要一點時間)..." -ForegroundColor Cyan

# --- 關鍵修正：使用通用排除語法 ---
# 1. 排除掛載點 (/mnt)，避免備份到 Windows 自己的硬碟
# 2. 排除系統動態目錄 (/proc, /sys, /dev, /run)
# 3. 排除容易出問題的 kubelet 與 docker socket 目錄
# 4. 使用 --ignore-failed-read 避免因為少數檔案權限問題而中斷整個備份
wsl -d $distro -u root -- bash -c "tar --ignore-failed-read --exclude='/mnt/*' --exclude='/proc/*' --exclude='/sys/*' --exclude='/dev/*' --exclude='/run/*' --exclude='*.sock' -cvf - /" > $backupFile

if ((Test-Path $backupFile) -and ((Get-Item $backupFile).Length -gt 1MB)) {
    $finalSize = [Math]::Round((Get-Item $backupFile).Length / 1GB, 2)
    Write-Host "`n[成功] 備份完成！" -ForegroundColor Green
    Write-Host "最終檔案大小: $finalSize GB" -ForegroundColor White
} else {
    Write-Host "`n[失敗] 備份檔案大小異常 (0 GB)，請檢查 WSL 內部權限。" -ForegroundColor Red
}
Read-Host "`n請按任意鍵關閉視窗..."
EOF

B64_COMMAND=$(echo -n "$PS_CONTENT" | iconv -t UTF-16LE | base64 -w 0)
$PS_EXE -Command "Start-Process powershell -ArgumentList '-NoProfile', '-EncodedCommand', '$B64_COMMAND' -Verb RunAs"