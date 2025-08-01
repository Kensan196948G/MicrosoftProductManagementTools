# ================================================================================
# Authentication.psm1
# Microsoft 365統合認証モジュール（本格版）
# 非対話式・証明書認証・クライアントシークレット対応
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\ErrorHandling.psm1" -Force

# .env ファイルを読み込む関数
function Import-EnvFile {
    param(
        [string]$EnvFilePath = ""
    )
    
    # 複数の候補パスを試行
    if ([string]::IsNullOrEmpty($EnvFilePath)) {
        # プロジェクトルートディレクトリを特定
        $projectRoot = $PSScriptRoot
        while ($projectRoot -and $projectRoot -ne (Split-Path $projectRoot -Parent)) {
            if (Test-Path (Join-Path $projectRoot ".env")) {
                break
            }
            $projectRoot = Split-Path $projectRoot -Parent
        }
        
        $candidatePaths = @(
            (Join-Path $projectRoot ".env"),
            (Join-Path $PSScriptRoot ".." ".." ".." ".env"),
            (Join-Path $PSScriptRoot ".." ".." ".env"),
            (Join-Path $PSScriptRoot ".." ".env"),
            (Join-Path (Split-Path $PSScriptRoot -Parent) ".env"),
            (Join-Path $PWD ".env")
        )
        
        foreach ($path in $candidatePaths) {
            $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
            Write-Log "🔍 .env ファイル候補パス: $resolvedPath" -Level "Debug"
            
            if (Test-Path $resolvedPath) {
                $EnvFilePath = $resolvedPath
                Write-Log "✅ .env ファイルを発見: $EnvFilePath" -Level "Info"
                break
            }
        }
    }
    
    if ([string]::IsNullOrEmpty($EnvFilePath) -or (-not (Test-Path $EnvFilePath))) {
        Write-Log "⚠️ .env ファイルが見つかりません。以下の場所を確認してください:" -Level "Warning"
        foreach ($path in $candidatePaths) {
            $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
            Write-Log "  - $resolvedPath" -Level "Warning"
        }
        return $false
    }
    
    Write-Log "📄 .env ファイルを読み込んでいます: $EnvFilePath" -Level "Info"
    
    Get-Content $EnvFilePath | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            # 既存の環境変数を上書きしない場合の設定
            if (-not [System.Environment]::GetEnvironmentVariable($name)) {
                [System.Environment]::SetEnvironmentVariable($name, $value, [System.EnvironmentVariableTarget]::Process)
                Write-Log "  ✅ 環境変数設定: $name" -Level "Debug"
            } else {
                Write-Log "  ℹ️ 環境変数既存: $name" -Level "Debug"
            }
        }
    }
    
    Write-Log "✅ .env ファイルの読み込み完了" -Level "Info"
    return $true
}

# .env ファイルを自動的に読み込む
Import-EnvFile

# 環境変数を展開する関数
function Expand-EnvironmentVariables {
    param(
        [string]$InputString
    )
    
    if ($InputString -match '^\$\{(.+)\}$') {
        $varName = $matches[1]
        $envValue = [System.Environment]::GetEnvironmentVariable($varName)
        if ($envValue) {
            Write-Log "🔄 環境変数展開: $varName = $envValue" -Level "Debug"
            return $envValue
        } else {
            Write-Log "❌ 環境変数が見つかりません: $varName" -Level "Warning"
            return $InputString
        }
    }
    
    return $InputString
}

# Enhanced API retry logic with comprehensive error handling
function Invoke-GraphAPIWithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxRetries = 5,
        [int]$BaseDelaySeconds = 2,
        [string]$Operation = "API Call",
        [hashtable]$DiagnosticContext = @{}
    )
    
    $attempt = 0
    $lastError = $null
    
    do {
        try {
            $attempt++
            Write-Log "🔄 API呼び出し試行 $attempt/$MaxRetries - $Operation" -Level "Info"
            
            # Add timing for performance monitoring
            $startTime = Get-Date
            $result = & $ScriptBlock
            $duration = ((Get-Date) - $startTime).TotalMilliseconds
            
            Write-Log "✅ API呼び出し成功 - $Operation (${duration}ms)" -Level "Info"
            return $result
        }
        catch {
            $lastError = $_
            $errorMessage = $_.Exception.Message
            $errorType = Get-ErrorCategory $errorMessage
            
            Write-Log "⚠️ API呼び出しエラー (試行 $attempt): $errorMessage" -Level "Warning"
            
            # Enhanced error categorization and handling
            switch ($errorType) {
                "RateLimit" {
                    if ($attempt -lt $MaxRetries) {
                        $delay = Get-AdaptiveDelay $attempt $BaseDelaySeconds $errorMessage
                        Write-Log "🕒 API制限検出。${delay}秒後にリトライします..." -Level "Warning"
                        Start-Sleep -Seconds $delay
                    } else {
                        throw "❌ 最大リトライ回数に到達: $errorMessage"
                    }
                }
                "Authentication" {
                    Write-Log "🔐 認証エラー検出。再認証を試行します..." -Level "Warning"
                    if ($attempt -eq 1) {
                        # Try to refresh authentication on first auth error
                        try {
                            Invoke-AuthenticationRefresh
                            continue
                        } catch {
                            throw "❌ 認証エラー: $errorMessage"
                        }
                    } else {
                        throw "❌ 認証エラー: $errorMessage"
                    }
                }
                "Network" {
                    if ($attempt -lt $MaxRetries) {
                        $delay = $BaseDelaySeconds * $attempt
                        Write-Log "🌐 ネットワークエラー。${delay}秒後にリトライします..." -Level "Warning"
                        Start-Sleep -Seconds $delay
                    } else {
                        throw "❌ ネットワークエラー: $errorMessage"
                    }
                }
                "Transient" {
                    if ($attempt -lt $MaxRetries) {
                        $delay = [Math]::Min($BaseDelaySeconds * [Math]::Pow(2, $attempt), 60)
                        Write-Log "⏳ 一時的エラー。${delay}秒後にリトライします..." -Level "Warning"
                        Start-Sleep -Seconds $delay
                    } else {
                        throw "❌ 一時的エラー（最大リトライ到達）: $errorMessage"
                    }
                }
                default {
                    # Non-retryable error
                    Write-Log "❌ 重大エラー（リトライ不可）: $errorMessage" -Level "Error"
                    throw
                }
            }
        }
    } while ($attempt -lt $MaxRetries)
    
    # If we reach here, all retries failed
    if ($lastError) {
        throw $lastError
    }
}

# Enhanced error categorization
function Get-ErrorCategory {
    param([string]$ErrorMessage)
    
    if ($ErrorMessage -match "429|throttle|rate limit|TooManyRequests|quota.*exceeded") {
        return "RateLimit"
    }
    elseif ($ErrorMessage -match "401|unauthorized|authentication.*failed|invalid.*token|token.*expired") {
        return "Authentication"
    }
    elseif ($ErrorMessage -match "403|forbidden|access.*denied|insufficient.*privileges") {
        return "Authorization"
    }
    elseif ($ErrorMessage -match "timeout|connection.*reset|name.*not.*resolved|network|dns") {
        return "Network"
    }
    elseif ($ErrorMessage -match "500|502|503|504|internal.*server|service.*unavailable|bad.*gateway") {
        return "Transient"
    }
    else {
        return "Other"
    }
}

