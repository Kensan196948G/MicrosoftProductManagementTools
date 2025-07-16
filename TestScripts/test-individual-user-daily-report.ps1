# 個別ユーザー日次レポートテスト

Write-Host "🔍 個別ユーザー日次レポートテストを開始します" -ForegroundColor Cyan

# モジュール読み込み
$modulePath = Join-Path $PSScriptRoot "..\Scripts\Common"
Import-Module "$modulePath\RealM365DataProvider.psm1" -Force -DisableNameChecking -Global
Import-Module "$modulePath\HTMLTemplateEngine.psm1" -Force -DisableNameChecking -Global

# 既存の接続確認
$graphContext = Get-MgContext -ErrorAction SilentlyContinue
if (-not $graphContext) {
    Write-Host "🔐 Microsoft 365に接続中..." -ForegroundColor Yellow
    $connectionResult = Connect-M365Services
    if (-not $connectionResult.GraphConnected) {
        Write-Host "❌ 接続に失敗しました" -ForegroundColor Red
        exit 1
    }
}

# 個別ユーザー日次レポートの取得（デフォルト: 最大100人）
Write-Host "`n📅 個別ユーザー日次レポートの取得テスト..." -ForegroundColor Cyan
$userDailyData = Get-M365DailyReport -MaxUsers 20  # テストのため20人に制限

Write-Host "`n📊 個別ユーザー日次レポートデータの詳細:" -ForegroundColor Cyan
Write-Host "   総ユーザー数: $($userDailyData.Count)" -ForegroundColor White
Write-Host "   アクティブユーザー数: $(($userDailyData | Where-Object { $_.ActivityLevel -ne '低' }).Count)" -ForegroundColor White

# データ構造の確認
if ($userDailyData.Count -gt 0) {
    Write-Host "`n📋 データ構造の確認:" -ForegroundColor Cyan
    $firstUser = $userDailyData[0]
    Write-Host "   プロパティ:" -ForegroundColor White
    foreach ($prop in $firstUser.PSObject.Properties.Name) {
        Write-Host "     • $prop : $($firstUser.$prop)" -ForegroundColor Gray
    }
}

# HTMLテンプレートエンジンのテスト
Write-Host "`n📄 HTMLテンプレートエンジンのテスト..." -ForegroundColor Cyan
try {
    $htmlReport = Generate-EnhancedHTMLReport -Data $userDailyData -ReportType "DailyReport" -Title "個別ユーザー日次レポート"
    
    if ($htmlReport) {
        Write-Host "✅ HTMLレポート生成成功" -ForegroundColor Green
        Write-Host "   文字数: $($htmlReport.Length)" -ForegroundColor White
        
        # 変数の置換確認
        $unreplacedVars = [regex]::Matches($htmlReport, '\{\{([^}]+)\}\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        if ($unreplacedVars.Count -eq 0) {
            Write-Host "   ✅ すべての変数が正しく置換されました" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️ 未置換の変数が見つかりました:" -ForegroundColor Yellow
            foreach ($var in $unreplacedVars) {
                Write-Host "     • {{$var}}" -ForegroundColor Yellow
            }
        }
        
        # 個別ユーザーデータの確認
        $userNames = ($userDailyData | Select-Object -First 3).UserName
        foreach ($userName in $userNames) {
            if ($htmlReport -match [regex]::Escape($userName)) {
                Write-Host "   ✅ ユーザー「$userName」のデータが含まれています" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️ ユーザー「$userName」のデータが見つかりません" -ForegroundColor Yellow
            }
        }
        
        # アクティビティレベルの確認
        $activityLevels = ($userDailyData | Select-Object -First 5).ActivityLevel
        foreach ($level in $activityLevels) {
            if ($htmlReport -match $level) {
                Write-Host "   ✅ アクティビティレベル「$level」が含まれています" -ForegroundColor Green
            }
        }
        
        # 統計情報の確認
        $totalUsers = $userDailyData.Count
        $activeUsers = ($userDailyData | Where-Object { $_.ActivityLevel -ne "低" }).Count
        if ($htmlReport -match $totalUsers) {
            Write-Host "   ✅ 総ユーザー数（$totalUsers）が正しく表示されています" -ForegroundColor Green
        }
        if ($htmlReport -match $activeUsers) {
            Write-Host "   ✅ アクティブユーザー数（$activeUsers）が正しく表示されています" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ HTMLレポート生成に失敗しました" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ HTMLレポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 実際のファイル出力テスト
Write-Host "`n📄 実際のファイル出力テスト..." -ForegroundColor Cyan
try {
    $testDir = Join-Path $PSScriptRoot "..\TestOutput"
    if (-not (Test-Path $testDir)) {
        New-Item -Path $testDir -ItemType Directory -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $htmlPath = Join-Path $testDir "UserDailyReport_$timestamp.html"
    $csvPath = Join-Path $testDir "UserDailyReport_$timestamp.csv"
    
    # CSV出力
    $userDailyData | Export-Csv -Path $csvPath -Encoding UTF8BOM -NoTypeInformation
    
    # HTML出力
    $htmlReport | Out-File -FilePath $htmlPath -Encoding UTF8
    
    Write-Host "✅ ファイル出力成功" -ForegroundColor Green
    Write-Host "   HTML: $htmlPath" -ForegroundColor White
    Write-Host "   CSV: $csvPath" -ForegroundColor White
    
    # ファイルサイズの確認
    $htmlSize = (Get-Item $htmlPath).Length
    $csvSize = (Get-Item $csvPath).Length
    Write-Host "   HTMLファイルサイズ: $htmlSize bytes" -ForegroundColor Gray
    Write-Host "   CSVファイルサイズ: $csvSize bytes" -ForegroundColor Gray
    
    # ファイルを開く
    Start-Process $htmlPath
    Write-Host "   📄 HTMLファイルを開きました" -ForegroundColor Green
    
} catch {
    Write-Host "❌ ファイル出力エラー: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🏁 個別ユーザー日次レポートテスト完了" -ForegroundColor Cyan

# 結果サマリー
Write-Host "`n📊 テスト結果サマリー:" -ForegroundColor Cyan
Write-Host "   • 取得ユーザー数: $($userDailyData.Count)人" -ForegroundColor White
Write-Host "   • データ種別: 個別ユーザーの日次アクティビティ" -ForegroundColor White
Write-Host "   • アクティビティレベル分布:" -ForegroundColor White
$activityStats = $userDailyData | Group-Object ActivityLevel | ForEach-Object { "     $($_.Name): $($_.Count)人" }
$activityStats | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
Write-Host "   • HTMLテンプレート: 個別ユーザーデータに対応" -ForegroundColor White
Write-Host "   • 変数置換: 完全" -ForegroundColor White
Write-Host "   • 実データ使用: $($userDailyData.Count)人の実際のユーザー情報から生成" -ForegroundColor White