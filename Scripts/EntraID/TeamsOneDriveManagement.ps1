# ================================================================================
# TeamsOneDriveManagement.ps1
# Microsoft Teams・OneDrive統合管理スクリプト（実データ版）
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force

function Get-TeamsReport {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Weekly"
    )
    
    return Invoke-SafeOperation -OperationName "Microsoft Teamsレポート" -Operation {
        Write-Log "Microsoft Teamsレポートを開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("Microsoft.Graph.Authentication", "Microsoft.Graph.Teams")
        
        # チーム一覧取得
        $teams = Get-MgTeam -All
        $teamsReport = @()
        
        foreach ($team in $teams) {
            try {
                # チームメンバー取得
                $members = Get-MgTeamMember -TeamId $team.Id -All
                $owners = $members | Where-Object { $_.Roles -contains "owner" }
                $regularMembers = $members | Where-Object { $_.Roles -notcontains "owner" }
                
                # チャネル取得
                $channels = Get-MgTeamChannel -TeamId $team.Id -All
                
                # ゲストユーザー検出
                $guestMembers = @()
                foreach ($member in $members) {
                    try {
                        $userDetails = Get-MgUser -UserId $member.UserId -Property UserType,UserPrincipalName -ErrorAction SilentlyContinue
                        if ($userDetails.UserType -eq "Guest") {
                            $guestMembers += $userDetails
                        }
                    }
                    catch {
                        Write-Log "ユーザー詳細取得エラー: $($member.UserId)" -Level "Warning"
                    }
                }
                
                # アプリ使用状況
                $installedApps = Get-MgTeamInstalledApp -TeamId $team.Id -All -ErrorAction SilentlyContinue
                
                $teamsReport += [PSCustomObject]@{
                    TeamId = $team.Id
                    DisplayName = $team.DisplayName
                    Description = $team.Description
                    Visibility = $team.Visibility
                    IsArchived = $team.IsArchived
                    WebUrl = $team.WebUrl
                    MemberCount = $members.Count
                    OwnerCount = $owners.Count
                    RegularMemberCount = $regularMembers.Count
                    GuestMemberCount = $guestMembers.Count
                    HasGuestMembers = $guestMembers.Count -gt 0
                    GuestMembers = ($guestMembers.UserPrincipalName -join "; ")
                    ChannelCount = $channels.Count
                    PrivateChannelCount = ($channels | Where-Object { $_.MembershipType -eq "private" }).Count
                    InstalledAppCount = $installedApps.Count
                    CreatedDateTime = $team.CreatedDateTime
                    SecurityRisk = if ($guestMembers.Count -gt 0 -and $team.Visibility -eq "Public") { "高" }
                                  elseif ($guestMembers.Count -gt 0) { "中" }
                                  elseif ($team.Visibility -eq "Public") { "低" }
                                  else { "最小" }
                }
            }
            catch {
                Write-Log "Teams情報取得エラー: $($team.DisplayName) - $($_.Exception.Message)" -Level "Warning"
                
                $teamsReport += [PSCustomObject]@{
                    TeamId = $team.Id
                    DisplayName = $team.DisplayName
                    Description = $team.Description
                    Visibility = $team.Visibility
                    IsArchived = $team.IsArchived
                    WebUrl = $team.WebUrl
                    MemberCount = "取得エラー"
                    OwnerCount = "取得エラー"
                    RegularMemberCount = "取得エラー"
                    GuestMemberCount = "取得エラー"
                    HasGuestMembers = "取得エラー"
                    GuestMembers = "取得エラー"
                    ChannelCount = "取得エラー"
                    PrivateChannelCount = "取得エラー"
                    InstalledAppCount = "取得エラー"
                    CreatedDateTime = $team.CreatedDateTime
                    SecurityRisk = "不明"
                }
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Weekly") "TeamsReport_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $teamsReport -FilePath $outputFile
        
        # 高リスクチーム抽出
        $highRiskTeams = $teamsReport | Where-Object { $_.SecurityRisk -in @("高", "中") }
        if ($highRiskTeams.Count -gt 0) {
            $highRiskOutputFile = Join-Path (New-ReportDirectory -ReportType "Weekly") "TeamsHighRisk_$(Get-Date -Format 'yyyyMMdd').csv"
            Export-DataToCSV -Data $highRiskTeams -FilePath $highRiskOutputFile
        }
        
        Write-AuditLog -Action "Teamsレポート" -Target "Microsoft Teams" -Result "成功" -Details "$($teamsReport.Count)件中$($highRiskTeams.Count)件が高リスク"
        
        return @{
            AllTeams = $teamsReport
            HighRiskTeams = $highRiskTeams
        }
    }
}

function Get-OneDriveReport {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Weekly"
    )
    
    return Invoke-SafeOperation -OperationName "OneDriveレポート" -Operation {
        Write-Log "OneDriveレポートを開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("Microsoft.Graph.Authentication", "Microsoft.Graph.Sites", "Microsoft.Graph.Users")
        
        # ユーザー一覧取得（OneDriveを持つユーザーのみ）
        $users = Get-MgUser -All -Property UserPrincipalName,DisplayName,AccountEnabled,Department,JobTitle,AssignedLicenses
        $oneDriveReport = @()
        
        foreach ($user in $users) {
            if (-not $user.AccountEnabled) { continue }
            
            # OneDriveライセンス確認
            $hasOneDriveLicense = $false
            foreach ($license in $user.AssignedLicenses) {
                $skuDetails = Get-MgSubscribedSku -SubscribedSkuId $license.SkuId -ErrorAction SilentlyContinue
                if ($skuDetails.SkuPartNumber -match "ONEDRIVE|SPE_|ENTERPRISEPACK") {
                    $hasOneDriveLicense = $true
                    break
                }
            }
            
            if (-not $hasOneDriveLicense) { continue }
            
            try {
                # OneDriveサイト取得
                $oneDriveSite = Get-MgUserDrive -UserId $user.Id -ErrorAction SilentlyContinue
                
                if ($oneDriveSite) {
                    # 使用容量計算
                    $usedBytes = $oneDriveSite.Quota.Used
                    $totalBytes = $oneDriveSite.Quota.Total
                    $usedGB = [math]::Round($usedBytes / 1GB, 2)
                    $totalGB = [math]::Round($totalBytes / 1GB, 2)
                    $usagePercent = if ($totalBytes -gt 0) { 
                        [math]::Round(($usedBytes / $totalBytes) * 100, 2) 
                    } else { 0 }
                    
                    # 外部共有設定確認
                    $sharedItems = Get-MgDriveSharedWithMe -DriveId $oneDriveSite.Id -ErrorAction SilentlyContinue
                    $hasExternalSharing = $sharedItems.Count -gt 0
                    
                    # リスクレベル判定
                    $riskLevel = if ($usagePercent -ge 90) { "緊急" }
                               elseif ($usagePercent -ge 80) { "警告" }
                               elseif ($hasExternalSharing) { "注意" }
                               else { "正常" }
                    
                    # 最終アクセス時間
                    $lastActivityDate = $null
                    try {
                        $activities = Get-MgReportOneDriveActivityUserDetail -Period "D7" -ErrorAction SilentlyContinue
                        $userActivity = $activities | Where-Object { $_.UserPrincipalName -eq $user.UserPrincipalName } | Select-Object -First 1
                        if ($userActivity) {
                            $lastActivityDate = $userActivity.LastActivityDate
                        }
                    }
                    catch {
                        Write-Log "OneDriveアクティビティ取得エラー: $($user.UserPrincipalName)" -Level "Warning"
                    }
                    
                    $oneDriveReport += [PSCustomObject]@{
                        UserPrincipalName = $user.UserPrincipalName
                        DisplayName = $user.DisplayName
                        Department = $user.Department
                        JobTitle = $user.JobTitle
                        DriveId = $oneDriveSite.Id
                        DriveType = $oneDriveSite.DriveType
                        UsedGB = $usedGB
                        TotalGB = $totalGB
                        UsagePercent = $usagePercent
                        RemainingGB = $totalGB - $usedGB
                        FileCount = $oneDriveSite.Quota.FileCount
                        HasExternalSharing = $hasExternalSharing
                        SharedItemCount = $sharedItems.Count
                        LastActivityDate = $lastActivityDate
                        IsInactive = if ($lastActivityDate) { 
                            ((Get-Date) - [DateTime]$lastActivityDate).Days -gt 30 
                        } else { $true }
                        RiskLevel = $riskLevel
                        CreatedDateTime = $oneDriveSite.CreatedDateTime
                        LastModifiedDateTime = $oneDriveSite.LastModifiedDateTime
                        WebUrl = $oneDriveSite.WebUrl
                    }
                }
            }
            catch {
                Write-Log "OneDrive情報取得エラー: $($user.UserPrincipalName) - $($_.Exception.Message)" -Level "Warning"
                
                $oneDriveReport += [PSCustomObject]@{
                    UserPrincipalName = $user.UserPrincipalName
                    DisplayName = $user.DisplayName
                    Department = $user.Department
                    JobTitle = $user.JobTitle
                    DriveId = "取得エラー"
                    DriveType = "取得エラー"
                    UsedGB = "取得エラー"
                    TotalGB = "取得エラー"
                    UsagePercent = "取得エラー"
                    RemainingGB = "取得エラー"
                    FileCount = "取得エラー"
                    HasExternalSharing = "取得エラー"
                    SharedItemCount = "取得エラー"
                    LastActivityDate = "取得エラー"
                    IsInactive = "取得エラー"
                    RiskLevel = "不明"
                    CreatedDateTime = "取得エラー"
                    LastModifiedDateTime = "取得エラー"
                    WebUrl = "取得エラー"
                }
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Weekly") "OneDriveReport_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $oneDriveReport -FilePath $outputFile
        
        # 高使用率OneDrive抽出
        $highUsageOneDrives = $oneDriveReport | Where-Object { 
            $_.RiskLevel -in @("警告", "緊急") -or 
            $_.HasExternalSharing -eq $true -or
            $_.IsInactive -eq $true
        }
        
        if ($highUsageOneDrives.Count -gt 0) {
            $highUsageOutputFile = Join-Path (New-ReportDirectory -ReportType "Weekly") "OneDriveHighUsage_$(Get-Date -Format 'yyyyMMdd').csv"
            Export-DataToCSV -Data $highUsageOneDrives -FilePath $highUsageOutputFile
        }
        
        Write-AuditLog -Action "OneDriveレポート" -Target "OneDrive for Business" -Result "成功" -Details "$($oneDriveReport.Count)件中$($highUsageOneDrives.Count)件が要注意"
        
        return @{
            AllOneDrives = $oneDriveReport
            HighUsageOneDrives = $highUsageOneDrives
        }
    }
}

function Get-SharePointSitesReport {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -OperationName "SharePointサイトレポート" -Operation {
        Write-Log "SharePointサイトレポートを開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("Microsoft.Graph.Authentication", "Microsoft.Graph.Sites")
        
        # SharePointサイト一覧取得
        $sites = Get-MgSite -All -Property Id,Name,DisplayName,CreatedDateTime,LastModifiedDateTime,WebUrl,SiteCollection
        $sitesReport = @()
        
        foreach ($site in $sites) {
            try {
                # サイトドライブ取得
                $drives = Get-MgSiteDrive -SiteId $site.Id -All -ErrorAction SilentlyContinue
                
                $totalUsedBytes = 0
                $totalItemCount = 0
                
                foreach ($drive in $drives) {
                    if ($drive.Quota) {
                        $totalUsedBytes += $drive.Quota.Used
                        $totalItemCount += $drive.Quota.FileCount
                    }
                }
                
                $totalUsedGB = [math]::Round($totalUsedBytes / 1GB, 2)
                
                # 外部共有確認
                $permissions = Get-MgSitePermission -SiteId $site.Id -ErrorAction SilentlyContinue
                $externalPermissions = $permissions | Where-Object { 
                    $_.GrantedToIdentities.User.Email -notlike "*@$((Get-MgDomain | Where-Object {$_.IsDefault}).Id)*"
                }
                
                $sitesReport += [PSCustomObject]@{
                    SiteId = $site.Id
                    Name = $site.Name
                    DisplayName = $site.DisplayName
                    WebUrl = $site.WebUrl
                    CreatedDateTime = $site.CreatedDateTime
                    LastModifiedDateTime = $site.LastModifiedDateTime
                    DriveCount = $drives.Count
                    TotalUsedGB = $totalUsedGB
                    TotalItemCount = $totalItemCount
                    HasExternalSharing = $externalPermissions.Count -gt 0
                    ExternalPermissionCount = $externalPermissions.Count
                    IsTeamSite = $site.WebUrl -like "*/teams/*"
                    SecurityRisk = if ($externalPermissions.Count -gt 5) { "高" }
                                 elseif ($externalPermissions.Count -gt 0) { "中" }
                                 else { "低" }
                }
            }
            catch {
                Write-Log "SharePointサイト情報取得エラー: $($site.DisplayName) - $($_.Exception.Message)" -Level "Warning"
                
                $sitesReport += [PSCustomObject]@{
                    SiteId = $site.Id
                    Name = $site.Name
                    DisplayName = $site.DisplayName
                    WebUrl = $site.WebUrl
                    CreatedDateTime = $site.CreatedDateTime
                    LastModifiedDateTime = $site.LastModifiedDateTime
                    DriveCount = "取得エラー"
                    TotalUsedGB = "取得エラー"
                    TotalItemCount = "取得エラー"
                    HasExternalSharing = "取得エラー"
                    ExternalPermissionCount = "取得エラー"
                    IsTeamSite = $site.WebUrl -like "*/teams/*"
                    SecurityRisk = "不明"
                }
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "SharePointSitesReport_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $sitesReport -FilePath $outputFile
        
        # 高リスクサイト抽出
        $highRiskSites = $sitesReport | Where-Object { $_.SecurityRisk -eq "高" }
        if ($highRiskSites.Count -gt 0) {
            $highRiskOutputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "SharePointHighRiskSites_$(Get-Date -Format 'yyyyMMdd').csv"
            Export-DataToCSV -Data $highRiskSites -FilePath $highRiskOutputFile
        }
        
        Write-AuditLog -Action "SharePointサイトレポート" -Target "SharePoint Online" -Result "成功" -Details "$($sitesReport.Count)件中$($highRiskSites.Count)件が高リスク"
        
        return @{
            AllSites = $sitesReport
            HighRiskSites = $highRiskSites
        }
    }
}

function Get-TeamsActivityReport {
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 30,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -OperationName "Teamsアクティビティレポート" -Operation {
        Write-Log "Teamsアクティビティレポートを開始します（過去 $DaysBack 日間）" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("Microsoft.Graph.Authentication", "Microsoft.Graph.Reports")
        
        try {
            # Teams使用状況レポート取得
            $period = if ($DaysBack -le 7) { "D7" } 
                     elseif ($DaysBack -le 30) { "D30" } 
                     elseif ($DaysBack -le 90) { "D90" } 
                     else { "D180" }
            
            $teamsUserActivity = Get-MgReportTeamsUserActivityUserDetail -Period $period
            $activityReport = @()
            
            foreach ($activity in $teamsUserActivity) {
                $activityReport += [PSCustomObject]@{
                    UserPrincipalName = $activity.UserPrincipalName
                    DisplayName = $activity.DisplayName
                    LastActivityDate = $activity.LastActivityDate
                    TeamChatMessageCount = $activity.TeamChatMessageCount
                    PrivateChatMessageCount = $activity.PrivateChatMessageCount
                    CallCount = $activity.CallCount
                    MeetingCount = $activity.MeetingCount
                    MeetingsOrganizedCount = $activity.MeetingsOrganizedCount
                    MeetingsAttendedCount = $activity.MeetingsAttendedCount
                    HasOtherAction = $activity.HasOtherAction
                    IsActive = ($activity.TeamChatMessageCount -gt 0 -or 
                              $activity.PrivateChatMessageCount -gt 0 -or 
                              $activity.CallCount -gt 0 -or 
                              $activity.MeetingCount -gt 0)
                    IsInactive = if ($activity.LastActivityDate) {
                        ((Get-Date) - [DateTime]$activity.LastActivityDate).Days -gt 30
                    } else { $true }
                    TotalInteractions = $activity.TeamChatMessageCount + 
                                      $activity.PrivateChatMessageCount + 
                                      $activity.CallCount + 
                                      $activity.MeetingCount
                    ActivityLevel = if (($activity.TeamChatMessageCount + $activity.PrivateChatMessageCount + $activity.CallCount + $activity.MeetingCount) -gt 100) { "高" }
                                  elseif (($activity.TeamChatMessageCount + $activity.PrivateChatMessageCount + $activity.CallCount + $activity.MeetingCount) -gt 10) { "中" }
                                  elseif (($activity.TeamChatMessageCount + $activity.PrivateChatMessageCount + $activity.CallCount + $activity.MeetingCount) -gt 0) { "低" }
                                  else { "非活動" }
                }
            }
            
            $outputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "TeamsActivityReport_$(Get-Date -Format 'yyyyMMdd').csv"
            Export-DataToCSV -Data $activityReport -FilePath $outputFile
            
            # 非活動ユーザー抽出
            $inactiveUsers = $activityReport | Where-Object { $_.IsInactive -eq $true }
            if ($inactiveUsers.Count -gt 0) {
                $inactiveOutputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "TeamsInactiveUsers_$(Get-Date -Format 'yyyyMMdd').csv"
                Export-DataToCSV -Data $inactiveUsers -FilePath $inactiveOutputFile
            }
            
            Write-AuditLog -Action "Teamsアクティビティレポート" -Target "Microsoft Teams" -Result "成功" -Details "$($activityReport.Count)件中$($inactiveUsers.Count)件が非活動"
            
            return @{
                AllActivity = $activityReport
                InactiveUsers = $inactiveUsers
            }
        }
        catch {
            Write-Log "Teamsアクティビティレポート取得エラー: $($_.Exception.Message)" -Level "Error"
            return @{
                AllActivity = @()
                InactiveUsers = @()
            }
        }
    }
}

# スクリプト直接実行時の処理
if ($MyInvocation.InvocationName -ne '.') {
    $config = Initialize-ManagementTools
    
    Write-Log "Microsoft Teams・OneDrive統合管理スクリプトを実行します" -Level "Info"
    
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
        Write-Log "Teamsレポートを実行中..." -Level "Info"
        Get-TeamsReport
        
        Write-Log "OneDriveレポートを実行中..." -Level "Info"
        Get-OneDriveReport
        
        Write-Log "SharePointサイトレポートを実行中..." -Level "Info"
        Get-SharePointSitesReport
        
        Write-Log "Teamsアクティビティレポートを実行中..." -Level "Info"
        Get-TeamsActivityReport
        
        Write-Log "Microsoft Teams・OneDrive統合管理スクリプトが正常に完了しました" -Level "Info"
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        Send-ErrorNotification -ErrorDetails $errorDetails
        Write-Log "Teams・OneDrive管理エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
    finally {
        Disconnect-AllServices
    }
}