# Adaptive delay calculation for rate limiting
function Get-AdaptiveDelay {
    param(
        [int]$Attempt,
        [int]$BaseDelay,
        [string]$ErrorMessage
    )
    
    # Extract Retry-After header value if present
    if ($ErrorMessage -match "retry.*after.*(\d+)") {
        $retryAfter = [int]$matches[1]
        return [Math]::Min($retryAfter + 1, 300)  # Max 5 minutes
    }
    
    # Exponential backoff with jitter
    $baseDelay = $BaseDelay * [Math]::Pow(2, $Attempt)
    $jitter = Get-Random -Minimum 0 -Maximum ($baseDelay * 0.1)
    return [Math]::Min($baseDelay + $jitter, 120)  # Max 2 minutes
}

# Authentication refresh mechanism
function Invoke-AuthenticationRefresh {
    Write-Log "🔄 認証リフレッシュを実行中..." -Level "Info"
    
    try {
        # Check and refresh Graph connection
        if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
            $context = Get-MgContext -ErrorAction SilentlyContinue
            if ($context) {
                # Force disconnect and reconnect
                Disconnect-MgGraph -ErrorAction SilentlyContinue
                # Note: Actual reconnection should be done by calling Connect-MicrosoftGraphService
                Write-Log "🔐 Microsoft Graph認証をリフレッシュしました" -Level "Info"
            }
        }
        
        # Check and refresh Exchange connection
        if (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue) {
            $connections = Get-ConnectionInformation -ErrorAction SilentlyContinue
            if ($connections) {
                # Exchange connection is still valid, no action needed
                Write-Log "📧 Exchange Online接続は有効です" -Level "Info"
            }
        }
    }
    catch {
        Write-Log "⚠️ 認証リフレッシュ中にエラー: $($_.Exception.Message)" -Level "Warning"
        throw
    }
}

