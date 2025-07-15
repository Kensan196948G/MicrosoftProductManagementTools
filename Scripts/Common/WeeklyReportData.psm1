# ================================================================================
# WeeklyReportData.psm1
# 週次レポート用実データ取得モジュール
# Microsoft 365 E3ライセンス対応版
# ================================================================================

Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\ErrorHandling.psm1" -Force
Import-Module "$PSScriptRoot\Authentication.psm1" -Force

# 週次レポート用統合データ取得（実データ優先）
function Get-WeeklyReportRealData {
    param(
        [switch]$ForceRealData = $false,
        [switch]$UseSampleData = $false
    )
    
    Write-Log "週次レポートデータ取得を開始します" -Level "Info"
    
    $reportData = @{
        MFAStatus = @()
        ExternalSharing = @()
        GroupReview = @()
        InactiveUsers = @()
        Summary = @{}
        DataSource = "Unknown"
        GeneratedAt = Get-Date
    }
    
    try {
        # 実データ取得を試行
        if (-not $UseSampleData) {
            Write-Log "Microsoft 365実データ取得を試行中..." -Level "Info"
            
            # 接続状態確認
            $isConnected = $false
            if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
                $mgContext = Get-MgContext -ErrorAction SilentlyContinue
                if ($mgContext) {
                    $isConnected = $true
                }
            }
            
            if ($isConnected -or $ForceRealData) {
                try {
                    # MFA状況データ
                    Write-Log "MFA状況データを取得中..." -Level "Info"
                    $reportData.MFAStatus = Get-WeeklyMFAStatusData
                    
                    # 外部共有データ
                    Write-Log "外部共有データを取得中..." -Level "Info"
                    $reportData.ExternalSharing = Get-WeeklyExternalSharingData
                    
                    # グループレビューデータ
                    Write-Log "グループレビューデータを取得中..." -Level "Info"
                    $reportData.GroupReview = Get-WeeklyGroupReviewData
                    
                    # 非アクティブユーザーデータ
                    Write-Log "非アクティブユーザーデータを取得中..." -Level "Info"
                    $reportData.InactiveUsers = Get-WeeklyInactiveUsersData
                    
                    $reportData.DataSource = "Microsoft365API"
                    Write-Log "実データ取得成功" -Level "Info"
                }
                catch {
                    Write-Log "実データ取得中にエラーが発生しました: $($_.Exception.Message)" -Level "Warning"
                    if ($ForceRealData) {
                        throw
                    }
                    # フォールバックへ
                    $reportData.DataSource = "SampleData"
                }
            }
            else {
                Write-Log "Microsoft 365への接続が無効です。サンプルデータを使用します。" -Level "Warning"
                $reportData.DataSource = "SampleData"
            }
        }
        
        # サンプルデータ使用（フォールバック）
        if ($reportData.DataSource -eq "SampleData" -or $UseSampleData) {
            Write-Log "サンプルデータを生成中..." -Level "Info"
            
            $reportData.MFAStatus = Get-WeeklyMFAStatusSampleData
            $reportData.ExternalSharing = Get-WeeklyExternalSharingSampleData
            $reportData.GroupReview = Get-WeeklyGroupReviewSampleData
            $reportData.InactiveUsers = Get-WeeklyInactiveUsersSampleData
        }
        
        # サマリー情報生成
        $reportData.Summary = @{
            TotalUsers = $reportData.MFAStatus.Count
            MFAEnabled = ($reportData.MFAStatus | Where-Object { $_.MFA状況 -eq "設定済み" }).Count
            MFADisabled = ($reportData.MFAStatus | Where-Object { $_.MFA状況 -eq "未設定" }).Count
            ExternalSharingCount = $reportData.ExternalSharing.Count
            GroupsReviewed = $reportData.GroupReview.Count
            InactiveUsersCount = $reportData.InactiveUsers.Count
            DataSource = $reportData.DataSource
            ReportDate = $reportData.GeneratedAt.ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        Write-Log "週次レポートデータ取得完了 (ソース: $($reportData.DataSource))" -Level "Info"
        return $reportData
    }
    catch {
        Write-Log "週次レポートデータ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# MFA状況実データ取得（週次）
function Get-WeeklyMFAStatusData {
    try {
        $mfaStatus = @()
        $users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,UserType,Department -Top 500
        
        foreach ($user in $users) {
            if ($user.AccountEnabled -and $user.UserType -eq "Member") {
                try {
                    $authMethods = Get-MgUserAuthenticationMethod -UserId $user.Id -ErrorAction Stop
                    
                    $hasMFA = $false
                    $mfaMethods = @()
                    
                    foreach ($method in $authMethods) {
                        $methodType = $method.AdditionalProperties.'@odata.type'
                        switch ($methodType) {
                            '#microsoft.graph.phoneAuthenticationMethod' {
                                $hasMFA = $true
                                $mfaMethods += "電話"
                            }
                            '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' {
                                $hasMFA = $true
                                $mfaMethods += "Authenticator"
                            }
                            '#microsoft.graph.fido2AuthenticationMethod' {
                                $hasMFA = $true
                                $mfaMethods += "FIDO2"
                            }
                            '#microsoft.graph.emailAuthenticationMethod' {
                                $hasMFA = $true
                                $mfaMethods += "メール"
                            }
                        }
                    }
                    
                    $mfaStatus += [PSCustomObject]@{
                        ユーザー名 = $user.DisplayName
                        メールアドレス = $user.UserPrincipalName
                        部署 = if ($user.Department) { $user.Department } else { "未設定" }
                        MFA状況 = if ($hasMFA) { "設定済み" } else { "未設定" }
                        認証方法 = if ($mfaMethods.Count -gt 0) { $mfaMethods -join ", " } else { "なし" }
                        方法数 = $mfaMethods.Count
                        リスク = if (-not $hasMFA) { "高" } 
                                elseif ($mfaMethods.Count -eq 1) { "中" } 
                                else { "低" }
                        推奨事項 = if (-not $hasMFA) { "MFA設定必須" }
                                  elseif ($mfaMethods.Count -eq 1) { "複数の認証方法を推奨" }
                                  else { "適切に設定済み" }
                        最終確認 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
                    }
                }
                catch {
                    Write-Log "ユーザー $($user.UserPrincipalName) のMFA情報取得エラー" -Level "Debug"
                }
            }
        }
        
        return $mfaStatus | Sort-Object リスク, ユーザー名
    }
    catch {
        Write-Log "週次MFA状況実データ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# 外部共有実データ取得（週次）
function Get-WeeklyExternalSharingData {
    try {
        $sharingData = @()
        
        # SharePoint/OneDriveの外部共有を確認（E3ライセンスで利用可能）
        # ここではグループメンバーシップから外部ユーザーを検出
        $groups = Get-MgGroup -All -Property Id,DisplayName,GroupTypes,Members -Top 100
        
        foreach ($group in $groups) {
            try {
                $members = Get-MgGroupMember -GroupId $group.Id -All
                $externalMembers = @()
                
                foreach ($member in $members) {
                    try {
                        $user = Get-MgUser -UserId $member.Id -Property UserPrincipalName,UserType -ErrorAction Stop
                        if ($user.UserType -eq "Guest") {
                            $externalMembers += $user.UserPrincipalName
                        }
                    }
                    catch {
                        # メンバーがユーザーでない場合はスキップ
                        continue
                    }
                }
                
                if ($externalMembers.Count -gt 0) {
                    $sharingData += [PSCustomObject]@{
                        リソース名 = $group.DisplayName
                        リソース種類 = if ($group.GroupTypes -contains "Unified") { "Microsoft 365グループ" } else { "セキュリティグループ" }
                        外部ユーザー数 = $externalMembers.Count
                        外部ユーザー = $externalMembers -join "; "
                        共有日時 = "グループ作成時から"
                        リスクレベル = if ($externalMembers.Count -gt 5) { "高" }
                                     elseif ($externalMembers.Count -gt 2) { "中" }
                                     else { "低" }
                        確認日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
                    }
                }
            }
            catch {
                Write-Log "グループ $($group.DisplayName) の外部共有確認エラー" -Level "Debug"
            }
        }
        
        return $sharingData | Sort-Object リスクレベル, 外部ユーザー数 -Descending
    }
    catch {
        Write-Log "週次外部共有実データ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# グループレビュー実データ取得（週次）
function Get-WeeklyGroupReviewData {
    try {
        $groupReview = @()
        $groups = Get-MgGroup -All -Property Id,DisplayName,GroupTypes,Description,CreatedDateTime,MembershipRule -Top 200
        
        foreach ($group in $groups) {
            try {
                $members = Get-MgGroupMember -GroupId $group.Id -All
                $owners = Get-MgGroupOwner -GroupId $group.Id -All -ErrorAction SilentlyContinue
                
                $createdDate = if ($group.CreatedDateTime) { [DateTime]::Parse($group.CreatedDateTime) } else { $null }
                $ageInDays = if ($createdDate) { ((Get-Date) - $createdDate).Days } else { 0 }
                
                $groupReview += [PSCustomObject]@{
                    グループ名 = $group.DisplayName
                    種類 = if ($group.GroupTypes -contains "Unified") { "Microsoft 365" }
                          elseif ($group.GroupTypes -contains "DynamicMembership") { "動的" }
                          else { "セキュリティ" }
                    メンバー数 = @($members).Count
                    オーナー数 = @($owners).Count
                    説明 = if ($group.Description) { $group.Description } else { "説明なし" }
                    作成日 = if ($createdDate) { $createdDate.ToString("yyyy-MM-dd") } else { "不明" }
                    経過日数 = $ageInDays
                    動的ルール = if ($group.MembershipRule) { "設定あり" } else { "なし" }
                    レビュー状態 = if (@($members).Count -eq 0) { "空のグループ" }
                                 elseif (@($owners).Count -eq 0) { "オーナー不在" }
                                 elseif ($ageInDays -gt 365 -and @($members).Count -lt 3) { "使用率低下" }
                                 else { "正常" }
                    推奨アクション = if (@($members).Count -eq 0) { "削除を検討" }
                                   elseif (@($owners).Count -eq 0) { "オーナー割り当て必要" }
                                   elseif ($ageInDays -gt 365 -and @($members).Count -lt 3) { "利用状況確認" }
                                   else { "なし" }
                }
            }
            catch {
                Write-Log "グループ $($group.DisplayName) のレビュー情報取得エラー" -Level "Debug"
            }
        }
        
        return $groupReview | Sort-Object レビュー状態, メンバー数
    }
    catch {
        Write-Log "週次グループレビュー実データ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# 非アクティブユーザー実データ取得（週次）
function Get-WeeklyInactiveUsersData {
    try {
        $inactiveUsers = @()
        $users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,LastPasswordChangeDateTime,CreatedDateTime,Department,JobTitle -Top 500
        
        $today = Get-Date
        $inactiveThreshold = 30 # 30日間
        
        foreach ($user in $users) {
            if ($user.AccountEnabled) {
                $lastActivity = $null
                $daysSinceActivity = 999
                $activityType = "不明"
                
                # パスワード変更日を活動指標として使用（E3ライセンス制限のため）
                if ($user.LastPasswordChangeDateTime) {
                    $lastActivity = [DateTime]::Parse($user.LastPasswordChangeDateTime)
                    $daysSinceActivity = ($today - $lastActivity).Days
                    $activityType = "パスワード変更"
                }
                
                # アカウント作成から30日以内は除外
                if ($user.CreatedDateTime) {
                    $createdDate = [DateTime]::Parse($user.CreatedDateTime)
                    $accountAge = ($today - $createdDate).Days
                    if ($accountAge -le 30) {
                        continue
                    }
                }
                
                # 非アクティブと判定
                if ($daysSinceActivity -gt $inactiveThreshold) {
                    $inactiveUsers += [PSCustomObject]@{
                        ユーザー名 = $user.DisplayName
                        メールアドレス = $user.UserPrincipalName
                        部署 = if ($user.Department) { $user.Department } else { "未設定" }
                        役職 = if ($user.JobTitle) { $user.JobTitle } else { "未設定" }
                        最終活動 = if ($lastActivity) { $lastActivity.ToString("yyyy-MM-dd") } else { "不明" }
                        活動種別 = $activityType
                        非アクティブ日数 = $daysSinceActivity
                        リスク = if ($daysSinceActivity -gt 90) { "高" }
                                elseif ($daysSinceActivity -gt 60) { "中" }
                                else { "低" }
                        推奨対応 = if ($daysSinceActivity -gt 90) { "アカウント無効化を検討" }
                                  elseif ($daysSinceActivity -gt 60) { "利用状況の確認" }
                                  else { "継続監視" }
                    }
                }
            }
        }
        
        return $inactiveUsers | Sort-Object 非アクティブ日数 -Descending
    }
    catch {
        Write-Log "週次非アクティブユーザー実データ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# サンプルデータ生成関数群
function Get-WeeklyMFAStatusSampleData {
    $departments = @("営業部", "開発部", "総務部", "マーケティング部", "経理部", "人事部")
    $mfaStatus = @()
    
    for ($i = 1; $i -le 100; $i++) {
        $hasMFA = (Get-Random -Minimum 0 -Maximum 100) -gt 20  # 80%がMFA設定済み
        $methods = @("Authenticator", "電話", "SMS", "FIDO2", "メール")
        $selectedMethods = if ($hasMFA) {
            $methods | Get-Random -Count (Get-Random -Minimum 1 -Maximum 3)
        } else {
            @()
        }
        
        $mfaStatus += [PSCustomObject]@{
            ユーザー名 = "ユーザー$i"
            メールアドレス = "user$i@miraiconst.onmicrosoft.com"
            部署 = $departments | Get-Random
            MFA状況 = if ($hasMFA) { "設定済み" } else { "未設定" }
            認証方法 = if ($selectedMethods.Count -gt 0) { $selectedMethods -join ", " } else { "なし" }
            方法数 = $selectedMethods.Count
            リスク = if (-not $hasMFA) { "高" } 
                    elseif ($selectedMethods.Count -eq 1) { "中" } 
                    else { "低" }
            推奨事項 = if (-not $hasMFA) { "MFA設定必須" }
                      elseif ($selectedMethods.Count -eq 1) { "複数の認証方法を推奨" }
                      else { "適切に設定済み" }
            最終確認 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
        }
    }
    
    return $mfaStatus | Sort-Object リスク, ユーザー名
}

function Get-WeeklyExternalSharingSampleData {
    $resourceTypes = @("SharePointサイト", "OneDriveフォルダ", "Microsoft 365グループ", "Teamsチャネル")
    $sharingData = @()
    
    for ($i = 1; $i -le 20; $i++) {
        $externalCount = Get-Random -Minimum 1 -Maximum 10
        $sharingData += [PSCustomObject]@{
            リソース名 = "共有リソース$i"
            リソース種類 = $resourceTypes | Get-Random
            外部ユーザー数 = $externalCount
            外部ユーザー = (1..$externalCount | ForEach-Object { "external$_@partner$_.com" }) -join "; "
            共有日時 = (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 90)).ToString("yyyy-MM-dd")
            リスクレベル = if ($externalCount -gt 5) { "高" }
                         elseif ($externalCount -gt 2) { "中" }
                         else { "低" }
            確認日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
        }
    }
    
    return $sharingData | Sort-Object リスクレベル, 外部ユーザー数 -Descending
}

function Get-WeeklyGroupReviewSampleData {
    $groupTypes = @("Microsoft 365", "セキュリティ", "配布", "動的")
    $groupReview = @()
    
    for ($i = 1; $i -le 50; $i++) {
        $memberCount = Get-Random -Minimum 0 -Maximum 100
        $ownerCount = Get-Random -Minimum 0 -Maximum 5
        $ageInDays = Get-Random -Minimum 1 -Maximum 730
        
        $groupReview += [PSCustomObject]@{
            グループ名 = "グループ$i"
            種類 = $groupTypes | Get-Random
            メンバー数 = $memberCount
            オーナー数 = $ownerCount
            説明 = if ((Get-Random -Minimum 0 -Maximum 10) -gt 3) { "業務用グループ" } else { "説明なし" }
            作成日 = (Get-Date).AddDays(-$ageInDays).ToString("yyyy-MM-dd")
            経過日数 = $ageInDays
            動的ルール = if ((Get-Random -Minimum 0 -Maximum 10) -gt 7) { "設定あり" } else { "なし" }
            レビュー状態 = if ($memberCount -eq 0) { "空のグループ" }
                         elseif ($ownerCount -eq 0) { "オーナー不在" }
                         elseif ($ageInDays -gt 365 -and $memberCount -lt 3) { "使用率低下" }
                         else { "正常" }
            推奨アクション = if ($memberCount -eq 0) { "削除を検討" }
                           elseif ($ownerCount -eq 0) { "オーナー割り当て必要" }
                           elseif ($ageInDays -gt 365 -and $memberCount -lt 3) { "利用状況確認" }
                           else { "なし" }
        }
    }
    
    return $groupReview | Sort-Object レビュー状態, メンバー数
}

function Get-WeeklyInactiveUsersSampleData {
    $departments = @("営業部", "開発部", "総務部", "マーケティング部", "経理部", "人事部")
    $titles = @("部長", "課長", "主任", "一般社員", "マネージャー", "リーダー")
    $inactiveUsers = @()
    
    for ($i = 1; $i -le 30; $i++) {
        $daysSince = Get-Random -Minimum 31 -Maximum 180
        $inactiveUsers += [PSCustomObject]@{
            ユーザー名 = "非アクティブユーザー$i"
            メールアドレス = "inactive$i@miraiconst.onmicrosoft.com"
            部署 = $departments | Get-Random
            役職 = $titles | Get-Random
            最終活動 = (Get-Date).AddDays(-$daysSince).ToString("yyyy-MM-dd")
            活動種別 = @("ログイン", "メール送信", "ファイルアクセス") | Get-Random
            非アクティブ日数 = $daysSince
            リスク = if ($daysSince -gt 90) { "高" }
                    elseif ($daysSince -gt 60) { "中" }
                    else { "低" }
            推奨対応 = if ($daysSince -gt 90) { "アカウント無効化を検討" }
                      elseif ($daysSince -gt 60) { "利用状況の確認" }
                      else { "継続監視" }
        }
    }
    
    return $inactiveUsers | Sort-Object 非アクティブ日数 -Descending
}

# エクスポート
Export-ModuleMember -Function @(
    'Get-WeeklyReportRealData',
    'Get-WeeklyMFAStatusData',
    'Get-WeeklyExternalSharingData',
    'Get-WeeklyGroupReviewData',
    'Get-WeeklyInactiveUsersData'
)