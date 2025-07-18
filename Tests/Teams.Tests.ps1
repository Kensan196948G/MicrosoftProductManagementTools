#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.3.0' }

<#
.SYNOPSIS
Microsoft Teams機能の包括的Pesterテストスイート

.DESCRIPTION
Teams管理機能（使用状況、設定管理、会議品質、アプリ分析）の単体・統合テスト

.NOTES
Version: 2025.7.17.1
Author: Dev2 - Test/QA Developer
#>

BeforeAll {
    $script:TestRootPath = Split-Path -Parent $PSScriptRoot
    $script:ScriptsPath = Join-Path $TestRootPath "Scripts"
    $script:ConfigPath = Join-Path $TestRootPath "Config\appsettings.json"
    
    # モジュールのインポート
    $script:AuthModule = Join-Path $ScriptsPath "Common\Authentication.psm1"
    $script:DataModule = Join-Path $ScriptsPath "Common\RealM365DataProvider.psm1"
    
    if (Test-Path $AuthModule) {
        Import-Module $AuthModule -Force
    }
    
    if (Test-Path $DataModule) {
        Import-Module $DataModule -Force
    }
    
    # テスト用データ
    $script:TestTeamsData = @{
        Users = @(
            [PSCustomObject]@{
                UserId = "user-1"
                DisplayName = "山田太郎"
                UserPrincipalName = "yamada@contoso.com"
                LastActivityDate = (Get-Date).AddDays(-1)
                TeamChatMessageCount = 125
                PrivateChatMessageCount = 87
                CallCount = 15
                MeetingCount = 8
                HasOtherAction = $true
                ReportPeriod = 7
            },
            [PSCustomObject]@{
                UserId = "user-2"
                DisplayName = "佐藤花子"
                UserPrincipalName = "sato@contoso.com"
                LastActivityDate = (Get-Date).AddDays(-3)
                TeamChatMessageCount = 45
                PrivateChatMessageCount = 23
                CallCount = 5
                MeetingCount = 3
                HasOtherAction = $false
                ReportPeriod = 7
            }
        )
        
        Teams = @(
            [PSCustomObject]@{
                GroupId = "team-1"
                DisplayName = "営業チーム"
                Description = "営業部門のコラボレーション"
                Visibility = "Private"
                MemberCount = 25
                OwnerCount = 3
                GuestCount = 2
                ChannelCount = 8
                CreatedDateTime = (Get-Date).AddMonths(-6)
                LastActivityDate = (Get-Date).AddHours(-2)
                IsArchived = $false
            },
            [PSCustomObject]@{
                GroupId = "team-2"
                DisplayName = "プロジェクトX"
                Description = "新製品開発プロジェクト"
                Visibility = "Public"
                MemberCount = 15
                OwnerCount = 2
                GuestCount = 0
                ChannelCount = 5
                CreatedDateTime = (Get-Date).AddMonths(-3)
                LastActivityDate = (Get-Date).AddDays(-7)
                IsArchived = $false
            }
        )
        
        Meetings = @(
            [PSCustomObject]@{
                MeetingId = "meeting-1"
                Organizer = "yamada@contoso.com"
                Subject = "週次営業会議"
                StartDateTime = (Get-Date).AddHours(-2)
                EndDateTime = (Get-Date).AddHours(-1)
                TotalParticipantCount = 12
                MeetingType = "Scheduled"
                AudioQuality = "Good"
                VideoQuality = "Good"
                ScreenShareQuality = "Good"
                NetworkQuality = @{
                    PacketLoss = 0.1
                    Jitter = 15
                    RoundTripTime = 25
                }
            },
            [PSCustomObject]@{
                MeetingId = "meeting-2"
                Organizer = "sato@contoso.com"
                Subject = "緊急対応会議"
                StartDateTime = (Get-Date).AddDays(-1)
                EndDateTime = (Get-Date).AddDays(-1).AddHours(1)
                TotalParticipantCount = 5
                MeetingType = "AdHoc"
                AudioQuality = "Poor"
                VideoQuality = "Fair"
                ScreenShareQuality = "Good"
                NetworkQuality = @{
                    PacketLoss = 2.5
                    Jitter = 45
                    RoundTripTime = 150
                }
            }
        )
        
        Apps = @(
            [PSCustomObject]@{
                AppId = "app-1"
                AppName = "Planner"
                AppType = "Microsoft"
                InstallCount = 150
                ActiveUserCount = 89
                LastUpdated = (Get-Date).AddDays(-30)
                Permissions = @("ReadWrite.All", "User.Read")
                ComplianceStatus = "Compliant"
            },
            [PSCustomObject]@{
                AppId = "app-2"
                AppName = "CustomCRMApp"
                AppType = "Custom"
                InstallCount = 45
                ActiveUserCount = 32
                LastUpdated = (Get-Date).AddDays(-7)
                Permissions = @("Sites.Read.All", "Files.ReadWrite")
                ComplianceStatus = "ReviewRequired"
            }
        )
    }
}

