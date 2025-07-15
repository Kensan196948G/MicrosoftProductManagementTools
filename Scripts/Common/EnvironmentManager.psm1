# ================================================================================
# EnvironmentManager.psm1
# 環境変数管理モジュール
# .envファイルの読み込みと環境変数の管理
# ================================================================================

# .envファイルの読み込み
function Import-EnvironmentFile {
    param(
        [Parameter(Mandatory = $false)]
        [string]$EnvFilePath = ".env",
        
        [Parameter(Mandatory = $false)]
        [switch]$UseRootDirectory = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$VerboseOutput = $false
    )
    
    try {
        # ルートディレクトリから.envファイルを探す
        if ($UseRootDirectory) {
            $scriptRoot = $PSScriptRoot
            $rootPath = Split-Path (Split-Path $scriptRoot -Parent) -Parent
            $envPath = Join-Path $rootPath $EnvFilePath
        } else {
            $envPath = $EnvFilePath
        }
        
        if (-not (Test-Path $envPath)) {
            Write-Warning ".envファイルが見つかりません: $envPath"
            Write-Warning "テンプレートファイルを作成してください"
            return $false
        }
        
        if ($VerboseOutput) {
            Write-Host ".envファイルを読み込んでいます: $envPath" -ForegroundColor Cyan
        }
        
        # .envファイルの内容を読み込み
        $envContent = Get-Content $envPath -ErrorAction Stop
        $loadedVars = 0
        
        foreach ($line in $envContent) {
            # 空行とコメント行をスキップ
            if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
                continue
            }
            
            # KEY=VALUE形式の行を処理
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                
                # 既存の環境変数をチェック
                if ([System.Environment]::GetEnvironmentVariable($key)) {
                    if ($VerboseOutput) {
                        Write-Host "環境変数 $key は既に設定されています（.envファイルの値は無視されます）" -ForegroundColor Yellow
                    }
                    continue
                }
                
                # 値の前後の引用符を除去
                $value = $value.Trim('"').Trim("'")
                
                # 環境変数として設定
                [System.Environment]::SetEnvironmentVariable($key, $value, [System.EnvironmentVariableTarget]::Process)
                
                if ($VerboseOutput) {
                    Write-Host "環境変数を設定しました: $key" -ForegroundColor Green
                }
                
                $loadedVars++
            }
        }
        
        if ($VerboseOutput) {
            Write-Host "$loadedVars 個の環境変数を読み込みました" -ForegroundColor Green
        }
        
        return $true
    }
    catch {
        Write-Error ".envファイルの読み込みに失敗しました: $($_.Exception.Message)"
        return $false
    }
}

# 環境変数の安全な取得
function Get-SecureEnvironmentVariable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VariableName,
        
        [Parameter(Mandatory = $false)]
        [string]$DefaultValue = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ThrowOnMissing = $false
    )
    
    try {
        $value = [System.Environment]::GetEnvironmentVariable($VariableName)
        
        if ([string]::IsNullOrWhiteSpace($value)) {
            if ($ThrowOnMissing) {
                throw "必須の環境変数が設定されていません: $VariableName"
            }
            return $DefaultValue
        }
        
        return $value
    }
    catch {
        if ($ThrowOnMissing) {
            throw $_
        }
        Write-Warning "環境変数の取得に失敗しました: $VariableName"
        return $DefaultValue
    }
}

# Azure認証情報の取得
function Get-AzureCredentials {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$ThrowOnMissing = $false
    )
    
    return @{
        TenantId = Get-SecureEnvironmentVariable -VariableName "AZURE_TENANT_ID" -ThrowOnMissing:$ThrowOnMissing
        ClientId = Get-SecureEnvironmentVariable -VariableName "AZURE_CLIENT_ID" -ThrowOnMissing:$ThrowOnMissing
        ClientSecret = Get-SecureEnvironmentVariable -VariableName "AZURE_CLIENT_SECRET" -ThrowOnMissing:$ThrowOnMissing
    }
}

