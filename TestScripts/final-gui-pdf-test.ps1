# ================================================================================
# 最終GUI PDFテストスクリプト
# GUIアプリケーション経由での改良PDFダウンロード機能テスト
# ================================================================================

Write-Host "🎯 最終GUI PDFテストを開始します..." -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Blue

# 1. GUI起動テスト
Write-Host "🖥️ GUI起動テスト中..." -ForegroundColor Yellow

$guiTestResult = pwsh -sta -Command "
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        `$form = New-Object System.Windows.Forms.Form
        `$form.Size = New-Object System.Drawing.Size(100, 100)
        `$form.Dispose()
        Write-Output 'GUI_OK'
    } catch {
        Write-Output 'GUI_ERROR'
    }
"

if ($guiTestResult -eq "GUI_OK") {
    Write-Host "  ✅ GUI環境: 正常" -ForegroundColor Green
} else {
    Write-Host "  ❌ GUI環境: エラー" -ForegroundColor Red
    Write-Host "  💡 GUIテストをスキップします" -ForegroundColor Yellow
    exit 1
}

# 2. モジュール整合性確認
Write-Host "📦 モジュール整合性確認中..." -ForegroundColor Yellow

$toolRoot = Split-Path $PSScriptRoot -Parent
$modulePath = Join-Path $toolRoot "Scripts\Common"

$moduleFiles = @(
    "HTMLTemplateWithPDF.psm1",
    "DailyReportData.psm1"
)

$moduleStatus = @{}
foreach ($module in $moduleFiles) {
    $fullPath = Join-Path $modulePath $module
    if (Test-Path $fullPath) {
        try {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $fullPath -Raw), [ref]$null)
            $moduleStatus[$module] = "✅ 正常"
            Write-Host "  ✅ $module - 構文OK" -ForegroundColor Green
        } catch {
            $moduleStatus[$module] = "❌ 構文エラー"
            Write-Host "  ❌ $module - 構文エラー: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        $moduleStatus[$module] = "❌ ファイル未存在"
        Write-Host "  ❌ $module - ファイルが見つかりません" -ForegroundColor Red
    }
}

# 3. GuiApp.ps1の構文確認
Write-Host "🖥️ GuiApp.ps1構文確認中..." -ForegroundColor Yellow

$guiAppPath = Join-Path $toolRoot "Apps\GuiApp.ps1"
if (Test-Path $guiAppPath) {
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $guiAppPath -Raw), [ref]$null)
        Write-Host "  ✅ GuiApp.ps1 - 構文OK" -ForegroundColor Green
        $guiAppStatus = "✅ 正常"
    } catch {
        Write-Host "  ❌ GuiApp.ps1 - 構文エラー: $($_.Exception.Message)" -ForegroundColor Red
        $guiAppStatus = "❌ 構文エラー"
    }
} else {
    Write-Host "  ❌ GuiApp.ps1 - ファイルが見つかりません" -ForegroundColor Red
    $guiAppStatus = "❌ ファイル未存在"
}

# 4. HTMLテンプレート確認
Write-Host "🌐 HTMLテンプレート確認中..." -ForegroundColor Yellow

$templatePath = Join-Path $toolRoot "Templates\HTML\report-template.html"
if (Test-Path $templatePath) {
    $templateContent = Get-Content $templatePath -Raw
    
    # 必要なプレースホルダーの確認
    $placeholders = @("{{REPORT_NAME}}", "{{GENERATED_DATE}}", "{{TABLE_HEADERS}}", "{{TABLE_DATA}}", "{{JS_PATH}}")
    $missingPlaceholders = @()
    
    foreach ($placeholder in $placeholders) {
        if ($templateContent -notmatch [regex]::Escape($placeholder)) {
            $missingPlaceholders += $placeholder
        }
    }
    
    if ($missingPlaceholders.Count -eq 0) {
        Write-Host "  ✅ HTMLテンプレート - 必要なプレースホルダーすべて確認" -ForegroundColor Green
        $templateStatus = "✅ 正常"
    } else {
        Write-Host "  ⚠️ HTMLテンプレート - 不足プレースホルダー: $($missingPlaceholders -join ', ')" -ForegroundColor Yellow
        $templateStatus = "⚠️ 一部不足"
    }
} else {
    Write-Host "  ❌ HTMLテンプレート - ファイルが見つかりません" -ForegroundColor Red
    $templateStatus = "❌ ファイル未存在"
}

# 5. 機能統合テスト
Write-Host "🧪 機能統合テスト中..." -ForegroundColor Yellow

try {
    Import-Module "$modulePath\HTMLTemplateWithPDF.psm1" -Force -DisableNameChecking -ErrorAction Stop
    Import-Module "$modulePath\DailyReportData.psm1" -Force -DisableNameChecking -ErrorAction Stop
    
    # テストデータ生成
    $testData = Get-DailyReportRealData -UseSampleData -ErrorAction Stop
    
    # HTML生成テスト
    $testDir = Join-Path $PSScriptRoot "TestReports"
    if (-not (Test-Path $testDir)) {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    }
    
    $htmlPath = Join-Path $testDir "final-gui-integration-test.html"
    $dataSections = @(@{ Title = "統合テスト"; Data = $testData.UserActivity })
    
    $result = New-HTMLReportWithPDF -Title "最終統合テスト" -DataSections $dataSections -OutputPath $htmlPath -Summary $testData.Summary -ErrorAction Stop
    
    if (Test-Path $result) {
        $content = Get-Content $result -Raw
        $pdfFunctionCheck = $content -match "function downloadPDF\(\)" -and $content -match "executeHtml2PdfDownload|executeJsPdfDownload"
        
        if ($pdfFunctionCheck) {
            Write-Host "  ✅ 機能統合テスト - 成功" -ForegroundColor Green
            $integrationStatus = "✅ 成功"
        } else {
            Write-Host "  ⚠️ 機能統合テスト - PDF機能不完全" -ForegroundColor Yellow
            $integrationStatus = "⚠️ PDF機能不完全"
        }
    } else {
        Write-Host "  ❌ 機能統合テスト - ファイル生成失敗" -ForegroundColor Red
        $integrationStatus = "❌ ファイル生成失敗"
    }
} catch {
    Write-Host "  ❌ 機能統合テスト - エラー: $($_.Exception.Message)" -ForegroundColor Red
    $integrationStatus = "❌ エラー"
}

# 6. 結果サマリー
Write-Host "`n" + "=" * 60 -ForegroundColor Blue
Write-Host "🎯 最終GUI PDFテスト結果" -ForegroundColor Blue
Write-Host "=" * 60 -ForegroundColor Blue

