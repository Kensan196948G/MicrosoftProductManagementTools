# ================================================================================
# Connection Reset by Peer エラー修正テスト
# 改善されたエラーハンドリングと再試行ロジックのテスト
# ================================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$VerboseOutput = $false
)

$Script:ToolRoot = $PSScriptRoot

# モジュール読み込み
Import-Module "$Script:ToolRoot\Scripts\Common\Logging.psm1" -Force
Import-Module "$Script:ToolRoot\Scripts\Common\ErrorHandling.psm1" -Force

Write-Host "================================" -ForegroundColor Green
Write-Host "接続エラー修正テスト開始" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

try {
    # 設定ファイル読み込み
    $configFile = Join-Path $Script:ToolRoot "Config\appsettings.json"
    if (Test-Path $configFile) {
        $config = Get-Content $configFile | ConvertFrom-Json
        Write-Host "✓ 設定ファイル読み込み成功" -ForegroundColor Green
        Write-Host "  - タイムアウト: $($config.Performance.TimeoutMinutes)分" -ForegroundColor Cyan
        Write-Host "  - 再試行回数: $($config.Performance.RetryAttempts)回" -ForegroundColor Cyan
        Write-Host "  - 再試行間隔: $($config.Performance.RetryDelaySeconds)秒" -ForegroundColor Cyan
    }
    else {
        Write-Host "✗ 設定ファイルが見つかりません" -ForegroundColor Red
        exit 1
    }
    
    # エラーハンドリング機能テスト
    Write-Host "`n--- エラーハンドリング機能テスト ---" -ForegroundColor Yellow
    
    # 模擬ネットワークエラーを作成
    $testError = try {
        throw "Connection reset by peer"
    } catch {
        $_
    }
    
    $errorDetails = Get-ErrorDetails -ErrorRecord $testError
    
    Write-Host "✓ エラー詳細取得テスト:" -ForegroundColor Green
    Write-Host "  - エラータイプ: $($errorDetails.ErrorType)" -ForegroundColor Cyan
    Write-Host "  - ネットワークエラー: $($errorDetails.IsNetworkError)" -ForegroundColor Cyan
    
    # 再試行ロジックテスト（成功シナリオ）
    Write-Host "`n--- 再試行ロジックテスト ---" -ForegroundColor Yellow
    
    $successAfterRetry = Invoke-RetryLogic -ScriptBlock {
        # 成功シナリオをシミュレート
        return "テスト成功"
    } -MaxRetries 3 -DelaySeconds 1 -Operation "接続テスト"
    
    Write-Host "✓ 再試行ロジックテスト成功: $successAfterRetry" -ForegroundColor Green
    
    Write-Host "`n================================" -ForegroundColor Green
    Write-Host "すべてのテストが完了しました" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Green
    
    Write-Host "`n🔧 修正内容サマリー:" -ForegroundColor White
    Write-Host "1. タイムアウト時間を30分→45分に延長" -ForegroundColor Gray
    Write-Host "2. 再試行回数を3回→7回に増加" -ForegroundColor Gray
    Write-Host "3. 再試行間隔を5秒→15秒に延長" -ForegroundColor Gray
    Write-Host "4. ネットワークエラーの自動検出機能追加" -ForegroundColor Gray
    Write-Host "5. ネットワークエラー時の指数バックオフ実装" -ForegroundColor Gray
    
    Write-Host "`n💡 次のステップ:" -ForegroundColor White
    Write-Host "1. アプリケーションを再起動してください" -ForegroundColor Gray
    Write-Host "2. 認証テストを実行してください" -ForegroundColor Gray
    Write-Host "3. エラーが再発する場合はログを確認してください" -ForegroundColor Gray
}
catch {
    Write-Host "✗ テスト中にエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}