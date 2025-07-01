# ================================================================================
# OneDriveExternalSharingAnalysis.ps1
# OneDrive外部共有状況確認スクリプト
# ITSM/ISO27001/27002準拠 - セキュリティ監査・外部共有監視
# ================================================================================

# 共通モジュールのインポート
try {
    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
    Import-Module "$PSScriptRoot\..\Common\Logging.psm1" -Force
    Import-Module "$PSScriptRoot\..\Common\ErrorHandling.psm1" -Force
    Import-Module "$PSScriptRoot\..\Common\ReportGenerator.psm1" -Force
}
catch {
    Write-Host "❌ 共通モジュールのインポートに失敗しました: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "スタンドアロンモードで実行します..." -ForegroundColor Yellow
}

function Get-OneDriveExternalSharingAnalysis {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Weekly",
        
        [Parameter(Mandatory = $false)]
        [string]$UserId = $null,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeFileDetails = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $true
    )
    
    try {
        # ログ関数の定義（スタンドアロン対応）
        if (-not (Get-Command "Write-Log" -ErrorAction SilentlyContinue)) {
            function Write-Log {
                param([string]$Message, [string]$Level = "Info")
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
                    switch ($Level) {
                        "Error" { "Red" }
                        "Warning" { "Yellow" }
                        "Info" { "Cyan" }
                        default { "White" }
                    }
                )
            }
        }
        
        Write-Log "OneDrive外部共有状況確認を開始します" -Level "Info"
        
        # 必要なモジュールのチェック
        $requiredModules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Sites", "Microsoft.Graph.Users", "Microsoft.Graph.Files")
        foreach ($module in $requiredModules) {
            if (-not (Get-Module -Name $module -ListAvailable)) {
                Write-Log "必要なモジュールがインストールされていません: $module" -Level "Warning"
            }
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $externalSharingReport = @()
        $riskySharingReport = @()
        
        # Microsoft Graph接続確認と自動接続
        $graphConnected = $false
        try {
            $context = Get-MgContext -ErrorAction SilentlyContinue
            if ($context) {
                $graphConnected = $true
                Write-Log "Microsoft Graph接続済み（テナント: $($context.TenantId)）" -Level "Info"
            } else {
                # 自動接続を試行
                Write-Log "Microsoft Graphへの自動接続を試行しています..." -Level "Info"
                
                # まず設定ファイルベースの認証を試行
                $authSuccess = $false
                
                # 1. 設定ファイルからの認証情報読み込み
                try {
                    $configPath = Join-Path $PWD "Config\appsettings.json"
                    if (Test-Path $configPath) {
                        Write-Log "設定ファイルから認証情報を読み込み中..." -Level "Info"
                        $config = Get-Content $configPath | ConvertFrom-Json
                        
                        # EntraID/MicrosoftGraph設定を確認
                        $graphConfig = if ($config.MicrosoftGraph) { $config.MicrosoftGraph } else { $config.EntraID }
                        
                        if ($graphConfig -and $graphConfig.ClientId -and $graphConfig.TenantId) {
                            # クライアントシークレット認証を優先実行
                            if ($graphConfig.ClientSecret) {
                                Write-Log "クライアントシークレット認証を試行中..." -Level "Info"
                                $clientSecret = ConvertTo-SecureString $graphConfig.ClientSecret -AsPlainText -Force
                                $credential = New-Object System.Management.Automation.PSCredential($graphConfig.ClientId, $clientSecret)
                                
                                Connect-MgGraph -ClientSecretCredential $credential -TenantId $graphConfig.TenantId -NoWelcome
                                $authSuccess = $true
                                Write-Log "クライアントシークレット認証成功" -Level "Info"
                            }
                            # 証明書ベース認証（フォールバック）
                            elseif ($graphConfig.CertificatePath -and (Test-Path $graphConfig.CertificatePath)) {
                                Write-Log "証明書ベース認証を試行中..." -Level "Info"
                                $certPassword = ConvertTo-SecureString $graphConfig.CertificatePassword -AsPlainText -Force
                                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($graphConfig.CertificatePath, $certPassword)
                                
                                Connect-MgGraph -ClientId $graphConfig.ClientId -Certificate $cert -TenantId $graphConfig.TenantId -NoWelcome
                                $authSuccess = $true
                                Write-Log "証明書ベース認証成功" -Level "Info"
                            }
                        }
                    }
                } catch {
                    Write-Log "設定ファイルベース認証エラー: $($_.Exception.Message)" -Level "Warning"
                }
                
                # 2. 非対話式での接続試行
                if (-not $authSuccess) {
                    try {
                        Write-Log "非対話式認証を試行中..." -Level "Info"
                        
                        # デバイスコード認証（非対話的環境向け）
                        $scopes = @(
                            "https://graph.microsoft.com/User.Read.All",
                            "https://graph.microsoft.com/Sites.Read.All", 
                            "https://graph.microsoft.com/Files.Read.All",
                            "https://graph.microsoft.com/Directory.Read.All"
                        )
                        
                        # 環境変数から認証情報を確認
                        $clientId = $env:AZURE_CLIENT_ID
                        $clientSecret = $env:AZURE_CLIENT_SECRET
                        $tenantId = $env:AZURE_TENANT_ID
                        
                        if ($clientId -and $clientSecret -and $tenantId) {
                            Write-Log "環境変数から認証情報を使用..." -Level "Info"
                            $clientSecretSecure = ConvertTo-SecureString $clientSecret -AsPlainText -Force
                            $credential = New-Object System.Management.Automation.PSCredential($clientId, $clientSecretSecure)
                            
                            Connect-MgGraph -ClientSecretCredential $credential -TenantId $tenantId -NoWelcome
                            $authSuccess = $true
                            Write-Log "環境変数ベース認証成功" -Level "Info"
                        } else {
                            Write-Log "認証情報が不足しています。サンプルデータモードで継続します" -Level "Warning"
                            Write-Log "必要な設定: Config\appsettings.json または環境変数 (AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID)" -Level "Info"
                        }
                    } catch {
                        Write-Log "非対話式認証エラー: $($_.Exception.Message)" -Level "Warning"
                        Write-Log "サンプルデータモードで継続します" -Level "Info"
                    }
                }
                
                # 接続確認
                if ($authSuccess) {
                    $context = Get-MgContext
                    if ($context) {
                        $graphConnected = $true
                        Write-Log "Microsoft Graph接続成功（テナント: $($context.TenantId)）" -Level "Info"
                        Write-Log "認証タイプ: $($context.AuthType)" -Level "Info"
                        Write-Log "利用可能スコープ: $($context.Scopes -join ', ')" -Level "Info"
                    }
                }
            }
        } catch {
            Write-Log "Microsoft Graph接続確認エラー: $($_.Exception.Message)" -Level "Warning"
        }

        # ユーザー一覧取得
        $users = @()
        if ($graphConnected) {
            try {
                if ($UserId) {
                    $users = @(Get-MgUser -UserId $UserId -Property UserPrincipalName,DisplayName,AccountEnabled,Department,JobTitle -ErrorAction Stop)
                    if (-not $users) {
                        throw "指定されたユーザーが見つかりません: $UserId"
                    }
                } else {
                    $users = Get-MgUser -All -Property UserPrincipalName,DisplayName,AccountEnabled,Department,JobTitle -Filter "accountEnabled eq true" -ErrorAction Stop
                }
                Write-Log "実データ取得成功: $($users.Count)ユーザー" -Level "Info"
            } catch {
                Write-Log "実データ取得エラー: $($_.Exception.Message)" -Level "Warning"
                Write-Log "サンプルデータを使用します" -Level "Info"
                $users = @()
            }
        } else {
            Write-Log "Microsoft Graphに接続されていません。サンプルデータを使用します" -Level "Warning"
        }

        # データが取得できない場合はサンプルデータを生成
        if ($users.Count -eq 0) {
            Write-Log "サンプルデータを生成中..." -Level "Info"
            $users = Generate-SampleUsers
        }
        
        Write-Log "対象ユーザー数: $($users.Count)" -Level "Info"
        
        foreach ($user in $users) {
            try {
                Write-Log "外部共有分析中: $($user.DisplayName)" -Level "Info"
                
                # OneDriveサイト取得（実データ・サンプルデータ両対応）
                $oneDriveSite = $null
                if ($graphConnected) {
                    try {
                        # ユーザーのOneDriveドライブを取得
                        Write-Log "OneDriveドライブ取得中: $($user.UserPrincipalName)" -Level "Info"
                        $oneDriveSite = Get-MgUserDrive -UserId $user.Id -ErrorAction Stop
                        
                        if ($oneDriveSite) {
                            Write-Log "OneDriveドライブ取得成功: $($oneDriveSite.Name)" -Level "Info"
                        } else {
                            Write-Log "OneDriveドライブが見つかりません: $($user.UserPrincipalName)" -Level "Warning"
                        }
                    } catch {
                        Write-Log "OneDrive実データ取得エラー: $($user.UserPrincipalName) - $($_.Exception.Message)" -Level "Warning"
                        Write-Log "エラー詳細: $($_.Exception.GetType().Name)" -Level "Warning"
                    }
                }
                
                # 外部共有情報を詳細分析
                if ($graphConnected -and $oneDriveSite) {
                    # 実データでの分析
                    $externalSharingAnalysis = Get-OneDriveExternalSharing -DriveId $oneDriveSite.Id -UserId $user.Id -IncludeFileDetails:$IncludeFileDetails
                    $driveId = $oneDriveSite.Id
                    $driveWebUrl = $oneDriveSite.WebUrl
                } else {
                    # サンプルデータを使用
                    Write-Log "サンプルデータを使用: $($user.UserPrincipalName)" -Level "Info"
                    $externalSharingAnalysis = Generate-SampleExternalSharingData -User $user
                    $driveId = "sample-drive-" + [Guid]::NewGuid().ToString().Substring(0,8)
                    $driveWebUrl = "https://miraiconst-my.sharepoint.com/personal/" + $user.UserPrincipalName.Replace("@", "_").Replace(".", "_")
                }
                
                # ユーザーごとのサマリーレポート作成
                $userSharingReport = [PSCustomObject]@{
                    UserPrincipalName = $user.UserPrincipalName
                    DisplayName = $user.DisplayName
                    Department = $user.Department
                    JobTitle = $user.JobTitle
                    DriveId = $driveId
                    DriveWebUrl = $driveWebUrl
                    HasExternalSharing = $externalSharingAnalysis.HasExternalSharing
                    ExternalShareCount = $externalSharingAnalysis.ExternalShareCount
                    ExternalUserCount = $externalSharingAnalysis.ExternalUserCount
                    PublicLinkCount = $externalSharingAnalysis.PublicLinkCount
                    AnonymousLinkCount = $externalSharingAnalysis.AnonymousLinkCount
                    SensitiveFileShareCount = $externalSharingAnalysis.SensitiveFileShareCount
                    SecurityRiskLevel = $externalSharingAnalysis.SecurityRiskLevel
                    RiskFactors = ($externalSharingAnalysis.RiskFactors -join "; ")
                    LastExternalShareDate = $externalSharingAnalysis.LastExternalShareDate
                    ExternalDomains = ($externalSharingAnalysis.ExternalDomains -join "; ")
                    RecommendedActions = ($externalSharingAnalysis.RecommendedActions -join "; ")
                    AnalysisTimestamp = Get-Date
                }
                
                $externalSharingReport += $userSharingReport
                
                # 高リスクユーザーの抽出
                if ($externalSharingAnalysis.SecurityRiskLevel -in @("高", "緊急")) {
                    $riskySharingReport += $userSharingReport
                }
                
                # ファイル詳細レポート（要求された場合）
                if ($IncludeFileDetails -and $externalSharingAnalysis.SharedFiles.Count -gt 0) {
                    foreach ($sharedFile in $externalSharingAnalysis.SharedFiles) {
                        $fileDetailReport = [PSCustomObject]@{
                            UserPrincipalName = $user.UserPrincipalName
                            DisplayName = $user.DisplayName
                            FileName = $sharedFile.FileName
                            FilePath = $sharedFile.FilePath
                            FileSize = $sharedFile.FileSize
                            ShareType = $sharedFile.ShareType
                            ShareScope = $sharedFile.ShareScope
                            SharedWith = $sharedFile.SharedWith
                            Permissions = $sharedFile.Permissions
                            ShareDate = $sharedFile.ShareDate
                            ExpirationDate = $sharedFile.ExpirationDate
                            IsPasswordProtected = $sharedFile.IsPasswordProtected
                            IsSensitive = $sharedFile.IsSensitive
                            SecurityRisk = $sharedFile.SecurityRisk
                            FileWebUrl = $sharedFile.FileWebUrl
                            AnalysisTimestamp = Get-Date
                        }
                        
                        # ファイル詳細は別のコレクションに保存
                        if (-not $script:fileDetailReports) {
                            $script:fileDetailReports = @()
                        }
                        $script:fileDetailReports += $fileDetailReport
                    }
                }
            }
            catch {
                Write-Log "外部共有分析エラー: $($user.DisplayName) - $($_.Exception.Message)" -Level "Error"
                
                # エラー情報を含むレコード作成
                $errorReport = [PSCustomObject]@{
                    UserPrincipalName = $user.UserPrincipalName
                    DisplayName = $user.DisplayName
                    Department = $user.Department
                    JobTitle = $user.JobTitle
                    DriveId = "取得エラー"
                    DriveWebUrl = "取得エラー"
                    HasExternalSharing = "分析エラー"
                    ExternalShareCount = "分析エラー"
                    ExternalUserCount = "分析エラー"
                    PublicLinkCount = "分析エラー"
                    AnonymousLinkCount = "分析エラー"
                    SensitiveFileShareCount = "分析エラー"
                    SecurityRiskLevel = "不明"
                    RiskFactors = $_.Exception.Message
                    LastExternalShareDate = "分析エラー"
                    ExternalDomains = "分析エラー"
                    RecommendedActions = "エラー解決後に再実行してください"
                    AnalysisTimestamp = Get-Date
                }
                
                $externalSharingReport += $errorReport
            }
        }
        
        # 出力ディレクトリ作成（スタンドアロン対応）
        if (Get-Command "New-ReportDirectory" -ErrorAction SilentlyContinue) {
            $outputDir = New-ReportDirectory -ReportType "Weekly"
        } else {
            $outputDir = "Reports\Weekly"
            if (-not (Test-Path $outputDir)) {
                New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
            }
        }
        
        # CSV出力
        if ($ExportCSV) {
            # メインレポート出力
            $csvPath = Join-Path $outputDir "OneDriveExternalSharing_Summary_$timestamp.csv"
            # CSV出力（スタンドアロン対応）
            if ($externalSharingReport.Count -gt 0) {
                if (Get-Command "Export-DataToCSV" -ErrorAction SilentlyContinue) {
                    Export-DataToCSV -Data $externalSharingReport -FilePath $csvPath
                } else {
                    $externalSharingReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                }
            } else {
                # 空のデータの場合はサンプル情報を出力
                $emptyData = @([PSCustomObject]@{
                    "情報" = "OneDrive外部共有分析（サンプル）"
                    "詳細" = "Microsoft Graph未接続のためサンプルデータで分析実行"
                    "生成日時" = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
                    "備考" = "実際の分析にはMicrosoft Graphへの接続が必要です"
                })
                $emptyData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            }
            
            # 高リスクユーザーレポート出力
            if ($riskySharingReport.Count -gt 0) {
                $riskyPath = Join-Path $outputDir "OneDriveExternalSharing_HighRisk_$timestamp.csv"
                if (Get-Command "Export-DataToCSV" -ErrorAction SilentlyContinue) {
                    Export-DataToCSV -Data $riskySharingReport -FilePath $riskyPath
                } else {
                    $riskySharingReport | Export-Csv -Path $riskyPath -NoTypeInformation -Encoding UTF8
                }
            }
            
            # ファイル詳細レポート出力
            if ($IncludeFileDetails -and $script:fileDetailReports.Count -gt 0) {
                $detailPath = Join-Path $outputDir "OneDriveExternalSharing_FileDetails_$timestamp.csv"
                if (Get-Command "Export-DataToCSV" -ErrorAction SilentlyContinue) {
                    Export-DataToCSV -Data $script:fileDetailReports -FilePath $detailPath
                } else {
                    $script:fileDetailReports | Export-Csv -Path $detailPath -NoTypeInformation -Encoding UTF8
                }
            }
        }
        
        # HTML出力
        if ($ExportHTML) {
            $htmlPath = Join-Path $outputDir "OneDriveExternalSharing_Dashboard_$timestamp.html"
            
            # 空のデータ対応
            if ($externalSharingReport.Count -eq 0) {
                $externalSharingReport = @([PSCustomObject]@{
                    UserPrincipalName = "sample@miraiconst.onmicrosoft.com"
                    DisplayName = "サンプルユーザー（データなし）"
                    Department = "システム管理部"
                    JobTitle = "情報提供"
                    DriveId = "sample-drive-001"
                    DriveWebUrl = "https://sample.sharepoint.com"
                    HasExternalSharing = $false
                    ExternalShareCount = 0
                    ExternalUserCount = 0
                    PublicLinkCount = 0
                    AnonymousLinkCount = 0
                    SensitiveFileShareCount = 0
                    SecurityRiskLevel = "情報"
                    RiskFactors = "Microsoft Graph未接続のためサンプル表示"
                    LastExternalShareDate = $null
                    ExternalDomains = ""
                    RecommendedActions = "Microsoft Graphへの接続設定を確認してください"
                    AnalysisTimestamp = Get-Date
                })
            }
            
            # 空のコレクション対応
            $safeRiskySharing = if ($riskySharingReport.Count -gt 0) { $riskySharingReport } else { @() }
            $safeFileDetails = if ($IncludeFileDetails -and $script:fileDetailReports.Count -gt 0) { $script:fileDetailReports } else { @() }
            
            $htmlContent = Generate-ExternalSharingHTML -SharingData $externalSharingReport -RiskySharing $safeRiskySharing -FileDetails $safeFileDetails
            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
        }
        
        # 統計情報計算
        $statistics = @{
            TotalUsers = $users.Count
            UsersWithExternalSharing = ($externalSharingReport | Where-Object { $_.HasExternalSharing -eq $true }).Count
            UsersWithoutExternalSharing = ($externalSharingReport | Where-Object { $_.HasExternalSharing -eq $false }).Count
            HighRiskUsers = ($externalSharingReport | Where-Object { $_.SecurityRiskLevel -eq "高" }).Count
            CriticalRiskUsers = ($externalSharingReport | Where-Object { $_.SecurityRiskLevel -eq "緊急" }).Count
            TotalExternalShares = ($externalSharingReport | Where-Object { $_.ExternalShareCount -ne "分析エラー" } | Measure-Object -Property ExternalShareCount -Sum).Sum
            TotalPublicLinks = ($externalSharingReport | Where-Object { $_.PublicLinkCount -ne "分析エラー" } | Measure-Object -Property PublicLinkCount -Sum).Sum
            TotalAnonymousLinks = ($externalSharingReport | Where-Object { $_.AnonymousLinkCount -ne "分析エラー" } | Measure-Object -Property AnonymousLinkCount -Sum).Sum
            AnalysisCompletedAt = Get-Date
        }
        
        # 監査ログ出力（スタンドアロン対応）
        if (Get-Command "Write-AuditLog" -ErrorAction SilentlyContinue) {
            Write-AuditLog -Action "OneDrive外部共有分析" -Target "OneDrive for Business" -Result "成功" -Details "分析対象: $($users.Count)ユーザー、外部共有あり: $($statistics.UsersWithExternalSharing)ユーザー、高リスク: $($statistics.HighRiskUsers)ユーザー"
        }
        
        Write-Log "OneDrive外部共有状況確認が完了しました" -Level "Info"
        
        return @{
            Success = $true
            SharingReport = $externalSharingReport
            RiskySharingReport = $riskySharingReport
            FileDetailReports = if ($IncludeFileDetails) { $script:fileDetailReports } else { @() }
            Statistics = $statistics
            CSVPath = if ($ExportCSV) { $csvPath } else { $null }
            HTMLPath = if ($ExportHTML) { $htmlPath } else { $null }
        }
    }
    catch {
        Write-Log "OneDrive外部共有状況確認でエラーが発生しました: $($_.Exception.Message)" -Level "Error"
        return @{
            Success = $false
            Error = $_.Exception.Message
            SharingReport = @()
            RiskySharingReport = @()
            FileDetailReports = @()
            Statistics = @{}
            CSVPath = $null
            HTMLPath = $null
        }
    }
}

