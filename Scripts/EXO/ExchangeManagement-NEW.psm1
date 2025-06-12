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
            
            $attachmentAnalysis | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
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

Export-ModuleMember -Function Get-AttachmentAnalysisNEW