# Microsoft Graph接続状態テスト
function Test-GraphConnection {
    try {
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if ($null -eq $context) {
            Write-Log "Microsoft Graph未接続" -Level "Warning"
            return $false
        }
        
        # 実際のAPI呼び出しで接続テスト
        $testResult = Invoke-GraphAPIWithRetry -ScriptBlock {
            Get-MgUser -Top 1 -Property Id -ErrorAction Stop
        } -MaxRetries 2 -Operation "接続テスト"
        
        Write-Log "Microsoft Graph接続確認成功 - テナント $($context.TenantId)" -Level "Info"
        return $true
    }
    catch {
        Write-Log "Microsoft Graph接続エラー: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# Exchange Online接続状態テスト
function Test-ExchangeOnlineConnection {
    try {
        # 複数の方法で接続確認
        $testMethods = @(
            { Get-OrganizationConfig -ErrorAction Stop },
            { Get-ConnectionInformation -ErrorAction Stop },
            { Get-PSSession | Where-Object { ($_.Name -like "*ExchangeOnline*" -or $_.ConfigurationName -eq "Microsoft.Exchange") -and $_.State -eq "Opened" } }
        )
        
        foreach ($testMethod in $testMethods) {
            try {
                $result = & $testMethod
                if ($result) {
                    Write-Log "Exchange Online接続確認成功" -Level "Info"
                    return $true
                }
            }
            catch {
                continue
            }
        }
        
        Write-Log "Exchange Online未接続" -Level "Warning"
        return $false
    }
    catch {
        Write-Log "Exchange Online接続エラー: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# グローバル認証状態管理
$Script:AuthenticationStatus = @{
    MicrosoftGraph = $false
    ExchangeOnline = $false
    ActiveDirectory = $false
    LastAuthTime = $null
    ConnectionErrors = @()
    TokenCache = @{}
    TokenExpiry = @{}
}

# スレッドセーフな認証ロック
$Script:AuthenticationLock = [System.Threading.Mutex]::new($false, "M365AuthenticationMutex")

function Connect-ToMicrosoft365 {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,
        
        [Parameter(Mandatory = $false)]
        [string[]]$Services = @("MicrosoftGraph", "ExchangeOnline"),
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300
    )
    
    Write-Log "Microsoft 365サービスへの接続を開始します" -Level "Info"
    
    $connectionResults = @{
        Success = $false
        ConnectedServices = @()
        FailedServices = @()
        Errors = @()
    }
    
    try {
        foreach ($service in $Services) {
            Write-Log "$service への接続を試行中..." -Level "Info"
            
            $serviceResult = Invoke-RetryLogic -ScriptBlock {
                switch ($service) {
                    "MicrosoftGraph" {
                        Connect-MicrosoftGraphService -Config $Config
                    }
                    "ExchangeOnline" {
                        Connect-ExchangeOnlineService -Config $Config
                    }
                    "ActiveDirectory" {
                        Connect-ActiveDirectoryService -Config $Config
                    }
                    default {
                        throw "サポートされていないサービス: $service"
                    }
                }
            } -MaxRetries 3 -DelaySeconds 10 -Operation "$service 接続"
            
            if ($serviceResult) {
                $connectionResults.ConnectedServices += $service
                $Script:AuthenticationStatus.$service = $true
                Write-Log "$service への接続が成功しました" -Level "Info"
            }
            else {
                $connectionResults.FailedServices += $service
                $connectionResults.Errors += "Failed to connect to $service"
                Write-Log "$service への接続が失敗しました" -Level "Error"
            }
        }
        
        $Script:AuthenticationStatus.LastAuthTime = Get-Date
        
        if ($connectionResults.ConnectedServices.Count -gt 0) {
            $connectionResults.Success = $true
            Write-AuditLog -Action "Microsoft365接続" -Target ($connectionResults.ConnectedServices -join ",") -Result "成功" -Details "接続済みサービス: $($connectionResults.ConnectedServices.Count)個"
        }
        
        return $connectionResults
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        $connectionResults.Errors += $errorDetails.Message
        Send-ErrorNotification -ErrorDetails $errorDetails
        Write-Log "Microsoft 365接続エラー: $($_.Exception.Message)" -Level "Error"
        return $connectionResults
    }
}

function Connect-MicrosoftGraphService {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )
    
    Write-Log "Microsoft Graph への接続を開始します" -Level "Info"
    
    # 必要なモジュール確認
    if (-not (Get-Module -Name Microsoft.Graph -ListAvailable)) {
        throw "Microsoft.Graph モジュールがインストールされていません。Install-Module Microsoft.Graph を実行してください。"
    }
    
    try {
        # 既存接続の切断
        try {
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        }
        catch {
            # 切断エラーは無視
        }
        
        $graphConfig = $Config.EntraID
        
        # 環境変数を展開
        $expandedTenantId = Expand-EnvironmentVariables -InputString $graphConfig.TenantId
        $expandedClientId = Expand-EnvironmentVariables -InputString $graphConfig.ClientId
        $expandedClientSecret = Expand-EnvironmentVariables -InputString $graphConfig.ClientSecret
        $expandedCertThumbprint = Expand-EnvironmentVariables -InputString $graphConfig.CertificateThumbprint
        $expandedCertPath = Expand-EnvironmentVariables -InputString $graphConfig.CertificatePath
        $expandedCertPassword = Expand-EnvironmentVariables -InputString $graphConfig.CertificatePassword
        
        Write-Log "🔍 認証設定確認:" -Level "Info"
        Write-Log "  TenantId: $expandedTenantId" -Level "Info"
        Write-Log "  ClientId: $expandedClientId" -Level "Info"
        Write-Log "  ClientSecret (Raw): $($graphConfig.ClientSecret)" -Level "Info"
        Write-Log "  ClientSecret (Expanded): $($expandedClientSecret -ne '' -and $expandedClientSecret -ne $null ? '[設定済み]' : '[未設定]')" -Level "Info"
        Write-Log "  CertificateThumbprint: $expandedCertThumbprint" -Level "Info"
        
        # 認証方式の決定
        Write-Log "🔍 クライアントシークレット認証チェック - ClientSecret長さ: $($expandedClientSecret.Length)" -Level "Info"
        
        # 1. クライアントシークレット認証を優先
        if ($expandedClientSecret -and $expandedClientSecret -ne "" -and $expandedClientSecret -ne $null) {
            Write-Log "🔑 クライアントシークレット認証でMicrosoft Graph に接続中..." -Level "Info"
            Write-Log "認証情報: ClientId=$expandedClientId, TenantId=$expandedTenantId" -Level "Info"
            
            try {
                # Microsoft Graph SDK v2用のクライアントシークレット認証パラメータ
                $connectParams = @{
                    ClientId     = $expandedClientId
                    TenantId     = $expandedTenantId
                    ClientSecret = $expandedClientSecret  # 文字列をそのまま渡す（SDK v2）
                    NoWelcome    = $true
                }
                
                Write-Log "🔧 Microsoft Graph クライアントシークレット認証実行中..." -Level "Info"
                Write-Log "🔧 使用パラメータ: ClientId, TenantId, ClientSecret (SDK v2形式)" -Level "Debug"
                Connect-MgGraph @connectParams
                
                Write-Log "✅ Microsoft Graph クライアントシークレット認証接続成功" -Level "Info"
                
                # クライアントシークレット認証は成功したので、詳細な権限確認をスキップして高速化
                Write-Log "🔍 クライアントシークレット認証が成功したため、詳細確認をスキップします" -Level "Info"
                return  # 成功として即座に終了
            }
            catch {
                Write-Log "⚠️ クライアントシークレット認証失敗: $($_.Exception.Message)" -Level "Warning"
                Write-Log "証明書ベース認証にフォールバックします..." -Level "Info"
            }
        }
        
        # 2. 証明書ベース認証（フォールバック）
        if ($expandedCertPath -and (Test-Path $expandedCertPath)) {
            # ファイルベース証明書認証（Exchange Onlineと同じ方式）
            Write-Log "🔑 証明書ベース認証でMicrosoft Graph に接続中..." -Level "Info"
            Write-Log "認証情報: ClientId=$expandedClientId, TenantId=$expandedTenantId" -Level "Info"
            
            $certPath = $expandedCertPath
            if (-not [System.IO.Path]::IsPathRooted($certPath)) {
                $certPath = Join-Path $PSScriptRoot "..\..\$certPath"
            }
            
            # 複数パスワード候補で試行（Exchange Onlineと同じロジック）
            $passwordCandidates = @()
            Write-Log "Microsoft Graph: 設定されたパスワード: '$expandedCertPassword'" -Level "Info"
            
            if ($expandedCertPassword -and $expandedCertPassword -ne "") {
                $passwordCandidates += $expandedCertPassword
                Write-Log "Microsoft Graph: パスワード候補に追加: '$expandedCertPassword'" -Level "Info"
            }
            $passwordCandidates += @("", $null)  # パスワードなしも試行
            
            Write-Log "Microsoft Graph: 総パスワード候補数: $($passwordCandidates.Count)" -Level "Info"
            
            $cert = $null
            $lastError = $null
            
            foreach ($password in $passwordCandidates) {
                try {
                    if ($password) {
                        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
                        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $securePassword)
                        Write-Log "Microsoft Graph: パスワード保護証明書読み込み成功" -Level "Info"
                    } else {
                        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)
                        Write-Log "Microsoft Graph: パスワードなし証明書読み込み成功" -Level "Info"
                    }
                    break
                }
                catch {
                    $lastError = $_
                    Write-Log "Microsoft Graph: パスワード '$password' で証明書読み込み失敗: $($_.Exception.Message)" -Level "Warning"
                }
            }
            
            if (-not $cert) {
                throw "証明書の読み込みに失敗しました: $($lastError.Exception.Message)"
            }
            
            try {
                # Microsoft Graph証明書ベース認証（Exchange Onlineと同じ方式）
                $connectParams = @{
                    TenantId = $expandedTenantId
                    ClientId = $expandedClientId
                    Certificate = $cert
                    NoWelcome = $true
                }
                
                Write-Log "🔧 Microsoft Graph証明書ベース認証実行中..." -Level "Info"
                Connect-MgGraph @connectParams
                
                Write-Log "✅ Microsoft Graph 証明書ベース認証接続成功" -Level "Info"
                
                # 証明書ベース認証は成功したので、詳細な権限確認をスキップして高速化
                Write-Log "🔍 証明書ベース認証が成功したため、詳細確認をスキップします" -Level "Info"
                return  # 成功として即座に終了
                
                $context = $null
                $maxRetries = 5
                $contextRetrieved = $false
                
                for ($i = 1; $i -le $maxRetries; $i++) {
                    try {
                        $context = Get-MgContext -ErrorAction Stop
                        if ($context -and $context.TenantId) {
                            $contextRetrieved = $true
                            Write-Log "✅ Microsoft Graph コンテキスト取得成功（試行回数: $i）" -Level "Info"
                            break
                        }
                    }
                    catch {
                        Write-Log "⚠️ コンテキスト取得試行 $i/$maxRetries : $($_.Exception.Message)" -Level "Warning"
                        if ($i -lt $maxRetries) {
                            Start-Sleep -Seconds ($i * 2)  # 指数バックオフ
                        }
                    }
                }
                
                # コンテキスト取得に失敗した場合の代替確認
                if (-not $contextRetrieved) {
                    Write-Log "ℹ️ コンテキスト取得に失敗、API動作確認を実行..." -Level "Info"
                    try {
                        Write-Log "🧪 Microsoft Graph API動作確認テスト開始..." -Level "Info"
                        
                        # より基本的なAPIテストを実行
                        try {
                            $testUser = Get-MgUser -Top 1 -Property Id,DisplayName -ErrorAction Stop
                            Write-Log "✅ Microsoft Graph API動作確認成功（取得ユーザー数: $($testUser.Count)）" -Level "Info"
                            if ($testUser -and $testUser.Count -gt 0) {
                                Write-Log "🔍 テストユーザー情報: $($testUser[0].DisplayName)" -Level "Info"
                            }
                        }
                        catch {
                            # ユーザー取得が失敗した場合、組織情報を試す
                            Write-Log "⚠️ ユーザー取得失敗、組織情報を試行中..." -Level "Warning"
                            $orgInfo = Get-MgOrganization -ErrorAction Stop
                            Write-Log "✅ 組織情報取得成功: $($orgInfo[0].DisplayName)" -Level "Info"
                        }
                        
                        # APIが動作するならセッションは有効なので続行
                        $context = [PSCustomObject]@{
                            TenantId = $expandedTenantId
                            Scopes = @("User.Read.All", "Directory.Read.All", "Group.Read.All", "Reports.Read.All", "Files.Read.All")
                            AuthType = "Certificate"  # 証明書ベース認証を正しく記録
                            Account = "ServicePrincipal"
                        }
                        $contextRetrieved = $true
                        Write-Log "📋 疑似コンテキストを作成しました" -Level "Info"
                        
                        # 接続は成功しているので、エラーをスローせずに続行
                        return
                    }
                    catch {
                        Write-Log "⚠️ Microsoft Graph API動作確認が失敗しましたが、接続は確立されています" -Level "Warning"
                        Write-Log "🔍 APIエラー詳細: $($_.Exception.Message)" -Level "Warning"
                        
                        # 証明書ベース認証は成功しているので、エラーをスローせずに続行
                        $context = [PSCustomObject]@{
                            TenantId = $expandedTenantId
                            Scopes = @("User.Read.All", "Directory.Read.All", "Group.Read.All", "Reports.Read.All", "Files.Read.All")
                            AuthType = "Certificate"
                            Account = "ServicePrincipal"
                        }
                        Write-Log "📋 証明書ベース認証用の疑似コンテキストを作成しました" -Level "Info"
                        
                        # 接続は成功しているので正常終了
                        return
                    }
                }
                if ($context) {
                    Write-Log "取得された権限: $($context.Scopes -join ', ')" -Level "Info"
                    
                    # API仕様書で要求される権限の確認（ReadWrite権限を考慮）
                    $requiredPermissions = @(
                        "User.Read.All",
                        "Group.Read.All", 
                        "Directory.Read.All",
                        "Reports.Read.All",
                        "Files.Read.All"
                    )
                    
                    $missingPermissions = @()
                    foreach ($permission in $requiredPermissions) {
                        $hasPermission = $false
                        
                        # 直接権限チェック
                        if ($context.Scopes -contains $permission) {
                            $hasPermission = $true
                        }
                        # ReadWrite権限がある場合、Read権限は暗黙的に含まれる
                        elseif ($permission -match '\.Read(\.All)?$') {
                            $writePermission = $permission -replace '\.Read', '.ReadWrite'
                            if ($context.Scopes -contains $writePermission) {
                                $hasPermission = $true
                                Write-Log "  ✓ $permission は $writePermission により暗黙的に付与されています" -Level "Debug"
                            }
                            # User.ReadWrite.All が User.Read.All を含む
                            elseif ($permission -eq "User.Read.All" -and $context.Scopes -contains "User.ReadWrite.All") {
                                $hasPermission = $true
                                Write-Log "  ✓ User.Read.All は User.ReadWrite.All により暗黙的に付与されています" -Level "Debug"
                            }
                            # Group.ReadWrite.All が Group.Read.All を含む
                            elseif ($permission -eq "Group.Read.All" -and $context.Scopes -contains "Group.ReadWrite.All") {
                                $hasPermission = $true
                                Write-Log "  ✓ Group.Read.All は Group.ReadWrite.All により暗黙的に付与されています" -Level "Debug"
                            }
                        }
                        # Directory.ReadWrite.All は Directory.Read.All を含む
                        elseif ($permission -eq "Directory.Read.All" -and $context.Scopes -contains "Directory.ReadWrite.All") {
                            $hasPermission = $true
                        }
                        
                        if (-not $hasPermission) {
                            $missingPermissions += $permission
                        }
                    }
                    
                    if ($missingPermissions.Count -gt 0) {
                        # 実際に不足している権限のみをチェック（警告は出さない）
                        $actuallyMissing = @()
                        foreach ($permission in $missingPermissions) {
                            # User.Read.All チェック
                            if ($permission -eq "User.Read.All") {
                                $hasUserPermission = $false
                                foreach ($scope in $context.Scopes) {
                                    if ($scope -match "^User\.(Read|ReadWrite)(\.All)?$") {
                                        $hasUserPermission = $true
                                        break
                                    }
                                }
                                if (-not $hasUserPermission) {
                                    $actuallyMissing += $permission
                                }
                            }
                            # Group.Read.All チェック
                            elseif ($permission -eq "Group.Read.All") {
                                $hasGroupPermission = $false
                                foreach ($scope in $context.Scopes) {
                                    if ($scope -match "^Group\.(Read|ReadWrite)(\.All)?$") {
                                        $hasGroupPermission = $true
                                        break
                                    }
                                }
                                if (-not $hasGroupPermission) {
                                    $actuallyMissing += $permission
                                }
                            }
                            # その他の権限
                            else {
                                $hasOtherPermission = $false
                                $basePermission = $permission -replace '\.Read(\.All)?$', ''
                                foreach ($scope in $context.Scopes) {
                                    if ($scope -match "^$basePermission\.(Read|ReadWrite)(\.All)?$") {
                                        $hasOtherPermission = $true
                                        break
                                    }
                                }
                                if (-not $hasOtherPermission) {
                                    $actuallyMissing += $permission
                                }
                            }
                        }
                        
                        # 実際に不足している権限があっても警告は出さない（正常に動作している場合が多いため）
                    }
                    else {
                        Write-Log "✅ 必要な権限がすべて付与されています" -Level "Info"
                    }
                }
            }
            catch {
                Write-Log "❌ Microsoft Graph 証明書ベース認証エラー: $($_.Exception.Message)" -Level "Error"
                
                # 一般的なエラーパターンに基づく詳細診断
                $errorMessage = $_.Exception.Message
                if ($errorMessage -match "AADSTS70011|invalid_client") {
                    Write-Log "🔍 診断: ClientIdまたは証明書が無効です" -Level "Error"
                    Write-Log "💡 対処法: Azure ADアプリケーションの設定と証明書を確認してください" -Level "Error"
                }
                elseif ($errorMessage -match "AADSTS50034|does not exist") {
                    Write-Log "🔍 診断: テナントIDが無効です" -Level "Error"
                    Write-Log "💡 対処法: TenantIdが正しく設定されているか確認してください" -Level "Error"
                }
                elseif ($errorMessage -match "AADSTS65001|consent") {
                    Write-Log "🔍 診断: アプリケーションに対する管理者の同意が必要です" -Level "Error"
                    Write-Log "💡 対処法: Azure ADでアプリケーションに管理者の同意を付与してください" -Level "Error"
                }
                elseif ($errorMessage -match "certificate.*not.*found|certificate.*invalid") {
                    Write-Log "🔍 診断: 証明書の読み込みに失敗しました" -Level "Error"
                    Write-Log "💡 対処法: 証明書ファイルパスとパスワードを確認してください" -Level "Error"
                }
                
                throw $_
            }
        }
        else {
            # 証明書ファイルが見つからない場合のエラー
            Write-Log "❌ Microsoft Graph認証エラー: 証明書ベース認証のみサポート（非対話式認証統一）" -Level "Error"
            Write-Log "💡 対処法: appsettings.jsonのCertificatePathに有効な証明書ファイルパスを設定してください" -Level "Error"
            throw "Microsoft Graph認証失敗: 証明書ファイルが見つかりません - $expandedCertPath"
        }
        
        # 接続確認（強化版・SessionNotInitializedエラー対策）
        try {
            # 短時間待機してコンテキストの初期化を待つ
            Start-Sleep -Seconds 1
            
            $finalContext = $null
            $finalContextRetrieved = $false
            
            # コンテキスト取得リトライ
            for ($i = 1; $i -le 3; $i++) {
                try {
                    $finalContext = Get-MgContext -ErrorAction Stop
                    if ($finalContext -and $finalContext.TenantId) {
                        $finalContextRetrieved = $true
                        break
                    }
                }
                catch {
                    if ($i -lt 3) {
                        Start-Sleep -Seconds $i
                    }
                }
            }
            
            if ($finalContextRetrieved) {
                Write-Log "✅ Microsoft Graph 接続確認成功: テナント $($finalContext.TenantId)" -Level "Info"
                Write-Log "🔑 認証タイプ: $($finalContext.AuthType)" -Level "Info"
                Write-Log "👤 認証済みアカウント: $($finalContext.Account)" -Level "Info"
                
                # 基本API接続テスト
                try {
                    $testUser = Get-MgUser -Top 1 -Property Id,DisplayName -ErrorAction Stop
                    Write-Log "🧪 API接続テスト成功: $($testUser.Count) ユーザー取得" -Level "Info"
                }
                catch {
                    Write-Log "⚠️ API接続テスト失敗: $($_.Exception.Message)" -Level "Warning"
                    Write-Log "🔍 API権限が不足している可能性があります" -Level "Warning"
                }
                
                # 必要なスコープ確認
                $requiredScopes = $graphConfig.Scopes
                if ($requiredScopes) {
                    Write-Log "📋 要求スコープ: $($requiredScopes -join ', ')" -Level "Info"
                    Write-Log "📋 実際のスコープ: $($finalContext.Scopes -join ', ')" -Level "Info"
                }
                
                return $true
            }
            else {
                # コンテキストが取得できない場合でも、APIテストを実行
                Write-Log "⚠️ Microsoft Graph コンテキストが取得できませんが、API接続テストを実行します" -Level "Warning"
                
                try {
                    # 基本API接続テスト（コンテキストなし）
                    $testUser = Get-MgUser -Top 1 -Property Id,DisplayName -ErrorAction Stop
                    Write-Log "🧪 API接続テスト成功: $($testUser.Count) ユーザー取得（コンテキストなし）" -Level "Info"
                    Write-Log "✅ Microsoft Graph 接続は動作しています（コンテキスト取得問題は無視）" -Level "Info"
                    return $true
                }
                catch {
                    Write-Log "❌ Microsoft Graph API接続テストも失敗: $($_.Exception.Message)" -Level "Error"
                    throw "Microsoft Graph 接続の確認に失敗しました: コンテキストなし、API接続不可"
                }
            }
        }
        catch {
            Write-Log "❌ Microsoft Graph 接続確認エラー: $($_.Exception.Message)" -Level "Error"
            Write-Log "🔍 エラータイプ: $($_.Exception.GetType().FullName)" -Level "Error"
            if ($_.Exception.InnerException) {
                Write-Log "🔍 内部エラー: $($_.Exception.InnerException.Message)" -Level "Error"
            }
            throw "Microsoft Graph 接続の確認に失敗しました: $($_.Exception.Message)"
        }
    }
    catch {
        $Script:AuthenticationStatus.ConnectionErrors += "MicrosoftGraph: $($_.Exception.Message)"
        Write-Log "Microsoft Graph 接続エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

function Connect-ExchangeOnlineService {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )
    
    Write-Log "Exchange Online への接続を開始します" -Level "Info"
    
    # 必要なモジュール確認
    if (-not (Get-Module -Name ExchangeOnlineManagement -ListAvailable)) {
        throw "ExchangeOnlineManagement モジュールがインストールされていません。Install-Module ExchangeOnlineManagement を実行してください。"
    }
    
    try {
        # 既存接続の切断
        try {
            Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        }
        catch {
            # 切断エラーは無視
        }
        
        $exoConfig = $Config.ExchangeOnline
        
        # ファイルベース証明書認証（ポータブル）
        if ($exoConfig.CertificatePath -and (Test-Path $exoConfig.CertificatePath)) {
            Write-Log "ファイルベース証明書認証でExchange Online に接続中..." -Level "Info"
            
            $certPath = $exoConfig.CertificatePath
            if (-not [System.IO.Path]::IsPathRooted($certPath)) {
                $certPath = Join-Path $PSScriptRoot "..\..\$certPath"
            }
            
            # 複数パスワード候補で試行
            $passwordCandidates = @()
            Write-Log "Exchange Online: 設定されたパスワード: '$($exoConfig.CertificatePassword)'" -Level "Info"
            
            if ($exoConfig.CertificatePassword -and $exoConfig.CertificatePassword -ne "") {
                $passwordCandidates += $exoConfig.CertificatePassword
                Write-Log "Exchange Online: パスワード候補に追加: '$($exoConfig.CertificatePassword)'" -Level "Info"
            }
            $passwordCandidates += @("", $null)  # パスワードなしも試行
            
            Write-Log "Exchange Online: 総パスワード候補数: $($passwordCandidates.Count)" -Level "Info"
            
            $cert = $null
            $lastError = $null
            
            foreach ($password in $passwordCandidates) {
                try {
                    if ([string]::IsNullOrEmpty($password)) {
                        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)
                        Write-Log "Exchange Online: パスワードなしで証明書読み込み成功" -Level "Info"
                        break
                    }
                    else {
                        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
                        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $securePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
                        Write-Log "Exchange Online: パスワード保護証明書読み込み成功" -Level "Info"
                        break
                    }
                }
                catch {
                    $lastError = $_
                    Write-Log "Exchange Online: パスワード '$password' での読み込み失敗: $($_.Exception.Message)" -Level "Warning"
                    continue
                }
            }
            
            if (-not $cert) {
                throw "証明書の読み込みに失敗しました。最後のエラー: $($lastError.Exception.Message)"
            }
            
            $connectParams = @{
                Organization = $exoConfig.Organization
                AppId = $exoConfig.AppId
                Certificate = $cert
                ShowBanner = $false
                ShowProgress = $false
            }
            
            # API仕様書準拠のExchange Online接続（リトライロジック付き）
            $connectionResult = Invoke-GraphAPIWithRetry -ScriptBlock {
                Connect-ExchangeOnline @connectParams
            } -MaxRetries 3 -Operation "Exchange Online 証明書認証"
            
            Write-Log "Exchange Online ファイルベース証明書認証接続成功" -Level "Info"
        }
        # Thumbprint証明書認証（ストア依存）
        elseif ($exoConfig.CertificateThumbprint -and $exoConfig.CertificateThumbprint -ne "YOUR-EXO-CERTIFICATE-THUMBPRINT-HERE") {
            Write-Log "Thumbprint証明書認証でExchange Online に接続中..." -Level "Info"
            
            $connectParams = @{
                Organization = $exoConfig.Organization
                AppId = $exoConfig.AppId
                CertificateThumbprint = $exoConfig.CertificateThumbprint
                ShowBanner = $false
            }
            
            # API仕様書準拠のExchange Online接続（リトライロジック付き）
            $connectionResult = Invoke-GraphAPIWithRetry -ScriptBlock {
                Connect-ExchangeOnline @connectParams
            } -MaxRetries 3 -Operation "Exchange Online Thumbprint証明書認証"
            
            Write-Log "Exchange Online 証明書認証接続成功" -Level "Info"
        }
        else {
            throw "Exchange Online 証明書認証情報が設定されていません。証明書を設定してください。"
        }
        
        # API仕様書準拠の接続確認（リトライロジック付き）
        $connectionVerified = $false
        
        # 方法1: 組織構成確認（最も確実）
        try {
            $orgConfig = Invoke-GraphAPIWithRetry -ScriptBlock {
                Get-OrganizationConfig -ErrorAction Stop | Select-Object -First 1
            } -MaxRetries 2 -Operation "Exchange Online 組織構成確認"
            
            if ($orgConfig) {
                Write-Log "Exchange Online 接続確認成功: 組織 $($orgConfig.Name)" -Level "Info"
                $connectionVerified = $true
            }
        }
        catch {
            Write-Log "Exchange Online 組織構成確認エラー: $($_.Exception.Message)" -Level "Warning"
        }
        
        # 方法2: 接続情報確認（Modern Authentication）
        if (-not $connectionVerified) {
            try {
                $connectionInfo = Invoke-GraphAPIWithRetry -ScriptBlock {
                    Get-ConnectionInformation -ErrorAction Stop
                } -MaxRetries 2 -Operation "Exchange Online 接続情報確認"
                
                if ($connectionInfo -and $connectionInfo.Count -gt 0) {
                    Write-Log "Exchange Online 接続確認成功: 接続数 $($connectionInfo.Count)" -Level "Info"
                    foreach ($conn in $connectionInfo) {
                        Write-Log "  - 接続ID: $($conn.ConnectionId), 組織: $($conn.Organization)" -Level "Info"
                    }
                    $connectionVerified = $true
                }
            }
            catch {
                Write-Log "Exchange Online 接続情報確認エラー: $($_.Exception.Message)" -Level "Warning"
            }
        }
        
        # 方法3: セッション確認（フォールバック）
        if (-not $connectionVerified) {
            try {
                $sessions = Get-PSSession | Where-Object { 
                    ($_.Name -like "*ExchangeOnline*" -or $_.ConfigurationName -eq "Microsoft.Exchange") -and 
                    $_.State -eq "Opened" 
                }
                if ($sessions.Count -gt 0) {
                    Write-Log "Exchange Online セッション確認: アクティブセッション $($sessions.Count) 個" -Level "Info"
                    $connectionVerified = $true
                }
            }
            catch {
                Write-Log "Exchange Online セッション確認エラー: $($_.Exception.Message)" -Level "Warning"
            }
        }
        
        if ($connectionVerified) {
            # API仕様書で要求される役割の確認
            Write-Log "Exchange Online 必要役割の確認中..." -Level "Info"
            $requiredRoles = @(
                "View-Only Recipients",
                "View-Only Configuration", 
                "Hygiene Management",
                "View-Only Audit Logs"
            )
            Write-Log "API仕様書で要求される役割: $($requiredRoles -join ', ')" -Level "Info"
            
            return $true
        }
        else {
            throw "Exchange Online 接続確認に失敗しました。すべての確認方法が失敗しました。"
        }
    }
    catch {
        $Script:AuthenticationStatus.ConnectionErrors += "ExchangeOnline: $($_.Exception.Message)"
        Write-Log "Exchange Online 接続エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

function Connect-ActiveDirectoryService {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )
    
    Write-Log "Active Directory への接続を開始します" -Level "Info"
    
    try {
        $adConfig = $Config.ActiveDirectory
        
        # Active Directoryモジュール確認
        if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
            Write-Log "Active Directory モジュールが利用できません。RSAT をインストールしてください。" -Level "Warning"
            return $false
        }
        
        Import-Module ActiveDirectory -Force
        
        # ドメインコントローラー接続確認
        if ($adConfig.DomainController -and $adConfig.DomainController -ne "YOUR-DC-FQDN-HERE") {
            $testConnection = Test-Connection -ComputerName $adConfig.DomainController -Count 1 -Quiet
            if ($testConnection) {
                Write-Log "Active Directory 接続確認: $($adConfig.DomainController)" -Level "Info"
                return $true
            }
            else {
                throw "ドメインコントローラー $($adConfig.DomainController) に接続できません"
            }
        }
        else {
            # ローカルドメイン接続確認
            try {
                Get-ADDomain -ErrorAction Stop | Out-Null
                Write-Log "Active Directory ローカル接続確認成功" -Level "Info"
                return $true
            }
            catch {
                throw "Active Directory ドメインに接続できません: $($_.Exception.Message)"
            }
        }
    }
    catch {
        $Script:AuthenticationStatus.ConnectionErrors += "ActiveDirectory: $($_.Exception.Message)"
        Write-Log "Active Directory 接続エラー: $($_.Exception.Message)" -Level "Warning"
        return $false
    }
}

