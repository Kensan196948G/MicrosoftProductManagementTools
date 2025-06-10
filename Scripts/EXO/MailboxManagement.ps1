# ================================================================================
# MailboxManagement.ps1
# Exchange Online メールボックス管理スクリプト（実データ版）
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force

function Get-ExchangeMailboxReport {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Daily"
    )
    
    return Invoke-SafeOperation -OperationName "Exchange Online メールボックスレポート" -Operation {
        Write-Log "Exchange Online メールボックスレポートを開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ExchangeOnlineManagement")
        
        # メールボックス一覧取得
        $mailboxes = Get-Mailbox -ResultSize Unlimited
        $mailboxReport = @()
        
        foreach ($mailbox in $mailboxes) {
            try {
                # メールボックス統計情報取得
                $stats = Get-MailboxStatistics -Identity $mailbox.Identity -ErrorAction SilentlyContinue
                $permissions = Get-MailboxPermission -Identity $mailbox.Identity -ErrorAction SilentlyContinue
                
                # 容量計算
                $totalItemSizeBytes = 0
                $totalItemSizeMB = 0
                if ($stats.TotalItemSize) {
                    $sizeString = $stats.TotalItemSize.ToString()
                    if ($sizeString -match '\(([0-9,]+) bytes\)') {
                        $totalItemSizeBytes = [long]($matches[1] -replace ',', '')
                        $totalItemSizeMB = [math]::Round($totalItemSizeBytes / 1MB, 2)
                    }
                }
                
                # 禁止送信制限取得
                $prohibitSendQuotaMB = 0
                if ($mailbox.ProhibitSendQuota) {
                    $quotaString = $mailbox.ProhibitSendQuota.ToString()
                    if ($quotaString -match '\(([0-9,]+) bytes\)') {
                        $prohibitSendQuotaBytes = [long]($matches[1] -replace ',', '')
                        $prohibitSendQuotaMB = [math]::Round($prohibitSendQuotaBytes / 1MB, 2)
                    }
                }
                
                # 使用率計算
                $usagePercent = 0
                if ($prohibitSendQuotaMB -gt 0 -and $totalItemSizeMB -gt 0) {
                    $usagePercent = [math]::Round(($totalItemSizeMB / $prohibitSendQuotaMB) * 100, 2)
                }
                
                # リスクレベル判定
                $riskLevel = if ($usagePercent -ge 95) { "緊急" }
                           elseif ($usagePercent -ge 80) { "警告" }
                           elseif ($usagePercent -ge 70) { "注意" }
                           else { "正常" }
                
                # 外部アクセス権限チェック
                $externalPermissions = $permissions | Where-Object { 
                    $_.User -notlike "*@$($mailbox.PrimarySmtpAddress.Split('@')[1])" -and
                    $_.User -ne "NT AUTHORITY\SELF" -and
                    $_.User -ne "SELF"
                }
                
                $mailboxReport += [PSCustomObject]@{
                    DisplayName = $mailbox.DisplayName
                    PrimarySmtpAddress = $mailbox.PrimarySmtpAddress
                    UserPrincipalName = $mailbox.UserPrincipalName
                    RecipientTypeDetails = $mailbox.RecipientTypeDetails
                    Department = $mailbox.Department
                    Office = $mailbox.Office
                    IsArchiveEnabled = $mailbox.ArchiveStatus -eq "Active"
                    TotalItemSizeMB = $totalItemSizeMB
                    ItemCount = $stats.ItemCount
                    DeletedItemSizeMB = if ($stats.TotalDeletedItemSize) { 
                        [math]::Round(($stats.TotalDeletedItemSize.ToString() -replace '[^\d]', '') / 1MB, 2) 
                    } else { 0 }
                    ProhibitSendQuotaMB = $prohibitSendQuotaMB
                    UsagePercent = $usagePercent
                    RiskLevel = $riskLevel
                    LastLogonTime = $stats.LastLogonTime
                    LastUserActionTime = $stats.LastUserActionTime
                    IsInactive = if ($stats.LastLogonTime) { 
                        ((Get-Date) - $stats.LastLogonTime).Days -gt 90 
                    } else { $true }
                    ExternalPermissionsCount = $externalPermissions.Count
                    HasExternalAccess = $externalPermissions.Count -gt 0
                    ExternalUsers = ($externalPermissions.User -join "; ")
                    LitigationHoldEnabled = $mailbox.LitigationHoldEnabled
                    ForwardingSmtpAddress = $mailbox.ForwardingSmtpAddress
                    DeliverToMailboxAndForward = $mailbox.DeliverToMailboxAndForward
                    CreatedDate = $mailbox.WhenCreated
                    LastModified = $mailbox.WhenChanged
                }
            }
            catch {
                Write-Log "メールボックス情報取得エラー: $($mailbox.DisplayName) - $($_.Exception.Message)" -Level "Warning"
                
                $mailboxReport += [PSCustomObject]@{
                    DisplayName = $mailbox.DisplayName
                    PrimarySmtpAddress = $mailbox.PrimarySmtpAddress
                    UserPrincipalName = $mailbox.UserPrincipalName
                    RecipientTypeDetails = $mailbox.RecipientTypeDetails
                    Department = $mailbox.Department
                    Office = $mailbox.Office
                    IsArchiveEnabled = $mailbox.ArchiveStatus -eq "Active"
                    TotalItemSizeMB = "取得エラー"
                    ItemCount = "取得エラー"
                    DeletedItemSizeMB = "取得エラー"
                    ProhibitSendQuotaMB = "取得エラー"
                    UsagePercent = "取得エラー"
                    RiskLevel = "不明"
                    LastLogonTime = "取得エラー"
                    LastUserActionTime = "取得エラー"
                    IsInactive = "取得エラー"
                    ExternalPermissionsCount = "取得エラー"
                    HasExternalAccess = "取得エラー"
                    ExternalUsers = "取得エラー"
                    LitigationHoldEnabled = $mailbox.LitigationHoldEnabled
                    ForwardingSmtpAddress = $mailbox.ForwardingSmtpAddress
                    DeliverToMailboxAndForward = $mailbox.DeliverToMailboxAndForward
                    CreatedDate = $mailbox.WhenCreated
                    LastModified = $mailbox.WhenChanged
                }
            }
        }
        
        # レポート出力
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "ExchangeMailboxReport_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $mailboxReport -FilePath $outputFile
        
        # 高リスクメールボックス抽出
        $highRiskMailboxes = $mailboxReport | Where-Object { 
            $_.RiskLevel -in @("警告", "緊急") -or 
            $_.HasExternalAccess -eq $true -or
            $_.IsInactive -eq $true
        }
        
        if ($highRiskMailboxes.Count -gt 0) {
            $highRiskOutputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "ExchangeHighRiskMailboxes_$(Get-Date -Format 'yyyyMMdd').csv"
            Export-DataToCSV -Data $highRiskMailboxes -FilePath $highRiskOutputFile
        }
        
        Write-AuditLog -Action "メールボックスレポート" -Target "Exchange Online" -Result "成功" -Details "$($mailboxReport.Count)件中$($highRiskMailboxes.Count)件が要注意"
        
        return @{
            AllMailboxes = $mailboxReport
            HighRiskMailboxes = $highRiskMailboxes
        }
    }
}

