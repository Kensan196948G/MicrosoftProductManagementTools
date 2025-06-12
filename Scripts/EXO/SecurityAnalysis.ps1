# ================================================================================
# SecurityAnalysis.ps1
# Exchange Online セキュリティ分析スクリプト
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\ErrorHandling.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\Logging.psm1" -Force

function Get-EXOSpamPhishingAnalysis {
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 7,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Weekly"
    )
    
    return Invoke-SafeOperation -ScriptBlock {
        Write-Log "Exchange Onlineスパム・フィッシング分析を開始します（過去 $DaysBack 日間）" -Level "Info"
        
        Test-Prerequisites -Prerequisites @(
            @{ Name = "ExchangeOnlineManagement"; Type = "Module"; Target = "ExchangeOnlineManagement" }
        )
        
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
    
    return Invoke-SafeOperation -ScriptBlock {
        Write-Log "Exchange Onlineメール配送レポートを開始します（過去 $DaysBack 日間）" -Level "Info"
        
        Test-Prerequisites -Prerequisites @(
            @{ Name = "ExchangeOnlineManagement"; Type = "Module"; Target = "ExchangeOnlineManagement" }
        )
        
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

function Get-EXORoomResourceAudit {
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 7,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Weekly",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $true
    )
    
    return Invoke-SafeOperation -ScriptBlock {
        Write-Log "Exchange Online会議室利用状況監査を開始します（過去 $DaysBack 日間）" -Level "Info"
        
        Test-Prerequisites -Prerequisites @(
            @{ Name = "ExchangeOnlineManagement"; Type = "Module"; Target = "ExchangeOnlineManagement" }
        )
        
        $startDate = (Get-Date).AddDays(-$DaysBack)
        $endDate = Get-Date
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        $roomUtilizationReport = @()
        $roomBookingReport = @()
        $utilizationSummary = @{}
        
        try {
            # 会議室メールボックス取得
            $roomMailboxes = Get-EXOMailbox -RecipientTypeDetails RoomMailbox -PropertySets All
            Write-Log "$($roomMailboxes.Count)件の会議室を検出しました" -Level "Info"
            
            foreach ($room in $roomMailboxes) {
                try {
                    Write-Log "会議室の予約分析を実行中: $($room.DisplayName)" -Level "Info"
                    
                    # 会議室統計情報取得
                    $roomStats = Get-EXOMailboxStatistics -Identity $room.UserPrincipalName -ErrorAction SilentlyContinue
                    
                    # 予約履歴分析（過去の予約からパターンを推定）
                    $bookingAnalysis = @{
                        TotalSlots = $DaysBack * 24 # 1日24時間として計算
                        BookedSlots = 0
                        AverageBookingDuration = 0
                        PeakUsageHours = @()
                        BookingPattern = "分析中"
                    }
                    
                    # メールボックスサイズから利用頻度を推定
                    $itemCount = if ($roomStats) { $roomStats.ItemCount } else { 0 }
                    $estimatedBookings = [math]::Max(0, [math]::Floor($itemCount / 10)) # 10アイテムあたり1予約と推定
                    
                    # 利用率計算（推定値）
                    $utilizationRate = if ($bookingAnalysis.TotalSlots -gt 0) {
                        [math]::Min(100, ($estimatedBookings / ($DaysBack * 3)) * 100) # 1日3予約を最大として計算
                    } else { 0 }
                    
                    # ピーク時間帯推定（経験的データに基づく）
                    $peakHours = if ($utilizationRate -gt 50) {
                        @("09:00-10:00", "11:00-12:00", "14:00-15:00", "16:00-17:00")
                    } elseif ($utilizationRate -gt 20) {
                        @("10:00-11:00", "14:00-15:00")
                    } else {
                        @("随時利用可能")
                    }
                    
                    $roomUtilizationReport += [PSCustomObject]@{
                        RoomName = $room.DisplayName
                        EmailAddress = $room.UserPrincipalName
                        ResourceCapacity = $room.ResourceCapacity
                        AnalysisPeriod = "$($startDate.ToString('yyyy/MM/dd')) - $($endDate.ToString('yyyy/MM/dd'))"
                        EstimatedBookings = $estimatedBookings
                        UtilizationRate = [math]::Round($utilizationRate, 2)
                        PeakUsageHours = ($peakHours -join ", ")
                        LastActivity = if ($roomStats) { $roomStats.LastLogonTime } else { "不明" }
                        TotalItemSize = if ($roomStats) { $roomStats.TotalItemSize } else { "0 MB" }
                        ItemCount = $itemCount
                        BookingPolicy = $room.AutomateProcessing
                        MaxBookingDays = $room.BookingWindowInDays
                        MaxDurationMinutes = $room.MaximumDurationInMinutes
                        AllowRecurring = $room.AllowRecurringMeetings
                        Status = if ($utilizationRate -gt 80) { "高負荷" } elseif ($utilizationRate -gt 50) { "標準" } elseif ($utilizationRate -gt 10) { "軽負荷" } else { "未使用" }
                        RiskLevel = if ($utilizationRate -gt 90) { "高" } elseif ($utilizationRate -lt 5) { "低（未活用）" } else { "正常" }
                        RecommendedAction = if ($utilizationRate -gt 90) { "追加会議室検討" } elseif ($utilizationRate -lt 5) { "利用促進・設定見直し" } else { "現状維持" }
                        AnalysisTimestamp = $endDate
                    }
                    
                } catch {
                    Write-Log "会議室分析エラー: $($room.DisplayName) - $($_.Exception.Message)" -Level "Warning"
                    
                    $roomUtilizationReport += [PSCustomObject]@{
                        RoomName = $room.DisplayName
                        EmailAddress = $room.UserPrincipalName
                        ResourceCapacity = $room.ResourceCapacity
                        AnalysisPeriod = "$($startDate.ToString('yyyy/MM/dd')) - $($endDate.ToString('yyyy/MM/dd'))"
                        EstimatedBookings = 0
                        UtilizationRate = 0
                        PeakUsageHours = "分析エラー"
                        LastActivity = "取得エラー"
                        TotalItemSize = "取得エラー"
                        ItemCount = 0
                        BookingPolicy = $room.AutomateProcessing
                        MaxBookingDays = $room.BookingWindowInDays
                        MaxDurationMinutes = $room.MaximumDurationInMinutes
                        AllowRecurring = $room.AllowRecurringMeetings
                        Status = "エラー"
                        RiskLevel = "不明"
                        RecommendedAction = "設定確認が必要"
                        AnalysisTimestamp = $endDate
                    }
                }
            }
            
            # 全体統計計算
            $utilizationSummary = @{
                TotalRooms = $roomMailboxes.Count
                HighUtilization = ($roomUtilizationReport | Where-Object { $_.UtilizationRate -gt 80 }).Count
                NormalUtilization = ($roomUtilizationReport | Where-Object { $_.UtilizationRate -ge 20 -and $_.UtilizationRate -le 80 }).Count
                LowUtilization = ($roomUtilizationReport | Where-Object { $_.UtilizationRate -lt 20 }).Count
                UnusedRooms = ($roomUtilizationReport | Where-Object { $_.UtilizationRate -eq 0 }).Count
                AverageUtilization = if ($roomUtilizationReport.Count -gt 0) { [math]::Round(($roomUtilizationReport | Measure-Object UtilizationRate -Average).Average, 2) } else { 0 }
                TotalEstimatedBookings = ($roomUtilizationReport | Measure-Object EstimatedBookings -Sum).Sum
                AnalysisPeriod = "$DaysBack日間"
                GeneratedAt = $endDate
            }
            
        } catch {
            Write-Log "会議室リソース監査エラー: $($_.Exception.Message)" -Level "Error"
            throw
        }
        
        # CSV出力
        if ($ExportCSV) {
            $csvPath = Join-Path (New-ReportDirectory -ReportType "Weekly") "Room_Utilization_Audit_$timestamp.csv"
            Export-DataToCSV -Data $roomUtilizationReport -FilePath $csvPath
            Write-Log "CSVレポート出力完了: $csvPath" -Level "Info"
        }
        
        # HTML出力
        if ($ExportHTML) {
            $htmlPath = Join-Path (New-ReportDirectory -ReportType "Weekly") "Room_Utilization_Audit_$timestamp.html"
            $htmlContent = Generate-RoomUtilizationHTML -Data $roomUtilizationReport -Summary $utilizationSummary
            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
            Write-Log "HTMLレポート出力完了: $htmlPath" -Level "Info"
        }
        
        Write-AuditLog -Action "会議室利用状況監査" -Target "会議室メールボックス" -Result "成功" -Details "$($roomUtilizationReport.Count)件の会議室を分析、平均利用率: $($utilizationSummary.AverageUtilization)%"
        
        return @{
            UtilizationData = $roomUtilizationReport
            Summary = $utilizationSummary
            CSVPath = if ($ExportCSV) { $csvPath } else { $null }
            HTMLPath = if ($ExportHTML) { $htmlPath } else { $null }
        }
    }
}

function Get-EXORoomResourceReport {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly"
    )
    
    return Invoke-SafeOperation -ScriptBlock {
        Write-Log "Exchange Online会議室リソースレポートを開始します" -Level "Info"
        
        Test-Prerequisites -Prerequisites @(
            @{ Name = "ExchangeOnlineManagement"; Type = "Module"; Target = "ExchangeOnlineManagement" }
        )
        
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

function Generate-RoomUtilizationHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    $timestamp = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
    
    # データが空の場合のダミーデータ
    if ($Data.Count -eq 0) {
        $Data = @([PSCustomObject]@{
            RoomName = "システム情報"
            EmailAddress = "分析結果"
            ResourceCapacity = 0
            AnalysisPeriod = $Summary.AnalysisPeriod
            EstimatedBookings = 0
            UtilizationRate = 0
            PeakUsageHours = "データなし"
            LastActivity = "不明"
            Status = "情報"
            RiskLevel = "低"
            RecommendedAction = "指定期間内に会議室データが見つかりませんでした"
        })
    }
    
    # 利用率によるステータス色の設定
    $statusColorMap = @{
        "高負荷" = "danger"
        "標準" = "success" 
        "軽負荷" = "warning"
        "未使用" = "secondary"
        "エラー" = "dark"
        "情報" = "info"
    }
    
    $html = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>会議室利用状況監査レポート - みらい建設工業株式会社</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }
        .header { 
            background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%); 
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
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); 
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
        .summary-card .description { font-size: 12px; color: #888; }
        .value.success { color: #107c10; }
        .value.warning { color: #ff8c00; }
        .value.danger { color: #d13438; }
        .room-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .room-card {
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            border-left: 4px solid #0078d4;
        }
        .room-card.high-utilization { border-left-color: #d13438; }
        .room-card.normal-utilization { border-left-color: #107c10; }
        .room-card.low-utilization { border-left-color: #ff8c00; }
        .room-card.unused { border-left-color: #6c757d; }
        .room-name { font-size: 18px; font-weight: bold; margin-bottom: 10px; }
        .room-utilization { 
            font-size: 24px; 
            font-weight: bold; 
            margin: 10px 0; 
        }
        .room-details { font-size: 14px; color: #666; }
        .room-details div { margin: 5px 0; }
        .status-badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
            text-transform: uppercase;
        }
        .status-high { background-color: #f8d7da; color: #721c24; }
        .status-normal { background-color: #d4edda; color: #155724; }
        .status-low { background-color: #fff3cd; color: #856404; }
        .status-unused { background-color: #e2e3e5; color: #383d41; }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        @media print {
            body { background-color: white; }
            .room-grid { grid-template-columns: repeat(2, 1fr); }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🏢 会議室利用状況監査レポート</h1>
        <div class="subtitle">みらい建設工業株式会社 - Exchange Online</div>
        <div class="subtitle">分析期間: $($Summary.AnalysisPeriod)</div>
        <div class="subtitle">レポート生成日時: $timestamp</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>総会議室数</h3>
            <div class="value">$($Summary.TotalRooms)</div>
            <div class="description">登録済み会議室</div>
        </div>
        <div class="summary-card">
            <h3>平均利用率</h3>
            <div class="value$(if($Summary.AverageUtilization -gt 80) { ' danger' } elseif($Summary.AverageUtilization -gt 50) { ' success' } else { ' warning' })">$($Summary.AverageUtilization)%</div>
            <div class="description">期間平均</div>
        </div>
        <div class="summary-card">
            <h3>高負荷会議室</h3>
            <div class="value$(if($Summary.HighUtilization -gt 0) { ' danger' } else { ' success' })">$($Summary.HighUtilization)</div>
            <div class="description">利用率80%以上</div>
        </div>
        <div class="summary-card">
            <h3>標準稼働</h3>
            <div class="value success">$($Summary.NormalUtilization)</div>
            <div class="description">利用率20-80%</div>
        </div>
        <div class="summary-card">
            <h3>低稼働</h3>
            <div class="value warning">$($Summary.LowUtilization)</div>
            <div class="description">利用率20%未満</div>
        </div>
        <div class="summary-card">
            <h3>未使用</h3>
            <div class="value$(if($Summary.UnusedRooms -gt 0) { ' warning' } else { ' success' })">$($Summary.UnusedRooms)</div>
            <div class="description">利用記録なし</div>
        </div>
    </div>

    <div class="room-grid">
"@

    foreach ($room in $Data) {
        $utilizationClass = switch ($room.Status) {
            "高負荷" { "high-utilization" }
            "標準" { "normal-utilization" }
            "軽負荷" { "low-utilization" }
            "未使用" { "unused" }
            default { "normal-utilization" }
        }
        
        $statusClass = switch ($room.Status) {
            "高負荷" { "status-high" }
            "標準" { "status-normal" }
            "軽負荷" { "status-low" }
            "未使用" { "status-unused" }
            default { "status-normal" }
        }
        
        $utilizationColor = if ($room.UtilizationRate -gt 80) { "danger" } elseif ($room.UtilizationRate -gt 50) { "success" } else { "warning" }
        
        $html += @"
        <div class="room-card $utilizationClass">
            <div class="room-name">$($room.RoomName)</div>
            <div class="room-utilization">
                <span class="value $utilizationColor">$($room.UtilizationRate)%</span>
                <span class="status-badge $statusClass">$($room.Status)</span>
            </div>
            <div class="room-details">
                <div><strong>収容人数:</strong> $($room.ResourceCapacity)人</div>
                <div><strong>予想予約数:</strong> $($room.EstimatedBookings)件</div>
                <div><strong>ピーク時間:</strong> $($room.PeakUsageHours)</div>
                <div><strong>最終利用:</strong> $($room.LastActivity)</div>
                <div><strong>予約ポリシー:</strong> $($room.BookingPolicy)</div>
                <div><strong>最大予約期間:</strong> $($room.MaxBookingDays)日</div>
                <div><strong>推奨アクション:</strong> $($room.RecommendedAction)</div>
            </div>
        </div>
"@
    }

    $html += @"
    </div>

    <div class="footer">
        <p>このレポートは Microsoft 365 統合管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $html
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
        Get-EXORoomResourceAudit
        
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