# 現在の証明書ファイルのThumbprintを確認
# Azure Portalに登録されている証明書と一致するか確認

$certificatePath = "E:\MicrosoftProductManagementTools\Certificates\mycert.pfx"
$certificatePassword = "armageddon2002"
$expectedThumbprint = "94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6"

Write-Host "🔍 現在の証明書ファイルのThumbprint確認..." -ForegroundColor Cyan
Write-Host "📂 証明書ファイル: $certificatePath" -ForegroundColor Gray
Write-Host "🎯 期待されるThumbprint: $expectedThumbprint" -ForegroundColor Gray

try {
    if (Test-Path $certificatePath) {
        Write-Host "✅ 証明書ファイルが見つかりました" -ForegroundColor Green
        
        # パスワードをSecureStringに変換
        $securePassword = ConvertTo-SecureString -String $certificatePassword -AsPlainText -Force
        
        # 証明書情報を取得
        $cert = Get-PfxCertificate -FilePath $certificatePath -Password $securePassword
        
        if ($cert) {
            Write-Host "`n📋 証明書詳細情報:" -ForegroundColor Yellow
            Write-Host "  実際のThumbprint: $($cert.Thumbprint)" -ForegroundColor White
            Write-Host "  期待されるThumbprint: $expectedThumbprint" -ForegroundColor White
            Write-Host "  Subject: $($cert.Subject)" -ForegroundColor Gray
            Write-Host "  NotAfter: $($cert.NotAfter)" -ForegroundColor Gray
            
            if ($cert.Thumbprint -eq $expectedThumbprint) {
                Write-Host "`n✅ 証明書Thumbprintが一致しています!" -ForegroundColor Green
                Write-Host "📊 この証明書はAzure Portalに登録済みです" -ForegroundColor Green
                
                # Windows証明書ストアにインストール
                Write-Host "`n🔧 Windows証明書ストアにインストール中..." -ForegroundColor Yellow
                try {
                    $importResult = Import-PfxCertificate -FilePath $certificatePath -Password $securePassword -CertStoreLocation "Cert:\CurrentUser\My" -Exportable
                    if ($importResult) {
                        Write-Host "✅ 証明書のインストール完了" -ForegroundColor Green
                        Write-Host "  インストール先: Cert:\CurrentUser\My" -ForegroundColor Gray
                    }
                } catch {
                    Write-Host "⚠️ 証明書は既にインストール済みの可能性があります" -ForegroundColor Yellow
                }
                
                Write-Host "`n🎉 Exchange Online証明書認証の準備完了!" -ForegroundColor Green
                
            } else {
                Write-Host "`n❌ 証明書Thumbprintが一致しません" -ForegroundColor Red
                Write-Host "💡 正しい証明書ファイルが必要です" -ForegroundColor Yellow
                Write-Host "📁 C:\temp\mycert.pfx から正しいファイルをコピーしてください" -ForegroundColor Cyan
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

Write-Host "`n🏁 証明書Thumbprint確認完了" -ForegroundColor Cyan