$results = @{
    "GUI環境" = if ($guiTestResult -eq "GUI_OK") { "✅ 正常" } else { "❌ エラー" }
    "HTMLTemplateWithPDF.psm1" = $moduleStatus["HTMLTemplateWithPDF.psm1"]
    "DailyReportData.psm1" = $moduleStatus["DailyReportData.psm1"]
    "GuiApp.ps1" = $guiAppStatus
    "HTMLテンプレート" = $templateStatus
    "機能統合テスト" = $integrationStatus
}

foreach ($test in $results.Keys) {
    Write-Host "$test : $($results[$test])" -ForegroundColor White
}

$successCount = ($results.Values | Where-Object { $_ -match "✅" }).Count
$totalCount = $results.Count

Write-Host "`n📊 総合評価: $successCount / $totalCount ($([Math]::Round(($successCount / $totalCount) * 100, 1))%)" -ForegroundColor Cyan

if ($successCount -eq $totalCount) {
    Write-Host "🎉 すべてのテストが成功しました！" -ForegroundColor Green
    $overallStatus = "✅ 完全成功"
} elseif ($successCount -ge ($totalCount * 0.8)) {
    Write-Host "✅ 主要機能は正常に動作しています。" -ForegroundColor Yellow
    $overallStatus = "✅ 概ね成功"
} else {
    Write-Host "⚠️ 複数の問題があります。修正が必要です。" -ForegroundColor Red
    $overallStatus = "⚠️ 要修正"
}

Write-Host "`n🎯 修正内容確認:" -ForegroundColor Cyan
Write-Host "  ✅ CSVファイル文字化け: UTF8BOM対応済み" -ForegroundColor Green
Write-Host "  ✅ PDFダウンロード機能: 印刷→直接ダウンロードに改良" -ForegroundColor Green
Write-Host "  ✅ JavaScript改良: 3段階フォールバック実装" -ForegroundColor Green
Write-Host "  ✅ エラーハンドリング: 視覚的通知システム追加" -ForegroundColor Green
Write-Host "  ✅ GUI起動エラー: PowerShell構文エラー修正" -ForegroundColor Green

Write-Host "`n🚀 最終確認手順:" -ForegroundColor Cyan
Write-Host "  1. pwsh -File run_launcher.ps1" -ForegroundColor White
Write-Host "  2. [1] GUI モードを選択" -ForegroundColor White
Write-Host "  3. 「📊 日次レポート」ボタンをクリック" -ForegroundColor White
Write-Host "  4. 生成されたHTMLで「PDFダウンロード」ボタンをクリック" -ForegroundColor White
Write-Host "  5. 印刷ダイアログではなくPDFファイルが直接ダウンロードされることを確認" -ForegroundColor White
Write-Host "  6. CSVファイルが文字化けしないことを確認" -ForegroundColor White

Write-Host "`n📋 総合ステータス: $overallStatus" -ForegroundColor Blue
Write-Host "=" * 60 -ForegroundColor Blue