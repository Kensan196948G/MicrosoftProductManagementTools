# ================================================================================
# UserSecurityManagement.ps1
# Entra ID ユーザーセキュリティ管理スクリプト
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force

function Get-EntraIDMFAStatus {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Weekly"
    )
    
    return Invoke-SafeOperation -OperationName "Entra ID MFA状況確認" -Operation {
        Write-Log "Entra ID MFA状況の確認を開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users", "Microsoft.Graph.Identity.SignIns")
        
        $users = Get-MgUser -All -Property UserPrincipalName,DisplayName,AccountEnabled,Department,JobTitle
        $mfaReport = @()
        
        foreach ($user in $users) {
            try {
                $authMethods = Get-MgUserAuthenticationMethod -UserId $user.Id
                $strongAuthMethods = Get-MgUserAuthenticationPhoneMethod -UserId $user.Id -ErrorAction SilentlyContinue
                $appAuthMethods = Get-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $user.Id -ErrorAction SilentlyContinue
                
                $hasMFA = $false
                $mfaTypes = @()
                
                if ($strongAuthMethods) {
                    $hasMFA = $true
                    $mfaTypes += "電話"
                }
                
                if ($appAuthMethods) {
                    $hasMFA = $true
                    $mfaTypes += "認証アプリ"
                }
                
                $signInActivity = Get-MgUserSignInActivity -UserId $user.Id -ErrorAction SilentlyContinue
                
                $mfaReport += [PSCustomObject]@{
                    UserPrincipalName = $user.UserPrincipalName
                    DisplayName = $user.DisplayName
                    AccountEnabled = $user.AccountEnabled
                    Department = $user.Department
                    JobTitle = $user.JobTitle
                    HasMFA = $hasMFA
                    MFATypes = ($mfaTypes -join ", ")
                    LastSignIn = $signInActivity.LastSignInDateTime
                    LastNonInteractiveSignIn = $signInActivity.LastNonInteractiveSignInDateTime
                    RiskLevel = if (-not $hasMFA -and $user.AccountEnabled) { "高" } 
                               elseif (-not $hasMFA) { "中" } 
                               else { "低" }
                }
            }
            catch {
                Write-Log "MFA状況取得エラー: $($user.UserPrincipalName) - $($_.Exception.Message)" -Level "Warning"
                
                $mfaReport += [PSCustomObject]@{
                    UserPrincipalName = $user.UserPrincipalName
                    DisplayName = $user.DisplayName
                    AccountEnabled = $user.AccountEnabled
                    Department = $user.Department
                    JobTitle = $user.JobTitle
                    HasMFA = "取得エラー"
                    MFATypes = "取得エラー"
                    LastSignIn = "取得エラー"
                    LastNonInteractiveSignIn = "取得エラー"
                    RiskLevel = "不明"
                }
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Weekly") "EntraIDMFAStatus_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $mfaReport -FilePath $outputFile
        
        $noMFACount = ($mfaReport | Where-Object { $_.HasMFA -eq $false -and $_.AccountEnabled -eq $true }).Count
        Write-AuditLog -Action "MFA状況確認" -Target "全Entra IDユーザー" -Result "成功" -Details "$($mfaReport.Count)件中$noMFACount件がMFA未設定"
        
        return $mfaReport
    }
}

