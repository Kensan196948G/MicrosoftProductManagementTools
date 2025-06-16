# 簡易日次レポートテストスクリプト
# Microsoft製品運用管理ツール

param(
    [string]$ReportType = "Daily"
)

Write-Host "=== 簡易日次レポートテスト ===" -ForegroundColor Green
Write-Host "レポート種別: $ReportType" -ForegroundColor Yellow
Write-Host "実行時刻: $(Get-Date)" -ForegroundColor Cyan

try {
    # モジュール読み込み
    Write-Host "必要なモジュールを読み込み中..." -ForegroundColor White
    Import-Module "$PSScriptRoot\Scripts\Common\Logging.psm1" -Force
    Import-Module "$PSScriptRoot\Scripts\Common\ErrorHandling.psm1" -Force  
    Import-Module "$PSScriptRoot\Scripts\Common\ReportGenerator.psm1" -Force
    
    Write-Host "レポート生成中..." -ForegroundColor White
    
    # 模擬データ作成（PSCustomObjectとして）
    $mockData = @(
        [PSCustomObject]@{ User = "user1@domain.com"; LoginTime = (Get-Date).AddHours(-2).ToString("yyyy/MM/dd HH:mm"); Result = "成功"; IPAddress = "192.168.1.100" }
        [PSCustomObject]@{ User = "user2@domain.com"; LoginTime = (Get-Date).AddHours(-1).ToString("yyyy/MM/dd HH:mm"); Result = "失敗"; IPAddress = "192.168.1.101" }
        [PSCustomObject]@{ User = "user3@domain.com"; LoginTime = (Get-Date).AddMinutes(-30).ToString("yyyy/MM/dd HH:mm"); Result = "成功"; IPAddress = "192.168.1.102" }
        [PSCustomObject]@{ User = "admin@domain.com"; LoginTime = (Get-Date).AddMinutes(-15).ToString("yyyy/MM/dd HH:mm"); Result = "失敗"; IPAddress = "192.168.1.103" }
    )
    
    # レポートセクション作成
    $reportSections = @(
        @{
            Title = "ログイン履歴サマリー"
            Summary = @(
                @{ Label = "総ログイン試行"; Value = $mockData.Count; Risk = "低" }
                @{ Label = "成功ログイン"; Value = ($mockData | Where-Object { $_.Result -eq "成功" }).Count; Risk = "低" }
                @{ Label = "失敗ログイン"; Value = ($mockData | Where-Object { $_.Result -eq "失敗" }).Count; Risk = "中" }
            )
            Data = $mockData
        }
    )
    
    # HTMLレポート生成
    $reportDir = New-ReportDirectory -ReportType $ReportType
    $reportPath = Join-Path $reportDir "TestDailyReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    
    New-HTMLReport -Title "${ReportType}運用レポート（テスト版）" -DataSections $reportSections -OutputPath $reportPath
    
    Write-Host "`n=== レポート生成完了 ===" -ForegroundColor Green
    Write-Host "出力先: $reportPath" -ForegroundColor Cyan
    
    # ファイル存在確認
    if (Test-Path $reportPath) {
        $fileSize = (Get-Item $reportPath).Length
        Write-Host "ファイルサイズ: $fileSize bytes" -ForegroundColor Green
        Write-Host "レポートが正常に生成されました！" -ForegroundColor Green
    }
    else {
        Write-Host "レポートファイルが見つかりません" -ForegroundColor Red
    }
    
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