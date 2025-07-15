# ================================================================================
# 🚀 Microsoft 365統合管理ツール - シンプルランチャー
# run_launcher_simple.ps1
# STAモードで確実に起動するランチャー
# ================================================================================

# 現在のスレッドがSTAモードかチェック
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "🔄 STAモードでPowerShellを再起動します..." -ForegroundColor Cyan
    
    # 現在のスクリプトのパスを取得
    $scriptPath = $MyInvocation.MyCommand.Path
    
    # PowerShell 7を探す
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        Write-Host "✅ PowerShell 7で起動します" -ForegroundColor Green
        # すべての引数を渡してSTAモードで再起動
        $arguments = @("-sta", "-NoProfile", "-File", "`"$scriptPath`"") + $args
        Start-Process pwsh -ArgumentList $arguments -NoNewWindow -Wait
    } else {
        Write-Host "⚠️ PowerShell 7が見つかりません。Windows PowerShellで起動します" -ForegroundColor Yellow
        # Windows PowerShellで実行
        $arguments = @("-sta", "-NoProfile", "-File", "`"$scriptPath`"") + $args
        Start-Process powershell -ArgumentList $arguments -NoNewWindow -Wait
    }
    
    exit
}

Write-Host "✅ STAモードで実行中です" -ForegroundColor Green
Write-Host ""

# メインのrun_launcher.ps1を実行
$mainLauncherPath = Join-Path $PSScriptRoot "run_launcher.ps1"

if (Test-Path $mainLauncherPath) {
    Write-Host "🚀 Microsoft 365統合管理ツールを起動します..." -ForegroundColor Cyan
    Write-Host "実行ファイル: $mainLauncherPath" -ForegroundColor Gray
    Write-Host ""
    
    # 同じプロセス内で実行
    & $mainLauncherPath @args
} else {
    Write-Host "❌ エラー: run_launcher.ps1が見つかりません" -ForegroundColor Red
    Write-Host "期待されるパス: $mainLauncherPath" -ForegroundColor Yellow
    exit 1
}