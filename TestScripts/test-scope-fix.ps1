# Get-ReportDataFromProvider 関数スコープ修正テスト

Write-Host "🔍 Get-ReportDataFromProvider 関数スコープ修正テスト開始" -ForegroundColor Cyan

# モジュール読み込み
$modulePath = Join-Path $PSScriptRoot "..\Scripts\Common"
Import-Module "$modulePath\RealM365DataProvider.psm1" -Force -DisableNameChecking -Global
Import-Module "$modulePath\HTMLTemplateEngine.psm1" -Force -DisableNameChecking -Global

# GuiApp_Enhanced.ps1と同じ方法でグローバル関数を定義
. {
    function global:Get-ReportDataFromProvider {
        param(
            [string]$DataType,
            [hashtable]$Parameters = @{}
        )
        
        try {
            # 常にリアルデータを取得（Microsoft 365接続状態は関数内で自動確認）
            switch ($DataType) {
                "Users" { return Get-M365AllUsers @Parameters }
                "LicenseAnalysis" { return Get-M365LicenseAnalysis @Parameters }
                "DailyReport" { return Get-M365DailyReport @Parameters }
                default { 
                    Write-Warning "未対応のデータタイプ: $DataType"
                    return @([PSCustomObject]@{ Message = "データタイプ '$DataType' は対応していません" })
                }
            }
        }
        catch {
            Write-Host "データ取得エラー: $($_.Exception.Message)" -ForegroundColor Red
            return @([PSCustomObject]@{ 
                Error = $_.Exception.Message
                DataType = $DataType
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            })
        }
    }
}

# 関数が正常に定義されているか確認
Write-Host "📋 関数定義確認中..." -ForegroundColor Yellow
if (Get-Command Get-ReportDataFromProvider -ErrorAction SilentlyContinue) {
    Write-Host "✅ Get-ReportDataFromProvider 関数が正常に定義されています" -ForegroundColor Green
    
    # 実際に関数を呼び出してテスト
    Write-Host "🧪 DailyReport データ取得テスト実行中..." -ForegroundColor Yellow
    try {
        $data = Get-ReportDataFromProvider -DataType "DailyReport"
        Write-Host "✅ DailyReport データ取得成功: $($data.Count) 件" -ForegroundColor Green
        Write-Host "📋 サンプルデータ: $($data[0].ServiceName)" -ForegroundColor Cyan
    } catch {
        Write-Host "❌ DailyReport データ取得エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Get-ReportDataFromProvider 関数が見つかりません" -ForegroundColor Red
}

Write-Host "🏁 スコープ修正テスト完了" -ForegroundColor Cyan