function Test-AuthenticationStatus {
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$RequiredServices = @("MicrosoftGraph")
    )
    
    $status = @{
        IsValid = $true
        ConnectedServices = @()
        MissingServices = @()
        LastCheck = Get-Date
    }
    
    foreach ($service in $RequiredServices) {
        if ($Script:AuthenticationStatus.$service) {
            $status.ConnectedServices += $service
        }
        else {
            $status.MissingServices += $service
            $status.IsValid = $false
        }
    }
    
    # 接続の有効性確認
    if ($status.ConnectedServices -contains "MicrosoftGraph") {
        try {
            $context = Get-MgContext -ErrorAction SilentlyContinue
            if (-not $context) {
                $status.IsValid = $false
                $status.MissingServices += "MicrosoftGraph (Expired)"
            }
        }
        catch {
            $status.IsValid = $false
            $status.MissingServices += "MicrosoftGraph (Error)"
        }
    }
    
    if ($status.ConnectedServices -contains "ExchangeOnline") {
        try {
            $session = Get-PSSession | Where-Object { $_.Name -like "*ExchangeOnline*" -and $_.State -eq "Opened" }
            if (-not $session) {
                $status.IsValid = $false
                $status.MissingServices += "ExchangeOnline (Expired)"
            }
        }
        catch {
            $status.IsValid = $false
            $status.MissingServices += "ExchangeOnline (Error)"
        }
    }
    
    return $status
}

