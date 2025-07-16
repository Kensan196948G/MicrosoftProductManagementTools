# 古い証明書ファイルを探してコピー
# Thumbprint: 94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6

$expectedThumbprint = "94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6"
$certificatePassword = "armageddon2002"
$targetPath = "E:\MicrosoftProductManagementTools\Certificates\mycert_old.pfx"

Write-Host "🔍 古い証明書ファイルを探しています..." -ForegroundColor Cyan
Write-Host "🎯 探している証明書Thumbprint: $expectedThumbprint" -ForegroundColor Gray

# 検索対象のパス
$searchPaths = @(
    "C:\temp\mycert.pfx",
    "E:\MicrosoftProductManagementTools\Certificates\MiraiConstEXO.pfx",
    "E:\Microsoft365認証書類\mycert.pfx",
    "E:\MicrosoftProductManagementTools\Certificates\old_mycert.pfx"
)

$foundCert = $false

foreach ($searchPath in $searchPaths) {
    Write-Host "`n🔍 検索中: $searchPath" -ForegroundColor Yellow
    
    try {
        if (Test-Path $searchPath) {
            Write-Host "✅ ファイルが見つかりました" -ForegroundColor Green
            
            # パスワードをSecureStringに変換
            $securePassword = ConvertTo-SecureString -String $certificatePassword -AsPlainText -Force
            
            # 証明書情報を取得
            $cert = Get-PfxCertificate -FilePath $searchPath -Password $securePassword
            
            if ($cert) {
                Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
                Write-Host "  NotAfter: $($cert.NotAfter)" -ForegroundColor Gray
                
                if ($cert.Thumbprint -eq $expectedThumbprint) {
                    Write-Host "  ✅ 目的の証明書が見つかりました!" -ForegroundColor Green
                    
                    # ファイルをコピー
                    Copy-Item -Path $searchPath -Destination $targetPath -Force
                    Write-Host "  📋 証明書をコピーしました: $targetPath" -ForegroundColor Green
                    
                    $foundCert = $true
                    break
                } else {
                    Write-Host "  ❌ Thumbprintが一致しません" -ForegroundColor Red
                }
            } else {
                Write-Host "  ❌ 証明書の読み取りに失敗しました" -ForegroundColor Red
            }
        } else {
            Write-Host "  ❌ ファイルが見つかりません" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ❌ エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if (-not $foundCert) {
    Write-Host "`n❌ 古い証明書ファイル (Thumbprint: $expectedThumbprint) が見つかりませんでした" -ForegroundColor Red
    Write-Host "💡 以下のいずれかの対処が必要です:" -ForegroundColor Yellow
    Write-Host "  1. 新しい証明書をAzure Portalに登録する" -ForegroundColor Cyan
    Write-Host "  2. 古い証明書ファイルを手動で配置する" -ForegroundColor Cyan
    Write-Host "  3. 証明書を再作成する" -ForegroundColor Cyan
} else {
    Write-Host "`n🎉 古い証明書ファイルが正常にコピーされました!" -ForegroundColor Green
    Write-Host "📁 コピー先: $targetPath" -ForegroundColor Gray
    Write-Host "🔧 次のステップ: appsettings.jsonのCertificatePathを更新してください" -ForegroundColor Yellow
}

Write-Host "`n🏁 証明書検索完了" -ForegroundColor Cyan