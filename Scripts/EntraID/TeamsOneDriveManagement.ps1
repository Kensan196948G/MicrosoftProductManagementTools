# ================================================================================
# TeamsOneDriveManagement.ps1
# Teams・OneDrive管理スクリプト（Microsoft Graph経由）
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force

function Get-TeamsReport {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -OperationName "Teamsレポート" -Operation {
        Write-Log "Microsoft Teamsレポートを開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("Microsoft.Graph.Authentication", "Microsoft.Graph.Teams", "Microsoft.Graph.Groups")
        
        $teams = Get-MgTeam -All
        $teamsReport = @()
        
        foreach ($team in $teams) {
            try {
                $teamDetails = Get-MgTeam -TeamId $team.Id
                $members = Get-MgTeamMember -TeamId $team.Id -All
                $channels = Get-MgTeamChannel -TeamId $team.Id -All
                $owners = $members | Where-Object { $_.Roles -contains "owner" }
                
                $group = Get-MgGroup -GroupId $team.Id -Property CreatedDateTime,Mail,Visibility
                
                $teamsReport += [PSCustomObject]@{
                    TeamName = $teamDetails.DisplayName
                    TeamId = $team.Id
                    Description = $teamDetails.Description
                    Visibility = $teamDetails.Visibility
                    IsArchived = $teamDetails.IsArchived
                    EmailAddress = $group.Mail
                    CreatedDateTime = $group.CreatedDateTime
                    MemberCount = $members.Count
                    OwnerCount = $owners.Count
                    ChannelCount = $channels.Count
                    HasOwners = $owners.Count -gt 0
                    AllowGuestCreateUpdateChannels = $teamDetails.GuestSettings.AllowCreateUpdateChannels
                    AllowGuestDeleteChannels = $teamDetails.GuestSettings.AllowDeleteChannels
                    AllowCreateUpdateChannels = $teamDetails.MemberSettings.AllowCreateUpdateChannels
                    AllowDeleteChannels = $teamDetails.MemberSettings.AllowDeleteChannels
                    AllowAddRemoveApps = $teamDetails.MemberSettings.AllowAddRemoveApps
                    DaysSinceCreated = if ($group.CreatedDateTime) { ((Get-Date) - $group.CreatedDateTime).Days } else { "不明" }
                    RiskLevel = if ($owners.Count -eq 0) { "高" } 
                               elseif ($teamDetails.GuestSettings.AllowCreateUpdateChannels -or $teamDetails.GuestSettings.AllowDeleteChannels) { "中" } 
                               else { "低" }
                }
            }
            catch {
                Write-Log "Teams詳細取得エラー: $($team.Id) - $($_.Exception.Message)" -Level "Warning"
                
                $teamsReport += [PSCustomObject]@{
                    TeamName = "取得エラー"
                    TeamId = $team.Id
                    Description = "取得エラー"
                    Visibility = "不明"
                    IsArchived = "不明"
                    EmailAddress = "不明"
                    CreatedDateTime = "不明"
                    MemberCount = "取得エラー"
                    OwnerCount = "取得エラー"
                    ChannelCount = "取得エラー"
                    HasOwners = "不明"
                    AllowGuestCreateUpdateChannels = "不明"
                    AllowGuestDeleteChannels = "不明"
                    AllowCreateUpdateChannels = "不明"
                    AllowDeleteChannels = "不明"
                    AllowAddRemoveApps = "不明"
                    DaysSinceCreated = "不明"
                    RiskLevel = "不明"
                }
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "TeamsReport_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $teamsReport -FilePath $outputFile
        
        $orphanedTeams = ($teamsReport | Where-Object { $_.OwnerCount -eq 0 -and $_.HasOwners -eq $false }).Count
        Write-AuditLog -Action "Teamsレポート" -Target "全Teamsチーム" -Result "成功" -Details "$($teamsReport.Count)件中$orphanedTeams件がオーナー不在"
        
        return $teamsReport
    }
}

function Get-OneDriveUsageReport {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -OperationName "OneDrive使用状況レポート" -Operation {
        Write-Log "OneDrive使用状況レポートを開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users", "Microsoft.Graph.Sites")
        
        try {
            $oneDriveUsage = Get-MgReportOneDriveUsageAccountDetail -Period "D30" -OutFile "$env:TEMP\onedrive_usage.csv"
            $usageData = Import-Csv "$env:TEMP\onedrive_usage.csv"
            
            $oneDriveReport = foreach ($usage in $usageData) {
                [PSCustomObject]@{
                    UserPrincipalName = $usage.'User Principal Name'
                    DisplayName = $usage.'Display Name'
                    IsDeleted = $usage.'Is Deleted'
                    LastActivityDate = $usage.'Last Activity Date'
                    FileCount = [int]$usage.'File Count'
                    ActiveFileCount = [int]$usage.'Active File Count'
                    StorageUsedBytes = [long]$usage.'Storage Used (Byte)'
                    StorageAllocatedBytes = [long]$usage.'Storage Allocated (Byte)'
                    StorageUsedGB = [math]::Round([long]$usage.'Storage Used (Byte)' / 1GB, 2)
                    StorageAllocatedGB = [math]::Round([long]$usage.'Storage Allocated (Byte)' / 1GB, 2)
                    UsagePercent = if ([long]$usage.'Storage Allocated (Byte)' -gt 0) {
                        [math]::Round(([long]$usage.'Storage Used (Byte)' / [long]$usage.'Storage Allocated (Byte)') * 100, 2)
                    } else { 0 }
                    ReportRefreshDate = $usage.'Report Refresh Date'
                    DaysSinceLastActivity = if ($usage.'Last Activity Date' -and $usage.'Last Activity Date' -ne '') {
                        ((Get-Date) - [DateTime]$usage.'Last Activity Date').Days
                    } else { "不明" }
                }
            }
            
            Remove-Item "$env:TEMP\onedrive_usage.csv" -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Log "OneDriveレポート取得エラー: $($_.Exception.Message)" -Level "Warning"
            $oneDriveReport = @()
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "OneDriveUsageReport_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $oneDriveReport -FilePath $outputFile
        
        $highUsageUsers = ($oneDriveReport | Where-Object { $_.UsagePercent -gt 80 }).Count
        $inactiveUsers = ($oneDriveReport | Where-Object { $_.DaysSinceLastActivity -gt 90 -and $_.DaysSinceLastActivity -ne "不明" }).Count
        
        Write-AuditLog -Action "OneDrive使用状況レポート" -Target "全OneDriveユーザー" -Result "成功" -Details "$($oneDriveReport.Count)件、高使用率:$highUsageUsers件、非アクティブ:$inactiveUsers件"
        
        return $oneDriveReport
    }
}

function Get-OneDriveSharingReport {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Weekly"
    )
    
    return Invoke-SafeOperation -OperationName "OneDrive外部共有レポート" -Operation {
        Write-Log "OneDrive外部共有レポートを開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users", "Microsoft.Graph.Sites")
        
        $users = Get-MgUser -All -Property UserPrincipalName,DisplayName
        $sharingReport = @()
        
        foreach ($user in $users) {
            try {
                $userSite = Get-MgUserDrive -UserId $user.Id -ErrorAction SilentlyContinue
                
                if ($userSite) {
                    $sharedItems = Get-MgDriveSharedWithMe -DriveId $userSite.Id -ErrorAction SilentlyContinue
                    
                    if ($sharedItems) {
                        foreach ($item in $sharedItems) {
                            $sharingReport += [PSCustomObject]@{
                                UserPrincipalName = $user.UserPrincipalName
                                DisplayName = $user.DisplayName
                                ItemName = $item.Name
                                ItemType = $item.File.MimeType
                                SharedDateTime = $item.CreatedDateTime
                                LastModified = $item.LastModifiedDateTime
                                ItemId = $item.Id
                                WebUrl = $item.WebUrl
                                Size = $item.Size
                            }
                        }
                    }
                }
            }
            catch {
                Write-Log "OneDrive共有情報取得エラー: $($user.UserPrincipalName) - $($_.Exception.Message)" -Level "Warning"
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Weekly") "OneDriveSharingReport_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $sharingReport -FilePath $outputFile
        
        $externalShares = ($sharingReport | Where-Object { $_.UserPrincipalName -notlike "*@$($config.Domain)" }).Count
        Write-AuditLog -Action "OneDrive外部共有レポート" -Target "OneDrive共有アイテム" -Result "成功" -Details "$($sharingReport.Count)件の共有、外部共有:$externalShares件"
        
        return $sharingReport
    }
}

function Get-M365LicenseUtilizationReport {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -OperationName "M365ライセンス利用率レポート" -Operation {
        Write-Log "Microsoft 365ライセンス利用率レポートを開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("Microsoft.Graph.Authentication", "Microsoft.Graph.Reports")
        
        try {
            # Office 365アクティブユーザー詳細を取得
            Get-MgReportOffice365ActiveUserDetail -Period "D30" -OutFile "$env:TEMP\active_users.csv"
            $activeUsersData = Import-Csv "$env:TEMP\active_users.csv"
            
            # ライセンス利用率レポートを作成
            $utilizationReport = foreach ($user in $activeUsersData) {
                [PSCustomObject]@{
                    UserPrincipalName = $user.'User Principal Name'
                    DisplayName = $user.'Display Name'
                    IsDeleted = $user.'Is Deleted'
                    HasExchangeLicense = $user.'Has Exchange License'
                    HasOneDriveLicense = $user.'Has OneDrive License'
                    HasSharePointLicense = $user.'Has SharePoint License'
                    HasSkypeForBusinessLicense = $user.'Has Skype For Business License'
                    HasYammerLicense = $user.'Has Yammer License'
                    HasTeamsLicense = $user.'Has Teams License'
                    ExchangeLastActivityDate = $user.'Exchange Last Activity Date'
                    OneDriveLastActivityDate = $user.'OneDrive Last Activity Date'
                    SharePointLastActivityDate = $user.'SharePoint Last Activity Date'
                    SkypeForBusinessLastActivityDate = $user.'Skype For Business Last Activity Date'
                    YammerLastActivityDate = $user.'Yammer Last Activity Date'
                    TeamsLastActivityDate = $user.'Teams Last Activity Date'
                    ExchangeActive = if ($user.'Exchange Last Activity Date' -and $user.'Exchange Last Activity Date' -ne '') { 
                        ((Get-Date) - [DateTime]$user.'Exchange Last Activity Date').Days -le 30 
                    } else { $false }
                    OneDriveActive = if ($user.'OneDrive Last Activity Date' -and $user.'OneDrive Last Activity Date' -ne '') { 
                        ((Get-Date) - [DateTime]$user.'OneDrive Last Activity Date').Days -le 30 
                    } else { $false }
                    SharePointActive = if ($user.'SharePoint Last Activity Date' -and $user.'SharePoint Last Activity Date' -ne '') { 
                        ((Get-Date) - [DateTime]$user.'SharePoint Last Activity Date').Days -le 30 
                    } else { $false }
                    TeamsActive = if ($user.'Teams Last Activity Date' -and $user.'Teams Last Activity Date' -ne '') { 
                        ((Get-Date) - [DateTime]$user.'Teams Last Activity Date').Days -le 30 
                    } else { $false }
                    ReportRefreshDate = $user.'Report Refresh Date'
                }
            }
            
            Remove-Item "$env:TEMP\active_users.csv" -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Log "ライセンス利用率レポート取得エラー: $($_.Exception.Message)" -Level "Warning"
            $utilizationReport = @()
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "M365LicenseUtilization_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $utilizationReport -FilePath $outputFile
        
        $inactiveUsers = ($utilizationReport | Where-Object { 
            -not $_.ExchangeActive -and -not $_.OneDriveActive -and -not $_.SharePointActive -and -not $_.TeamsActive 
        }).Count
        
        Write-AuditLog -Action "M365ライセンス利用率レポート" -Target "全M365ユーザー" -Result "成功" -Details "$($utilizationReport.Count)件中$inactiveUsers件が非アクティブ"
        
        return $utilizationReport
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $config = Initialize-ManagementTools
    
    Write-Log "Teams・OneDrive管理スクリプトを実行します" -Level "Info"
    
    try {
        if ($config) {
            Connect-EntraID -TenantId $config.EntraID.TenantId -ClientId $config.EntraID.ClientId -CertificateThumbprint $config.EntraID.CertificateThumbprint
        }
        else {
            Write-Log "設定ファイルが見つからないため、手動接続が必要です" -Level "Warning"
        }
        
        Get-TeamsReport
        Get-OneDriveUsageReport
        Get-OneDriveSharingReport
        Get-M365LicenseUtilizationReport
        
        Write-Log "Teams・OneDrive管理スクリプトが正常に完了しました" -Level "Info"
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        Send-ErrorNotification -ErrorDetails $errorDetails
        throw $_
    }
    finally {
        Disconnect-AllServices
    }
}