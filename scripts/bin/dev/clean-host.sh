#!/bin/bash
source environment/shell/sh.env
PS_EXE='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
# 取得 distro 名稱
DISTRO_NAME=$(wsl.exe -l --quiet 2>/dev/null | head -1 | tr -d '\r\0 ')
echo ""
echo "════════════════════════════════════════════════════════"
echo " WSL Disk Compactor - 開始執行"
echo " Distro: $DISTRO_NAME"
echo "════════════════════════════════════════════════════════"

echo ""
echo "--- [1/2] Linux 內部垃圾清理 ---"

echo "  ▸ 清理 apt 快取..."
sudo apt-get clean -y 2>/dev/null
sudo apt-get autoremove -y 2>/dev/null

echo "  ▸ 壓縮 systemd journal..."
sudo journalctl --vacuum-size=50M 2>/dev/null

echo "  ▸ 清理 /tmp..."
sudo rm -rf /tmp/* 2>/dev/null

if command -v docker &>/dev/null; then
    echo "  ▸ 清理 Docker 未使用資源..."

    # 建立 grep 排除條件，例如 KEEP_IMAGES=("nginx:latest" "my-app:v1")
    if [ ${#KEEP_IMAGES[@]} -gt 0 ]; then
        EXCLUDE_PATTERN=$(printf "%s\n" "${KEEP_IMAGES[@]}" | paste -sd'|')
        echo "  ▸ 保留映像檔：${KEEP_IMAGES[*]}"
        docker images --format "{{.ID}} {{.Repository}}:{{.Tag}}" |
            grep -Ev "$EXCLUDE_PATTERN" |
            awk '{print $1}' |
            xargs -r docker rmi -f 2>/dev/null
    else
        docker rmi -f $(docker images -q) 2>/dev/null
    fi

    docker system prune -af --volumes 2>/dev/null
fi

if command -v k3s &>/dev/null; then
    echo "  ▸ 停止 k3s service..."
    sudo systemctl stop k3s
    echo "  ▸ 清除 k3s containerd 快取（images + snapshots）..."
    sudo rm -rf /var/lib/rancher/k3s/agent/containerd
    echo "  ▸ 重啟 k3s service..."
    sudo systemctl start k3s
    echo "  ▸ k3s 清理完成（請記得跑 task deploy-dev 重新部署）"
fi

echo ""
echo "--- [2/2] 執行 fstrim ---"
sudo fstrim -av

echo ""
echo "--- 啟動 Windows 端壓縮視窗 ---"

read -r -d '' PS_CONTENT <<EOF
Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host " WSL Disk Compactor" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor DarkCyan

\$distro = "$DISTRO_NAME"
\$vhdxPath = (Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss" -ErrorAction SilentlyContinue | ForEach-Object {
    \$base = (Get-ItemProperty \$_.PSPath -ErrorAction SilentlyContinue).BasePath
    if (\$base) { Join-Path \$base "ext4.vhdx" }
} | Where-Object { \$_ -and (Test-Path \$_) } | Sort-Object { (Get-Item \$_).Length } -Descending | Select-Object -First 1)

if (-not \$vhdxPath) {
    Write-Host "❌ 找不到 ext4.vhdx，請確認 WSL Distro 已正確安裝。" -ForegroundColor Red
    Read-Host "按 Enter 關閉此視窗..."
    exit 1
}

\$sizeBefore = [Math]::Round((Get-Item \$vhdxPath).Length / 1GB, 2)
Write-Host "Distro   : \$distro" -ForegroundColor White
Write-Host "VHDX     : \$vhdxPath" -ForegroundColor White
Write-Host "壓縮前大小: \$sizeBefore GB" -ForegroundColor White
Write-Host ""

Write-Host "[1/3] 關閉 WSL..." -ForegroundColor Yellow
wsl --shutdown
Start-Sleep -Seconds 3
Write-Host "  ✔ 完成" -ForegroundColor Green

Write-Host ""
Write-Host "[2/3] 確保 VHDX 為稀疏格式..." -ForegroundColor Yellow
wsl --manage \$distro --set-sparse true 2>&1 | Out-Null
Write-Host "  ✔ 完成" -ForegroundColor Green

Write-Host ""
Write-Host "[3/3] 使用 diskpart 壓縮 VHDX（這可能需要幾分鐘）..." -ForegroundColor Yellow
\$diskpartScript = @"
select vdisk file="\$vhdxPath"
attach vdisk readonly
compact vdisk
detach vdisk
exit
"@
\$tmpFile = [System.IO.Path]::GetTempFileName() + ".txt"
\$diskpartScript | Set-Content -Path \$tmpFile -Encoding ASCII
diskpart /s \$tmpFile | Out-Null
Remove-Item \$tmpFile -ErrorAction SilentlyContinue
Write-Host "  ✔ 完成" -ForegroundColor Green

Write-Host ""
\$sizeAfter = [Math]::Round((Get-Item \$vhdxPath).Length / 1GB, 2)
\$saved = [Math]::Round(\$sizeBefore - \$sizeAfter, 2)

Write-Host "────────────────────────────────" -ForegroundColor DarkCyan
Write-Host " 壓縮前：\$sizeBefore GB" -ForegroundColor White
Write-Host " 壓縮後：\$sizeAfter GB" -ForegroundColor White
if (\$saved -gt 0) {
    Write-Host " 釋放了：\$saved GB" -ForegroundColor Green
} else {
    Write-Host " 無變化（Linux 層無可回收空間）" -ForegroundColor Yellow
}
Write-Host "────────────────────────────────" -ForegroundColor DarkCyan
Write-Host ""
Read-Host "按 Enter 關閉此視窗..."
EOF

B64_COMMAND=$(echo -n "$PS_CONTENT" | iconv -t UTF-16LE | base64 -w 0)

"$PS_EXE" -NoProfile -Command \
    "Start-Process powershell.exe -ArgumentList '-NoExit', '-NoProfile', '-EncodedCommand', '$B64_COMMAND' -Verb RunAs -WindowStyle Normal"

echo "--- [完成] 管理員視窗已啟動 ---"