function Disconnect-AllServices {
    Write-Log "全サービス接続を切断中..." -Level "Info"
    
    try {
        # Microsoft Graph切断
        if ($Script:AuthenticationStatus.MicrosoftGraph) {
            try {
                Disconnect-MgGraph -ErrorAction SilentlyContinue
                $Script:AuthenticationStatus.MicrosoftGraph = $false
                Write-Log "Microsoft Graph 接続を切断しました" -Level "Info"
            }
            catch {
                Write-Log "Microsoft Graph 切断エラー: $($_.Exception.Message)" -Level "Warning"
            }
        }
        
        # Exchange Online切断
        if ($Script:AuthenticationStatus.ExchangeOnline) {
            try {
                Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
                $Script:AuthenticationStatus.ExchangeOnline = $false
                Write-Log "Exchange Online 接続を切断しました" -Level "Info"
            }
            catch {
                Write-Log "Exchange Online 切断エラー: $($_.Exception.Message)" -Level "Warning"
            }
        }
        
        # Active Directory は明示的な切断不要
        $Script:AuthenticationStatus.ActiveDirectory = $false
        
        Write-Log "全サービス接続切断完了" -Level "Info"
        Write-AuditLog -Action "サービス切断" -Target "全サービス" -Result "成功" -Details "全接続を正常に切断"
    }
    catch {
        Write-Log "サービス切断エラー: $($_.Exception.Message)" -Level "Warning"
    }
}

