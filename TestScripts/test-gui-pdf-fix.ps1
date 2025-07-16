# ================================================================================
# GUI PDF生成修正テスト
# Microsoft 365統合管理ツール用
# ================================================================================

[CmdletBinding()]
param()

# スクリプトの場所とToolRootを設定
$Script:TestRoot = $PSScriptRoot
$Script:ToolRoot = Split-Path $Script:TestRoot -Parent

Write-Host "=== GUI PDF生成修正テスト開始 ===" -ForegroundColor Green
Write-Host "ToolRoot: $Script:ToolRoot" -ForegroundColor Cyan

try {
    # GuiReportFunctions.psm1をインポート
    $guiModulePath = Join-Path $Script:ToolRoot "Scripts\Common\GuiReportFunctions.psm1"
    Write-Host "モジュールパス: $guiModulePath" -ForegroundColor Cyan
    
    if (-not (Test-Path $guiModulePath)) {
        throw "GuiReportFunctionsモジュールが見つかりません: $guiModulePath"
    }
    
    Import-Module $guiModulePath -Force -ErrorAction Stop
    Write-Host "✅ GuiReportFunctionsモジュールを読み込みました" -ForegroundColor Green
    
    # テスト用ダミーデータ
    $testData = @()
    for ($i = 1; $i -le 5; $i++) {
        $testData += [PSCustomObject]@{
            ID = $i
            ユーザー名 = "テストユーザー$i"
            部署 = "テスト部署"
            ステータス = "正常"
            作成日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    Write-Host "✅ テスト用ダミーデータを生成しました ($($testData.Count) 件)" -ForegroundColor Green
    
    # Export-GuiReport関数のテスト
    Write-Host "`n🔄 Export-GuiReport関数をテスト中..." -ForegroundColor Yellow
    
    $reportName = "GUI PDF生成テスト"
    $action = "TestPDF"
    
    try {
        Export-GuiReport -Data $testData -ReportName $reportName -Action $action
        Write-Host "✅ Export-GuiReport関数のテスト完了" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Export-GuiReport関数エラー: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "詳細: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    }
    
}
catch {
    Write-Host "`n❌ テストエラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "詳細: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

Write-Host "`n=== GUI PDF生成修正テスト終了 ===" -ForegroundColor Magenta