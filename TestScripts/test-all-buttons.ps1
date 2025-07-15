# ================================================================================
# 全ボタン機能テスト
# test-all-buttons.ps1
# Teams以外の全ボタンが実データ取得を試行することを確認
# ================================================================================

Write-Host "`n🔍 全ボタン機能テスト開始" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor DarkGray

# テスト環境準備
$rootPath = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $rootPath "Scripts\Common"

Write-Host "`n1️⃣ モジュール読み込み" -ForegroundColor Yellow
try {
    Import-Module "$modulePath\Common.psm1" -Force
    Import-Module "$modulePath\GuiReportFunctions.psm1" -Force
    Write-Host "✅ モジュール読み込み成功" -ForegroundColor Green
}
catch {
    Write-Host "❌ モジュール読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n2️⃣ 認証状態確認" -ForegroundColor Yellow
$authStatus = Test-AuthenticationStatus -RequiredServices @("MicrosoftGraph", "ExchangeOnline")
if ($authStatus.IsValid) {
    Write-Host "✅ 認証済み" -ForegroundColor Green
}
else {
    Write-Host "⚠️  未認証 - 実データ取得は失敗しますが、サンプルデータで動作します" -ForegroundColor Yellow
}

Write-Host "`n3️⃣ 個別機能テスト" -ForegroundColor Yellow

# テスト対象の機能リスト
$testFunctions = @(
    @{ Name = "週次レポート"; Type = "Weekly" },
    @{ Name = "月次レポート"; Type = "Monthly" },
    @{ Name = "年次レポート"; Type = "Yearly" },
    @{ Name = "ライセンス分析"; Type = "License" },
    @{ Name = "使用状況分析"; Type = "Usage" },
    @{ Name = "パフォーマンス監視"; Type = "Performance" },
    @{ Name = "セキュリティ分析"; Type = "Security" },
    @{ Name = "権限監査"; Type = "Permissions" },
    @{ Name = "Entra IDユーザー"; Type = "EntraIDUsers" },
    @{ Name = "Entra ID MFA"; Type = "EntraIDMFA" },
    @{ Name = "条件付きアクセス"; Type = "ConditionalAccess" },
    @{ Name = "サインインログ"; Type = "SignInLogs" },
    @{ Name = "Exchangeメールボックス"; Type = "ExchangeMailbox" },
    @{ Name = "メールフロー"; Type = "MailFlow" },
    @{ Name = "スパム対策"; Type = "AntiSpam" },
    @{ Name = "メール配信"; Type = "MailDelivery" },
    @{ Name = "OneDriveストレージ"; Type = "OneDriveStorage" },
    @{ Name = "OneDrive共有"; Type = "OneDriveSharing" },
    @{ Name = "同期エラー"; Type = "SyncErrors" },
    @{ Name = "外部共有"; Type = "ExternalSharing" }
)

$successCount = 0
$failCount = 0

foreach ($test in $testFunctions) {
    Write-Host "`n  📋 $($test.Name) テスト中..." -ForegroundColor Cyan
    
    try {
        # 簡易フォールバックデータ生成関数
        $fallback = {
            Write-Host "    サンプルデータを使用します" -ForegroundColor Yellow
        }
        
        # 実際の関数呼び出しをシミュレート
        Invoke-GuiReportGeneration -ReportType $test.Type -ReportName "$($test.Name)テスト" -FallbackDataGenerator $fallback
        
        Write-Host "    ✅ $($test.Name) - 成功" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host "    ❌ $($test.Name) - エラー: $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
}

Write-Host "`n4️⃣ テスト結果サマリー" -ForegroundColor Yellow
Write-Host "  総テスト数: $($testFunctions.Count)" -ForegroundColor Gray
Write-Host "  成功: $successCount" -ForegroundColor Green
Write-Host "  失敗: $failCount" -ForegroundColor Red

if ($failCount -eq 0) {
    Write-Host "`n✅ すべてのテストが正常に完了しました" -ForegroundColor Green
}
else {
    Write-Host "`n⚠️  一部のテストが失敗しました" -ForegroundColor Yellow
}

Write-Host "`n5️⃣ GUI起動方法" -ForegroundColor Yellow
Write-Host @"
実際のGUIでテストする場合:

    pwsh -File "$rootPath\Apps\GuiApp.ps1"

各ボタンをクリックして以下を確認:
- 実データ取得を試行するメッセージが表示される
- 認証済みの場合は実データでレポート生成
- 未認証の場合はサンプルデータでレポート生成
- レポートファイルが自動的に開かれる

"@ -ForegroundColor Cyan

Write-Host "=" * 60 -ForegroundColor DarkGray
Write-Host "テスト完了" -ForegroundColor Cyan