# シンプル認証確認スクリプト
# 設定ファイルの内容と実際の認証状況を確認

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                     Microsoft 365 認証設定確認                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""

# 設定ファイル読み込み
$localConfigPath = "Config/appsettings.local.json"
$baseConfigPath = "Config/appsettings.json"

if (Test-Path $localConfigPath) {
    $config = Get-Content $localConfigPath -Raw | ConvertFrom-Json
    Write-Host "📁 使用設定ファイル: appsettings.local.json" -ForegroundColor Green
}
elseif (Test-Path $baseConfigPath) {
    $config = Get-Content $baseConfigPath -Raw | ConvertFrom-Json
    Write-Host "📁 使用設定ファイル: appsettings.json" -ForegroundColor Yellow
}
else {
    Write-Host "❌ 設定ファイルが見つかりません" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Microsoft Graph 設定 ===" -ForegroundColor Yellow
$graphConfig = $config.EntraID

Write-Host "  TenantId: " -NoNewline
if ($graphConfig.TenantId -and $graphConfig.TenantId -notlike "*YOUR-*-HERE*") {
    Write-Host "✅ 設定済み ($($graphConfig.TenantId))" -ForegroundColor Green
} else {
    Write-Host "❌ 未設定" -ForegroundColor Red
}

Write-Host "  ClientId: " -NoNewline
if ($graphConfig.ClientId -and $graphConfig.ClientId -notlike "*YOUR-*-HERE*") {
    Write-Host "✅ 設定済み ($($graphConfig.ClientId))" -ForegroundColor Green
} else {
    Write-Host "❌ 未設定" -ForegroundColor Red
}

Write-Host "  ClientSecret: " -NoNewline
if ($graphConfig.ClientSecret -and $graphConfig.ClientSecret -notlike "*YOUR-*-HERE*") {
    Write-Host "✅ 設定済み" -ForegroundColor Green
} else {
    Write-Host "❌ 未設定" -ForegroundColor Red
}

Write-Host "  CertificateThumbprint: " -NoNewline
if ($graphConfig.CertificateThumbprint -and $graphConfig.CertificateThumbprint -notlike "*YOUR-*-HERE*") {
    Write-Host "✅ 設定済み ($($graphConfig.CertificateThumbprint))" -ForegroundColor Green
} else {
    Write-Host "❌ 未設定" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Exchange Online 設定 ===" -ForegroundColor Yellow
$exoConfig = $config.ExchangeOnline

Write-Host "  Organization: " -NoNewline
if ($exoConfig.Organization -and $exoConfig.Organization -notlike "*your-tenant*") {
    Write-Host "✅ 設定済み ($($exoConfig.Organization))" -ForegroundColor Green
} else {
    Write-Host "❌ 未設定" -ForegroundColor Red
}

Write-Host "  AppId: " -NoNewline
if ($exoConfig.AppId -and $exoConfig.AppId -notlike "*YOUR-*-HERE*") {
    Write-Host "✅ 設定済み ($($exoConfig.AppId))" -ForegroundColor Green
} else {
    Write-Host "❌ 未設定" -ForegroundColor Red
}

Write-Host "  CertificateThumbprint: " -NoNewline
if ($exoConfig.CertificateThumbprint -and $exoConfig.CertificateThumbprint -notlike "*YOUR-*-HERE*") {
    Write-Host "✅ 設定済み ($($exoConfig.CertificateThumbprint))" -ForegroundColor Green
} else {
    Write-Host "❌ 未設定" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== 環境情報 ===" -ForegroundColor Yellow
Write-Host "  PowerShell版: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))" -ForegroundColor Gray
Write-Host "  プラットフォーム: $($PSVersionTable.Platform)" -ForegroundColor Gray
Write-Host "  OS: $($PSVersionTable.OS)" -ForegroundColor Gray

if ($env:WSL_DISTRO_NAME) {
    Write-Host "  WSL環境: $($env:WSL_DISTRO_NAME)" -ForegroundColor Yellow
    Write-Host "    💡 Exchange Online認証にはWindows環境が必要です" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== 推奨アクション ===" -ForegroundColor Cyan

# Microsoft Graph チェック
$graphReady = ($graphConfig.TenantId -and $graphConfig.TenantId -notlike "*YOUR-*-HERE*") -and
              ($graphConfig.ClientId -and $graphConfig.ClientId -notlike "*YOUR-*-HERE*") -and
              (($graphConfig.ClientSecret -and $graphConfig.ClientSecret -notlike "*YOUR-*-HERE*") -or
               ($graphConfig.CertificateThumbprint -and $graphConfig.CertificateThumbprint -notlike "*YOUR-*-HERE*"))

if ($graphReady) {
    Write-Host "✅ Microsoft Graph: 認証テスト可能" -ForegroundColor Green
    Write-Host "   コマンド: .\TestScripts\test-auth.ps1" -ForegroundColor Cyan
} else {
    Write-Host "❌ Microsoft Graph: 設定が不完全" -ForegroundColor Red
}

# Exchange Online チェック
$exoReady = ($exoConfig.Organization -and $exoConfig.Organization -notlike "*your-tenant*") -and
            ($exoConfig.AppId -and $exoConfig.AppId -notlike "*YOUR-*-HERE*") -and
            ($exoConfig.CertificateThumbprint -and $exoConfig.CertificateThumbprint -notlike "*YOUR-*-HERE*")

if ($exoReady) {
    if ($env:WSL_DISTRO_NAME) {
        Write-Host "⚠️  Exchange Online: Windows環境で認証テスト可能" -ForegroundColor Yellow
        Write-Host "   WSL2では証明書ストア制限のため認証不可" -ForegroundColor Yellow
    } else {
        Write-Host "✅ Exchange Online: 認証テスト可能" -ForegroundColor Green
        Write-Host "   コマンド: .\TestScripts\test-auth-windows.ps1" -ForegroundColor Cyan
    }
} else {
    Write-Host "❌ Exchange Online: 設定が不完全" -ForegroundColor Red
}

Write-Host ""
Write-Host "📚 利用可能な認証テストスクリプト:" -ForegroundColor White
Write-Host "  - test-auth.ps1           : Microsoft Graph認証テスト" -ForegroundColor Gray
Write-Host "  - test-exchange-auth.ps1  : Exchange Online認証テスト" -ForegroundColor Gray
Write-Host "  - test-auth-windows.ps1   : Windows環境統合テスト" -ForegroundColor Gray
Write-Host "  - test-auth-integrated.ps1: WSL2対応統合テスト" -ForegroundColor Gray

Write-Host ""
Read-Host "Enterキーを押して終了"