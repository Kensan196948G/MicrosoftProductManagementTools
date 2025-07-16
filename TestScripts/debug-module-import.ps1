# モジュールインポートデバッグ
$modulePath = "E:\MicrosoftProductManagementTools\Scripts\Common\DailyReportData.psm1"

Write-Host "モジュールパスチェック: $modulePath"
Write-Host "ファイル存在: $(Test-Path $modulePath)"

try {
    Import-Module $modulePath -Force -Verbose
    Write-Host "インポート成功"
    
    $commands = Get-Command -Module DailyReportData
    Write-Host "エクスポートされた関数:"
    $commands | ForEach-Object { Write-Host "  - $($_.Name)" }
    
    if (Get-Command Get-DailyReportRealData -ErrorAction SilentlyContinue) {
        Write-Host "✅ Get-DailyReportRealData 利用可能"
    } else {
        Write-Host "❌ Get-DailyReportRealData 見つからない"
    }
} catch {
    Write-Host "インポートエラー: $($_.Exception.Message)"
}