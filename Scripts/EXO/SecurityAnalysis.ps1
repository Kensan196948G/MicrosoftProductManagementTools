# ================================================================================
# SecurityAnalysis.ps1
# Exchange Online セキュリティ分析スクリプト
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force

function Get-EXOSpamPhishingAnalysis {
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 7,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Weekly"
    )
    
    return Invoke-SafeOperation -OperationName "EXOスパム・フィッシング分析" -Operation {
        Write-Log "Exchange Onlineスパム・フィッシング分析を開始します（過去 $DaysBack 日間）" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ExchangeOnlineManagement")
        
        $startDate = (Get-Date).AddDays(-$DaysBack)
        $endDate = Get-Date
        
        $spamReport = @()
        $phishingReport = @()
        
        try {
            $messageTrace = Get-MessageTrace -StartDate $startDate -EndDate $endDate -PageSize 5000 | 
            Where-Object { $_.Status -in @("FilteredAsSpam", "FilteredAsPhish", "FilteredAsMalware") }
            
            foreach ($message in $messageTrace) {
                $reportEntry = [PSCustomObject]@{
                    Received = $message.Received
                    SenderAddress = $message.SenderAddress
                    RecipientAddress = $message.RecipientAddress
                    Subject = $message.Subject
                    Status = $message.Status
                    Size = $message.Size
                    MessageId = $message.MessageId
                    ToIP = $message.ToIP
                    FromIP = $message.FromIP
                }
                
                switch ($message.Status) {
                    "FilteredAsSpam" { $spamReport += $reportEntry }
                    "FilteredAsPhish" { $phishingReport += $reportEntry }
                    "FilteredAsMalware" { $phishingReport += $reportEntry }
                }
            }
        }
        catch {
            Write-Log "メッセージトレース取得エラー: $($_.Exception.Message)" -Level "Warning"
        }
        
        $spamOutputFile = Join-Path (New-ReportDirectory -ReportType "Weekly") "EXOSpamAnalysis_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $spamReport -FilePath $spamOutputFile
        
        $phishingOutputFile = Join-Path (New-ReportDirectory -ReportType "Weekly") "EXOPhishingAnalysis_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $phishingReport -FilePath $phishingOutputFile
        
        $senderAnalysis = $spamReport + $phishingReport | 
        Group-Object SenderAddress | 
        Sort-Object Count -Descending | 
        Select-Object Name, Count, @{Name="FirstSeen"; Expression={($_.Group | Sort-Object Received)[0].Received}}, @{Name="LastSeen"; Expression={($_.Group | Sort-Object Received -Descending)[0].Received}}
        
        $senderOutputFile = Join-Path (New-ReportDirectory -ReportType "Weekly") "EXOMaliciousSenders_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $senderAnalysis -FilePath $senderOutputFile
        
        Write-AuditLog -Action "スパム・フィッシング分析" -Target "メールメッセージ" -Result "成功" -Details "スパム:$($spamReport.Count)件、フィッシング:$($phishingReport.Count)件"
        
        return @{
            SpamMessages = $spamReport
            PhishingMessages = $phishingReport
            SuspiciousSenders = $senderAnalysis
        }
    }
}

function Get-EXOMailDeliveryReport {
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 1,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Daily"
    )
    
    return Invoke-SafeOperation -OperationName "EXOメール配送レポート" -Operation {
        Write-Log "Exchange Onlineメール配送レポートを開始します（過去 $DaysBack 日間）" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ExchangeOnlineManagement")
        
        $startDate = (Get-Date).AddDays(-$DaysBack)
        $endDate = Get-Date
        
        $deliveryReport = @()
        
        try {
            $messageTrace = Get-MessageTrace -StartDate $startDate -EndDate $endDate -PageSize 5000
            
            $statusSummary = $messageTrace | Group-Object Status | Select-Object Name, Count
            
            $delayedMessages = $messageTrace | Where-Object { 
                $_.Status -eq "Pending" -or 
                ($_.Received -and $_.Status -eq "Delivered" -and 
                 ((Get-Date) - $_.Received).TotalMinutes -gt 30)
            }
            
            $failedMessages = $messageTrace | Where-Object { 
                $_.Status -in @("Failed", "FilteredAsSpam", "Quarantined") 
            }
            
            foreach ($message in $messageTrace) {
                $deliveryTime = if ($message.Status -eq "Delivered" -and $message.Received) {
                    ((Get-Date) - $message.Received).TotalMinutes
                } else { $null }
                
                $deliveryReport += [PSCustomObject]@{
                    Received = $message.Received
                    SenderAddress = $message.SenderAddress
                    RecipientAddress = $message.RecipientAddress
                    Subject = $message.Subject
                    Status = $message.Status
                    Size = $message.Size
                    MessageId = $message.MessageId
                    DeliveryTimeMinutes = $deliveryTime
                    IsDelayed = if ($deliveryTime -gt 30) { $true } else { $false }
                }
            }
        }
        catch {
            Write-Log "メール配送レポート取得エラー: $($_.Exception.Message)" -Level "Warning"
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "EXODeliveryReport_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $deliveryReport -FilePath $outputFile
        
        $summaryOutputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "EXODeliveryStatus_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $statusSummary -FilePath $summaryOutputFile
        
        $delayedOutputFile = Join-Path (New-ReportDirectory -ReportType "Daily") "EXODelayedMessages_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $delayedMessages -FilePath $delayedOutputFile
        
        Write-AuditLog -Action "メール配送レポート" -Target "メールメッセージ" -Result "成功" -Details "総数:$($deliveryReport.Count)件、遅延:$($delayedMessages.Count)件、失敗:$($failedMessages.Count)件"
        
        return @{
            AllMessages = $deliveryReport
            StatusSummary = $statusSummary
            DelayedMessages = $delayedMessages
            FailedMessages = $failedMessages
        }
    }
}

