# ================================================================================
# ExchangeManagement.psm1
# EX系 - Exchange Online管理機能モジュール
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\Authentication.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\ReportGenerator.psm1" -Force

# EX-02: 添付ファイル送信履歴分析（改良版）
function Get-AttachmentAnalysis {
    param(
        [Parameter(Mandatory = $false)]
        [int]$Days = 7,  # E3制限を考慮して短期間に設定
        
        [Parameter(Mandatory = $false)]
        [int]$SizeThresholdMB = 10,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false
    )
    
    Write-Log "添付ファイル送信履歴分析を開始します (過去${Days}日間, 閾値: ${SizeThresholdMB}MB)" -Level "Info"
    
    try {
        # Exchange Online接続確認と自動接続
        try {
            Get-Mailbox -ResultSize 1 -ErrorAction Stop | Out-Null
            Write-Log "Exchange Online 接続確認完了" -Level "Info"
        }
        catch {
            Write-Log "Exchange Online に接続されていません。自動接続を試行します..." -Level "Warning"
            
            try {
                if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                }
                
                $config = Initialize-ManagementTools
                if (-not $config) {
                    throw "設定ファイルの読み込みに失敗しました"
                }
                
                Write-Log "Exchange Online への自動接続を開始します" -Level "Info"
                $connectResult = Connect-ExchangeOnlineService -Config $config
                
                if ($connectResult) {
                    Write-Log "Exchange Online 自動接続成功" -Level "Info"
                }
                else {
                    throw "Exchange Online への自動接続に失敗しました"
                }
            }
            catch {
                throw "Exchange Online 接続エラー: $($_.Exception.Message). 先にメニュー選択2で認証テストを実行してください。"
            }
        }
        
        # E3制限を考慮したデータ期間調整 (最大7日間に制限)
        $adjustedDays = [Math]::Min($Days, 7)
        if ($Days -gt 7) {
            Write-Log "E3ライセンス制限により、分析期間を${adjustedDays}日間に調整します" -Level "Warning"
        }
        
        $startDate = (Get-Date).AddDays(-$adjustedDays).Date
        $endDate = (Get-Date).Date
        
        Write-Log "メッセージトレースを実行中 (期間: $($startDate.ToString('yyyy-MM-dd')) - $($endDate.ToString('yyyy-MM-dd')))..." -Level "Info"
        
        try {
            # E3制限内でメッセージトレースを取得 (結果サイズも制限)
            $messageTrace = Get-MessageTrace -StartDate $startDate -EndDate $endDate -PageSize 1000 -ResultSize 1000 -ErrorAction Stop
            Write-Log "メッセージトレース取得完了: $($messageTrace.Count)件" -Level "Info"
        }
        catch {
            Write-Log "メッセージトレース取得エラー: $($_.Exception.Message)" -Level "Warning"
            Write-Log "より短い期間で再試行します..." -Level "Info"
            
            # さらに短期間で再試行
            try {
                $shortStartDate = (Get-Date).AddDays(-3).Date
                $shortEndDate = (Get-Date).Date
                $messageTrace = Get-MessageTrace -StartDate $shortStartDate -EndDate $shortEndDate -PageSize 500 -ResultSize 500 -ErrorAction Stop
                Write-Log "短期間メッセージトレース取得完了: $($messageTrace.Count)件" -Level "Info"
            }
            catch {
                Write-Log "短期間メッセージトレース取得エラー: $($_.Exception.Message)" -Level "Error"
                $messageTrace = @()
            }
        }
        
        if ($messageTrace.Count -eq 0) {
            Write-Log "添付ファイル分析は制限されたデータで実行されます（Exchange Online制限）" -Level "Warning"
            Write-Log "Microsoft Graph APIによる詳細分析を試行中..." -Level "Info"
            Write-Log "DEBUG: ExchangeManagement.psm1 バージョン 2.1 - Graph API統合版が実行中" -Level "Info"
            
            # Microsoft Graph APIによる詳細添付ファイル分析
            try {
                # Graph APIの接続確認
                $graphContext = Get-MgContext -ErrorAction SilentlyContinue
                Write-Log "Graph APIコンテキスト確認: $(if ($graphContext) { '接続済み' } else { '未接続' })" -Level "Info"
                
                if ($graphContext) {
                    Write-Log "Microsoft Graph API接続確認済み。詳細添付ファイル分析を実行します" -Level "Info"
                    Write-Log "Graph APIテナント: $($graphContext.TenantId)" -Level "Info"
                    Write-Log "Graph APIスコープ: $($graphContext.Scopes -join ', ')" -Level "Info"
                    
                    # ユーザー一覧取得（制限付き）
                    $users = Get-MgUser -Top 20 -ErrorAction SilentlyContinue
                    $attachmentAnalysis = @()
                    $totalMessages = 0
                    $attachmentMessages = 0
                    $largeAttachments = 0
                    $uniqueSenders = 0
                    
                    foreach ($user in $users) {
                        try {
                            # 添付ファイル付きメッセージを取得
                            $filter = "hasAttachments eq true"
                            if ($adjustedDays -gt 0) {
                                $graphStartDate = (Get-Date).AddDays(-$adjustedDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
                                $filter += " and receivedDateTime ge $graphStartDate"
                            }
                            
                            $messages = Get-MgUserMessage -UserId $user.UserPrincipalName -Filter $filter -Top 50 -ErrorAction SilentlyContinue
                            $totalMessages += $messages.Count
                            
                            foreach ($message in $messages) {
                                try {
                                    # 各メッセージの添付ファイル詳細を取得
                                    $attachments = Get-MgUserMessageAttachment -UserId $user.UserPrincipalName -MessageId $message.Id -ErrorAction SilentlyContinue
                                    
                                    if ($attachments.Count -gt 0) {
                                        $attachmentMessages++
                                    }
                                    
                                    foreach ($attachment in $attachments) {
                                        $sizeBytes = if ($attachment.Size) { $attachment.Size } else { 0 }
                                        $sizeMB = [math]::Round($sizeBytes / 1048576, 2)
                                        $isLargeAttachment = $sizeMB -gt $SizeThresholdMB
                                        
                                        if ($isLargeAttachment) {
                                            $largeAttachments++
                                        }
                                        
                                        $attachmentAnalysis += [PSCustomObject]@{
                                            Timestamp = $message.ReceivedDateTime
                                            SenderAddress = if ($message.From.EmailAddress.Address) { $message.From.EmailAddress.Address } else { "不明" }
                                            RecipientAddress = $user.UserPrincipalName
                                            Subject = $message.Subject
                                            MessageSize = $sizeMB
                                            HasAttachment = $true
                                            AttachmentType = if ($attachment.ContentType) { $attachment.ContentType } else { "不明" }
                                            AttachmentName = if ($attachment.Name) { $attachment.Name } else { "名前なし" }
                                            IsLargeAttachment = $isLargeAttachment
                                            RiskLevel = if ($sizeMB -gt ($SizeThresholdMB * 2)) { "高" } elseif ($sizeMB -gt $SizeThresholdMB) { "中" } elseif ($sizeMB -gt 1) { "低" } else { "最小" }
                                            AnalysisSource = "MicrosoftGraphAPI"
                                            AttachmentId = $attachment.Id
                                            IsInline = if ($attachment.IsInline -ne $null) { $attachment.IsInline } else { $false }
                                            ContentId = if ($attachment.ContentId) { $attachment.ContentId } else { "" }
                                        }
                                    }
                                }
                                catch {
                                    Write-Log "添付ファイル詳細取得エラー (Message: $($message.Id)): $($_.Exception.Message)" -Level "Debug"
                                }
                            }
                        }
                        catch {
                            Write-Log "ユーザーメッセージ取得エラー ($($user.UserPrincipalName)): $($_.Exception.Message)" -Level "Debug"
                        }
                    }
                    
                    $uniqueSenders = ($attachmentAnalysis | Group-Object SenderAddress).Count
                    Write-Log "Microsoft Graph API分析完了: $($attachmentAnalysis.Count)件の添付ファイル検出" -Level "Info"
                }
                else {
                    Write-Log "Microsoft Graph API未接続。接続を試行します..." -Level "Warning"
                    
                    # Graph API接続を試行
                    try {
                        if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                            Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                        }
                        
                        $config = Initialize-ManagementTools
                        if ($config) {
                            $connectResult = Connect-MicrosoftGraphService -Config $config
                            if ($connectResult) {
                                Write-Log "Microsoft Graph API接続成功。詳細分析を実行します" -Level "Info"
                                $graphContext = Get-MgContext -ErrorAction SilentlyContinue
                            }
                        }
                    }
                    catch {
                        Write-Log "Microsoft Graph API接続試行失敗: $($_.Exception.Message)" -Level "Warning"
                    }
                    
                    if (-not $graphContext) {
                        Write-Log "Microsoft Graph API未接続。メールボックス統計による補完分析を実行中..." -Level "Warning"
                    
                    # フォールバック: メールボックス統計による補完分析
                    $mailboxes = Get-Mailbox -ResultSize 50
                    $alternativeData = @()
                    
                    foreach ($mailbox in $mailboxes) {
                        try {
                            $stats = Get-MailboxStatistics -Identity $mailbox.Identity -ErrorAction SilentlyContinue
                            if ($stats) {
                                $alternativeData += [PSCustomObject]@{
                                    Mailbox = $mailbox.UserPrincipalName
                                    TotalItemSize = $stats.TotalItemSize
                                    ItemCount = $stats.ItemCount
                                    EstimatedAttachmentSize = if ($stats.TotalItemSize -match "(\d+(?:\.\d+)?)\s*(KB|MB|GB)") {
                                        $value = [double]$matches[1]
                                        $unit = $matches[2]
                                        switch ($unit) {
                                            "KB" { $value / 1024 }
                                            "MB" { $value }
                                            "GB" { $value * 1024 }
                                            default { 0 }
                                        }
                                    } else { 0 }
                                }
                            }
                        }
                        catch {
                            Write-Log "メールボックス統計取得エラー ($($mailbox.Identity)): $($_.Exception.Message)" -Level "Debug"
                        }
                    }
                    
                    # 代替データからレポート生成
                    $attachmentAnalysis = @()
                    $totalMessages = $alternativeData.Count
                    $attachmentMessages = 0
                    $largeAttachments = 0
                    $uniqueSenders = $alternativeData.Count
                    
                    foreach ($data in $alternativeData) {
                        if ($data.EstimatedAttachmentSize -gt 0) {
                            $attachmentMessages++
                        }
                        if ($data.EstimatedAttachmentSize -gt $SizeThresholdMB) {
                            $largeAttachments++
                        }
                        
                        $attachmentAnalysis += [PSCustomObject]@{
                            Timestamp = Get-Date
                            SenderAddress = $data.Mailbox
                            RecipientAddress = "不明（統計ベース）"
                            Subject = "統計ベース分析"
                            MessageSize = $data.EstimatedAttachmentSize
                            HasAttachment = $data.EstimatedAttachmentSize -gt 0
                            AttachmentType = "不明"
                            AttachmentName = "統計ベース"
                            IsLargeAttachment = $data.EstimatedAttachmentSize -gt $SizeThresholdMB
                            RiskLevel = if ($data.EstimatedAttachmentSize -gt ($SizeThresholdMB * 2)) { "高" } elseif ($data.EstimatedAttachmentSize -gt $SizeThresholdMB) { "中" } else { "低" }
                            AnalysisSource = "MailboxStatistics"
                        }
                    }
                }
            }
            catch {
                Write-Log "Graph API/メールボックス統計による補完分析エラー: $($_.Exception.Message)" -Level "Error"
                $attachmentAnalysis = @()
                $totalMessages = 0
                $attachmentMessages = 0
                $largeAttachments = 0
                $uniqueSenders = 0
            }
        }
        else {
            # 通常のメッセージトレース分析
            $attachmentAnalysis = @()
            $sizeThresholdBytes = $SizeThresholdMB * 1024 * 1024
            
            foreach ($message in $messageTrace) {
                $hasAttachment = $message.Size -gt 50000  # 50KB以上を添付ファイルありと推定
                $isLargeAttachment = $message.Size -gt $sizeThresholdBytes
                
                $attachmentAnalysis += [PSCustomObject]@{
                    Timestamp = $message.Received
                    SenderAddress = $message.SenderAddress
                    RecipientAddress = $message.RecipientAddress
                    Subject = $message.Subject
                    MessageSize = [math]::Round($message.Size / 1024 / 1024, 2)  # MB単位
                    HasAttachment = $hasAttachment
                    AttachmentType = "不明（E3制限）"
                    AttachmentName = "詳細不明"
                    IsLargeAttachment = $isLargeAttachment
                    RiskLevel = if ($isLargeAttachment) { "中" } elseif ($hasAttachment) { "低" } else { "なし" }
                    AnalysisSource = "MessageTrace"
                }
            }
            
            $totalMessages = $messageTrace.Count
            $attachmentMessages = ($attachmentAnalysis | Where-Object { $_.HasAttachment }).Count
            $largeAttachments = ($attachmentAnalysis | Where-Object { $_.IsLargeAttachment }).Count
            $uniqueSenders = ($attachmentAnalysis | Group-Object SenderAddress).Count
        }
        
        Write-Log "添付ファイル分析完了" -Level "Info"
        Write-Log "総メッセージ数: $totalMessages" -Level "Info"
        Write-Log "添付ファイル付き: $attachmentMessages" -Level "Info"
        Write-Log "大容量添付ファイル: $largeAttachments" -Level "Info"
        Write-Log "送信者数: $uniqueSenders" -Level "Info"
        
        # レポート出力
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $reportData = @{
            AnalysisData = $attachmentAnalysis
            Summary = @{
                TotalMessages = $totalMessages
                AttachmentMessages = $attachmentMessages
                LargeAttachments = $largeAttachments
                UniqueSenders = $uniqueSenders
                AnalysisPeriod = "$adjustedDays days"
                SizeThreshold = "${SizeThresholdMB}MB"
                Limitations = "Exchange Online E3制限により、詳細な添付ファイル情報は制限されています"
            }
        }
        
        # CSV出力
        if ($ExportCSV -or -not $OutputPath) {
            $csvPath = if ($OutputPath) { 
                Join-Path $OutputPath "Attachment_Analysis_$timestamp.csv" 
            } else { 
                "Reports\Daily\Attachment_Analysis_$timestamp.csv" 
            }
            
            $attachmentAnalysis | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Log "CSVレポート出力完了: $csvPath" -Level "Info"
            $reportData.CSVPath = $csvPath
        }
        
        # HTML出力
        if ($ExportHTML -or -not $OutputPath) {
            $htmlPath = if ($OutputPath) { 
                Join-Path $OutputPath "Attachment_Analysis_$timestamp.html" 
            } else { 
                "Reports\Daily\Attachment_Analysis_$timestamp.html" 
            }
            
            $htmlContent = Generate-AttachmentAnalysisHTML -Data $attachmentAnalysis -Summary $reportData.Summary
            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
            Write-Log "HTMLレポート出力完了: $htmlPath" -Level "Info"
            $reportData.HTMLPath = $htmlPath
        }
        
        return @{
            Success = $true
            TotalMessages = $totalMessages
            AttachmentMessages = $attachmentMessages
            LargeAttachments = $largeAttachments
            UniqueSenders = $uniqueSenders
            OutputPath = $reportData.CSVPath
            HTMLOutputPath = $reportData.HTMLPath
            Data = $attachmentAnalysis
            Summary = $reportData.Summary
        }
    }
    catch {
        Write-Log "添付ファイル分析エラー: $($_.Exception.Message)" -Level "Error"
        return @{
            Success = $false
            Error = $_.Exception.Message
            TotalMessages = 0
            AttachmentMessages = 0
            LargeAttachments = 0
            UniqueSenders = 0
        }
    }
}

