# ================================================================================
# Migrate-SecretsToEnv.ps1
# 機密情報を.envファイルに移行するためのスクリプト
# ================================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$DryRun = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$BackupOriginal = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$VerboseOutput = $false
)

# スクリプトルートパス
$Script:ToolRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# ログ出力関数
function Write-MigrationLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "Cyan" }
    }
    
    $prefix = switch ($Level) {
        "Success" { "✓" }
        "Warning" { "⚠" }
        "Error" { "✗" }
        default { "ℹ" }
    }
    
    Write-Host "[$timestamp] $prefix $Message" -ForegroundColor $color
}

# バックアップ作成
function New-BackupFile {
    param(
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-MigrationLog "バックアップ対象ファイルが見つかりません: $FilePath" -Level Warning
        return $null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = "$FilePath.backup.$timestamp"
    
    try {
        Copy-Item -Path $FilePath -Destination $backupPath -Force
        Write-MigrationLog "バックアップを作成しました: $backupPath" -Level Success
        return $backupPath
    }
    catch {
        Write-MigrationLog "バックアップの作成に失敗しました: $($_.Exception.Message)" -Level Error
        return $null
    }
}

# appsettings.jsonから機密情報を抽出
function Extract-SecretsFromAppSettings {
    param(
        [string]$AppSettingsPath
    )
    
    if (-not (Test-Path $AppSettingsPath)) {
        Write-MigrationLog "appsettings.jsonが見つかりません: $AppSettingsPath" -Level Error
        return @{}
    }
    
    try {
        $appSettings = Get-Content $AppSettingsPath -Raw | ConvertFrom-Json
        $secrets = @{}
        
        # EntraID設定
        if ($appSettings.EntraID) {
            $secrets["AZURE_TENANT_ID"] = $appSettings.EntraID.TenantId
            $secrets["AZURE_CLIENT_ID"] = $appSettings.EntraID.ClientId
            $secrets["AZURE_CLIENT_SECRET"] = $appSettings.EntraID.ClientSecret
            $secrets["CERTIFICATE_THUMBPRINT"] = $appSettings.EntraID.CertificateThumbprint
            $secrets["CERTIFICATE_PATH"] = $appSettings.EntraID.CertificatePath
            $secrets["CERTIFICATE_PASSWORD"] = $appSettings.EntraID.CertificatePassword
        }
        
        # Exchange Online設定
        if ($appSettings.ExchangeOnline) {
            $secrets["EXCHANGE_ONLINE_APP_ID"] = $appSettings.ExchangeOnline.AppId
            $secrets["EXCHANGE_ONLINE_THUMBPRINT"] = $appSettings.ExchangeOnline.CertificateThumbprint
            $secrets["EXCHANGE_ONLINE_ORGANIZATION"] = $appSettings.ExchangeOnline.Organization
            if ($appSettings.ExchangeOnline.CertificatePassword) {
                $secrets["CERTIFICATE_PASSWORD"] = $appSettings.ExchangeOnline.CertificatePassword
            }
        }
        
        # Microsoft Graph設定
        if ($appSettings.MicrosoftGraph) {
            $secrets["GRAPH_CLIENT_ID"] = $appSettings.MicrosoftGraph.ClientId
            $secrets["GRAPH_CLIENT_SECRET"] = $appSettings.MicrosoftGraph.ClientSecret
            $secrets["GRAPH_REDIRECT_URI"] = $appSettings.MicrosoftGraph.RedirectUri
        }
        
        # Active Directory設定
        if ($appSettings.ActiveDirectory) {
            $secrets["AD_DOMAIN_CONTROLLER"] = $appSettings.ActiveDirectory.DomainController
            $secrets["AD_SEARCH_BASE"] = $appSettings.ActiveDirectory.SearchBase
            $secrets["AD_CREDENTIAL_USERNAME"] = $appSettings.ActiveDirectory.CredentialUsername
            $secrets["AD_CREDENTIAL_PASSWORD"] = $appSettings.ActiveDirectory.CredentialPasswordSecure
        }
        
        # SMTP設定
        if ($appSettings.SMTP) {
            $secrets["SMTP_SERVER"] = $appSettings.SMTP.Server
            $secrets["SMTP_PORT"] = $appSettings.SMTP.Port
            $secrets["SMTP_USERNAME"] = $appSettings.SMTP.Username
            $secrets["SMTP_PASSWORD"] = $appSettings.SMTP.Password
        }
        
        # 暗号化設定
        if ($appSettings.Encryption) {
            $secrets["ENCRYPTION_KEY"] = $appSettings.Encryption.Key
            $secrets["JWT_SECRET"] = $appSettings.Encryption.JwtSecret
        }
        
        Write-MigrationLog "appsettings.jsonから $($secrets.Count) 個の機密情報を抽出しました" -Level Success
        return $secrets
    }
    catch {
        Write-MigrationLog "appsettings.jsonの解析に失敗しました: $($_.Exception.Message)" -Level Error
        return @{}
    }
}

# Google Drive設定から機密情報を抽出
function Extract-SecretsFromGoogleDrive {
    param(
        [string]$GoogleDrivePath
    )
    
    if (-not (Test-Path $GoogleDrivePath)) {
        Write-MigrationLog "googledrive.jsonが見つかりません: $GoogleDrivePath" -Level Warning
        return @{}
    }
    
    try {
        $googleDrive = Get-Content $GoogleDrivePath -Raw | ConvertFrom-Json
        $secrets = @{}
        
        if ($googleDrive.client_id) {
            $secrets["GOOGLE_DRIVE_CLIENT_ID"] = $googleDrive.client_id
        }
        
        if ($googleDrive.client_secret) {
            $secrets["GOOGLE_DRIVE_CLIENT_SECRET"] = $googleDrive.client_secret
        }
        
        if ($googleDrive.project_id) {
            $secrets["GOOGLE_DRIVE_PROJECT_ID"] = $googleDrive.project_id
        }
        
        Write-MigrationLog "googledrive.jsonから $($secrets.Count) 個の機密情報を抽出しました" -Level Success
        return $secrets
    }
    catch {
        Write-MigrationLog "googledrive.jsonの解析に失敗しました: $($_.Exception.Message)" -Level Error
        return @{}
    }
}

# PowerShellスクリプトから機密情報を検索
function Find-SecretsInPowerShellFiles {
    param(
        [string]$ScriptsPath
    )
    
    $secrets = @{}
    $suspiciousPatterns = @(
        'password\s*=\s*"([^"]+)"',
        'secret\s*=\s*"([^"]+)"',
        'key\s*=\s*"([^"]+)"',
        'token\s*=\s*"([^"]+)"',
        'thumbprint\s*=\s*"([^"]+)"'
    )
    
    try {
        $psFiles = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" -Recurse
        $foundSecrets = 0
        
        foreach ($file in $psFiles) {
            $content = Get-Content $file.FullName -Raw
            
            foreach ($pattern in $suspiciousPatterns) {
                $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                
                foreach ($match in $matches) {
                    $value = $match.Groups[1].Value
                    
                    # プレースホルダーや明らかにダミーの値は除外
                    if ($value -match "YOUR-.*-HERE|placeholder|dummy|example|test|CHANGE-ME") {
                        continue
                    }
                    
                    # 実際の値と思われるものをログに記録
                    Write-MigrationLog "機密情報の可能性: $($file.Name) - $($match.Groups[0].Value)" -Level Warning
                    $foundSecrets++
                }
            }
        }
        
        Write-MigrationLog "PowerShellファイルから $foundSecrets 個の機密情報候補を発見しました" -Level Info
        return $secrets
    }
    catch {
        Write-MigrationLog "PowerShellファイルの検索に失敗しました: $($_.Exception.Message)" -Level Error
        return @{}
    }
}

# .envファイルを更新
function Update-EnvFile {
    param(
        [string]$EnvPath,
        [hashtable]$Secrets
    )
    
    try {
        # 既存の.envファイルを読み込み
        $existingContent = @()
        if (Test-Path $EnvPath) {
            $existingContent = Get-Content $EnvPath
        }
        
        # 新しい内容を準備
        $newContent = @()
        $updatedVars = @()
        
        # 既存の内容をコピー（機密情報以外）
        foreach ($line in $existingContent) {
            if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
                $newContent += $line
                continue
            }
            
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                
                # 機密情報を更新
                if ($Secrets.ContainsKey($key)) {
                    $newContent += "$key=$($Secrets[$key])"
                    $updatedVars += $key
                    $Secrets.Remove($key)
                } else {
                    $newContent += $line
                }
            } else {
                $newContent += $line
            }
        }
        
        # 新しい機密情報を追加
        if ($Secrets.Count -gt 0) {
            $newContent += ""
            $newContent += "# ================================================================================"
            $newContent += "# 移行された機密情報 ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))"
            $newContent += "# ================================================================================"
            
            foreach ($key in $Secrets.Keys) {
                if (![string]::IsNullOrWhiteSpace($Secrets[$key])) {
                    $newContent += "$key=$($Secrets[$key])"
                    $updatedVars += $key
                }
            }
        }
        
        # DryRunモードでない場合のみファイルを更新
        if (-not $DryRun) {
            $newContent | Out-File -FilePath $EnvPath -Encoding UTF8 -Force
            Write-MigrationLog ".envファイルを更新しました: $EnvPath" -Level Success
        } else {
            Write-MigrationLog "[DryRun] .envファイルの更新をシミュレートしました" -Level Info
        }
        
        Write-MigrationLog "$($updatedVars.Count) 個の環境変数を更新しました" -Level Success
        
        if ($VerboseOutput) {
            Write-MigrationLog "更新された変数:" -Level Info
            foreach ($var in $updatedVars) {
                Write-MigrationLog "  ✓ $var" -Level Success
            }
        }
        
        return $updatedVars.Count
    }
    catch {
        Write-MigrationLog ".envファイルの更新に失敗しました: $($_.Exception.Message)" -Level Error
        return 0
    }
}

