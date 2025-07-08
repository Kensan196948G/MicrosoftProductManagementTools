# ================================================================================
# 展開前チェックリスト - Microsoft製品運用管理ツール
# ================================================================================

Write-Host "Microsoft製品運用管理ツール - 展開準備チェック" -ForegroundColor Blue
Write-Host "=" * 60 -ForegroundColor Blue

$checkResults = @{}

# 1. 必須ファイル存在確認
Write-Host "`n=== 必須ファイル確認 ===" -ForegroundColor Yellow

$requiredFiles = @(
    "Config/appsettings.json",
    "Certificates/MiraiConstEXO.pfx",
    "Certificates/MiraiConstEXO.cer",
    "Scripts/Common/Authentication.psm1",
    "Scripts/Common/Common.psm1",
    "Scripts/Common/Logging.psm1",
    "Templates/ReportTemplate.html",
    "DEPLOYMENT-GUIDE.md"
)

$missingFiles = @()
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✓ $file" -ForegroundColor Green
    }
    else {
        Write-Host "✗ $file" -ForegroundColor Red
        $missingFiles += $file
    }
}

$checkResults.RequiredFiles = $missingFiles.Count -eq 0

# 2. 設定ファイル構文確認
Write-Host "`n=== 設定ファイル確認 ===" -ForegroundColor Yellow

try {
    $config = Get-Content "Config/appsettings.json" | ConvertFrom-Json
    Write-Host "✓ JSON構文正常" -ForegroundColor Green
    
    # 重要な設定項目確認
    $requiredSettings = @(
        @{ Path = "EntraID.TenantId"; Value = $config.EntraID.TenantId },
        @{ Path = "EntraID.ClientId"; Value = $config.EntraID.ClientId },
        @{ Path = "EntraID.CertificatePath"; Value = $config.EntraID.CertificatePath },
        @{ Path = "ExchangeOnline.Organization"; Value = $config.ExchangeOnline.Organization },
        @{ Path = "ExchangeOnline.CertificatePath"; Value = $config.ExchangeOnline.CertificatePath }
    )
    
    foreach ($setting in $requiredSettings) {
        if ($setting.Value -and $setting.Value -ne "") {
            Write-Host "✓ $($setting.Path): $($setting.Value)" -ForegroundColor Green
        }
        else {
            Write-Host "✗ $($setting.Path): 未設定" -ForegroundColor Red
        }
    }
    
    $checkResults.ConfigFile = $true
}
catch {
    Write-Host "✗ JSON構文エラー: $($_.Exception.Message)" -ForegroundColor Red
    $checkResults.ConfigFile = $false
}

# 3. 証明書ファイル確認
Write-Host "`n=== 証明書ファイル確認 ===" -ForegroundColor Yellow

try {
    # PFXファイル読み込みテスト（パスワード保護対応）
    $securePassword = ConvertTo-SecureString "YOUR_CERTIFICATE_PASSWORD" -AsPlainText -Force
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("Certificates/mycert.pfx", $securePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
    
    Write-Host "✓ PFXファイル読み込み成功" -ForegroundColor Green
    Write-Host "  Subject: $($cert.Subject)" -ForegroundColor Cyan
    Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor Cyan
    Write-Host "  有効期限: $($cert.NotAfter)" -ForegroundColor Cyan
    
    # 有効期限チェック
    $daysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days
    if ($daysUntilExpiry -gt 30) {
        Write-Host "✓ 証明書有効期限OK (残り${daysUntilExpiry}日)" -ForegroundColor Green
    }
    elseif ($daysUntilExpiry -gt 0) {
        Write-Host "⚠ 証明書有効期限注意 (残り${daysUntilExpiry}日)" -ForegroundColor Yellow
    }
    else {
        Write-Host "✗ 証明書有効期限切れ" -ForegroundColor Red
    }
    
    $checkResults.Certificate = $true
}
catch {
    Write-Host "✗ 証明書読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  パスワード保護されている可能性があります" -ForegroundColor Yellow
    $checkResults.Certificate = $false
}

# 4. ディレクトリ構造確認
Write-Host "`n=== ディレクトリ構造確認 ===" -ForegroundColor Yellow

$requiredDirs = @(
    "Scripts/Common",
    "Scripts/AD", 
    "Scripts/EXO",
    "Scripts/EntraID",
    "Reports/Daily",
    "Reports/Weekly",
    "Reports/Monthly",
    "Reports/Yearly",
    "Templates",
    "Config",
    "Certificates",
    "Logs"
)

$missingDirs = @()
foreach ($dir in $requiredDirs) {
    if (Test-Path $dir) {
        Write-Host "✓ $dir" -ForegroundColor Green
    }
    else {
        Write-Host "✗ $dir" -ForegroundColor Red
        $missingDirs += $dir
    }
}

$checkResults.DirectoryStructure = $missingDirs.Count -eq 0

# 5. ファイルサイズ確認
Write-Host "`n=== パッケージサイズ確認 ===" -ForegroundColor Yellow

$totalSize = (Get-ChildItem -Recurse | Measure-Object -Property Length -Sum).Sum
$sizeMB = [math]::Round($totalSize / 1MB, 2)

Write-Host "総サイズ: ${sizeMB} MB" -ForegroundColor Cyan

if ($sizeMB -lt 50) {
    Write-Host "✓ 適切なパッケージサイズ" -ForegroundColor Green
    $checkResults.PackageSize = $true
}
else {
    Write-Host "⚠ パッケージサイズが大きいです" -ForegroundColor Yellow
    $checkResults.PackageSize = $false
}

# 6. 総合判定
Write-Host "`n" + "=" * 60 -ForegroundColor Blue
Write-Host "=== 展開準備状況 ===" -ForegroundColor Blue

$totalChecks = $checkResults.Count
$passedChecks = ($checkResults.Values | Where-Object { $_ -eq $true }).Count

Write-Host "チェック結果: $passedChecks/$totalChecks" -ForegroundColor Cyan

if ($passedChecks -eq $totalChecks) {
    Write-Host "✅ 展開準備完了" -ForegroundColor Green
    Write-Host "このフォルダは別PCに安全に展開できます" -ForegroundColor Green
}
elseif ($passedChecks -ge ($totalChecks * 0.8)) {
    Write-Host "⚠️ 展開可能（一部注意事項あり）" -ForegroundColor Yellow
    Write-Host "軽微な問題がありますが展開可能です" -ForegroundColor Yellow
}
else {
    Write-Host "❌ 展開前に問題を修正してください" -ForegroundColor Red
    Write-Host "重要なファイルまたは設定に問題があります" -ForegroundColor Red
}

Write-Host "`n展開手順は DEPLOYMENT-GUIDE.md を参照してください" -ForegroundColor Blue
Write-Host "=" * 60 -ForegroundColor Blue