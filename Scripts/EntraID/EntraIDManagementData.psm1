# ================================================================================
# EntraIDManagementData.psm1
# EntraID管理機能用実データ取得モジュール
# Microsoft 365 E3ライセンス対応版
# ================================================================================

Import-Module "$PSScriptRoot\..\Common\Logging.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\ErrorHandling.psm1" -Force
Import-Module "$PSScriptRoot\..\Common\Authentication.psm1" -Force

# ユーザー一覧実データ取得
function Get-M365RealUserData {
    try {
        Write-Log "EntraIDユーザー一覧を取得中..." -Level "Info"
        
        $userData = @()
        $users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,Department,JobTitle,AccountEnabled,CreatedDateTime,LastPasswordChangeDateTime,Mail,UsageLocation,AssignedLicenses -Top 1000
        
        foreach ($user in $users) {
            # ライセンス情報の取得
            $licenses = @()
            if ($user.AssignedLicenses) {
                $subscribedSkus = Get-MgSubscribedSku -All
                foreach ($license in $user.AssignedLicenses) {
                    $sku = $subscribedSkus | Where-Object { $_.SkuId -eq $license.SkuId }
                    if ($sku) {
                        $licenses += Get-LicenseFriendlyName -SkuPartNumber $sku.SkuPartNumber
                    }
                }
            }
            
            # アカウント年齢の計算
            $accountAge = if ($user.CreatedDateTime) {
                ((Get-Date) - [DateTime]::Parse($user.CreatedDateTime)).Days
            } else { 0 }
            
            # 最終パスワード変更からの日数
            $passwordAge = if ($user.LastPasswordChangeDateTime) {
                ((Get-Date) - [DateTime]::Parse($user.LastPasswordChangeDateTime)).Days
            } else { 999 }
            
            $userData += [PSCustomObject]@{
                表示名 = $user.DisplayName
                ユーザー名 = $user.UserPrincipalName
                メール = if ($user.Mail) { $user.Mail } else { $user.UserPrincipalName }
                部署 = if ($user.Department) { $user.Department } else { "未設定" }
                役職 = if ($user.JobTitle) { $user.JobTitle } else { "未設定" }
                状態 = if ($user.AccountEnabled) { "有効" } else { "無効" }
                場所 = if ($user.UsageLocation) { $user.UsageLocation } else { "未設定" }
                ライセンス = if ($licenses.Count -gt 0) { $licenses -join ", " } else { "なし" }
                作成日 = if ($user.CreatedDateTime) { [DateTime]::Parse($user.CreatedDateTime).ToString("yyyy-MM-dd") } else { "不明" }
                アカウント年齢 = "$accountAge 日"
                パスワード年齢 = "$passwordAge 日"
                リスク = if ($passwordAge -gt 365) { "高" }
                        elseif ($passwordAge -gt 180) { "中" }
                        else { "低" }
            }
        }
        
        Write-Log "EntraIDユーザー一覧取得完了（$($userData.Count)件）" -Level "Info"
        return $userData
    }
    catch {
        Write-Log "EntraIDユーザー一覧取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# MFA状況実データ取得（詳細版）
function Get-MFAStatusRealData {
    try {
        Write-Log "MFA状況詳細を取得中..." -Level "Info"
        
        $mfaData = @()
        $users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,Department,AccountEnabled,UserType -Top 500
        
        foreach ($user in $users) {
            if ($user.AccountEnabled -and $user.UserType -eq "Member") {
                try {
                    # 認証方法の取得
                    $authMethods = Get-MgUserAuthenticationMethod -UserId $user.Id -ErrorAction Stop
                    
                    $methodDetails = @()
                    $hasMFA = $false
                    $strongAuthCount = 0
                    
                    foreach ($method in $authMethods) {
                        $methodType = $method.AdditionalProperties.'@odata.type'
                        $methodInfo = switch ($methodType) {
                            '#microsoft.graph.passwordAuthenticationMethod' {
                                @{ Type = "パスワード"; Strength = "弱" }
                            }
                            '#microsoft.graph.phoneAuthenticationMethod' {
                                $hasMFA = $true
                                $strongAuthCount++
                                @{ Type = "電話"; Strength = "中" }
                            }
                            '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' {
                                $hasMFA = $true
                                $strongAuthCount++
                                @{ Type = "Microsoft Authenticator"; Strength = "強" }
                            }
                            '#microsoft.graph.fido2AuthenticationMethod' {
                                $hasMFA = $true
                                $strongAuthCount++
                                @{ Type = "FIDO2セキュリティキー"; Strength = "最強" }
                            }
                            '#microsoft.graph.emailAuthenticationMethod' {
                                $hasMFA = $true
                                @{ Type = "メール"; Strength = "弱" }
                            }
                            '#microsoft.graph.temporaryAccessPassAuthenticationMethod' {
                                @{ Type = "一時アクセスパス"; Strength = "一時的" }
                            }
                            default {
                                @{ Type = "その他"; Strength = "不明" }
                            }
                        }
                        
                        if ($methodInfo) {
                            $methodDetails += $methodInfo
                        }
                    }
                    
                    # セキュリティ評価
                    $securityScore = if ($strongAuthCount -ge 2) { "優秀" }
                                   elseif ($strongAuthCount -eq 1) { "良好" }
                                   elseif ($hasMFA) { "要改善" }
                                   else { "危険" }
                    
                    $mfaData += [PSCustomObject]@{
                        ユーザー名 = $user.DisplayName
                        メールアドレス = $user.UserPrincipalName
                        部署 = if ($user.Department) { $user.Department } else { "未設定" }
                        MFA有効 = $hasMFA
                        認証方法数 = $methodDetails.Count
                        認証方法詳細 = ($methodDetails | ForEach-Object { "$($_.Type)($($_.Strength))" }) -join ", "
                        強力な認証方法数 = $strongAuthCount
                        セキュリティ評価 = $securityScore
                        推奨事項 = if (-not $hasMFA) { "MFAを今すぐ有効化" }
                                  elseif ($strongAuthCount -eq 0) { "より強力な認証方法を追加" }
                                  elseif ($strongAuthCount -eq 1) { "バックアップ用の強力な認証方法を追加" }
                                  else { "現状を維持" }
                        最終確認 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
                    }
                }
                catch {
                    Write-Log "ユーザー $($user.UserPrincipalName) のMFA情報取得エラー" -Level "Debug"
                    
                    $mfaData += [PSCustomObject]@{
                        ユーザー名 = $user.DisplayName
                        メールアドレス = $user.UserPrincipalName
                        部署 = if ($user.Department) { $user.Department } else { "未設定" }
                        MFA有効 = "確認不可"
                        認証方法数 = "確認不可"
                        認証方法詳細 = "アクセス権限不足"
                        強力な認証方法数 = 0
                        セキュリティ評価 = "不明"
                        推奨事項 = "管理者に確認を依頼"
                        最終確認 = (Get-Date).ToString("yyyy-MM-dd HH:mm")
                    }
                }
            }
        }
        
        Write-Log "MFA状況詳細取得完了（$($mfaData.Count)件）" -Level "Info"
        return $mfaData
    }
    catch {
        Write-Log "MFA状況詳細取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# 条件付きアクセスポリシー実データ取得
function Get-ConditionalAccessPoliciesData {
    try {
        Write-Log "条件付きアクセスポリシーを取得中..." -Level "Info"
        
        $policies = Get-MgIdentityConditionalAccessPolicy -All
        $policyData = @()
        
        foreach ($policy in $policies) {
            # 対象ユーザー/グループの解析
            $includedUsers = @()
            $excludedUsers = @()
            
            if ($policy.Conditions.Users.IncludeUsers) {
                foreach ($userId in $policy.Conditions.Users.IncludeUsers) {
                    if ($userId -eq "All") {
                        $includedUsers += "すべてのユーザー"
                    }
                    else {
                        try {
                            $user = Get-MgUser -UserId $userId -Property DisplayName -ErrorAction Stop
                            $includedUsers += $user.DisplayName
                        }
                        catch {
                            $includedUsers += "不明なユーザー"
                        }
                    }
                }
            }
            
            if ($policy.Conditions.Users.IncludeGroups) {
                foreach ($groupId in $policy.Conditions.Users.IncludeGroups) {
                    try {
                        $group = Get-MgGroup -GroupId $groupId -Property DisplayName -ErrorAction Stop
                        $includedUsers += "$($group.DisplayName) (グループ)"
                    }
                    catch {
                        $includedUsers += "不明なグループ"
                    }
                }
            }
            
            # 対象アプリケーションの解析
            $targetApps = @()
            if ($policy.Conditions.Applications.IncludeApplications) {
                foreach ($appId in $policy.Conditions.Applications.IncludeApplications) {
                    if ($appId -eq "All") {
                        $targetApps += "すべてのクラウドアプリ"
                    }
                    elseif ($appId -eq "Office365") {
                        $targetApps += "Office 365"
                    }
                    else {
                        $targetApps += "カスタムアプリ"
                    }
                }
            }
            
            # 条件の解析
            $conditions = @()
            if ($policy.Conditions.Platforms.IncludePlatforms) {
                $conditions += "プラットフォーム: " + ($policy.Conditions.Platforms.IncludePlatforms -join ", ")
            }
            if ($policy.Conditions.Locations.IncludeLocations) {
                $conditions += "場所: 指定あり"
            }
            if ($policy.Conditions.ClientAppTypes) {
                $conditions += "クライアントアプリ: " + ($policy.Conditions.ClientAppTypes -join ", ")
            }
            if ($policy.Conditions.SignInRiskLevels) {
                $conditions += "サインインリスク: " + ($policy.Conditions.SignInRiskLevels -join ", ")
            }
            
            # アクセス制御の解析
            $controls = @()
            if ($policy.GrantControls.BuiltInControls) {
                foreach ($control in $policy.GrantControls.BuiltInControls) {
                    $controls += switch ($control) {
                        "mfa" { "多要素認証を要求" }
                        "compliantDevice" { "準拠デバイスを要求" }
                        "domainJoinedDevice" { "ドメイン参加済みデバイスを要求" }
                        "approvedApplication" { "承認済みアプリを要求" }
                        "compliantApplication" { "アプリ保護ポリシーを要求" }
                        default { $control }
                    }
                }
            }
            
            $policyData += [PSCustomObject]@{
                ポリシー名 = $policy.DisplayName
                状態 = if ($policy.State -eq "enabled") { "有効" } 
                      elseif ($policy.State -eq "disabled") { "無効" } 
                      else { "レポート専用" }
                対象ユーザー = if ($includedUsers.Count -gt 0) { $includedUsers -join ", " } else { "なし" }
                対象アプリ = if ($targetApps.Count -gt 0) { $targetApps -join ", " } else { "なし" }
                条件 = if ($conditions.Count -gt 0) { $conditions -join " | " } else { "なし" }
                アクセス制御 = if ($controls.Count -gt 0) { $controls -join ", " } else { "なし" }
                作成日 = if ($policy.CreatedDateTime) { [DateTime]::Parse($policy.CreatedDateTime).ToString("yyyy-MM-dd") } else { "不明" }
                更新日 = if ($policy.ModifiedDateTime) { [DateTime]::Parse($policy.ModifiedDateTime).ToString("yyyy-MM-dd") } else { "不明" }
                リスク評価 = if ($policy.State -eq "disabled") { "無効化されている" }
                            elseif ($controls -contains "多要素認証を要求") { "適切" }
                            else { "要確認" }
            }
        }
        
        Write-Log "条件付きアクセスポリシー取得完了（$($policyData.Count)件）" -Level "Info"
        return $policyData
    }
    catch {
        Write-Log "条件付きアクセスポリシー取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# サインインログ実データ取得
function Get-SignInLogsData {
    try {
        Write-Log "サインインログを取得中..." -Level "Info"
        
        # E3ライセンスでは過去7日間のログのみ取得可能
        $startDate = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd")
        $filter = "createdDateTime ge $($startDate)T00:00:00Z"
        
        # 最新1000件を取得（E3の制限）
        $signInLogs = Get-MgAuditLogSignIn -Filter $filter -Top 1000 -OrderBy "createdDateTime desc"
        $logData = @()
        
        foreach ($log in $signInLogs) {
            # エラーコードの解釈
            $statusDetail = if ($log.Status.ErrorCode -eq 0) { "成功" }
                          else {
                              $errorMessage = switch ($log.Status.ErrorCode) {
                                  50126 { "無効な資格情報" }
                                  50074 { "強力な認証が必要" }
                                  50076 { "多要素認証が必要" }
                                  50079 { "条件付きアクセスによりブロック" }
                                  53003 { "条件付きアクセスによりブロック" }
                                  530032 { "条件付きアクセスによりブロック（場所）" }
                                  default { $log.Status.FailureReason }
                              }
                              "失敗: $errorMessage"
                          }
            
            # リスクレベルの判定
            $riskLevel = if ($log.RiskLevelDuringSignIn) { $log.RiskLevelDuringSignIn }
                        elseif ($log.RiskLevelAggregated) { $log.RiskLevelAggregated }
                        else { "none" }
            
            $riskLevelJp = switch ($riskLevel) {
                "high" { "高" }
                "medium" { "中" }
                "low" { "低" }
                "none" { "なし" }
                default { "不明" }
            }
            
            # MFA詳細
            $mfaDetail = if ($log.IsInteractive -and $log.AuthenticationRequirement -eq "multiFactorAuthentication") {
                "MFA実行済み"
            }
            elseif ($log.AuthenticationRequirement -eq "singleFactorAuthentication") {
                "単一要素"
            }
            else {
                "N/A"
            }
            
            $logData += [PSCustomObject]@{
                日時 = [DateTime]::Parse($log.CreatedDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                ユーザー = $log.UserPrincipalName
                アプリケーション = if ($log.AppDisplayName) { $log.AppDisplayName } else { "不明" }
                結果 = $statusDetail
                IPアドレス = if ($log.IpAddress) { $log.IpAddress } else { "不明" }
                場所 = if ($log.Location.City -and $log.Location.CountryOrRegion) { 
                    "$($log.Location.City), $($log.Location.CountryOrRegion)" 
                } else { "不明" }
                デバイス = if ($log.DeviceDetail.OperatingSystem) {
                    "$($log.DeviceDetail.OperatingSystem) / $($log.DeviceDetail.Browser)"
                } else { "不明" }
                リスクレベル = $riskLevelJp
                MFA = $mfaDetail
                条件付きアクセス = if ($log.ConditionalAccessStatus -eq "success") { "通過" }
                                 elseif ($log.ConditionalAccessStatus -eq "failure") { "ブロック" }
                                 else { "未評価" }
            }
        }
        
        Write-Log "サインインログ取得完了（$($logData.Count)件）" -Level "Info"
        return $logData
    }
    catch {
        Write-Log "サインインログ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# ヘルパー関数
function Get-LicenseFriendlyName {
    param([string]$SkuPartNumber)
    
    switch ($SkuPartNumber) {
        "SPE_E3" { return "Microsoft 365 E3" }
        "SPE_E5" { return "Microsoft 365 E5" }
        "ENTERPRISEPACK" { return "Office 365 E3" }
        "ENTERPRISEPREMIUM" { return "Office 365 E5" }
        "EXCHANGESTANDARD" { return "Exchange Online (Plan 1)" }
        "EXCHANGEENTERPRISE" { return "Exchange Online (Plan 2)" }
        "TEAMS_EXPLORATORY" { return "Teams Exploratory" }
        "STREAM" { return "Microsoft Stream" }
        "POWER_BI_STANDARD" { return "Power BI (無料)" }
        "POWER_BI_PRO" { return "Power BI Pro" }
        default { return $SkuPartNumber }
    }
}

# エクスポート
Export-ModuleMember -Function @(
    'Get-M365RealUserData',
    'Get-MFAStatusRealData',
    'Get-ConditionalAccessPoliciesData',
    'Get-SignInLogsData'
)