# Exchange Online認証情報の取得
function Get-ExchangeOnlineCredentials {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$ThrowOnMissing = $false
    )
    
    return @{
        AppId = Get-SecureEnvironmentVariable -VariableName "EXCHANGE_ONLINE_APP_ID" -ThrowOnMissing:$ThrowOnMissing
        Thumbprint = Get-SecureEnvironmentVariable -VariableName "EXCHANGE_ONLINE_THUMBPRINT" -ThrowOnMissing:$ThrowOnMissing
        Organization = Get-SecureEnvironmentVariable -VariableName "EXCHANGE_ONLINE_ORGANIZATION" -ThrowOnMissing:$ThrowOnMissing
    }
}

# Microsoft Graph認証情報の取得
function Get-GraphCredentials {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$ThrowOnMissing = $false
    )
    
    return @{
        ClientId = Get-SecureEnvironmentVariable -VariableName "GRAPH_CLIENT_ID" -ThrowOnMissing:$ThrowOnMissing
        ClientSecret = Get-SecureEnvironmentVariable -VariableName "GRAPH_CLIENT_SECRET" -ThrowOnMissing:$ThrowOnMissing
        RedirectUri = Get-SecureEnvironmentVariable -VariableName "GRAPH_REDIRECT_URI" -DefaultValue "https://login.microsoftonline.com/common/oauth2/nativeclient"
    }
}

# 証明書情報の取得
function Get-CertificateCredentials {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$ThrowOnMissing = $false
    )
    
    return @{
        Path = Get-SecureEnvironmentVariable -VariableName "CERTIFICATE_PATH" -ThrowOnMissing:$ThrowOnMissing
        Password = Get-SecureEnvironmentVariable -VariableName "CERTIFICATE_PASSWORD" -ThrowOnMissing:$ThrowOnMissing
        Thumbprint = Get-SecureEnvironmentVariable -VariableName "CERTIFICATE_THUMBPRINT" -ThrowOnMissing:$ThrowOnMissing
    }
}

# Git認証情報の取得
function Get-GitCredentials {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$ThrowOnMissing = $false
    )
    
    return @{
        Username = Get-SecureEnvironmentVariable -VariableName "GIT_USERNAME" -ThrowOnMissing:$ThrowOnMissing
        Password = Get-SecureEnvironmentVariable -VariableName "GIT_PASSWORD" -ThrowOnMissing:$ThrowOnMissing
        RepositoryUrl = Get-SecureEnvironmentVariable -VariableName "GIT_REPOSITORY_URL" -ThrowOnMissing:$ThrowOnMissing
        Branch = Get-SecureEnvironmentVariable -VariableName "GIT_BRANCH" -DefaultValue "main"
    }
}

# SMTP認証情報の取得
function Get-SmtpCredentials {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$ThrowOnMissing = $false
    )
    
    return @{
        Server = Get-SecureEnvironmentVariable -VariableName "SMTP_SERVER" -DefaultValue "smtp.office365.com"
        Port = Get-SecureEnvironmentVariable -VariableName "SMTP_PORT" -DefaultValue "587"
        Username = Get-SecureEnvironmentVariable -VariableName "SMTP_USERNAME" -ThrowOnMissing:$ThrowOnMissing
        Password = Get-SecureEnvironmentVariable -VariableName "SMTP_PASSWORD" -ThrowOnMissing:$ThrowOnMissing
    }
}