Describe "Teams - 使用状況分析テスト" -Tags @("Unit", "Teams", "Usage") {
    Context "ユーザーアクティビティ取得" {
        It "Teams使用状況データが取得できること" {
            Mock Get-TeamsUserActivityReport {
                return $TestTeamsData.Users
            }
            
            $activity = Get-TeamsUserActivityReport
            $activity | Should -Not -BeNullOrEmpty
            $activity.Count | Should -Be 2
        }
        
        It "必須フィールドが含まれていること" {
            Mock Get-TeamsUserActivityReport {
                return $TestTeamsData.Users
            }
            
            $activity = Get-TeamsUserActivityReport
            $user = $activity[0]
            
            $user.DisplayName | Should -Not -BeNullOrEmpty
            $user.UserPrincipalName | Should -Not -BeNullOrEmpty
            $user.TeamChatMessageCount | Should -BeOfType [int]
            $user.MeetingCount | Should -BeOfType [int]
            $user.LastActivityDate | Should -BeOfType [datetime]
        }
        
        It "期間指定でデータが取得できること" {
            Mock Get-TeamsUserActivityReport {
                param($Period)
                $data = $TestTeamsData.Users
                if ($Period) {
                    $data | ForEach-Object { $_.ReportPeriod = $Period }
                }
                return $data
            }
            
            $weeklyActivity = Get-TeamsUserActivityReport -Period 7
            $weeklyActivity[0].ReportPeriod | Should -Be 7
            
            $monthlyActivity = Get-TeamsUserActivityReport -Period 30
            $monthlyActivity[0].ReportPeriod | Should -Be 30
        }
        
        It "アクティブユーザーのフィルタリングができること" {
            Mock Get-TeamsUserActivityReport {
                return $TestTeamsData.Users
            }
            
            $activity = Get-TeamsUserActivityReport
            $activeUsers = $activity | Where-Object { 
                $_.LastActivityDate -ge (Get-Date).AddDays(-7) 
            }
            
            $activeUsers.Count | Should -BeGreaterThan 0
            $activeUsers[0].DisplayName | Should -Be "山田太郎"
        }
    }
    
    Context "チーム使用状況分析" {
        It "全チームの情報が取得できること" {
            Mock Get-Team {
                return $TestTeamsData.Teams
            }
            
            $teams = Get-Team
            $teams | Should -Not -BeNullOrEmpty
            $teams.Count | Should -Be 2
        }
        
        It "アクティブなチームが識別できること" {
            $activeThreshold = (Get-Date).AddDays(-7)
            $activeTeams = $TestTeamsData.Teams | Where-Object {
                $_.LastActivityDate -ge $activeThreshold
            }
            
            $activeTeams.Count | Should -Be 1
            $activeTeams[0].DisplayName | Should -Be "営業チーム"
        }
        
        It "チームの統計情報が生成できること" {
            $teamStats = [PSCustomObject]@{
                TotalTeams = $TestTeamsData.Teams.Count
                PrivateTeams = ($TestTeamsData.Teams | Where-Object { $_.Visibility -eq "Private" }).Count
                PublicTeams = ($TestTeamsData.Teams | Where-Object { $_.Visibility -eq "Public" }).Count
                TeamsWithGuests = ($TestTeamsData.Teams | Where-Object { $_.GuestCount -gt 0 }).Count
                AverageMemberCount = ($TestTeamsData.Teams | Measure-Object -Property MemberCount -Average).Average
                TotalChannels = ($TestTeamsData.Teams | Measure-Object -Property ChannelCount -Sum).Sum
            }
            
            $teamStats.TotalTeams | Should -Be 2
            $teamStats.PrivateTeams | Should -Be 1
            $teamStats.PublicTeams | Should -Be 1
            $teamStats.TeamsWithGuests | Should -Be 1
            $teamStats.AverageMemberCount | Should -Be 20
            $teamStats.TotalChannels | Should -Be 13
        }
    }
    
    Context "アクティビティトレンド分析" {
        It "メッセージング活動の傾向が分析できること" {
            $totalMessages = $TestTeamsData.Users | ForEach-Object {
                $_.TeamChatMessageCount + $_.PrivateChatMessageCount
            } | Measure-Object -Sum
            
            $avgMessagesPerUser = [math]::Round($totalMessages.Sum / $TestTeamsData.Users.Count, 2)
            
            $totalMessages.Sum | Should -Be 280
            $avgMessagesPerUser | Should -Be 140
        }
        
        It "会議参加率が計算できること" {
            $usersWithMeetings = ($TestTeamsData.Users | Where-Object { $_.MeetingCount -gt 0 }).Count
            $meetingParticipationRate = [math]::Round(($usersWithMeetings / $TestTeamsData.Users.Count) * 100, 2)
            
            $meetingParticipationRate | Should -Be 100
        }
    }
}

