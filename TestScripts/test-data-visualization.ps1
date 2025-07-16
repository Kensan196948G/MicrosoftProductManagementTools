# データソース可視化機能の完全テスト

Write-Host "🔍 データソース可視化機能 完全テスト" -ForegroundColor Cyan
Write-Host "="*80 -ForegroundColor Cyan

# モジュール読み込み
$modulePath = Join-Path $PSScriptRoot "..\Scripts\Common"
Import-Module "$modulePath\RealM365DataProvider.psm1" -Force -DisableNameChecking -Global
Import-Module "$modulePath\HTMLTemplateEngine.psm1" -Force -DisableNameChecking -Global
Import-Module "$modulePath\DataSourceVisualization.psm1" -Force -DisableNameChecking -Global

# 接続状況の表示
Show-ConnectionStatus

# グローバル関数定義
. {
    function global:Get-ReportDataFromProvider {
        param(
            [string]$DataType,
            [hashtable]$Parameters = @{}
        )
        
        try {
            switch ($DataType) {
                "DailyReport" { return Get-M365DailyReport @Parameters }
                "Users" { return Get-M365AllUsers @Parameters }
                "SignInLogs" { return Get-M365SignInLogs @Parameters }
                default { 
                    return @([PSCustomObject]@{ Message = "テストデータ" })
                }
            }
        }
        catch {
            Show-DataSourceStatus -DataType $DataType -Status "Error" -Details @{
                "ErrorMessage" = $_.Exception.Message
            }
            return @([PSCustomObject]@{ 
                Error = $_.Exception.Message
                DataType = $DataType
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            })
        }
    }
}

Write-Host "`n🧪 各データ種別のテスト実行" -ForegroundColor Yellow
Write-Host "="*80 -ForegroundColor Yellow

# 1. 日次レポートテスト
Write-Host "`n📅 1. 日次レポートデータ取得テスト" -ForegroundColor Cyan
$dailyData = Get-ReportDataFromProvider -DataType "DailyReport"

# 2. ユーザーデータテスト
Write-Host "`n👥 2. ユーザーデータ取得テスト" -ForegroundColor Cyan
$userData = Get-ReportDataFromProvider -DataType "Users"

# 3. サインインログテスト
Write-Host "`n🔐 3. サインインログ取得テスト" -ForegroundColor Cyan
$signInData = Get-ReportDataFromProvider -DataType "SignInLogs"

Write-Host "`n🎯 テスト結果サマリー" -ForegroundColor Green
Write-Host "="*80 -ForegroundColor Green
Write-Host "✅ 日次レポート: $($dailyData.Count) 件" -ForegroundColor White
Write-Host "✅ ユーザーデータ: $($userData.Count) 件" -ForegroundColor White
Write-Host "✅ サインインログ: $($signInData.Count) 件" -ForegroundColor White

Write-Host "`n🔍 データ品質評価結果:" -ForegroundColor Yellow
@("DailyReport", "Users", "SignInLogs") | ForEach-Object {
    $dataType = $_
    $data = switch ($dataType) {
        "DailyReport" { $dailyData }
        "Users" { $userData }
        "SignInLogs" { $signInData }
    }
    
    if ($data.Count -gt 0) {
        $quality = Test-RealDataQuality -Data $data -DataType $dataType
        $status = if ($quality.IsRealData) { "✅ 実データ" } else { "⚠️ 推定/フォールバック" }
        Write-Host "   $dataType : $status (信頼度: $($quality.Confidence)%)" -ForegroundColor $(if ($quality.IsRealData) { 'Green' } else { 'Yellow' })
    }
}

Write-Host "`n🏁 データソース可視化機能テスト完了" -ForegroundColor Cyan
Write-Host "="*80 -ForegroundColor Cyan