function Get-EntraIDSignInAnalysis {
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 7,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Daily"
    )
    
    return Invoke-SafeOperation -OperationName "Entra IDサインイン分析" -Operation {
        Write-Log "Entra IDサインイン分析を開始します（過去 $DaysBack 日間）" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("Microsoft.Graph.Authentication", "Microsoft.Graph.Reports")
        
        $startDate = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-dd")
        
        try {
            $signInLogs = Get-MgAuditLogSignIn -Filter "createdDateTime ge $startDate" -All
            
            $signInReport = foreach ($log in $signInLogs) {
                [PSCustomObject]@{
                    CreatedDateTime = $log.CreatedDateTime
                    UserPrincipalName = $log.UserPrincipalName
                    AppDisplayName = $log.AppDisplayName
                    ClientAppUsed = $log.ClientAppUsed
                    DeviceDetail = $log.DeviceDetail.DisplayName
                    LocationCity = $log.Location.City
                    LocationCountryOrRegion = $log.Location.CountryOrRegion
                    IpAddress = $log.IpAddress
                    Status = $log.Status.ErrorCode
                    FailureReason = $log.Status.FailureReason
                    RiskLevel = $log.RiskLevelDuringSignIn
                    RiskState = $log.RiskState
                    ConditionalAccessStatus = $log.ConditionalAccessStatus
                    IsInteractive = $log.IsInteractive
                }
            }
            
            $failedSignIns = $signInReport | Where-Object { $_.Status -ne 0 }
            $riskySignIns = $signInReport | Where-Object { $_.RiskLevel -in @("medium", "high") }
            
            $outputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "EntraIDSignInAnalysis_$(Get-Date -Format 'yyyyMMdd').csv"
            Export-DataToCSV -Data $signInReport -FilePath $outputFile
            
            $failedOutputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "EntraIDFailedSignIns_$(Get-Date -Format 'yyyyMMdd').csv"
            Export-DataToCSV -Data $failedSignIns -FilePath $failedOutputFile
            
            $riskyOutputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "EntraIDRiskySignIns_$(Get-Date -Format 'yyyyMMdd').csv"
            Export-DataToCSV -Data $riskySignIns -FilePath $riskyOutputFile
        }
        catch {
            # E3ライセンスではサインインログ取得に制限があります
            if ($_.Exception.Message -like "*Authentication_RequestFromNonPremiumTenantOrB2CTenant*" -or $_.Exception.Message -like "*Forbidden*") {
                Write-Log "E3ライセンス制限: サインインログ取得はプレミアムライセンスが必要です。ユーザーベースの代替分析を実行します" -Level "Warning"
                
                # 代替案：ユーザーのサインインアクティビティを使用した分析
                try {
                    $users = Get-MgUser -All -Property UserPrincipalName,DisplayName,AccountEnabled,SignInActivity
                    $signInReport = foreach ($user in $users) {
                        if ($user.SignInActivity) {
                            [PSCustomObject]@{
                                CreatedDateTime = $user.SignInActivity.LastSignInDateTime
                                UserPrincipalName = $user.UserPrincipalName
                                AppDisplayName = "E3制限により不明"
                                ClientAppUsed = "E3制限により不明"
                                DeviceDetail = "E3制限により不明"
                                LocationCity = "E3制限により不明"
                                LocationCountryOrRegion = "E3制限により不明"
                                IpAddress = "E3制限により不明"
                                Status = "E3制限により不明"
                                FailureReason = "E3制限により不明"
                                RiskLevel = "E3制限により不明"
                                RiskState = "E3制限により不明"
                                ConditionalAccessStatus = "E3制限により不明"
                                IsInteractive = "E3制限により不明"
                            }
                        }
                    }
                    
                    $failedSignIns = @()  # E3では失敗ログ取得不可
                    $riskySignIns = @()   # E3ではリスクレベル取得不可
                    
                    # E3制限についての注意情報を含むCSV出力
                    $outputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "EntraIDSignInAnalysis_E3Limited_$(Get-Date -Format 'yyyyMMdd').csv"
                    if ($signInReport) {
                        Export-DataToCSV -Data $signInReport -FilePath $outputFile
                    }
                    
                    Write-Log "E3制限環境でのサインイン分析が完了しました。詳細情報は制限されています" -Level "Info"
                }
                catch {
                    Write-Log "代替サインイン分析もエラー: $($_.Exception.Message)" -Level "Warning"
                    $signInReport = @()
                    $failedSignIns = @()
                    $riskySignIns = @()
                }
            }
            else {
                Write-Log "サインインログ取得エラー: $($_.Exception.Message)" -Level "Error"
                $signInReport = @()
                $failedSignIns = @()
                $riskySignIns = @()
            }
        }
        
        Write-AuditLog -Action "サインイン分析" -Target "Entra IDサインインログ" -Result "成功" -Details "総数:$($signInReport.Count)件、失敗:$($failedSignIns.Count)件、リスク:$($riskySignIns.Count)件"
        
        return @{
            AllSignIns = $signInReport
            FailedSignIns = $failedSignIns
            RiskySignIns = $riskySignIns
        }
    }
}

function Get-EntraIDLicenseReport {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -OperationName "Entra IDライセンスレポート" -Operation {
        Write-Log "Entra IDライセンスレポートを開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users", "Microsoft.Graph.Identity.DirectoryManagement")
        
        $users = Get-MgUser -All -Property UserPrincipalName,DisplayName,AccountEnabled,AssignedLicenses,Department,JobTitle,CreatedDateTime,LastPasswordChangeDateTime
        $subscriptions = Get-MgSubscribedSku
        
        $subscriptionMap = @{}
        foreach ($sub in $subscriptions) {
            $subscriptionMap[$sub.SkuId] = $sub.SkuPartNumber
        }
        
        $licenseReport = foreach ($user in $users) {
            $assignedLicenses = @()
            foreach ($license in $user.AssignedLicenses) {
                if ($subscriptionMap.ContainsKey($license.SkuId)) {
                    $assignedLicenses += $subscriptionMap[$license.SkuId]
                }
            }
            
            [PSCustomObject]@{
                UserPrincipalName = $user.UserPrincipalName
                DisplayName = $user.DisplayName
                AccountEnabled = $user.AccountEnabled
                Department = $user.Department
                JobTitle = $user.JobTitle
                AssignedLicenses = ($assignedLicenses -join "; ")
                LicenseCount = $assignedLicenses.Count
                HasM365License = if ($assignedLicenses -match "ENTERPRISEPACK|BUSINESS|SPE_E") { $true } else { $false }
                CreatedDateTime = $user.CreatedDateTime
                LastPasswordChangeDateTime = $user.LastPasswordChangeDateTime
                DaysSinceCreated = if ($user.CreatedDateTime) { ((Get-Date) - $user.CreatedDateTime).Days } else { "不明" }
            }
        }
        
        $licenseOutputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "EntraIDLicenseReport_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $licenseReport -FilePath $licenseOutputFile
        
        $subscriptionReport = foreach ($sub in $subscriptions) {
            [PSCustomObject]@{
                SkuPartNumber = $sub.SkuPartNumber
                SkuId = $sub.SkuId
                ConsumedUnits = $sub.ConsumedUnits
                PrepaidUnits = $sub.PrepaidUnits.Enabled
                SuspendedUnits = $sub.PrepaidUnits.Suspended
                WarningUnits = $sub.PrepaidUnits.Warning
                AvailableUnits = $sub.PrepaidUnits.Enabled - $sub.ConsumedUnits
                UtilizationPercent = if ($sub.PrepaidUnits.Enabled -gt 0) { 
                    [math]::Round(($sub.ConsumedUnits / $sub.PrepaidUnits.Enabled) * 100, 2) 
                } else { 0 }
            }
        }
        
        $subscriptionOutputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "EntraIDSubscriptionReport_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $subscriptionReport -FilePath $subscriptionOutputFile
        
        $unlicensedUsers = ($licenseReport | Where-Object { $_.LicenseCount -eq 0 -and $_.AccountEnabled -eq $true }).Count
        Write-AuditLog -Action "ライセンスレポート" -Target "全Entra IDユーザー" -Result "成功" -Details "$($licenseReport.Count)件中$unlicensedUsers件がライセンス未付与"
        
        return @{
            UserLicenses = $licenseReport
            Subscriptions = $subscriptionReport
        }
    }
}

