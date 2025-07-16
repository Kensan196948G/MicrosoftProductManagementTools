# HTMLテンプレートエンジンテスト

Write-Host "🔍 HTMLテンプレートエンジンテストを開始します" -ForegroundColor Cyan

# モジュール読み込み
$modulePath = Join-Path $PSScriptRoot "..\Scripts\Common"
Import-Module "$modulePath\HTMLTemplateEngine.psm1" -Force -DisableNameChecking -Global

# テンプレートマッピングの確認
Write-Host "`n📋 テンプレートマッピングを確認中..." -ForegroundColor Yellow
$testReportTypes = @("DailyReport", "WeeklyReport", "Users", "LicenseAnalysis", "UnknownType")

foreach ($reportType in $testReportTypes) {
    Write-Host "  📊 $reportType : " -ForegroundColor White -NoNewline
    
    try {
        $template = Get-HTMLTemplate -ReportType $reportType
        if ($template) {
            Write-Host "✅ テンプレート取得成功" -ForegroundColor Green
        } else {
            Write-Host "❌ テンプレート取得失敗" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# サンプルデータでHTMLレポート生成テスト
Write-Host "`n📄 HTMLレポート生成テスト..." -ForegroundColor Yellow
$sampleData = @(
    [PSCustomObject]@{
        ServiceName = "Microsoft 365"
        ActiveUsersCount = 458
        TotalActivityCount = 1234
        Status = "正常"
    },
    [PSCustomObject]@{
        ServiceName = "Exchange Online"
        ActiveUsersCount = 445
        TotalActivityCount = 2345
        Status = "正常"
    },
    [PSCustomObject]@{
        ServiceName = "Microsoft Teams"
        ActiveUsersCount = 380
        TotalActivityCount = 3456
        Status = "正常"
    }
)

try {
    $htmlReport = Generate-EnhancedHTMLReport -Data $sampleData -ReportType "DailyReport" -Title "日次レポート"
    if ($htmlReport) {
        Write-Host "✅ HTMLレポート生成成功" -ForegroundColor Green
        Write-Host "   レポート文字数: $($htmlReport.Length) 文字" -ForegroundColor Gray
    } else {
        Write-Host "❌ HTMLレポート生成失敗" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ HTMLレポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🏁 HTMLテンプレートエンジンテスト完了" -ForegroundColor Cyan