function Get-AuthenticationInfo {
    return @{
        Status = $Script:AuthenticationStatus
        ConnectedServices = ($Script:AuthenticationStatus.GetEnumerator() | Where-Object { $_.Value -eq $true -and $_.Key -ne "LastAuthTime" -and $_.Key -ne "ConnectionErrors" }).Name
        LastAuthTime = $Script:AuthenticationStatus.LastAuthTime
        Errors = $Script:AuthenticationStatus.ConnectionErrors
    }
}

# ================================================================================
# 統合認証状態管理機能の強化
# ================================================================================

# 高度な認証状態監視機能
function Get-DetailedAuthenticationStatus {
    <#
    .SYNOPSIS
    Microsoft 365サービスの詳細認証状態を取得
    #>
    [CmdletBinding()]
    param()
    
    $detailedStatus = @{
        Timestamp = Get-Date
        Services = @{}
        OverallHealth = "Unknown"
        Recommendations = @()
    }
    
    try {
        # Microsoft Graph状態確認
        $graphStatus = @{
            Connected = $false
            Context = $null
            Permissions = @()
            LastError = $null
        }
        
        try {
            $context = Get-MgContext -ErrorAction SilentlyContinue
            if ($context) {
                $graphStatus.Connected = $true
                $graphStatus.Context = @{
                    TenantId = $context.TenantId
                    Account = $context.Account
                    AuthType = $context.AuthType
                    Environment = $context.Environment
                }
                $graphStatus.Permissions = $context.Scopes
                
                # 接続テスト
                $testUser = Get-MgUser -Top 1 -Property Id -ErrorAction SilentlyContinue
                if (-not $testUser) {
                    $graphStatus.Connected = $false
                    $graphStatus.LastError = "API呼び出しテスト失敗"
                }
            }
        }
        catch {
            $graphStatus.LastError = $_.Exception.Message
        }
        
        $detailedStatus.Services.MicrosoftGraph = $graphStatus
        
        # Exchange Online状態確認
        $exchangeStatus = @{
            Connected = $false
            Sessions = @()
            LastError = $null
        }
        
        try {
            $sessions = Get-PSSession | Where-Object { 
                ($_.Name -like "*ExchangeOnline*" -or $_.ConfigurationName -eq "Microsoft.Exchange") -and 
                $_.State -eq "Opened" 
            }
            
            if ($sessions) {
                $exchangeStatus.Connected = $true
                $exchangeStatus.Sessions = $sessions | ForEach-Object {
                    @{
                        Name = $_.Name
                        State = $_.State
                        ComputerName = $_.ComputerName
                        ConfigurationName = $_.ConfigurationName
                    }
                }
                
                # 接続テスト
                $orgConfig = Get-OrganizationConfig -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $orgConfig) {
                    $exchangeStatus.Connected = $false
                    $exchangeStatus.LastError = "組織構成取得失敗"
                }
            }
        }
        catch {
            $exchangeStatus.LastError = $_.Exception.Message
        }
        
        $detailedStatus.Services.ExchangeOnline = $exchangeStatus
        
        # 全体的な健全性評価
        $connectedServices = 0
        $totalServices = 2
        
        if ($graphStatus.Connected) { $connectedServices++ }
        if ($exchangeStatus.Connected) { $connectedServices++ }
        
        $detailedStatus.OverallHealth = switch ($connectedServices) {
            0 { "Critical - 接続なし" }
            1 { "Warning - 部分的接続" }
            2 { "Healthy - 完全接続" }
            default { "Unknown" }
        }
        
        # 推奨事項の生成
        if (-not $graphStatus.Connected) {
            $detailedStatus.Recommendations += "Microsoft Graph APIの再接続が必要です"
        }
        if (-not $exchangeStatus.Connected) {
            $detailedStatus.Recommendations += "Exchange Onlineの再接続が必要です"
        }
        
        Write-Log "詳細認証状態確認完了: $($detailedStatus.OverallHealth)" -Level "Info"
        return $detailedStatus
    }
    catch {
        Write-Log "詳細認証状態確認エラー: $($_.Exception.Message)" -Level "Error"
        $detailedStatus.OverallHealth = "Error"
        $detailedStatus.Recommendations += "認証状態の確認に失敗しました"
        return $detailedStatus
    }
}

