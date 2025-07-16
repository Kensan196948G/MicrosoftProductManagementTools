# 取得件数修正テスト

Write-Host "🔍 取得件数修正テストを開始します" -ForegroundColor Cyan

# モジュール読み込み
$modulePath = Join-Path $PSScriptRoot "..\Scripts\Common"
Import-Module "$modulePath\RealM365DataProvider.psm1" -Force -DisableNameChecking -Global
Import-Module "$modulePath\DataSourceVisualization.psm1" -Force -DisableNameChecking -Global

# 既存の接続状況確認
$graphContext = Get-MgContext -ErrorAction SilentlyContinue
if ($graphContext) {
    Write-Host "✅ 既存のMicrosoft Graph接続を使用します" -ForegroundColor Green
    Write-Host "   テナント: $($graphContext.TenantId)" -ForegroundColor Gray
} else {
    Write-Host "🔐 Microsoft 365に接続中..." -ForegroundColor Yellow
    $connectionResult = Connect-M365Services
    if (-not $connectionResult.GraphConnected) {
        Write-Host "❌ 接続に失敗しました" -ForegroundColor Red
        exit 1
    }
}

# 実際のユーザー数を取得
Write-Host "`n👥 実際のユーザー数を取得中..." -ForegroundColor Cyan
try {
    $totalUsers = (Get-MgUser -All -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "✅ 総ユーザー数: $totalUsers ユーザー" -ForegroundColor Green
} catch {
    Write-Host "❌ ユーザー数取得エラー: $($_.Exception.Message)" -ForegroundColor Red
    $totalUsers = 0
}

# 日次レポート取得テスト（修正後）
Write-Host "`n📅 日次レポート取得テスト（修正後）..." -ForegroundColor Cyan
try {
    $dailyReport = Get-M365DailyReport
    if ($dailyReport.Count -gt 0) {
        Write-Host "✅ 日次レポート取得成功" -ForegroundColor Green
        Write-Host "   レポート項目数: $($dailyReport.Count)" -ForegroundColor White
        Write-Host "   最初の項目: $($dailyReport[0].ServiceName)" -ForegroundColor White
        Write-Host "   アクティブユーザー数: $($dailyReport[0].ActiveUsersCount)" -ForegroundColor White
        
        # 実際のユーザー数と比較
        if ($totalUsers -gt 0) {
            Write-Host "   実際のユーザー数: $totalUsers" -ForegroundColor White
            Write-Host "   表示された取得件数が$totalUsersと一致しているか確認してください" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ 日次レポートが空です" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ 日次レポート取得エラー: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🏁 取得件数修正テスト完了" -ForegroundColor Cyan
Write-Host "上記の出力で「取得件数: $totalUsers 件」と表示されていれば修正成功です" -ForegroundColor Green