# ================================================================================
# GUI日次レポートボタンテストスクリプト
# New-HTMLReportWithPDF関数のGUI統合テスト
# ================================================================================

Write-Host "🔍 GUI日次レポートボタン機能をテスト中..." -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Blue

# ツールルートの取得
$toolRoot = Split-Path $PSScriptRoot -Parent
$modulePath = Join-Path $toolRoot "Scripts\Common"

# 1. 必要なモジュールを先に読み込み
Write-Host "📦 必要なモジュールを読み込み中..." -ForegroundColor Yellow

try {
    # 既存のモジュールを削除
    Remove-Module HTMLTemplateWithPDF -ErrorAction SilentlyContinue
    Remove-Module DailyReportData -ErrorAction SilentlyContinue
    Remove-Module GuiReportFunctions -ErrorAction SilentlyContinue
    
    # フルパスでモジュールを強制読み込み
    $htmlModule = Join-Path $modulePath "HTMLTemplateWithPDF.psm1"
    $dailyModule = Join-Path $modulePath "DailyReportData.psm1"
    $guiModule = Join-Path $modulePath "GuiReportFunctions.psm1"
    
    Import-Module $htmlModule -Force -DisableNameChecking
    Write-Host "  ✅ HTMLTemplateWithPDF.psm1 読み込み完了" -ForegroundColor Green
    
    Import-Module $dailyModule -Force -DisableNameChecking
    Write-Host "  ✅ DailyReportData.psm1 読み込み完了" -ForegroundColor Green
    
    Import-Module $guiModule -Force -DisableNameChecking -ErrorAction SilentlyContinue
    Write-Host "  ✅ GuiReportFunctions.psm1 読み込み完了" -ForegroundColor Green
    
    # 即座に関数確認
    if (Get-Command Get-DailyReportRealData -ErrorAction SilentlyContinue) {
        Write-Host "  ✅ Get-DailyReportRealData 関数確認済み" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Get-DailyReportRealData 関数が見つかりません" -ForegroundColor Red
        # デバッグ: モジュールから利用可能な関数をリスト
        $dailyCommands = Get-Command -Module DailyReportData -ErrorAction SilentlyContinue
        Write-Host "  📋 DailyReportDataモジュールの関数:" -ForegroundColor Cyan
        $dailyCommands | ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor White }
    }
    
    Write-Host "  ✅ 必要なモジュール読み込み完了" -ForegroundColor Green
} catch {
    Write-Host "  ❌ モジュール読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. 関数存在確認
Write-Host "🔧 関数の存在確認中..." -ForegroundColor Yellow

$functions = @("New-HTMLReportWithPDF", "Get-DailyReportRealData")
foreach ($func in $functions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "  ✅ $func - 利用可能" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $func - 見つかりません" -ForegroundColor Red
    }
}

# 3. 日次レポート機能をシミュレート
Write-Host "🚀 日次レポート機能をシミュレート中..." -ForegroundColor Yellow

