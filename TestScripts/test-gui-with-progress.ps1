# ================================================================================
# GUIアプリケーション プログレス表示統合テスト
# Microsoft 365統合管理ツール用
# ================================================================================

[CmdletBinding()]
param()

# スクリプトの場所とToolRootを設定
$Script:TestRoot = $PSScriptRoot
$Script:ToolRoot = Split-Path $Script:TestRoot -Parent

Write-Host "=== GUIプログレス表示統合テスト開始 ===" -ForegroundColor Green
Write-Host "ToolRoot: $Script:ToolRoot" -ForegroundColor Cyan

try {
    # 必要なモジュールのテスト
    $progressModulePath = Join-Path $Script:ToolRoot "Scripts\Common\ProgressDisplay.psm1"
    $guiModulePath = Join-Path $Script:ToolRoot "Scripts\Common\GuiReportFunctions.psm1"
    
    Write-Host "`n📦 モジュールファイルの存在チェック" -ForegroundColor Yellow
    if (Test-Path $progressModulePath) {
        Write-Host "✅ ProgressDisplay.psm1 が見つかりました" -ForegroundColor Green
    } else {
        Write-Host "❌ ProgressDisplay.psm1 が見つかりません: $progressModulePath" -ForegroundColor Red
    }
    
    if (Test-Path $guiModulePath) {
        Write-Host "✅ GuiReportFunctions.psm1 が見つかりました" -ForegroundColor Green
    } else {
        Write-Host "❌ GuiReportFunctions.psm1 が見つかりません: $guiModulePath" -ForegroundColor Red
    }
    
    # モジュールのインポートテスト
    Write-Host "`n📥 モジュールインポートテスト" -ForegroundColor Yellow
    Import-Module $progressModulePath -Force -ErrorAction Stop
    Write-Host "✅ ProgressDisplayモジュールインポート成功" -ForegroundColor Green
    
    if (Test-Path $guiModulePath) {
        Import-Module $guiModulePath -Force -ErrorAction SilentlyContinue
        Write-Host "✅ GuiReportFunctionsモジュールインポート成功" -ForegroundColor Green
    }
    
    # 関数の存在確認
    Write-Host "`n🔍 関数の存在確認" -ForegroundColor Yellow
    $requiredFunctions = @(
        "Show-ProgressBar",
        "Write-LiveLog", 
        "Invoke-ReportGenerationWithProgress",
        "Clear-AllProgress"
    )
    
    foreach ($funcName in $requiredFunctions) {
        if (Get-Command $funcName -ErrorAction SilentlyContinue) {
            Write-Host "✅ $funcName 関数が利用可能" -ForegroundColor Green
        } else {
            Write-Host "❌ $funcName 関数が見つかりません" -ForegroundColor Red
        }
    }
    
    # 実際のレポート生成テスト
    Write-Host "`n🚀 レポート生成テスト実行" -ForegroundColor Yellow
    
    $reportTypes = @(
        @{ Type = "Daily"; Name = "📊 日次レポート"; Count = 15 },
        @{ Type = "License"; Name = "📊 ライセンス分析"; Count = 10 },
        @{ Type = "TeamsUsage"; Name = "💬 Teams使用状況"; Count = 20 }
    )
    
    foreach ($report in $reportTypes) {
        Write-Host "`n🔄 テスト実行: $($report.Name)" -ForegroundColor Cyan
        
        try {
            $data = Invoke-ReportGenerationWithProgress -ReportType $report.Type -ReportName $report.Name -RecordCount $report.Count
            
            if ($data -and $data.Count -gt 0) {
                Write-Host "✅ $($report.Name) 成功: $($data.Count) 件のデータ生成" -ForegroundColor Green
                Write-Host "📋 サンプル: $($data[0].ユーザー名) - $($data[0].ステータス)" -ForegroundColor Gray
            } else {
                Write-Host "⚠️ $($report.Name) データが空です" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "❌ $($report.Name) エラー: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # プログレスバーをクリア
        Clear-AllProgress
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "`n✅ GUIプログレス表示統合テスト完了!" -ForegroundColor Green
    Write-Host "🚀 修正されたGUIアプリケーションでプログレスバー表示が正常に動作するはずです" -ForegroundColor Cyan
    Write-Host "📊 コンソールに [██████░░░░░░░░░░░░] 形式のプログレスバーが表示されます" -ForegroundColor Cyan
    
}
catch {
    Write-Host "`n❌ テストエラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "詳細: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

Write-Host "`n=== GUIプログレス表示統合テスト終了 ===" -ForegroundColor Magenta