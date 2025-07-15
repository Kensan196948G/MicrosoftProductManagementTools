# GUIテスト用スクリプト
# 現在のディレクトリから確実にrun_launcher.ps1を実行

$scriptPath = Join-Path $PSScriptRoot "run_launcher.ps1"

if (Test-Path $scriptPath) {
    Write-Host "run_launcher.ps1のパス: $scriptPath" -ForegroundColor Cyan
    Write-Host "PowerShell 7でSTAモードで起動します..." -ForegroundColor Green
    
    # PowerShell 7のSTAモードで起動
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        & pwsh -sta -NoProfile -File $scriptPath
    } else {
        Write-Host "PowerShell 7が見つかりません。Windows PowerShellで起動します..." -ForegroundColor Yellow
        & powershell -sta -NoProfile -File $scriptPath
    }
} else {
    Write-Host "エラー: run_launcher.ps1が見つかりません: $scriptPath" -ForegroundColor Red
}