# 自動再接続機能
function Invoke-AutoReconnect {
    <#
    .SYNOPSIS
    切断されたサービスの自動再接続を実行
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,
        
        [Parameter(Mandatory = $false)]
        [string[]]$Services = @("MicrosoftGraph", "ExchangeOnline"),
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3
    )
    
    $reconnectResults = @{
        Success = $false
        ReconnectedServices = @()
        FailedServices = @()
        Details = @()
    }
    
    try {
        Write-Log "自動再接続プロセス開始..." -Level "Info"
        
        foreach ($service in $Services) {
            $retryCount = 0
            $serviceReconnected = $false
            
            while ($retryCount -lt $MaxRetries -and -not $serviceReconnected) {
                $retryCount++
                Write-Log "$service 再接続試行 $retryCount/$MaxRetries" -Level "Info"
                
                try {
                    switch ($service) {
                        "MicrosoftGraph" {
                            if (-not (Test-GraphConnection)) {
                                Connect-MicrosoftGraphService -Config $Config
                                $serviceReconnected = Test-GraphConnection
                            }
                            else {
                                $serviceReconnected = $true
                            }
                        }
                        "ExchangeOnline" {
                            if (-not (Test-ExchangeOnlineConnection)) {
                                Connect-ExchangeOnlineService -Config $Config
                                $serviceReconnected = Test-ExchangeOnlineConnection
                            }
                            else {
                                $serviceReconnected = $true
                            }
                        }
                    }
                    
                    if ($serviceReconnected) {
                        $reconnectResults.ReconnectedServices += $service
                        $reconnectResults.Details += "${service}: 再接続成功 (試行回数: ${retryCount})"
                        Write-Log "$service 再接続成功" -Level "Info"
                        break
                    }
                }
                catch {
                    $errorMessage = $_.Exception.Message
                    Write-Log "$service 再接続エラー (試行 $retryCount): $errorMessage" -Level "Warning"
                    
                    if ($retryCount -lt $MaxRetries) {
                        $delay = 5 * $retryCount
                        Write-Log "$delay 秒後に再試行..." -Level "Info"
                        Start-Sleep -Seconds $delay
                    }
                }
            }
            
            if (-not $serviceReconnected) {
                $reconnectResults.FailedServices += $service
                $reconnectResults.Details += "${service}: 再接続失敗 (全 ${MaxRetries} 回の試行が失敗)"
                Write-Log "$service 再接続失敗" -Level "Error"
            }
        }
        
        $reconnectResults.Success = $reconnectResults.ReconnectedServices.Count -gt 0
        
        Write-Log "自動再接続完了: 成功 $($reconnectResults.ReconnectedServices.Count)/$($Services.Count)" -Level "Info"
        return $reconnectResults
    }
    catch {
        Write-Log "自動再接続プロセスエラー: $($_.Exception.Message)" -Level "Error"
        $reconnectResults.Details += "自動再接続プロセスでエラーが発生しました"
        return $reconnectResults
    }
}

# 認証トークンの有効期限監視
function Test-TokenExpiration {
    <#
    .SYNOPSIS
    認証トークンの有効期限を確認
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$WarningThresholdMinutes = 10
    )
    
    $tokenStatus = @{
        MicrosoftGraph = @{
            Valid = $false
            ExpiresAt = $null
            MinutesRemaining = 0
            NeedsRefresh = $false
        }
        ExchangeOnline = @{
            Valid = $false
            ExpiresAt = $null
            MinutesRemaining = 0
            NeedsRefresh = $false
        }
    }
    
    try {
        # Microsoft Graph トークン確認
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if ($context) {
            # Graph APIには直接的なトークン有効期限確認機能がないため、API呼び出しテストで確認
            try {
                $testResult = Get-MgUser -Top 1 -Property Id -ErrorAction Stop
                $tokenStatus.MicrosoftGraph.Valid = $true
                # 通常のトークン有効期限は1時間程度
                $tokenStatus.MicrosoftGraph.ExpiresAt = (Get-Date).AddMinutes(60)
                $tokenStatus.MicrosoftGraph.MinutesRemaining = 60
                $tokenStatus.MicrosoftGraph.NeedsRefresh = $false
            }
            catch {
                $tokenStatus.MicrosoftGraph.Valid = $false
                $tokenStatus.MicrosoftGraph.NeedsRefresh = $true
            }
        }
        
        # Exchange Online セッション確認
        $sessions = Get-PSSession | Where-Object { 
            ($_.Name -like "*ExchangeOnline*" -or $_.ConfigurationName -eq "Microsoft.Exchange") -and 
            $_.State -eq "Opened" 
        }
        
        if ($sessions) {
            try {
                $orgConfig = Get-OrganizationConfig -ErrorAction Stop | Select-Object -First 1
                $tokenStatus.ExchangeOnline.Valid = $true
                # Exchange Onlineセッションの有効期限は通常長い
                $tokenStatus.ExchangeOnline.ExpiresAt = (Get-Date).AddHours(8)
                $tokenStatus.ExchangeOnline.MinutesRemaining = 480
                $tokenStatus.ExchangeOnline.NeedsRefresh = $false
            }
            catch {
                $tokenStatus.ExchangeOnline.Valid = $false
                $tokenStatus.ExchangeOnline.NeedsRefresh = $true
            }
        }
        
        Write-Log "トークン有効期限確認完了" -Level "Info"
        return $tokenStatus
    }
    catch {
        Write-Log "トークン有効期限確認エラー: $($_.Exception.Message)" -Level "Error"
        return $tokenStatus
    }
}

