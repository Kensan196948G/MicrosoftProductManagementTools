# ================================================================================
# MailboxManagement.ps1
# Exchange Online メールボックス管理スクリプト
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force

function Get-EXOMailboxCapacityReport {
    param(
        [Parameter(Mandatory = $false)]
        [int]$WarningThresholdPercent = 80,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Daily"
    )
    
    return Invoke-SafeOperation -OperationName "EXOメールボックス容量監視" -Operation {
        Write-Log "Exchange Onlineメールボックス容量監視を開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ExchangeOnlineManagement")
        
        $mailboxes = Get-EXOMailbox -PropertySets StatisticsSeed, Quota
        $capacityReport = @()
        
        foreach ($mailbox in $mailboxes) {
            try {
                $stats = Get-EXOMailboxStatistics -Identity $mailbox.UserPrincipalName -PropertySets All
                
                if ($stats.TotalItemSize -and $mailbox.ProhibitSendQuota) {
                    $usedBytes = [double]($stats.TotalItemSize -replace '.*\(([0-9,]+) bytes\)', '$1' -replace ',', '')
                    $quotaBytes = [double]($mailbox.ProhibitSendQuota -replace '.*\(([0-9,]+) bytes\)', '$1' -replace ',', '')
                    $usagePercent = [math]::Round(($usedBytes / $quotaBytes) * 100, 2)
                    
                    $capacityReport += [PSCustomObject]@{
                        UserPrincipalName = $mailbox.UserPrincipalName
                        DisplayName = $mailbox.DisplayName
                        MailboxType = $mailbox.RecipientTypeDetails
                        TotalItemSize = $stats.TotalItemSize
                        ItemCount = $stats.ItemCount
                        ProhibitSendQuota = $mailbox.ProhibitSendQuota
                        UsagePercent = $usagePercent
                        Status = if ($usagePercent -ge $WarningThresholdPercent) { "警告" } else { "正常" }
                        LastLogonTime = $stats.LastLogonTime
                        LastUserActionTime = $stats.LastUserActionTime
                    }
                }
            }
            catch {
                Write-Log "メールボックス統計取得エラー: $($mailbox.UserPrincipalName) - $($_.Exception.Message)" -Level "Warning"
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "EXOMailboxCapacity_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $capacityReport -FilePath $outputFile
        
        $warningCount = ($capacityReport | Where-Object { $_.Status -eq "警告" }).Count
        Write-AuditLog -Action "メールボックス容量監視" -Target "全メールボックス" -Result "成功" -Details "$($capacityReport.Count)件中$warningCount件が警告レベル"
        
        return $capacityReport
    }
}

function Get-EXOAttachmentAnalysis {
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 7,
        
        [Parameter(Mandatory = $false)]
        [int]$SizeThresholdMB = 10,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Daily"
    )
    
    return Invoke-SafeOperation -OperationName "EXO添付ファイル分析" -Operation {
        Write-Log "Exchange Online添付ファイル分析を開始します（過去 $DaysBack 日間）" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ExchangeOnlineManagement")
        
        $startDate = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-dd")
        $endDate = (Get-Date).ToString("yyyy-MM-dd")
        
        $messageTrace = Get-MessageTrace -StartDate $startDate -EndDate $endDate -PageSize 5000
        $attachmentReport = @()
        
        foreach ($message in $messageTrace) {
            try {
                $messageDetails = Get-MessageTraceDetail -MessageTraceId $message.MessageTraceId -RecipientAddress $message.RecipientAddress
                
                foreach ($detail in $messageDetails) {
                    if ($detail.Event -eq "SEND" -and $detail.Data -like "*attachment*") {
                        $attachmentReport += [PSCustomObject]@{
                            Received = $message.Received
                            SenderAddress = $message.SenderAddress
                            RecipientAddress = $message.RecipientAddress
                            Subject = $message.Subject
                            Status = $message.Status
                            Size = $message.Size
                            MessageId = $message.MessageId
                            AttachmentInfo = $detail.Data
                        }
                    }
                }
            }
            catch {
                Write-Log "メッセージ詳細取得エラー: $($message.MessageId)" -Level "Warning"
            }
        }
        
        $largeAttachments = $attachmentReport | Where-Object { $_.Size -gt ($SizeThresholdMB * 1MB) }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "EXOAttachmentAnalysis_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $attachmentReport -FilePath $outputFile
        
        $largeOutputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "EXOLargeAttachments_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $largeAttachments -FilePath $largeOutputFile
        
        Write-AuditLog -Action "添付ファイル分析" -Target "メールメッセージ" -Result "成功" -Details "$($attachmentReport.Count)件中$($largeAttachments.Count)件が大容量"
        
        return @{
            AllAttachments = $attachmentReport
            LargeAttachments = $largeAttachments
        }
    }
}