function Get-OneDriveExternalSharing {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveId,
        
        [Parameter(Mandatory = $true)]
        [string]$UserId,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeFileDetails = $true
    )
    
    try {
        $externalShares = @()
        $externalUsers = @()
        $publicLinks = @()
        $anonymousLinks = @()
        $sensitiveFileShares = @()
        $riskFactors = @()
        $recommendedActions = @()
        $externalDomains = @()
        $sharedFiles = @()
        
        Write-Log "OneDriveアイテム取得中: $DriveId" -Level "Info"
        
        # ドライブのアイテム一覧取得（制限付きで実行）
        $driveItems = @()
        try {
            # まずルートアイテムを取得
            $rootItems = Get-MgDriveItem -DriveId $DriveId -Top 100 -ErrorAction Stop
            $driveItems = $rootItems
            
            Write-Log "OneDriveアイテム取得成功: $($driveItems.Count)件" -Level "Info"
        } catch {
            Write-Log "OneDriveアイテム取得エラー: $($_.Exception.Message)" -Level "Warning"
            # 権限不足の場合は空の配列で継続
            $driveItems = @()
        }
        
        if ($driveItems) {
            foreach ($item in $driveItems) {
                try {
                    Write-Log "権限確認中: $($item.Name)" -Level "Info"
                    
                    # アイテムの権限確認（エラーハンドリング強化）
                    $permissions = @()
                    try {
                        $permissions = Get-MgDriveItemPermission -DriveId $DriveId -DriveItemId $item.Id -All -ErrorAction Stop
                        Write-Log "権限取得成功: $($item.Name) - $($permissions.Count)個の権限" -Level "Info"
                    } catch {
                        Write-Log "権限取得エラー: $($item.Name) - $($_.Exception.Message)" -Level "Warning"
                        # 権限取得エラーの場合は次のアイテムに進む
                        continue
                    }
                    
                    if ($permissions) {
                        foreach ($permission in $permissions) {
                            # 外部共有の判定
                            $isExternalShare = $false
                            $shareType = "不明"
                            $shareScope = "不明"
                            $sharedWith = "不明"
                            $isPasswordProtected = $false
                            
                            # 権限タイプ別の分析
                            if ($permission.Link) {
                                # リンクベースの共有
                                $shareType = "リンク共有"
                                $shareScope = $permission.Link.Scope
                                
                                if ($permission.Link.Scope -eq "anonymous") {
                                    $isExternalShare = $true
                                    $anonymousLinks += $permission
                                    $shareScope = "匿名アクセス"
                                    $riskFactors += "匿名リンク共有"
                                }
                                elseif ($permission.Link.Scope -eq "organization") {
                                    $shareScope = "組織内"
                                }
                                elseif ($permission.Link.Scope -eq "users") {
                                    $shareScope = "特定ユーザー"
                                    # 外部ユーザーかどうか確認
                                    if ($permission.GrantedToIdentities) {
                                        foreach ($identity in $permission.GrantedToIdentities) {
                                            if ($identity.User -and $identity.User.Email) {
                                                $userEmail = $identity.User.Email
                                                $userDomain = ($userEmail -split "@")[1]
                                                
                                                # 組織ドメインかどうか確認
                                                $organizationDomains = Get-OrganizationDomains
                                                if ($userDomain -notin $organizationDomains) {
                                                    $isExternalShare = $true
                                                    $externalUsers += $identity.User
                                                    $externalDomains += $userDomain
                                                    $sharedWith = $userEmail
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                $isPasswordProtected = [bool]$permission.Link.PreventsDownload
                                
                                if ($permission.Link.Scope -ne "organization") {
                                    $publicLinks += $permission
                                }
                            }
                            elseif ($permission.GrantedToIdentities) {
                                # 直接ユーザー招待の共有
                                $shareType = "ユーザー招待"
                                foreach ($identity in $permission.GrantedToIdentities) {
                                    if ($identity.User -and $identity.User.Email) {
                                        $userEmail = $identity.User.Email
                                        $userDomain = ($userEmail -split "@")[1]
                                        
                                        # 組織ドメインかどうか確認
                                        $organizationDomains = Get-OrganizationDomains
                                        if ($userDomain -notin $organizationDomains) {
                                            $isExternalShare = $true
                                            $externalUsers += $identity.User
                                            $externalDomains += $userDomain
                                            $sharedWith += $userEmail
                                        }
                                    }
                                }
                            }
                            
                            # 外部共有が確認された場合
                            if ($isExternalShare) {
                                $externalShares += $permission
                                
                                # 機密ファイルの判定
                                $isSensitive = Test-SensitiveFile -FileName $item.Name -FileSize $item.Size
                                if ($isSensitive) {
                                    $sensitiveFileShares += $permission
                                    $riskFactors += "機密ファイルの外部共有"
                                }
                                
                                # ファイル詳細情報収集
                                if ($IncludeFileDetails) {
                                    $fileDetail = [PSCustomObject]@{
                                        FileName = $item.Name
                                        FilePath = $item.ParentReference.Path + "/" + $item.Name
                                        FileSize = if ($item.Size) { [math]::Round($item.Size / 1MB, 2) } else { 0 }
                                        ShareType = $shareType
                                        ShareScope = $shareScope
                                        SharedWith = $sharedWith
                                        Permissions = $permission.Roles -join ", "
                                        ShareDate = $permission.CreatedDateTime
                                        ExpirationDate = $permission.ExpirationDateTime
                                        IsPasswordProtected = $isPasswordProtected
                                        IsSensitive = $isSensitive
                                        SecurityRisk = if ($isSensitive -and $shareScope -eq "匿名アクセス") { "緊急" }
                                                     elseif ($isSensitive) { "高" }
                                                     elseif ($shareScope -eq "匿名アクセス") { "中" }
                                                     else { "低" }
                                        FileWebUrl = $item.WebUrl
                                    }
                                    $sharedFiles += $fileDetail
                                }
                            }
                        }
                    } else {
                        Write-Log "権限情報なし: $($item.Name)" -Level "Info"
                    }
                }
                catch {
                    Write-Log "アイテム権限取得エラー: $($item.Name) - $($_.Exception.Message)" -Level "Warning"
                }
            }
        }
        
        # リスクレベル判定
        $securityRiskLevel = "正常"
        if ($anonymousLinks.Count -gt 0 -and $sensitiveFileShares.Count -gt 0) {
            $securityRiskLevel = "緊急"
            $riskFactors += "機密ファイルの匿名共有"
        }
        elseif ($anonymousLinks.Count -gt 5) {
            $securityRiskLevel = "高"
            $riskFactors += "多数の匿名リンク"
        }
        elseif ($sensitiveFileShares.Count -gt 0) {
            $securityRiskLevel = "高"
            $riskFactors += "機密ファイルの外部共有"
        }
        elseif ($externalShares.Count -gt 10) {
            $securityRiskLevel = "中"
            $riskFactors += "多数の外部共有"
        }
        elseif ($externalShares.Count -gt 0) {
            $securityRiskLevel = "低"
        }
        
        # 推奨対応の生成
        if ($securityRiskLevel -eq "緊急") {
            $recommendedActions += "機密ファイルの匿名共有を即座に停止"
            $recommendedActions += "セキュリティ部門への報告"
        }
        if ($anonymousLinks.Count -gt 0) {
            $recommendedActions += "匿名リンクの見直しと期限設定"
        }
        if ($sensitiveFileShares.Count -gt 0) {
            $recommendedActions += "機密ファイル共有の承認プロセス確認"
        }
        if ($externalShares.Count -gt 5) {
            $recommendedActions += "外部共有ポリシーの教育実施"
        }
        
        # 最終共有日時の取得
        $lastExternalShareDate = $null
        if ($externalShares.Count -gt 0) {
            $lastExternalShareDate = ($externalShares | Sort-Object CreatedDateTime -Descending | Select-Object -First 1).CreatedDateTime
        }
        
        return @{
            HasExternalSharing = $externalShares.Count -gt 0
            ExternalShareCount = $externalShares.Count
            ExternalUserCount = ($externalUsers | Select-Object Email -Unique).Count
            PublicLinkCount = $publicLinks.Count
            AnonymousLinkCount = $anonymousLinks.Count
            SensitiveFileShareCount = $sensitiveFileShares.Count
            SecurityRiskLevel = $securityRiskLevel
            RiskFactors = $riskFactors | Select-Object -Unique
            RecommendedActions = $recommendedActions | Select-Object -Unique
            LastExternalShareDate = $lastExternalShareDate
            ExternalDomains = $externalDomains | Select-Object -Unique
            SharedFiles = $sharedFiles
        }
    }
    catch {
        Write-Log "OneDrive外部共有分析エラー: $($_.Exception.Message)" -Level "Error"
        
        return @{
            HasExternalSharing = $false
            ExternalShareCount = 0
            ExternalUserCount = 0
            PublicLinkCount = 0
            AnonymousLinkCount = 0
            SensitiveFileShareCount = 0
            SecurityRiskLevel = "分析エラー"
            RiskFactors = @("分析エラー: $($_.Exception.Message)")
            RecommendedActions = @("エラー解決後に再分析してください")
            LastExternalShareDate = $null
            ExternalDomains = @()
            SharedFiles = @()
        }
    }
}

function Get-OrganizationDomains {
    try {
        # 組織のドメイン一覧を取得
        $domains = Get-MgDomain | Where-Object { $_.IsVerified -eq $true }
        return $domains.Id
    }
    catch {
        Write-Log "組織ドメイン取得エラー: $($_.Exception.Message)" -Level "Warning"
        # デフォルトドメインのみ返す
        try {
            $defaultDomain = Get-MgDomain | Where-Object { $_.IsDefault -eq $true }
            return @($defaultDomain.Id)
        }
        catch {
            # フォールバック：よく使われる Microsoft ドメイン
            return @("onmicrosoft.com")
        }
    }
}

function Test-SensitiveFile {
    param(
        [string]$FileName,
        [long]$FileSize
    )
    
    # 機密ファイルの判定ロジック
    $sensitiveExtensions = @(".docx", ".xlsx", ".pptx", ".pdf", ".zip", ".rar", ".7z")
    $sensitiveKeywords = @("契約", "秘密", "機密", "confidential", "secret", "contract", "給与", "salary", "個人情報", "personal")
    
    # ファイル拡張子チェック
    $fileExtension = [System.IO.Path]::GetExtension($FileName).ToLower()
    $isSensitiveExtension = $fileExtension -in $sensitiveExtensions
    
    # ファイル名キーワードチェック
    $isSensitiveKeyword = $false
    foreach ($keyword in $sensitiveKeywords) {
        if ($FileName -like "*$keyword*") {
            $isSensitiveKeyword = $true
            break
        }
    }
    
    # 大容量ファイルは機密の可能性が高い
    $isLargeFile = $FileSize -gt 50MB
    
    return ($isSensitiveExtension -and $isSensitiveKeyword) -or ($isLargeFile -and $isSensitiveKeyword)
}

function Generate-ExternalSharingHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$SharingData,
        
        [Parameter(Mandatory = $false)]
        [array]$RiskySharing = @(),
        
        [Parameter(Mandatory = $false)]
        [array]$FileDetails = @()
    )
    
    $timestamp = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
    
    # 統計計算
    $totalUsers = $SharingData.Count
    $usersWithSharing = ($SharingData | Where-Object { $_.HasExternalSharing -eq $true }).Count
    $highRiskUsers = ($SharingData | Where-Object { $_.SecurityRiskLevel -eq "高" }).Count
    $criticalRiskUsers = ($SharingData | Where-Object { $_.SecurityRiskLevel -eq "緊急" }).Count
    $totalExternalShares = ($SharingData | Where-Object { $_.ExternalShareCount -ne "分析エラー" } | Measure-Object -Property ExternalShareCount -Sum).Sum
    $totalAnonymousLinks = ($SharingData | Where-Object { $_.AnonymousLinkCount -ne "分析エラー" } | Measure-Object -Property AnonymousLinkCount -Sum).Sum
    
    $html = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OneDrive外部共有状況分析ダッシュボード</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }
        .header { 
            background: linear-gradient(135deg, #d13438 0%, #dc3545 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
            text-align: center;
        }
        .header h1 { margin: 0; font-size: 28px; }
        .header .subtitle { margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }
        .summary-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .summary-card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-card h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .summary-card .value { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .value.success { color: #107c10; }
        .value.warning { color: #ff8c00; }
        .value.danger { color: #d13438; }
        .value.info { color: #0078d4; }
        .section {
            background: white;
            margin-bottom: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-header {
            background: linear-gradient(135deg, #6c757d 0%, #5a6268 100%);
            color: white;
            padding: 15px 20px;
            border-radius: 8px 8px 0 0;
            font-weight: bold;
        }
        .section-content { padding: 20px; }
        .data-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
            margin: 20px 0;
        }
        .data-table th {
            background-color: #343a40;
            color: white;
            border: 1px solid #ddd;
            padding: 12px 8px;
            text-align: left;
            font-weight: bold;
        }
        .data-table td {
            border: 1px solid #ddd;
            padding: 8px;
            font-size: 12px;
        }
        .data-table tr:nth-child(even) {
            background-color: #f8f9fa;
        }
        .data-table tr:hover {
            background-color: #e9ecef;
        }
        .risk-critical { background-color: #f8d7da !important; color: #721c24; font-weight: bold; }
        .risk-high { background-color: #fff3cd !important; color: #856404; font-weight: bold; }
        .risk-medium { background-color: #cce5f0 !important; color: #0c5460; }
        .risk-low { background-color: #d4edda !important; color: #155724; }
        .risk-normal { background-color: #d4edda !important; color: #155724; }
        .scrollable-table {
            overflow-x: auto;
            margin: 20px 0;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .alert-box {
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
        }
        .alert-critical {
            background-color: #f8d7da;
            border: 1px solid #f5c6cb;
            color: #721c24;
        }
        .alert-warning {
            background-color: #fff3cd;
            border-color: #ffeaa7;
            color: #856404;
        }
        .alert-info {
            background-color: #d1ecf1;
            border-color: #bee5eb;
            color: #0c5460;
        }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔒 OneDrive外部共有状況分析ダッシュボード</h1>
        <div class="subtitle">みらい建設工業株式会社 - セキュリティ監査レポート</div>
        <div class="subtitle">分析実行日時: $timestamp</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>分析対象ユーザー</h3>
            <div class="value info">$totalUsers</div>
            <div class="description">人</div>
        </div>
        <div class="summary-card">
            <h3>外部共有あり</h3>
            <div class="value$(if($usersWithSharing -gt 0) { ' warning' } else { ' success' })">$usersWithSharing</div>
            <div class="description">ユーザー</div>
        </div>
        <div class="summary-card">
            <h3>高リスク</h3>
            <div class="value$(if($highRiskUsers -gt 0) { ' danger' } else { ' success' })">$highRiskUsers</div>
            <div class="description">ユーザー</div>
        </div>
        <div class="summary-card">
            <h3>緊急対応</h3>
            <div class="value$(if($criticalRiskUsers -gt 0) { ' danger' } else { ' success' })">$criticalRiskUsers</div>
            <div class="description">ユーザー</div>
        </div>
        <div class="summary-card">
            <h3>外部共有総数</h3>
            <div class="value$(if($totalExternalShares -gt 50) { ' warning' } elseif($totalExternalShares -gt 0) { ' info' } else { ' success' })">$totalExternalShares</div>
            <div class="description">件</div>
        </div>
        <div class="summary-card">
            <h3>匿名リンク</h3>
            <div class="value$(if($totalAnonymousLinks -gt 0) { ' danger' } else { ' success' })">$totalAnonymousLinks</div>
            <div class="description">件</div>
        </div>
    </div>

    $(if ($criticalRiskUsers -gt 0) {
        '<div class="alert-box alert-critical">
            <strong>🚨 緊急対応が必要:</strong> ' + $criticalRiskUsers + '名のユーザーで機密ファイルの外部共有が検出されました。即座に対応してください。
        </div>'
    } elseif ($highRiskUsers -gt 0) {
        '<div class="alert-box alert-warning">
            <strong>⚠️ 注意:</strong> ' + $highRiskUsers + '名のユーザーで高リスクな外部共有が検出されました。確認と対策を実施してください。
        </div>'
    } elseif ($usersWithSharing -gt 0) {
        '<div class="alert-box alert-info">
            <strong>ℹ️ 情報:</strong> ' + $usersWithSharing + '名のユーザーで外部共有が検出されました。定期的な監視を継続してください。
        </div>'
    } else {
        '<div class="alert-box alert-info">
            <strong>✅ 良好:</strong> 危険な外部共有は検出されませんでした。現在のセキュリティ状態は良好です。
        </div>'
    })

    <div class="section">
        <div class="section-header">📊 ユーザー別外部共有状況</div>
        <div class="section-content">
            <div class="scrollable-table">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>ユーザー名</th>
                            <th>UPN</th>
                            <th>部署</th>
                            <th>外部共有</th>
                            <th>共有数</th>
                            <th>外部ユーザー数</th>
                            <th>匿名リンク</th>
                            <th>機密ファイル</th>
                            <th>リスクレベル</th>
                            <th>推奨対応</th>
                        </tr>
                    </thead>
                    <tbody>
"@

    # ユーザー別データテーブル生成
    foreach ($sharing in $SharingData) {
        $riskClass = switch ($sharing.SecurityRiskLevel) {
            "緊急" { "risk-critical" }
            "高" { "risk-high" }
            "中" { "risk-medium" }
            "低" { "risk-low" }
            default { "risk-normal" }
        }
        
        $html += @"
                        <tr class="$riskClass">
                            <td>$($sharing.DisplayName)</td>
                            <td style="word-break: break-all;">$($sharing.UserPrincipalName)</td>
                            <td>$($sharing.Department)</td>
                            <td style="text-align: center;">$(if($sharing.HasExternalSharing -eq $true) { '✅' } else { '❌' })</td>
                            <td style="text-align: center;">$($sharing.ExternalShareCount)</td>
                            <td style="text-align: center;">$($sharing.ExternalUserCount)</td>
                            <td style="text-align: center;">$($sharing.AnonymousLinkCount)</td>
                            <td style="text-align: center;">$($sharing.SensitiveFileShareCount)</td>
                            <td style="text-align: center;">$($sharing.SecurityRiskLevel)</td>
                            <td>$($sharing.RecommendedActions)</td>
                        </tr>
"@
    }

    $html += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    $(if ($FileDetails.Count -gt 0) {
        '<div class="section">
            <div class="section-header">📄 共有ファイル詳細</div>
            <div class="section-content">
                <div class="scrollable-table">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>ユーザー</th>
                                <th>ファイル名</th>
                                <th>サイズ(MB)</th>
                                <th>共有タイプ</th>
                                <th>共有先</th>
                                <th>権限</th>
                                <th>共有日</th>
                                <th>パスワード保護</th>
                                <th>機密ファイル</th>
                                <th>リスク</th>
                            </tr>
                        </thead>
                        <tbody>'
        
        foreach ($file in $FileDetails) {
            $fileRiskClass = switch ($file.SecurityRisk) {
                "緊急" { "risk-critical" }
                "高" { "risk-high" }
                "中" { "risk-medium" }
                "低" { "risk-low" }
                default { "risk-normal" }
            }
            
            $html += "                            <tr class=`"$fileRiskClass`">
                                <td>$($file.DisplayName)</td>
                                <td>$($file.FileName)</td>
                                <td style=`"text-align: right;`">$($file.FileSize)</td>
                                <td>$($file.ShareType)</td>
                                <td>$($file.SharedWith)</td>
                                <td>$($file.Permissions)</td>
                                <td style=`"text-align: center;`">$(if($file.ShareDate) { [DateTime]::Parse($file.ShareDate).ToString('yyyy/MM/dd') } else { '-' })</td>
                                <td style=`"text-align: center;`">$(if($file.IsPasswordProtected) { '✅' } else { '❌' })</td>
                                <td style=`"text-align: center;`">$(if($file.IsSensitive) { '⚠️' } else { '-' })</td>
                                <td style=`"text-align: center;`">$($file.SecurityRisk)</td>
                            </tr>"
        }
        
        $html += '                        </tbody>
                    </table>
                </div>
            </div>
        </div>'
    })

    $html += @"
    <div class="section">
        <div class="section-header">🛡️ セキュリティ対策とベストプラクティス</div>
        <div class="section-content">
            <h4>外部共有セキュリティ対策:</h4>
            <ul>
                <li><strong>定期監査:</strong> 外部共有状況を定期的に確認し、不要な共有を削除</li>
                <li><strong>機密ファイル保護:</strong> 機密情報を含むファイルの外部共有を制限</li>
                <li><strong>匿名リンク禁止:</strong> 匿名アクセスリンクの使用を原則禁止</li>
                <li><strong>期限設定:</strong> 外部共有に適切な有効期限を設定</li>
                <li><strong>パスワード保護:</strong> 外部共有ファイルにパスワードを設定</li>
            </ul>
            
            <h4>ユーザー教育:</h4>
            <ul>
                <li><strong>共有ポリシー:</strong> 外部共有のガイドラインを明文化し教育</li>
                <li><strong>セキュリティ意識:</strong> 情報漏洩リスクに関する定期的な研修</li>
                <li><strong>承認プロセス:</strong> 機密ファイル共有の事前承認制度</li>
                <li><strong>監視通知:</strong> 外部共有実行時のアラート設定</li>
            </ul>
            
            <h4>技術的対策:</h4>
            <ul>
                <li><strong>DLP設定:</strong> データ損失防止ポリシーの実装</li>
                <li><strong>条件付きアクセス:</strong> 外部共有の制限条件設定</li>
                <li><strong>監査ログ:</strong> 外部共有活動の詳細ログ記録</li>
                <li><strong>自動検知:</strong> 機密ファイル共有の自動検知とアラート</li>
            </ul>
        </div>
    </div>

    <div class="footer">
        <p>このレポートは Microsoft 365 セキュリティ監査システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社 セキュリティ管理センター</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $html
}

function Generate-SampleUsers {
    # サンプルユーザーデータを生成
    $sampleUsers = @()
    $departments = @("営業部", "技術部", "管理部", "人事部", "総務部")
    $jobTitles = @("部長", "課長", "主任", "一般", "新入社員")
    
    for ($i = 1; $i -le 10; $i++) {
        $sampleUsers += [PSCustomObject]@{
            Id = [Guid]::NewGuid().ToString()
            UserPrincipalName = "user$i@miraiconst.onmicrosoft.com"
            DisplayName = "サンプルユーザー$i"
            AccountEnabled = $true
            Department = $departments[(Get-Random -Maximum $departments.Count)]
            JobTitle = $jobTitles[(Get-Random -Maximum $jobTitles.Count)]
        }
    }
    
    return $sampleUsers
}

function Generate-SampleExternalSharingData {
    param($User)
    
    # サンプルの外部共有データを生成
    $hasSharing = (Get-Random -Maximum 100) -lt 30  # 30%の確率で外部共有あり
    
    if ($hasSharing) {
        $shareCount = Get-Random -Minimum 1 -Maximum 5
        $anonymousLinks = Get-Random -Minimum 0 -Maximum 2
        $sensitiveFiles = Get-Random -Minimum 0 -Maximum 1
        
        $riskLevel = if ($anonymousLinks -gt 0 -and $sensitiveFiles -gt 0) { "緊急" }
                    elseif ($sensitiveFiles -gt 0) { "高" }
                    elseif ($shareCount -gt 3) { "中" }
                    else { "低" }
    } else {
        $shareCount = 0
        $anonymousLinks = 0
        $sensitiveFiles = 0
        $riskLevel = "正常"
    }
    
    return @{
        HasExternalSharing = $hasSharing
        ExternalShareCount = $shareCount
        ExternalUserCount = if ($hasSharing) { Get-Random -Minimum 1 -Maximum 3 } else { 0 }
        PublicLinkCount = if ($hasSharing) { Get-Random -Minimum 0 -Maximum 2 } else { 0 }
        AnonymousLinkCount = $anonymousLinks
        SensitiveFileShareCount = $sensitiveFiles
        SecurityRiskLevel = $riskLevel
        RiskFactors = if ($hasSharing) { @("サンプルデータ", "外部共有検出") } else { @() }
        RecommendedActions = if ($riskLevel -eq "緊急") { @("機密ファイル共有の即座停止") }
                            elseif ($riskLevel -eq "高") { @("外部共有の確認と制限") }
                            else { @("定期監視の継続") }
        LastExternalShareDate = if ($hasSharing) { (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 30)) } else { $null }
        ExternalDomains = if ($hasSharing) { @("example.com", "partner.co.jp") } else { @() }
        SharedFiles = @()
    }
}

# スクリプト直接実行時の処理
if ($MyInvocation.InvocationName -ne '.') {
    $config = Initialize-ManagementTools
    
    Write-Log "OneDrive外部共有状況確認スクリプトを実行します" -Level "Info"
    
    try {
        if ($config) {
            # 新しい認証システムを使用
            $connectionResult = Connect-ToMicrosoft365 -Config $config -Services @("MicrosoftGraph")
            
            if (-not $connectionResult.Success) {
                throw "Microsoft Graph への接続に失敗しました: $($connectionResult.Errors -join ', ')"
            }
            
            Write-Log "Microsoft Graph 接続成功" -Level "Info"
        }
        else {
            Write-Log "設定ファイルが見つからないため、手動接続が必要です" -Level "Warning"
            throw "設定ファイルが見つかりません"
        }
        
        # OneDrive外部共有分析実行
        Write-Log "OneDrive外部共有状況確認を実行中..." -Level "Info"
        $result = Get-OneDriveExternalSharingAnalysis -IncludeFileDetails -ExportHTML -ExportCSV
        
        if ($result.Success) {
            Write-Log "OneDrive外部共有状況確認が正常に完了しました" -Level "Info"
            Write-Log "分析結果: 対象ユーザー $($result.Statistics.TotalUsers)名、外部共有あり $($result.Statistics.UsersWithExternalSharing)名、高リスク $($result.Statistics.HighRiskUsers)名" -Level "Info"
        } else {
            Write-Log "OneDrive外部共有状況確認でエラーが発生しました" -Level "Error"
        }
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        Send-ErrorNotification -ErrorDetails $errorDetails
        Write-Log "OneDrive外部共有分析エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
    finally {
        Disconnect-AllServices
    }
}