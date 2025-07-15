# シンプルなGUI起動スクリプト（コンソールハンドル問題を回避）
param()

Write-Host "=== Microsoft 365統合管理ツール - GUI起動 ===" -ForegroundColor Cyan
Write-Host ""

try {
    # GUIアプリケーションのパス
    $guiPath = Join-Path $PSScriptRoot "Apps\GuiApp.ps1"
    
    # パス存在確認
    if (-not (Test-Path $guiPath)) {
        Write-Host "❌ GUIアプリケーションが見つかりません: $guiPath" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "🚀 GUIアプリケーションを起動中..." -ForegroundColor Green
    Write-Host "📁 パス: $guiPath" -ForegroundColor Gray
    
    # 新しいプロセスでGUIを起動
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        $process = Start-Process pwsh -ArgumentList "-sta", "-NoProfile", "-File", "`"$guiPath`"" -PassThru -WindowStyle Normal
    } else {
        $process = Start-Process powershell -ArgumentList "-sta", "-NoProfile", "-File", "`"$guiPath`"" -PassThru -WindowStyle Normal
    }
    
    Write-Host "✅ GUIプロセスが起動しました" -ForegroundColor Green
    Write-Host "🔢 プロセスID: $($process.Id)" -ForegroundColor Gray
    Write-Host "💻 プロセス名: $($process.ProcessName)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📝 GUIアプリケーションが別ウィンドウで実行中です" -ForegroundColor Cyan
    Write-Host "🔄 このコンソールはそのまま使用できます" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ エラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "📄 詳細: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")