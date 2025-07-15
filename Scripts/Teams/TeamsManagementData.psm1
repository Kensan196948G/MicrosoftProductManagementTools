# ================================================================================
# TeamsManagementData.psm1
# Teams管理機能用ダミーデータ生成モジュール
# Microsoft Teams APIはE5ライセンスが必要なため、ダミーデータで実装
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\ErrorHandling.psm1" -Force

# Teams使用状況ダミーデータ生成
function Get-TeamsUsageData {
    try {
        Write-Log "Teams使用状況データを生成中（ダミーデータ）..." -Level "Info"
        
        $usageData = @()
        $departments = @("営業部", "開発部", "総務部", "マーケティング部", "経理部", "人事部", "IT部")
        
        # ユーザー別使用状況
        for ($i = 1; $i -le 100; $i++) {
            $dept = $departments | Get-Random
            $lastActivity = (Get-Date).AddDays(-(Get-Random -Minimum 0 -Maximum 30))
            $messagesPosted = Get-Random -Minimum 0 -Maximum 500
            $repliesPosted = Get-Random -Minimum 0 -Maximum 300
            $urgentMessages = Get-Random -Minimum 0 -Maximum 20
            $meetingsAttended = Get-Random -Minimum 0 -Maximum 50
            $callsMade = Get-Random -Minimum 0 -Maximum 100
            
            $activityScore = [Math]::Round(($messagesPosted + $repliesPosted * 2 + $meetingsAttended * 5 + $callsMade * 3) / 100, 2)
            
            $usageData += [PSCustomObject]@{
                ユーザー名 = "ユーザー$i"
                メールアドレス = "user$i@miraiconst.onmicrosoft.com"
                部署 = $dept
                最終アクティビティ = $lastActivity.ToString("yyyy-MM-dd HH:mm")
                投稿メッセージ数 = $messagesPosted
                返信数 = $repliesPosted
                緊急メッセージ数 = $urgentMessages
                会議参加数 = $meetingsAttended
                通話数 = $callsMade
                アクティビティスコア = $activityScore
                使用頻度 = if ($activityScore -gt 10) { "高" }
                          elseif ($activityScore -gt 5) { "中" }
                          else { "低" }
                推奨事項 = if ($activityScore -lt 3) { "Teams活用促進トレーニングを推奨" }
                          elseif ($messagesPosted -gt 300) { "効率的なコミュニケーション方法の見直しを推奨" }
                          else { "適切に活用されています" }
            }
        }
        
        # チーム別使用状況
        $teamUsage = @()
        $teamNames = @("営業チーム", "開発プロジェクトA", "開発プロジェクトB", "経営企画", "品質管理", "カスタマーサポート", "新規事業開発", "マーケティング戦略")
        
        foreach ($team in $teamNames) {
            $memberCount = Get-Random -Minimum 5 -Maximum 50
            $activeMembers = Get-Random -Minimum 3 -Maximum $memberCount
            $channelCount = Get-Random -Minimum 3 -Maximum 15
            $messagesPerDay = Get-Random -Minimum 10 -Maximum 200
            $filesShared = Get-Random -Minimum 20 -Maximum 500
            
            $teamUsage += [PSCustomObject]@{
                チーム名 = $team
                メンバー数 = $memberCount
                アクティブメンバー = $activeMembers
                チャネル数 = $channelCount
                日平均メッセージ数 = $messagesPerDay
                共有ファイル数 = $filesShared
                作成日 = (Get-Date).AddDays(-(Get-Random -Minimum 30 -Maximum 365)).ToString("yyyy-MM-dd")
                最終活動 = (Get-Date).AddHours(-(Get-Random -Minimum 1 -Maximum 72)).ToString("yyyy-MM-dd HH:mm")
                活動レベル = if ($messagesPerDay -gt 100) { "非常に活発" }
                            elseif ($messagesPerDay -gt 50) { "活発" }
                            elseif ($messagesPerDay -gt 20) { "普通" }
                            else { "低活動" }
            }
        }
        
        return [PSCustomObject]@{
            ユーザー使用状況 = $usageData
            チーム使用状況 = $teamUsage
            全体統計 = @{
                総ユーザー数 = $usageData.Count
                アクティブユーザー数 = ($usageData | Where-Object { $_.使用頻度 -ne "低" }).Count
                総チーム数 = $teamUsage.Count
                アクティブチーム数 = ($teamUsage | Where-Object { $_.活動レベル -ne "低活動" }).Count
                平均アクティビティスコア = [Math]::Round(($usageData | Measure-Object -Property アクティビティスコア -Average).Average, 2)
            }
        }
    }
    catch {
        Write-Log "Teams使用状況データ生成エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# Teams設定分析ダミーデータ生成
function Get-TeamsConfigAnalysisData {
    try {
        Write-Log "Teams設定分析データを生成中（ダミーデータ）..." -Level "Info"
        
        # グローバル設定
        $globalSettings = [PSCustomObject]@{
            外部アクセス = @{
                許可 = $true
                許可ドメイン = @("partner1.com", "partner2.com", "consulting.co.jp")
                ブロックドメイン = @("competitor.com", "spam-domain.net")
            }
            ゲストアクセス = @{
                許可 = $true
                チーム作成許可 = $false
                チャネル作成許可 = $false
                メッセージ削除許可 = $false
            }
            会議ポリシー = @{
                匿名参加許可 = $true
                自動参加許可 = $true
                録画許可 = $true
                画面共有モード = "全画面"
                最大参加者数 = 250
            }
            メッセージングポリシー = @{
                メッセージ削除許可 = $true
                メッセージ編集許可 = $true
                既読確認 = $true
                Giphy許可 = $true
                ミーム許可 = $false
            }
        }
        
        # チーム別設定
        $teamSettings = @()
        $teamNames = @("営業チーム", "開発プロジェクトA", "開発プロジェクトB", "経営企画", "品質管理")
        
        foreach ($team in $teamNames) {
            $teamSettings += [PSCustomObject]@{
                チーム名 = $team
                プライバシー = @("パブリック", "プライベート") | Get-Random
                ゲスト許可 = (Get-Random -Minimum 0 -Maximum 2) -eq 1
                メンション許可 = @{
                    チーム = $true
                    チャネル = $true
                    オーナー = $true
                    メンバー = (Get-Random -Minimum 0 -Maximum 2) -eq 1
                }
                チャネル設定 = @{
                    メンバー作成許可 = (Get-Random -Minimum 0 -Maximum 2) -eq 1
                    プライベートチャネル許可 = $true
                    アプリ許可 = $true
                    タブ追加許可 = $true
                }
                モデレーション = @{
                    有効 = (Get-Random -Minimum 0 -Maximum 3) -eq 1
                    モデレーター数 = Get-Random -Minimum 0 -Maximum 3
                }
                コンプライアンス評価 = @("準拠", "一部準拠", "要改善") | Get-Random
            }
        }
        
        # ポリシー分析
        $policyAnalysis = [PSCustomObject]@{
            セキュリティリスク = @(
                if ($globalSettings.外部アクセス.許可) { "外部アクセスが有効になっています" }
                if ($globalSettings.ゲストアクセス.許可) { "ゲストアクセスが有効になっています" }
                if ($globalSettings.会議ポリシー.匿名参加許可) { "匿名ユーザーの会議参加が許可されています" }
            )
            推奨事項 = @(
                "定期的なゲストアクセス権限の見直し",
                "外部ドメインホワイトリストの最小化",
                "会議録画データの保存期間ポリシー設定",
                "機密情報を扱うチームでのゲストアクセス無効化"
            )
            コンプライアンススコア = Get-Random -Minimum 70 -Maximum 95
        }
        
        return [PSCustomObject]@{
            グローバル設定 = $globalSettings
            チーム別設定 = $teamSettings
            ポリシー分析 = $policyAnalysis
        }
    }
    catch {
        Write-Log "Teams設定分析データ生成エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# 会議品質分析ダミーデータ生成
function Get-MeetingQualityAnalysisData {
    try {
        Write-Log "会議品質分析データを生成中（ダミーデータ）..." -Level "Info"
        
        $meetingData = @()
        $organizerNames = @("会議主催者A", "会議主催者B", "会議主催者C", "会議主催者D", "会議主催者E")
        
        # 過去30日間の会議データ
        for ($i = 1; $i -le 200; $i++) {
            $startTime = (Get-Date).AddDays(-(Get-Random -Minimum 0 -Maximum 30)).AddHours(-(Get-Random -Minimum 0 -Maximum 8))
            $duration = Get-Random -Minimum 15 -Maximum 180
            $participantCount = Get-Random -Minimum 2 -Maximum 50
            
            # 品質メトリクス
            $audioQuality = Get-Random -Minimum 1 -Maximum 100
            $videoQuality = Get-Random -Minimum 1 -Maximum 100
            $screenShareQuality = Get-Random -Minimum 1 -Maximum 100
            $networkLatency = Get-Random -Minimum 10 -Maximum 200
            $packetLoss = [Math]::Round((Get-Random -Minimum 0 -Maximum 50) / 10, 2)
            $jitter = Get-Random -Minimum 5 -Maximum 50
            
            $overallQuality = [Math]::Round(($audioQuality + $videoQuality + $screenShareQuality) / 3, 2)
            
            $meetingData += [PSCustomObject]@{
                会議ID = "MTG-$(Get-Random -Minimum 10000 -Maximum 99999)"
                会議名 = "定例会議 #$i"
                主催者 = $organizerNames | Get-Random
                開始時刻 = $startTime.ToString("yyyy-MM-dd HH:mm")
                継続時間分 = $duration
                参加者数 = $participantCount
                音声品質 = $audioQuality
                ビデオ品質 = $videoQuality
                画面共有品質 = $screenShareQuality
                ネットワーク遅延ms = $networkLatency
                パケットロス率 = $packetLoss
                ジッターms = $jitter
                全体品質スコア = $overallQuality
                品質評価 = if ($overallQuality -ge 80) { "優良" }
                           elseif ($overallQuality -ge 60) { "良好" }
                           elseif ($overallQuality -ge 40) { "要改善" }
                           else { "不良" }
                問題報告 = if ($overallQuality -lt 60) {
                    @("音声の途切れ", "映像の乱れ", "画面共有の遅延", "エコー", "接続切断") | Get-Random -Count (Get-Random -Minimum 1 -Maximum 3)
                } else { @() }
            }
        }
        
        # デバイス別品質統計
        $deviceStats = @(
            [PSCustomObject]@{
                デバイスタイプ = "Windows PC"
                使用率 = 45
                平均品質スコア = 85
                主な問題 = "マイクドライバーの更新が必要"
            },
            [PSCustomObject]@{
                デバイスタイプ = "Mac"
                使用率 = 25
                平均品質スコア = 88
                主な問題 = "特になし"
            },
            [PSCustomObject]@{
                デバイスタイプ = "iPhone/iPad"
                使用率 = 20
                平均品質スコア = 75
                主な問題 = "WiFi接続の不安定性"
            },
            [PSCustomObject]@{
                デバイスタイプ = "Android"
                使用率 = 10
                平均品質スコア = 72
                主な問題 = "バッテリー消費が多い"
            }
        )
        
        # ネットワーク別品質統計
        $networkStats = @(
            [PSCustomObject]@{
                ネットワーク種別 = "社内LAN"
                使用率 = 60
                平均品質スコア = 90
                平均遅延ms = 20
                推奨事項 = "現状維持"
            },
            [PSCustomObject]@{
                ネットワーク種別 = "自宅WiFi"
                使用率 = 30
                平均品質スコア = 75
                平均遅延ms = 50
                推奨事項 = "ルーターの最適化を推奨"
            },
            [PSCustomObject]@{
                ネットワーク種別 = "モバイル回線"
                使用率 = 10
                平均品質スコア = 65
                平均遅延ms = 100
                推奨事項 = "重要な会議ではWiFi使用を推奨"
            }
        )
        
        return [PSCustomObject]@{
            会議詳細 = $meetingData
            デバイス統計 = $deviceStats
            ネットワーク統計 = $networkStats
            全体サマリー = @{
                総会議数 = $meetingData.Count
                平均参加者数 = [Math]::Round(($meetingData | Measure-Object -Property 参加者数 -Average).Average, 1)
                平均継続時間 = [Math]::Round(($meetingData | Measure-Object -Property 継続時間分 -Average).Average, 1)
                平均品質スコア = [Math]::Round(($meetingData | Measure-Object -Property 全体品質スコア -Average).Average, 1)
                問題発生率 = [Math]::Round((($meetingData | Where-Object { $_.問題報告.Count -gt 0 }).Count / $meetingData.Count) * 100, 2)
            }
        }
    }
    catch {
        Write-Log "会議品質分析データ生成エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# Teamsアプリ分析ダミーデータ生成
function Get-TeamsAppsAnalysisData {
    try {
        Write-Log "Teamsアプリ分析データを生成中（ダミーデータ）..." -Level "Info"
        
        # インストール済みアプリ
        $installedApps = @(
            [PSCustomObject]@{
                アプリ名 = "Planner"
                カテゴリ = "プロジェクト管理"
                発行元 = "Microsoft"
                インストール数 = 450
                アクティブユーザー数 = 380
                使用率 = 84
                最終更新 = (Get-Date).AddDays(-15).ToString("yyyy-MM-dd")
                セキュリティ評価 = "安全"
            },
            [PSCustomObject]@{
                アプリ名 = "Forms"
                カテゴリ = "アンケート"
                発行元 = "Microsoft"
                インストール数 = 320
                アクティブユーザー数 = 250
                使用率 = 78
                最終更新 = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")
                セキュリティ評価 = "安全"
            },
            [PSCustomObject]@{
                アプリ名 = "OneNote"
                カテゴリ = "ノート"
                発行元 = "Microsoft"
                インストール数 = 280
                アクティブユーザー数 = 200
                使用率 = 71
                最終更新 = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd")
                セキュリティ評価 = "安全"
            },
            [PSCustomObject]@{
                アプリ名 = "Polly"
                カテゴリ = "投票"
                発行元 = "サードパーティ"
                インストール数 = 150
                アクティブユーザー数 = 100
                使用率 = 67
                最終更新 = (Get-Date).AddDays(-45).ToString("yyyy-MM-dd")
                セキュリティ評価 = "要確認"
            },
            [PSCustomObject]@{
                アプリ名 = "GitHub"
                カテゴリ = "開発ツール"
                発行元 = "GitHub Inc."
                インストール数 = 80
                アクティブユーザー数 = 75
                使用率 = 94
                最終更新 = (Get-Date).AddDays(-3).ToString("yyyy-MM-dd")
                セキュリティ評価 = "安全"
            }
        )
        
        # チーム別アプリ使用状況
        $teamAppUsage = @()
        $teams = @("営業チーム", "開発チームA", "開発チームB", "マーケティング", "人事総務")
        
        foreach ($team in $teams) {
            $appCount = Get-Random -Minimum 3 -Maximum 10
            $apps = $installedApps | Get-Random -Count $appCount
            
            $teamAppUsage += [PSCustomObject]@{
                チーム名 = $team
                インストールアプリ数 = $appCount
                主要アプリ = ($apps | Select-Object -First 3 -ExpandProperty アプリ名) -join ", "
                月間アクティビティ = Get-Random -Minimum 100 -Maximum 1000
                推奨アプリ = @("Power Automate", "Shifts", "Approvals") | Get-Random
            }
        }
        
        # アプリ権限分析
        $permissionAnalysis = @(
            [PSCustomObject]@{
                アプリ名 = "Polly"
                要求権限 = @("ユーザープロファイル読み取り", "チームメンバー一覧取得", "メッセージ投稿")
                リスクレベル = "中"
                推奨事項 = "定期的な権限レビューを実施"
            },
            [PSCustomObject]@{
                アプリ名 = "GitHub"
                要求権限 = @("ファイル読み書き", "外部API接続")
                リスクレベル = "中"
                推奨事項 = "開発チームのみに制限"
            }
        )
        
        # 使用トレンド
        $usageTrend = @()
        for ($i = 11; $i -ge 0; $i--) {
            $month = (Get-Date).AddMonths(-$i).ToString("yyyy-MM")
            $usageTrend += [PSCustomObject]@{
                年月 = $month
                総アプリ数 = Get-Random -Minimum 20 -Maximum 40
                アクティブアプリ数 = Get-Random -Minimum 15 -Maximum 35
                新規インストール = Get-Random -Minimum 0 -Maximum 5
                アンインストール = Get-Random -Minimum 0 -Maximum 3
            }
        }
        
        return [PSCustomObject]@{
            インストール済みアプリ = $installedApps | Sort-Object 使用率 -Descending
            チーム別使用状況 = $teamAppUsage
            権限分析 = $permissionAnalysis
            使用トレンド = $usageTrend
            推奨事項 = @(
                "未使用アプリの定期的な棚卸し",
                "サードパーティアプリの権限確認",
                "セキュリティポリシーに基づくアプリ承認プロセスの確立",
                "ユーザー教育によるアプリ活用促進"
            )
        }
    }
    catch {
        Write-Log "Teamsアプリ分析データ生成エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# エクスポート
Export-ModuleMember -Function @(
    'Get-TeamsUsageData',
    'Get-TeamsConfigAnalysisData',
    'Get-MeetingQualityAnalysisData',
    'Get-TeamsAppsAnalysisData'
)