function Get-ExchangeMessageTrace {
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 1,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Daily"
    )
    
    return Invoke-SafeOperation -OperationName "Exchange Onlineメッセージトレース" -Operation {
        Write-Log "Exchange Onlineメッセージトレース分析を開始します（過去 $DaysBack 日間）" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ExchangeOnlineManagement")
        
        $startDate = (Get-Date).AddDays(-$DaysBack)
        $endDate = Get-Date
        
        $messageTrace = Get-MessageTrace -StartDate $startDate -EndDate $endDate -PageSize 5000
        $traceReport = @()
        
        foreach ($message in $messageTrace) {
            $traceReport += [PSCustomObject]@{
                Timestamp = $message.Received
                SenderAddress = $message.SenderAddress
                RecipientAddress = $message.RecipientAddress
                Subject = $message.Subject
                Status = $message.Status
                ToIP = $message.ToIP
                FromIP = $message.FromIP
                Size = $message.Size
                MessageId = $message.MessageId
                MessageTraceId = $message.MessageTraceId
                IsSpam = $message.Status -eq "FilteredAsSpam"
                IsBlocked = $message.Status -in @("Failed", "Blocked")
                IsExternal = -not ($message.SenderAddress -like "*@$((Get-AcceptedDomain | Where-Object {$_.Default}).Name)*")
                HasAttachment = $message.Size -gt 50000  # 50KB以上を添付ファイルありと仮定
            }
        }
        
        # 基本レポート出力
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "ExchangeMessageTrace_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $traceReport -FilePath $outputFile
        
        # スパム・ブロックメール抽出
        $spamBlockedMessages = $traceReport | Where-Object { $_.IsSpam -or $_.IsBlocked }
        if ($spamBlockedMessages.Count -gt 0) {
            $spamOutputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "ExchangeSpamBlockedMessages_$(Get-Date -Format 'yyyyMMdd').csv"
            Export-DataToCSV -Data $spamBlockedMessages -FilePath $spamOutputFile
        }
        
        # 外部メール統計
        $externalMessages = $traceReport | Where-Object { $_.IsExternal }
        if ($externalMessages.Count -gt 0) {
            $externalOutputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "ExchangeExternalMessages_$(Get-Date -Format 'yyyyMMdd').csv"
            Export-DataToCSV -Data $externalMessages -FilePath $externalOutputFile
        }
        
        Write-AuditLog -Action "メッセージトレース" -Target "Exchange Online" -Result "成功" -Details "総数:$($traceReport.Count)件、スパム/ブロック:$($spamBlockedMessages.Count)件、外部:$($externalMessages.Count)件"
        
        return @{
            AllMessages = $traceReport
            SpamBlockedMessages = $spamBlockedMessages
            ExternalMessages = $externalMessages
        }
    }
}