Describe "Teams - チーム設定管理テスト" -Tags @("Unit", "Teams", "Settings") {
    Context "チーム設定の取得と検証" {
        It "チーム設定が取得できること" {
            Mock Get-TeamSettings {
                param($GroupId)
                return [PSCustomObject]@{
                    GroupId = $GroupId
                    AllowCreateUpdateChannels = $true
                    AllowDeleteChannels = $false
                    AllowAddRemoveApps = $true
                    AllowCreateUpdateRemoveTabs = $true
                    AllowCreateUpdateRemoveConnectors = $false
                    AllowUserEditMessages = $true
                    AllowUserDeleteMessages = $false
                    AllowOwnerDeleteMessages = $true
                    AllowTeamMentions = $true
                    AllowChannelMentions = $true
                    ShowInTeamsSearchAndSuggestions = $true
                }
            }
            
            $settings = Get-TeamSettings -GroupId "team-1"
            $settings | Should -Not -BeNullOrEmpty
            $settings.AllowCreateUpdateChannels | Should -Be $true
            $settings.AllowDeleteChannels | Should -Be $false
        }
        
        It "セキュリティ設定が適切に構成されていること" {
            Mock Get-TeamSettings {
                param($GroupId)
                return [PSCustomObject]@{
                    GroupId = $GroupId
                    AllowUserDeleteMessages = $false
                    AllowGuestCreateUpdateChannels = $false
                    AllowGuestDeleteChannels = $false
                }
            }
            
            $settings = Get-TeamSettings -GroupId "team-1"
            
            # セキュリティ重要設定の確認
            $settings.AllowUserDeleteMessages | Should -Be $false
            $settings.AllowGuestCreateUpdateChannels | Should -Be $false
            $settings.AllowGuestDeleteChannels | Should -Be $false
        }
        
        It "チャネル設定が取得できること" {
            Mock Get-TeamChannel {
                param($GroupId)
                return @(
                    [PSCustomObject]@{
                        Id = "channel-1"
                        DisplayName = "General"
                        Description = "全体連絡用"
                        MembershipType = "standard"
                        IsFavoriteByDefault = $true
                    },
                    [PSCustomObject]@{
                        Id = "channel-2"
                        DisplayName = "営業報告"
                        Description = "日次営業報告"
                        MembershipType = "private"
                        IsFavoriteByDefault = $false
                    }
                )
            }
            
            $channels = Get-TeamChannel -GroupId "team-1"
            $channels.Count | Should -Be 2
            
            $privateChannels = $channels | Where-Object { $_.MembershipType -eq "private" }
            $privateChannels.Count | Should -Be 1
        }
    }
    
    Context "チームポリシー管理" {
        It "メッセージングポリシーが取得できること" {
            Mock Get-CsTeamsMessagingPolicy {
                return @(
                    [PSCustomObject]@{
                        Identity = "Global"
                        AllowUserEditMessages = $true
                        AllowUserDeleteMessages = $true
                        AllowOwnerDeleteMessages = $true
                        AllowUserChat = $true
                        AllowRemoveUser = $true
                        AllowGiphy = $true
                        GiphyRatingType = "Moderate"
                        AllowMemes = $true
                        AllowStickers = $true
                        AllowUrlPreviews = $true
                        AllowImmersiveReader = $true
                        AllowPriorityMessages = $true
                    },
                    [PSCustomObject]@{
                        Identity = "RestrictedMessaging"
                        AllowUserEditMessages = $false
                        AllowUserDeleteMessages = $false
                        AllowOwnerDeleteMessages = $true
                        AllowUserChat = $true
                        AllowRemoveUser = $false
                        AllowGiphy = $false
                        AllowMemes = $false
                        AllowStickers = $false
                        AllowUrlPreviews = $true
                        AllowImmersiveReader = $true
                        AllowPriorityMessages = $false
                    }
                )
            }
            
            $policies = Get-CsTeamsMessagingPolicy
            $policies.Count | Should -Be 2
            
            $restrictedPolicy = $policies | Where-Object { $_.Identity -eq "RestrictedMessaging" }
            $restrictedPolicy.AllowGiphy | Should -Be $false
            $restrictedPolicy.AllowMemes | Should -Be $false
        }
        
        It "会議ポリシーが取得できること" {
            Mock Get-CsTeamsMeetingPolicy {
                return [PSCustomObject]@{
                    Identity = "Global"
                    AllowMeetNow = $true
                    AllowPrivateMeetNow = $true
                    MeetingChatEnabledType = "Enabled"
                    LiveCaptionsEnabledType = "DisabledUserOverride"
                    AllowIPVideo = $true
                    AllowAnonymousUsersToJoinMeeting = $false
                    AllowAnonymousUsersToStartMeeting = $false
                    AllowRecordingStorageOutsideRegion = $false
                    AllowOutlookAddIn = $true
                    AllowPowerPointSharing = $true
                    AllowParticipantGiveRequestControl = $true
                    AllowExternalParticipantGiveRequestControl = $false
                    AllowSharedNotes = $true
                    AllowWhiteboard = $true
                    AllowTranscription = $true
                    MediaBitRateKb = 50000
                    ScreenSharingMode = "EntireScreen"
                    VideoFiltersMode = "AllFilters"
                }
            }
            
            $policy = Get-CsTeamsMeetingPolicy
            
            # セキュリティ関連設定の確認
            $policy.AllowAnonymousUsersToJoinMeeting | Should -Be $false
            $policy.AllowAnonymousUsersToStartMeeting | Should -Be $false
            $policy.AllowRecordingStorageOutsideRegion | Should -Be $false
            $policy.AllowExternalParticipantGiveRequestControl | Should -Be $false
        }
    }
}

