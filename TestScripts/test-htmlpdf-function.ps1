# ================================================================================
# HTMLTemplateWithPDF.psm1関数テストスクリプト
# New-HTMLReportWithPDF関数の動作確認
# ================================================================================

Write-Host "🔍 HTMLTemplateWithPDF機能をテスト中..." -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Blue

# ツールルートの取得
$toolRoot = Split-Path $PSScriptRoot -Parent
$modulePath = Join-Path $toolRoot "Scripts\Common"

# 1. モジュール読み込みテスト
Write-Host "📦 HTMLTemplateWithPDFモジュールを読み込み中..." -ForegroundColor Yellow

try {
    Remove-Module HTMLTemplateWithPDF -ErrorAction SilentlyContinue
    Import-Module "$modulePath\HTMLTemplateWithPDF.psm1" -Force -DisableNameChecking
    Write-Host "  ✅ HTMLTemplateWithPDFモジュール読み込み成功" -ForegroundColor Green
} catch {
    Write-Host "  ❌ HTMLTemplateWithPDFモジュール読み込み失敗: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 2. 関数存在確認
Write-Host "🔧 関数の存在確認中..." -ForegroundColor Yellow

$requiredFunctions = @(
    "New-HTMLReportWithPDF",
    "Set-TemplateVariables", 
    "Get-StatusBadgeClass",
    "Generate-JavaScriptContent",
    "Get-FallbackTemplate"
)

foreach ($function in $requiredFunctions) {
    if (Get-Command $function -ErrorAction SilentlyContinue) {
        Write-Host "  ✅ $function - 利用可能" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $function - 見つかりません" -ForegroundColor Red
    }
}

# 3. テストデータ準備
Write-Host "📊 テストデータを準備中..." -ForegroundColor Yellow

$testDataSections = @(
    @{
        Title = "ユーザーアクティビティ"
        Data = @(
            [PSCustomObject]@{
                ユーザー名 = "テストユーザー1"
                メールアドレス = "test1@test.com"
                Status = "アクティブ"
                最終ログイン = "2024-01-15"
            },
            [PSCustomObject]@{
                ユーザー名 = "テストユーザー2"
                メールアドレス = "test2@test.com"
                Status = "警告"
                最終ログイン = "2024-01-10"
            }
        )
    }
)

$testSummary = @{
    総ユーザー数 = 2
    アクティブユーザー数 = 1
    警告ユーザー数 = 1
}

# 4. HTMLレポート生成テスト
Write-Host "🚀 HTMLレポート生成をテスト中..." -ForegroundColor Yellow

$outputPath = Join-Path $PSScriptRoot "TestReports\test-htmlpdf-output.html"
$outputDir = Split-Path $outputPath -Parent

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

try {
    $result = New-HTMLReportWithPDF -Title "機能テストレポート" -DataSections $testDataSections -OutputPath $outputPath -Summary $testSummary
    
    if (Test-Path $result) {
        Write-Host "  ✅ HTMLレポート生成成功" -ForegroundColor Green
        Write-Host "    📄 出力ファイル: $result" -ForegroundColor White
        
        # ファイルサイズ確認
        $fileSize = (Get-Item $result).Length
        Write-Host "    📏 ファイルサイズ: $fileSize バイト" -ForegroundColor White
        
        # 内容確認（最初の500文字）
        $content = Get-Content $result -Raw
        if ($content.Length -gt 0) {
            Write-Host "    ✅ HTMLコンテンツが正常に生成されました" -ForegroundColor Green
            
            # テンプレート使用確認
            if ($content -match "{{REPORT_NAME}}") {
                Write-Host "    ⚠️ テンプレート変数が未置換です" -ForegroundColor Yellow
            } else {
                Write-Host "    ✅ テンプレート変数が正常に置換されました" -ForegroundColor Green
            }
            
            # データテーブル確認
            if ($content -match "テストユーザー1") {
                Write-Host "    ✅ テストデータがHTMLに含まれています" -ForegroundColor Green
            } else {
                Write-Host "    ⚠️ テストデータがHTMLに見つかりません" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    ❌ HTMLコンテンツが空です" -ForegroundColor Red
        }
    } else {
        Write-Host "  ❌ HTMLレポート生成失敗 - ファイルが作成されませんでした" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ HTMLレポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    詳細: $($_.Exception.InnerException.Message)" -ForegroundColor Yellow
}

# 5. テンプレートファイル確認
Write-Host "📄 テンプレートファイル確認中..." -ForegroundColor Yellow

$templatePath = Join-Path $toolRoot "Templates\HTML\report-template.html"
if (Test-Path $templatePath) {
    Write-Host "  ✅ テンプレートファイル発見: $templatePath" -ForegroundColor Green
    $templateSize = (Get-Item $templatePath).Length
    Write-Host "    📏 テンプレートサイズ: $templateSize バイト" -ForegroundColor White
} else {
    Write-Host "  ⚠️ テンプレートファイルが見つかりません: $templatePath" -ForegroundColor Yellow
    Write-Host "    💡 フォールバックテンプレートが使用されます" -ForegroundColor Cyan
}

# 6. 結果サマリー
Write-Host "`n" + "=" * 60 -ForegroundColor Blue
Write-Host "🎯 HTMLTemplateWithPDF機能テスト結果" -ForegroundColor Blue
Write-Host "=" * 60 -ForegroundColor Blue

if (Get-Command "New-HTMLReportWithPDF" -ErrorAction SilentlyContinue) {
    Write-Host "✅ New-HTMLReportWithPDF関数: 利用可能" -ForegroundColor Green
    Write-Host "✅ モジュール読み込み: 成功" -ForegroundColor Green
    
    if (Test-Path $outputPath) {
        Write-Host "✅ テストレポート生成: 成功" -ForegroundColor Green
        Write-Host "📊 機能は正常に動作しています！" -ForegroundColor Green
        Write-Host ""
        Write-Host "🚀 次のステップ:" -ForegroundColor Cyan
        Write-Host "  1. GUIで「📊 日次レポート」ボタンをクリックしてテスト" -ForegroundColor White
        Write-Host "  2. 生成されたHTMLファイルを確認" -ForegroundColor White
        Write-Host "  3. PDF生成機能をテスト" -ForegroundColor White
    } else {
        Write-Host "❌ テストレポート生成: 失敗" -ForegroundColor Red
    }
} else {
    Write-Host "❌ New-HTMLReportWithPDF関数: 利用不可" -ForegroundColor Red
    Write-Host "❌ 関数認識エラーが継続しています" -ForegroundColor Red
}

Write-Host "=" * 60 -ForegroundColor Blue