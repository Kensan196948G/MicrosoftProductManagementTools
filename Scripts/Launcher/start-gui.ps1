# GUI起動用簡易スクリプト
# STAモードで確実にGUIを起動します

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$guiAppPath = Join-Path $scriptRoot "Apps\GuiApp.ps1"

if (-not (Test-Path $guiAppPath)) {
    Write-Host "エラー: GuiApp.ps1が見つかりません: $guiAppPath" -ForegroundColor Red
    exit 1
}

Write-Host "Microsoft 365統合管理ツール GUIを起動します..." -ForegroundColor Green
Write-Host "パス: $guiAppPath" -ForegroundColor Cyan

# PowerShell 7が利用可能か確認
$ps7Path = Get-Command pwsh -ErrorAction SilentlyContinue
if ($ps7Path) {
    Write-Host "PowerShell 7を使用してSTAモードで起動します..." -ForegroundColor Green
    Start-Process pwsh -ArgumentList "-sta", "-NoProfile", "-File", "`"$guiAppPath`"" -NoNewWindow -Wait
} else {
    Write-Host "Windows PowerShellを使用してSTAモードで起動します..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-sta", "-NoProfile", "-File", "`"$guiAppPath`"" -NoNewWindow -Wait
}

Write-Host "GUIアプリケーションが終了しました。" -ForegroundColor Green