function Get-ExchangeTransportRules {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Weekly"
    )
    
    return Invoke-SafeOperation -OperationName "Exchange Onlineトランスポートルール" -Operation {
        Write-Log "Exchange Onlineトランスポートルール分析を開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ExchangeOnlineManagement")
        
        $transportRules = Get-TransportRule
        $ruleReport = @()
        
        foreach ($rule in $transportRules) {
            $conditions = @()
            $actions = @()
            
            # 条件の抽出
            if ($rule.FromAddressContainsWords) { $conditions += "送信者アドレス文字列: $($rule.FromAddressContainsWords -join ', ')" }
            if ($rule.RecipientAddressContainsWords) { $conditions += "受信者アドレス文字列: $($rule.RecipientAddressContainsWords -join ', ')" }
            if ($rule.SubjectContainsWords) { $conditions += "件名文字列: $($rule.SubjectContainsWords -join ', ')" }
            if ($rule.BodyContainsWords) { $conditions += "本文文字列: $($rule.BodyContainsWords -join ', ')" }
            if ($rule.AttachmentHasExecutableContent) { $conditions += "実行可能添付ファイル: $($rule.AttachmentHasExecutableContent)" }
            if ($rule.MessageSizeOver) { $conditions += "メッセージサイズ上限: $($rule.MessageSizeOver)" }
            
            # アクションの抽出
            if ($rule.BlockMessage) { $actions += "メッセージブロック: $($rule.BlockMessage)" }
            if ($rule.DeleteMessage) { $actions += "メッセージ削除: $($rule.DeleteMessage)" }
            if ($rule.ModerateMessageByUser) { $actions += "承認者: $($rule.ModerateMessageByUser -join ', ')" }
            if ($rule.RedirectMessageTo) { $actions += "リダイレクト先: $($rule.RedirectMessageTo -join ', ')" }
            if ($rule.BlindCopyTo) { $actions += "BCC追加: $($rule.BlindCopyTo -join ', ')" }
            if ($rule.PrependSubject) { $actions += "件名プレフィックス: $($rule.PrependSubject)" }
            if ($rule.ApplyClassification) { $actions += "分類: $($rule.ApplyClassification)" }
            if ($rule.SetSCL) { $actions += "スパム信頼度: $($rule.SetSCL)" }
            
            $ruleReport += [PSCustomObject]@{
                Name = $rule.Name
                Description = $rule.Description
                State = $rule.State
                Mode = $rule.Mode
                Priority = $rule.Priority
                Conditions = ($conditions -join " | ")
                Actions = ($actions -join " | ")
                IsHighImpact = ($rule.DeleteMessage -or $rule.BlockMessage -or $rule.QuarantineMessage)
                IsSecurityRelated = ($rule.AttachmentHasExecutableContent -or 
                                   $rule.AttachmentIsUnsupported -or 
                                   $rule.SubjectContainsWords -contains "phishing" -or
                                   $rule.SubjectContainsWords -contains "malware")
                CreatedBy = $rule.CreatedBy
                LastModified = $rule.LastModifiedTime
                RuleVersion = $rule.RuleVersion
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Weekly") "ExchangeTransportRules_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $ruleReport -FilePath $outputFile
        
        $highImpactRules = ($ruleReport | Where-Object { $_.IsHighImpact -eq $true }).Count
        $securityRules = ($ruleReport | Where-Object { $_.IsSecurityRelated -eq $true }).Count
        
        Write-AuditLog -Action "トランスポートルール分析" -Target "Exchange Online" -Result "成功" -Details "総数:$($ruleReport.Count)件、高影響:$highImpactRules件、セキュリティ:$securityRules件"
        
        return $ruleReport
    }
}

