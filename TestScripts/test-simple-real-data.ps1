# シンプルな実データ取得テスト

Write-Host "🔍 シンプルな実データ取得テスト開始" -ForegroundColor Cyan

# モジュール読み込み
$modulePath = Join-Path $PSScriptRoot "..\Scripts\Common"
Import-Module "$modulePath\RealM365DataProvider.psm1" -Force -DisableNameChecking -Global
Import-Module "$modulePath\DataSourceVisualization.psm1" -Force -DisableNameChecking -Global

# 既存の接続を確認
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

# 簡単なユーザー数取得テスト
Write-Host "`n📊 ユーザー数取得テスト..." -ForegroundColor Cyan
try {
    $userCount = (Get-MgUser -Top 100 -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "✅ 取得成功: $userCount ユーザー" -ForegroundColor Green
} catch {
    Write-Host "❌ ユーザー数取得エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 基本的なユーザー情報テスト
Write-Host "`n👥 基本ユーザー情報テスト..." -ForegroundColor Cyan
try {
    $users = Get-MgUser -Top 5 -Select "DisplayName,UserPrincipalName,AccountEnabled" -ErrorAction SilentlyContinue
    Write-Host "✅ 取得成功: $($users.Count) ユーザー" -ForegroundColor Green
    foreach ($user in $users) {
        Write-Host "   • $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ ユーザー情報取得エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# ライセンス情報テスト
Write-Host "`n📋 ライセンス情報テスト..." -ForegroundColor Cyan
try {
    $licenses = Get-MgSubscribedSku -ErrorAction SilentlyContinue
    Write-Host "✅ 取得成功: $($licenses.Count) ライセンス" -ForegroundColor Green
    foreach ($license in $licenses) {
        $skuName = switch ($license.SkuPartNumber) {
            "ENTERPRISEPACK" { "Microsoft 365 E3" }
            "ENTERPRISEPREMIUM" { "Microsoft 365 E5" }
            "SPE_E3" { "Microsoft 365 E3" }
            "SPE_E5" { "Microsoft 365 E5" }
            default { $license.SkuPartNumber }
        }
        Write-Host "   • $skuName : $($license.ConsumedUnits)/$($license.PrepaidUnits.Enabled)" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ ライセンス情報取得エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 日次レポートテスト
Write-Host "`n📅 日次レポートテスト..." -ForegroundColor Cyan
try {
    $dailyReport = Get-M365DailyReport
    if ($dailyReport.Count -gt 0) {
        Write-Host "✅ 日次レポート取得成功: $($dailyReport.Count) 件" -ForegroundColor Green
        Write-Host "   サンプル: $($dailyReport[0].ServiceName) - アクティブユーザー: $($dailyReport[0].ActiveUsersCount)" -ForegroundColor Gray
    } else {
        Write-Host "❌ 日次レポートが空です" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ 日次レポート取得エラー: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🏁 シンプルな実データ取得テスト完了" -ForegroundColor Cyan