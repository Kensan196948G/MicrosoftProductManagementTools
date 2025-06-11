# ================================================================================
# シンプル接続テストスクリプト（Linux対応）
# ================================================================================

# 設定読み込み
try {
    $configContent = Get-Content "Config/appsettings.json" | ConvertFrom-Json
    Write-Host "✓ 設定ファイル読み込み成功" -ForegroundColor Green
    Write-Host "  TenantId: $($configContent.EntraID.TenantId)" -ForegroundColor Cyan
    Write-Host "  ClientId: $($configContent.EntraID.ClientId)" -ForegroundColor Cyan
    Write-Host "  CertificateThumbprint: $($configContent.EntraID.CertificateThumbprint)" -ForegroundColor Cyan
}
catch {
    Write-Host "✗ 設定ファイル読み込み失敗: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# モジュール確認
Write-Host "`n=== モジュール確認 ===" -ForegroundColor Yellow

$modules = @("Microsoft.Graph", "ExchangeOnlineManagement")
foreach ($module in $modules) {
    try {
        $moduleInfo = Get-Module -ListAvailable -Name $module | Select-Object -First 1
        if ($moduleInfo) {
            Write-Host "✓ $module (Version: $($moduleInfo.Version))" -ForegroundColor Green
        }
        else {
            Write-Host "✗ $module - 未インストール" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "✗ $module - エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 証明書ファイル確認
Write-Host "`n=== 証明書ファイル確認 ===" -ForegroundColor Yellow

$certFiles = @(
    "Certificates/MiraiConstEXO.cer",
    "Certificates/MiraiConstEXO.pfx",
    "Certificates/MiraiConstEXO.crt"
)

foreach ($certFile in $certFiles) {
    if (Test-Path $certFile) {
        $fileInfo = Get-Item $certFile
        Write-Host "✓ $certFile (Size: $($fileInfo.Length) bytes, Modified: $($fileInfo.LastWriteTime))" -ForegroundColor Green
    }
    else {
        Write-Host "✗ $certFile - ファイルが見つかりません" -ForegroundColor Red
    }
}

# Microsoft Graph接続テスト（簡易版）
Write-Host "`n=== Microsoft Graph 接続テスト ===" -ForegroundColor Yellow

try {
    # モジュールインポート
    Import-Module Microsoft.Graph.Authentication -Force
    Write-Host "✓ Microsoft.Graph.Authentication モジュール読み込み成功" -ForegroundColor Green
    
    # 接続試行（エラーハンドリング付き）
    try {
        $connectParams = @{
            TenantId = $configContent.EntraID.TenantId
            ClientId = $configContent.EntraID.ClientId
            CertificateThumbprint = $configContent.EntraID.CertificateThumbprint
            NoWelcome = $true
        }
        
        Write-Host "接続パラメータ:" -ForegroundColor Cyan
        Write-Host "  TenantId: $($connectParams.TenantId)" -ForegroundColor Cyan
        Write-Host "  ClientId: $($connectParams.ClientId)" -ForegroundColor Cyan
        Write-Host "  CertificateThumbprint: $($connectParams.CertificateThumbprint)" -ForegroundColor Cyan
        
        Connect-MgGraph @connectParams -ErrorAction Stop
        
        # 接続確認
        $context = Get-MgContext
        if ($context) {
            Write-Host "✓ Microsoft Graph 接続成功" -ForegroundColor Green
            Write-Host "  接続済みテナント: $($context.TenantId)" -ForegroundColor Cyan
            Write-Host "  認証タイプ: $($context.AuthType)" -ForegroundColor Cyan
        }
        else {
            Write-Host "✗ Microsoft Graph 接続確認失敗" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "✗ Microsoft Graph 接続エラー: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  詳細: Linux環境では証明書認証に制限があります" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Microsoft Graph モジュールエラー: $($_.Exception.Message)" -ForegroundColor Red
}

# Exchange Online接続テスト（簡易版）
Write-Host "`n=== Exchange Online 接続テスト ===" -ForegroundColor Yellow

try {
    # モジュールインポート
    Import-Module ExchangeOnlineManagement -Force
    Write-Host "✓ ExchangeOnlineManagement モジュール読み込み成功" -ForegroundColor Green
    
    # 接続試行（エラーハンドリング付き）
    try {
        $exoParams = @{
            Organization = $configContent.ExchangeOnline.Organization
            AppId = $configContent.ExchangeOnline.AppId
            CertificateThumbprint = $configContent.ExchangeOnline.CertificateThumbprint
            ShowBanner = $false
            ShowProgress = $false
        }
        
        Write-Host "接続パラメータ:" -ForegroundColor Cyan
        Write-Host "  Organization: $($exoParams.Organization)" -ForegroundColor Cyan
        Write-Host "  AppId: $($exoParams.AppId)" -ForegroundColor Cyan
        Write-Host "  CertificateThumbprint: $($exoParams.CertificateThumbprint)" -ForegroundColor Cyan
        
        Connect-ExchangeOnline @exoParams -ErrorAction Stop
        
        # 接続確認
        $session = Get-PSSession | Where-Object { $_.Name -like "*ExchangeOnline*" -and $_.State -eq "Opened" }
        if ($session) {
            Write-Host "✓ Exchange Online 接続成功" -ForegroundColor Green
            Write-Host "  セッション: $($session.Name)" -ForegroundColor Cyan
            Write-Host "  状態: $($session.State)" -ForegroundColor Cyan
        }
        else {
            Write-Host "✗ Exchange Online セッション確認失敗" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "✗ Exchange Online 接続エラー: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  詳細: Linux環境では証明書認証に制限があります" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Exchange Online モジュールエラー: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== 接続テスト完了 ===" -ForegroundColor Green
Write-Host "注意: Linux/WSL環境では証明書ストアの制限により、証明書認証が正常に動作しない場合があります。" -ForegroundColor Yellow
Write-Host "Windows環境または適切に設定されたサーバー環境での実行を推奨します。" -ForegroundColor Yellow