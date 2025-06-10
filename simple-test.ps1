# シンプルテストスクリプト
# Microsoft製品運用管理ツール - 基本動作確認

param(
    [string]$TestType = "Basic"
)

Write-Host "=== Microsoft製品運用管理ツール - シンプルテスト ===" -ForegroundColor Green
Write-Host "テスト種別: $TestType" -ForegroundColor Yellow
Write-Host "実行時刻: $(Get-Date)" -ForegroundColor Cyan

try {
    # Commonモジュールインポート
    Write-Host "Commonモジュールを読み込み中..." -ForegroundColor White
    Import-Module "$PSScriptRoot\Scripts\Common\Common.psm1" -Force
    
    # 初期化実行
    Write-Host "管理ツールを初期化中..." -ForegroundColor White
    $config = Initialize-ManagementTools
    
    Write-Host "初期化完了！" -ForegroundColor Green
    Write-Host "設定情報:" -ForegroundColor Yellow
    
    # 基本設定情報表示
    Write-Host "  組織名: $($config.General.OrganizationName)" -ForegroundColor White
    Write-Host "  環境: $($config.General.Environment)" -ForegroundColor White
    Write-Host "  言語コード: $($config.General.LanguageCode)" -ForegroundColor White
    
    # システム情報取得
    Write-Host "`nシステム情報:" -ForegroundColor Yellow
    $sysInfo = Get-SystemInfo
    Write-Host "  PowerShell: $($sysInfo.PowerShellVersion)" -ForegroundColor White
    Write-Host "  OS: $($sysInfo.OSVersion)" -ForegroundColor White
    Write-Host "  マシン名: $($sysInfo.MachineName)" -ForegroundColor White
    Write-Host "  ユーザー: $($sysInfo.UserName)" -ForegroundColor White
    
    Write-Host "`n=== テスト正常完了 ===" -ForegroundColor Green
    
    return $true
}
catch {
    Write-Host "`n=== テスト失敗 ===" -ForegroundColor Red
    Write-Host "エラー: $($_.Exception.Message)" -ForegroundColor Red
    return $false
}
finally {
    Write-Host "実行終了時刻: $(Get-Date)" -ForegroundColor Cyan
}