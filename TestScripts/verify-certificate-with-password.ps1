# 証明書パスワード確認スクリプト
# パスワード armageddon2002 で証明書を確認・インストール

$certificatePath = "E:\MicrosoftProductManagementTools\Certificates\mycert.pfx"
$certificatePassword = "armageddon2002"

Write-Host "🔍 証明書確認中..." -ForegroundColor Cyan
Write-Host "📂 証明書ファイル: $certificatePath" -ForegroundColor Gray
Write-Host "🔑 パスワード: $certificatePassword" -ForegroundColor Gray

try {
    if (Test-Path $certificatePath) {
        Write-Host "✅ 証明書ファイルが見つかりました" -ForegroundColor Green
        
        # パスワードをSecureStringに変換
        $securePassword = ConvertTo-SecureString -String $certificatePassword -AsPlainText -Force
        
        # 証明書情報を取得
        Write-Host "`n🔍 証明書情報を取得中..." -ForegroundColor Yellow
        $cert = Get-PfxCertificate -FilePath $certificatePath -Password $securePassword
        
        if ($cert) {
            Write-Host "✅ 証明書の読み取りが成功しました" -ForegroundColor Green
            
            Write-Host "`n📋 証明書詳細情報:" -ForegroundColor Yellow
            Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor White
            Write-Host "  Subject: $($cert.Subject)" -ForegroundColor Gray
            Write-Host "  Issuer: $($cert.Issuer)" -ForegroundColor Gray
            Write-Host "  NotBefore: $($cert.NotBefore)" -ForegroundColor Gray
            Write-Host "  NotAfter: $($cert.NotAfter)" -ForegroundColor Gray
            Write-Host "  SerialNumber: $($cert.SerialNumber)" -ForegroundColor Gray
            
            # 設定ファイルのThumbprintと比較
            $configPath = "E:\MicrosoftProductManagementTools\Config\appsettings.json"
            if (Test-Path $configPath) {
                $config = Get-Content $configPath -Raw | ConvertFrom-Json
                $configThumbprint = $config.ExchangeOnline.CertificateThumbprint
                
                Write-Host "`n🔍 設定ファイル比較:" -ForegroundColor Yellow
                Write-Host "  設定ファイルのThumbprint: $configThumbprint" -ForegroundColor Gray
                Write-Host "  実際の証明書Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
                
                if ($cert.Thumbprint -eq $configThumbprint) {
                    Write-Host "  ✅ Thumbprintが一致しています" -ForegroundColor Green
                } else {
                    Write-Host "  ❌ Thumbprintが一致しません" -ForegroundColor Red
                    Write-Host "  📝 設定ファイルを更新する必要があります" -ForegroundColor Yellow
                    Write-Host "  正しいThumbprint: $($cert.Thumbprint)" -ForegroundColor Cyan
                }
            }
            
            # 証明書をWindows証明書ストアにインストール
            Write-Host "`n🔧 証明書をWindows証明書ストアにインストール中..." -ForegroundColor Yellow
            
            try {
                $importResult = Import-PfxCertificate -FilePath $certificatePath -Password $securePassword -CertStoreLocation "Cert:\CurrentUser\My" -Exportable
                
                if ($importResult) {
                    Write-Host "✅ 証明書のインストールが完了しました" -ForegroundColor Green
                    Write-Host "  インストール場所: Cert:\CurrentUser\My" -ForegroundColor Gray
                    Write-Host "  Thumbprint: $($importResult.Thumbprint)" -ForegroundColor Gray
                    
                    # インストール後の確認
                    $installedCert = Get-ChildItem "Cert:\CurrentUser\My" | Where-Object { $_.Thumbprint -eq $importResult.Thumbprint }
                    if ($installedCert) {
                        Write-Host "  ✅ 証明書ストアで証明書が確認できました" -ForegroundColor Green
                    }
                } else {
                    Write-Host "❌ 証明書のインストールに失敗しました" -ForegroundColor Red
                }
            } catch {
                Write-Host "❌ 証明書インストール中にエラー: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            # .envファイルのパスワードを確認
            $envPath = "E:\MicrosoftProductManagementTools\.env"
            if (Test-Path $envPath) {
                $envContent = Get-Content $envPath -Raw
                Write-Host "`n🔍 .envファイルのパスワード確認:" -ForegroundColor Yellow
                
                if ($envContent -match "EXO_CERTIFICATE_PASSWORD=(.+)") {
                    $currentEnvPassword = $matches[1]
                    Write-Host "  現在の.envパスワード: $currentEnvPassword" -ForegroundColor Gray
                    Write-Host "  正しいパスワード: $certificatePassword" -ForegroundColor Gray
                    
                    if ($currentEnvPassword -eq $certificatePassword) {
                        Write-Host "  ✅ .envファイルのパスワードが正しく設定されています" -ForegroundColor Green
                    } else {
                        Write-Host "  ❌ .envファイルのパスワードを更新する必要があります" -ForegroundColor Red
                    }
                } else {
                    Write-Host "  ⚠️ .envファイルにEXO_CERTIFICATE_PASSWORDが見つかりません" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "❌ 証明書の読み取りに失敗しました" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ 証明書ファイルが見つかりません: $certificatePath" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ エラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🏁 証明書確認処理完了" -ForegroundColor Cyan