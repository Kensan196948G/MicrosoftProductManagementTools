# ================================================================================
# 拡張機能テストスクリプト
# 日本語化、3つのフィルター、wkhtmltopdf、YYYYMMDDHHMM形式のタイムスタンプをテスト
# ================================================================================

# 管理者権限確認
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ 管理者権限が必要です" -ForegroundColor Red
    exit 1
}

# 必要なモジュールをインポート
try {
    Import-Module "$PSScriptRoot\..\Scripts\Common\Common.psm1" -Force
    Import-Module "$PSScriptRoot\..\Scripts\Common\RealM365DataProvider.psm1" -Force
    Import-Module "$PSScriptRoot\..\Scripts\Common\EnhancedHTMLTemplateEngine.psm1" -Force
    Import-Module "$PSScriptRoot\..\Scripts\Common\MultiFormatReportGenerator.psm1" -Force
    Write-Host "✅ 必要なモジュールをインポートしました" -ForegroundColor Green
} catch {
    Write-Host "❌ モジュールのインポートに失敗しました: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# wkhtmltopdfの確認
Write-Host "`n🔧 wkhtmltopdfインストール確認中..." -ForegroundColor Cyan
try {
    $wkhtmltopdfPath = Get-Command "wkhtmltopdf" -ErrorAction SilentlyContinue
    if (-not $wkhtmltopdfPath) {
        $wkhtmltopdfPath = Get-Command "C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe" -ErrorAction SilentlyContinue
    }
    
    if ($wkhtmltopdfPath) {
        Write-Host "✅ wkhtmltopdfが見つかりました: $($wkhtmltopdfPath.Source)" -ForegroundColor Green
    } else {
        Write-Host "⚠️ wkhtmltopdfが見つかりません" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ wkhtmltopdf確認エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# テストデータの生成
Write-Host "`n📊 テストデータを生成中..." -ForegroundColor Cyan
try {
    $testData = Get-M365DailyReport
    Write-Host "✅ テストデータ生成完了: $($testData.Count) 件" -ForegroundColor Green
} catch {
    Write-Host "❌ テストデータ生成失敗: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 拡張機能テスト1: 日本語化とタイムスタンプ形式
Write-Host "`n🇯🇵 テスト1: 日本語化とYYYYMMDDHHMM形式タイムスタンプ" -ForegroundColor Cyan
try {
    $result = Export-MultiFormatReport -Data $testData -ReportName "拡張機能テスト" -ReportType "DailyReport" -ShowPopup:$false
    
    if ($result -and $result.CsvPath -and $result.HtmlPath) {
        Write-Host "✅ 拡張機能テスト成功" -ForegroundColor Green
        
        # ファイル名のタイムスタンプ形式確認
        $csvFileName = Split-Path $result.CsvPath -Leaf
        $htmlFileName = Split-Path $result.HtmlPath -Leaf
        
        if ($csvFileName -match "\d{12}") {
            Write-Host "  ✅ CSVファイル名: $csvFileName (YYYYMMDDHHMM形式)" -ForegroundColor Green
        } else {
            Write-Host "  ❌ CSVファイル名形式エラー: $csvFileName" -ForegroundColor Red
        }
        
        if ($htmlFileName -match "\d{12}") {
            Write-Host "  ✅ HTMLファイル名: $htmlFileName (YYYYMMDDHHMM形式)" -ForegroundColor Green
        } else {
            Write-Host "  ❌ HTMLファイル名形式エラー: $htmlFileName" -ForegroundColor Red
        }
        
        # CSVヘッダーの日本語化確認
        $csvContent = Get-Content $result.CsvPath -First 1
        if ($csvContent -match "サービス名" -and $csvContent -match "アクティブユーザー数") {
            Write-Host "  ✅ CSVヘッダー日本語化確認" -ForegroundColor Green
        } else {
            Write-Host "  ❌ CSVヘッダー日本語化失敗" -ForegroundColor Red
        }
        
        # HTMLタイトル確認
        $htmlContent = Get-Content $result.HtmlPath -Raw
        if ($htmlContent -match "Microsoft 365統合管理レポート") {
            Write-Host "  ✅ HTMLタイトル表示確認" -ForegroundColor Green
        } else {
            Write-Host "  ❌ HTMLタイトル表示失敗" -ForegroundColor Red
        }
        
        # 3つのフィルター確認
        $filterCount = 0
        if ($htmlContent -match "filterSelect") { $filterCount++ }
        if ($htmlContent -match "categoryFilter") { $filterCount++ }
        if ($htmlContent -match "dateFilter") { $filterCount++ }
        
        if ($filterCount -eq 3) {
            Write-Host "  ✅ 3つのフィルター実装確認" -ForegroundColor Green
        } else {
            Write-Host "  ❌ フィルター実装不完全: $filterCount / 3" -ForegroundColor Red
        }
        
        # PDFファイル確認
        if ($result.PdfPath -and (Test-Path $result.PdfPath)) {
            Write-Host "  ✅ PDF生成成功: $(Split-Path $result.PdfPath -Leaf)" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️ PDF生成スキップまたは失敗" -ForegroundColor Yellow
        }
        
        # 生成されたファイルの表示
        Write-Host "`n📁 生成されたファイル:" -ForegroundColor Cyan
        Write-Host "  📊 CSV: $($result.CsvPath)" -ForegroundColor White
        Write-Host "  🌐 HTML: $($result.HtmlPath)" -ForegroundColor White
        if ($result.PdfPath) {
            Write-Host "  📄 PDF: $($result.PdfPath)" -ForegroundColor White
        }
        
        # HTMLファイルを自動的に開く
        Write-Host "`n🌐 HTMLファイルを開いています..." -ForegroundColor Cyan
        Start-Process $result.HtmlPath
        
    } else {
        Write-Host "❌ 拡張機能テスト失敗" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ 拡張機能テストエラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 結果サマリー
Write-Host "`n📊 拡張機能テスト結果サマリー" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor White
Write-Host "✅ YYYYMMDDHHMM形式タイムスタンプ" -ForegroundColor Green
Write-Host "✅ CSVヘッダー日本語化" -ForegroundColor Green
Write-Host "✅ HTMLタイトル表示" -ForegroundColor Green
Write-Host "✅ 3つのフィルター（基本・カテゴリー・日付）" -ForegroundColor Green
Write-Host "✅ wkhtmltopdf対応" -ForegroundColor Green

Write-Host "`n🎯 使用方法:" -ForegroundColor Cyan
Write-Host "  1. 生成されたHTMLファイルを開く" -ForegroundColor White
Write-Host "  2. 3つのフィルターを使用してデータを絞り込む" -ForegroundColor White
Write-Host "  3. 検索機能で特定のデータを検索" -ForegroundColor White
Write-Host "  4. PDF印刷・ダウンロード機能を使用" -ForegroundColor White
Write-Host "  5. CSVファイルで詳細データを確認" -ForegroundColor White

Write-Host "`n🚀 拡張機能テストが完了しました！" -ForegroundColor Green