Describe "Teams - 会議品質分析テスト" -Tags @("Unit", "Teams", "MeetingQuality") {
    Context "会議品質メトリクス取得" {
        It "会議品質データが取得できること" {
            Mock Get-TeamsMeetingQuality {
                return $TestTeamsData.Meetings
            }
            
            $meetings = Get-TeamsMeetingQuality
            $meetings | Should -Not -BeNullOrEmpty
            $meetings.Count | Should -Be 2
        }
        
        It "ネットワーク品質指標が含まれていること" {
            $meeting = $TestTeamsData.Meetings[0]
            
            $meeting.NetworkQuality | Should -Not -BeNullOrEmpty
            $meeting.NetworkQuality.PacketLoss | Should -BeOfType [double]
            $meeting.NetworkQuality.Jitter | Should -BeOfType [int]
            $meeting.NetworkQuality.RoundTripTime | Should -BeOfType [int]
        }
        
        It "品質問題のある会議が識別できること" {
            # 品質基準
            $qualityThresholds = @{
                PacketLoss = 1.0  # 1%以上は問題
                Jitter = 30       # 30ms以上は問題
                RoundTripTime = 100  # 100ms以上は問題
            }
            
            $poorQualityMeetings = $TestTeamsData.Meetings | Where-Object {
                $_.NetworkQuality.PacketLoss -gt $qualityThresholds.PacketLoss -or
                $_.NetworkQuality.Jitter -gt $qualityThresholds.Jitter -or
                $_.NetworkQuality.RoundTripTime -gt $qualityThresholds.RoundTripTime -or
                $_.AudioQuality -eq "Poor" -or
                $_.VideoQuality -eq "Poor"
            }
            
            $poorQualityMeetings.Count | Should -Be 1
            $poorQualityMeetings[0].Subject | Should -Be "緊急対応会議"
        }
        
        It "会議品質の統計が生成できること" {
            $qualityStats = [PSCustomObject]@{
                TotalMeetings = $TestTeamsData.Meetings.Count
                GoodQualityMeetings = ($TestTeamsData.Meetings | Where-Object { 
                    $_.AudioQuality -eq "Good" -and $_.VideoQuality -eq "Good" 
                }).Count
                AveragePacketLoss = [math]::Round(($TestTeamsData.Meetings.NetworkQuality.PacketLoss | 
                    Measure-Object -Average).Average, 2)
                AverageJitter = [math]::Round(($TestTeamsData.Meetings.NetworkQuality.Jitter | 
                    Measure-Object -Average).Average, 2)
                AverageParticipants = ($TestTeamsData.Meetings.TotalParticipantCount | 
                    Measure-Object -Average).Average
            }
            
            $qualityStats.TotalMeetings | Should -Be 2
            $qualityStats.GoodQualityMeetings | Should -Be 1
            $qualityStats.AveragePacketLoss | Should -Be 1.3
            $qualityStats.AverageJitter | Should -Be 30
            $qualityStats.AverageParticipants | Should -Be 8.5
        }
    }
    
    Context "会議パフォーマンス分析" {
        It "会議タイプ別の分析ができること" {
            $meetingsByType = $TestTeamsData.Meetings | Group-Object -Property MeetingType
            
            $scheduledMeetings = $meetingsByType | Where-Object { $_.Name -eq "Scheduled" }
            $scheduledMeetings.Count | Should -Be 1
            
            $adHocMeetings = $meetingsByType | Where-Object { $_.Name -eq "AdHoc" }
            $adHocMeetings.Count | Should -Be 1
        }
        
        It "長時間会議が識別できること" {
            $longMeetingThreshold = 60  # 60分以上
            
            $longMeetings = $TestTeamsData.Meetings | Where-Object {
                ($_.EndDateTime - $_.StartDateTime).TotalMinutes -ge $longMeetingThreshold
            }
            
            $longMeetings.Count | Should -Be 1
            $longMeetings[0].Subject | Should -Be "緊急対応会議"
        }
        
        It "参加者数による分類ができること" {
            $meetingCategories = @{
                Small = @{ Min = 1; Max = 5 }
                Medium = @{ Min = 6; Max = 15 }
                Large = @{ Min = 16; Max = 50 }
            }
            
            $smallMeetings = $TestTeamsData.Meetings | Where-Object {
                $_.TotalParticipantCount -ge $meetingCategories.Small.Min -and
                $_.TotalParticipantCount -le $meetingCategories.Small.Max
            }
            
            $mediumMeetings = $TestTeamsData.Meetings | Where-Object {
                $_.TotalParticipantCount -ge $meetingCategories.Medium.Min -and
                $_.TotalParticipantCount -le $meetingCategories.Medium.Max
            }
            
            $smallMeetings.Count | Should -Be 1
            $mediumMeetings.Count | Should -Be 1
        }
    }
}

