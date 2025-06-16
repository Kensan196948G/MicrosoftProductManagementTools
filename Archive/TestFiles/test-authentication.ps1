# ================================================================================
# Microsoft 365認証テストスクリプト
# ================================================================================

# 必要なモジュールのインポート
try {
    Import-Module "$PSScriptRoot\Scripts\Common\Common.psm1" -Force
    Import-Module "$PSScriptRoot\Scripts\Common\Authentication.psm1" -Force
    Import-Module "$PSScriptRoot\Scripts\Common\Logging.psm1" -Force
    Write-Host "モジュールのインポートが完了しました" -ForegroundColor Green
}
catch {
    Write-Host "モジュールインポートエラー: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 設定ファイルの読み込み
try {
    $config = Initialize-ManagementTools
    if (-not $config) {
        throw "設定ファイルの読み込みに失敗しました"
    }
    Write-Host "設定ファイルを正常に読み込みました" -ForegroundColor Green
    Write-Host "TenantId: $($config.EntraID.TenantId)" -ForegroundColor Cyan
    Write-Host "ClientId: $($config.EntraID.ClientId)" -ForegroundColor Cyan
    Write-Host "CertificateThumbprint: $($config.EntraID.CertificateThumbprint)" -ForegroundColor Cyan
}
catch {
    Write-Host "設定読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# システム要件チェック
Write-Host "`n=== システム要件チェック ===" -ForegroundColor Yellow
$requirements = Test-SystemRequirements
if ($requirements.Overall) {
    Write-Host "システム要件: ✓ 合格" -ForegroundColor Green
}
else {
    Write-Host "システム要件: ✗ 一部要件を満たしていません" -ForegroundColor Yellow
    Write-Host "PowerShell: $($requirements.PowerShellOK)" -ForegroundColor Cyan
    Write-Host "モジュール: $($requirements.ModulesOK)" -ForegroundColor Cyan
    Write-Host "OS: $($requirements.OSOK)" -ForegroundColor Cyan
}

# Microsoft Graph認証テスト
Write-Host "`n=== Microsoft Graph認証テスト ===" -ForegroundColor Yellow
try {
    $graphResult = Connect-MicrosoftGraphService -Config $config
    if ($graphResult) {
        Write-Host "Microsoft Graph接続: ✓ 成功" -ForegroundColor Green
        
        # 接続情報表示
        $context = Get-MgContext
        if ($context) {
            Write-Host "テナントID: $($context.TenantId)" -ForegroundColor Cyan
            Write-Host "アプリID: $($context.ClientId)" -ForegroundColor Cyan
            Write-Host "認証タイプ: $($context.AuthType)" -ForegroundColor Cyan
        }
    }
    else {
        Write-Host "Microsoft Graph接続: ✗ 失敗" -ForegroundColor Red
    }
}
catch {
    Write-Host "Microsoft Graph接続エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# Exchange Online認証テスト
Write-Host "`n=== Exchange Online認証テスト ===" -ForegroundColor Yellow
try {
    $exoResult = Connect-ExchangeOnlineService -Config $config
    if ($exoResult) {
        Write-Host "Exchange Online接続: ✓ 成功" -ForegroundColor Green
        
        # 接続セッション表示
        $session = Get-PSSession | Where-Object { $_.Name -like "*ExchangeOnline*" -and $_.State -eq "Opened" }
        if ($session) {
            Write-Host "セッション名: $($session.Name)" -ForegroundColor Cyan
            Write-Host "セッション状態: $($session.State)" -ForegroundColor Cyan
        }
    }
    else {
        Write-Host "Exchange Online接続: ✗ 失敗" -ForegroundColor Red
    }
}
catch {
    Write-Host "Exchange Online接続エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 認証状態サマリー
Write-Host "`n=== 認証状態サマリー ===" -ForegroundColor Yellow
$authInfo = Get-AuthenticationInfo
Write-Host "接続済みサービス: $($authInfo.ConnectedServices -join ', ')" -ForegroundColor Cyan
if ($authInfo.Errors -and $authInfo.Errors.Count -gt 0) {
    Write-Host "エラー:" -ForegroundColor Red
    foreach ($error in $authInfo.Errors) {
        Write-Host "  - $error" -ForegroundColor Red
    }
}

Write-Host "`n認証テスト完了" -ForegroundColor Green