# 環境変数の設定状況チェック
function Test-EnvironmentConfiguration {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$VerboseOutput = $false
    )
    
    $requiredVars = @(
        "AZURE_TENANT_ID",
        "AZURE_CLIENT_ID",
        "AZURE_CLIENT_SECRET",
        "EXCHANGE_ONLINE_APP_ID",
        "EXCHANGE_ONLINE_THUMBPRINT",
        "EXCHANGE_ONLINE_ORGANIZATION",
        "GRAPH_CLIENT_ID",
        "GRAPH_CLIENT_SECRET",
        "CERTIFICATE_PATH",
        "CERTIFICATE_PASSWORD",
        "GIT_USERNAME",
        "GIT_PASSWORD",
        "GIT_REPOSITORY_URL"
    )
    
    $missingVars = @()
    $setVars = @()
    
    foreach ($var in $requiredVars) {
        $value = [System.Environment]::GetEnvironmentVariable($var)
        if ([string]::IsNullOrWhiteSpace($value)) {
            $missingVars += $var
        } else {
            $setVars += $var
        }
    }
    
    if ($Verbose) {
        Write-Host "環境変数設定状況:" -ForegroundColor Cyan
        Write-Host "設定済み: $($setVars.Count)/$($requiredVars.Count)" -ForegroundColor Green
        
        if ($setVars.Count -gt 0) {
            Write-Host "設定済み変数:" -ForegroundColor Green
            foreach ($var in $setVars) {
                Write-Host "  ✓ $var" -ForegroundColor Green
            }
        }
        
        if ($missingVars.Count -gt 0) {
            Write-Host "未設定変数:" -ForegroundColor Red
            foreach ($var in $missingVars) {
                Write-Host "  ✗ $var" -ForegroundColor Red
            }
        }
    }
    
    return @{
        IsComplete = ($missingVars.Count -eq 0)
        SetVariables = $setVars
        MissingVariables = $missingVars
        CompletionPercentage = [math]::Round(($setVars.Count / $requiredVars.Count) * 100, 2)
    }
}

# 環境変数の一括設定ヘルパー
function Set-EnvironmentVariables {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Variables,
        
        [Parameter(Mandatory = $false)]
        [System.EnvironmentVariableTarget]$Target = [System.EnvironmentVariableTarget]::Process
    )
    
    $setCount = 0
    foreach ($key in $Variables.Keys) {
        try {
            [System.Environment]::SetEnvironmentVariable($key, $Variables[$key], $Target)
            $setCount++
            Write-Host "環境変数を設定しました: $key" -ForegroundColor Green
        }
        catch {
            Write-Warning "環境変数の設定に失敗しました: $key - $($_.Exception.Message)"
        }
    }
    
    Write-Host "$setCount 個の環境変数を設定しました" -ForegroundColor Green
    return $setCount
}

# 初期化関数
function Initialize-Environment {
    param(
        [Parameter(Mandatory = $false)]
        [string]$EnvFilePath = ".env",
        
        [Parameter(Mandatory = $false)]
        [switch]$VerboseOutput = $false
    )
    
    Write-Host "環境変数管理システムを初期化しています..." -ForegroundColor Cyan
    
    # .envファイルの読み込み
    $envLoaded = Import-EnvironmentFile -EnvFilePath $EnvFilePath -VerboseOutput:$VerboseOutput
    
    if ($envLoaded) {
        # 設定状況の確認
        $configStatus = Test-EnvironmentConfiguration -VerboseOutput:$VerboseOutput
        
        if ($configStatus.IsComplete) {
            Write-Host "環境設定が完了しています ($($configStatus.CompletionPercentage)%)" -ForegroundColor Green
        } else {
            Write-Host "環境設定が不完全です ($($configStatus.CompletionPercentage)%)" -ForegroundColor Yellow
            Write-Host "不足している変数を .env ファイルに追加してください" -ForegroundColor Yellow
        }
        
        return $configStatus
    } else {
        Write-Warning "環境変数の初期化に失敗しました"
        return $null
    }
}

# エクスポート関数
Export-ModuleMember -Function Import-EnvironmentFile, Get-SecureEnvironmentVariable, Get-AzureCredentials, Get-ExchangeOnlineCredentials, Get-GraphCredentials, Get-CertificateCredentials, Get-GitCredentials, Get-SmtpCredentials, Test-EnvironmentConfiguration, Set-EnvironmentVariables, Initialize-Environment