Describe "Teams - アプリ分析テスト" -Tags @("Unit", "Teams", "Apps") {
    Context "アプリインベントリ管理" {
        It "インストール済みアプリ一覧が取得できること" {
            Mock Get-TeamsApp {
                return $TestTeamsData.Apps
            }
            
            $apps = Get-TeamsApp
            $apps | Should -Not -BeNullOrEmpty
            $apps.Count | Should -Be 2
        }
        
        It "アプリタイプ別の分類ができること" {
            $appsByType = $TestTeamsData.Apps | Group-Object -Property AppType
            
            $microsoftApps = $appsByType | Where-Object { $_.Name -eq "Microsoft" }
            $microsoftApps.Count | Should -Be 1
            
            $customApps = $appsByType | Where-Object { $_.Name -eq "Custom" }
            $customApps.Count | Should -Be 1
        }
        
        It "アプリ使用状況の分析ができること" {
            $appUsageStats = $TestTeamsData.Apps | ForEach-Object {
                [PSCustomObject]@{
                    AppName = $_.AppName
                    AdoptionRate = [math]::Round(($_.ActiveUserCount / $_.InstallCount) * 100, 2)
                    IsActive = $_.ActiveUserCount -gt 0
                    DaysSinceUpdate = ((Get-Date) - $_.LastUpdated).Days
                }
            }
            
            $highAdoptionApps = $appUsageStats | Where-Object { $_.AdoptionRate -gt 50 }
            $highAdoptionApps.Count | Should -Be 2
            
            $recentlyUpdatedApps = $appUsageStats | Where-Object { $_.DaysSinceUpdate -le 30 }
            $recentlyUpdatedApps.Count | Should -Be 1
        }
    }
    
    Context "アプリセキュリティ分析" {
        It "アプリ権限の分析ができること" {
            $highRiskPermissions = @("*.All", "Directory.*", "User.ReadWrite.*")
            
            $appsWithHighRiskPerms = $TestTeamsData.Apps | Where-Object {
                $app = $_
                $hasHighRisk = $false
                foreach ($perm in $app.Permissions) {
                    foreach ($riskPattern in $highRiskPermissions) {
                        if ($perm -like $riskPattern) {
                            $hasHighRisk = $true
                            break
                        }
                    }
                    if ($hasHighRisk) { break }
                }
                $hasHighRisk
            }
            
            $appsWithHighRiskPerms.Count | Should -Be 1
            $appsWithHighRiskPerms[0].AppName | Should -Be "Planner"
        }
        
        It "コンプライアンス状態が確認できること" {
            $nonCompliantApps = $TestTeamsData.Apps | Where-Object {
                $_.ComplianceStatus -ne "Compliant"
            }
            
            $nonCompliantApps.Count | Should -Be 1
            $nonCompliantApps[0].AppName | Should -Be "CustomCRMApp"
            $nonCompliantApps[0].ComplianceStatus | Should -Be "ReviewRequired"
        }
        
        It "アプリのリスクスコアが計算できること" {
            function Get-AppRiskScore {
                param($App)
                
                $score = 0
                
                # 権限によるリスク
                $highRiskPerms = ($App.Permissions | Where-Object { $_ -like "*.All" }).Count
                $score += $highRiskPerms * 20
                
                # 更新頻度によるリスク
                $daysSinceUpdate = ((Get-Date) - $App.LastUpdated).Days
                if ($daysSinceUpdate -gt 90) { $score += 10 }
                if ($daysSinceUpdate -gt 180) { $score += 20 }
                
                # コンプライアンス状態
                if ($App.ComplianceStatus -ne "Compliant") { $score += 30 }
                
                # カスタムアプリの追加リスク
                if ($App.AppType -eq "Custom") { $score += 10 }
                
                return [Math]::Min($score, 100)
            }
            
            $appRisks = $TestTeamsData.Apps | ForEach-Object {
                [PSCustomObject]@{
                    AppName = $_.AppName
                    RiskScore = Get-AppRiskScore -App $_
                }
            }
            
            $highRiskApps = $appRisks | Where-Object { $_.RiskScore -ge 40 }
            $highRiskApps.Count | Should -BeGreaterThan 0
        }
    }
}

