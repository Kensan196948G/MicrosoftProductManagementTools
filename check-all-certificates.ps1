# 全証明書ファイルの詳細確認
Write-Host "全証明書ファイルの詳細確認を開始します..." -ForegroundColor Yellow

$certFiles = @(
    "./Certificates/mycert.pfx",
    "./Certificates/MiraiConstEXO.cer",
    "./Certificates/mycert.cer"
)

$targetThumbprint = "94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6"
Write-Host "`nAzure AD登録済みThumbprint: $targetThumbprint" -ForegroundColor Cyan

foreach ($certFile in $certFiles) {
    Write-Host "`n=== $certFile ===" -ForegroundColor Yellow
    
    if (-not (Test-Path $certFile)) {
        Write-Host "❌ ファイルが存在しません" -ForegroundColor Red
        continue
    }
    
    try {
        if ($certFile -like "*.pfx") {
            # PFXファイルの場合
            Write-Host "PFXファイルとして処理中..." -ForegroundColor Gray
            
            # パスワードなしで試行
            try {
                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certFile)
                Write-Host "✅ パスワードなしで読み込み成功" -ForegroundColor Green
            } catch {
                Write-Host "❌ パスワードなし読み込み失敗: $($_.Exception.Message)" -ForegroundColor Red
                
                # パスワード付きで試行
                try {
                    $securePassword = ConvertTo-SecureString "armageddon2002" -AsPlainText -Force
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certFile, $securePassword)
                    Write-Host "✅ パスワード付きで読み込み成功" -ForegroundColor Green
                } catch {
                    Write-Host "❌ パスワード付き読み込み失敗: $($_.Exception.Message)" -ForegroundColor Red
                    continue
                }
            }
        } else {
            # CER/CRTファイルの場合
            Write-Host "CER/CRTファイルとして処理中..." -ForegroundColor Gray
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certFile)
            Write-Host "✅ 読み込み成功" -ForegroundColor Green
        }
        
        # 証明書情報表示
        Write-Host "   Subject: $($cert.Subject)" -ForegroundColor White
        Write-Host "   Thumbprint: $($cert.Thumbprint)" -ForegroundColor White
        Write-Host "   有効期限: $($cert.NotAfter)" -ForegroundColor White
        Write-Host "   秘密キー: $($cert.HasPrivateKey)" -ForegroundColor White
        
        # Azure AD登録証明書との照合
        if ($cert.Thumbprint -eq $targetThumbprint) {
            Write-Host "   🎯 Azure AD登録証明書と一致!" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Azure AD登録証明書と不一致" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "❌ 証明書読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== 推奨対処法 ===" -ForegroundColor Cyan
Write-Host "Azure AD登録証明書 (Thumbprint: $targetThumbprint) に対応するファイルが見つからない場合:" -ForegroundColor Yellow
Write-Host "1. Azure ADで新しい証明書 (Thumbprint: 3C5C3A9C4F97CD1C95DFDB389AB1F371AAB87975) を登録" -ForegroundColor Yellow
Write-Host "2. または、古い証明書ファイルを復旧" -ForegroundColor Yellow
Write-Host "3. ClientSecret認証を使用 (現在正常動作中)" -ForegroundColor Yellow