function Get-EXORoomResourceReport {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -OperationName "EXO会議室リソースレポート" -Operation {
        Write-Log "Exchange Online会議室リソースレポートを開始します" -Level "Info"
        
        Test-Prerequisites -RequiredModules @("ExchangeOnlineManagement")
        
        $roomReport = @()
        
        try {
            $roomMailboxes = Get-EXOMailbox -RecipientTypeDetails RoomMailbox -PropertySets All
            
            foreach ($room in $roomMailboxes) {
                try {
                    $roomStats = Get-EXOMailboxStatistics -Identity $room.UserPrincipalName
                    $roomCalendar = Get-EXOCalendarPermission -Identity "$($room.UserPrincipalName):\Calendar" -ErrorAction SilentlyContinue
                    
                    $roomReport += [PSCustomObject]@{
                        RoomName = $room.DisplayName
                        EmailAddress = $room.UserPrincipalName
                        ResourceCapacity = $room.ResourceCapacity
                        AutomateProcessing = $room.AutomateProcessing
                        BookingWindowInDays = $room.BookingWindowInDays
                        MaximumDurationInMinutes = $room.MaximumDurationInMinutes
                        AllowRecurringMeetings = $room.AllowRecurringMeetings
                        BookInPolicy = ($room.BookInPolicy -join "; ")
                        RequestInPolicy = ($room.RequestInPolicy -join "; ")
                        RequestOutOfPolicy = ($room.RequestOutOfPolicy -join "; ")
                        AllRequestInPolicy = $room.AllRequestInPolicy
                        AllRequestOutOfPolicy = $room.AllRequestOutOfPolicy
                        LastLogonTime = $roomStats.LastLogonTime
                        TotalItemSize = $roomStats.TotalItemSize
                        ItemCount = $roomStats.ItemCount
                    }
                }
                catch {
                    Write-Log "会議室詳細取得エラー: $($room.DisplayName)" -Level "Warning"
                    
                    $roomReport += [PSCustomObject]@{
                        RoomName = $room.DisplayName
                        EmailAddress = $room.UserPrincipalName
                        ResourceCapacity = $room.ResourceCapacity
                        AutomateProcessing = $room.AutomateProcessing
                        BookingWindowInDays = $room.BookingWindowInDays
                        MaximumDurationInMinutes = $room.MaximumDurationInMinutes
                        AllowRecurringMeetings = $room.AllowRecurringMeetings
                        BookInPolicy = ($room.BookInPolicy -join "; ")
                        RequestInPolicy = ($room.RequestInPolicy -join "; ")
                        RequestOutOfPolicy = ($room.RequestOutOfPolicy -join "; ")
                        AllRequestInPolicy = $room.AllRequestInPolicy
                        AllRequestOutOfPolicy = $room.AllRequestOutOfPolicy
                        LastLogonTime = "取得エラー"
                        TotalItemSize = "取得エラー"
                        ItemCount = "取得エラー"
                    }
                }
            }
        }
        catch {
            Write-Log "会議室リソース取得エラー: $($_.Exception.Message)" -Level "Error"
        }
        
        $outputFile = Join-Path (New-ReportDirectory -ReportType "Monthly") "EXORoomResources_$(Get-Date -Format 'yyyyMMdd').csv"
        Export-DataToCSV -Data $roomReport -FilePath $outputFile
        
        Write-AuditLog -Action "会議室リソースレポート" -Target "会議室メールボックス" -Result "成功" -Details "$($roomReport.Count)件の会議室を分析"
        
        return $roomReport
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $config = Initialize-ManagementTools
    
    Write-Log "Exchange Onlineセキュリティ分析スクリプトを実行します" -Level "Info"
    
    try {
        if ($config) {
            Connect-ExchangeOnlineService -Organization $config.ExchangeOnline.Organization -AppId $config.ExchangeOnline.AppId -CertificateThumbprint $config.ExchangeOnline.CertificateThumbprint
        }
        else {
            Write-Log "設定ファイルが見つからないため、手動接続が必要です" -Level "Warning"
        }
        
        Get-EXOSpamPhishingAnalysis
        Get-EXOMailDeliveryReport
        Get-EXORoomResourceReport
        
        Write-Log "Exchange Onlineセキュリティ分析スクリプトが正常に完了しました" -Level "Info"
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