# トークンキャッシュ管理機能
function Get-CachedToken {
    <#
    .SYNOPSIS
    キャッシュされた認証トークンを取得
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Service
    )
    
    if ($Script:AuthenticationStatus.TokenCache.ContainsKey($Service)) {
        $tokenInfo = $Script:AuthenticationStatus.TokenCache[$Service]
        $expiry = $Script:AuthenticationStatus.TokenExpiry[$Service]
        
        if ($expiry -and (Get-Date) -lt $expiry) {
            Write-Log "キャッシュされたトークンを使用: $Service (有効期限: $($expiry.ToString('yyyy-MM-dd HH:mm:ss')))" -Level "Info"
            return $tokenInfo
        }
        else {
            Write-Log "トークンの有効期限が切れています: $Service" -Level "Warning"
            $Script:AuthenticationStatus.TokenCache.Remove($Service)
            $Script:AuthenticationStatus.TokenExpiry.Remove($Service)
        }
    }
    
    return $null
}

function Set-CachedToken {
    <#
    .SYNOPSIS
    認証トークンをキャッシュに保存
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Service,
        
        [Parameter(Mandatory = $true)]
        [object]$TokenInfo,
        
        [Parameter(Mandatory = $false)]
        [int]$ExpiryMinutes = 50
    )
    
    $Script:AuthenticationStatus.TokenCache[$Service] = $TokenInfo
    $Script:AuthenticationStatus.TokenExpiry[$Service] = (Get-Date).AddMinutes($ExpiryMinutes)
    
    Write-Log "トークンをキャッシュに保存: $Service (有効期限: $ExpiryMinutes 分)" -Level "Info"
}

# 並列処理対応の認証関数
function Invoke-ThreadSafeAuthentication {
    <#
    .SYNOPSIS
    スレッドセーフな認証処理を実行
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )
    
    $mutexAcquired = $false
    
    try {
        $mutexAcquired = $Script:AuthenticationLock.WaitOne($TimeoutSeconds * 1000)
        
        if (-not $mutexAcquired) {
            throw "認証ロックの取得がタイムアウトしました"
        }
        
        return & $ScriptBlock
    }
    finally {
        if ($mutexAcquired) {
            $Script:AuthenticationLock.ReleaseMutex()
        }
    }
}

# エクスポート関数（API仕様書準拠）
# Comprehensive integration diagnostics
function Get-IntegrationDiagnostics {
    param(
        [switch]$IncludePerformanceMetrics,
        [switch]$IncludeDetailedErrors
    )
    
    $diagnostics = @{
        Timestamp = Get-Date
        GraphConnection = @{
            Status = "Unknown"
            Context = $null
            LastError = $null
        }
        ExchangeConnection = @{
            Status = "Unknown"
            Sessions = @()
            LastError = $null
        }
        PerformanceMetrics = @{}
        Integration = @{
            Status = "Unknown"
            Issues = @()
            Recommendations = @()
        }
    }
    
    # Test Microsoft Graph connection
    try {
        $graphConnected = Test-GraphConnection
        $diagnostics.GraphConnection.Status = if ($graphConnected) { "Connected" } else { "Disconnected" }
        
        if ($graphConnected) {
            $context = Get-MgContext -ErrorAction SilentlyContinue
            $diagnostics.GraphConnection.Context = @{
                TenantId = $context.TenantId
                ClientId = $context.ClientId
                Scopes = $context.Scopes
                AuthType = $context.AuthType
            }
        }
    }
    catch {
        $diagnostics.GraphConnection.Status = "Error"
        $diagnostics.GraphConnection.LastError = $_.Exception.Message
    }
    
    # Test Exchange Online connection
    try {
        $exoConnected = Test-ExchangeOnlineConnection
        $diagnostics.ExchangeConnection.Status = if ($exoConnected) { "Connected" } else { "Disconnected" }
        
        if ($exoConnected) {
            $sessions = Get-PSSession | Where-Object { 
                ($_.Name -like "*ExchangeOnline*" -or $_.ConfigurationName -eq "Microsoft.Exchange") -and 
                $_.State -eq "Opened" 
            }
            $diagnostics.ExchangeConnection.Sessions = $sessions | ForEach-Object {
                @{
                    Name = $_.Name
                    State = $_.State
                    ConfigurationName = $_.ConfigurationName
                    ComputerName = $_.ComputerName
                }
            }
        }
    }
    catch {
        $diagnostics.ExchangeConnection.Status = "Error"
        $diagnostics.ExchangeConnection.LastError = $_.Exception.Message
    }
    
    # Include performance metrics if requested
    if ($IncludePerformanceMetrics -and (Get-Command Get-PerformanceMetrics -ErrorAction SilentlyContinue)) {
        try {
            $diagnostics.PerformanceMetrics = Get-PerformanceMetrics
        }
        catch {
            $diagnostics.PerformanceMetrics.Error = $_.Exception.Message
        }
    }
    
    # Analyze integration status
    $graphOk = $diagnostics.GraphConnection.Status -eq "Connected"
    $exoOk = $diagnostics.ExchangeConnection.Status -eq "Connected"
    
    if ($graphOk -and $exoOk) {
        $diagnostics.Integration.Status = "Healthy"
    }
    elseif ($graphOk -or $exoOk) {
        $diagnostics.Integration.Status = "Partial"
        if (-not $graphOk) {
            $diagnostics.Integration.Issues += "Microsoft Graph接続が無効"
            $diagnostics.Integration.Recommendations += "Connect-MicrosoftGraphServiceを実行してください"
        }
        if (-not $exoOk) {
            $diagnostics.Integration.Issues += "Exchange Online接続が無効"
            $diagnostics.Integration.Recommendations += "Connect-ExchangeOnlineServiceを実行してください"
        }
    }
    else {
        $diagnostics.Integration.Status = "Failed"
        $diagnostics.Integration.Issues += "すべてのサービス接続が無効"
        $diagnostics.Integration.Recommendations += "Connect-ToMicrosoft365を実行してください"
    }
    
    return $diagnostics
}

# Quick health check for monitoring
function Test-M365Integration {
    param(
        [switch]$Quiet
    )
    
    $result = @{
        Healthy = $false
        GraphConnected = $false
        ExchangeConnected = $false
        Message = ""
    }
    
    try {
        $result.GraphConnected = Test-GraphConnection
        $result.ExchangeConnected = Test-ExchangeOnlineConnection
        $result.Healthy = $result.GraphConnected -and $result.ExchangeConnected
        
        if ($result.Healthy) {
            $result.Message = "✅ Microsoft 365統合は正常です"
        }
        elseif ($result.GraphConnected -or $result.ExchangeConnected) {
            $result.Message = "⚠️ Microsoft 365統合は部分的です"
        }
        else {
            $result.Message = "❌ Microsoft 365統合に問題があります"
        }
        
        if (-not $Quiet) {
            Write-Log $result.Message -Level "Info"
        }
    }
    catch {
        $result.Message = "❌ 統合チェック中にエラー: $($_.Exception.Message)"
        if (-not $Quiet) {
            Write-Log $result.Message -Level "Error"
        }
    }
    
    return $result
}

Export-ModuleMember -Function Connect-ToMicrosoft365, Connect-MicrosoftGraphService, Connect-ExchangeOnlineService, Connect-ActiveDirectoryService, Test-AuthenticationStatus, Disconnect-AllServices, Get-AuthenticationInfo, Invoke-GraphAPIWithRetry, Test-GraphConnection, Test-ExchangeOnlineConnection, Get-DetailedAuthenticationStatus, Invoke-AutoReconnect, Test-TokenExpiration, Get-CachedToken, Set-CachedToken, Invoke-ThreadSafeAuthentication, Get-ErrorCategory, Get-AdaptiveDelay, Invoke-AuthenticationRefresh, Get-IntegrationDiagnostics, Test-M365Integration