# HTMLレポート生成ヘルパー関数
function Generate-AttachmentAnalysisHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>添付ファイル送信履歴分析レポート</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #0078D4; color: white; padding: 15px; border-radius: 5px; }
        .summary { background-color: #F3F9FF; padding: 15px; margin: 15px 0; border-radius: 5px; }
        .limitation { background-color: #FFF8DC; padding: 10px; margin: 10px 0; border-left: 4px solid #FFD700; }
        table { border-collapse: collapse; width: 100%; margin-top: 15px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #0078D4; color: white; }
        .risk-high { background-color: #FFEBEE; }
        .risk-medium { background-color: #FFF8E1; }
        .risk-low { background-color: #E8F5E8; }
    </style>
</head>
<body>
    <div class="header">
        <h1>添付ファイル送信履歴分析レポート</h1>
        <p>生成日時: $(Get-Date -Format "yyyy年MM月dd日 HH:mm:ss")</p>
    </div>
    
    <div class="limitation">
        <strong>⚠️ 制限事項:</strong> $($Summary.Limitations)
    </div>
    
    <div class="summary">
        <h2>分析サマリー</h2>
        <ul>
            <li><strong>分析期間:</strong> $($Summary.AnalysisPeriod)</li>
            <li><strong>大容量閾値:</strong> $($Summary.SizeThreshold)</li>
            <li><strong>総メッセージ数:</strong> $($Summary.TotalMessages)件</li>
            <li><strong>添付ファイル付き:</strong> $($Summary.AttachmentMessages)件</li>
            <li><strong>大容量添付:</strong> $($Summary.LargeAttachments)件</li>
            <li><strong>送信者数:</strong> $($Summary.UniqueSenders)名</li>
        </ul>
    </div>
    
    <h2>詳細データ</h2>
    <table>
        <tr>
            <th>日時</th>
            <th>送信者</th>
            <th>受信者</th>
            <th>件名</th>
            <th>サイズ(MB)</th>
            <th>添付あり</th>
            <th>大容量</th>
            <th>リスクレベル</th>
            <th>分析ソース</th>
        </tr>
"@
    
    foreach ($item in $Data) {
        $riskClass = switch ($item.RiskLevel) {
            "高" { "risk-high" }
            "中" { "risk-medium" }
            "低" { "risk-low" }
            default { "" }
        }
        
        $htmlContent += @"
        <tr class="$riskClass">
            <td>$($item.Timestamp)</td>
            <td>$($item.SenderAddress)</td>
            <td>$($item.RecipientAddress)</td>
            <td>$($item.Subject)</td>
            <td>$($item.MessageSize)</td>
            <td>$(if ($item.HasAttachment) { "はい" } else { "いいえ" })</td>
            <td>$(if ($item.IsLargeAttachment) { "はい" } else { "いいえ" })</td>
            <td>$($item.RiskLevel)</td>
            <td>$($item.AnalysisSource)</td>
        </tr>
"@
    }
    
    $htmlContent += @"
    </table>
</body>
</html>
"@
    
    return $htmlContent
}

# EX-01: メールボックス容量・上限監視
function Get-MailboxQuotaMonitoring {
    param(
        [Parameter(Mandatory = $false)]
        [int]$WarningThreshold = 80,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false
    )
    
    Write-Log "メールボックス容量・上限監視を開始します (警告閾値: ${WarningThreshold}%)" -Level "Info"
    
    try {
        # Exchange Online接続確認と自動接続
        try {
            Get-Mailbox -ResultSize 1 -ErrorAction Stop | Out-Null
            Write-Log "Exchange Online 接続確認完了" -Level "Info"
        }
        catch {
            Write-Log "Exchange Online に接続されていません。自動接続を試行します..." -Level "Warning"
            
            try {
                if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                }
                
                $config = Initialize-ManagementTools
                if (-not $config) {
                    throw "設定ファイルの読み込みに失敗しました"
                }
                
                Write-Log "Exchange Online への自動接続を開始します" -Level "Info"
                $connectResult = Connect-ExchangeOnlineService -Config $config
                
                if ($connectResult) {
                    Write-Log "Exchange Online 自動接続成功" -Level "Info"
                }
                else {
                    throw "Exchange Online への自動接続に失敗しました"
                }
            }
            catch {
                throw "Exchange Online 接続エラー: $($_.Exception.Message). 先にメニュー選択2で認証テストを実行してください。"
            }
        }
        
        # 全メールボックスの取得
        Write-Log "メールボックス一覧を取得中..." -Level "Info"
        
        try {
            $allMailboxes = Get-Mailbox -ResultSize Unlimited
            Write-Log "メールボックス情報取得完了" -Level "Info"
        }
        catch {
            Write-Log "メールボックス取得エラー: $($_.Exception.Message)" -Level "Error"
            throw $_
        }
        
        Write-Log "取得完了: $($allMailboxes.Count)個のメールボックス" -Level "Info"
        
        # メールボックス容量分析
        $quotaResults = @()
        $progressCount = 0
        
        foreach ($mailbox in $allMailboxes) {
            $progressCount++
            if ($progressCount % 10 -eq 0) {
                Write-Progress -Activity "メールボックス容量確認中" -Status "$progressCount/$($allMailboxes.Count)" -PercentComplete (($progressCount / $allMailboxes.Count) * 100)
            }
            
            try {
                # メールボックス統計の取得
                $mailboxStats = Get-MailboxStatistics -Identity $mailbox.Identity -ErrorAction SilentlyContinue
                
                if ($mailboxStats) {
                    # 容量情報の解析
                    $totalItemSize = $mailboxStats.TotalItemSize
                    $quotaLimit = $mailbox.ProhibitSendQuota
                    $warningQuota = $mailbox.IssueWarningQuota
                    
                    # サイズを MB に変換
                    $currentSizeMB = 0
                    $quotaLimitMB = 0
                    $warningQuotaMB = 0
                    $usagePercentage = 0
                    
                    if ($totalItemSize -and $totalItemSize.ToString() -ne "Unlimited") {
                        $sizeString = $totalItemSize.ToString()
                        if ($sizeString -match "([\d,\.]+)\s*([KMGT]?B)") {
                            $sizeValue = [double]($matches[1] -replace ",", "")
                            $sizeUnit = $matches[2]
                            
                            switch ($sizeUnit) {
                                "KB" { $currentSizeMB = $sizeValue / 1024 }
                                "MB" { $currentSizeMB = $sizeValue }
                                "GB" { $currentSizeMB = $sizeValue * 1024 }
                                "TB" { $currentSizeMB = $sizeValue * 1024 * 1024 }
                                default { $currentSizeMB = $sizeValue / (1024 * 1024) }
                            }
                        }
                    }
                    
                    if ($quotaLimit -and $quotaLimit.ToString() -ne "Unlimited") {
                        $quotaString = $quotaLimit.ToString()
                        if ($quotaString -match "([\d,\.]+)\s*([KMGT]?B)") {
                            $quotaValue = [double]($matches[1] -replace ",", "")
                            $quotaUnit = $matches[2]
                            
                            switch ($quotaUnit) {
                                "KB" { $quotaLimitMB = $quotaValue / 1024 }
                                "MB" { $quotaLimitMB = $quotaValue }
                                "GB" { $quotaLimitMB = $quotaValue * 1024 }
                                "TB" { $quotaLimitMB = $quotaValue * 1024 * 1024 }
                                default { $quotaLimitMB = $quotaValue / (1024 * 1024) }
                            }
                        }
                    }
                    
                    if ($warningQuota -and $warningQuota.ToString() -ne "Unlimited") {
                        $warningString = $warningQuota.ToString()
                        if ($warningString -match "([\d,\.]+)\s*([KMGT]?B)") {
                            $warningValue = [double]($matches[1] -replace ",", "")
                            $warningUnit = $matches[2]
                            
                            switch ($warningUnit) {
                                "KB" { $warningQuotaMB = $warningValue / 1024 }
                                "MB" { $warningQuotaMB = $warningValue }
                                "GB" { $warningQuotaMB = $warningValue * 1024 }
                                "TB" { $warningQuotaMB = $warningValue * 1024 * 1024 }
                                default { $warningQuotaMB = $warningValue / (1024 * 1024) }
                            }
                        }
                    }
                    
                    # 使用率計算
                    if ($quotaLimitMB -gt 0) {
                        $usagePercentage = [math]::Round(($currentSizeMB / $quotaLimitMB) * 100, 2)
                    }
                    
                    # ステータス判定
                    $status = "正常"
                    $riskLevel = "低"
                    
                    if ($quotaLimitMB -eq 0 -or $quotaLimit.ToString() -eq "Unlimited") {
                        $status = "制限なし"
                        $riskLevel = "中"
                    }
                    elseif ($usagePercentage -ge 95) {
                        $status = "緊急"
                        $riskLevel = "高"
                    }
                    elseif ($usagePercentage -ge $WarningThreshold) {
                        $status = "警告"
                        $riskLevel = "中"
                    }
                    
                    # 最終アクセス日時
                    $lastLogonTime = if ($mailboxStats.LastLogonTime) { 
                        $mailboxStats.LastLogonTime.ToString("yyyy/MM/dd HH:mm") 
                    } else { 
                        "不明" 
                    }
                    
                    # アイテム数
                    $itemCount = if ($mailboxStats.ItemCount) { $mailboxStats.ItemCount } else { 0 }
                    
                    # 結果オブジェクト作成
                    $result = [PSCustomObject]@{
                        DisplayName = $mailbox.DisplayName
                        UserPrincipalName = $mailbox.UserPrincipalName
                        MailboxType = $mailbox.RecipientTypeDetails
                        CurrentSizeMB = [math]::Round($currentSizeMB, 2)
                        QuotaLimitMB = [math]::Round($quotaLimitMB, 2)
                        WarningQuotaMB = [math]::Round($warningQuotaMB, 2)
                        UsagePercentage = $usagePercentage
                        Status = $status
                        RiskLevel = $riskLevel
                        ItemCount = $itemCount
                        LastLogonTime = $lastLogonTime
                        MailboxEnabled = $mailbox.ExchangeObjectId -ne $null
                        Database = $mailboxStats.Database
                        ArchiveEnabled = $mailbox.ArchiveStatus -eq "Active"
                        LitigationHoldEnabled = $mailbox.LitigationHoldEnabled
                        CreatedDate = if ($mailbox.WhenCreated) { $mailbox.WhenCreated.ToString("yyyy/MM/dd") } else { "不明" }
                        MailboxId = $mailbox.ExchangeObjectId
                    }
                    
                    $quotaResults += $result
                }
                else {
                    # 統計情報が取得できない場合
                    $result = [PSCustomObject]@{
                        DisplayName = $mailbox.DisplayName
                        UserPrincipalName = $mailbox.UserPrincipalName
                        MailboxType = $mailbox.RecipientTypeDetails
                        CurrentSizeMB = 0
                        QuotaLimitMB = 0
                        WarningQuotaMB = 0
                        UsagePercentage = 0
                        Status = "統計取得エラー"
                        RiskLevel = "要確認"
                        ItemCount = 0
                        LastLogonTime = "不明"
                        MailboxEnabled = $mailbox.ExchangeObjectId -ne $null
                        Database = "不明"
                        ArchiveEnabled = $mailbox.ArchiveStatus -eq "Active"
                        LitigationHoldEnabled = $mailbox.LitigationHoldEnabled
                        CreatedDate = if ($mailbox.WhenCreated) { $mailbox.WhenCreated.ToString("yyyy/MM/dd") } else { "不明" }
                        MailboxId = $mailbox.ExchangeObjectId
                    }
                    
                    $quotaResults += $result
                }
                
            }
            catch {
                Write-Log "メールボックス $($mailbox.DisplayName) の容量確認エラー: $($_.Exception.Message)" -Level "Warning"
                
                # エラー時も基本情報は記録
                $result = [PSCustomObject]@{
                    DisplayName = $mailbox.DisplayName
                    UserPrincipalName = $mailbox.UserPrincipalName
                    MailboxType = $mailbox.RecipientTypeDetails
                    CurrentSizeMB = 0
                    QuotaLimitMB = 0
                    WarningQuotaMB = 0
                    UsagePercentage = 0
                    Status = "確認エラー"
                    RiskLevel = "要確認"
                    ItemCount = 0
                    LastLogonTime = "確認エラー"
                    MailboxEnabled = $false
                    Database = "確認エラー"
                    ArchiveEnabled = $false
                    LitigationHoldEnabled = $false
                    CreatedDate = "確認エラー"
                    MailboxId = $mailbox.ExchangeObjectId
                }
                
                $quotaResults += $result
            }
        }
        
        Write-Progress -Activity "メールボックス容量確認中" -Completed
        
        # 結果集計
        $totalMailboxes = $quotaResults.Count
        $urgentMailboxes = ($quotaResults | Where-Object { $_.Status -eq "緊急" }).Count
        $warningMailboxes = ($quotaResults | Where-Object { $_.Status -eq "警告" }).Count
        $unlimitedMailboxes = ($quotaResults | Where-Object { $_.Status -eq "制限なし" }).Count
        $normalMailboxes = ($quotaResults | Where-Object { $_.Status -eq "正常" }).Count
        $archiveEnabledCount = ($quotaResults | Where-Object { $_.ArchiveEnabled -eq $true }).Count
        $litigationHoldCount = ($quotaResults | Where-Object { $_.LitigationHoldEnabled -eq $true }).Count
        
        # 平均使用率
        $avgUsage = if ($totalMailboxes -gt 0) {
            [math]::Round(($quotaResults | Where-Object { $_.UsagePercentage -gt 0 } | Measure-Object -Property UsagePercentage -Average).Average, 2)
        } else { 0 }
        
        Write-Log "メールボックス容量監視完了" -Level "Info"
        Write-Log "総メールボックス数: $totalMailboxes" -Level "Info"
        Write-Log "緊急対応: $urgentMailboxes" -Level "Info"
        Write-Log "警告対象: $warningMailboxes" -Level "Info"
        Write-Log "制限なし: $unlimitedMailboxes" -Level "Info"
        Write-Log "正常: $normalMailboxes" -Level "Info"
        Write-Log "平均使用率: ${avgUsage}%" -Level "Info"
        
        # 詳細表示
        if ($ShowDetails) {
            Write-Host "`n=== メールボックス容量監視結果 ===`n" -ForegroundColor Yellow
            
            # 緊急対応メールボックス
            $urgentList = $quotaResults | Where-Object { $_.Status -eq "緊急" } | Sort-Object UsagePercentage -Descending
            if ($urgentList.Count -gt 0) {
                Write-Host "【緊急対応（95%以上）】" -ForegroundColor Red
                foreach ($mailbox in $urgentList) {
                    Write-Host "  ● $($mailbox.DisplayName) ($($mailbox.UserPrincipalName))" -ForegroundColor Red
                    Write-Host "    使用率: $($mailbox.UsagePercentage)% ($($mailbox.CurrentSizeMB)MB / $($mailbox.QuotaLimitMB)MB)" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # 警告対象メールボックス
            $warningList = $quotaResults | Where-Object { $_.Status -eq "警告" } | Sort-Object UsagePercentage -Descending
            if ($warningList.Count -gt 0) {
                Write-Host "【警告対象（$WarningThreshold% 以上）】" -ForegroundColor Yellow
                foreach ($mailbox in $warningList) {
                    Write-Host "  ⚠ $($mailbox.DisplayName) ($($mailbox.UserPrincipalName))" -ForegroundColor Yellow
                    Write-Host "    使用率: $($mailbox.UsagePercentage)% ($($mailbox.CurrentSizeMB)MB / $($mailbox.QuotaLimitMB)MB)" -ForegroundColor Gray
                }
            }
        }
        
        # CSV出力
        if ($ExportCSV) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputPath = "Reports\Daily\Mailbox_Quota_Monitoring_$timestamp.csv"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $OutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # CSV出力（BOM付きUTF-8）
            if ($quotaResults -and $quotaResults.Count -gt 0) {
                if ($IsWindows -or $env:OS -eq "Windows_NT") {
                    $csvContent = $quotaResults | ConvertTo-Csv -NoTypeInformation
                    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
                    [System.IO.File]::WriteAllLines($OutputPath, $csvContent, $utf8WithBom)
                }
                else {
                    $quotaResults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
            }
            
            Write-Log "CSVレポート出力完了: $OutputPath" -Level "Info"
        }
        
        # HTMLレポート出力
        $htmlOutputPath = ""
        if ($ExportHTML) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $htmlOutputPath = "Reports\Daily\Mailbox_Quota_Monitoring_$timestamp.html"
            }
            else {
                $htmlOutputPath = $OutputPath -replace "\.csv$", ".html"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $htmlOutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # HTML生成
            $htmlContent = Generate-MailboxQuotaReportHTML -QuotaResults $quotaResults -Summary @{
                TotalMailboxes = $totalMailboxes
                UrgentMailboxes = $urgentMailboxes
                WarningMailboxes = $warningMailboxes
                UnlimitedMailboxes = $unlimitedMailboxes
                NormalMailboxes = $normalMailboxes
                ArchiveEnabledCount = $archiveEnabledCount
                LitigationHoldCount = $litigationHoldCount
                AverageUsage = $avgUsage
                WarningThreshold = $WarningThreshold
                ReportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
            }
            
            # UTF-8 BOM付きで出力
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($htmlOutputPath, $htmlContent, $utf8WithBom)
            
            Write-Log "HTMLレポート出力完了: $htmlOutputPath" -Level "Info"
        }
        
        # 結果返却
        return @{
            Success = $true
            TotalMailboxes = $totalMailboxes
            UrgentMailboxes = $urgentMailboxes
            WarningMailboxes = $warningMailboxes
            UnlimitedMailboxes = $unlimitedMailboxes
            NormalMailboxes = $normalMailboxes
            ArchiveEnabledCount = $archiveEnabledCount
            LitigationHoldCount = $litigationHoldCount
            AverageUsage = $avgUsage
            WarningThreshold = $WarningThreshold
            DetailedResults = $quotaResults
            OutputPath = $OutputPath
            HTMLOutputPath = $htmlOutputPath
        }
        
    }
    catch {
        Write-Log "メールボックス容量・上限監視エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}


# メールボックス容量監視 HTMLレポート生成関数
function Generate-MailboxQuotaReportHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$QuotaResults,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    # 各カテゴリ別にメールボックスを抽出
    $urgentMailboxes = $QuotaResults | Where-Object { $_.Status -eq "緊急" } | Sort-Object UsagePercentage -Descending
    $warningMailboxes = $QuotaResults | Where-Object { $_.Status -eq "警告" } | Sort-Object UsagePercentage -Descending
    $largeMailboxes = $QuotaResults | Where-Object { $_.CurrentSizeMB -gt 1000 } | Sort-Object CurrentSizeMB -Descending
    $archiveMailboxes = $QuotaResults | Where-Object { $_.ArchiveEnabled -eq $true } | Sort-Object DisplayName
    
    $htmlTemplate = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>メールボックス容量監視レポート - みらい建設工業株式会社</title>
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
            grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); 
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
        .section { 
            background: white; 
            margin-bottom: 20px; 
            border-radius: 8px; 
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-header { 
            background: #f8f9fa; 
            padding: 15px 20px; 
            border-bottom: 1px solid #dee2e6; 
        }
        .section-header h2 { margin: 0; color: #495057; font-size: 18px; }
        .section-content { padding: 20px; }
        .table-container { overflow-x: auto; }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            margin-top: 10px; 
        }
        th, td { 
            padding: 12px; 
            text-align: left; 
            border-bottom: 1px solid #dee2e6; 
            font-size: 14px;
        }
        th { 
            background: #f8f9fa; 
            font-weight: 600; 
            color: #495057; 
        }
        .status-urgent { color: #d13438; font-weight: bold; }
        .status-warning { color: #ff8c00; font-weight: bold; }
        .status-normal { color: #107c10; }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        @media print {
            body { background-color: white; }
            .summary-grid { grid-template-columns: repeat(8, 1fr); }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>📫 メールボックス容量監視レポート</h1>
        <div class="subtitle">みらい建設工業株式会社 - Exchange Online</div>
        <div class="subtitle">レポート生成日時: $($Summary.ReportDate)</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>総メールボックス数</h3>
            <div class="value">$($Summary.TotalMailboxes)</div>
            <div class="description">全メールボックス</div>
        </div>
        <div class="summary-card">
            <h3>緊急対応</h3>
            <div class="value danger">$($Summary.UrgentMailboxes)</div>
            <div class="description">95%以上</div>
        </div>
        <div class="summary-card">
            <h3>警告対象</h3>
            <div class="value warning">$($Summary.WarningMailboxes)</div>
            <div class="description">${($Summary.WarningThreshold)}%以上</div>
        </div>
        <div class="summary-card">
            <h3>正常</h3>
            <div class="value success">$($Summary.NormalMailboxes)</div>
            <div class="description">正常範囲</div>
        </div>
        <div class="summary-card">
            <h3>制限なし</h3>
            <div class="value">$($Summary.UnlimitedMailboxes)</div>
            <div class="description">容量制限なし</div>
        </div>
        <div class="summary-card">
            <h3>アーカイブ有効</h3>
            <div class="value">$($Summary.ArchiveEnabledCount)</div>
            <div class="description">アーカイブ機能</div>
        </div>
        <div class="summary-card">
            <h3>訴訟ホールド</h3>
            <div class="value">$($Summary.LitigationHoldCount)</div>
            <div class="description">法的保持</div>
        </div>
        <div class="summary-card">
            <h3>平均使用率</h3>
            <div class="value">$($Summary.AverageUsage)%</div>
            <div class="description">全体平均</div>
        </div>
    </div>
"@

    # 緊急対応メールボックス一覧
    if ($urgentMailboxes.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>🚨 緊急対応メールボックス (95%以上)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>使用率</th>
                            <th>現在サイズ</th>
                            <th>制限値</th>
                            <th>最終ログオン</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($mailbox in $urgentMailboxes) {
            $htmlTemplate += @"
                        <tr>
                            <td>$($mailbox.DisplayName)</td>
                            <td>$($mailbox.UserPrincipalName)</td>
                            <td class="status-urgent">$($mailbox.UsagePercentage)%</td>
                            <td>$($mailbox.CurrentSizeMB) MB</td>
                            <td>$($mailbox.QuotaLimitMB) MB</td>
                            <td>$($mailbox.LastLogonTime)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 警告対象メールボックス一覧
    if ($warningMailboxes.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>⚠️ 警告対象メールボックス ($($Summary.WarningThreshold)%以上)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>使用率</th>
                            <th>現在サイズ</th>
                            <th>制限値</th>
                            <th>最終ログオン</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($mailbox in $warningMailboxes) {
            $htmlTemplate += @"
                        <tr>
                            <td>$($mailbox.DisplayName)</td>
                            <td>$($mailbox.UserPrincipalName)</td>
                            <td class="status-warning">$($mailbox.UsagePercentage)%</td>
                            <td>$($mailbox.CurrentSizeMB) MB</td>
                            <td>$($mailbox.QuotaLimitMB) MB</td>
                            <td>$($mailbox.LastLogonTime)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 上位使用率メールボックス一覧（問題がない場合でも表示）
    $topUsageMailboxes = $QuotaResults | Where-Object { $_.UsagePercentage -gt 0 } | Sort-Object UsagePercentage -Descending | Select-Object -First 20
    if ($topUsageMailboxes.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>📊 上位使用率メールボックス (TOP 20)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>メールボックス種別</th>
                            <th>使用率</th>
                            <th>現在サイズ</th>
                            <th>制限値</th>
                            <th>最終ログオン</th>
                            <th>アーカイブ</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($mailbox in $topUsageMailboxes) {
            $statusClass = if ($mailbox.Status -eq "緊急") { "status-urgent" } 
                          elseif ($mailbox.Status -eq "警告") { "status-warning" } 
                          else { "status-normal" }
            $archiveStatus = if ($mailbox.ArchiveEnabled) { "有効" } else { "無効" }
            
            $htmlTemplate += @"
                        <tr>
                            <td>$($mailbox.DisplayName)</td>
                            <td>$($mailbox.UserPrincipalName)</td>
                            <td>$($mailbox.MailboxType)</td>
                            <td class="$statusClass">$($mailbox.UsagePercentage)%</td>
                            <td>$($mailbox.CurrentSizeMB) MB</td>
                            <td>$($mailbox.QuotaLimitMB) MB</td>
                            <td>$($mailbox.LastLogonTime)</td>
                            <td>$archiveStatus</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 大容量メールボックス一覧
    $largeMailboxes = $QuotaResults | Where-Object { $_.CurrentSizeMB -gt 1000 } | Sort-Object CurrentSizeMB -Descending | Select-Object -First 15
    if ($largeMailboxes.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>💾 大容量メールボックス (1GB以上)</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>現在サイズ</th>
                            <th>使用率</th>
                            <th>アイテム数</th>
                            <th>最終ログオン</th>
                            <th>アーカイブ</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($mailbox in $largeMailboxes) {
            $archiveStatus = if ($mailbox.ArchiveEnabled) { "有効" } else { "無効" }
            $sizeGB = [math]::Round($mailbox.CurrentSizeMB / 1024, 2)
            
            $htmlTemplate += @"
                        <tr>
                            <td>$($mailbox.DisplayName)</td>
                            <td>$($mailbox.UserPrincipalName)</td>
                            <td>${sizeGB} GB</td>
                            <td>$($mailbox.UsagePercentage)%</td>
                            <td>$($mailbox.ItemCount)</td>
                            <td>$($mailbox.LastLogonTime)</td>
                            <td>$archiveStatus</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    $htmlTemplate += @"
    <div class="footer">
        <p>このレポートは Microsoft 365 統合管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $htmlTemplate
}

# 添付ファイル分析 HTMLレポート生成関数
function Generate-AttachmentAnalysisReportHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$AttachmentResults,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    $htmlTemplate = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>添付ファイル分析レポート - みらい建設工業株式会社</title>
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
        .alert-info {
            background-color: #d1ecf1;
            border: 1px solid #bee5eb;
            color: #0c5460;
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
        }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        @media print {
            body { background-color: white; }
            .summary-grid { grid-template-columns: repeat(6, 1fr); }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>📎 添付ファイル分析レポート</h1>
        <div class="subtitle">みらい建設工業株式会社 - Exchange Online</div>
        <div class="subtitle">分析期間: 過去$($Summary.AnalysisDays)日間</div>
        <div class="subtitle">レポート生成日時: $($Summary.ReportDate)</div>
    </div>

    <div class="alert-info">
        <strong>注意:</strong> このレポートはExchange Online E3ライセンスの制限により、限定的な情報に基づいて生成されています。
        詳細な添付ファイル分析には追加のライセンスまたはツールが必要です。
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>分析メッセージ数</h3>
            <div class="value">$($Summary.TotalMessages)</div>
            <div class="description">過去$($Summary.AnalysisDays)日間</div>
        </div>
        <div class="summary-card">
            <h3>添付ファイル付き</h3>
            <div class="value">$($Summary.AttachmentMessages)</div>
            <div class="description">推定値</div>
        </div>
        <div class="summary-card">
            <h3>大容量添付</h3>
            <div class="value danger">$($Summary.LargeAttachments)</div>
            <div class="description">${($Summary.SizeThresholdMB)}MB以上</div>
        </div>
        <div class="summary-card">
            <h3>送信者数</h3>
            <div class="value">$($Summary.UniqueSenders)</div>
            <div class="description">ユニーク送信者</div>
        </div>
        <div class="summary-card">
            <h3>平均サイズ</h3>
            <div class="value">$($Summary.AverageSizeMB)</div>
            <div class="description">MB (推定)</div>
        </div>
        <div class="summary-card">
            <h3>制限値</h3>
            <div class="value warning">$($Summary.SizeThresholdMB)</div>
            <div class="description">MB 閾値</div>
        </div>
    </div>

    <div class="footer">
        <p>このレポートは Microsoft 365 統合管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $htmlTemplate
}

# EX-03: 自動転送・返信設定の確認
function Get-AutoForwardReplyConfiguration {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false
    )
    
    Write-Log "自動転送・返信設定の確認を開始します" -Level "Info"
    
    try {
        # Exchange Online接続確認と自動接続
        try {
            Get-Mailbox -ResultSize 1 -ErrorAction Stop | Out-Null
            Write-Log "Exchange Online 接続確認完了" -Level "Info"
        }
        catch {
            Write-Log "Exchange Online に接続されていません。自動接続を試行します..." -Level "Warning"
            
            try {
                if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                    Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                }
                
                $config = Initialize-ManagementTools
                if (-not $config) {
                    throw "設定ファイルの読み込みに失敗しました"
                }
                
                Write-Log "Exchange Online への自動接続を開始します" -Level "Info"
                $connectResult = Connect-ExchangeOnlineService -Config $config
                
                if ($connectResult) {
                    Write-Log "Exchange Online 自動接続成功" -Level "Info"
                }
                else {
                    throw "Exchange Online への自動接続に失敗しました"
                }
            }
            catch {
                throw "Exchange Online 接続エラー: $($_.Exception.Message). 先にメニュー選択2で認証テストを実行してください。"
            }
        }
        
        # 全メールボックスの取得
        Write-Log "メールボックス一覧を取得中..." -Level "Info"
        
        try {
            $allMailboxes = Get-Mailbox -ResultSize Unlimited
            Write-Log "メールボックス情報取得完了: $($allMailboxes.Count)個" -Level "Info"
        }
        catch {
            Write-Log "メールボックス取得エラー: $($_.Exception.Message)" -Level "Error"
            throw $_
        }
        
        # 自動転送・返信設定分析
        $autoConfigResults = @()
        $progressCount = 0
        
        foreach ($mailbox in $allMailboxes) {
            $progressCount++
            if ($progressCount % 10 -eq 0) {
                Write-Progress -Activity "自動転送・返信設定確認中" -Status "$progressCount/$($allMailboxes.Count)" -PercentComplete (($progressCount / $allMailboxes.Count) * 100)
            }
            
            try {
                # メールボックス設定の取得
                $mailboxConfig = Get-MailboxMessageConfiguration -Identity $mailbox.Identity -ErrorAction SilentlyContinue
                $inboxRules = Get-InboxRule -Mailbox $mailbox.Identity -ErrorAction SilentlyContinue
                
                # 自動転送設定の確認
                $autoForwardEnabled = $false
                $forwardingAddress = ""
                $forwardingSmtpAddress = ""
                $deliverToMailboxAndForward = $false
                
                if ($mailbox.ForwardingAddress) {
                    $autoForwardEnabled = $true
                    $forwardingAddress = $mailbox.ForwardingAddress
                }
                
                if ($mailbox.ForwardingSmtpAddress) {
                    $autoForwardEnabled = $true
                    $forwardingSmtpAddress = $mailbox.ForwardingSmtpAddress
                }
                
                $deliverToMailboxAndForward = $mailbox.DeliverToMailboxAndForward
                
                # 自動返信設定の確認
                $autoReplyEnabled = $false
                $autoReplyMessage = ""
                $autoReplyState = "Disabled"
                
                if ($mailboxConfig) {
                    $autoReplyState = $mailboxConfig.AutomaticReplies.AutoReplyState
                    if ($autoReplyState -ne "Disabled") {
                        $autoReplyEnabled = $true
                        $autoReplyMessage = $mailboxConfig.AutomaticReplies.InternalMessage
                    }
                }
                
                # 受信トレイルールの確認
                $suspiciousRules = @()
                $ruleCount = 0
                $forwardingRules = 0
                $deleteRules = 0
                
                if ($inboxRules) {
                    $ruleCount = $inboxRules.Count
                    
                    foreach ($rule in $inboxRules) {
                        if ($rule.Enabled) {
                            # 転送ルール
                            if ($rule.ForwardTo -or $rule.ForwardAsAttachmentTo -or $rule.RedirectTo) {
                                $forwardingRules++
                                $suspiciousRules += "転送: $($rule.Name)"
                            }
                            
                            # 削除ルール
                            if ($rule.DeleteMessage -or $rule.MoveToFolder -like "*削除*" -or $rule.MoveToFolder -like "*Delete*") {
                                $deleteRules++
                                $suspiciousRules += "削除: $($rule.Name)"
                            }
                        }
                    }
                }
                
                # リスクレベルの判定
                $riskLevel = "低"
                $riskFactors = @()
                
                if ($autoForwardEnabled) {
                    $riskFactors += "自動転送有効"
                    $riskLevel = "中"
                }
                
                if ($forwardingRules -gt 0) {
                    $riskFactors += "転送ルール存在"
                    $riskLevel = "中"
                }
                
                if ($deleteRules -gt 2) {
                    $riskFactors += "多数の削除ルール"
                    $riskLevel = "中"
                }
                
                if ($forwardingSmtpAddress -and $forwardingSmtpAddress -notlike "*@*$(($mailbox.PrimarySmtpAddress -split '@')[1])*") {
                    $riskFactors += "外部ドメインへの転送"
                    $riskLevel = "高"
                }
                
                if ($riskFactors.Count -gt 2) {
                    $riskLevel = "高"
                }
                
                # ステータス判定
                $status = "正常"
                if ($autoForwardEnabled -or $forwardingRules -gt 0) {
                    $status = "転送設定あり"
                }
                if ($riskLevel -eq "高") {
                    $status = "要確認"
                }
                
                # 結果オブジェクト作成
                $result = [PSCustomObject]@{
                    DisplayName = $mailbox.DisplayName
                    UserPrincipalName = $mailbox.UserPrincipalName
                    MailboxType = $mailbox.RecipientTypeDetails
                    AutoForwardEnabled = $autoForwardEnabled
                    ForwardingAddress = $forwardingAddress
                    ForwardingSmtpAddress = $forwardingSmtpAddress
                    DeliverToMailboxAndForward = $deliverToMailboxAndForward
                    AutoReplyEnabled = $autoReplyEnabled
                    AutoReplyState = $autoReplyState
                    AutoReplyMessage = if ($autoReplyMessage.Length -gt 100) { $autoReplyMessage.Substring(0, 100) + "..." } else { $autoReplyMessage }
                    InboxRuleCount = $ruleCount
                    ForwardingRules = $forwardingRules
                    DeleteRules = $deleteRules
                    SuspiciousRules = ($suspiciousRules -join ", ")
                    RiskLevel = $riskLevel
                    RiskFactors = ($riskFactors -join ", ")
                    Status = $status
                    LastModified = if ($mailbox.WhenChanged) { $mailbox.WhenChanged.ToString("yyyy/MM/dd HH:mm") } else { "不明" }
                    CreatedDate = if ($mailbox.WhenCreated) { $mailbox.WhenCreated.ToString("yyyy/MM/dd") } else { "不明" }
                    MailboxEnabled = $mailbox.ExchangeObjectId -ne $null
                    MailboxId = $mailbox.ExchangeObjectId
                }
                
                $autoConfigResults += $result
                
            }
            catch {
                Write-Log "メールボックス $($mailbox.DisplayName) の設定確認エラー: $($_.Exception.Message)" -Level "Warning"
                
                # エラー時も基本情報は記録
                $result = [PSCustomObject]@{
                    DisplayName = $mailbox.DisplayName
                    UserPrincipalName = $mailbox.UserPrincipalName
                    MailboxType = $mailbox.RecipientTypeDetails
                    AutoForwardEnabled = $false
                    ForwardingAddress = ""
                    ForwardingSmtpAddress = ""
                    DeliverToMailboxAndForward = $false
                    AutoReplyEnabled = $false
                    AutoReplyState = "確認エラー"
                    AutoReplyMessage = ""
                    InboxRuleCount = 0
                    ForwardingRules = 0
                    DeleteRules = 0
                    SuspiciousRules = ""
                    RiskLevel = "要確認"
                    RiskFactors = "設定確認エラー"
                    Status = "確認エラー"
                    LastModified = "確認エラー"
                    CreatedDate = "確認エラー"
                    MailboxEnabled = $false
                    MailboxId = $mailbox.ExchangeObjectId
                }
                
                $autoConfigResults += $result
            }
        }
        
        Write-Progress -Activity "自動転送・返信設定確認中" -Completed
        
        # 結果集計
        $totalMailboxes = $autoConfigResults.Count
        $autoForwardCount = ($autoConfigResults | Where-Object { $_.AutoForwardEnabled }).Count
        $autoReplyCount = ($autoConfigResults | Where-Object { $_.AutoReplyEnabled }).Count
        $highRiskCount = ($autoConfigResults | Where-Object { $_.RiskLevel -eq "高" }).Count
        $mediumRiskCount = ($autoConfigResults | Where-Object { $_.RiskLevel -eq "中" }).Count
        $suspiciousRulesCount = ($autoConfigResults | Where-Object { $_.ForwardingRules -gt 0 -or $_.DeleteRules -gt 2 }).Count
        $externalForwardingCount = ($autoConfigResults | Where-Object { $_.ForwardingSmtpAddress -and $_.ForwardingSmtpAddress -notlike "*@*" }).Count
        
        Write-Log "自動転送・返信設定確認完了" -Level "Info"
        Write-Log "総メールボックス数: $totalMailboxes" -Level "Info"
        Write-Log "自動転送設定: $autoForwardCount" -Level "Info"
        Write-Log "自動返信設定: $autoReplyCount" -Level "Info"
        Write-Log "高リスク: $highRiskCount" -Level "Info"
        Write-Log "中リスク: $mediumRiskCount" -Level "Info"
        Write-Log "疑わしいルール: $suspiciousRulesCount" -Level "Info"
        
        # 詳細表示
        if ($ShowDetails) {
            Write-Host "`n=== 自動転送・返信設定確認結果 ===`n" -ForegroundColor Yellow
            
            # 高リスクメールボックス
            $highRiskList = $autoConfigResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object DisplayName
            if ($highRiskList.Count -gt 0) {
                Write-Host "【高リスク メールボックス】" -ForegroundColor Red
                foreach ($mailbox in $highRiskList) {
                    Write-Host "  ● $($mailbox.DisplayName) ($($mailbox.UserPrincipalName))" -ForegroundColor Red
                    Write-Host "    転送先: $($mailbox.ForwardingSmtpAddress)" -ForegroundColor Gray
                    Write-Host "    リスク要因: $($mailbox.RiskFactors)" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            # 自動転送設定メールボックス
            $autoForwardList = $autoConfigResults | Where-Object { $_.AutoForwardEnabled } | Sort-Object DisplayName
            if ($autoForwardList.Count -gt 0) {
                Write-Host "【自動転送設定メールボックス】" -ForegroundColor Yellow
                foreach ($mailbox in $autoForwardList) {
                    Write-Host "  ⚠ $($mailbox.DisplayName) ($($mailbox.UserPrincipalName))" -ForegroundColor Yellow
                    if ($mailbox.ForwardingAddress) {
                        Write-Host "    内部転送先: $($mailbox.ForwardingAddress)" -ForegroundColor Gray
                    }
                    if ($mailbox.ForwardingSmtpAddress) {
                        Write-Host "    外部転送先: $($mailbox.ForwardingSmtpAddress)" -ForegroundColor Gray
                    }
                    Write-Host "    配信と転送: $(if ($mailbox.DeliverToMailboxAndForward) { '有効' } else { '無効' })" -ForegroundColor Gray
                }
            }
        }
        
        # CSV出力
        if ($ExportCSV) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputPath = "Reports\Daily\AutoForward_Reply_Configuration_$timestamp.csv"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $OutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # CSV出力（BOM付きUTF-8）
            if ($autoConfigResults -and $autoConfigResults.Count -gt 0) {
                if ($IsWindows -or $env:OS -eq "Windows_NT") {
                    $csvContent = $autoConfigResults | ConvertTo-Csv -NoTypeInformation
                    $utf8WithBom = New-Object System.Text.UTF8Encoding $true
                    [System.IO.File]::WriteAllLines($OutputPath, $csvContent, $utf8WithBom)
                }
                else {
                    $autoConfigResults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
            }
            
            Write-Log "CSVレポート出力完了: $OutputPath" -Level "Info"
        }
        
        # HTMLレポート出力
        $htmlOutputPath = ""
        if ($ExportHTML) {
            if ([string]::IsNullOrEmpty($OutputPath)) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $htmlOutputPath = "Reports\Daily\AutoForward_Reply_Configuration_$timestamp.html"
            }
            else {
                $htmlOutputPath = $OutputPath -replace "\.csv$", ".html"
            }
            
            # レポートディレクトリ確認
            $reportDir = Split-Path $htmlOutputPath -Parent
            if (-not (Test-Path $reportDir)) {
                New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
            }
            
            # HTML生成
            $htmlContent = Generate-AutoForwardReplyReportHTML -ConfigResults $autoConfigResults -Summary @{
                TotalMailboxes = $totalMailboxes
                AutoForwardCount = $autoForwardCount
                AutoReplyCount = $autoReplyCount
                HighRiskCount = $highRiskCount
                MediumRiskCount = $mediumRiskCount
                SuspiciousRulesCount = $suspiciousRulesCount
                ExternalForwardingCount = $externalForwardingCount
                ReportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
            }
            
            # UTF-8 BOM付きで出力
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllText($htmlOutputPath, $htmlContent, $utf8WithBom)
            
            Write-Log "HTMLレポート出力完了: $htmlOutputPath" -Level "Info"
        }
        
        # 結果返却
        return @{
            Success = $true
            TotalMailboxes = $totalMailboxes
            AutoForwardCount = $autoForwardCount
            AutoReplyCount = $autoReplyCount
            HighRiskCount = $highRiskCount
            MediumRiskCount = $mediumRiskCount
            SuspiciousRulesCount = $suspiciousRulesCount
            ExternalForwardingCount = $externalForwardingCount
            DetailedResults = $autoConfigResults
            OutputPath = $OutputPath
            HTMLOutputPath = $htmlOutputPath
        }
        
    }
    catch {
        Write-Log "自動転送・返信設定確認エラー: $($_.Exception.Message)" -Level "Error"
        return @{
            Success = $false
            Error = $_.Exception.Message
            TotalMailboxes = 0
            AutoForwardCount = 0
            AutoReplyCount = 0
            HighRiskCount = 0
            MediumRiskCount = 0
            SuspiciousRulesCount = 0
            ExternalForwardingCount = 0
        }
    }
}

# 自動転送・返信設定 HTMLレポート生成関数
function Generate-AutoForwardReplyReportHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$ConfigResults,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Summary
    )
    
    # リスク別にメールボックスを抽出
    $highRiskMailboxes = $ConfigResults | Where-Object { $_.RiskLevel -eq "高" } | Sort-Object DisplayName
    $mediumRiskMailboxes = $ConfigResults | Where-Object { $_.RiskLevel -eq "中" } | Sort-Object DisplayName
    $autoForwardMailboxes = $ConfigResults | Where-Object { $_.AutoForwardEnabled } | Sort-Object DisplayName
    $autoReplyMailboxes = $ConfigResults | Where-Object { $_.AutoReplyEnabled } | Sort-Object DisplayName
    
    $htmlTemplate = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>自動転送・返信設定確認レポート - みらい建設工業株式会社</title>
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
        .section { 
            background: white; 
            margin-bottom: 20px; 
            border-radius: 8px; 
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-header { 
            background: #f8f9fa; 
            padding: 15px 20px; 
            border-bottom: 1px solid #dee2e6; 
        }
        .section-header h2 { margin: 0; color: #495057; font-size: 18px; }
        .section-content { padding: 20px; }
        .table-container { overflow-x: auto; }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            margin-top: 10px; 
        }
        th, td { 
            padding: 12px; 
            text-align: left; 
            border-bottom: 1px solid #dee2e6; 
            font-size: 14px;
        }
        th { 
            background: #f8f9fa; 
            font-weight: 600; 
            color: #495057; 
        }
        .risk-high { background-color: #FFEBEE; }
        .risk-medium { background-color: #FFF8E1; }
        .risk-low { background-color: #E8F5E8; }
        .status-forward { color: #ff8c00; font-weight: bold; }
        .status-normal { color: #107c10; }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        @media print {
            body { background-color: white; }
            .summary-grid { grid-template-columns: repeat(7, 1fr); }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>📧 自動転送・返信設定確認レポート</h1>
        <div class="subtitle">みらい建設工業株式会社 - Exchange Online</div>
        <div class="subtitle">レポート生成日時: $($Summary.ReportDate)</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>総メールボックス数</h3>
            <div class="value">$($Summary.TotalMailboxes)</div>
            <div class="description">全メールボックス</div>
        </div>
        <div class="summary-card">
            <h3>自動転送設定</h3>
            <div class="value warning">$($Summary.AutoForwardCount)</div>
            <div class="description">転送有効</div>
        </div>
        <div class="summary-card">
            <h3>自動返信設定</h3>
            <div class="value">$($Summary.AutoReplyCount)</div>
            <div class="description">返信有効</div>
        </div>
        <div class="summary-card">
            <h3>高リスク</h3>
            <div class="value danger">$($Summary.HighRiskCount)</div>
            <div class="description">要確認</div>
        </div>
        <div class="summary-card">
            <h3>中リスク</h3>
            <div class="value warning">$($Summary.MediumRiskCount)</div>
            <div class="description">注意</div>
        </div>
        <div class="summary-card">
            <h3>疑わしいルール</h3>
            <div class="value warning">$($Summary.SuspiciousRulesCount)</div>
            <div class="description">転送・削除ルール</div>
        </div>
        <div class="summary-card">
            <h3>外部転送</h3>
            <div class="value danger">$($Summary.ExternalForwardingCount)</div>
            <div class="description">外部ドメイン</div>
        </div>
    </div>
"@

    # 高リスクメールボックス一覧
    if ($highRiskMailboxes.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>🚨 高リスク メールボックス</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>転送先</th>
                            <th>リスク要因</th>
                            <th>ルール数</th>
                            <th>最終更新</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($mailbox in $highRiskMailboxes) {
            $htmlTemplate += @"
                        <tr class="risk-high">
                            <td>$($mailbox.DisplayName)</td>
                            <td>$($mailbox.UserPrincipalName)</td>
                            <td>$($mailbox.ForwardingSmtpAddress)</td>
                            <td>$($mailbox.RiskFactors)</td>
                            <td>$($mailbox.InboxRuleCount)</td>
                            <td>$($mailbox.LastModified)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    # 自動転送設定メールボックス一覧
    if ($autoForwardMailboxes.Count -gt 0) {
        $htmlTemplate += @"
    <div class="section">
        <div class="section-header">
            <h2>⚠️ 自動転送設定メールボックス</h2>
        </div>
        <div class="section-content">
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>表示名</th>
                            <th>ユーザープリンシパル名</th>
                            <th>内部転送先</th>
                            <th>外部転送先</th>
                            <th>配信と転送</th>
                            <th>リスクレベル</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($mailbox in $autoForwardMailboxes) {
            $riskClass = switch ($mailbox.RiskLevel) {
                "高" { "risk-high" }
                "中" { "risk-medium" }
                "低" { "risk-low" }
                default { "" }
            }
            
            $htmlTemplate += @"
                        <tr class="$riskClass">
                            <td>$($mailbox.DisplayName)</td>
                            <td>$($mailbox.UserPrincipalName)</td>
                            <td>$($mailbox.ForwardingAddress)</td>
                            <td>$($mailbox.ForwardingSmtpAddress)</td>
                            <td>$(if ($mailbox.DeliverToMailboxAndForward) { "有効" } else { "無効" })</td>
                            <td>$($mailbox.RiskLevel)</td>
                        </tr>
"@
        }
        $htmlTemplate += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
"@
    }

    $htmlTemplate += @"
    <div class="footer">
        <p>このレポートは Microsoft 365 統合管理システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社</p>
        <p>🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@

    return $htmlTemplate
}

# 公開関数のエクスポート
Export-ModuleMember -Function Get-MailboxQuotaMonitoring, Get-AttachmentAnalysis, Get-AutoForwardReplyConfiguration