function Get-ExchangeDistributionGroups {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -OperationName "Exchange Online配布グループ" -Operation {
        Write-Log "Exchange Online配布グループ分析を開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ExchangeOnlineManagement")
        
        $distributionGroups = Get-DistributionGroup -ResultSize Unlimited
        $groupReport = @()
        
        foreach ($group in $distributionGroups) {
            try {
                $members = Get-DistributionGroupMember -Identity $group.Identity -ErrorAction SilentlyContinue
                
                # 外部メンバーチェック
                $internalDomain = (Get-AcceptedDomain | Where-Object {$_.Default}).Name
                $externalMembers = $members | Where-Object { 
                    $_.PrimarySmtpAddress -notlike "*@$internalDomain*"
                }
                
                $groupReport += [PSCustomObject]@{
                    Name = $group.Name
                    DisplayName = $group.DisplayName
                    PrimarySmtpAddress = $group.PrimarySmtpAddress
                    GroupType = $group.GroupType
                    RecipientTypeDetails = $group.RecipientTypeDetails
                    MemberCount = $members.Count
                    ExternalMemberCount = $externalMembers.Count
                    HasExternalMembers = $externalMembers.Count -gt 0
                    ExternalMembers = ($externalMembers.PrimarySmtpAddress -join "; ")
                    RequireSenderAuthenticationEnabled = $group.RequireSenderAuthenticationEnabled
                    AcceptMessagesOnlyFromSendersOrMembers = $group.AcceptMessagesOnlyFromSendersOrMembers.Count -gt 0
                    IsSecurityEnabled = $group.GroupType -eq "Security"
                    ManagedBy = ($group.ManagedBy -join "; ")
                    CreatedDate = $group.WhenCreated
                    LastModified = $group.WhenChanged
                    IsHighRisk = ($externalMembers.Count -gt 0 -and -not $group.RequireSenderAuthenticationEnabled)
                }
            }
            catch {
                Write-Log "配布グループ情報取得エラー: $($group.Name) - $($_.Exception.Message)" -Level "Warning"
                
                $groupReport += [PSCustomObject]@{
                    Name = $group.Name
                    DisplayName = $group.DisplayName
                    PrimarySmtpAddress = $group.PrimarySmtpAddress
                    GroupType = $group.GroupType
                    RecipientTypeDetails = $group.RecipientTypeDetails
                    MemberCount = "取得エラー"
                    ExternalMemberCount = "取得エラー"
                    HasExternalMembers = "取得エラー"
                    ExternalMembers = "取得エラー"
                    RequireSenderAuthenticationEnabled = $group.RequireSenderAuthenticationEnabled
                    AcceptMessagesOnlyFromSendersOrMembers = $group.AcceptMessagesOnlyFromSendersOrMembers.Count -gt 0
                    IsSecurityEnabled = $group.GroupType -eq "Security"
                    ManagedBy = ($group.ManagedBy -join "; ")
                    CreatedDate = $group.WhenCreated
                    LastModified = $group.WhenChanged
                    IsHighRisk = "不明"
                }
            }
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "ExchangeDistributionGroups_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $groupReport -FilePath $outputFile
        
        # 高リスクグループ抽出
        $highRiskGroups = $groupReport | Where-Object { $_.IsHighRisk -eq $true }
        if ($highRiskGroups.Count -gt 0) {
            $highRiskOutputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "ExchangeHighRiskGroups_$(Get-Date -Format 'yyyyMMdd').csv"
            Export-DataToCSV -Data $highRiskGroups -FilePath $highRiskOutputFile
        }
        
        Write-AuditLog -Action "配布グループ分析" -Target "Exchange Online" -Result "成功" -Details "$($groupReport.Count)件中$($highRiskGroups.Count)件が高リスク"
        
        return @{
            AllGroups = $groupReport
            HighRiskGroups = $highRiskGroups
        }
    }
}

# スクリプト直接実行時の処理
if ($MyInvocation.InvocationName -ne '.') {
    $config = Initialize-ManagementTools
    
    Write-Log "Exchange Onlineメールボックス管理スクリプトを実行します" -Level "Info"
    
    try {
        if ($config) {
            # 新しい認証システムを使用
            $connectionResult = Connect-ToMicrosoft365 -Config $config -Services @("ExchangeOnline")
            
            if (-not $connectionResult.Success) {
                throw "Exchange Online への接続に失敗しました: $($connectionResult.Errors -join ', ')"
            }
            
            Write-Log "Exchange Online 接続成功" -Level "Info"
        }
        else {
            Write-Log "設定ファイルが見つからないため、手動接続が必要です" -Level "Warning"
            throw "設定ファイルが見つかりません"
        }
        
        # 各レポート実行
        Write-Log "メールボックスレポートを実行中..." -Level "Info"
        Get-ExchangeMailboxReport
        
        Write-Log "トランスポートルール分析を実行中..." -Level "Info"
        Get-ExchangeTransportRules
        
        Write-Log "メッセージトレース分析を実行中..." -Level "Info"
        Get-ExchangeMessageTrace
        
        Write-Log "配布グループ分析を実行中..." -Level "Info"
        Get-ExchangeDistributionGroups
        
        Write-Log "Exchange Onlineメールボックス管理スクリプトが正常に完了しました" -Level "Info"
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        Send-ErrorNotification -ErrorDetails $errorDetails
        Write-Log "Exchange Onlineメールボックス管理エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
    finally {
        Disconnect-AllServices
    }
}