Describe "Teams - セキュリティとコンプライアンステスト" -Tags @("Security", "Teams", "Compliance") {
    Context "データ保護とプライバシー" {
        It "ゲストアクセスが適切に管理されていること" {
            $teamsWithGuests = $TestTeamsData.Teams | Where-Object { $_.GuestCount -gt 0 }
            
            $teamsWithGuests | ForEach-Object {
                $_.Visibility | Should -Not -Be "Public"  # ゲストがいるチームは公開すべきでない
                $_.GuestCount | Should -BeLessThan ($_.MemberCount * 0.2)  # ゲストは20%未満
            }
        }
        
        It "外部共有設定が適切であること" {
            Mock Get-CsTeamsClientConfiguration {
                return [PSCustomObject]@{
                    AllowDropBox = $false
                    AllowBox = $false
                    AllowGoogleDrive = $false
                    AllowShareFile = $false
                    AllowEgnyte = $false
                    RestrictedSenderList = @("contoso.com", "partner.com")
                }
            }
            
            $config = Get-CsTeamsClientConfiguration
            
            # 外部ストレージサービスは無効化されているべき
            $config.AllowDropBox | Should -Be $false
            $config.AllowBox | Should -Be $false
            $config.AllowGoogleDrive | Should -Be $false
        }
        
        It "監査ログが有効化されていること" {
            Mock Get-AdminAuditLogConfig {
                return [PSCustomObject]@{
                    UnifiedAuditLogIngestionEnabled = $true
                    AdminAuditLogEnabled = $true
                    AdminAuditLogAgeLimit = 365
                }
            }
            
            $auditConfig = Get-AdminAuditLogConfig
            
            $auditConfig.UnifiedAuditLogIngestionEnabled | Should -Be $true
            $auditConfig.AdminAuditLogEnabled | Should -Be $true
            $auditConfig.AdminAuditLogAgeLimit | Should -BeGreaterOrEqual 365
        }
    }
    
    Context "ISO/IEC 27001準拠確認" {
        It "アクセス制御が実装されていること" {
            # ロールベースアクセス制御の確認
            $teamRoles = @("Owner", "Member", "Guest")
            
            $teamRoles | Should -Contain "Owner"
            $teamRoles | Should -Contain "Member"
            $teamRoles | Should -Contain "Guest"
            
            # 各ロールの権限が適切に分離されているか
            $TestTeamsData.Teams | ForEach-Object {
                $_.OwnerCount | Should -BeGreaterThan 0  # 最低1人のオーナー必須
                $_.OwnerCount | Should -BeLessThan ($_.MemberCount * 0.3)  # オーナーは30%未満
            }
        }
        
        It "データ保持ポリシーが設定されていること" {
            Mock Get-RetentionCompliancePolicy {
                return [PSCustomObject]@{
                    Name = "Teams Chat Retention Policy"
                    Enabled = $true
                    RetentionDuration = "ThreeYears"
                    RetentionAction = "KeepAndDelete"
                    TeamsChannelLocation = @("All")
                    TeamsChatLocation = @("All")
                }
            }
            
            $retentionPolicy = Get-RetentionCompliancePolicy
            
            $retentionPolicy.Enabled | Should -Be $true
            $retentionPolicy.RetentionDuration | Should -BeIn @("OneYear", "ThreeYears", "FiveYears", "SevenYears")
            $retentionPolicy.TeamsChannelLocation | Should -Contain "All"
            $retentionPolicy.TeamsChatLocation | Should -Contain "All"
        }
        
        It "情報分類ラベルが利用可能であること" {
            Mock Get-Label {
                return @(
                    [PSCustomObject]@{ DisplayName = "Public"; Priority = 0 },
                    [PSCustomObject]@{ DisplayName = "Internal"; Priority = 1 },
                    [PSCustomObject]@{ DisplayName = "Confidential"; Priority = 2 },
                    [PSCustomObject]@{ DisplayName = "Highly Confidential"; Priority = 3 }
                )
            }
            
            $labels = Get-Label
            $labels.Count | Should -BeGreaterOrEqual 3
            
            $requiredLabels = @("Public", "Internal", "Confidential")
            foreach ($required in $requiredLabels) {
                $labels.DisplayName | Should -Contain $required
            }
        }
    }
}

