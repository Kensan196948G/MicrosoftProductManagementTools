# GUI起動テスト用スクリプト
Write-Host "GUI起動テスト開始" -ForegroundColor Yellow

try {
    # GUIアプリケーションのパス確認
    $guiPath = "Apps\GuiApp.ps1"
    Write-Host "パス確認: $guiPath" -ForegroundColor Cyan
    Write-Host "ファイル存在: $(Test-Path $guiPath)" -ForegroundColor Cyan
    
    # プロセス起動
    Write-Host "プロセス起動中..." -ForegroundColor Cyan
    $process = Start-Process pwsh -ArgumentList "-sta", "-NoProfile", "-File", $guiPath -PassThru -WindowStyle Normal
    
    Write-Host "プロセスID: $($process.Id)" -ForegroundColor Green
    Write-Host "プロセス名: $($process.ProcessName)" -ForegroundColor Green
    
    # 少し待機
    Start-Sleep -Seconds 3
    
    # プロセス状態確認
    Write-Host "プロセス状態確認中..." -ForegroundColor Cyan
    $hasExited = $process.HasExited
    
    if ($hasExited -eq $false) {
        Write-Host "GUIプロセスが実行中です" -ForegroundColor Green
    } else {
        Write-Host "GUIプロセスが終了しました" -ForegroundColor Red
        Write-Host "終了コード: $($process.ExitCode)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "エラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "スタックトレース: $($_.ScriptStackTrace)" -ForegroundColor Red
}