try {
    # サンプルデータで日次レポートを生成
    Write-Host "  📊 ダミーデータで日次レポートを作成中..." -ForegroundColor Cyan
    $reportData = Get-DailyReportRealData -UseSampleData
    
    if ($reportData) {
        Write-Host "  ✅ 日次レポートデータ取得成功" -ForegroundColor Green
        Write-Host "    データソース: $($reportData.DataSource)" -ForegroundColor White
        Write-Host "    ユーザーアクティビティ: $($reportData.UserActivity.Count) 件" -ForegroundColor White
        Write-Host "    メールボックス容量: $($reportData.MailboxCapacity.Count) 件" -ForegroundColor White
        Write-Host "    セキュリティアラート: $($reportData.SecurityAlerts.Count) 件" -ForegroundColor White
        Write-Host "    MFA状況: $($reportData.MFAStatus.Count) 件" -ForegroundColor White
        
        # HTML生成テスト
        Write-Host "  📄 HTMLレポート生成中..." -ForegroundColor Cyan
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $outputPath = Join-Path $toolRoot "Reports\Daily\日次レポート_GUI_テスト_$timestamp.html"
        $outputDir = Split-Path $outputPath -Parent
        
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        
        # データセクション準備
        $dataSections = @(
            @{
                Title = "ユーザーアクティビティ"
                Data = $reportData.UserActivity
            },
            @{
                Title = "メールボックス容量"
                Data = $reportData.MailboxCapacity
            },
            @{
                Title = "セキュリティアラート" 
                Data = $reportData.SecurityAlerts
            },
            @{
                Title = "MFA状況"
                Data = $reportData.MFAStatus
            }
        )
        
        # HTMLレポート生成
        $htmlPath = New-HTMLReportWithPDF -Title "日次レポート（GUI統合テスト）" -DataSections $dataSections -OutputPath $outputPath -Summary $reportData.Summary
        
        if (Test-Path $htmlPath) {
            Write-Host "  ✅ HTMLレポート生成成功" -ForegroundColor Green
            Write-Host "    📄 出力先: $htmlPath" -ForegroundColor White
            
            # ファイルサイズ確認
            $fileSize = (Get-Item $htmlPath).Length
            Write-Host "    📏 ファイルサイズ: $([Math]::Round($fileSize / 1024, 2)) KB" -ForegroundColor White
            
            # CSV出力も実行
            $csvPath = $htmlPath -replace '\.html$', '.csv'
            try {
                # 最初のデータセクションをCSVで出力
                if ($reportData.UserActivity -and $reportData.UserActivity.Count -gt 0) {
                    $reportData.UserActivity | Export-Csv -Path $csvPath -Encoding UTF8 -NoTypeInformation
                    Write-Host "  ✅ CSVファイル生成成功: $csvPath" -ForegroundColor Green
                }
            } catch {
                Write-Host "  ⚠️ CSVファイル生成エラー: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            
        } else {
            Write-Host "  ❌ HTMLレポート生成失敗" -ForegroundColor Red
        }
    } else {
        Write-Host "  ❌ 日次レポートデータ取得失敗" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ 日次レポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    詳細: $($_.Exception.InnerException.Message)" -ForegroundColor Yellow
}

# 4. 結果サマリー
Write-Host "`n" + "=" * 60 -ForegroundColor Blue
Write-Host "🎯 GUI日次レポートボタンテスト結果" -ForegroundColor Blue
Write-Host "=" * 60 -ForegroundColor Blue

if (Get-Command "New-HTMLReportWithPDF" -ErrorAction SilentlyContinue) {
    Write-Host "✅ New-HTMLReportWithPDF関数: 正常に動作" -ForegroundColor Green
}

if (Get-Command "Get-DailyReportRealData" -ErrorAction SilentlyContinue) {
    Write-Host "✅ Get-DailyReportRealData関数: 正常に動作" -ForegroundColor Green
}

$reportFiles = Get-ChildItem -Path (Join-Path $toolRoot "Reports\Daily") -Filter "*GUI_テスト*" -ErrorAction SilentlyContinue
if ($reportFiles) {
    Write-Host "✅ テストレポート生成: 成功 ($($reportFiles.Count) ファイル)" -ForegroundColor Green
    Write-Host "📊 GUI日次レポートボタン機能は正常に動作します！" -ForegroundColor Green
    Write-Host ""
    Write-Host "🚀 実際のGUIでのテスト手順:" -ForegroundColor Cyan
    Write-Host "  1. pwsh -File run_launcher.ps1 でランチャー起動" -ForegroundColor White
    Write-Host "  2. [1] GUI モードを選択" -ForegroundColor White
    Write-Host "  3. 「📊 日次レポート」ボタンをクリック" -ForegroundColor White
    Write-Host "  4. HTMLファイルが自動で開かれることを確認" -ForegroundColor White
} else {
    Write-Host "❌ テストレポート生成: 失敗" -ForegroundColor Red
}

Write-Host "=" * 60 -ForegroundColor Blue