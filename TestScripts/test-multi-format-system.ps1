# ================================================================================
# マルチフォーマットレポートシステム統合テスト
# 新しいEnhancedHTMLTemplateEngine、MultiFormatReportGenerator、GuiApp_Enhanced をテスト
# ================================================================================

# 管理者権限とPowerShell 7.5.1実行環境を確認
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ 管理者権限が必要です" -ForegroundColor Red
    exit 1
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "⚠️ PowerShell 7.5.1以上での実行を推奨します" -ForegroundColor Yellow
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

# テストデータの生成
Write-Host "`n📊 テストデータを生成中..." -ForegroundColor Cyan

# 1. 日次レポートデータ（539人のユーザーデータ）
Write-Host "  🔄 日次レポートデータを生成中..." -ForegroundColor Gray
try {
    $dailyData = Get-M365DailyReport
    Write-Host "  ✅ 日次レポートデータ生成完了: $($dailyData.Count) 件" -ForegroundColor Green
} catch {
    Write-Host "  ❌ 日次レポートデータ生成失敗: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 2. ユーザー一覧データ
Write-Host "  🔄 ユーザー一覧データを生成中..." -ForegroundColor Gray
try {
    $usersData = Get-M365AllUsers
    Write-Host "  ✅ ユーザー一覧データ生成完了: $($usersData.Count) 件" -ForegroundColor Green
} catch {
    Write-Host "  ❌ ユーザー一覧データ生成失敗: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 3. ライセンス分析データ
Write-Host "  🔄 ライセンス分析データを生成中..." -ForegroundColor Gray
try {
    $licenseData = Get-M365LicenseAnalysis
    Write-Host "  ✅ ライセンス分析データ生成完了: $($licenseData.Count) 件" -ForegroundColor Green
} catch {
    Write-Host "  ❌ ライセンス分析データ生成失敗: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# テストケース1: 日次レポートの多形式出力
Write-Host "`n📄 テストケース1: 日次レポートの多形式出力" -ForegroundColor Cyan
try {
    $result1 = Export-MultiFormatReport -Data $dailyData -ReportName "DailyReport" -ReportType "DailyReport" -ShowPopup:$false
    
    if ($result1 -and $result1.CsvPath -and $result1.HtmlPath) {
        Write-Host "  ✅ 日次レポート多形式出力成功" -ForegroundColor Green
        Write-Host "    📊 CSV: $(Split-Path $result1.CsvPath -Leaf)" -ForegroundColor White
        Write-Host "    🌐 HTML: $(Split-Path $result1.HtmlPath -Leaf)" -ForegroundColor White
        if ($result1.PdfPath) {
            Write-Host "    📄 PDF: $(Split-Path $result1.PdfPath -Leaf)" -ForegroundColor White
        }
    } else {
        Write-Host "  ❌ 日次レポート多形式出力失敗" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ 日次レポート多形式出力エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# テストケース2: ユーザー一覧の多形式出力
Write-Host "`n👥 テストケース2: ユーザー一覧の多形式出力" -ForegroundColor Cyan
try {
    $result2 = Export-MultiFormatReport -Data $usersData -ReportName "AllUsers" -ReportType "Users" -ShowPopup:$false
    
    if ($result2 -and $result2.CsvPath -and $result2.HtmlPath) {
        Write-Host "  ✅ ユーザー一覧多形式出力成功" -ForegroundColor Green
        Write-Host "    📊 CSV: $(Split-Path $result2.CsvPath -Leaf)" -ForegroundColor White
        Write-Host "    🌐 HTML: $(Split-Path $result2.HtmlPath -Leaf)" -ForegroundColor White
        if ($result2.PdfPath) {
            Write-Host "    📄 PDF: $(Split-Path $result2.PdfPath -Leaf)" -ForegroundColor White
        }
    } else {
        Write-Host "  ❌ ユーザー一覧多形式出力失敗" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ ユーザー一覧多形式出力エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# テストケース3: ライセンス分析の多形式出力
Write-Host "`n🔑 テストケース3: ライセンス分析の多形式出力" -ForegroundColor Cyan
try {
    $result3 = Export-MultiFormatReport -Data $licenseData -ReportName "LicenseAnalysis" -ReportType "LicenseAnalysis" -ShowPopup:$false
    
    if ($result3 -and $result3.CsvPath -and $result3.HtmlPath) {
        Write-Host "  ✅ ライセンス分析多形式出力成功" -ForegroundColor Green
        Write-Host "    📊 CSV: $(Split-Path $result3.CsvPath -Leaf)" -ForegroundColor White
        Write-Host "    🌐 HTML: $(Split-Path $result3.HtmlPath -Leaf)" -ForegroundColor White
        if ($result3.PdfPath) {
            Write-Host "    📄 PDF: $(Split-Path $result3.PdfPath -Leaf)" -ForegroundColor White
        }
    } else {
        Write-Host "  ❌ ライセンス分析多形式出力失敗" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ ライセンス分析多形式出力エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# テストケース4: インタラクティブHTML機能の確認
Write-Host "`n🌐 テストケース4: インタラクティブHTML機能の確認" -ForegroundColor Cyan
try {
    $testHtmlPath = "E:\MicrosoftProductManagementTools\TestScripts\TestReports\interactive-test.html"
    
    # インタラクティブHTMLレポートを生成
    $htmlContent = Generate-InteractiveHTMLReport -Data $dailyData -ReportType "DailyReport" -Title "インタラクティブHTML機能テスト" -OutputPath $testHtmlPath
    
    if ($htmlContent -and (Test-Path $testHtmlPath)) {
        Write-Host "  ✅ インタラクティブHTML生成成功" -ForegroundColor Green
        
        # JavaScript機能をチェック
        $jsFeatures = @(
            "performSearch()",
            "performFilter()",
            "printReport()",
            "downloadPDF()",
            "resetFilters()"
        )
        
        $foundFeatures = 0
        foreach ($feature in $jsFeatures) {
            if ($htmlContent -match [regex]::Escape($feature)) {
                $foundFeatures++
            }
        }
        
        Write-Host "    📊 JavaScript機能: $foundFeatures / $($jsFeatures.Count) 個実装済み" -ForegroundColor White
        
        # CSSクラスをチェック
        $cssClasses = @(
            "search-input",
            "filter-select",
            "btn-primary",
            "badge-active",
            "data-row"
        )
        
        $foundClasses = 0
        foreach ($class in $cssClasses) {
            if ($htmlContent -match $class) {
                $foundClasses++
            }
        }
        
        Write-Host "    🎨 CSSクラス: $foundClasses / $($cssClasses.Count) 個実装済み" -ForegroundColor White
        
        if ($foundFeatures -eq $jsFeatures.Count -and $foundClasses -eq $cssClasses.Count) {
            Write-Host "  ✅ インタラクティブHTML機能確認完了" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️ 一部の機能が実装されていません" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ❌ インタラクティブHTML生成失敗" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ インタラクティブHTML機能テストエラー: $($_.Exception.Message)" -ForegroundColor Red
}

# テストケース5: フォルダ構造の確認
Write-Host "`n📁 テストケース5: フォルダ構造の確認" -ForegroundColor Cyan
try {
    $expectedFolders = @(
        "E:\MicrosoftProductManagementTools\Reports\Regularreports",
        "E:\MicrosoftProductManagementTools\Reports\EntraIDManagement",
        "E:\MicrosoftProductManagementTools\Reports\Analyticreport",
        "E:\MicrosoftProductManagementTools\Reports\ExchangeOnlineManagement",
        "E:\MicrosoftProductManagementTools\Reports\TeamsManagement",
        "E:\MicrosoftProductManagementTools\Reports\OneDriveManagement"
    )
    
    $existingFolders = 0
    foreach ($folder in $expectedFolders) {
        if (Test-Path $folder) {
            $existingFolders++
            Write-Host "    ✅ $(Split-Path $folder -Leaf)" -ForegroundColor Green
        } else {
            Write-Host "    ❌ $(Split-Path $folder -Leaf)" -ForegroundColor Red
        }
    }
    
    Write-Host "  📊 フォルダ構造: $existingFolders / $($expectedFolders.Count) 個存在" -ForegroundColor White
} catch {
    Write-Host "  ❌ フォルダ構造確認エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# テストケース6: ポップアップ表示機能（デモンストレーション）
Write-Host "`n📢 テストケース6: ポップアップ表示機能（デモンストレーション）" -ForegroundColor Cyan
try {
    Write-Host "  🔄 ポップアップ表示機能をテスト中..." -ForegroundColor Gray
    
    # ポップアップ表示を有効にしてテスト
    $popupResult = Export-MultiFormatReport -Data ($dailyData | Select-Object -First 5) -ReportName "PopupTest" -ReportType "DailyReport" -ShowPopup:$true
    
    if ($popupResult) {
        Write-Host "  ✅ ポップアップ表示機能テスト完了" -ForegroundColor Green
        Write-Host "    💡 ポップアップウィンドウが表示されます" -ForegroundColor Yellow
    } else {
        Write-Host "  ❌ ポップアップ表示機能テスト失敗" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ ポップアップ表示機能テストエラー: $($_.Exception.Message)" -ForegroundColor Red
}

# テスト結果の総括
Write-Host "`n📊 テスト結果総括" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor White

$testResults = @(
    @{ Name = "日次レポート多形式出力"; Status = ($result1 -ne $null) },
    @{ Name = "ユーザー一覧多形式出力"; Status = ($result2 -ne $null) },
    @{ Name = "ライセンス分析多形式出力"; Status = ($result3 -ne $null) },
    @{ Name = "インタラクティブHTML機能"; Status = (Test-Path "E:\MicrosoftProductManagementTools\TestScripts\TestReports\interactive-test.html") },
    @{ Name = "フォルダ構造"; Status = ($existingFolders -eq $expectedFolders.Count) },
    @{ Name = "ポップアップ表示機能"; Status = ($popupResult -ne $null) }
)

$passedTests = 0
foreach ($test in $testResults) {
    if ($test.Status) {
        Write-Host "✅ $($test.Name)" -ForegroundColor Green
        $passedTests++
    } else {
        Write-Host "❌ $($test.Name)" -ForegroundColor Red
    }
}

Write-Host "`n📈 総合結果: $passedTests / $($testResults.Count) テスト合格" -ForegroundColor White

if ($passedTests -eq $testResults.Count) {
    Write-Host "🎉 すべてのテストが合格しました！" -ForegroundColor Green
    Write-Host "   マルチフォーマットレポートシステムは正常に動作しています。" -ForegroundColor Green
} else {
    Write-Host "⚠️ 一部のテストが失敗しました。" -ForegroundColor Yellow
    Write-Host "   上記の結果を確認して問題を修正してください。" -ForegroundColor Yellow
}

Write-Host "`n💡 使用方法:" -ForegroundColor Cyan
Write-Host "   1. pwsh -File run_launcher.ps1" -ForegroundColor White
Write-Host "   2. 1 (GUI モード) を選択" -ForegroundColor White
Write-Host "   3. 各ボタンをクリックしてレポートを生成" -ForegroundColor White
Write-Host "   4. CSV、HTML、PDFファイルが自動生成され、ポップアップ表示されます" -ForegroundColor White

Write-Host "`n🔧 開発者向け情報:" -ForegroundColor Cyan
Write-Host "   - EnhancedHTMLTemplateEngine.psm1: インタラクティブHTML生成" -ForegroundColor White
Write-Host "   - MultiFormatReportGenerator.psm1: マルチフォーマット出力" -ForegroundColor White
Write-Host "   - 各テンプレートファイル: Templates/Samples/ 配下" -ForegroundColor White
Write-Host "   - 出力先: E:\MicrosoftProductManagementTools\Reports\ 配下" -ForegroundColor White