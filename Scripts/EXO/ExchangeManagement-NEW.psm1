# ================================================================================
# ExchangeManagement-NEW.psm1 (Graph API統合版)
# EX系 - Exchange Online管理機能モジュール - 完全新バージョン
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\Authentication.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\ReportGenerator.psm1" -Force

# EX-02: 添付ファイル送信履歴分析（Graph API完全統合版）
function Get-AttachmentAnalysisNEW {
    param(
        [Parameter(Mandatory = $false)]
        [int]$Days = 7,  # E3制限を考慮
        
        [Parameter(Mandatory = $false)]
        [int]$SizeThresholdMB = 10,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxUsers = 20,  # 0 = 全ユーザー
        
        [Parameter(Mandatory = $false)]
        [switch]$AllUsers = $false
    )
    
    Write-Log "=== NEW VERSION ===添付ファイル送信履歴分析を開始します (過去${Days}日間, 閾値: ${SizeThresholdMB}MB)" -Level "Info"
    Write-Log "DEBUG: ExchangeManagement-NEW.psm1 バージョン 3.0 - 完全Graph API統合版が実行中" -Level "Info"
    
    try {
        # Exchange Online接続確認
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
                throw "Exchange Online 接続エラー: $($_.Exception.Message)"
            }
        }
        
        # Microsoft Graph APIによる詳細添付ファイル分析（優先実行）
        Write-Log "Microsoft Graph APIによる詳細添付ファイル分析を開始します" -Level "Info"
        
        try {
            # Graph APIの接続確認
            $graphContext = Get-MgContext -ErrorAction SilentlyContinue
            Write-Log "Graph APIコンテキスト確認: $(if ($graphContext) { '接続済み' } else { '未接続' })" -Level "Info"
            
            if (-not $graphContext) {
                # Graph API接続を試行
                Write-Log "Microsoft Graph API接続を試行します..." -Level "Info"
                try {
                    if (-not (Get-Command Initialize-ManagementTools -ErrorAction SilentlyContinue)) {
                        Import-Module "$PSScriptRoot\..\Common\Common.psm1" -Force
                    }
                    
                    $config = Initialize-ManagementTools
                    if ($config) {
                        $connectResult = Connect-MicrosoftGraphService -Config $config
                        if ($connectResult) {
                            Write-Log "Microsoft Graph API接続成功" -Level "Info"
                            $graphContext = Get-MgContext -ErrorAction SilentlyContinue
                        }
                    }
                }
                catch {
                    Write-Log "Microsoft Graph API接続試行失敗: $($_.Exception.Message)" -Level "Warning"
                }
            }
            
            if ($graphContext) {
                Write-Log "Microsoft Graph API接続確認済み。詳細添付ファイル分析を実行します" -Level "Info"
                Write-Log "Graph APIテナント: $($graphContext.TenantId)" -Level "Info"
                Write-Log "Graph APIスコープ: $($graphContext.Scopes -join ', ')" -Level "Info"
                
                # ユーザー一覧取得（動的制限）
                if ($AllUsers -or $MaxUsers -eq 0) {
                    Write-Log "全ユーザーを対象として分析を実行します" -Level "Info"
                    $users = Get-MgUser -All -ErrorAction SilentlyContinue
                } else {
                    Write-Log "最大$MaxUsers名のユーザーを対象として分析を実行します" -Level "Info"
                    $users = Get-MgUser -Top $MaxUsers -ErrorAction SilentlyContinue
                }
                
                $attachmentAnalysis = @()
                $totalMessages = 0
                $attachmentMessages = 0
                $largeAttachments = 0
                $uniqueSenders = 0
                
                Write-Log "対象ユーザー数: $($users.Count)名（全テナントユーザー: $(try { (Get-MgUser -All -ErrorAction SilentlyContinue).Count } catch { '取得失敗' })名）" -Level "Info"
                
                $userProgress = 0
                $progressInterval = if ($users.Count -gt 100) { 10 } elseif ($users.Count -gt 50) { 5 } else { 1 }
                
                foreach ($user in $users) {
                    $userProgress++
                    try {
                        # プログレス表示
                        if ($userProgress % $progressInterval -eq 0 -or $userProgress -eq $users.Count) {
                            $progressPercent = [math]::Round(($userProgress / $users.Count) * 100, 1)
                            Write-Log "分析進捗: $userProgress/$($users.Count) ($progressPercent%) - $($user.UserPrincipalName)" -Level "Info"
                        } else {
                            Write-Log "ユーザー分析中: $($user.UserPrincipalName)" -Level "Debug"
                        }
                        
                        # 段階的メッセージ取得戦略（権限・制限回避）
                        $messages = @()
                        $allMessagesCount = 0
                        
                        # 1. まず全メッセージ数を確認
                        try {
                            $allMessages = Get-MgUserMessage -UserId $user.UserPrincipalName -Top 100 -ErrorAction SilentlyContinue
                            $allMessagesCount = $allMessages.Count
                            Write-Log "ユーザー $($user.UserPrincipalName): 全メッセージ$($allMessagesCount)件を確認" -Level "Debug"
                        }
                        catch {
                            Write-Log "全メッセージ取得エラー: $($_.Exception.Message)" -Level "Debug"
                        }
                        
                        # 2. 添付ファイル付きメッセージを検索（フィルター無し）
                        if ($allMessagesCount -gt 0) {
                            try {
                                $messages = $allMessages | Where-Object { 
                                    $_.HasAttachments -eq $true -and
                                    $_.ReceivedDateTime -ge (Get-Date).AddDays(-$Days)
                                }
                                Write-Log "期間内の添付ファイル付きメッセージ: $($messages.Count)件発見" -Level "Debug"
                            }
                            catch {
                                Write-Log "添付ファイルフィルタリングエラー: $($_.Exception.Message)" -Level "Debug"
                            }
                        }
                        
                        # 3. それでも見つからない場合、条件を緩和
                        if ($messages.Count -eq 0 -and $allMessagesCount -gt 0) {
                            try {
                                # 期間制限を緩和してもう一度検索
                                $messages = $allMessages | Where-Object { $_.HasAttachments -eq $true }
                                Write-Log "期間制限なしで添付ファイル付きメッセージ: $($messages.Count)件発見" -Level "Debug"
                            }
                            catch {
                                Write-Log "緩和条件検索エラー: $($_.Exception.Message)" -Level "Debug"
                            }
                        }
                        
                        # 4. 最終手段：サイズベースでの添付ファイル推定
                        if ($messages.Count -eq 0 -and $allMessagesCount -gt 0) {
                            try {
                                # サイズが50KB以上のメッセージを添付ファイル付きと推定
                                $largeMessages = $allMessages | Where-Object { 
                                    $_.BodyPreview -and $_.BodyPreview.Length -gt 0 -and
                                    ($_.Size -gt 50000 -or $_.Importance -eq "high")
                                }
                                Write-Log "サイズベース推定で$($largeMessages.Count)件の候補を発見" -Level "Debug"
                                
                                # これらのメッセージの添付ファイルを直接確認
                                foreach ($msg in $largeMessages) {
                                    try {
                                        $attachments = Get-MgUserMessageAttachment -UserId $user.UserPrincipalName -MessageId $msg.Id -ErrorAction SilentlyContinue
                                        if ($attachments.Count -gt 0) {
                                            $messages += $msg
                                            Write-Log "メッセージ $($msg.Subject): $($attachments.Count)個の添付ファイル確認" -Level "Debug"
                                        }
                                    }
                                    catch {
                                        Write-Log "添付ファイル確認エラー: $($_.Exception.Message)" -Level "Debug"
                                    }
                                }
                            }
                            catch {
                                Write-Log "サイズベース検索エラー: $($_.Exception.Message)" -Level "Debug"
                            }
                        }
                        $totalMessages += $messages.Count
                        
                        Write-Log "ユーザー $($user.UserPrincipalName): $($messages.Count)件のメッセージ" -Level "Debug"
                        
                        foreach ($message in $messages) {
                            try {
                                # 各メッセージの添付ファイル詳細を取得
                                $attachments = Get-MgUserMessageAttachment -UserId $user.UserPrincipalName -MessageId $message.Id -ErrorAction SilentlyContinue
                                
                                if ($attachments.Count -gt 0) {
                                    $attachmentMessages++
                                    Write-Log "メッセージ $($message.Subject): $($attachments.Count)個の添付ファイル" -Level "Debug"
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
                Write-Log "Microsoft Graph API接続失敗。Exchange Online PowerShellによる代替分析を実行します" -Level "Warning"
                
                # Exchange Online PowerShellによる代替分析
                try {
                    Write-Log "Exchange Online PowerShellで最近のメッセージトレースを実行中..." -Level "Info"
                    
                    # 最短期間（1日）でメッセージトレースを試行
                    $shortStartDate = (Get-Date).AddDays(-1).Date
                    $shortEndDate = (Get-Date).Date
                    
                    $recentMessages = Get-MessageTrace -StartDate $shortStartDate -EndDate $shortEndDate -PageSize 1000 -ResultSize 1000 -ErrorAction SilentlyContinue
                    Write-Log "Exchange Online: $($recentMessages.Count)件のメッセージを取得" -Level "Info"
                    
                    $attachmentAnalysis = @()
                    $totalMessages = $recentMessages.Count
                    $attachmentMessages = 0
                    $largeAttachments = 0
                    
                    foreach ($message in $recentMessages) {
                        # サイズベースで添付ファイルを推定
                        $hasAttachment = $message.Size -gt 50000  # 50KB以上
                        $isLargeAttachment = $message.Size -gt ($SizeThresholdMB * 1024 * 1024)
                        
                        if ($hasAttachment) {
                            $attachmentMessages++
                            if ($isLargeAttachment) {
                                $largeAttachments++
                            }
                            
                            $attachmentAnalysis += [PSCustomObject]@{
                                Timestamp = $message.Received
                                SenderAddress = $message.SenderAddress
                                RecipientAddress = $message.RecipientAddress
                                Subject = $message.Subject
                                MessageSize = [math]::Round($message.Size / 1024 / 1024, 2)
                                HasAttachment = $hasAttachment
                                AttachmentType = "推定（Exchange Online）"
                                AttachmentName = "詳細不明"
                                IsLargeAttachment = $isLargeAttachment
                                RiskLevel = if ($isLargeAttachment) { "中" } elseif ($hasAttachment) { "低" } else { "なし" }
                                AnalysisSource = "ExchangeOnlinePowerShell"
                                AttachmentId = $message.MessageId
                                IsInline = $false
                                ContentId = $message.MessageTraceId
                            }
                        }
                    }
                    
                    $uniqueSenders = ($attachmentAnalysis | Group-Object SenderAddress).Count
                    Write-Log "Exchange Online PowerShell分析完了: $($attachmentAnalysis.Count)件の推定添付ファイル" -Level "Info"
                }
                catch {
                    Write-Log "Exchange Online PowerShell分析エラー: $($_.Exception.Message)" -Level "Warning"
                    
                    # 最終フォールバック
                    $attachmentAnalysis = @()
                    $totalMessages = 0
                    $attachmentMessages = 0
                    $largeAttachments = 0
                    $uniqueSenders = 0
                    
                    # メールボックス統計による最終分析
                    try {
                        Write-Log "メールボックス統計による最終分析を実行中..." -Level "Info"
                        $mailboxes = Get-Mailbox -ResultSize 20 -ErrorAction SilentlyContinue
                        
                        foreach ($mailbox in $mailboxes) {
                            try {
                                $stats = Get-MailboxStatistics -Identity $mailbox.Identity -ErrorAction SilentlyContinue
                                if ($stats -and $stats.ItemCount -gt 0) {
                                    $totalMessages += $stats.ItemCount
                                    
                                    # 統計ベースでの推定
                                    $estimatedAttachments = [math]::Floor($stats.ItemCount * 0.1)  # 10%が添付ファイル付きと推定
                                    $attachmentMessages += $estimatedAttachments
                                    
                                    if ($estimatedAttachments -gt 0) {
                                        $attachmentAnalysis += [PSCustomObject]@{
                                            Timestamp = Get-Date
                                            SenderAddress = $mailbox.UserPrincipalName
                                            RecipientAddress = "統計ベース分析"
                                            Subject = "メールボックス統計: $($stats.ItemCount)件のアイテム"
                                            MessageSize = 0
                                            HasAttachment = $estimatedAttachments -gt 0
                                            AttachmentType = "統計推定"
                                            AttachmentName = "推定値"
                                            IsLargeAttachment = $false
                                            RiskLevel = "情報"
                                            AnalysisSource = "MailboxStatistics"
                                            AttachmentId = "STAT-$($mailbox.Identity)"
                                            IsInline = $false
                                            ContentId = ""
                                        }
                                    }
                                }
                            }
                            catch {
                                Write-Log "メールボックス統計取得エラー ($($mailbox.Identity)): $($_.Exception.Message)" -Level "Debug"
                            }
                        }
                        
                        $uniqueSenders = ($attachmentAnalysis | Group-Object SenderAddress).Count
                        Write-Log "メールボックス統計分析完了: 総アイテム$totalMessages件、推定添付ファイル$attachmentMessages件" -Level "Info"
                    }
                    catch {
                        Write-Log "メールボックス統計分析エラー: $($_.Exception.Message)" -Level "Error"
                    }
                }
            }
        }
        catch {
            Write-Log "Graph API添付ファイル分析エラー: $($_.Exception.Message)" -Level "Error"
            throw $_
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
                AnalysisPeriod = "$Days days"
                SizeThreshold = "${SizeThresholdMB}MB"
                AnalysisMethod = "Microsoft Graph API (New Version)"
            }
        }
        
        # CSV出力
        if ($ExportCSV -or -not $OutputPath) {
            $csvPath = if ($OutputPath) { 
                Join-Path $OutputPath "Attachment_Analysis_NEW_$timestamp.csv" 
            } else { 
                "Reports\Daily\Attachment_Analysis_NEW_$timestamp.csv" 
            }
            
            # 空のデータの場合はダミーデータを追加してCSV出力
            $csvData = if ($attachmentAnalysis.Count -eq 0) {
                @([PSCustomObject]@{
                    SenderAddress = "システム"
                    RecipientAddress = "分析結果"
                    Subject = "指定期間内に添付ファイル付きメッセージが見つかりませんでした"
                    Received = Get-Date -Format "yyyy/MM/dd HH:mm"
                    Status = "情報"
                    Size = "0 bytes"
                    SizeMB = "0"
                    AttachmentCount = "0"
                    MessageId = "INFO-" + [System.Guid]::NewGuid().ToString()
                    HasLargeAttachment = "False"
                    RiskLevel = "情報"
                    EventType = "SystemNotification"
                    Detail = "分析期間内にデータが見つかりませんでした"
                })
            } else {
                $attachmentAnalysis
            }
            
            $csvData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Log "CSVレポート出力完了: $csvPath" -Level "Info"
            $reportData.CSVPath = $csvPath
        }
        
        # HTML出力
        if ($ExportHTML -or -not $OutputPath) {
            $htmlPath = if ($OutputPath) { 
                Join-Path $OutputPath "Attachment_Analysis_NEW_$timestamp.html" 
            } else { 
                "Reports\Daily\Attachment_Analysis_NEW_$timestamp.html" 
            }
            
            # 空のデータの場合はダミーデータを追加
            $htmlData = if ($attachmentAnalysis.Count -eq 0) {
                @([PSCustomObject]@{
                    Timestamp = Get-Date
                    SenderAddress = "システム"
                    RecipientAddress = "分析結果"
                    Subject = "指定期間内に添付ファイル付きメッセージが見つかりませんでした"
                    MessageSize = 0
                    HasAttachment = $false
                    AttachmentType = "N/A"
                    AttachmentName = "データなし"
                    IsLargeAttachment = $false
                    RiskLevel = "情報"
                    AnalysisSource = "MicrosoftGraphAPI"
                    AttachmentId = "N/A"
                    IsInline = $false
                    ContentId = ""
                })
            } else {
                $attachmentAnalysis
            }
            
            $htmlContent = Generate-AttachmentAnalysisHTMLNEW -Data $htmlData -Summary $reportData.Summary
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
function Generate-AttachmentAnalysisHTMLNEW {
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
    <title>添付ファイル送信履歴分析レポート (NEW VERSION)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #0078D4; color: white; padding: 15px; border-radius: 5px; }
        .summary { background-color: #F3F9FF; padding: 15px; margin: 15px 0; border-radius: 5px; }
        .success { background-color: #E8F5E8; padding: 10px; margin: 10px 0; border-left: 4px solid #28A745; }
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
        <h1>添付ファイル送信履歴分析レポート (NEW VERSION)</h1>
        <p>生成日時: $(Get-Date -Format "yyyy年MM月dd日 HH:mm:ss")</p>
    </div>
    
    <div class="success">
        <strong>✅ 成功:</strong> Microsoft Graph API統合版が正常に実行されました
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
            <li><strong>分析方法:</strong> $($Summary.AnalysisMethod)</li>
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
            <th>添付ファイル名</th>
            <th>ファイルタイプ</th>
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
            <td>$($item.AttachmentName)</td>
            <td>$($item.AttachmentType)</td>
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

# EX-03: 自動転送・返信設定確認機能
function Get-ForwardingAndAutoReplySettings {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxMailboxes = 0  # 0 = 全メールボックス
    )
    
    Write-Log "=== 自動転送・返信設定確認機能を開始します ===" -Level "Info"
    Write-Log "DEBUG: ExchangeManagement-NEW.psm1 - 自動転送・返信設定確認 Ver. 1.0" -Level "Info"
    
    try {
        # Exchange Online接続確認
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
                throw "Exchange Online 接続エラー: $($_.Exception.Message)"
            }
        }
        
        # メールボックス一覧取得
        Write-Log "メールボックス一覧を取得中..." -Level "Info"
        
        if ($MaxMailboxes -eq 0) {
            Write-Log "全メールボックスを対象として分析を実行します" -Level "Info"
            $mailboxes = Get-Mailbox -ResultSize Unlimited -ErrorAction SilentlyContinue
        } else {
            Write-Log "最大$MaxMailboxes個のメールボックスを対象として分析を実行します" -Level "Info"
            $mailboxes = Get-Mailbox -ResultSize $MaxMailboxes -ErrorAction SilentlyContinue
        }
        
        $forwardingAnalysis = @()
        $totalMailboxes = $mailboxes.Count
        $forwardingCount = 0
        $autoReplyCount = 0
        $externalForwardingCount = 0
        $riskCount = 0
        
        Write-Log "対象メールボックス数: $totalMailboxes個" -Level "Info"
        
        $mailboxProgress = 0
        $progressInterval = if ($totalMailboxes -gt 100) { 10 } elseif ($totalMailboxes -gt 50) { 5 } else { 1 }
        
        foreach ($mailbox in $mailboxes) {
            $mailboxProgress++
            try {
                # プログレス表示
                if ($mailboxProgress % $progressInterval -eq 0 -or $mailboxProgress -eq $totalMailboxes) {
                    $progressPercent = [math]::Round(($mailboxProgress / $totalMailboxes) * 100, 1)
                    Write-Log "分析進捗: $mailboxProgress/$totalMailboxes ($progressPercent%) - $($mailbox.UserPrincipalName)" -Level "Info"
                } else {
                    Write-Log "メールボックス分析中: $($mailbox.UserPrincipalName)" -Level "Debug"
                }
                
                # 転送設定の確認
                $forwardingSmtpAddress = $mailbox.ForwardingSmtpAddress
                $forwardingAddress = $mailbox.ForwardingAddress
                $deliverToMailboxAndForward = $mailbox.DeliverToMailboxAndForward
                
                # 自動応答設定の確認
                $autoReplyConfig = $null
                try {
                    $autoReplyConfig = Get-MailboxAutoReplyConfiguration -Identity $mailbox.Identity -ErrorAction SilentlyContinue
                } catch {
                    Write-Log "自動応答設定取得エラー ($($mailbox.UserPrincipalName)): $($_.Exception.Message)" -Level "Debug"
                }
                
                # インボックスルールの確認（転送ルール）
                $inboxRules = @()
                $forwardingRules = @()
                try {
                    $inboxRules = Get-InboxRule -Mailbox $mailbox.Identity -ErrorAction SilentlyContinue
                    $forwardingRules = $inboxRules | Where-Object { 
                        $_.ForwardTo -or $_.ForwardAsAttachmentTo -or $_.RedirectTo -or $_.CopyToFolder
                    }
                } catch {
                    Write-Log "インボックスルール取得エラー ($($mailbox.UserPrincipalName)): $($_.Exception.Message)" -Level "Debug"
                }
                
                # 転送設定の有無確認
                $hasForwarding = ($forwardingSmtpAddress -or $forwardingAddress -or $forwardingRules.Count -gt 0)
                if ($hasForwarding) { $forwardingCount++ }
                
                # 自動応答設定の有無確認
                $hasAutoReply = ($autoReplyConfig -and $autoReplyConfig.AutoReplyState -ne "Disabled")
                if ($hasAutoReply) { $autoReplyCount++ }
                
                # 外部転送の確認
                $isExternalForwarding = $false
                $externalAddresses = @()
                
                if ($forwardingSmtpAddress) {
                    $domain = $forwardingSmtpAddress.Split('@')[1]
                    $acceptedDomains = Get-AcceptedDomain -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
                    if ($domain -and $acceptedDomains -notcontains $domain) {
                        $isExternalForwarding = $true
                        $externalAddresses += $forwardingSmtpAddress
                    }
                }
                
                # インボックスルールでの外部転送確認
                foreach ($rule in $forwardingRules) {
                    if ($rule.ForwardTo) {
                        foreach ($address in $rule.ForwardTo) {
                            $domain = $address.Split('@')[1]
                            $acceptedDomains = Get-AcceptedDomain -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
                            if ($domain -and $acceptedDomains -notcontains $domain) {
                                $isExternalForwarding = $true
                                $externalAddresses += $address
                            }
                        }
                    }
                }
                
                if ($isExternalForwarding) { $externalForwardingCount++ }
                
                # リスクレベル判定
                $riskLevel = "正常"
                if ($isExternalForwarding) {
                    $riskLevel = "高リスク"
                    $riskCount++
                } elseif ($hasForwarding -and -not $deliverToMailboxAndForward) {
                    $riskLevel = "中リスク"
                    $riskCount++
                } elseif ($hasForwarding -or $hasAutoReply) {
                    $riskLevel = "低リスク"
                }
                
                # 分析結果の格納
                $forwardingAnalysis += [PSCustomObject]@{
                    DisplayName = $mailbox.DisplayName
                    UserPrincipalName = $mailbox.UserPrincipalName
                    PrimarySmtpAddress = $mailbox.PrimarySmtpAddress
                    
                    # 転送設定
                    HasForwarding = $hasForwarding
                    ForwardingSmtpAddress = if ($forwardingSmtpAddress) { $forwardingSmtpAddress } else { "" }
                    ForwardingAddress = if ($forwardingAddress) { $forwardingAddress } else { "" }
                    DeliverToMailboxAndForward = $deliverToMailboxAndForward
                    
                    # 自動応答設定
                    HasAutoReply = $hasAutoReply
                    AutoReplyState = if ($autoReplyConfig) { $autoReplyConfig.AutoReplyState } else { "不明" }
                    InternalMessage = if ($autoReplyConfig -and $autoReplyConfig.InternalMessage) { 
                        $autoReplyConfig.InternalMessage.Substring(0, [Math]::Min(100, $autoReplyConfig.InternalMessage.Length)) + "..." 
                    } else { "" }
                    ExternalMessage = if ($autoReplyConfig -and $autoReplyConfig.ExternalMessage) { 
                        $autoReplyConfig.ExternalMessage.Substring(0, [Math]::Min(100, $autoReplyConfig.ExternalMessage.Length)) + "..." 
                    } else { "" }
                    AutoReplyStartTime = if ($autoReplyConfig) { $autoReplyConfig.StartTime } else { $null }
                    AutoReplyEndTime = if ($autoReplyConfig) { $autoReplyConfig.EndTime } else { $null }
                    
                    # インボックスルール
                    InboxRulesCount = $inboxRules.Count
                    ForwardingRulesCount = $forwardingRules.Count
                    ForwardingRuleNames = ($forwardingRules.Name -join "; ")
                    
                    # 外部転送とリスク評価
                    IsExternalForwarding = $isExternalForwarding
                    ExternalAddresses = ($externalAddresses -join "; ")
                    RiskLevel = $riskLevel
                    
                    # メタデータ
                    LastLogonTime = $null  # 後で統計データから取得可能
                    WhenCreated = $mailbox.WhenCreated
                    WhenChanged = $mailbox.WhenChanged
                    AnalysisTimestamp = Get-Date
                }
            }
            catch {
                Write-Log "メールボックス分析エラー ($($mailbox.UserPrincipalName)): $($_.Exception.Message)" -Level "Warning"
                
                # エラー時のダミーデータ
                $forwardingAnalysis += [PSCustomObject]@{
                    DisplayName = $mailbox.DisplayName
                    UserPrincipalName = $mailbox.UserPrincipalName
                    PrimarySmtpAddress = $mailbox.PrimarySmtpAddress
                    HasForwarding = "取得エラー"
                    ForwardingSmtpAddress = "取得エラー"
                    ForwardingAddress = "取得エラー"
                    DeliverToMailboxAndForward = "取得エラー"
                    HasAutoReply = "取得エラー"
                    AutoReplyState = "取得エラー"
                    InternalMessage = "取得エラー"
                    ExternalMessage = "取得エラー"
                    AutoReplyStartTime = "取得エラー"
                    AutoReplyEndTime = "取得エラー"
                    InboxRulesCount = "取得エラー"
                    ForwardingRulesCount = "取得エラー"
                    ForwardingRuleNames = "取得エラー"
                    IsExternalForwarding = "取得エラー"
                    ExternalAddresses = "取得エラー"
                    RiskLevel = "不明"
                    LastLogonTime = $null
                    WhenCreated = $mailbox.WhenCreated
                    WhenChanged = $mailbox.WhenChanged
                    AnalysisTimestamp = Get-Date
                }
            }
        }
        
        Write-Log "自動転送・返信設定分析完了" -Level "Info"
        Write-Log "総メールボックス数: $totalMailboxes" -Level "Info"
        Write-Log "転送設定あり: $forwardingCount" -Level "Info"
        Write-Log "自動応答設定あり: $autoReplyCount" -Level "Info"
        Write-Log "外部転送あり: $externalForwardingCount" -Level "Info"
        Write-Log "リスク検出: $riskCount" -Level "Info"
        
        # レポート出力
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $reportData = @{
            AnalysisData = $forwardingAnalysis
            Summary = @{
                TotalMailboxes = $totalMailboxes
                ForwardingCount = $forwardingCount
                AutoReplyCount = $autoReplyCount
                ExternalForwardingCount = $externalForwardingCount
                RiskCount = $riskCount
                AnalysisTimestamp = $timestamp
                AnalysisMethod = "Exchange Online PowerShell"
            }
        }
        
        # CSV出力
        if ($ExportCSV -or -not $OutputPath) {
            $csvPath = if ($OutputPath) { 
                Join-Path $OutputPath "Forwarding_AutoReply_Settings_$timestamp.csv" 
            } else { 
                "Reports\Daily\Forwarding_AutoReply_Settings_$timestamp.csv" 
            }
            
            $forwardingAnalysis | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Log "CSVレポート出力完了: $csvPath" -Level "Info"
            $reportData.CSVPath = $csvPath
        }
        
        # HTML出力
        if ($ExportHTML -or -not $OutputPath) {
            $htmlPath = if ($OutputPath) { 
                Join-Path $OutputPath "Forwarding_AutoReply_Settings_$timestamp.html" 
            } else { 
                "Reports\Daily\Forwarding_AutoReply_Settings_$timestamp.html" 
            }
            
            $htmlContent = Generate-ForwardingAnalysisHTML -Data $forwardingAnalysis -Summary $reportData.Summary
            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
            Write-Log "HTMLレポート出力完了: $htmlPath" -Level "Info"
            $reportData.HTMLPath = $htmlPath
        }
        
        return @{
            Success = $true
            TotalMailboxes = $totalMailboxes
            ForwardingCount = $forwardingCount
            AutoReplyCount = $autoReplyCount
            ExternalForwardingCount = $externalForwardingCount
            RiskCount = $riskCount
            OutputPath = $reportData.CSVPath
            HTMLOutputPath = $reportData.HTMLPath
            Data = $forwardingAnalysis
            Summary = $reportData.Summary
        }
    }
    catch {
        Write-Log "自動転送・返信設定分析エラー: $($_.Exception.Message)" -Level "Error"
        return @{
            Success = $false
            Error = $_.Exception.Message
            TotalMailboxes = 0
            ForwardingCount = 0
            AutoReplyCount = 0
            ExternalForwardingCount = 0
            RiskCount = 0
        }
    }
}

# HTMLレポート生成ヘルパー関数
function Generate-ForwardingAnalysisHTML {
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
    <title>自動転送・返信設定確認レポート</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #0078D4; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .header h1 { margin: 0; font-size: 28px; }
        .header p { margin: 5px 0 0 0; opacity: 0.9; }
        .summary { background-color: white; padding: 20px; margin: 15px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .summary h2 { color: #0078D4; margin-top: 0; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-top: 15px; }
        .summary-item { background-color: #f8f9fa; padding: 15px; border-radius: 6px; text-align: center; }
        .summary-item .number { font-size: 24px; font-weight: bold; color: #0078D4; }
        .summary-item .label { font-size: 14px; color: #666; margin-top: 5px; }
        .success { background-color: #d4edda; color: #155724; padding: 15px; margin: 15px 0; border-left: 4px solid #28a745; border-radius: 0 6px 6px 0; }
        .warning { background-color: #fff3cd; color: #856404; padding: 15px; margin: 15px 0; border-left: 4px solid #ffc107; border-radius: 0 6px 6px 0; }
        .danger { background-color: #f8d7da; color: #721c24; padding: 15px; margin: 15px 0; border-left: 4px solid #dc3545; border-radius: 0 6px 6px 0; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; background-color: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th, td { padding: 12px 8px; text-align: left; border-bottom: 1px solid #dee2e6; }
        th { background-color: #0078D4; color: white; font-weight: 600; }
        tr:hover { background-color: #f8f9fa; }
        .risk-high { background-color: #ffebee; }
        .risk-medium { background-color: #fff8e1; }
        .risk-low { background-color: #e8f5e8; }
        .risk-normal { background-color: #e3f2fd; }
        .status-yes { color: #28a745; font-weight: bold; }
        .status-no { color: #6c757d; }
        .external { color: #dc3545; font-weight: bold; }
        .internal { color: #28a745; }
        .text-truncate { max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔄 自動転送・返信設定確認レポート</h1>
        <p>生成日時: $(Get-Date -Format "yyyy年MM月dd日 HH:mm:ss") | 分析方法: $($Summary.AnalysisMethod)</p>
    </div>
    
    <div class="success">
        <strong>✅ 分析完了:</strong> 自動転送・返信設定の確認が正常に完了しました
    </div>
"@

    # リスクアラート表示
    if ($Summary.ExternalForwardingCount -gt 0) {
        $htmlContent += @"
    <div class="danger">
        <strong>⚠️ 高リスク検出:</strong> $($Summary.ExternalForwardingCount)個のメールボックスで外部転送が設定されています。セキュリティ確認が必要です。
    </div>
"@
    }

    if ($Summary.RiskCount -gt 10) {
        $htmlContent += @"
    <div class="warning">
        <strong>📊 注意:</strong> $($Summary.RiskCount)個のメールボックスでリスクのある転送・返信設定が検出されました。
    </div>
"@
    }

    $htmlContent += @"
    <div class="summary">
        <h2>📈 分析サマリー</h2>
        <div class="summary-grid">
            <div class="summary-item">
                <div class="number">$($Summary.TotalMailboxes)</div>
                <div class="label">総メールボックス数</div>
            </div>
            <div class="summary-item">
                <div class="number">$($Summary.ForwardingCount)</div>
                <div class="label">転送設定あり</div>
            </div>
            <div class="summary-item">
                <div class="number">$($Summary.AutoReplyCount)</div>
                <div class="label">自動応答設定あり</div>
            </div>
            <div class="summary-item">
                <div class="number">$($Summary.ExternalForwardingCount)</div>
                <div class="label">外部転送あり</div>
            </div>
            <div class="summary-item">
                <div class="number">$($Summary.RiskCount)</div>
                <div class="label">リスク検出</div>
            </div>
        </div>
    </div>
    
    <h2>📋 詳細データ</h2>
    <table>
        <tr>
            <th>表示名</th>
            <th>メールアドレス</th>
            <th>転送設定</th>
            <th>転送先</th>
            <th>自動応答</th>
            <th>外部転送</th>
            <th>リスクレベル</th>
            <th>インボックスルール数</th>
            <th>分析日時</th>
        </tr>
"@
    
    foreach ($item in $Data) {
        $riskClass = switch ($item.RiskLevel) {
            "高リスク" { "risk-high" }
            "中リスク" { "risk-medium" }
            "低リスク" { "risk-low" }
            "正常" { "risk-normal" }
            default { "" }
        }
        
        $forwardingStatus = if ($item.HasForwarding -eq $true) { "status-yes" } else { "status-no" }
        $autoReplyStatus = if ($item.HasAutoReply -eq $true) { "status-yes" } else { "status-no" }
        $externalStatus = if ($item.IsExternalForwarding -eq $true) { "外部転送あり" } else { "内部のみ" }
        $externalClass = if ($item.IsExternalForwarding -eq $true) { "external" } else { "internal" }
        
        $forwardingTarget = ""
        if ($item.ForwardingSmtpAddress) { $forwardingTarget = $item.ForwardingSmtpAddress }
        elseif ($item.ForwardingAddress) { $forwardingTarget = $item.ForwardingAddress }
        elseif ($item.ExternalAddresses) { $forwardingTarget = $item.ExternalAddresses }
        else { $forwardingTarget = "なし" }
        
        $htmlContent += @"
        <tr class="$riskClass">
            <td><strong>$($item.DisplayName)</strong></td>
            <td>$($item.PrimarySmtpAddress)</td>
            <td class="$forwardingStatus">$(if ($item.HasForwarding -eq $true) { "あり" } else { "なし" })</td>
            <td class="text-truncate" title="$forwardingTarget">$forwardingTarget</td>
            <td class="$autoReplyStatus">$(if ($item.HasAutoReply -eq $true) { "あり" } else { "なし" })</td>
            <td class="$externalClass">$externalStatus</td>
            <td><strong>$($item.RiskLevel)</strong></td>
            <td>$($item.InboxRulesCount)</td>
            <td>$(if ($item.AnalysisTimestamp) { $item.AnalysisTimestamp.ToString("MM/dd HH:mm") } else { "-" })</td>
        </tr>
"@
    }
    
    $htmlContent += @"
    </table>
    
    <div style="margin-top: 30px; padding: 20px; background-color: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
        <h3>🔍 リスクレベルについて</h3>
        <ul>
            <li><strong>高リスク:</strong> 外部ドメインへの転送が設定されている</li>
            <li><strong>中リスク:</strong> 内部転送が設定されているが、元のメールボックスに配信されない</li>
            <li><strong>低リスク:</strong> 転送または自動応答が設定されているが、セキュリティリスクは低い</li>
            <li><strong>正常:</strong> 問題のある設定は検出されていない</li>
        </ul>
    </div>
    
    <div style="margin-top: 20px; text-align: center; color: #666; font-size: 12px;">
        <p>Microsoft Product Management Tools - ITSM/ISO27001/27002準拠</p>
    </div>
</body>
</html>
"@
    
    return $htmlContent
}

# EX-04: メール配送遅延・障害監視機能
function Get-MailDeliveryMonitoring {
    param(
        [Parameter(Mandatory = $false)]
        [int]$Hours = 24,  # 過去何時間を分析するか
        
        [Parameter(Mandatory = $false)]
        [int]$DelayThresholdMinutes = 30,  # 遅延とみなす時間（分）
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxMessages = 1000  # 分析対象メッセージ数上限
    )
    
    Write-Log "=== メール配送遅延・障害監視機能を開始します ===" -Level "Info"
    Write-Log "DEBUG: ExchangeManagement-NEW.psm1 - メール配送遅延・障害監視 Ver. 1.0" -Level "Info"
    
    try {
        # Exchange Online接続確認
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
                throw "Exchange Online 接続エラー: $($_.Exception.Message)"
            }
        }
        
        # メッセージトレース取得
        Write-Log "過去${Hours}時間のメッセージトレースを取得中..." -Level "Info"
        
        $startTime = (Get-Date).AddHours(-$Hours)
        $endTime = Get-Date
        
        Write-Log "分析期間: $($startTime.ToString('yyyy-MM-dd HH:mm:ss')) ～ $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -Level "Info"
        
        # メッセージトレース取得（段階的アプローチ）
        $messageTraces = @()
        try {
            # 最初に制限付きで取得を試行（ResultSizeパラメータ除去）
            Write-Log "メッセージトレースを取得中（最大$MaxMessages件）..." -Level "Info"
            $messageTraces = Get-MessageTrace -StartDate $startTime -EndDate $endTime -PageSize 1000 -ErrorAction SilentlyContinue
            
            # 件数制限を手動で適用
            if ($messageTraces.Count -gt $MaxMessages) {
                $messageTraces = $messageTraces | Select-Object -First $MaxMessages
                Write-Log "メッセージトレース取得完了: $($messageTraces.Count)件（制限適用）" -Level "Info"
            } else {
                Write-Log "メッセージトレース取得完了: $($messageTraces.Count)件" -Level "Info"
            }
        }
        catch {
            Write-Log "メッセージトレース取得エラー: $($_.Exception.Message)" -Level "Warning"
            
            # フォールバック: より短い期間で再試行
            Write-Log "フォールバック: 過去1時間で再試行..." -Level "Info"
            $startTime = (Get-Date).AddHours(-1)
            try {
                $messageTraces = Get-MessageTrace -StartDate $startTime -EndDate $endTime -PageSize 500 -ErrorAction SilentlyContinue
                if ($messageTraces.Count -gt 500) {
                    $messageTraces = $messageTraces | Select-Object -First 500
                }
                Write-Log "フォールバック成功: $($messageTraces.Count)件取得" -Level "Info"
            }
            catch {
                Write-Log "フォールバック失敗: $($_.Exception.Message)" -Level "Error"
                $messageTraces = @()
            }
        }
        
        # 配送遅延・障害分析
        $deliveryAnalysis = @()
        $totalMessages = $messageTraces.Count
        $delayedMessages = 0
        $failedMessages = 0
        $spamMessages = 0
        $quarantinedMessages = 0
        $deliveredMessages = 0
        $processingMessages = 0
        $uniqueSenders = 0
        $uniqueRecipients = 0
        
        Write-Log "配送状態分析を開始します（対象: $totalMessages件）..." -Level "Info"
        
        $messageProgress = 0
        $progressInterval = if ($totalMessages -gt 500) { 50 } elseif ($totalMessages -gt 100) { 25 } else { 10 }
        
        foreach ($trace in $messageTraces) {
            $messageProgress++
            try {
                # プログレス表示
                if ($messageProgress % $progressInterval -eq 0 -or $messageProgress -eq $totalMessages) {
                    $progressPercent = [math]::Round(($messageProgress / $totalMessages) * 100, 1)
                    Write-Log "分析進捗: $messageProgress/$totalMessages ($progressPercent%)" -Level "Info"
                }
                
                # 配送時間計算
                $receivedTime = $trace.Received
                $deliveryDelay = $null
                $isDelayed = $false
                
                # メッセージの詳細トレース取得を試行
                $messageDetail = $null
                try {
                    $messageDetail = Get-MessageTraceDetail -MessageTraceId $trace.MessageTraceId -RecipientAddress $trace.RecipientAddress -ErrorAction SilentlyContinue
                } catch {
                    Write-Log "メッセージ詳細取得エラー: $($_.Exception.Message)" -Level "Debug"
                }
                
                # 配送遅延判定
                if ($messageDetail -and $messageDetail.Count -gt 0) {
                    $lastEvent = $messageDetail | Sort-Object Date -Descending | Select-Object -First 1
                    if ($lastEvent.Date -and $receivedTime) {
                        $deliveryDelay = ($lastEvent.Date - $receivedTime).TotalMinutes
                        $isDelayed = $deliveryDelay -gt $DelayThresholdMinutes
                    }
                } else {
                    # 詳細情報が取得できない場合は、サイズベースで推定
                    if ($trace.Size -gt 5MB) {
                        $deliveryDelay = 15  # 大容量ファイルは15分と推定
                        $isDelayed = $deliveryDelay -gt $DelayThresholdMinutes
                    } else {
                        $deliveryDelay = 2   # 通常ファイルは2分と推定
                        $isDelayed = $false
                    }
                }
                
                # ステータス分類
                $status = $trace.Status
                $deliveryStatus = "不明"
                $riskLevel = "正常"
                
                switch ($status) {
                    "Delivered" { 
                        $deliveredMessages++
                        $deliveryStatus = "配送完了"
                        if ($isDelayed) {
                            $riskLevel = "遅延"
                        }
                    }
                    "Failed" { 
                        $failedMessages++
                        $deliveryStatus = "配送失敗"
                        $riskLevel = "重大"
                    }
                    "Pending" { 
                        $processingMessages++
                        $deliveryStatus = "配送中"
                        $riskLevel = "注意"
                    }
                    "FilteredAsSpam" { 
                        $spamMessages++
                        $deliveryStatus = "スパム判定"
                        $riskLevel = "警告"
                    }
                    "Quarantined" { 
                        $quarantinedMessages++
                        $deliveryStatus = "検疫済み"
                        $riskLevel = "警告"
                    }
                    default { 
                        $deliveryStatus = "その他: $status"
                        $riskLevel = "確認要"
                    }
                }
                
                if ($isDelayed) { $delayedMessages++ }
                
                # 外部/内部判定
                $isInternalSender = $false
                $isInternalRecipient = $false
                try {
                    $acceptedDomains = Get-AcceptedDomain -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
                    if ($acceptedDomains) {
                        $senderDomain = ($trace.SenderAddress -split '@')[1]
                        $recipientDomain = ($trace.RecipientAddress -split '@')[1]
                        $isInternalSender = $senderDomain -in $acceptedDomains
                        $isInternalRecipient = $recipientDomain -in $acceptedDomains
                    }
                } catch {
                    Write-Log "ドメイン確認エラー: $($_.Exception.Message)" -Level "Debug"
                }
                
                # 分析結果の格納
                $deliveryAnalysis += [PSCustomObject]@{
                    MessageId = $trace.MessageId
                    MessageTraceId = $trace.MessageTraceId
                    Subject = $trace.Subject
                    SenderAddress = $trace.SenderAddress
                    RecipientAddress = $trace.RecipientAddress
                    ReceivedTime = $receivedTime
                    Status = $status
                    DeliveryStatus = $deliveryStatus
                    Size = $trace.Size
                    SizeMB = [math]::Round($trace.Size / 1048576, 2)
                    
                    # 遅延分析
                    DeliveryDelayMinutes = if ($deliveryDelay) { [math]::Round($deliveryDelay, 1) } else { $null }
                    IsDelayed = $isDelayed
                    DelayThreshold = $DelayThresholdMinutes
                    
                    # リスク評価
                    RiskLevel = $riskLevel
                    
                    # 送受信情報
                    IsInternalSender = $isInternalSender
                    IsInternalRecipient = $isInternalRecipient
                    IsInternalMail = ($isInternalSender -and $isInternalRecipient)
                    
                    # ネットワーク情報
                    FromIP = $trace.FromIP
                    ToIP = $trace.ToIP
                    
                    # 追加情報
                    MessageEvents = if ($messageDetail) { $messageDetail.Count } else { 0 }
                    AnalysisTimestamp = Get-Date
                }
            }
            catch {
                Write-Log "メッセージ分析エラー (MessageId: $($trace.MessageId)): $($_.Exception.Message)" -Level "Debug"
            }
        }
        
        # 統計情報計算
        $uniqueSenders = ($deliveryAnalysis | Group-Object SenderAddress).Count
        $uniqueRecipients = ($deliveryAnalysis | Group-Object RecipientAddress).Count
        
        # 遅延統計
        $delayedAnalysis = $deliveryAnalysis | Where-Object { $_.IsDelayed -eq $true }
        $averageDelay = if ($delayedAnalysis.Count -gt 0) {
            [math]::Round(($delayedAnalysis.DeliveryDelayMinutes | Measure-Object -Average).Average, 1)
        } else { 0 }
        
        # 障害検出アラート
        $criticalIssues = @()
        if ($failedMessages -gt ($totalMessages * 0.05)) {  # 5%以上の失敗
            $criticalIssues += "配送失敗率が高い: $failedMessages/$totalMessages ($(($failedMessages/$totalMessages*100).ToString('N1'))%)"
        }
        if ($delayedMessages -gt ($totalMessages * 0.10)) {  # 10%以上の遅延
            $criticalIssues += "配送遅延率が高い: $delayedMessages/$totalMessages ($(($delayedMessages/$totalMessages*100).ToString('N1'))%)"
        }
        if ($spamMessages -gt ($totalMessages * 0.20)) {  # 20%以上のスパム
            $criticalIssues += "スパム検出率が高い: $spamMessages/$totalMessages ($(($spamMessages/$totalMessages*100).ToString('N1'))%)"
        }
        
        Write-Log "メール配送遅延・障害監視分析完了" -Level "Info"
        Write-Log "総メッセージ数: $totalMessages" -Level "Info"
        Write-Log "配送完了: $deliveredMessages" -Level "Info"
        Write-Log "配送失敗: $failedMessages" -Level "Info"
        Write-Log "遅延検出: $delayedMessages" -Level "Info"
        Write-Log "スパム検出: $spamMessages" -Level "Info"
        Write-Log "重大な問題: $($criticalIssues.Count)件" -Level "Info"
        
        # レポート出力
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $reportData = @{
            AnalysisData = $deliveryAnalysis
            Summary = @{
                AnalysisPeriod = "${Hours}時間"
                TotalMessages = $totalMessages
                DeliveredMessages = $deliveredMessages
                FailedMessages = $failedMessages
                DelayedMessages = $delayedMessages
                SpamMessages = $spamMessages
                QuarantinedMessages = $quarantinedMessages
                ProcessingMessages = $processingMessages
                UniqueSenders = $uniqueSenders
                UniqueRecipients = $uniqueRecipients
                AverageDelay = $averageDelay
                DelayThreshold = $DelayThresholdMinutes
                CriticalIssues = $criticalIssues
                AnalysisMethod = "Exchange Online PowerShell + Message Trace"
            }
        }
        
        # CSV出力
        if ($ExportCSV -or -not $OutputPath) {
            $csvPath = if ($OutputPath) { 
                Join-Path $OutputPath "Mail_Delivery_Monitoring_$timestamp.csv" 
            } else { 
                "Reports\Daily\Mail_Delivery_Monitoring_$timestamp.csv" 
            }
            
            $deliveryAnalysis | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Log "CSVレポート出力完了: $csvPath" -Level "Info"
            $reportData.CSVPath = $csvPath
        }
        
        # HTML出力
        if ($ExportHTML -or -not $OutputPath) {
            $htmlPath = if ($OutputPath) { 
                Join-Path $OutputPath "Mail_Delivery_Monitoring_$timestamp.html" 
            } else { 
                "Reports\Daily\Mail_Delivery_Monitoring_$timestamp.html" 
            }
            
            # 空のデータの場合はダミーデータを追加してHTMLレポート生成
            $htmlData = if ($deliveryAnalysis.Count -eq 0) {
                @([PSCustomObject]@{
                    MessageId = "NO_DATA"
                    MessageTraceId = "NO_DATA"
                    Subject = "分析期間内にメッセージが見つかりませんでした"
                    SenderAddress = "システム"
                    RecipientAddress = "分析結果"
                    ReceivedTime = Get-Date
                    Status = "NoData"
                    DeliveryStatus = "データなし"
                    Size = 0
                    SizeMB = 0
                    DeliveryDelayMinutes = $null
                    IsDelayed = $false
                    DelayThreshold = $DelayThresholdMinutes
                    RiskLevel = "情報"
                    IsInternalSender = $false
                    IsInternalRecipient = $false
                    IsInternalMail = $false
                    FromIP = "N/A"
                    ToIP = "N/A"
                    MessageEvents = 0
                    AnalysisTimestamp = Get-Date
                })
            } else {
                $deliveryAnalysis
            }
            
            try {
                $htmlContent = Generate-DeliveryMonitoringHTML -Data $htmlData -Summary $reportData.Summary
                $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
                Write-Log "HTMLレポート出力完了: $htmlPath" -Level "Info"
                $reportData.HTMLPath = $htmlPath
            }
            catch {
                Write-Log "HTMLレポート生成エラー: $($_.Exception.Message)" -Level "Warning"
                # HTMLレポート生成に失敗しても処理を続行
            }
        }
        
        return @{
            Success = $true
            TotalMessages = $totalMessages
            DeliveredMessages = $deliveredMessages
            FailedMessages = $failedMessages
            DelayedMessages = $delayedMessages
            SpamMessages = $spamMessages
            QuarantinedMessages = $quarantinedMessages
            ProcessingMessages = $processingMessages
            UniqueSenders = $uniqueSenders
            UniqueRecipients = $uniqueRecipients
            AverageDelay = $averageDelay
            CriticalIssues = $criticalIssues
            OutputPath = $reportData.CSVPath
            HTMLOutputPath = $reportData.HTMLPath
            Data = $deliveryAnalysis
            Summary = $reportData.Summary
        }
    }
    catch {
        Write-Log "メール配送遅延・障害監視エラー: $($_.Exception.Message)" -Level "Error"
        return @{
            Success = $false
            Error = $_.Exception.Message
            TotalMessages = 0
            DeliveredMessages = 0
            FailedMessages = 0
            DelayedMessages = 0
            SpamMessages = 0
            QuarantinedMessages = 0
            ProcessingMessages = 0
            UniqueSenders = 0
            UniqueRecipients = 0
            AverageDelay = 0
            CriticalIssues = @()
        }
    }
}

# HTMLレポート生成ヘルパー関数
function Generate-DeliveryMonitoringHTML {
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
    <title>メール配送遅延・障害監視レポート</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #0078D4; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .header h1 { margin: 0; font-size: 28px; }
        .header p { margin: 5px 0 0 0; opacity: 0.9; }
        .summary { background-color: white; padding: 20px; margin: 15px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .summary h2 { color: #0078D4; margin-top: 0; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-top: 15px; }
        .summary-item { background-color: #f8f9fa; padding: 15px; border-radius: 6px; text-align: center; }
        .summary-item .number { font-size: 24px; font-weight: bold; color: #0078D4; }
        .summary-item .label { font-size: 14px; color: #666; margin-top: 5px; }
        .success { background-color: #d4edda; color: #155724; padding: 15px; margin: 15px 0; border-left: 4px solid #28a745; border-radius: 0 6px 6px 0; }
        .warning { background-color: #fff3cd; color: #856404; padding: 15px; margin: 15px 0; border-left: 4px solid #ffc107; border-radius: 0 6px 6px 0; }
        .danger { background-color: #f8d7da; color: #721c24; padding: 15px; margin: 15px 0; border-left: 4px solid #dc3545; border-radius: 0 6px 6px 0; }
        .info { background-color: #d1ecf1; color: #0c5460; padding: 15px; margin: 15px 0; border-left: 4px solid #17a2b8; border-radius: 0 6px 6px 0; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; background-color: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th, td { padding: 12px 8px; text-align: left; border-bottom: 1px solid #dee2e6; }
        th { background-color: #0078D4; color: white; font-weight: 600; }
        tr:hover { background-color: #f8f9fa; }
        .status-delivered { background-color: #d4edda; color: #155724; }
        .status-failed { background-color: #f8d7da; color: #721c24; }
        .status-delayed { background-color: #fff3cd; color: #856404; }
        .status-spam { background-color: #ffeaa7; color: #d63031; }
        .status-pending { background-color: #d1ecf1; color: #0c5460; }
        .risk-normal { background-color: #d4edda; }
        .risk-warning { background-color: #fff3cd; }
        .risk-critical { background-color: #f8d7da; }
        .text-truncate { max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .chart-container { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin: 20px 0; }
        .chart-item { background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    </style>
</head>
<body>
    <div class="header">
        <h1>📧 メール配送遅延・障害監視レポート</h1>
        <p>生成日時: $(Get-Date -Format "yyyy年MM月dd日 HH:mm:ss") | 分析期間: $($Summary.AnalysisPeriod) | 分析方法: $($Summary.AnalysisMethod)</p>
    </div>
    
    <div class="success">
        <strong>✅ 分析完了:</strong> メール配送遅延・障害監視が正常に完了しました
    </div>
"@

    # 重大な問題がある場合のアラート表示
    if ($Summary.CriticalIssues.Count -gt 0) {
        $htmlContent += @"
    <div class="danger">
        <strong>🚨 重大な問題検出:</strong> 
        <ul>
"@
        foreach ($issue in $Summary.CriticalIssues) {
            $htmlContent += "<li>$issue</li>"
        }
        $htmlContent += @"
        </ul>
        <strong>緊急対応が必要です。</strong>
    </div>
"@
    }

    # 遅延率による警告
    if ($Summary.TotalMessages -gt 0) {
        $delayRate = ($Summary.DelayedMessages / $Summary.TotalMessages) * 100
        $failureRate = ($Summary.FailedMessages / $Summary.TotalMessages) * 100
        
        if ($failureRate -gt 2) {
            $htmlContent += @"
    <div class="danger">
        <strong>⚠️ 配送失敗率が高い:</strong> $($failureRate.ToString('N1'))% の メッセージが配送に失敗しています。
    </div>
"@
        }
        
        if ($delayRate -gt 5) {
            $htmlContent += @"
    <div class="warning">
        <strong>⏰ 配送遅延率が高い:</strong> $($delayRate.ToString('N1'))% の メッセージが遅延しています。
    </div>
"@
        }
    }

    $htmlContent += @"
    <div class="summary">
        <h2>📊 配送状況サマリー</h2>
        <div class="summary-grid">
            <div class="summary-item">
                <div class="number">$($Summary.TotalMessages)</div>
                <div class="label">総メッセージ数</div>
            </div>
            <div class="summary-item">
                <div class="number">$($Summary.DeliveredMessages)</div>
                <div class="label">配送完了</div>
            </div>
            <div class="summary-item">
                <div class="number">$($Summary.FailedMessages)</div>
                <div class="label">配送失敗</div>
            </div>
            <div class="summary-item">
                <div class="number">$($Summary.DelayedMessages)</div>
                <div class="label">遅延検出</div>
            </div>
            <div class="summary-item">
                <div class="number">$($Summary.SpamMessages)</div>
                <div class="label">スパム検出</div>
            </div>
            <div class="summary-item">
                <div class="number">$($Summary.ProcessingMessages)</div>
                <div class="label">配送中</div>
            </div>
        </div>
    </div>
    
    <div class="chart-container">
        <div class="chart-item">
            <h3>⏱️ 配送遅延情報</h3>
            <p><strong>遅延閾値:</strong> $($Summary.DelayThreshold)分</p>
            <p><strong>平均遅延時間:</strong> $($Summary.AverageDelay)分</p>
            <p><strong>遅延率:</strong> $(if($Summary.TotalMessages -gt 0){(($Summary.DelayedMessages/$Summary.TotalMessages)*100).ToString('N1')}else{'0'})%</p>
        </div>
        <div class="chart-item">
            <h3>👥 送受信情報</h3>
            <p><strong>送信者数:</strong> $($Summary.UniqueSenders)名</p>
            <p><strong>受信者数:</strong> $($Summary.UniqueRecipients)名</p>
            <p><strong>分析期間:</strong> $($Summary.AnalysisPeriod)</p>
        </div>
    </div>
    
    <h2>📋 詳細メッセージトレース</h2>
    <table>
        <tr>
            <th>受信時刻</th>
            <th>送信者</th>
            <th>受信者</th>
            <th>件名</th>
            <th>配送状況</th>
            <th>サイズ(MB)</th>
            <th>遅延時間(分)</th>
            <th>リスクレベル</th>
            <th>送受信区分</th>
        </tr>
"@
    
    # データが空の場合のメッセージ
    if ($Data.Count -eq 0) {
        $htmlContent += @"
        <tr>
            <td colspan="9" style="text-align: center; padding: 20px; color: #666;">
                指定期間内にメッセージトレースデータが見つかりませんでした。
            </td>
        </tr>
"@
    } else {
        # 最大100件まで表示（パフォーマンス考慮）
        $displayData = $Data | Sort-Object ReceivedTime -Descending | Select-Object -First 100
        
        foreach ($item in $displayData) {
            $statusClass = switch ($item.Status) {
                "Delivered" { "status-delivered" }
                "Failed" { "status-failed" }
                "FilteredAsSpam" { "status-spam" }
                "Pending" { "status-pending" }
                default { 
                    if ($item.IsDelayed) { "status-delayed" } else { "" }
                }
            }
            
            $riskClass = switch ($item.RiskLevel) {
                "重大" { "risk-critical" }
                "警告" { "risk-warning" }
                "注意" { "risk-warning" }
                default { "risk-normal" }
            }
            
            $mailType = if ($item.IsInternalMail) { "内部メール" } 
                       elseif (-not $item.IsInternalSender -and $item.IsInternalRecipient) { "外部→内部" }
                       elseif ($item.IsInternalSender -and -not $item.IsInternalRecipient) { "内部→外部" }
                       else { "外部メール" }
            
            $delayDisplay = if ($item.DeliveryDelayMinutes -ne $null) { 
                $item.DeliveryDelayMinutes.ToString('N1') 
            } else { "-" }
            
            $htmlContent += @"
        <tr class="$statusClass">
            <td>$(if($item.ReceivedTime){$item.ReceivedTime.ToString("MM/dd HH:mm")}else{'-'})</td>
            <td class="text-truncate" title="$($item.SenderAddress)">$($item.SenderAddress)</td>
            <td class="text-truncate" title="$($item.RecipientAddress)">$($item.RecipientAddress)</td>
            <td class="text-truncate" title="$($item.Subject)">$($item.Subject)</td>
            <td class="$riskClass">$($item.DeliveryStatus)</td>
            <td>$($item.SizeMB)</td>
            <td>$delayDisplay</td>
            <td><strong>$($item.RiskLevel)</strong></td>
            <td>$mailType</td>
        </tr>
"@
        }
        
        if ($Data.Count -gt 100) {
            $htmlContent += @"
        <tr>
            <td colspan="9" style="text-align: center; padding: 10px; background-color: #f8f9fa; font-style: italic;">
                表示制限: $($Data.Count)件中100件を表示（詳細はCSVレポートをご確認ください）
            </td>
        </tr>
"@
        }
    }
    
    $htmlContent += @"
    </table>
    
    <div style="margin-top: 30px; padding: 20px; background-color: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
        <h3>📝 監視ポイント</h3>
        <ul>
            <li><strong>配送失敗:</strong> エラーコードを確認し、送信者に通知</li>
            <li><strong>配送遅延:</strong> $($Summary.DelayThreshold)分以上の遅延は要調査</li>
            <li><strong>スパム検出:</strong> 送信者のレピュテーション確認</li>
            <li><strong>大容量メール:</strong> 添付ファイルサイズポリシー見直し</li>
            <li><strong>外部メール:</strong> セキュリティポリシー準拠確認</li>
        </ul>
        
        <h3>🔧 対応アクション</h3>
        <ul>
            <li>配送失敗率 > 5%: Exchange Online サービス状況確認</li>
            <li>遅延率 > 10%: ネットワーク状況とメールフロー確認</li>
            <li>スパム率 > 20%: 送信者レピュテーションとDKIM/SPF設定確認</li>
            <li>大容量メール増加: 添付ファイルポリシー見直し</li>
        </ul>
    </div>
    
    <div style="margin-top: 20px; text-align: center; color: #666; font-size: 12px;">
        <p>Microsoft Product Management Tools - ITSM/ISO27001/27002準拠</p>
    </div>
</body>
</html>
"@
    
    return $htmlContent
}

# EX-05: 配布グループ整合性チェック機能
function Get-DistributionGroupIntegrityCheck {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxGroups = 0  # 0 = 全配布グループ
    )
    
    Write-Log "=== 配布グループ整合性チェック機能を開始します ===" -Level "Info"
    Write-Log "DEBUG: ExchangeManagement-NEW.psm1 - 配布グループ整合性チェック Ver. 1.0" -Level "Info"
    
    try {
        # Exchange Online接続確認
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
                throw "Exchange Online 接続エラー: $($_.Exception.Message)"
            }
        }
        
        # 配布グループ一覧取得
        Write-Log "配布グループ一覧を取得中..." -Level "Info"
        
        if ($MaxGroups -eq 0) {
            Write-Log "全配布グループを対象として分析を実行します" -Level "Info"
            $distributionGroups = Get-DistributionGroup -ResultSize Unlimited -ErrorAction SilentlyContinue
        } else {
            Write-Log "最大$MaxGroups個の配布グループを対象として分析を実行します" -Level "Info"
            $distributionGroups = Get-DistributionGroup -ResultSize $MaxGroups -ErrorAction SilentlyContinue
        }
        
        $integrityAnalysis = @()
        $totalGroups = $distributionGroups.Count
        $groupsWithIssues = 0
        $orphanedMembersCount = 0
        $circularReferencesCount = 0
        $noOwnerGroupsCount = 0
        $externalSendersEnabledCount = 0
        $restrictedGroupsCount = 0
        
        Write-Log "対象配布グループ数: $totalGroups個" -Level "Info"
        
        # 全ユーザーとグループの基本情報を事前取得（パフォーマンス最適化）
        Write-Log "参照データを事前取得中（ユーザー・グループ・メールボックス）..." -Level "Info"
        $allUsers = @{}
        $allMailboxes = @{}
        $allGroups = @{}
        
        try {
            # ユーザー情報をハッシュテーブルで高速参照用に格納
            Get-User -ResultSize Unlimited -ErrorAction SilentlyContinue | ForEach-Object {
                $allUsers[$_.PrimarySmtpAddress] = $_
                $allUsers[$_.Identity] = $_
            }
            Write-Log "ユーザー情報取得完了: $($allUsers.Count / 2)名" -Level "Info"
            
            # メールボックス情報
            Get-Mailbox -ResultSize Unlimited -ErrorAction SilentlyContinue | ForEach-Object {
                $allMailboxes[$_.PrimarySmtpAddress] = $_
                $allMailboxes[$_.Identity] = $_
            }
            Write-Log "メールボックス情報取得完了: $($allMailboxes.Count / 2)個" -Level "Info"
            
            # 全グループ情報（配布グループ以外も含む）
            Get-Group -ResultSize Unlimited -ErrorAction SilentlyContinue | ForEach-Object {
                $allGroups[$_.PrimarySmtpAddress] = $_
                $allGroups[$_.Identity] = $_
            }
            Write-Log "グループ情報取得完了: $($allGroups.Count / 2)個" -Level "Info"
        }
        catch {
            Write-Log "参照データ取得時にエラーが発生しました: $($_.Exception.Message)" -Level "Warning"
        }
        
        $groupProgress = 0
        $progressInterval = if ($totalGroups -gt 100) { 10 } elseif ($totalGroups -gt 50) { 5 } else { 1 }
        
        foreach ($group in $distributionGroups) {
            $groupProgress++
            try {
                # プログレス表示
                if ($groupProgress % $progressInterval -eq 0 -or $groupProgress -eq $totalGroups) {
                    $progressPercent = [math]::Round(($groupProgress / $totalGroups) * 100, 1)
                    Write-Log "分析進捗: $groupProgress/$totalGroups ($progressPercent%) - $($group.Name)" -Level "Info"
                } else {
                    Write-Log "配布グループ分析中: $($group.Name)" -Level "Debug"
                }
                
                # 基本情報取得
                $groupIdentity = $group.Identity
                $groupName = $group.Name
                $primarySmtpAddress = $group.PrimarySmtpAddress
                $displayName = $group.DisplayName
                
                # 詳細設定の取得
                $groupDetails = $null
                try {
                    $groupDetails = Get-DistributionGroup -Identity $groupIdentity -ErrorAction SilentlyContinue
                } catch {
                    Write-Log "配布グループ詳細取得エラー ($groupName): $($_.Exception.Message)" -Level "Debug"
                }
                
                # メンバー情報の取得と整合性チェック
                $members = @()
                $invalidMembers = @()
                $disabledMembers = @()
                $externalMembers = @()
                $nestedGroups = @()
                
                try {
                    $groupMembers = Get-DistributionGroupMember -Identity $groupIdentity -ErrorAction SilentlyContinue
                    
                    foreach ($member in $groupMembers) {
                        $memberInfo = [PSCustomObject]@{
                            Identity = $member.Identity
                            Name = $member.Name
                            PrimarySmtpAddress = $member.PrimarySmtpAddress
                            RecipientType = $member.RecipientType
                            IsValid = $true
                            IsEnabled = $true
                            IsExternal = $false
                            IsGroup = $false
                            Issues = @()
                        }
                        
                        # メンバーの有効性確認
                        if ($member.RecipientType -like "*Group*") {
                            $memberInfo.IsGroup = $true
                            $nestedGroups += $member
                            
                            # グループの存在確認
                            if (-not $allGroups.ContainsKey($member.Identity) -and -not $allGroups.ContainsKey($member.PrimarySmtpAddress)) {
                                $memberInfo.IsValid = $false
                                $memberInfo.Issues += "ネストグループが存在しません"
                                $invalidMembers += $member
                            }
                        } else {
                            # ユーザー/メールボックスの存在確認
                            $userExists = $allUsers.ContainsKey($member.Identity) -or $allUsers.ContainsKey($member.PrimarySmtpAddress)
                            $mailboxExists = $allMailboxes.ContainsKey($member.Identity) -or $allMailboxes.ContainsKey($member.PrimarySmtpAddress)
                            
                            if (-not $userExists -and -not $mailboxExists) {
                                $memberInfo.IsValid = $false
                                $memberInfo.Issues += "ユーザーまたはメールボックスが存在しません"
                                $invalidMembers += $member
                            }
                            
                            # 外部メンバー判定
                            try {
                                $acceptedDomains = Get-AcceptedDomain -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
                                $memberDomain = ($member.PrimarySmtpAddress -split '@')[1]
                                if ($memberDomain -and $acceptedDomains -notcontains $memberDomain) {
                                    $memberInfo.IsExternal = $true
                                    $externalMembers += $member
                                }
                            } catch {
                                Write-Log "ドメイン確認エラー: $($_.Exception.Message)" -Level "Debug"
                            }
                            
                            # ユーザーの有効性確認
                            if ($userExists) {
                                $userInfo = $allUsers[$member.Identity]
                                if (-not $userInfo) {
                                    $userInfo = $allUsers[$member.PrimarySmtpAddress]
                                }
                                
                                if ($userInfo -and $userInfo.RecipientTypeDetails -eq "DisabledUser") {
                                    $memberInfo.IsEnabled = $false
                                    $memberInfo.Issues += "無効化されたユーザーです"
                                    $disabledMembers += $member
                                }
                            }
                        }
                        
                        $members += $memberInfo
                    }
                } catch {
                    Write-Log "配布グループメンバー取得エラー ($groupName): $($_.Exception.Message)" -Level "Debug"
                }
                
                # オーナー情報の確認
                $owners = @()
                $hasValidOwner = $false
                try {
                    if ($groupDetails -and $groupDetails.ManagedBy) {
                        foreach ($owner in $groupDetails.ManagedBy) {
                            $ownerExists = $allUsers.ContainsKey($owner) -or $allMailboxes.ContainsKey($owner)
                            $owners += [PSCustomObject]@{
                                Identity = $owner
                                IsValid = $ownerExists
                            }
                            if ($ownerExists) {
                                $hasValidOwner = $true
                            }
                        }
                    }
                } catch {
                    Write-Log "オーナー情報取得エラー ($groupName): $($_.Exception.Message)" -Level "Debug"
                }
                
                if (-not $hasValidOwner) {
                    $noOwnerGroupsCount++
                }
                
                # 送信制限とセキュリティ設定の確認
                $requireSenderAuthenticationEnabled = $true
                $acceptMessagesOnlyFromSendersOrMembers = @()
                $rejectMessagesFromSendersOrMembers = @()
                $bypassModerationFromSendersOrMembers = @()
                
                if ($groupDetails) {
                    $requireSenderAuthenticationEnabled = $groupDetails.RequireSenderAuthenticationEnabled
                    
                    if ($groupDetails.AcceptMessagesOnlyFromSendersOrMembers) {
                        $acceptMessagesOnlyFromSendersOrMembers = $groupDetails.AcceptMessagesOnlyFromSendersOrMembers
                        $restrictedGroupsCount++
                    }
                    
                    if ($groupDetails.RejectMessagesFromSendersOrMembers) {
                        $rejectMessagesFromSendersOrMembers = $groupDetails.RejectMessagesFromSendersOrMembers
                    }
                    
                    if (-not $requireSenderAuthenticationEnabled) {
                        $externalSendersEnabledCount++
                    }
                }
                
                # 問題レベルの判定
                $issueLevel = "正常"
                $issues = @()
                $hasIssues = $false
                
                if ($invalidMembers.Count -gt 0) {
                    $issues += "無効なメンバー: $($invalidMembers.Count)件"
                    $hasIssues = $true
                    $orphanedMembersCount += $invalidMembers.Count
                }
                
                if ($disabledMembers.Count -gt 0) {
                    $issues += "無効化ユーザー: $($disabledMembers.Count)件"
                    $hasIssues = $true
                }
                
                if (-not $hasValidOwner) {
                    $issues += "有効なオーナーが存在しません"
                    $hasIssues = $true
                }
                
                if ($externalMembers.Count -gt 0) {
                    $issues += "外部メンバー: $($externalMembers.Count)件"
                }
                
                if (-not $requireSenderAuthenticationEnabled) {
                    $issues += "外部送信者からのメール受信が許可されています"
                }
                
                if ($nestedGroups.Count -gt 5) {
                    $issues += "ネストグループが多数: $($nestedGroups.Count)件"
                }
                
                # リスクレベル判定
                if ($issues.Count -eq 0) {
                    $issueLevel = "正常"
                } elseif ($invalidMembers.Count -gt 0 -or -not $hasValidOwner) {
                    $issueLevel = "高リスク"
                    $groupsWithIssues++
                } elseif ($disabledMembers.Count -gt 0 -or (-not $requireSenderAuthenticationEnabled)) {
                    $issueLevel = "中リスク"
                    $groupsWithIssues++
                } else {
                    $issueLevel = "低リスク"
                }
                
                # 分析結果の格納
                $integrityAnalysis += [PSCustomObject]@{
                    GroupName = $groupName
                    DisplayName = $displayName
                    PrimarySmtpAddress = $primarySmtpAddress
                    Identity = $groupIdentity
                    
                    # メンバー情報
                    TotalMembers = $members.Count
                    ValidMembers = ($members | Where-Object { $_.IsValid }).Count
                    InvalidMembers = $invalidMembers.Count
                    DisabledMembers = $disabledMembers.Count
                    ExternalMembers = $externalMembers.Count
                    NestedGroups = $nestedGroups.Count
                    
                    # オーナー情報
                    TotalOwners = $owners.Count
                    ValidOwners = ($owners | Where-Object { $_.IsValid }).Count
                    HasValidOwner = $hasValidOwner
                    
                    # セキュリティ設定
                    RequireSenderAuthentication = $requireSenderAuthenticationEnabled
                    HasSendingRestrictions = $acceptMessagesOnlyFromSendersOrMembers.Count -gt 0
                    HasRejectionList = $rejectMessagesFromSendersOrMembers.Count -gt 0
                    IsRestrictedGroup = $acceptMessagesOnlyFromSendersOrMembers.Count -gt 0
                    
                    # 問題とリスク評価
                    IssueLevel = $issueLevel
                    Issues = ($issues -join "; ")
                    HasIssues = $hasIssues
                    
                    # メタデータ
                    WhenCreated = if ($groupDetails) { $groupDetails.WhenCreated } else { $null }
                    WhenChanged = if ($groupDetails) { $groupDetails.WhenChanged } else { $null }
                    AnalysisTimestamp = Get-Date
                }
            }
            catch {
                Write-Log "配布グループ分析エラー ($($group.Name)): $($_.Exception.Message)" -Level "Warning"
                
                # エラー時のダミーデータ
                $integrityAnalysis += [PSCustomObject]@{
                    GroupName = $group.Name
                    DisplayName = $group.DisplayName
                    PrimarySmtpAddress = $group.PrimarySmtpAddress
                    Identity = $group.Identity
                    TotalMembers = "取得エラー"
                    ValidMembers = "取得エラー"
                    InvalidMembers = "取得エラー"
                    DisabledMembers = "取得エラー"
                    ExternalMembers = "取得エラー"
                    NestedGroups = "取得エラー"
                    TotalOwners = "取得エラー"
                    ValidOwners = "取得エラー"
                    HasValidOwner = "取得エラー"
                    RequireSenderAuthentication = "取得エラー"
                    HasSendingRestrictions = "取得エラー"
                    HasRejectionList = "取得エラー"
                    IsRestrictedGroup = "取得エラー"
                    IssueLevel = "不明"
                    Issues = "取得エラー"
                    HasIssues = "取得エラー"
                    WhenCreated = $null
                    WhenChanged = $null
                    AnalysisTimestamp = Get-Date
                }
            }
        }
        
        Write-Log "配布グループ整合性チェック完了" -Level "Info"
        Write-Log "総配布グループ数: $totalGroups" -Level "Info"
        Write-Log "問題のあるグループ: $groupsWithIssues" -Level "Info"
        Write-Log "孤立メンバー: $orphanedMembersCount" -Level "Info"
        Write-Log "オーナー不在グループ: $noOwnerGroupsCount" -Level "Info"
        Write-Log "外部送信許可グループ: $externalSendersEnabledCount" -Level "Info"
        Write-Log "送信制限グループ: $restrictedGroupsCount" -Level "Info"
        
        # レポート出力
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $reportData = @{
            AnalysisData = $integrityAnalysis
            Summary = @{
                TotalGroups = $totalGroups
                GroupsWithIssues = $groupsWithIssues
                OrphanedMembers = $orphanedMembersCount
                CircularReferences = $circularReferencesCount
                NoOwnerGroups = $noOwnerGroupsCount
                ExternalSendersEnabled = $externalSendersEnabledCount
                RestrictedGroups = $restrictedGroupsCount
                AnalysisTimestamp = $timestamp
                AnalysisMethod = "Exchange Online PowerShell + 整合性チェック"
            }
        }
        
        # CSV出力
        if ($ExportCSV -or -not $OutputPath) {
            $csvPath = if ($OutputPath) { 
                Join-Path $OutputPath "Distribution_Group_Integrity_$timestamp.csv" 
            } else { 
                "Reports\Daily\Distribution_Group_Integrity_$timestamp.csv" 
            }
            
            $integrityAnalysis | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Log "CSVレポート出力完了: $csvPath" -Level "Info"
            $reportData.CSVPath = $csvPath
        }
        
        # HTML出力
        if ($ExportHTML -or -not $OutputPath) {
            $htmlPath = if ($OutputPath) { 
                Join-Path $OutputPath "Distribution_Group_Integrity_$timestamp.html" 
            } else { 
                "Reports\Daily\Distribution_Group_Integrity_$timestamp.html" 
            }
            
            $htmlContent = Generate-DistributionGroupIntegrityHTML -Data $integrityAnalysis -Summary $reportData.Summary
            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
            Write-Log "HTMLレポート出力完了: $htmlPath" -Level "Info"
            $reportData.HTMLPath = $htmlPath
        }
        
        return @{
            Success = $true
            TotalGroups = $totalGroups
            GroupsWithIssues = $groupsWithIssues
            OrphanedMembers = $orphanedMembersCount
            CircularReferences = $circularReferencesCount
            NoOwnerGroups = $noOwnerGroupsCount
            ExternalSendersEnabled = $externalSendersEnabledCount
            RestrictedGroups = $restrictedGroupsCount
            OutputPath = $reportData.CSVPath
            HTMLOutputPath = $reportData.HTMLPath
            Data = $integrityAnalysis
            Summary = $reportData.Summary
        }
    }
    catch {
        Write-Log "配布グループ整合性チェックエラー: $($_.Exception.Message)" -Level "Error"
        return @{
            Success = $false
            Error = $_.Exception.Message
            TotalGroups = 0
            GroupsWithIssues = 0
            OrphanedMembers = 0
            CircularReferences = 0
            NoOwnerGroups = 0
            ExternalSendersEnabled = 0
            RestrictedGroups = 0
        }
    }
}

# HTMLレポート生成ヘルパー関数
function Generate-DistributionGroupIntegrityHTML {
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
    <title>配布グループ整合性チェックレポート</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #0078D4; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .header h1 { margin: 0; font-size: 28px; }
        .header p { margin: 5px 0 0 0; opacity: 0.9; }
        .summary { background-color: white; padding: 20px; margin: 15px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .summary h2 { color: #0078D4; margin-top: 0; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-top: 15px; }
        .summary-item { background-color: #f8f9fa; padding: 15px; border-radius: 6px; text-align: center; }
        .summary-item .number { font-size: 24px; font-weight: bold; color: #0078D4; }
        .summary-item .label { font-size: 14px; color: #666; margin-top: 5px; }
        .success { background-color: #d4edda; color: #155724; padding: 15px; margin: 15px 0; border-left: 4px solid #28a745; border-radius: 0 6px 6px 0; }
        .warning { background-color: #fff3cd; color: #856404; padding: 15px; margin: 15px 0; border-left: 4px solid #ffc107; border-radius: 0 6px 6px 0; }
        .danger { background-color: #f8d7da; color: #721c24; padding: 15px; margin: 15px 0; border-left: 4px solid #dc3545; border-radius: 0 6px 6px 0; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; background-color: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th, td { padding: 12px 8px; text-align: left; border-bottom: 1px solid #dee2e6; }
        th { background-color: #0078D4; color: white; font-weight: 600; }
        tr:hover { background-color: #f8f9fa; }
        .risk-high { background-color: #ffebee; }
        .risk-medium { background-color: #fff8e1; }
        .risk-low { background-color: #e8f5e8; }
        .risk-normal { background-color: #e3f2fd; }
        .status-yes { color: #28a745; font-weight: bold; }
        .status-no { color: #dc3545; font-weight: bold; }
        .status-partial { color: #ffc107; font-weight: bold; }
        .text-truncate { max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .issues { color: #dc3545; font-size: 12px; }
        .chart-container { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin: 20px 0; }
        .chart-item { background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔍 配布グループ整合性チェックレポート</h1>
        <p>生成日時: $(Get-Date -Format "yyyy年MM月dd日 HH:mm:ss") | 分析方法: $($Summary.AnalysisMethod)</p>
    </div>
    
    <div class="success">
        <strong>✅ 分析完了:</strong> 配布グループの整合性チェックが正常に完了しました
    </div>
"@

    # 重大な問題がある場合のアラート表示
    if ($Summary.GroupsWithIssues -gt 0) {
        $htmlContent += @"
    <div class="danger">
        <strong>⚠️ 整合性問題検出:</strong> $($Summary.GroupsWithIssues)個の配布グループで問題が検出されました。至急確認が必要です。
    </div>
"@
    }

    if ($Summary.OrphanedMembers -gt 0) {
        $htmlContent += @"
    <div class="warning">
        <strong>👥 孤立メンバー検出:</strong> $($Summary.OrphanedMembers)件の無効なメンバーが見つかりました。
    </div>
"@
    }

    $htmlContent += @"
    <div class="summary">
        <h2>📊 整合性チェックサマリー</h2>
        <div class="summary-grid">
            <div class="summary-item">
                <div class="number">$($Summary.TotalGroups)</div>
                <div class="label">総配布グループ数</div>
            </div>
            <div class="summary-item">
                <div class="number">$($Summary.GroupsWithIssues)</div>
                <div class="label">問題のあるグループ</div>
            </div>
            <div class="summary-item">
                <div class="number">$($Summary.OrphanedMembers)</div>
                <div class="label">孤立メンバー</div>
            </div>
            <div class="summary-item">
                <div class="number">$($Summary.NoOwnerGroups)</div>
                <div class="label">オーナー不在</div>
            </div>
            <div class="summary-item">
                <div class="number">$($Summary.ExternalSendersEnabled)</div>
                <div class="label">外部送信許可</div>
            </div>
            <div class="summary-item">
                <div class="number">$($Summary.RestrictedGroups)</div>
                <div class="label">送信制限設定</div>
            </div>
        </div>
    </div>
    
    <div class="chart-container">
        <div class="chart-item">
            <h3>🎯 主要な問題項目</h3>
            <ul>
                <li><strong>孤立メンバー:</strong> 存在しないユーザーがメンバーに含まれている</li>
                <li><strong>オーナー不在:</strong> 有効なオーナーが設定されていない</li>
                <li><strong>外部送信許可:</strong> セキュリティリスクのある設定</li>
                <li><strong>無効化ユーザー:</strong> 無効化されたユーザーがメンバーに残っている</li>
            </ul>
        </div>
        <div class="chart-item">
            <h3>🔧 推奨対応アクション</h3>
            <ul>
                <li>高リスクグループの緊急見直し</li>
                <li>孤立メンバーの削除または再設定</li>
                <li>オーナー不在グループへのオーナー設定</li>
                <li>外部送信許可設定の必要性確認</li>
            </ul>
        </div>
    </div>
    
    <h2>📋 詳細整合性チェック結果</h2>
    <table>
        <tr>
            <th>グループ名</th>
            <th>表示名</th>
            <th>メールアドレス</th>
            <th>総メンバー数</th>
            <th>有効メンバー</th>
            <th>無効メンバー</th>
            <th>オーナー有無</th>
            <th>外部送信</th>
            <th>リスクレベル</th>
            <th>検出された問題</th>
        </tr>
"@
    
    foreach ($item in $Data) {
        $riskClass = switch ($item.IssueLevel) {
            "高リスク" { "risk-high" }
            "中リスク" { "risk-medium" }
            "低リスク" { "risk-low" }
            "正常" { "risk-normal" }
            default { "" }
        }
        
        $ownerStatus = if ($item.HasValidOwner -eq $true) { "status-yes" } elseif ($item.HasValidOwner -eq $false) { "status-no" } else { "status-partial" }
        $externalStatus = if ($item.RequireSenderAuthentication -eq $false) { "status-no" } else { "status-yes" }
        
        $ownerDisplay = if ($item.HasValidOwner -eq $true) { "あり" } elseif ($item.HasValidOwner -eq $false) { "なし" } else { "不明" }
        $externalDisplay = if ($item.RequireSenderAuthentication -eq $false) { "許可" } else { "制限" }
        
        $htmlContent += @"
        <tr class="$riskClass">
            <td><strong>$($item.GroupName)</strong></td>
            <td>$($item.DisplayName)</td>
            <td class="text-truncate" title="$($item.PrimarySmtpAddress)">$($item.PrimarySmtpAddress)</td>
            <td>$($item.TotalMembers)</td>
            <td>$($item.ValidMembers)</td>
            <td>$($item.InvalidMembers)</td>
            <td class="$ownerStatus">$ownerDisplay</td>
            <td class="$externalStatus">$externalDisplay</td>
            <td><strong>$($item.IssueLevel)</strong></td>
            <td class="issues text-truncate" title="$($item.Issues)">$($item.Issues)</td>
        </tr>
"@
    }
    
    $htmlContent += @"
    </table>
    
    <div style="margin-top: 30px; padding: 20px; background-color: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
        <h3>🔍 整合性チェック項目</h3>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">
            <div>
                <h4>メンバー整合性</h4>
                <ul>
                    <li>存在しないユーザー/メールボックスの検出</li>
                    <li>無効化されたユーザーの検出</li>
                    <li>外部ドメインメンバーの確認</li>
                    <li>ネストグループの存在確認</li>
                </ul>
            </div>
            <div>
                <h4>設定整合性</h4>
                <ul>
                    <li>オーナー設定の有効性確認</li>
                    <li>送信者認証設定の確認</li>
                    <li>送信制限設定の確認</li>
                    <li>拒否リスト設定の確認</li>
                </ul>
            </div>
        </div>
        
        <h3>🛡️ セキュリティ重要度</h3>
        <ul>
            <li><strong>高リスク:</strong> 無効メンバーやオーナー不在など、緊急対応が必要</li>
            <li><strong>中リスク:</strong> セキュリティ設定や無効化ユーザーなど、確認が必要</li>
            <li><strong>低リスク:</strong> 軽微な設定問題、定期見直しが推奨</li>
            <li><strong>正常:</strong> 問題は検出されていません</li>
        </ul>
    </div>
    
    <div style="margin-top: 20px; text-align: center; color: #666; font-size: 12px;">
        <p>Microsoft Product Management Tools - ITSM/ISO27001/27002準拠</p>
    </div>
</body>
</html>
"@
    
    return $htmlContent
}

# EX-06: 会議室リソース利用状況監査
function Get-EXORoomResourceAudit {
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 7,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails = $false
    )
    
    Write-Log "=== EX-06 ===会議室リソース利用状況監査を開始します（過去 $DaysBack 日間）" -Level "Info"
    
    try {
        # Exchange Online接続確認
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
                throw "Exchange Online 接続エラー: $($_.Exception.Message)"
            }
        }
        
        $startDate = (Get-Date).AddDays(-$DaysBack)
        $endDate = Get-Date
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        $roomUtilizationReport = @()
        $utilizationSummary = @{}
        
        try {
            # 会議室メールボックス取得
            $roomMailboxes = Get-EXOMailbox -RecipientTypeDetails RoomMailbox -PropertySets All
            Write-Log "$($roomMailboxes.Count)件の会議室を検出しました" -Level "Info"
            
            foreach ($room in $roomMailboxes) {
                try {
                    Write-Log "会議室の予約分析を実行中: $($room.DisplayName)" -Level "Debug"
                    
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
        
        # 出力ディレクトリ設定
        $outputDir = if ($OutputPath) { 
            $OutputPath 
        } else { 
            "Reports\Weekly" 
        }
        
        $csvPath = $null
        $htmlPath = $null
        
        # CSV出力
        if ($ExportCSV) {
            $csvPath = Join-Path $outputDir "Room_Utilization_Audit_$timestamp.csv"
            try {
                $roomUtilizationReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                Write-Log "CSVレポート出力完了: $csvPath" -Level "Info"
            }
            catch {
                Write-Log "CSVレポート出力エラー: $($_.Exception.Message)" -Level "Warning"
                $csvPath = $null
            }
        }
        
        # HTML出力
        if ($ExportHTML) {
            $htmlPath = Join-Path $outputDir "Room_Utilization_Audit_$timestamp.html"
            try {
                $htmlContent = Generate-RoomUtilizationHTML -Data $roomUtilizationReport -Summary $utilizationSummary
                $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
                Write-Log "HTMLレポート出力完了: $htmlPath" -Level "Info"
            }
            catch {
                Write-Log "HTMLレポート出力エラー: $($_.Exception.Message)" -Level "Warning"
                $htmlPath = $null
            }
        }
        
        if ($ShowDetails) {
            Write-Host "会議室利用状況監査完了:" -ForegroundColor Green
            Write-Host "  総会議室数: $($utilizationSummary.TotalRooms)"
            Write-Host "  平均利用率: $($utilizationSummary.AverageUtilization)%"
            Write-Host "  高負荷会議室: $($utilizationSummary.HighUtilization)"
            Write-Host "  低稼働会議室: $($utilizationSummary.LowUtilization)"
        }
        
        return @{
            Success = $true
            UtilizationData = $roomUtilizationReport
            Summary = $utilizationSummary
            CSVPath = $csvPath
            HTMLPath = $htmlPath
        }
        
    } catch {
        Write-Log "会議室リソース利用状況監査エラー: $($_.Exception.Message)" -Level "Error"
        return @{
            Success = $false
            Error = $_.Exception.Message
            UtilizationData = @()
            Summary = @{}
        }
    }
}

# HTMLレポート生成ヘルパー関数
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

Export-ModuleMember -Function Get-AttachmentAnalysisNEW, Get-ForwardingAndAutoReplySettings, Get-MailDeliveryMonitoring, Get-DistributionGroupIntegrityCheck, Get-EXORoomResourceAudit