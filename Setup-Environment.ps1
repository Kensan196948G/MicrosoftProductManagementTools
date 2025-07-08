# Environment Setup Script
# 環境セットアップスクリプト

param(
    [switch]$CreateSampleFiles,
    [switch]$Validate
)

Write-Host "🔧 Microsoft Product Management Tools - Environment Setup" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green

# 必要なディレクトリを作成
$RequiredDirectories = @(
    "Certificates",
    "Config",
    "Logs",
    "Reports"
)

foreach ($dir in $RequiredDirectories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "✅ Created directory: $dir" -ForegroundColor Green
    } else {
        Write-Host "📁 Directory exists: $dir" -ForegroundColor Yellow
    }
}

# 設定ファイルのチェック
$ConfigFiles = @{
    "Config/appsettings.local.json" = "Local configuration file"
    "Certificates/mycert.pfx" = "Exchange Online certificate"
    "Certificates/certificate-info.txt" = "Certificate information"
}

Write-Host "`n📋 Configuration File Status:" -ForegroundColor Cyan
foreach ($file in $ConfigFiles.GetEnumerator()) {
    if (Test-Path $file.Key) {
        Write-Host "✅ $($file.Value): $($file.Key)" -ForegroundColor Green
    } else {
        Write-Host "❌ $($file.Value): $($file.Key) - MISSING" -ForegroundColor Red
    }
}

# サンプルファイルの作成
if ($CreateSampleFiles) {
    Write-Host "`n🔨 Creating sample configuration files..." -ForegroundColor Cyan
    
    # Certificate info sample
    $certInfoPath = "Certificates/certificate-info.txt"
    if (-not (Test-Path $certInfoPath)) {
        $certInfoContent = @"
# Certificate Information
# 証明書情報

Thumbprint: YOUR-CERTIFICATE-THUMBPRINT-HERE
Expiry Date: YYYY/MM/DD
Certificate ID: YOUR-CERTIFICATE-ID-HERE
App ID: YOUR-APP-ID-HERE

# Update Instructions
# 更新手順
1. Generate new certificate in Azure AD
2. Update thumbprint in appsettings.local.json
3. Update certificate files in Certificates folder
4. Test authentication with TestScripts/test-auth.ps1
"@
        Set-Content -Path $certInfoPath -Value $certInfoContent -Encoding UTF8
        Write-Host "✅ Created: $certInfoPath" -ForegroundColor Green
    }
}

# 検証モード
if ($Validate) {
    Write-Host "`n🔍 Validation Mode - Checking configuration..." -ForegroundColor Cyan
    
    # appsettings.local.json の検証
    $localConfigPath = "Config/appsettings.local.json"
    if (Test-Path $localConfigPath) {
        try {
            $localConfig = Get-Content $localConfigPath -Raw | ConvertFrom-Json
            
            # 必須設定の確認
            $requiredSettings = @(
                "EntraID.TenantId",
                "EntraID.ClientId",
                "EntraID.ClientSecret",
                "ExchangeOnline.AppId",
                "ExchangeOnline.CertificateThumbprint"
            )
            
            $missingSettings = @()
            foreach ($setting in $requiredSettings) {
                $parts = $setting.Split('.')
                $value = $localConfig
                foreach ($part in $parts) {
                    if ($value.$part) {
                        $value = $value.$part
                    } else {
                        $missingSettings += $setting
                        break
                    }
                }
                
                if ($value -like "*YOUR-*-HERE*") {
                    $missingSettings += $setting
                }
            }
            
            if ($missingSettings.Count -eq 0) {
                Write-Host "✅ All required settings configured" -ForegroundColor Green
            } else {
                Write-Host "❌ Missing or placeholder settings:" -ForegroundColor Red
                foreach ($missing in $missingSettings) {
                    Write-Host "   - $missing" -ForegroundColor Red
                }
            }
        }
        catch {
            Write-Host "❌ Error reading local configuration: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Local configuration file not found: $localConfigPath" -ForegroundColor Red
    }
}

Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Copy your certificate files to Certificates/ folder" -ForegroundColor White
Write-Host "2. Update Config/appsettings.local.json with your credentials" -ForegroundColor White
Write-Host "3. Run: .\Setup-Environment.ps1 -Validate" -ForegroundColor White
Write-Host "4. Test authentication: .\TestScripts\test-auth.ps1" -ForegroundColor White

Write-Host "`n🔒 Security Reminder:" -ForegroundColor Yellow
Write-Host "- Never commit appsettings.local.json or certificate files to Git" -ForegroundColor Yellow
Write-Host "- These files are protected by .gitignore" -ForegroundColor Yellow

Write-Host "`n✅ Setup completed!" -ForegroundColor Green