# appsettings.jsonをサニタイズ
function Sanitize-AppSettings {
    param(
        [string]$AppSettingsPath
    )
    
    if (-not (Test-Path $AppSettingsPath)) {
        return
    }
    
    try {
        $appSettings = Get-Content $AppSettingsPath -Raw | ConvertFrom-Json
        
        # 機密情報をプレースホルダーに置換
        if ($appSettings.EntraID) {
            $appSettings.EntraID.TenantId = "YOUR-TENANT-ID-HERE"
            $appSettings.EntraID.ClientId = "YOUR-CLIENT-ID-HERE"
            $appSettings.EntraID.ClientSecret = "YOUR-CLIENT-SECRET-HERE"
            $appSettings.EntraID.CertificateThumbprint = "YOUR-CERTIFICATE-THUMBPRINT-HERE"
            $appSettings.EntraID.CertificatePassword = "YOUR-CERTIFICATE-PASSWORD-HERE"
        }
        
        if ($appSettings.ExchangeOnline) {
            $appSettings.ExchangeOnline.AppId = "YOUR-APP-ID-HERE"
            $appSettings.ExchangeOnline.CertificateThumbprint = "YOUR-CERTIFICATE-THUMBPRINT-HERE"
            $appSettings.ExchangeOnline.CertificatePassword = "YOUR-CERTIFICATE-PASSWORD-HERE"
        }
        
        if ($appSettings.MicrosoftGraph) {
            $appSettings.MicrosoftGraph.ClientId = "YOUR-CLIENT-ID-HERE"
            $appSettings.MicrosoftGraph.ClientSecret = "YOUR-CLIENT-SECRET-HERE"
        }
        
        if ($appSettings.ActiveDirectory) {
            $appSettings.ActiveDirectory.CredentialUsername = "YOUR-USERNAME-HERE"
            $appSettings.ActiveDirectory.CredentialPasswordSecure = "YOUR-PASSWORD-HERE"
        }
        
        if ($appSettings.SMTP) {
            $appSettings.SMTP.Username = "YOUR-SMTP-USERNAME-HERE"
            $appSettings.SMTP.Password = "YOUR-SMTP-PASSWORD-HERE"
        }
        
        if ($appSettings.Encryption) {
            $appSettings.Encryption.Key = "YOUR-ENCRYPTION-KEY-HERE"
            $appSettings.Encryption.JwtSecret = "YOUR-JWT-SECRET-HERE"
        }
        
        # DryRunモードでない場合のみファイルを更新
        if (-not $DryRun) {
            $appSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $AppSettingsPath -Encoding UTF8 -Force
            Write-MigrationLog "appsettings.jsonをサニタイズしました" -Level Success
        } else {
            Write-MigrationLog "[DryRun] appsettings.jsonのサニタイズをシミュレートしました" -Level Info
        }
    }
    catch {
        Write-MigrationLog "appsettings.jsonのサニタイズに失敗しました: $($_.Exception.Message)" -Level Error
    }
}

