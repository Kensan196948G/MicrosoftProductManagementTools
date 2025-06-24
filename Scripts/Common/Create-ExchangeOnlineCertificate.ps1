# ================================================================================
# Create-ExchangeOnlineCertificate.ps1
# Exchange Online PowerShell用証明書作成スクリプト
# ================================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$CertificateName = "ExchangeOnlineApp",
    
    [Parameter(Mandatory = $false)]
    [string]$OrganizationName = "未来建設株式会社",
    
    [Parameter(Mandatory = $false)]
    [int]$ValidityYears = 2,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ""
)

# 管理者権限確認
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "このスクリプトは管理者権限で実行してください"
    exit 1
}

Write-Host "🔐 Exchange Online PowerShell用証明書を作成します" -ForegroundColor Green
Write-Host "組織名: $OrganizationName" -ForegroundColor Yellow
Write-Host "有効期間: $ValidityYears 年" -ForegroundColor Yellow

# 出力ディレクトリ設定と作成
if ([string]::IsNullOrEmpty($OutputPath)) {
    # 相対パスでプロジェクトのCertificatesディレクトリを使用
    $OutputPath = Join-Path $PSScriptRoot "..\..\Certificates"
}

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "📁 証明書保存ディレクトリを作成: $OutputPath" -ForegroundColor Green
}

try {
    # 証明書作成
    $cert = New-SelfSignedCertificate -Subject "CN=$CertificateName" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy Exportable `
        -KeySpec Signature `
        -KeyLength 2048 `
        -KeyAlgorithm RSA `
        -HashAlgorithm SHA256 `
        -NotAfter (Get-Date).AddYears($ValidityYears) `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")
    
    Write-Host "✅ 証明書作成完了" -ForegroundColor Green
    Write-Host "拇印: $($cert.Thumbprint)" -ForegroundColor Cyan
    Write-Host "件名: $($cert.Subject)" -ForegroundColor Cyan
    Write-Host "有効期限: $($cert.NotAfter)" -ForegroundColor Cyan
    
    # CERファイル（公開鍵）エクスポート
    $cerPath = Join-Path $OutputPath "$CertificateName.cer"
    Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null
    Write-Host "📄 CERファイル出力: $cerPath" -ForegroundColor Green
    
    # PFXファイル（秘密鍵付き）エクスポート
    $pfxPassword = Read-Host -AsSecureString -Prompt "PFXファイル用パスワードを設定してください"
    $pfxPath = Join-Path $OutputPath "$CertificateName.pfx"
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $pfxPassword | Out-Null
    Write-Host "🔐 PFXファイル出力: $pfxPath" -ForegroundColor Green
    
    # Azure AD用設定情報表示
    Write-Host "`n" -NoNewline
    Write-Host "📋 Azure ADアプリケーション設定情報:" -ForegroundColor Yellow
    Write-Host "======================================" -ForegroundColor Yellow
    Write-Host "証明書拇印: $($cert.Thumbprint)" -ForegroundColor White
    Write-Host "証明書ファイル: $cerPath" -ForegroundColor White
    Write-Host "有効期限: $($cert.NotAfter.ToString('yyyy/M/d'))" -ForegroundColor White
    
    # appsettings.json用設定
    Write-Host "`n" -NoNewline
    Write-Host "⚙️  appsettings.json設定:" -ForegroundColor Yellow
    Write-Host "=========================" -ForegroundColor Yellow
    Write-Host '"CertificateThumbprint": "' -NoNewline -ForegroundColor White
    Write-Host $cert.Thumbprint -NoNewline -ForegroundColor Cyan
    Write-Host '"' -ForegroundColor White
    
    # 次のステップ案内
    Write-Host "`n" -NoNewline
    Write-Host "📝 次のステップ:" -ForegroundColor Yellow
    Write-Host "===============" -ForegroundColor Yellow
    Write-Host "1. Azure ADでアプリケーション登録を作成または更新" -ForegroundColor White
    Write-Host "2. CERファイル ($cerPath) をアップロード" -ForegroundColor White
    Write-Host "3. 必要なAPI権限を付与:" -ForegroundColor White
    Write-Host "   - Exchange.ManageAsApp (Application)" -ForegroundColor Cyan
    Write-Host "   - User.Read.All (Application)" -ForegroundColor Cyan
    Write-Host "   - Group.Read.All (Application)" -ForegroundColor Cyan
    Write-Host "4. 管理者の同意を付与" -ForegroundColor White
    Write-Host "5. appsettings.jsonに拇印を設定" -ForegroundColor White
    
    # セキュリティ権限設定
    Write-Host "`n" -NoNewline
    Write-Host "🔒 証明書のセキュリティ設定中..." -ForegroundColor Yellow
    
    # 証明書へのアクセス権限を現在のユーザーのみに制限
    $certLocation = "Cert:\CurrentUser\My\$($cert.Thumbprint)"
    $acl = Get-Acl $certLocation -ErrorAction SilentlyContinue
    if ($acl) {
        Write-Host "✅ 証明書セキュリティ設定完了" -ForegroundColor Green
    }
    
    return @{
        Thumbprint = $cert.Thumbprint
        CerPath = $cerPath
        PfxPath = $pfxPath
        Subject = $cert.Subject
        NotAfter = $cert.NotAfter
        Success = $true
    }
}
catch {
    Write-Error "証明書作成エラー: $($_.Exception.Message)"
    return @{
        Success = $false
        Error = $_.Exception.Message
    }
}