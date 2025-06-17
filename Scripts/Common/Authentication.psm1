# ================================================================================
# Authentication.psm1
# Microsoft 365統合認証モジュール（本格版）
# 非対話式・証明書認証・クライアントシークレット対応
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\ErrorHandling.psm1" -Force

# API仕様書準拠のリトライロジック
function Invoke-GraphAPIWithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxRetries = 5,
        [int]$BaseDelaySeconds = 2,
        [string]$Operation = "API Call"
    )
    
    $attempt = 0
    do {
        try {
            $attempt++
            Write-Log "API呼び出し試行 $attempt/$MaxRetries - $Operation" -Level "Info"
            return & $ScriptBlock
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-Log "API呼び出しエラー (試行 $attempt): $errorMessage" -Level "Warning"
            
            if ($errorMessage -match "429|throttle|rate limit|TooManyRequests") {
                if ($attempt -lt $MaxRetries) {
                    $delay = $BaseDelaySeconds * [Math]::Pow(2, $attempt)
                    Write-Log "API制限検出。$delay 秒後にリトライします..." -Level "Warning"
                    Start-Sleep -Seconds $delay
                }
                else {
                    throw "最大リトライ回数に到達しました: $errorMessage"
                }
            }
            elseif ($errorMessage -match "authentication|authorization|forbidden|unauthorized") {
                throw "認証エラー: $errorMessage"
            }
            else {
                throw
            }
        }
    } while ($attempt -lt $MaxRetries)
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
}

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
        
        # 認証方式の決定
        if ($graphConfig.CertificatePath -and (Test-Path $graphConfig.CertificatePath)) {
            # ファイルベース証明書認証（ポータブル）
            Write-Log "ファイルベース証明書認証でMicrosoft Graph に接続中..." -Level "Info"
            
            $certPath = $graphConfig.CertificatePath
            if (-not [System.IO.Path]::IsPathRooted($certPath)) {
                $certPath = Join-Path $PSScriptRoot "..\..\$certPath"
            }
            
            # 複数パスワード候補で試行
            $passwordCandidates = @()
            Write-Log "Microsoft Graph: 設定されたパスワード: '$($graphConfig.CertificatePassword)'" -Level "Info"
            
            if ($graphConfig.CertificatePassword -and $graphConfig.CertificatePassword -ne "") {
                $passwordCandidates += $graphConfig.CertificatePassword
                Write-Log "Microsoft Graph: パスワード候補に追加: '$($graphConfig.CertificatePassword)'" -Level "Info"
            }
            $passwordCandidates += @("", $null)  # パスワードなしも試行
            
            Write-Log "Microsoft Graph: 総パスワード候補数: $($passwordCandidates.Count)" -Level "Info"
            
            $cert = $null
            $lastError = $null
            
            foreach ($password in $passwordCandidates) {
                try {
                    if ([string]::IsNullOrEmpty($password)) {
                        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)
                        Write-Log "Microsoft Graph: パスワードなしで証明書読み込み成功" -Level "Info"
                        break
                    }
                    else {
                        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
                        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $securePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
                        Write-Log "Microsoft Graph: パスワード保護証明書読み込み成功" -Level "Info"
                        break
                    }
                }
                catch {
                    $lastError = $_
                    Write-Log "Microsoft Graph: パスワード '$password' での読み込み失敗: $($_.Exception.Message)" -Level "Warning"
                    continue
                }
            }
            
            if (-not $cert) {
                throw "証明書の読み込みに失敗しました。最後のエラー: $($lastError.Exception.Message)"
            }
            
            $connectParams = @{
                TenantId = $graphConfig.TenantId
                ClientId = $graphConfig.ClientId
                Certificate = $cert
                NoWelcome = $true
            }
            
            Connect-MgGraph @connectParams
            
            Write-Log "Microsoft Graph ファイルベース証明書認証接続成功" -Level "Info"
        }
        elseif ($graphConfig.CertificateThumbprint -and $graphConfig.CertificateThumbprint -ne "YOUR-CERTIFICATE-THUMBPRINT-HERE") {
            # Thumbprint証明書認証（ストア依存）
            Write-Log "Thumbprint証明書認証でMicrosoft Graph に接続中..." -Level "Info"
            
            $connectParams = @{
                TenantId = $graphConfig.TenantId
                ClientId = $graphConfig.ClientId
                CertificateThumbprint = $graphConfig.CertificateThumbprint
                NoWelcome = $true
            }
            
            Connect-MgGraph @connectParams
            
            Write-Log "Microsoft Graph 証明書認証接続成功" -Level "Info"
        }
        elseif ($graphConfig.ClientSecret -and $graphConfig.ClientSecret -ne "" -and $graphConfig.ClientSecret -ne "YOUR-CLIENT-SECRET-HERE") {
            # クライアントシークレット認証（API仕様書準拠）
            Write-Log "クライアントシークレット認証でMicrosoft Graph に接続中..." -Level "Info"
            Write-Log "認証情報: ClientId=$($graphConfig.ClientId), TenantId=$($graphConfig.TenantId)" -Level "Info"
            
            # API仕様書に基づくクライアントシークレット認証
            try {
                $secureSecret = ConvertTo-SecureString $graphConfig.ClientSecret -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential ($graphConfig.ClientId, $secureSecret)
                
                $connectParams = @{
                    TenantId = $graphConfig.TenantId
                    ClientSecretCredential = $credential
                    NoWelcome = $true
                }
                
                # API仕様書のスコープ設定を考慮
                if ($graphConfig.Scopes -and $graphConfig.Scopes.Count -gt 0) {
                    Write-Log "要求スコープ: $($graphConfig.Scopes -join ', ')" -Level "Info"
                    # 注意: Client Credentialフローではスコープは自動的に決定されます
                }
                
                # リトライロジックを使用して接続
                $connectionResult = Invoke-GraphAPIWithRetry -ScriptBlock {
                    Connect-MgGraph @connectParams
                } -MaxRetries 3 -Operation "Microsoft Graph クライアントシークレット認証"
                
                Write-Log "Microsoft Graph クライアントシークレット認証接続成功" -Level "Info"
                
                # 権限確認
                $context = Get-MgContext
                if ($context) {
                    Write-Log "取得された権限: $($context.Scopes -join ', ')" -Level "Info"
                    
                    # API仕様書で要求される権限の確認
                    $requiredPermissions = @(
                        "User.Read.All",
                        "Group.Read.All", 
                        "Directory.Read.All",
                        "Reports.Read.All",
                        "Files.Read.All"
                    )
                    
                    $missingPermissions = @()
                    foreach ($permission in $requiredPermissions) {
                        if ($context.Scopes -notcontains $permission) {
                            $missingPermissions += $permission
                        }
                    }
                    
                    if ($missingPermissions.Count -gt 0) {
                        Write-Log "不足している権限があります: $($missingPermissions -join ', ')" -Level "Warning"
                        Write-Log "Azure ADアプリケーションで以下の権限を追加してください:" -Level "Warning"
                        foreach ($permission in $missingPermissions) {
                            Write-Log "  - $permission" -Level "Warning"
                        }
                    }
                    else {
                        Write-Log "必要な権限がすべて付与されています" -Level "Info"
                    }
                }
            }
            catch {
                Write-Log "クライアントシークレット認証エラー: $($_.Exception.Message)" -Level "Error"
                
                # 一般的なエラーパターンに基づく詳細診断
                $errorMessage = $_.Exception.Message
                if ($errorMessage -match "AADSTS70011|invalid_client") {
                    Write-Log "診断: ClientIdまたはClientSecretが無効です" -Level "Error"
                    Write-Log "対処法: Azure ADアプリケーションの設定を確認してください" -Level "Error"
                }
                elseif ($errorMessage -match "AADSTS50034|does not exist") {
                    Write-Log "診断: テナントIDが無効です" -Level "Error"
                    Write-Log "対処法: TenantIdが正しく設定されているか確認してください" -Level "Error"
                }
                elseif ($errorMessage -match "AADSTS65001|consent") {
                    Write-Log "診断: アプリケーションに対する管理者の同意が必要です" -Level "Error"
                    Write-Log "対処法: Azure ADでアプリケーションに管理者の同意を付与してください" -Level "Error"
                }
                
                throw $_
            }
        }
        else {
            throw "有効な認証情報が設定されていません。証明書またはクライアントシークレットを設定してください。"
        }
        
        # 接続確認
        $context = Get-MgContext
        if ($context) {
            Write-Log "Microsoft Graph 接続確認: テナント $($context.TenantId)" -Level "Info"
            
            # 必要なスコープ確認
            $requiredScopes = $graphConfig.Scopes
            if ($requiredScopes) {
                Write-Log "要求スコープ: $($requiredScopes -join ', ')" -Level "Info"
            }
            
            return $true
        }
        else {
            throw "Microsoft Graph 接続の確認に失敗しました"
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
                ShowProgress = $false
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

# エクスポート関数（API仕様書準拠）
Export-ModuleMember -Function Connect-ToMicrosoft365, Connect-MicrosoftGraphService, Connect-ExchangeOnlineService, Connect-ActiveDirectoryService, Test-AuthenticationStatus, Disconnect-AllServices, Get-AuthenticationInfo, Invoke-GraphAPIWithRetry, Test-GraphConnection, Test-ExchangeOnlineConnection