function Get-EntraIDApplicationReport {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -OperationName "Entra IDアプリケーションレポート" -Operation {
        Write-Log "Entra IDアプリケーションレポートを開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("Microsoft.Graph.Authentication", "Microsoft.Graph.Applications")
        
        $applications = Get-MgApplication -All -Property DisplayName,AppId,SignInAudience,CreatedDateTime,PasswordCredentials,KeyCredentials,RequiredResourceAccess
        
        $appReport = foreach ($app in $applications) {
            $hasSecrets = $app.PasswordCredentials.Count -gt 0
            $hasCertificates = $app.KeyCredentials.Count -gt 0
            
            $expiredSecrets = $app.PasswordCredentials | Where-Object { $_.EndDateTime -lt (Get-Date) }
            $expiringSoonSecrets = $app.PasswordCredentials | Where-Object { 
                $_.EndDateTime -gt (Get-Date) -and $_.EndDateTime -lt (Get-Date).AddDays(30) 
            }
            
            $permissions = @()
            foreach ($resource in $app.RequiredResourceAccess) {
                foreach ($scope in $resource.ResourceAccess) {
                    $permissions += "$($resource.ResourceAppId):$($scope.Id)"
                }
            }
            
            [PSCustomObject]@{
                DisplayName = $app.DisplayName
                AppId = $app.AppId
                SignInAudience = $app.SignInAudience
                CreatedDateTime = $app.CreatedDateTime
                HasSecrets = $hasSecrets
                HasCertificates = $hasCertificates
                SecretCount = $app.PasswordCredentials.Count
                CertificateCount = $app.KeyCredentials.Count
                ExpiredSecretsCount = $expiredSecrets.Count
                ExpiringSoonSecretsCount = $expiringSoonSecrets.Count
                RequiredPermissions = ($permissions -join "; ")
                PermissionCount = $permissions.Count
                DaysSinceCreated = if ($app.CreatedDateTime) { ((Get-Date) - $app.CreatedDateTime).Days } else { "不明" }
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "EntraIDApplicationReport_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $appReport -FilePath $outputFile
        
        $highRiskApps = ($appReport | Where-Object { 
            $_.ExpiredSecretsCount -gt 0 -or 
            $_.ExpiringSoonSecretsCount -gt 0 -or
            $_.PermissionCount -gt 10
        }).Count
        
        Write-AuditLog -Action "アプリケーションレポート" -Target "Entra IDアプリケーション" -Result "成功" -Details "$($appReport.Count)件中$highRiskApps件が要注意"
        
        return $appReport
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $config = Initialize-ManagementTools
    
    Write-Log "Entra IDユーザーセキュリティ管理スクリプトを実行します" -Level "Info"
    
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
        
        # 各レポート実行
        Write-Log "MFA状況レポートを実行中..." -Level "Info"
        Get-EntraIDMFAStatus
        
        Write-Log "サインイン分析レポートを実行中..." -Level "Info"
        Get-EntraIDSignInAnalysis
        
        Write-Log "ライセンスレポートを実行中..." -Level "Info"
        Get-EntraIDLicenseReport
        
        Write-Log "アプリケーションレポートを実行中..." -Level "Info"
        Get-EntraIDApplicationReport
        
        Write-Log "Entra IDユーザーセキュリティ管理スクリプトが正常に完了しました" -Level "Info"
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        Send-ErrorNotification -ErrorDetails $errorDetails
        Write-Log "Entra IDユーザーセキュリティ管理エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
    finally {
        Disconnect-AllServices
    }
}