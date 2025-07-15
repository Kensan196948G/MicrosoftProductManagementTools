# Exchange Online設定デバッグスクリプト

Write-Host "Exchange Online設定デバッグ" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

# ローカル設定ファイルを読み込み
$localConfigPath = "Config/appsettings.local.json"
$baseConfigPath = "Config/appsettings.json"

if (Test-Path $localConfigPath) {
    Write-Host "ローカル設定ファイルを使用: $localConfigPath" -ForegroundColor Green
    $config = Get-Content $localConfigPath -Raw | ConvertFrom-Json
}
elseif (Test-Path $baseConfigPath) {
    Write-Host "ベース設定ファイルを使用: $baseConfigPath" -ForegroundColor Yellow
    $config = Get-Content $baseConfigPath -Raw | ConvertFrom-Json
}
else {
    Write-Host "設定ファイルが見つかりません" -ForegroundColor Red
    exit 1
}

$exoConfig = $config.ExchangeOnline

Write-Host ""
Write-Host "Exchange Online設定値:" -ForegroundColor White
Write-Host "  Organization: '$($exoConfig.Organization)'" -ForegroundColor Gray
Write-Host "  AppId: '$($exoConfig.AppId)'" -ForegroundColor Gray
Write-Host "  CertificateThumbprint: '$($exoConfig.CertificateThumbprint)'" -ForegroundColor Gray
Write-Host "  CertificatePassword: '$($exoConfig.CertificatePassword)'" -ForegroundColor Gray
Write-Host ""

Write-Host "判定条件チェック:" -ForegroundColor White
Write-Host "  CertificateThumbprint 存在: $($exoConfig.CertificateThumbprint -ne $null -and $exoConfig.CertificateThumbprint -ne '')" -ForegroundColor Gray
Write-Host "  CertificateThumbprint プレースホルダーでない: $($exoConfig.CertificateThumbprint -notlike '*YOUR-*-HERE*')" -ForegroundColor Gray
Write-Host "  Organization 存在: $($exoConfig.Organization -ne $null -and $exoConfig.Organization -ne '')" -ForegroundColor Gray
Write-Host "  AppId 存在: $($exoConfig.AppId -ne $null -and $exoConfig.AppId -ne '')" -ForegroundColor Gray
Write-Host ""

# 総合判定
$hasValidConfig = ($exoConfig.CertificateThumbprint -and 
                   $exoConfig.CertificateThumbprint -notlike "*YOUR-*-HERE*" -and 
                   $exoConfig.Organization -and 
                   $exoConfig.AppId)

Write-Host "総合判定: $hasValidConfig" -ForegroundColor $(if ($hasValidConfig) { "Green" } else { "Red" })

if ($hasValidConfig) {
    Write-Host "✅ Exchange Online設定は正常です" -ForegroundColor Green
} else {
    Write-Host "❌ Exchange Online設定に問題があります" -ForegroundColor Red
    
    if (-not $exoConfig.CertificateThumbprint) {
        Write-Host "  - CertificateThumbprint が未設定" -ForegroundColor Red
    }
    if ($exoConfig.CertificateThumbprint -like "*YOUR-*-HERE*") {
        Write-Host "  - CertificateThumbprint がプレースホルダー" -ForegroundColor Red
    }
    if (-not $exoConfig.Organization) {
        Write-Host "  - Organization が未設定" -ForegroundColor Red
    }
    if (-not $exoConfig.AppId) {
        Write-Host "  - AppId が未設定" -ForegroundColor Red
    }
}