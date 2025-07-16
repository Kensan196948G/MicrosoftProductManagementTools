# 証明書パスワード確認スクリプト
# 複数のパスワード候補を試して正しいパスワードを見つける

$certificatePath = "E:\MicrosoftProductManagementTools\Certificates\mycert.pfx"

# パスワード候補リスト
$passwordCandidates = @(
    "MiraiConst2025",
    "miraiconst2025",
    "MiraiConstEXO",
    "miraiconst",
    "MyPassword",
    "password",
    "123456",
    ""  # 空パスワード
)

Write-Host "🔍 証明書パスワード検索中..." -ForegroundColor Cyan
Write-Host "📂 証明書ファイル: $certificatePath" -ForegroundColor Gray

if (Test-Path $certificatePath) {
    Write-Host "✅ 証明書ファイルが見つかりました" -ForegroundColor Green
    
    foreach ($password in $passwordCandidates) {
        try {
            Write-Host "`n🔑 パスワード候補をテスト中: '$password'" -ForegroundColor Yellow
            
            if ($password -eq "") {
                # 空パスワードの場合
                $cert = Get-PfxCertificate -FilePath $certificatePath
            } else {
                # パスワードありの場合
                $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
                $cert = Get-PfxCertificate -FilePath $certificatePath -Password $securePassword
            }
            
            if ($cert) {
                Write-Host "✅ 正しいパスワードが見つかりました: '$password'" -ForegroundColor Green
                Write-Host "`n📋 証明書詳細情報:" -ForegroundColor Yellow
                Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor White
                Write-Host "  Subject: $($cert.Subject)" -ForegroundColor Gray
                Write-Host "  NotBefore: $($cert.NotBefore)" -ForegroundColor Gray
                Write-Host "  NotAfter: $($cert.NotAfter)" -ForegroundColor Gray
                
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
                    }
                }
                
                # 証明書をインストール
                Write-Host "`n🔧 証明書をWindows証明書ストアにインストール中..." -ForegroundColor Yellow
                
                try {
                    if ($password -eq "") {
                        $importResult = Import-PfxCertificate -FilePath $certificatePath -CertStoreLocation "Cert:\CurrentUser\My" -Exportable
                    } else {
                        $importResult = Import-PfxCertificate -FilePath $certificatePath -Password $securePassword -CertStoreLocation "Cert:\CurrentUser\My" -Exportable
                    }
                    
                    if ($importResult) {
                        Write-Host "✅ 証明書のインストールが完了しました" -ForegroundColor Green
                        Write-Host "  インストール場所: Cert:\CurrentUser\My" -ForegroundColor Gray
                        Write-Host "  Thumbprint: $($importResult.Thumbprint)" -ForegroundColor Gray
                    }
                } catch {
                    Write-Host "⚠️ 証明書インストール中にエラー: $($_.Exception.Message)" -ForegroundColor Yellow
                }
                
                break  # 正しいパスワードが見つかったのでループを終了
            }
        } catch {
            Write-Host "  ❌ パスワード '$password' は正しくありません" -ForegroundColor Red
        }
    }
} else {
    Write-Host "❌ 証明書ファイルが見つかりません: $certificatePath" -ForegroundColor Red
}

Write-Host "`n🏁 証明書パスワード検索完了" -ForegroundColor Cyan