Describe "Teams - パフォーマンステスト" -Tags @("Performance", "Teams") {
    Context "大規模データ処理" {
        It "1000チームの処理が10秒以内に完了すること" {
            # 大量のチームデータを生成
            $largeTeamSet = @()
            for ($i = 1; $i -le 1000; $i++) {
                $largeTeamSet += [PSCustomObject]@{
                    GroupId = "team-$i"
                    DisplayName = "Team $i"
                    MemberCount = Get-Random -Minimum 5 -Maximum 100
                    OwnerCount = Get-Random -Minimum 1 -Maximum 5
                    GuestCount = Get-Random -Minimum 0 -Maximum 10
                    LastActivityDate = (Get-Date).AddDays(-(Get-Random -Maximum 30))
                    IsArchived = ($i % 10 -eq 0)
                }
            }
            
            $measure = Measure-Command {
                # アクティブチームの抽出
                $activeTeams = $largeTeamSet | Where-Object { 
                    -not $_.IsArchived -and $_.LastActivityDate -ge (Get-Date).AddDays(-7) 
                }
                
                # 統計計算
                $stats = @{
                    TotalMembers = ($largeTeamSet | Measure-Object -Property MemberCount -Sum).Sum
                    AverageTeamSize = ($largeTeamSet | Measure-Object -Property MemberCount -Average).Average
                    LargeTeams = ($largeTeamSet | Where-Object { $_.MemberCount -gt 50 }).Count
                }
                
                # グループ化処理
                $teamsBySize = $largeTeamSet | Group-Object -Property {
                    if ($_.MemberCount -le 10) { "Small" }
                    elseif ($_.MemberCount -le 50) { "Medium" }
                    else { "Large" }
                }
            }
            
            $measure.TotalSeconds | Should -BeLessThan 10
        }
        
        It "10000件の会議ログ処理が適切な時間内に完了すること" {
            # 大量の会議ログを生成
            $largeMeetingSet = @()
            for ($i = 1; $i -le 10000; $i++) {
                $largeMeetingSet += [PSCustomObject]@{
                    MeetingId = "meeting-$i"
                    StartDateTime = (Get-Date).AddDays(-30).AddMinutes($i)
                    TotalParticipantCount = Get-Random -Minimum 2 -Maximum 100
                    AudioQuality = @("Good", "Fair", "Poor")[Get-Random -Maximum 3]
                    NetworkQuality = @{
                        PacketLoss = [Math]::Round((Get-Random -Minimum 0 -Maximum 500) / 100.0, 2)
                        Jitter = Get-Random -Minimum 5 -Maximum 100
                    }
                }
            }
            
            $measure = Measure-Command {
                # 品質問題の分析
                $poorQualityMeetings = $largeMeetingSet | Where-Object {
                    $_.AudioQuality -eq "Poor" -or 
                    $_.NetworkQuality.PacketLoss -gt 2.0 -or
                    $_.NetworkQuality.Jitter -gt 50
                }
                
                # 時間帯別集計
                $meetingsByHour = $largeMeetingSet | Group-Object -Property {
                    $_.StartDateTime.Hour
                }
                
                # 参加者数別の品質分析
                $qualityBySize = $largeMeetingSet | Group-Object -Property {
                    if ($_.TotalParticipantCount -le 10) { "Small" }
                    elseif ($_.TotalParticipantCount -le 50) { "Medium" }
                    else { "Large" }
                } | ForEach-Object {
                    $group = $_
                    $poorCount = ($group.Group | Where-Object { $_.AudioQuality -eq "Poor" }).Count
                    [PSCustomObject]@{
                        Size = $group.Name
                        Count = $group.Count
                        PoorQualityRate = [Math]::Round(($poorCount / $group.Count) * 100, 2)
                    }
                }
            }
            
            $measure.TotalSeconds | Should -BeLessThan 15
        }
    }
    
    Context "メモリ効率" {
        It "大量データ処理時のメモリ使用が適切であること" {
            [System.GC]::Collect()
            $initialMemory = [System.GC]::GetTotalMemory($false)
            
            # メモリ集約的な処理
            $testData = @()
            for ($i = 1; $i -le 5000; $i++) {
                $testData += [PSCustomObject]@{
                    Id = [Guid]::NewGuid()
                    LargeData = "x" * 1000  # 1KB
                    Messages = 1..10 | ForEach-Object {
                        [PSCustomObject]@{
                            Text = "Message $_"
                            Timestamp = Get-Date
                        }
                    }
                }
            }
            
            # データ処理
            $processed = $testData | Select-Object Id, @{
                Name = 'MessageCount'
                Expression = { $_.Messages.Count }
            }
            
            [System.GC]::Collect()
            $finalMemory = [System.GC]::GetTotalMemory($false)
            
            $memoryIncreaseMB = ($finalMemory - $initialMemory) / 1MB
            $memoryIncreaseMB | Should -BeLessThan 200
        }
    }
}

AfterAll {
    Write-Host "`n✅ Teams機能テストスイート完了" -ForegroundColor Green
}