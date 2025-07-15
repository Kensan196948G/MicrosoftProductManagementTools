# ================================================================================
# ExchangeManagementData.psm1
# Exchange Online管理機能用実データ取得モジュール
# Microsoft 365 E3ライセンス対応版
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\ErrorHandling.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\Authentication.psm1" -Force

# メールボックス分析実データ取得（GUI用詳細版）
function Get-MailboxCapacityRealData {
    try {
        Write-Log "Exchange Onlineメールボックス容量分析を開始..." -Level "Info"
        
        $mailboxData = @()
        
        # Exchange Online接続確認
        if (-not (Test-ExchangeOnlineConnection)) {
            throw "Exchange Onlineに接続されていません"
        }
        
        # メールボックス一覧取得
        $mailboxes = Get-Mailbox -ResultSize Unlimited
        Write-Log "メールボックス数: $($mailboxes.Count)" -Level "Info"
        
        foreach ($mailbox in $mailboxes) {
            try {
                # メールボックス統計情報取得
                $stats = Get-MailboxStatistics -Identity $mailbox.Identity -ErrorAction SilentlyContinue
                
                if ($stats) {
                    # サイズ計算
                    $totalSizeGB = 0
                    $deletedSizeGB = 0
                    
                    if ($stats.TotalItemSize) {
                        $sizeString = $stats.TotalItemSize.ToString()
                        if ($sizeString -match '(\d+(?:\.\d+)?)\s*(GB|MB|KB|B)') {
                            $size = [double]$matches[1]
                            $unit = $matches[2]
                            
                            $totalSizeGB = switch ($unit) {
                                'GB' { $size }
                                'MB' { $size / 1024 }
                                'KB' { $size / 1024 / 1024 }
                                'B'  { $size / 1024 / 1024 / 1024 }
                            }
                        }
                    }
                    
                    if ($stats.TotalDeletedItemSize) {
                        $deletedString = $stats.TotalDeletedItemSize.ToString()
                        if ($deletedString -match '(\d+(?:\.\d+)?)\s*(GB|MB|KB|B)') {
                            $size = [double]$matches[1]
                            $unit = $matches[2]
                            
                            $deletedSizeGB = switch ($unit) {
                                'GB' { $size }
                                'MB' { $size / 1024 }
                                'KB' { $size / 1024 / 1024 }
                                'B'  { $size / 1024 / 1024 / 1024 }
                            }
                        }
                    }
                    
                    # クォータ取得
                    $quotaGB = 100  # デフォルト100GB（E3）
                    if ($mailbox.ProhibitSendQuota -and $mailbox.ProhibitSendQuota -ne "Unlimited") {
                        $quotaString = $mailbox.ProhibitSendQuota.ToString()
                        if ($quotaString -match '(\d+(?:\.\d+)?)\s*(GB|MB)') {
                            $quota = [double]$matches[1]
                            $unit = $matches[2]
                            $quotaGB = if ($unit -eq 'GB') { $quota } else { $quota / 1024 }
                        }
                    }
                    
                    $usagePercent = if ($quotaGB -gt 0) { 
                        [Math]::Round(($totalSizeGB / $quotaGB) * 100, 2) 
                    } else { 0 }
                    
                    # フォルダー統計
                    $folderStats = Get-MailboxFolderStatistics -Identity $mailbox.Identity -FolderScope All -ErrorAction SilentlyContinue
                    $largestFolders = $folderStats | Sort-Object FolderSize -Descending | Select-Object -First 5
                    
                    $mailboxData += [PSCustomObject]@{
                        メールボックス = $mailbox.DisplayName
                        メールアドレス = $mailbox.PrimarySmtpAddress
                        部署 = if ($mailbox.Department) { $mailbox.Department } else { "未設定" }
                        使用容量GB = [Math]::Round($totalSizeGB, 2)
                        削除済みGB = [Math]::Round($deletedSizeGB, 2)
                        制限容量GB = $quotaGB
                        使用率 = $usagePercent
                        アイテム数 = $stats.ItemCount
                        削除済み数 = $stats.DeletedItemCount
                        フォルダー数 = $folderStats.Count
                        最大フォルダー = if ($largestFolders[0]) { $largestFolders[0].Name } else { "N/A" }
                        最終ログオン = if ($stats.LastLogonTime) { $stats.LastLogonTime.ToString("yyyy-MM-dd HH:mm") } else { "未ログオン" }
                        作成日 = $mailbox.WhenCreated.ToString("yyyy-MM-dd")
                        状態 = if ($usagePercent -ge 95) { "容量不足" }
                               elseif ($usagePercent -ge 80) { "警告" }
                               else { "正常" }
                        推奨事項 = if ($usagePercent -ge 95) { "アーカイブまたは削除が必要" }
                                  elseif ($usagePercent -ge 80) { "容量監視を強化" }
                                  elseif ($stats.DeletedItemCount -gt 10000) { "削除済みアイテムの完全削除を推奨" }
                                  else { "問題なし" }
                    }
                }
            }
            catch {
                Write-Log "メールボックス $($mailbox.DisplayName) の情報取得エラー: $($_.Exception.Message)" -Level "Warning"
            }
        }
        
        Write-Log "メールボックス容量分析完了（$($mailboxData.Count)件）" -Level "Info"
        return $mailboxData
    }
    catch {
        Write-Log "メールボックス容量分析エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# メールフロー分析実データ取得
function Get-MailFlowAnalysisData {
    try {
        Write-Log "メールフロー分析を開始..." -Level "Info"
        
        # メッセージトレース（過去48時間）
        $startDate = (Get-Date).AddDays(-2)
        $endDate = Get-Date
        
        $messageTrace = Get-MessageTrace -StartDate $startDate -EndDate $endDate -PageSize 5000
        
        # メールフロー統計の集計
        $flowStats = @{
            TotalMessages = $messageTrace.Count
            SuccessfulDelivery = ($messageTrace | Where-Object { $_.Status -eq "Delivered" }).Count
            Failed = ($messageTrace | Where-Object { $_.Status -eq "Failed" }).Count
            Pending = ($messageTrace | Where-Object { $_.Status -eq "Pending" }).Count
            Quarantined = ($messageTrace | Where-Object { $_.Status -eq "Quarantined" }).Count
        }
        
        # 送信者別統計
        $senderStats = $messageTrace | Group-Object SenderAddress | 
            Sort-Object Count -Descending | 
            Select-Object -First 20 |
            ForEach-Object {
                [PSCustomObject]@{
                    送信者 = $_.Name
                    メール数 = $_.Count
                    成功率 = [Math]::Round((($_.Group | Where-Object { $_.Status -eq "Delivered" }).Count / $_.Count) * 100, 2)
                }
            }
        
        # 受信者別統計
        $recipientStats = $messageTrace | Group-Object RecipientAddress | 
            Sort-Object Count -Descending | 
            Select-Object -First 20 |
            ForEach-Object {
                [PSCustomObject]@{
                    受信者 = $_.Name
                    メール数 = $_.Count
                    成功率 = [Math]::Round((($_.Group | Where-Object { $_.Status -eq "Delivered" }).Count / $_.Count) * 100, 2)
                }
            }
        
        # 時間帯別統計
        $hourlyStats = $messageTrace | ForEach-Object {
            [PSCustomObject]@{
                Hour = $_.Received.Hour
                Message = $_
            }
        } | Group-Object Hour | Sort-Object Name | ForEach-Object {
            [PSCustomObject]@{
                時間帯 = "$($_.Name):00"
                メール数 = $_.Count
            }
        }
        
        # ドメイン別統計
        $domainStats = $messageTrace | ForEach-Object {
            $domain = if ($_.SenderAddress -match '@(.+)$') { $matches[1] } else { "不明" }
            [PSCustomObject]@{
                Domain = $domain
                IsExternal = $domain -ne "miraiconst.onmicrosoft.com"
            }
        } | Group-Object Domain | ForEach-Object {
            [PSCustomObject]@{
                ドメイン = $_.Name
                メール数 = $_.Count
                種別 = if ($_.Group[0].IsExternal) { "外部" } else { "内部" }
            }
        } | Sort-Object メール数 -Descending | Select-Object -First 20
        
        return [PSCustomObject]@{
            概要 = $flowStats
            送信者トップ20 = $senderStats
            受信者トップ20 = $recipientStats
            時間帯別 = $hourlyStats
            ドメイン別 = $domainStats
            分析期間 = "$($startDate.ToString('yyyy-MM-dd HH:mm')) ～ $($endDate.ToString('yyyy-MM-dd HH:mm'))"
        }
    }
    catch {
        Write-Log "メールフロー分析エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# スパム対策分析実データ取得
function Get-AntiSpamAnalysisData {
    try {
        Write-Log "スパム対策分析を開始..." -Level "Info"
        
        # ホストコンテンツフィルターポリシー取得
        $spamPolicies = Get-HostedContentFilterPolicy
        $policyData = @()
        
        foreach ($policy in $spamPolicies) {
            $policyData += [PSCustomObject]@{
                ポリシー名 = $policy.Name
                有効 = $policy.Enabled
                スパム閾値 = $policy.SpamAction
                高信頼度スパム = $policy.HighConfidenceSpamAction
                フィッシング = $policy.PhishSpamAction
                バルクメール閾値 = $policy.BulkThreshold
                検疫期間 = "$($policy.QuarantineRetentionPeriod) 日"
                セーフリスト = @{
                    許可送信者 = $policy.AllowedSenders.Count
                    許可ドメイン = $policy.AllowedSenderDomains.Count
                    ブロック送信者 = $policy.BlockedSenders.Count
                    ブロックドメイン = $policy.BlockedSenderDomains.Count
                }
                詳細設定 = @{
                    画像リンク = $policy.IncreaseScoreWithImageLinks
                    数値IP = $policy.IncreaseScoreWithNumericIps
                    リダイレクトURL = $policy.IncreaseScoreWithRedirectToOtherPort
                    安全リンク = $policy.EnableSafeList
                }
            }
        }
        
        # スパム統計（過去7日間）
        $startDate = (Get-Date).AddDays(-7)
        $messageTrace = Get-MessageTrace -StartDate $startDate -EndDate (Get-Date) -PageSize 5000
        
        $spamStats = @{
            総メール数 = $messageTrace.Count
            スパム検出数 = ($messageTrace | Where-Object { $_.Status -eq "FilteredAsSpam" }).Count
            フィッシング検出数 = ($messageTrace | Where-Object { $_.Status -match "Phish" }).Count
            マルウェア検出数 = ($messageTrace | Where-Object { $_.Status -match "Malware" }).Count
            検疫数 = ($messageTrace | Where-Object { $_.Status -eq "Quarantined" }).Count
        }
        
        $spamStats['スパム率'] = if ($spamStats.総メール数 -gt 0) {
            [Math]::Round(($spamStats.スパム検出数 / $spamStats.総メール数) * 100, 2)
        } else { 0 }
        
        # 送信者別スパム統計
        $spamSenders = $messageTrace | Where-Object { $_.Status -eq "FilteredAsSpam" } | 
            Group-Object SenderAddress | 
            Sort-Object Count -Descending | 
            Select-Object -First 10 |
            ForEach-Object {
                [PSCustomObject]@{
                    送信者 = $_.Name
                    スパム数 = $_.Count
                }
            }
        
        return [PSCustomObject]@{
            ポリシー = $policyData
            統計 = $spamStats
            スパム送信者TOP10 = $spamSenders
            推奨事項 = Get-AntiSpamRecommendations -SpamRate $spamStats.スパム率 -Policies $policyData
        }
    }
    catch {
        Write-Log "スパム対策分析エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# メール配信分析実データ取得
function Get-MailDeliveryAnalysisData {
    try {
        Write-Log "メール配信分析を開始..." -Level "Info"
        
        # 過去24時間の配信統計
        $startDate = (Get-Date).AddHours(-24)
        $endDate = Get-Date
        
        $messages = Get-MessageTrace -StartDate $startDate -EndDate $endDate -PageSize 5000
        
        # 配信ステータス別集計
        $deliveryStats = $messages | Group-Object Status | ForEach-Object {
            [PSCustomObject]@{
                ステータス = switch ($_.Name) {
                    "Delivered" { "配信成功" }
                    "Failed" { "配信失敗" }
                    "Pending" { "配信保留" }
                    "Quarantined" { "検疫" }
                    "FilteredAsSpam" { "スパムフィルター" }
                    "Expanded" { "配布グループ展開" }
                    default { $_.Name }
                }
                件数 = $_.Count
                割合 = [Math]::Round(($_.Count / $messages.Count) * 100, 2)
            }
        } | Sort-Object 件数 -Descending
        
        # 配信遅延分析
        $delayedMessages = @()
        foreach ($msg in $messages | Where-Object { $_.Status -eq "Delivered" }) {
            if ($msg.Received -and $msg.ReceivedTime) {
                $delay = ($msg.ReceivedTime - $msg.Received).TotalMinutes
                if ($delay -gt 5) {  # 5分以上の遅延
                    $delayedMessages += [PSCustomObject]@{
                        送信者 = $msg.SenderAddress
                        受信者 = $msg.RecipientAddress
                        件名 = $msg.Subject
                        遅延時間 = [Math]::Round($delay, 2)
                        サイズ = $msg.Size
                    }
                }
            }
        }
        
        # 配信失敗分析
        $failedMessages = $messages | Where-Object { $_.Status -eq "Failed" } | 
            Select-Object -First 100 |
            ForEach-Object {
                [PSCustomObject]@{
                    送信者 = $_.SenderAddress
                    受信者 = $_.RecipientAddress
                    件名 = $_.Subject
                    理由 = if ($_.Detail) { $_.Detail } else { "不明" }
                    時刻 = $_.Received.ToString("yyyy-MM-dd HH:mm")
                }
            }
        
        # サイズ別配信統計
        $sizeStats = $messages | ForEach-Object {
            $sizeCategory = if ($_.Size -lt 1024) { "< 1KB" }
                           elseif ($_.Size -lt 102400) { "1KB-100KB" }
                           elseif ($_.Size -lt 1048576) { "100KB-1MB" }
                           elseif ($_.Size -lt 10485760) { "1MB-10MB" }
                           else { "> 10MB" }
            
            [PSCustomObject]@{
                Category = $sizeCategory
                Size = $_.Size
                Status = $_.Status
            }
        } | Group-Object Category | ForEach-Object {
            $successCount = ($_.Group | Where-Object { $_.Status -eq "Delivered" }).Count
            [PSCustomObject]@{
                サイズ区分 = $_.Name
                メール数 = $_.Count
                成功率 = if ($_.Count -gt 0) { [Math]::Round(($successCount / $_.Count) * 100, 2) } else { 0 }
            }
        }
        
        return [PSCustomObject]@{
            配信統計 = $deliveryStats
            遅延メール = $delayedMessages | Sort-Object 遅延時間 -Descending | Select-Object -First 20
            失敗メール = $failedMessages
            サイズ別統計 = $sizeStats
            サマリー = @{
                総配信数 = $messages.Count
                成功率 = [Math]::Round((($messages | Where-Object { $_.Status -eq "Delivered" }).Count / $messages.Count) * 100, 2)
                平均サイズKB = [Math]::Round(($messages | Measure-Object -Property Size -Average).Average / 1024, 2)
                遅延率 = [Math]::Round(($delayedMessages.Count / $messages.Count) * 100, 2)
            }
        }
    }
    catch {
        Write-Log "メール配信分析エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# ヘルパー関数
function Get-AntiSpamRecommendations {
    param(
        [double]$SpamRate,
        [array]$Policies
    )
    
    $recommendations = @()
    
    if ($SpamRate -gt 10) {
        $recommendations += "スパム検出率が高いため、フィルター設定の見直しを推奨"
    }
    
    foreach ($policy in $Policies) {
        if ($policy.BulkThreshold -gt 7) {
            $recommendations += "$($policy.ポリシー名): バルクメール閾値を下げることを検討"
        }
        if ($policy.セーフリスト.ブロック送信者 -eq 0) {
            $recommendations += "$($policy.ポリシー名): 既知のスパム送信者をブロックリストに追加"
        }
    }
    
    if ($recommendations.Count -eq 0) {
        $recommendations += "現在の設定は適切です。定期的な見直しを継続してください。"
    }
    
    return $recommendations
}

# エクスポート
Export-ModuleMember -Function @(
    'Get-MailboxCapacityRealData',
    'Get-MailFlowAnalysisData',
    'Get-AntiSpamAnalysisData',
    'Get-MailDeliveryAnalysisData'
)