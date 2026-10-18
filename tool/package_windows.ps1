# 打包 Windows 本地測試部署版（Release → dist/zip）
# 用法：pwsh tool/package_windows.ps1 [-Version 0.2.0]
# 前置：專案須位於 ASCII 路徑（DBG-002：非 ASCII 路徑會使 MSBuild 失敗）；
#       或先於 ASCII clone 副本建置後，以本腳本打包該 Release 目錄。
param(
    [string]$Version = "0.2.0",
    [string]$SourceDir = "build/windows/x64/runner/Release"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

try {
    if (-not (Test-Path $SourceDir)) { throw "找不到 $SourceDir —— 請先 flutter build windows --release" }
    if (-not (Test-Path "dist")) { New-Item -ItemType Directory -Path "dist" | Out-Null }
    $zip = "dist/LedgerSync-v$Version-windows-x64-local-test.zip"
    if (Test-Path $zip) { Remove-Item $zip }
    Compress-Archive -Path "$SourceDir/*" -DestinationPath $zip
    "打包完成：$zip（{0:N1} MB）" -f ((Get-Item $zip).Length / 1MB)
}
finally {
    Pop-Location
}
