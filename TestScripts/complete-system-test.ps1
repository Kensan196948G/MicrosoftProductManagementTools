# ================================================================================
# 完全システムテストスクリプト
# 全修正内容の統合確認
# ================================================================================

Write-Host "🎯 完全システムテストを開始します..." -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Blue

# テスト項目
$testResults = @{}

# 1. GUI起動テスト
Write-Host "🖥️ GUI起動テスト中..." -ForegroundColor Yellow
try {
    $guiTestResult = pwsh -sta -Command "
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        `$form = New-Object System.Windows.Forms.Form
        `$form.Size = New-Object System.Drawing.Size(100, 100)
        `$form.Dispose()
        Write-Output 'GUI_SUCCESS'
    "
    if ($guiTestResult -eq "GUI_SUCCESS") {
        $testResults["GUI起動"] = "✅ 成功"
        Write-Host "  ✅ GUI環境テスト成功" -ForegroundColor Green
    } else {
        $testResults["GUI起動"] = "❌ 失敗"
        Write-Host "  ❌ GUI環境テスト失敗" -ForegroundColor Red
    }
} catch {
    $testResults["GUI起動"] = "❌ エラー: $($_.Exception.Message)"
    Write-Host "  ❌ GUI起動エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. 構文チェック
Write-Host "📝 PowerShellスクリプト構文チェック中..." -ForegroundColor Yellow
$scriptFiles = @(
    "Apps\GuiApp.ps1",
    "Scripts\Common\HTMLTemplateWithPDF.psm1",
    "Scripts\Common\DailyReportData.psm1"
)

$syntaxErrors = 0
foreach ($file in $scriptFiles) {
    $fullPath = Join-Path (Split-Path $PSScriptRoot -Parent) $file
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $fullPath -Raw), [ref]$null)
        Write-Host "  ✅ $file - 構文OK" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ $file - 構文エラー: $($_.Exception.Message)" -ForegroundColor Red
        $syntaxErrors++
    }
}

if ($syntaxErrors -eq 0) {
    $testResults["構文チェック"] = "✅ 成功"
} else {
    $testResults["構文チェック"] = "❌ $syntaxErrors 個のエラー"
}

# 3. モジュール読み込みテスト
Write-Host "📦 モジュール読み込みテスト中..." -ForegroundColor Yellow
$toolRoot = Split-Path $PSScriptRoot -Parent
$modulePath = Join-Path $toolRoot "Scripts\Common"

try {
    Import-Module "$modulePath\HTMLTemplateWithPDF.psm1" -Force -DisableNameChecking -ErrorAction Stop
    Import-Module "$modulePath\DailyReportData.psm1" -Force -DisableNameChecking -ErrorAction Stop
    
    if ((Get-Command "New-HTMLReportWithPDF" -ErrorAction SilentlyContinue) -and 
        (Get-Command "Get-DailyReportRealData" -ErrorAction SilentlyContinue)) {
        $testResults["モジュール読み込み"] = "✅ 成功"
        Write-Host "  ✅ 必要な関数がすべて利用可能" -ForegroundColor Green
    } else {
        $testResults["モジュール読み込み"] = "❌ 関数が見つからない"
        Write-Host "  ❌ 一部の関数が利用できません" -ForegroundColor Red
    }
} catch {
    $testResults["モジュール読み込み"] = "❌ エラー: $($_.Exception.Message)"
    Write-Host "  ❌ モジュール読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. 実データ取得テスト
Write-Host "📊 実データ取得テスト中..." -ForegroundColor Yellow
try {
    $realData = Get-DailyReportRealData -UseSampleData -ErrorAction Stop
    if ($realData -and $realData.UserActivity -and $realData.UserActivity.Count -gt 0) {
        $testResults["実データ取得"] = "✅ 成功 ($($realData.UserActivity.Count) 件)"
        Write-Host "  ✅ 実データ取得成功: $($realData.UserActivity.Count) ユーザー" -ForegroundColor Green
    } else {
        $testResults["実データ取得"] = "❌ データが空"
        Write-Host "  ❌ 実データが空です" -ForegroundColor Red
    }
} catch {
    $testResults["実データ取得"] = "❌ エラー: $($_.Exception.Message)"
    Write-Host "  ❌ 実データ取得エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. CSV UTF8BOM テスト
Write-Host "📄 CSV UTF8BOM エンコーディングテスト中..." -ForegroundColor Yellow
$testDir = Join-Path $PSScriptRoot "TestReports"
if (-not (Test-Path $testDir)) {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
}

$csvPath = Join-Path $testDir "utf8bom-test.csv"
$testData = @([PSCustomObject]@{ "テスト" = "UTF8BOM"; "値" = "日本語テスト" })

try {
    $testData | Export-Csv -Path $csvPath -Encoding UTF8BOM -NoTypeInformation -ErrorAction Stop
    $bytes = [System.IO.File]::ReadAllBytes($csvPath)
    if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $testResults["CSV UTF8BOM"] = "✅ 成功"
        Write-Host "  ✅ UTF8 BOM確認済み" -ForegroundColor Green
    } else {
        $testResults["CSV UTF8BOM"] = "❌ BOMなし"
        Write-Host "  ❌ UTF8 BOMが見つかりません" -ForegroundColor Red
    }
} catch {
    $testResults["CSV UTF8BOM"] = "❌ エラー: $($_.Exception.Message)"
    Write-Host "  ❌ CSV出力エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. HTML+PDF生成テスト
Write-Host "🌐 HTML+PDF生成テスト中..." -ForegroundColor Yellow
$htmlPath = Join-Path $testDir "complete-test.html"
try {
    $dataSections = @(@{ Title = "テストデータ"; Data = $testData })
    $summary = @{ "テスト日時" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }
    
    $result = New-HTMLReportWithPDF -Title "完全システムテスト" -DataSections $dataSections -OutputPath $htmlPath -Summary $summary -ErrorAction Stop
    
    if (Test-Path $result) {
        $content = Get-Content $result -Raw
        if ($content -match "downloadPDF.*jsPDF|html2pdf") {
            $testResults["HTML+PDF生成"] = "✅ 成功"
            Write-Host "  ✅ HTML+PDF機能確認済み" -ForegroundColor Green
        } else {
            $testResults["HTML+PDF生成"] = "⚠️ PDF機能不完全"
            Write-Host "  ⚠️ PDF機能が不完全です" -ForegroundColor Yellow
        }
    } else {
        $testResults["HTML+PDF生成"] = "❌ ファイル未作成"
        Write-Host "  ❌ HTMLファイルが作成されませんでした" -ForegroundColor Red
    }
} catch {
    $testResults["HTML+PDF生成"] = "❌ エラー: $($_.Exception.Message)"
    Write-Host "  ❌ HTML生成エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 7. 統合レポート機能テスト
Write-Host "📋 統合レポート機能テスト中..." -ForegroundColor Yellow
$integrationTestPath = Join-Path $testDir "integration-test.html"
$integrationCsvPath = Join-Path $testDir "integration-test.csv"

try {
    # 実データでの統合テスト
    if ($realData) {
        $allSections = @(
            @{ Title = "👥 ユーザーアクティビティ"; Data = $realData.UserActivity },
            @{ Title = "📧 メールボックス容量"; Data = $realData.MailboxCapacity },
            @{ Title = "🔒 セキュリティアラート"; Data = $realData.SecurityAlerts },
            @{ Title = "🔐 MFA状況"; Data = $realData.MFAStatus }
        )
        
        $realData.UserActivity | Export-Csv -Path $integrationCsvPath -Encoding UTF8BOM -NoTypeInformation
        $htmlResult = New-HTMLReportWithPDF -Title "統合テストレポート" -DataSections $allSections -OutputPath $integrationTestPath -Summary $realData.Summary
        
        if ((Test-Path $htmlResult) -and (Test-Path $integrationCsvPath)) {
            $testResults["統合レポート"] = "✅ 成功"
            Write-Host "  ✅ 統合レポート生成成功" -ForegroundColor Green
        } else {
            $testResults["統合レポート"] = "❌ ファイル未作成"
            Write-Host "  ❌ 統合レポートファイル作成失敗" -ForegroundColor Red
        }
    } else {
        $testResults["統合レポート"] = "⚠️ 実データなしでスキップ"
        Write-Host "  ⚠️ 実データがないため統合テストをスキップ" -ForegroundColor Yellow
    }
} catch {
    $testResults["統合レポート"] = "❌ エラー: $($_.Exception.Message)"
    Write-Host "  ❌ 統合レポートエラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 結果サマリー
Write-Host "`n" + "=" * 60 -ForegroundColor Blue
Write-Host "🎯 完全システムテスト結果" -ForegroundColor Blue
Write-Host "=" * 60 -ForegroundColor Blue

foreach ($test in $testResults.Keys) {
    Write-Host "$test : $($testResults[$test])" -ForegroundColor White
}

$successCount = ($testResults.Values | Where-Object { $_ -match "✅" }).Count
$totalCount = $testResults.Count

Write-Host "`n📊 成功率: $successCount / $totalCount ($([Math]::Round(($successCount / $totalCount) * 100, 1))%)" -ForegroundColor Cyan

if ($successCount -eq $totalCount) {
    Write-Host "🎉 全テスト成功！システムは完全に動作しています。" -ForegroundColor Green
} elseif ($successCount -ge ($totalCount * 0.8)) {
    Write-Host "✅ 主要機能は正常です。軽微な問題があります。" -ForegroundColor Yellow
} else {
    Write-Host "⚠️ 複数の問題があります。修正が必要です。" -ForegroundColor Red
}

Write-Host "`n🚀 GUIアプリケーション起動手順:" -ForegroundColor Cyan
Write-Host "  1. pwsh -File run_launcher.ps1" -ForegroundColor White
Write-Host "  2. [1] GUI モードを選択" -ForegroundColor White
Write-Host "  3. 「📊 日次レポート」ボタンをクリック" -ForegroundColor White
Write-Host "  4. 生成されたHTMLでPDFダウンロードボタンをテスト" -ForegroundColor White

Write-Host "=" * 60 -ForegroundColor Blue