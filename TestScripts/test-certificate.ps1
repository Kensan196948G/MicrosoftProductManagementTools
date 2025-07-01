# 証明書ファイルの詳細検証
Write-Host "証明書ファイル検証を開始します..." -ForegroundColor Yellow

$certPath = "./Certificates/mycert.pfx"
$certPassword = "armageddon2002"

# 1. ファイル存在確認
Write-Host "`n=== ファイル存在確認 ===" -ForegroundColor Cyan
if (Test-Path $certPath) {
    Write-Host "✅ 証明書ファイルが存在します: $certPath" -ForegroundColor Green
    $fileInfo = Get-Item $certPath
    Write-Host "   ファイルサイズ: $($fileInfo.Length) bytes" -ForegroundColor Gray
    Write-Host "   最終更新: $($fileInfo.LastWriteTime)" -ForegroundColor Gray
} else {
    Write-Host "❌ 証明書ファイルが見つかりません: $certPath" -ForegroundColor Red
    Write-Host "現在のディレクトリ: $(Get-Location)" -ForegroundColor Yellow
    Write-Host "Certificates フォルダの内容:" -ForegroundColor Yellow
    Get-ChildItem "./Certificates" -ErrorAction SilentlyContinue | Format-Table Name, Length, LastWriteTime
    exit 1
}

# 2. パスワードなしでの読み込みテスト
Write-Host "`n=== パスワードなし読み込みテスト ===" -ForegroundColor Cyan
try {
    $certNoPassword = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)
    Write-Host "✅ パスワードなしで読み込み成功" -ForegroundColor Green
    Write-Host "   Subject: $($certNoPassword.Subject)" -ForegroundColor Gray
    Write-Host "   Thumbprint: $($certNoPassword.Thumbprint)" -ForegroundColor Gray
    Write-Host "   有効期限: $($certNoPassword.NotAfter)" -ForegroundColor Gray
} catch {
    Write-Host "❌ パスワードなし読み込み失敗: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. パスワード付き読み込みテスト
Write-Host "`n=== パスワード付き読み込みテスト ===" -ForegroundColor Cyan
try {
    $securePassword = ConvertTo-SecureString $certPassword -AsPlainText -Force
    $certWithPassword = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $securePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
    Write-Host "✅ パスワード付き読み込み成功" -ForegroundColor Green
    Write-Host "   Subject: $($certWithPassword.Subject)" -ForegroundColor Gray
    Write-Host "   Thumbprint: $($certWithPassword.Thumbprint)" -ForegroundColor Gray
    Write-Host "   有効期限: $($certWithPassword.NotAfter)" -ForegroundColor Gray
    Write-Host "   秘密キー: $($certWithPassword.HasPrivateKey)" -ForegroundColor Gray
    
    # 現在の設定との比較
    $currentThumbprint = "94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6"
    Write-Host "`n=== 設定との比較 ===" -ForegroundColor Cyan
    Write-Host "   現在の設定Thumbprint: $currentThumbprint" -ForegroundColor Yellow
    Write-Host "   実際の証明書Thumbprint: $($certWithPassword.Thumbprint)" -ForegroundColor Yellow
    if ($certWithPassword.Thumbprint -eq $currentThumbprint) {
        Write-Host "   ✅ Thumbprintが一致しています" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Thumbprintが一致しません - 設定更新が必要" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ パスワード付き読み込み失敗: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. 異なるパスワードでのテスト
Write-Host "`n=== 異なるパスワードテスト ===" -ForegroundColor Cyan
$testPasswords = @("", "password", "123456", "armageddon2002")
foreach ($testPassword in $testPasswords) {
    try {
        if ([string]::IsNullOrEmpty($testPassword)) {
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)
            Write-Host "   ✅ 空パスワードで成功" -ForegroundColor Green
        } else {
            $secureTestPassword = ConvertTo-SecureString $testPassword -AsPlainText -Force
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $secureTestPassword)
            Write-Host "   ✅ パスワード '$testPassword' で成功" -ForegroundColor Green
        }
        Write-Host "      Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
    } catch {
        Write-Host "   ❌ パスワード '$testPassword' で失敗" -ForegroundColor Red
    }
}

Write-Host "`n証明書検証完了" -ForegroundColor Yellow