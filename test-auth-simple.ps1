# ================================================================================
# Microsoft 365統合管理ツール - 簡単認証テスト
# test-auth-simple.ps1
# 最小限の依存関係で認証をテスト
# ================================================================================

param(
    [Parameter(Mandatory = $false)]
    [switch]$UseCurrentConfig = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$DetailedOutput = $false
)

function Test-CertificateAccess {
    param(
        [string]$CertPath,
        [string]$Password
    )
    
    try {
        Write-Host "🔐 証明書ファイルアクセステスト..." -ForegroundColor Yellow
        
        if (-not (Test-Path $CertPath)) {
            Write-Host "❌ 証明書ファイルが見つかりません: $CertPath" -ForegroundColor Red
            return $false
        }
        
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath, $Password)
        
        if ($cert) {
            Write-Host "✅ 証明書読み込み成功" -ForegroundColor Green
            Write-Host "   Subject: $($cert.Subject)" -ForegroundColor Gray
            Write-Host "   Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
            Write-Host "   有効期限: $($cert.NotAfter)" -ForegroundColor Gray
            return $true
        }
    }
    catch {
        Write-Host "❌ 証明書読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-GraphConnection {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$CertPath,
        [string]$Password
    )
    
    try {
        Write-Host "🌐 Microsoft Graph接続テスト..." -ForegroundColor Yellow
        
        # Microsoft.Graph モジュール確認
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
            Write-Host "⚠️ Microsoft.Graph.Authentication モジュールがインストールされていません" -ForegroundColor Yellow
            Write-Host "   インストール: Install-Module Microsoft.Graph.Authentication -Force" -ForegroundColor Gray
            return $false
        }
        
        # 証明書での接続試行
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath, $Password)
        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Certificate $cert -NoWelcome
        
        # 接続確認
        $context = Get-MgContext
        if ($context) {
            Write-Host "✅ Microsoft Graph接続成功" -ForegroundColor Green
            Write-Host "   Tenant: $($context.TenantId)" -ForegroundColor Gray
            Write-Host "   Client: $($context.ClientId)" -ForegroundColor Gray
            Write-Host "   Scopes: $($context.Scopes -join ', ')" -ForegroundColor Gray
            
            # 簡単なクエリテスト
            try {
                $org = Get-MgOrganization
                Write-Host "   Organization: $($org.DisplayName)" -ForegroundColor Gray
            }
            catch {
                Write-Host "⚠️ 組織情報の取得に失敗しましたが、接続は成功しています" -ForegroundColor Yellow
            }
            
            Disconnect-MgGraph
            return $true
        }
    }
    catch {
        Write-Host "❌ Microsoft Graph接続エラー: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# メイン実行
Write-Host "🚀 Microsoft 365統合管理ツール - 認証テスト" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# 設定読み込み
$configPath = Join-Path $PSScriptRoot "Config\appsettings.json"
if (-not (Test-Path $configPath)) {
    Write-Host "❌ 設定ファイルが見つかりません: $configPath" -ForegroundColor Red
    exit 1
}

try {
    $config = Get-Content $configPath | ConvertFrom-Json
    $tenantId = $config.EntraID.TenantId
    $clientId = $config.EntraID.ClientId
    $certPath = Join-Path $PSScriptRoot $config.EntraID.CertificatePath
    $certPassword = $config.EntraID.CertificatePassword
    
    Write-Host "📋 設定情報:" -ForegroundColor Cyan
    Write-Host "   Tenant ID: $tenantId" -ForegroundColor Gray
    Write-Host "   Client ID: $clientId" -ForegroundColor Gray
    Write-Host "   証明書パス: $certPath" -ForegroundColor Gray
    Write-Host ""
    
    # 証明書テスト
    $certTest = Test-CertificateAccess -CertPath $certPath -Password $certPassword
    
    if ($certTest) {
        # Graph接続テスト
        $graphTest = Test-GraphConnection -TenantId $tenantId -ClientId $clientId -CertPath $certPath -Password $certPassword
        
        if ($graphTest) {
            Write-Host "`n🎉 すべてのテストが成功しました!" -ForegroundColor Green
        } else {
            Write-Host "`n⚠️ 証明書は有効ですが、Graph接続に問題があります" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n❌ 証明書に問題があります" -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ 設定ファイル読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}