function Get-EXOForwardingRules {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Weekly"
    )
    
    return Invoke-SafeOperation -OperationName "EXO転送ルール確認" -Operation {
        Write-Log "Exchange Online転送ルールの確認を開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ExchangeOnlineManagement")
        
        $forwardingReport = @()
        $mailboxes = Get-EXOMailbox -PropertySets Forwarding
        
        foreach ($mailbox in $mailboxes) {
            if ($mailbox.ForwardingAddress -or $mailbox.ForwardingSmtpAddress) {
                $forwardingReport += [PSCustomObject]@{
                    UserPrincipalName = $mailbox.UserPrincipalName
                    DisplayName = $mailbox.DisplayName
                    ForwardingAddress = $mailbox.ForwardingAddress
                    ForwardingSmtpAddress = $mailbox.ForwardingSmtpAddress
                    DeliverToMailboxAndForward = $mailbox.DeliverToMailboxAndForward
                    Type = "メールボックス転送"
                }
            }
            
            try {
                $inboxRules = Get-EXOInboxRule -Mailbox $mailbox.UserPrincipalName | 
                Where-Object { $_.ForwardTo -or $_.ForwardAsAttachmentTo -or $_.RedirectTo }
                
                foreach ($rule in $inboxRules) {
                    $forwardingReport += [PSCustomObject]@{
                        UserPrincipalName = $mailbox.UserPrincipalName
                        DisplayName = $mailbox.DisplayName
                        RuleName = $rule.Name
                        ForwardTo = $rule.ForwardTo -join "; "
                        ForwardAsAttachmentTo = $rule.ForwardAsAttachmentTo -join "; "
                        RedirectTo = $rule.RedirectTo -join "; "
                        Enabled = $rule.Enabled
                        Type = "受信トレイルール"
                    }
                }
            }
            catch {
                Write-Log "受信トレイルール取得エラー: $($mailbox.UserPrincipalName)" -Level "Warning"
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Weekly") "EXOForwardingRules_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $forwardingReport -FilePath $outputFile
        
        Write-AuditLog -Action "転送ルール確認" -Target "全メールボックス" -Result "成功" -Details "$($forwardingReport.Count)件の転送設定を検出"
        
        return $forwardingReport
    }
}

function Get-EXODistributionGroupReport {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -OperationName "EXO配布グループレポート" -Operation {
        Write-Log "Exchange Online配布グループレポートを開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ExchangeOnlineManagement")
        
        $distributionGroups = Get-DistributionGroup -ResultSize Unlimited
        $groupReport = @()
        
        foreach ($group in $distributionGroups) {
            try {
                $members = Get-DistributionGroupMember -Identity $group.Identity -ResultSize Unlimited
                
                $groupReport += [PSCustomObject]@{
                    Name = $group.Name
                    DisplayName = $group.DisplayName
                    PrimarySmtpAddress = $group.PrimarySmtpAddress
                    GroupType = $group.GroupType
                    MemberCount = $members.Count
                    ManagedBy = ($group.ManagedBy -join "; ")
                    RequireSenderAuthenticationEnabled = $group.RequireSenderAuthenticationEnabled
                    HiddenFromAddressListsEnabled = $group.HiddenFromAddressListsEnabled
                    WhenCreated = $group.WhenCreated
                    WhenChanged = $group.WhenChanged
                }
            }
            catch {
                Write-Log "配布グループメンバー取得エラー: $($group.Name)" -Level "Warning"
                
                $groupReport += [PSCustomObject]@{
                    Name = $group.Name
                    DisplayName = $group.DisplayName
                    PrimarySmtpAddress = $group.PrimarySmtpAddress
                    GroupType = $group.GroupType
                    MemberCount = "取得エラー"
                    ManagedBy = ($group.ManagedBy -join "; ")
                    RequireSenderAuthenticationEnabled = $group.RequireSenderAuthenticationEnabled
                    HiddenFromAddressListsEnabled = $group.HiddenFromAddressListsEnabled
                    WhenCreated = $group.WhenCreated
                    WhenChanged = $group.WhenChanged
                }
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "EXODistributionGroups_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $groupReport -FilePath $outputFile
        
        Write-AuditLog -Action "配布グループレポート" -Target "全配布グループ" -Result "成功" -Details "$($groupReport.Count)件の配布グループを分析"
        
        return $groupReport
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $config = Initialize-ManagementTools
    
    Write-Log "Exchange Onlineメールボックス管理スクリプトを実行します" -Level "Info"
    
    try {
        if ($config) {
            Connect-ExchangeOnlineService -Organization $config.ExchangeOnline.Organization -AppId $config.ExchangeOnline.AppId -CertificateThumbprint $config.ExchangeOnline.CertificateThumbprint
        }
        else {
            Write-Log "設定ファイルが見つからないため、手動接続が必要です" -Level "Warning"
        }
        
        Get-EXOMailboxCapacityReport
        Get-EXOAttachmentAnalysis
        Get-EXOForwardingRules
        Get-EXODistributionGroupReport
        
        Write-Log "Exchange Onlineメールボックス管理スクリプトが正常に完了しました" -Level "Info"
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