# ================================================================================
# RealM365DataProvider.psm1
# Microsoft 365リアルタイムデータ取得モジュール
# 非対話型認証・本格運用対応
# ================================================================================

Import-Module "$PSScriptRoot\Authentication.psm1" -Force
Import-Module "$PSScriptRoot\Logging.psm1" -Force

# Microsoft 365リアルユーザーデータ取得
function Get-M365RealUserData {
    param(
        [int]$MaxUsers = 50,
        [switch]$IncludeLastSignIn = $true,
        [switch]$IncludeGroupMembership = $true
    )
    
    try {
        Write-Log "Microsoft 365実データユーザー取得開始" -Level "Info"
        
        # Microsoft Graph接続確認
        if (-not (Test-GraphConnection)) {
            Write-Log "Microsoft Graph未接続のため、自動接続を試行します" -Level "Warning"
            
            # 設定ファイル読み込み
            $configPath = Join-Path (Split-Path $PSScriptRoot -Parent -Resolve) "..\Config\appsettings.json"
            if (Test-Path $configPath) {
                $config = Get-Content $configPath | ConvertFrom-Json
                $connectResult = Connect-ToMicrosoft365 -Config $config -Services @("MicrosoftGraph")
                
                if (-not $connectResult.Success) {
                    throw "Microsoft Graph自動接続失敗: $($connectResult.ErrorMessage)"
                }
            }
            else {
                throw "設定ファイルが見つかりません: $configPath"
            }
        }
        
        # 実際のユーザーデータ収集
        $userData = @()
        
        # プロパティリスト（最適化）
        $userProperties = @(
            "Id", "UserPrincipalName", "DisplayName", "JobTitle", "Department", 
            "CompanyName", "OfficeLocation", "AccountEnabled", "CreatedDateTime",
            "AssignedLicenses", "SignInActivity"
        )
        
        # API制限を考慮してバッチ処理
        $batchSize = 25
        $totalUsers = 0
        
        do {
            $batch = Invoke-GraphAPIWithRetry -ScriptBlock {
                Get-MgUser -Top $batchSize -Property ($userProperties -join ",") -ErrorAction Stop
            } -MaxRetries 3 -Operation "ユーザーデータ取得"
            
            foreach ($user in $batch) {
                if ($totalUsers -ge $MaxUsers) { break }
                
                try {
                    # 基本情報
                    $userInfo = [PSCustomObject]@{
                        種別 = "ユーザー"
                        名前 = $user.DisplayName
                        プリンシパル = $user.UserPrincipalName
                        部署 = $user.Department ?? "未設定"
                        役職 = $user.JobTitle ?? "未設定"
                        場所 = $user.OfficeLocation ?? "未設定"
                        状態 = if ($user.AccountEnabled) { "有効" } else { "無効" }
                        作成日 = $user.CreatedDateTime ? $user.CreatedDateTime.ToString("yyyy/MM/dd") : "不明"
                        ライセンス数 = $user.AssignedLicenses ? $user.AssignedLicenses.Count : 0
                        最終サインイン = "取得中"
                        グループ数 = 0
                        リスクレベル = "評価中"
                        推奨アクション = "確認中"
                    }
                    
                    # 最終サインイン情報（API制限考慮）
                    if ($IncludeLastSignIn) {
                        try {
                            $signInData = Invoke-GraphAPIWithRetry -ScriptBlock {
                                Get-MgUser -UserId $user.Id -Property "SignInActivity" -ErrorAction Stop
                            } -MaxRetries 2 -Operation "サインイン情報取得"
                            
                            if ($signInData.SignInActivity) {
                                $lastSignIn = $signInData.SignInActivity.LastSignInDateTime
                                if ($lastSignIn) {
                                    $userInfo.最終サインイン = $lastSignIn.ToString("yyyy/MM/dd HH:mm")
                                    
                                    # リスク評価（最終サインインベース）
                                    $daysSinceLastSignIn = (Get-Date) - $lastSignIn
                                    if ($daysSinceLastSignIn.Days -gt 90) {
                                        $userInfo.リスクレベル = "高"
                                        $userInfo.推奨アクション = "アカウント確認要"
                                    } elseif ($daysSinceLastSignIn.Days -gt 30) {
                                        $userInfo.リスクレベル = "中"
                                        $userInfo.推奨アクション = "利用状況確認"
                                    } else {
                                        $userInfo.リスクレベル = "低"
                                        $userInfo.推奨アクション = "定期確認"
                                    }
                                }
                            }
                        } catch {
                            $userInfo.最終サインイン = "取得失敗"
                            Write-Log "ユーザー $($user.UserPrincipalName) のサインイン情報取得失敗: $($_.Exception.Message)" -Level "Warning"
                        }
                    }
                    
                    # グループメンバーシップ情報
                    if ($IncludeGroupMembership) {
                        try {
                            $memberOf = Invoke-GraphAPIWithRetry -ScriptBlock {
                                Get-MgUserMemberOf -UserId $user.Id -Top 10 -ErrorAction Stop
                            } -MaxRetries 2 -Operation "グループメンバーシップ取得"
                            
                            $userInfo.グループ数 = $memberOf ? $memberOf.Count : 0
                            
                            # グループ数でリスク評価更新
                            if ($userInfo.グループ数 -gt 15) {
                                $userInfo.リスクレベル = "高"
                                $userInfo.推奨アクション = "権限見直し要"
                            } elseif ($userInfo.グループ数 -gt 8) {
                                if ($userInfo.リスクレベル -ne "高") {
                                    $userInfo.リスクレベル = "中"
                                    $userInfo.推奨アクション = "権限確認"
                                }
                            }
                        } catch {
                            Write-Log "ユーザー $($user.UserPrincipalName) のグループ情報取得失敗: $($_.Exception.Message)" -Level "Warning"
                        }
                    }
                    
                    $userData += $userInfo
                    $totalUsers++
                }
                catch {
                    Write-Log "ユーザー $($user.UserPrincipalName) の処理中エラー: $($_.Exception.Message)" -Level "Warning"
                    continue
                }
            }
        } while ($batch.Count -eq $batchSize -and $totalUsers -lt $MaxUsers)
        
        Write-Log "Microsoft 365実データユーザー取得完了: $($userData.Count)件" -Level "Info"
        return $userData
    }
    catch {
        Write-Log "Microsoft 365実データ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# Microsoft 365リアルグループデータ取得
function Get-M365RealGroupData {
    param(
        [int]$MaxGroups = 25
    )
    
    try {
        Write-Log "Microsoft 365実データグループ取得開始" -Level "Info"
        
        $groupData = @()
        $groupProperties = @(
            "Id", "DisplayName", "GroupTypes", "CreatedDateTime", 
            "Description", "Visibility", "ResourceProvisioningOptions"
        )
        
        $groups = Invoke-GraphAPIWithRetry -ScriptBlock {
            Get-MgGroup -Top $MaxGroups -Property ($groupProperties -join ",") -ErrorAction Stop
        } -MaxRetries 3 -Operation "グループデータ取得"
        
        foreach ($group in $groups) {
            try {
                # メンバー数取得
                $memberCount = 0
                try {
                    $members = Invoke-GraphAPIWithRetry -ScriptBlock {
                        Get-MgGroupMember -GroupId $group.Id -Top 1 -ErrorAction Stop
                    } -MaxRetries 2 -Operation "グループメンバー確認"
                    
                    if ($members) {
                        $allMembers = Invoke-GraphAPIWithRetry -ScriptBlock {
                            Get-MgGroupMember -GroupId $group.Id -All -ErrorAction Stop
                        } -MaxRetries 2 -Operation "全メンバー取得"
                        $memberCount = $allMembers ? $allMembers.Count : 0
                    }
                } catch {
                    Write-Log "グループ $($group.DisplayName) のメンバー情報取得失敗" -Level "Warning"
                }
                
                # グループタイプ判定
                $groupType = "セキュリティ"
                if ($group.GroupTypes -contains "Unified") {
                    $groupType = "Microsoft 365"
                } elseif ($group.ResourceProvisioningOptions -contains "Team") {
                    $groupType = "Teams"
                }
                
                # リスク評価
                $riskLevel = "低"
                $action = "定期確認"
                if ($memberCount -gt 100) {
                    $riskLevel = "高"
                    $action = "メンバー見直し要"
                } elseif ($memberCount -gt 50) {
                    $riskLevel = "中"
                    $action = "メンバー確認"
                }
                
                $groupInfo = [PSCustomObject]@{
                    種別 = "グループ"
                    名前 = $group.DisplayName
                    プリンシパル = $groupType
                    説明 = $group.Description ?? "未設定"
                    可視性 = $group.Visibility ?? "未設定"
                    メンバー数 = $memberCount
                    作成日 = $group.CreatedDateTime ? $group.CreatedDateTime.ToString("yyyy/MM/dd") : "不明"
                    リスクレベル = $riskLevel
                    推奨アクション = $action
                }
                
                $groupData += $groupInfo
            }
            catch {
                Write-Log "グループ $($group.DisplayName) の処理中エラー: $($_.Exception.Message)" -Level "Warning"
                continue
            }
        }
        
        Write-Log "Microsoft 365実データグループ取得完了: $($groupData.Count)件" -Level "Info"
        return $groupData
    }
    catch {
        Write-Log "Microsoft 365グループデータ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# Microsoft 365セキュリティ分析データ取得
function Get-M365SecurityAnalysisData {
    param(
        [int]$MaxUsers = 30
    )
    
    try {
        Write-Log "Microsoft 365セキュリティ分析データ取得開始" -Level "Info"
        
        $securityData = @()
        
        # ユーザーのセキュリティ情報取得
        $users = Invoke-GraphAPIWithRetry -ScriptBlock {
            Get-MgUser -Top $MaxUsers -Property "Id,UserPrincipalName,DisplayName,AccountEnabled,SignInActivity,AssignedLicenses" -ErrorAction Stop
        } -MaxRetries 3 -Operation "セキュリティ分析用ユーザー取得"
        
        foreach ($user in $users) {
            try {
                # リスク判定用データ収集
                $riskFactors = @()
                $riskScore = 0
                
                # アカウント状態
                if (-not $user.AccountEnabled) {
                    $riskFactors += "無効アカウント"
                    $riskScore += 5
                }
                
                # サインイン状況
                $lastSignIn = "不明"
                $signInRisk = "低"
                try {
                    $signInInfo = Invoke-GraphAPIWithRetry -ScriptBlock {
                        Get-MgUser -UserId $user.Id -Property "SignInActivity" -ErrorAction Stop
                    } -MaxRetries 2 -Operation "サインイン情報取得"
                    
                    if ($signInInfo.SignInActivity -and $signInInfo.SignInActivity.LastSignInDateTime) {
                        $lastSignInDate = $signInInfo.SignInActivity.LastSignInDateTime
                        $lastSignIn = $lastSignInDate.ToString("yyyy/MM/dd")
                        $daysSince = (Get-Date) - $lastSignInDate
                        
                        if ($daysSince.Days -gt 90) {
                            $riskFactors += "長期未サインイン"
                            $signInRisk = "高"
                            $riskScore += 8
                        } elseif ($daysSince.Days -gt 30) {
                            $riskFactors += "中期未サインイン"
                            $signInRisk = "中"
                            $riskScore += 4
                        }
                    }
                } catch {
                    $riskFactors += "サインイン情報取得失敗"
                    $riskScore += 2
                }
                
                # ライセンス状況
                $licenseCount = $user.AssignedLicenses ? $user.AssignedLicenses.Count : 0
                $licenseRisk = "低"
                if ($licenseCount -eq 0) {
                    $riskFactors += "ライセンス未割り当て"
                    $licenseRisk = "中"
                    $riskScore += 3
                } elseif ($licenseCount -gt 5) {
                    $riskFactors += "多数ライセンス"
                    $licenseRisk = "中"
                    $riskScore += 2
                }
                
                # 総合リスクレベル判定
                $totalRisk = "低"
                $recommendation = "定期監視"
                if ($riskScore -gt 10) {
                    $totalRisk = "高"
                    $recommendation = "即座に確認要"
                } elseif ($riskScore -gt 5) {
                    $totalRisk = "中"
                    $recommendation = "詳細確認要"
                }
                
                $securityInfo = [PSCustomObject]@{
                    ユーザー名 = $user.DisplayName
                    プリンシパル = $user.UserPrincipalName
                    アカウント状態 = if ($user.AccountEnabled) { "有効" } else { "無効" }
                    最終サインイン = $lastSignIn
                    サインインリスク = $signInRisk
                    ライセンス数 = $licenseCount
                    ライセンスリスク = $licenseRisk
                    リスク要因 = if ($riskFactors.Count -gt 0) { $riskFactors -join ", " } else { "なし" }
                    リスクスコア = $riskScore
                    総合リスク = $totalRisk
                    推奨対応 = $recommendation
                    確認日 = (Get-Date).ToString("yyyy/MM/dd")
                }
                
                $securityData += $securityInfo
            }
            catch {
                Write-Log "ユーザー $($user.UserPrincipalName) のセキュリティ分析エラー: $($_.Exception.Message)" -Level "Warning"
                continue
            }
        }
        
        Write-Log "Microsoft 365セキュリティ分析完了: $($securityData.Count)件" -Level "Info"
        return $securityData
    }
    catch {
        Write-Log "Microsoft 365セキュリティ分析エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# 使用状況分析データ取得
function Get-M365UsageAnalysisData {
    param(
        [int]$DaysBack = 30
    )
    
    try {
        Write-Log "Microsoft 365使用状況分析開始" -Level "Info"
        
        $usageData = @()
        
        # Microsoft Graph レポートAPI使用
        try {
            # Office 365使用状況レポート
            $office365Usage = Invoke-GraphAPIWithRetry -ScriptBlock {
                Get-MgReportOffice365ActiveUserDetail -Period "D$DaysBack" -ErrorAction Stop
            } -MaxRetries 3 -Operation "Office 365使用状況取得"
            
            if ($office365Usage) {
                # CSVデータをパース
                $csvData = $office365Usage | ConvertFrom-Csv
                
                foreach ($userUsage in $csvData | Select-Object -First 25) {
                    $usageInfo = [PSCustomObject]@{
                        ユーザー名 = $userUsage."Display Name"
                        プリンシパル = $userUsage."User Principal Name"
                        Exchange利用 = $userUsage."Has Exchange License"
                        OneDrive利用 = $userUsage."Has OneDrive License"  
                        SharePoint利用 = $userUsage."Has SharePoint License"
                        Teams利用 = $userUsage."Has Teams License"
                        最終アクティビティ = $userUsage."Last Activity Date"
                        分析期間 = "${DaysBack}日間"
                        取得日時 = (Get-Date).ToString("yyyy/MM/dd HH:mm")
                    }
                    $usageData += $usageInfo
                }
            }
        } catch {
            Write-Log "Office 365使用状況レポート取得失敗: $($_.Exception.Message)" -Level "Warning"
            
            # フォールバック: 基本的なユーザー情報での使用状況推定
            $users = Get-MgUser -Top 20 -Property "Id,UserPrincipalName,DisplayName,AssignedLicenses" -ErrorAction SilentlyContinue
            foreach ($user in $users) {
                $licenseInfo = $user.AssignedLicenses | ForEach-Object { 
                    # ライセンスSKU IDから製品名を推定
                    switch ($_.SkuId) {
                        "6fd2c87f-b296-42f0-b197-1e91e994b900" { "Office 365 E3" }
                        "c7df2760-2c81-4ef7-b578-5b5392b571df" { "Office 365 E5" }
                        default { "その他" }
                    }
                }
                
                $usageInfo = [PSCustomObject]@{
                    ユーザー名 = $user.DisplayName
                    プリンシパル = $user.UserPrincipalName
                    ライセンス = ($licenseInfo -join ", ") ?? "未割り当て"
                    推定利用状況 = if ($user.AssignedLicenses.Count -gt 0) { "利用中" } else { "未利用" }
                    分析期間 = "${DaysBack}日間"
                    取得日時 = (Get-Date).ToString("yyyy/MM/dd HH:mm")
                }
                $usageData += $usageInfo
            }
        }
        
        Write-Log "Microsoft 365使用状況分析完了: $($usageData.Count)件" -Level "Info"
        return $usageData
    }
    catch {
        Write-Log "Microsoft 365使用状況分析エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

Export-ModuleMember -Function Get-M365RealUserData, Get-M365RealGroupData, Get-M365SecurityAnalysisData, Get-M365UsageAnalysisData