#!/bin/bash
PS_EXE='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'

read -r -d '' PS_CONTENT << 'EOF'
Write-Host "--- 從登錄檔偵測 WSL 硬碟路徑 ---" -ForegroundColor Cyan

# 直接從 Registry 抓取所有已註冊的 WSL 實體路徑
$RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
Get-ChildItem -Path $RegistryPath | ForEach-Object {
    $basePath = Get-ItemProperty -Path $_.PSPath | Select-Object -ExpandProperty BasePath
    $distroName = Get-ItemProperty -Path $_.PSPath | Select-Object -ExpandProperty DistributionName
    
    $vhdxPath = Join-Path $basePath "ext4.vhdx"
    
    if (Test-Path $vhdxPath) {
        $file = Get-Item $vhdxPath
        [PSCustomObject]@{
            Distro = $distroName
            Size_GB = [Math]::Round($file.Length / 1GB, 2)
            Path = $vhdxPath
        }
    }
} | Format-Table -AutoSize

# 檢查 Docker
$dockerPath = "$env:LOCALAPPDATA\Docker\wsl\data\ext4.vhdx"
if (Test-Path $dockerPath) {
    $size = [Math]::Round((Get-Item $dockerPath).Length / 1GB, 2)
    Write-Host "--- Docker Desktop 資料碟 ---" -ForegroundColor Yellow
    Write-Host "實體佔用: $size GB | 路徑: $dockerPath"
}
EOF

B64_COMMAND=$(echo -n "$PS_CONTENT" | iconv -t UTF-16LE | base64 -w 0)
$PS_EXE -NoProfile -EncodedCommand "$B64_COMMAND"