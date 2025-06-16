# Microsoft 365ライセンス分析の実行テストスクリプト
# 固定ファイル名での出力テスト

param(
    [ValidateSet("Dashboard", "Report", "Both")]
    [string]$TestType = "Both"
)

# 共通機能をインポート
Import-Module "$PSScriptRoot\Common\Common.psm1" -Force

try {
    Write-LogMessage "=== Microsoft 365ライセンス分析テスト実行 ===" -Level Info
    Write-LogMessage "テストタイプ: $TestType" -Level Info
    
    # 期待される出力ファイルパス
    $expectedHTML = "Reports/Monthly/License_Analysis_Dashboard_20250613_150236.html"
    $expectedCSV = "Reports/Monthly/Clean_Complete_User_License_Details.csv"
    
    Write-LogMessage "期待される出力ファイル:" -Level Info
    Write-LogMessage "  HTML: $expectedHTML" -Level Info
    Write-LogMessage "  CSV: $expectedCSV" -Level Info
    
    # 既存ファイルの確認
    $htmlPath = Join-Path $PSScriptRoot $expectedHTML
    $csvPath = Join-Path $PSScriptRoot $expectedCSV
    
    if (Test-Path $htmlPath) {
        Write-LogMessage "既存HTMLファイル確認: ✅" -Level Success
        $htmlInfo = Get-Item $htmlPath
        Write-LogMessage "  作成日時: $($htmlInfo.CreationTime)" -Level Info
        Write-LogMessage "  更新日時: $($htmlInfo.LastWriteTime)" -Level Info
        Write-LogMessage "  ファイルサイズ: $([math]::Round($htmlInfo.Length / 1KB, 2)) KB" -Level Info
    } else {
        Write-LogMessage "HTMLファイルが見つかりません: ❌" -Level Warning
    }
    
    if (Test-Path $csvPath) {
        Write-LogMessage "既存CSVファイル確認: ✅" -Level Success
        $csvInfo = Get-Item $csvPath
        Write-LogMessage "  作成日時: $($csvInfo.CreationTime)" -Level Info
        Write-LogMessage "  更新日時: $($csvInfo.LastWriteTime)" -Level Info
        Write-LogMessage "  ファイルサイズ: $([math]::Round($csvInfo.Length / 1KB, 2)) KB" -Level Info
        
        # CSVの行数をカウント
        $csvLines = Get-Content $csvPath | Measure-Object -Line
        Write-LogMessage "  レコード数: $($csvLines.Lines - 1) ユーザー（ヘッダー除く）" -Level Info
    } else {
        Write-LogMessage "CSVファイルが見つかりません: ❌" -Level Warning
    }
    
    # 統合実行スクリプトを呼び出し
    Write-LogMessage "ライセンス分析統合スクリプトを実行中..." -Level Info
    
    $invokeScript = Join-Path $PSScriptRoot "EXO\Invoke-LicenseAnalysis.ps1"
    $results = & $invokeScript -AnalysisType $TestType -UseTemplate
    
    # 結果の検証
    Write-LogMessage "=== 実行結果検証 ===" -Level Info
    
    if ($results.DashboardPath -and (Test-Path $results.DashboardPath)) {
        Write-LogMessage "ダッシュボード生成: ✅" -Level Success
        Write-LogMessage "  出力先: $($results.DashboardPath)" -Level Info
        
        # HTMLファイルの内容を簡易チェック
        $htmlContent = Get-Content $results.DashboardPath -Raw
        if ($htmlContent -match "License_Analysis_Dashboard_20250613_150236") {
            Write-LogMessage "  ファイル名一致: ✅" -Level Success
        }
        if ($htmlContent -match "総ライセンス数.*508") {
            Write-LogMessage "  統計情報正確: ✅" -Level Success
        }
        if ($htmlContent -match "使用中ライセンス.*157") {
            Write-LogMessage "  使用中ライセンス正確: ✅" -Level Success
        }
    } else {
        Write-LogMessage "ダッシュボード生成: ❌" -Level Error
    }
    
    if ($results.ReportPath -and (Test-Path $results.ReportPath)) {
        Write-LogMessage "CSVレポート生成: ✅" -Level Success
        Write-LogMessage "  出力先: $($results.ReportPath)" -Level Info
    } else {
        Write-LogMessage "CSVレポート生成: ❌" -Level Error
    }
    
    Write-LogMessage "=== テスト完了 ===" -Level Success
    
    return $results
}
catch {
    Write-LogMessage "テスト実行エラー: $_" -Level Error
    throw
}