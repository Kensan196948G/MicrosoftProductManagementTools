# ================================================================================
# test-daily-report-real.ps1
# 日次レポート実データ取得テスト
# ================================================================================

# モジュールパスの設定
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath
$modulePath = Join-Path $rootPath "Scripts\Common"

# 必要なモジュールをインポート
Import-Module "$modulePath\Logging.psm1" -Force
Import-Module "$modulePath\ErrorHandling.psm1" -Force
Import-Module "$modulePath\Authentication.psm1" -Force
Import-Module "$modulePath\DailyReportData.psm1" -Force

Write-Host "`n🔍 日次レポート実データ取得テスト開始" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor DarkGray

# 1. 認証状態確認
Write-Host "`n1️⃣ 認証状態確認" -ForegroundColor Yellow
$authStatus = Test-AuthenticationStatus -RequiredServices @("MicrosoftGraph", "ExchangeOnline")

if ($authStatus.IsValid) {
    Write-Host "✅ 認証済み - 接続サービス: $($authStatus.ConnectedServices -join ', ')" -ForegroundColor Green
} else {
    Write-Host "⚠️  未認証 - 不足サービス: $($authStatus.MissingServices -join ', ')" -ForegroundColor Yellow
    Write-Host "認証を試行します..." -ForegroundColor Cyan
    
    try {
        # 設定ファイル読み込み
        $configPath = Join-Path $rootPath "Config\appsettings.local.json"
        if (-not (Test-Path $configPath)) {
            $configPath = Join-Path $rootPath "Config\appsettings.json"
        }
        
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $connectResult = Connect-ToMicrosoft365 -Config $config -Services @("MicrosoftGraph", "ExchangeOnline")
        
        if ($connectResult.Success) {
            Write-Host "✅ 認証成功" -ForegroundColor Green
        } else {
            Write-Host "❌ 認証失敗: $($connectResult.Errors -join ', ')" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ 認証エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 2. 実データ取得テスト（強制実行）
Write-Host "`n2️⃣ 実データ取得テスト（API接続）" -ForegroundColor Yellow
try {
    $realData = Get-DailyReportRealData -ForceRealData:$false
    
    Write-Host "✅ データ取得成功" -ForegroundColor Green
    Write-Host "   データソース: $($realData.DataSource)" -ForegroundColor Cyan
    Write-Host "   生成日時: $($realData.GeneratedAt)" -ForegroundColor Gray
    
    # サマリー表示
    if ($realData.Summary) {
        Write-Host "`n📊 データサマリー:" -ForegroundColor Yellow
        Write-Host "   総ユーザー数: $($realData.Summary.TotalUsers)" -ForegroundColor Gray
        Write-Host "   アクティブユーザー: $($realData.Summary.ActiveUsers)" -ForegroundColor Gray
        Write-Host "   非アクティブユーザー: $($realData.Summary.InactiveUsers)" -ForegroundColor Gray
        Write-Host "   監視メールボックス: $($realData.Summary.MailboxesMonitored)" -ForegroundColor Gray
        Write-Host "   容量警告: $($realData.Summary.MailboxWarnings)" -ForegroundColor Gray
        Write-Host "   セキュリティアラート: $($realData.Summary.SecurityAlerts)" -ForegroundColor Gray
        Write-Host "   高リスクアラート: $($realData.Summary.HighRiskAlerts)" -ForegroundColor Gray
        Write-Host "   MFA設定済み: $($realData.Summary.UsersWithMFA)" -ForegroundColor Gray
        Write-Host "   MFA未設定: $($realData.Summary.UsersWithoutMFA)" -ForegroundColor Gray
    }
    
    # 各データの詳細表示
    Write-Host "`n📋 取得データ詳細:" -ForegroundColor Yellow
    
    # ユーザーアクティビティ
    if ($realData.UserActivity -and $realData.UserActivity.Count -gt 0) {
        Write-Host "`n  👥 ユーザーアクティビティ (上位5件):" -ForegroundColor Cyan
        $realData.UserActivity | Select-Object -First 5 | ForEach-Object {
            Write-Host "     - $($_.ユーザー名) [$($_.Status)] 最終ログイン: $($_.最終ログイン)" -ForegroundColor Gray
        }
    }
    
    # メールボックス容量
    if ($realData.MailboxCapacity -and $realData.MailboxCapacity.Count -gt 0) {
        Write-Host "`n  📧 メールボックス容量 (警告のみ):" -ForegroundColor Cyan
        $realData.MailboxCapacity | Where-Object { $_.Status -in @("警告", "危険") } | Select-Object -First 5 | ForEach-Object {
            Write-Host "     - $($_.メールボックス) [$($_.Status)] 使用率: $($_.使用率)%" -ForegroundColor Gray
        }
    }
    
    # セキュリティアラート
    if ($realData.SecurityAlerts -and $realData.SecurityAlerts.Count -gt 0) {
        Write-Host "`n  🔒 セキュリティアラート (最新5件):" -ForegroundColor Cyan
        $realData.SecurityAlerts | Select-Object -First 5 | ForEach-Object {
            Write-Host "     - [$($_.Severity)] $($_.種類) - $($_.ユーザー) ($($_.検出時刻))" -ForegroundColor Gray
        }
    }
    
    # MFA状況
    if ($realData.MFAStatus -and $realData.MFAStatus.Count -gt 0) {
        Write-Host "`n  🔐 MFA未設定ユーザー (上位5件):" -ForegroundColor Cyan
        $realData.MFAStatus | Where-Object { $_.HasMFA -eq $false } | Select-Object -First 5 | ForEach-Object {
            Write-Host "     - $($_.ユーザー名) - $($_.メールアドレス)" -ForegroundColor Gray
        }
    }
}
catch {
    Write-Host "❌ データ取得エラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor DarkRed
}

# 3. サンプルデータ取得テスト
Write-Host "`n3️⃣ サンプルデータ取得テスト（フォールバック）" -ForegroundColor Yellow
try {
    $sampleData = Get-DailyReportRealData -UseSampleData
    
    Write-Host "✅ サンプルデータ取得成功" -ForegroundColor Green
    Write-Host "   データソース: $($sampleData.DataSource)" -ForegroundColor Cyan
    Write-Host "   総ユーザー数: $($sampleData.Summary.TotalUsers)" -ForegroundColor Gray
    Write-Host "   総メールボックス: $($sampleData.Summary.MailboxesMonitored)" -ForegroundColor Gray
}
catch {
    Write-Host "❌ サンプルデータ取得エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. 日次レポート生成テスト
Write-Host "`n4️⃣ 日次レポート生成テスト" -ForegroundColor Yellow
try {
    # ScheduledReportsモジュールをインポート
    Import-Module "$modulePath\ScheduledReports.ps1" -Force
    
    Write-Host "日次レポート生成を実行中..." -ForegroundColor Cyan
    Invoke-DailyReports
    
    Write-Host "✅ 日次レポート生成完了" -ForegroundColor Green
    
    # レポートファイルの確認
    $reportsPath = Join-Path $rootPath "Reports\Daily"
    $latestReport = Get-ChildItem -Path $reportsPath -Filter "*.html" | Sort-Object CreationTime -Descending | Select-Object -First 1
    
    if ($latestReport) {
        Write-Host "   生成ファイル: $($latestReport.Name)" -ForegroundColor Gray
        Write-Host "   ファイルサイズ: $([Math]::Round($latestReport.Length / 1KB, 2)) KB" -ForegroundColor Gray
        Write-Host "   作成日時: $($latestReport.CreationTime)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "❌ レポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. 接続切断
Write-Host "`n5️⃣ クリーンアップ" -ForegroundColor Yellow
try {
    Disconnect-AllServices
    Write-Host "✅ 接続を切断しました" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  切断エラー: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor DarkGray
Write-Host "テスト完了" -ForegroundColor Cyan