# メイン実行
function Main {
    Write-MigrationLog "機密情報の.env移行を開始します..." -Level Info
    
    if ($DryRun) {
        Write-MigrationLog "DryRunモードで実行中（実際の変更は行われません）" -Level Warning
    }
    
    # パス設定
    $envPath = Join-Path $Script:ToolRoot ".env"
    $appSettingsPath = Join-Path $Script:ToolRoot "Config\appsettings.json"
    $googleDrivePath = Join-Path $Script:ToolRoot "Config\googledrive.json"
    $scriptsPath = Join-Path $Script:ToolRoot "Scripts"
    
    # バックアップ作成
    if ($BackupOriginal -and -not $DryRun) {
        Write-MigrationLog "バックアップを作成しています..." -Level Info
        
        if (Test-Path $appSettingsPath) {
            New-BackupFile -FilePath $appSettingsPath
        }
        
        if (Test-Path $googleDrivePath) {
            New-BackupFile -FilePath $googleDrivePath
        }
        
        if (Test-Path $envPath) {
            New-BackupFile -FilePath $envPath
        }
    }
    
    # 機密情報の抽出
    $allSecrets = @{}
    
    # appsettings.jsonから抽出
    $appSettingsSecrets = Extract-SecretsFromAppSettings -AppSettingsPath $appSettingsPath
    foreach ($key in $appSettingsSecrets.Keys) {
        $allSecrets[$key] = $appSettingsSecrets[$key]
    }
    
    # Google Drive設定から抽出
    $googleDriveSecrets = Extract-SecretsFromGoogleDrive -GoogleDrivePath $googleDrivePath
    foreach ($key in $googleDriveSecrets.Keys) {
        $allSecrets[$key] = $googleDriveSecrets[$key]
    }
    
    # PowerShellファイルから検索
    Find-SecretsInPowerShellFiles -ScriptsPath $scriptsPath
    
    # Git認証情報を追加（提供された情報から）
    $allSecrets["GIT_USERNAME"] = "YOUR_GITHUB_USERNAME"
    $allSecrets["GIT_PASSWORD"] = "YOUR_GITHUB_PASSWORD"
    $allSecrets["GIT_REPOSITORY_URL"] = "https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git"
    $allSecrets["GIT_BRANCH"] = "main"
    
    # .envファイルを更新
    $updatedCount = Update-EnvFile -EnvPath $envPath -Secrets $allSecrets
    
    # 設定ファイルのサニタイズ
    if ($updatedCount -gt 0) {
        Write-MigrationLog "設定ファイルをサニタイズしています..." -Level Info
        Sanitize-AppSettings -AppSettingsPath $appSettingsPath
    }
    
    # 結果の表示
    Write-MigrationLog "移行完了: $updatedCount 個の環境変数を処理しました" -Level Success
    
    if (-not $DryRun) {
        Write-MigrationLog "次のステップ:" -Level Info
        Write-MigrationLog "  1. .env ファイルの内容を確認してください" -Level Info
        Write-MigrationLog "  2. 実際の認証情報を設定してください" -Level Info
        Write-MigrationLog "  3. git add . && git commit でコミットしてください" -Level Info
        Write-MigrationLog "  4. 機密情報が .gitignore に含まれていることを確認してください" -Level Info
    }
}

# スクリプト実行
Main