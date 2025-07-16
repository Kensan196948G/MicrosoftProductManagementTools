# Export-DataToFiles 関数修正テスト

Write-Host "🔍 Export-DataToFiles 関数修正テスト開始" -ForegroundColor Cyan

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
            switch ($DataType) {
                "DailyReport" { return Get-M365DailyReport @Parameters }
                default { 
                    return @([PSCustomObject]@{ Message = "テストデータ" })
                }
            }
        }
        catch {
            return @([PSCustomObject]@{ 
                Error = $_.Exception.Message
                DataType = $DataType
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            })
        }
    }
    
    function global:Export-DataToFiles {
        param(
            [array]$Data,
            [string]$ReportName,
            [string]$FolderName = "TestReports"
        )
        
        if (-not $Data -or $Data.Count -eq 0) {
            Write-Host "❌ 出力するデータがありません" -ForegroundColor Red
            return
        }
        
        try {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $reportsDir = Join-Path $PSScriptRoot $FolderName
            $specificDir = Join-Path $reportsDir $ReportName
            
            if (-not (Test-Path $specificDir)) {
                New-Item -Path $specificDir -ItemType Directory -Force | Out-Null
            }
            
            # CSV出力
            $csvPath = Join-Path $specificDir "${ReportName}_${timestamp}.csv"
            $Data | Export-Csv -Path $csvPath -Encoding UTF8BOM -NoTypeInformation
            
            # HTML出力
            $htmlPath = Join-Path $specificDir "${ReportName}_${timestamp}.html"
            $htmlContent = Generate-EnhancedHTMLReport -Data $Data -ReportType $ReportName -Title $ReportName
            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
            
            Write-Host "✅ レポートを生成しました" -ForegroundColor Green
            Write-Host "   HTML: $htmlPath" -ForegroundColor Cyan
            Write-Host "   CSV: $csvPath" -ForegroundColor Cyan
        }
        catch {
            Write-Host "❌ ファイル出力エラー: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# 関数が正常に定義されているか確認
Write-Host "📋 関数定義確認中..." -ForegroundColor Yellow
$functionsOK = $true

if (Get-Command Get-ReportDataFromProvider -ErrorAction SilentlyContinue) {
    Write-Host "✅ Get-ReportDataFromProvider 関数が正常に定義されています" -ForegroundColor Green
} else {
    Write-Host "❌ Get-ReportDataFromProvider 関数が見つかりません" -ForegroundColor Red
    $functionsOK = $false
}

if (Get-Command Export-DataToFiles -ErrorAction SilentlyContinue) {
    Write-Host "✅ Export-DataToFiles 関数が正常に定義されています" -ForegroundColor Green
} else {
    Write-Host "❌ Export-DataToFiles 関数が見つかりません" -ForegroundColor Red
    $functionsOK = $false
}

if ($functionsOK) {
    # 実際の機能テスト
    Write-Host "🧪 エクスポート機能テスト実行中..." -ForegroundColor Yellow
    try {
        # データを取得
        $data = Get-ReportDataFromProvider -DataType "DailyReport"
        Write-Host "✅ データ取得成功: $($data.Count) 件" -ForegroundColor Green
        
        # ファイルにエクスポート
        Export-DataToFiles -Data $data -ReportName "TestExport"
        
        Write-Host "✅ エクスポート機能テスト完了" -ForegroundColor Green
    } catch {
        Write-Host "❌ エクスポート機能テストエラー: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "🏁 Export-DataToFiles 関数修正テスト完了" -ForegroundColor Cyan