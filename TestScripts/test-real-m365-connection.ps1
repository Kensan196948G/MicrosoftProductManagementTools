# Microsoft 365 実データ接続テスト

Write-Host "🔍 Microsoft 365 実データ接続テスト開始" -ForegroundColor Cyan
Write-Host "="*80 -ForegroundColor Cyan

# モジュール読み込み
$modulePath = Join-Path $PSScriptRoot "..\Scripts\Common"
Import-Module "$modulePath\RealM365DataProvider.psm1" -Force -DisableNameChecking -Global
Import-Module "$modulePath\DataSourceVisualization.psm1" -Force -DisableNameChecking -Global

# 接続状況の確認
Write-Host "📋 現在の接続状況:" -ForegroundColor Yellow
Show-ConnectionStatus

# Microsoft 365 接続の試行
Write-Host "`n🔐 Microsoft 365 接続を試行中..." -ForegroundColor Yellow
try {
    # Connect-M365Services関数を呼び出し
    $connectionResult = Connect-M365Services
    
    if ($connectionResult.GraphConnected) {
        Write-Host "✅ Microsoft Graph 接続成功" -ForegroundColor Green
        
        # 接続後の状況確認
        Write-Host "`n📋 接続後の状況:" -ForegroundColor Yellow
        Show-ConnectionStatus
        
        # 実際のユーザーデータを取得
        Write-Host "`n👥 実際のユーザーデータを取得中..." -ForegroundColor Cyan
        $users = Get-M365AllUsers
        
        if ($users.Count -gt 0) {
            Write-Host "✅ 実ユーザーデータ取得成功: $($users.Count) 件" -ForegroundColor Green
            
            # データサマリーを表示
            Show-DataSummary -Data $users -DataType "Users" -Source "Microsoft 365 API (実データ)"
            
            # 日次レポートも実データで取得
            Write-Host "`n📅 実データで日次レポートを取得中..." -ForegroundColor Cyan
            $dailyReport = Get-M365DailyReport
            
            if ($dailyReport.Count -gt 0) {
                Write-Host "✅ 実データ日次レポート取得成功: $($dailyReport.Count) 件" -ForegroundColor Green
                
                # 実データかどうかの品質チェック
                $qualityCheck = Test-RealDataQuality -Data $dailyReport -DataType "DailyReport"
                Write-Host "`n🔍 データ品質評価:" -ForegroundColor Yellow
                Write-Host "   信頼度: $($qualityCheck.Confidence)%" -ForegroundColor White
                Write-Host "   判定理由: $($qualityCheck.Reason)" -ForegroundColor Gray
                Write-Host "   実データ判定: $(if ($qualityCheck.IsRealData) { '✅ 実データ' } else { '⚠️ 推定/フォールバック' })" -ForegroundColor $(if ($qualityCheck.IsRealData) { 'Green' } else { 'Yellow' })
            } else {
                Write-Host "❌ 日次レポートの取得に失敗しました" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ ユーザーデータの取得に失敗しました" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Microsoft Graph 接続に失敗しました" -ForegroundColor Red
        Write-Host "理由: $($connectionResult.Error)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ 接続エラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🏁 Microsoft 365 実データ接続テスト完了" -ForegroundColor Cyan
Write-Host "="*80 -ForegroundColor Cyan