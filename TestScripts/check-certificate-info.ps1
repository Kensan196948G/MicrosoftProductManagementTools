# 証明書情報確認スクリプト
# 実際の証明書のThumbprintを確認

$certificatePath = "E:\MicrosoftProductManagementTools\Certificates\mycert.pfx"

Write-Host "🔍 証明書情報確認中..." -ForegroundColor Cyan
Write-Host "📂 証明書ファイル: $certificatePath" -ForegroundColor Gray

try {
    if (Test-Path $certificatePath) {
        Write-Host "✅ 証明書ファイルが見つかりました" -ForegroundColor Green
        
        # 証明書情報を取得
        $cert = Get-PfxCertificate -FilePath $certificatePath
        
        Write-Host "`n📋 証明書詳細情報:" -ForegroundColor Yellow
        Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor White
        Write-Host "  Subject: $($cert.Subject)" -ForegroundColor Gray
        Write-Host "  Issuer: $($cert.Issuer)" -ForegroundColor Gray
        Write-Host "  NotBefore: $($cert.NotBefore)" -ForegroundColor Gray
        Write-Host "  NotAfter: $($cert.NotAfter)" -ForegroundColor Gray
        Write-Host "  SerialNumber: $($cert.SerialNumber)" -ForegroundColor Gray
        
        # 設定ファイルの値と比較
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
        
        # Windows証明書ストアで同じ証明書を探す
        Write-Host "`n🔍 Windows証明書ストア確認:" -ForegroundColor Yellow
        
        # 現在のユーザーの証明書ストアを確認
        $storeLocations = @(
            "CurrentUser\My",
            "CurrentUser\Root", 
            "LocalMachine\My",
            "LocalMachine\Root"
        )
        
        $foundInStore = $false
        foreach ($location in $storeLocations) {
            try {
                $store = Get-ChildItem "Cert:\$location" | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
                if ($store) {
                    Write-Host "  ✅ 証明書が見つかりました: Cert:\$location" -ForegroundColor Green
                    $foundInStore = $true
                }
            } catch {
                # ストアにアクセスできない場合はスキップ
            }
        }
        
        if (-not $foundInStore) {
            Write-Host "  ❌ Windows証明書ストアに証明書が見つかりません" -ForegroundColor Red
            Write-Host "  📝 証明書をインストールする必要があります" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "❌ 証明書ファイルが見つかりません: $certificatePath" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ エラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🏁 証明書情報確認完了" -ForegroundColor Cyan