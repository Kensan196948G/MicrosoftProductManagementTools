# 証明書インストールスクリプト
# PFX証明書をWindows証明書ストアにインストール

$certificatePath = "E:\MicrosoftProductManagementTools\Certificates\mycert.pfx"
$certificatePassword = "MiraiConst2025"

Write-Host "🔑 証明書インストール開始..." -ForegroundColor Cyan
Write-Host "📂 証明書ファイル: $certificatePath" -ForegroundColor Gray

try {
    if (Test-Path $certificatePath) {
        Write-Host "✅ 証明書ファイルが見つかりました" -ForegroundColor Green
        
        # パスワードをSecureStringに変換
        $securePassword = ConvertTo-SecureString -String $certificatePassword -AsPlainText -Force
        
        # 証明書情報を取得（パスワード付き）
        Write-Host "🔍 証明書情報を取得中..." -ForegroundColor Yellow
        $cert = Get-PfxCertificate -FilePath $certificatePath -Password $securePassword
        
        Write-Host "`n📋 証明書詳細情報:" -ForegroundColor Yellow
        Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor White
        Write-Host "  Subject: $($cert.Subject)" -ForegroundColor Gray
        Write-Host "  NotBefore: $($cert.NotBefore)" -ForegroundColor Gray
        Write-Host "  NotAfter: $($cert.NotAfter)" -ForegroundColor Gray
        
        # 証明書を現在のユーザーの個人証明書ストアにインストール
        Write-Host "`n🔧 証明書をインストール中..." -ForegroundColor Yellow
        
        # Import-PfxCertificateコマンドレットを使用
        $importResult = Import-PfxCertificate -FilePath $certificatePath -Password $securePassword -CertStoreLocation "Cert:\CurrentUser\My" -Exportable
        
        if ($importResult) {
            Write-Host "✅ 証明書のインストールが完了しました" -ForegroundColor Green
            Write-Host "  インストール場所: Cert:\CurrentUser\My" -ForegroundColor Gray
            Write-Host "  Thumbprint: $($importResult.Thumbprint)" -ForegroundColor Gray
            
            # 設定ファイルの更新が必要かチェック
            $configPath = "E:\MicrosoftProductManagementTools\Config\appsettings.json"
            if (Test-Path $configPath) {
                $config = Get-Content $configPath -Raw | ConvertFrom-Json
                $configThumbprint = $config.ExchangeOnline.CertificateThumbprint
                
                Write-Host "`n🔍 設定ファイル確認:" -ForegroundColor Yellow
                Write-Host "  現在の設定Thumbprint: $configThumbprint" -ForegroundColor Gray
                Write-Host "  実際の証明書Thumbprint: $($importResult.Thumbprint)" -ForegroundColor Gray
                
                if ($importResult.Thumbprint -eq $configThumbprint) {
                    Write-Host "  ✅ 設定ファイルのThumbprintが正しく設定されています" -ForegroundColor Green
                } else {
                    Write-Host "  ❌ 設定ファイルのThumbprintを更新する必要があります" -ForegroundColor Red
                    Write-Host "  📝 正しい値: $($importResult.Thumbprint)" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "❌ 証明書のインストールに失敗しました" -ForegroundColor Red
        }
        
    } else {
        Write-Host "❌ 証明書ファイルが見つかりません: $certificatePath" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ エラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "詳細: $($_.Exception.InnerException.Message)" -ForegroundColor Red
}

Write-Host "`n🏁 証明書インストール処理完了" -ForegroundColor Cyan