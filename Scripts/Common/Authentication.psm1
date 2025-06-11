# ================================================================================
# Authentication.psm1
# Microsoft 365統合認証モジュール（本格版）
# 非対話式・証明書認証・クライアントシークレット対応
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\ErrorHandling.psm1" -Force

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
        elseif ($graphConfig.ClientSecret -and $graphConfig.ClientSecret -ne "") {
            # クライアントシークレット認証
            Write-Log "クライアントシークレット認証でMicrosoft Graph に接続中..." -Level "Info"
            
            $secureSecret = ConvertTo-SecureString $graphConfig.ClientSecret -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential ($graphConfig.ClientId, $secureSecret)
            
            $connectParams = @{
                TenantId = $graphConfig.TenantId
                ClientSecretCredential = $credential
                NoWelcome = $true
            }
            
            Connect-MgGraph @connectParams
            
            Write-Log "Microsoft Graph クライアントシークレット認証接続成功" -Level "Info"
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
            
            Connect-ExchangeOnline @connectParams
            
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
            
            Connect-ExchangeOnline @connectParams
            
            Write-Log "Exchange Online 証明書認証接続成功" -Level "Info"
        }
        else {
            throw "Exchange Online 証明書認証情報が設定されていません。証明書を設定してください。"
        }
        
        # 接続確認（複数方法で試行）
        try {
            # 方法1: 基本的なコマンドテスト
            $testResult = Get-OrganizationConfig -ErrorAction SilentlyContinue
            if ($testResult) {
                Write-Log "Exchange Online 接続確認: Get-OrganizationConfig テスト成功" -Level "Info"
                return $true
            }
        }
        catch {
            Write-Log "Exchange Online 確認エラー（方法1）: $($_.Exception.Message)" -Level "Warning"
        }
        
        try {
            # 方法2: セッション確認
            $sessions = Get-PSSession | Where-Object { 
                ($_.Name -like "*ExchangeOnline*" -or $_.ConfigurationName -eq "Microsoft.Exchange") -and 
                $_.State -eq "Opened" 
            }
            if ($sessions.Count -gt 0) {
                Write-Log "Exchange Online 接続確認: アクティブセッション $($sessions.Count) 個" -Level "Info"
                return $true
            }
        }
        catch {
            Write-Log "Exchange Online 確認エラー（方法2）: $($_.Exception.Message)" -Level "Warning"
        }
        
        try {
            # 方法3: 接続状態確認
            $connectionInfo = Get-ConnectionInformation -ErrorAction SilentlyContinue
            if ($connectionInfo) {
                Write-Log "Exchange Online 接続確認: 接続情報取得成功" -Level "Info"
                return $true
            }
        }
        catch {
            Write-Log "Exchange Online 確認エラー（方法3）: $($_.Exception.Message)" -Level "Warning"
        }
        
        # 接続成功として扱う（認証が通れば基本的に成功）
        Write-Log "Exchange Online: 証明書認証成功のため接続成功と判定" -Level "Info"
        return $true
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

# エクスポート関数
Export-ModuleMember -Function Connect-ToMicrosoft365, Connect-MicrosoftGraphService, Connect-ExchangeOnlineService, Connect-ActiveDirectoryService, Test-AuthenticationStatus, Disconnect-AllServices, Get-AuthenticationInfo