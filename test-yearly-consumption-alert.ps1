# Test script for Yearly Consumption Alert functionality
param(
    [int]$BudgetLimit = 5000000,
    [int]$AlertThreshold = 80
)

Write-Host "🚨 年間消費傾向アラート機能テストを開始します" -ForegroundColor Cyan
Write-Host "設定: 予算上限=¥$($BudgetLimit.ToString('N0')), 閾値=$AlertThreshold%" -ForegroundColor Yellow
Write-Host ""

try {
    # スクリプトパスの設定
    $scriptPath = Join-Path $PSScriptRoot "Scripts\EntraID\YearlyConsumptionAlert.ps1"
    
    if (-not (Test-Path $scriptPath)) {
        Write-Host "❌ スクリプトが見つかりません: $scriptPath" -ForegroundColor Red
        return
    }
    
    Write-Host "✅ スクリプトファイル確認: $scriptPath" -ForegroundColor Green
    
    # スクリプト読み込み
    . $scriptPath
    
    Write-Host "✅ スクリプト読み込み完了" -ForegroundColor Green
    
    # 関数実行
    Write-Host "⏳ 年間消費傾向アラート分析を実行中..." -ForegroundColor Cyan
    $result = Get-YearlyConsumptionAlert -BudgetLimit $BudgetLimit -AlertThreshold $AlertThreshold -ExportHTML -ExportCSV
    
    if ($result -and $result.Success) {
        Write-Host ""
        Write-Host "✅ 年間消費傾向アラート分析テスト成功" -ForegroundColor Green
        Write-Host ""
        Write-Host "📊 テスト結果サマリー:" -ForegroundColor Yellow
        Write-Host "現在ライセンス数: $($result.TotalLicenses)" -ForegroundColor Cyan
        Write-Host "年間予測消費: $($result.PredictedYearlyConsumption)" -ForegroundColor Yellow
        Write-Host "予算使用率: $($result.BudgetUtilization)%" -ForegroundColor $(if($result.BudgetUtilization -ge 100) { "Red" } elseif($result.BudgetUtilization -ge 90) { "Yellow" } else { "Green" })
        Write-Host "緊急アラート: $($result.CriticalAlerts)件" -ForegroundColor Red
        Write-Host "警告アラート: $($result.WarningAlerts)件" -ForegroundColor Yellow
        Write-Host ""
        
        if ($result.HTMLPath) {
            Write-Host "🌐 HTMLダッシュボード: $($result.HTMLPath)" -ForegroundColor Green
            if (Test-Path $result.HTMLPath) {
                Write-Host "   ✅ HTMLファイル生成確認済み" -ForegroundColor Green
            } else {
                Write-Host "   ❌ HTMLファイルが見つかりません" -ForegroundColor Red
            }
        }
        
        if ($result.CSVPaths -and $result.CSVPaths.Count -gt 0) {
            Write-Host "📄 CSVレポート数: $($result.CSVPaths.Count)ファイル" -ForegroundColor Green
            foreach ($csvPath in $result.CSVPaths) {
                if (Test-Path $csvPath) {
                    Write-Host "   ✅ $(Split-Path $csvPath -Leaf)" -ForegroundColor Green
                } else {
                    Write-Host "   ❌ $(Split-Path $csvPath -Leaf) が見つかりません" -ForegroundColor Red
                }
            }
        }
        
        Write-Host ""
        Write-Host "📈 アラート評価:" -ForegroundColor Yellow
        if ($result.CriticalAlerts -gt 0) {
            Write-Host "🚨 緊急対応が必要: $($result.CriticalAlerts)件の緊急アラート" -ForegroundColor Red
        }
        if ($result.WarningAlerts -gt 0) {
            Write-Host "⚠️ 監視強化推奨: $($result.WarningAlerts)件の警告アラート" -ForegroundColor Yellow
        }
        if ($result.BudgetUtilization -ge 100) {
            Write-Host "💰 予算オーバー警告: 年間予算を超過する予測" -ForegroundColor Red
        } elseif ($result.BudgetUtilization -ge 90) {
            Write-Host "⚠️ 予算警告: 年間予算の90%超過予測" -ForegroundColor Yellow
        } else {
            Write-Host "✅ 予算内: 予算使用率は正常範囲内" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "🎉 年間消費傾向アラート機能テスト完了" -ForegroundColor Green
        return $result
    } else {
        Write-Host ""
        Write-Host "❌ 年間消費傾向アラート分析テスト失敗" -ForegroundColor Red
        if ($result -and $result.Error) {
            Write-Host "エラー詳細: $($result.Error)" -ForegroundColor Red
        } else {
            Write-Host "エラー詳細: 結果オブジェクトが取得できませんでした" -ForegroundColor Red
        }
        return @{ Success = $false; Error = "テスト実行失敗" }
    }
}
catch {
    Write-Host ""
    Write-Host "❌ 年間消費傾向アラート機能テスト例外エラー" -ForegroundColor Red
    Write-Host "例外詳細: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "発生場所: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    return @{ Success = $false; Error = $_.Exception.Message }
}