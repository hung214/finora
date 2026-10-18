# 同步 BDD feature 檔：specs/plan/tests → test/bdd（BE）與 integration_test/features（FE）
# 規範：specs/plan/tasks.md §0.2 —— 副本禁止手改，一律以本腳本重新同步
# 用法：pwsh tool/sync_features.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

try {
    foreach ($dir in @("test/bdd", "integration_test/features")) {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }
    Copy-Item "specs/plan/tests/backend/*.feature" "test/bdd/" -Force
    Copy-Item "specs/plan/tests/frontend/*.feature" "integration_test/features/" -Force
    Write-Host "已同步：BE feature -> test/bdd（$(@(Get-ChildItem 'test/bdd' -Filter *.feature).Count) 檔）；FE feature -> integration_test/features（$(@(Get-ChildItem 'integration_test/features' -Filter *.feature).Count) 檔）"
}
finally {
    Pop-Location
}
