# ================================================================================
# Update-Certificate-Only.ps1
# 証明書拇印のみ更新（クライアントIDは維持）
# ================================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$NewCertificateThumbprint,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "Config/appsettings.json"
)

Write-Host "🔧 証明書拇印のみ更新中..." -ForegroundColor Green
Write-Host "クライアントID は変更しません" -ForegroundColor Yellow

try {
    # 設定ファイル読み込み
    if (-not (Test-Path $ConfigPath)) {
        throw "設定ファイルが見つかりません: $ConfigPath"
    }
    
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    
    # 現在の設定表示
    Write-Host "`n📋 現在の設定:" -ForegroundColor Cyan
    Write-Host "クライアントID: $($config.EntraID.ClientId)" -ForegroundColor White
    Write-Host "現在の拇印: $($config.EntraID.CertificateThumbprint)" -ForegroundColor White
    Write-Host "新しい拇印: $NewCertificateThumbprint" -ForegroundColor Green
    
    # 証明書拇印のみ更新
    $oldThumbprint = $config.EntraID.CertificateThumbprint
    $config.EntraID.CertificateThumbprint = $NewCertificateThumbprint
    $config.ExchangeOnline.CertificateThumbprint = $NewCertificateThumbprint
    
    # ファイル保存
    $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
    
    Write-Host "`n✅ 証明書拇印更新完了" -ForegroundColor Green
    Write-Host "変更前: $oldThumbprint" -ForegroundColor Yellow
    Write-Host "変更後: $NewCertificateThumbprint" -ForegroundColor Green
    
    # 変更内容確認
    Write-Host "`n📋 更新後の設定確認:" -ForegroundColor Cyan
    $updatedConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    Write-Host "EntraID.ClientId: $($updatedConfig.EntraID.ClientId)" -ForegroundColor White
    Write-Host "EntraID.CertificateThumbprint: $($updatedConfig.EntraID.CertificateThumbprint)" -ForegroundColor White
    Write-Host "ExchangeOnline.AppId: $($updatedConfig.ExchangeOnline.AppId)" -ForegroundColor White
    Write-Host "ExchangeOnline.CertificateThumbprint: $($updatedConfig.ExchangeOnline.CertificateThumbprint)" -ForegroundColor White
    
    # 証明書存在確認
    Write-Host "`n🔍 証明書ストア確認中..." -ForegroundColor Yellow
    $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object {$_.Thumbprint -eq $NewCertificateThumbprint}
    
    if ($cert) {
        Write-Host "✅ 証明書が正常にインストールされています" -ForegroundColor Green
        Write-Host "件名: $($cert.Subject)" -ForegroundColor White
        Write-Host "有効期限: $($cert.NotAfter)" -ForegroundColor White
        Write-Host "秘密キー: $($cert.HasPrivateKey)" -ForegroundColor White
    } else {
        Write-Host "⚠️ 証明書がローカルストアに見つかりません" -ForegroundColor Red
        Write-Host "証明書作成スクリプトを再実行してください" -ForegroundColor Yellow
    }
    
    Write-Host "`n🎯 次のステップ:" -ForegroundColor Yellow
    Write-Host "1. Azure Portalで古い証明書を削除" -ForegroundColor White
    Write-Host "2. 接続テスト実行: ./auto-test.sh --comprehensive" -ForegroundColor White
    Write-Host "3. システム開始: ./start-all.sh" -ForegroundColor White
}
catch {
    Write-Error "設定更新エラー: $($_.Exception.Message)"
    exit 1
}