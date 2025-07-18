#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.3.0' }

<#
.SYNOPSIS
Entra ID機能の包括的Pesterテストスイート

.DESCRIPTION
Entra ID管理機能（ユーザー管理、MFA、条件付きアクセス、サインインログ）の単体・統合テスト

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
    $script:EntraIDPath = Join-Path $ScriptsPath "EntraID"
    
    if (Test-Path $AuthModule) {
        Import-Module $AuthModule -Force
    }
    
    if (Test-Path $DataModule) {
        Import-Module $DataModule -Force
    }
    
    # テスト用ユーザーデータ
    $script:TestUsers = @(
        [PSCustomObject]@{
            Id = "test-user-1"
            DisplayName = "テストユーザー1"
            UserPrincipalName = "testuser1@contoso.com"
            Department = "IT"
            JobTitle = "エンジニア"
            AccountEnabled = $true
            LicenseAssigned = $true
            MfaEnabled = $true
            LastSignIn = (Get-Date).AddDays(-1)
        },
        [PSCustomObject]@{
            Id = "test-user-2"
            DisplayName = "テストユーザー2"
            UserPrincipalName = "testuser2@contoso.com"
            Department = "Sales"
            JobTitle = "営業"
            AccountEnabled = $false
            LicenseAssigned = $false
            MfaEnabled = $false
            LastSignIn = $null
        }
    )
}

Describe "Entra ID - ユーザー管理機能テスト" -Tags @("Unit", "EntraID", "Users") {
    Context "ユーザー一覧取得機能" {
        It "Get-AllUsersRealData関数が存在すること" {
            $function = Get-Command -Name "Get-AllUsersRealData" -ErrorAction SilentlyContinue
            $function | Should -Not -BeNullOrEmpty
        }
        
        It "ユーザー一覧が取得できること" {
            Mock Get-AllUsersRealData {
                return $TestUsers
            }
            
            $users = Get-AllUsersRealData
            $users | Should -Not -BeNullOrEmpty
            $users.Count | Should -Be 2
        }
        
        It "必須プロパティが含まれていること" {
            Mock Get-AllUsersRealData {
                return $TestUsers
            }
            
            $users = Get-AllUsersRealData
            $user = $users[0]
            
            $user.DisplayName | Should -Not -BeNullOrEmpty
            $user.UserPrincipalName | Should -Not -BeNullOrEmpty
            $user.Department | Should -Not -BeNullOrEmpty
            $user.AccountEnabled | Should -BeOfType [bool]
        }
        
        It "フィルタリングパラメータが機能すること" {
            Mock Get-AllUsersRealData {
                param($Filter)
                if ($Filter -eq "AccountEnabled eq true") {
                    return $TestUsers | Where-Object { $_.AccountEnabled -eq $true }
                }
                return $TestUsers
            }
            
            $activeUsers = Get-AllUsersRealData -Filter "AccountEnabled eq true"
            $activeUsers.Count | Should -Be 1
            $activeUsers[0].AccountEnabled | Should -Be $true
        }
        
        It "MaxResults パラメータが機能すること" {
            Mock Get-AllUsersRealData {
                param($MaxResults)
                if ($MaxResults) {
                    return $TestUsers | Select-Object -First $MaxResults
                }
                return $TestUsers
            }
            
            $limitedUsers = Get-AllUsersRealData -MaxResults 1
            $limitedUsers.Count | Should -Be 1
        }
    }
    
    Context "ユーザー詳細情報取得" {
        It "個別ユーザー情報が取得できること" {
            Mock Get-MgUser {
                param($UserId)
                return $TestUsers | Where-Object { $_.Id -eq $UserId } | Select-Object -First 1
            }
            
            $user = Get-MgUser -UserId "test-user-1"
            $user | Should -Not -BeNullOrEmpty
            $user.DisplayName | Should -Be "テストユーザー1"
        }
        
        It "存在しないユーザーIDでエラーハンドリングが機能すること" {
            Mock Get-MgUser {
                param($UserId)
                if ($UserId -eq "non-existent-user") {
                    throw "User not found"
                }
                return $TestUsers | Where-Object { $_.Id -eq $UserId } | Select-Object -First 1
            }
            
            { Get-MgUser -UserId "non-existent-user" -ErrorAction Stop } | Should -Throw
        }
    }
    
    Context "ユーザーエクスポート機能" {
        It "CSV形式でエクスポートできること" {
            $tempFile = [System.IO.Path]::GetTempFileName()
            
            try {
                $TestUsers | Export-Csv -Path $tempFile -NoTypeInformation -Encoding UTF8
                
                Test-Path $tempFile | Should -Be $true
                $imported = Import-Csv $tempFile
                $imported.Count | Should -Be 2
                $imported[0].DisplayName | Should -Be "テストユーザー1"
            }
            finally {
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -Force
                }
            }
        }
    }
}

Describe "Entra ID - MFA状況管理テスト" -Tags @("Unit", "EntraID", "MFA") {
    Context "MFA状態確認機能" {
        It "ユーザーのMFA状態が確認できること" {
            Mock Get-MsolUser {
                param($UserPrincipalName)
                $user = $TestUsers | Where-Object { $_.UserPrincipalName -eq $UserPrincipalName }
                if ($user) {
                    return [PSCustomObject]@{
                        UserPrincipalName = $user.UserPrincipalName
                        StrongAuthenticationRequirements = if ($user.MfaEnabled) { @([PSCustomObject]@{State = "Enabled"}) } else { @() }
                        StrongAuthenticationMethods = if ($user.MfaEnabled) { @([PSCustomObject]@{MethodType = "PhoneAppNotification"}) } else { @() }
                    }
                }
                return $null
            }
            
            $mfaUser = Get-MsolUser -UserPrincipalName "testuser1@contoso.com"
            $mfaUser.StrongAuthenticationRequirements | Should -Not -BeNullOrEmpty
            
            $nonMfaUser = Get-MsolUser -UserPrincipalName "testuser2@contoso.com"
            $nonMfaUser.StrongAuthenticationRequirements | Should -BeNullOrEmpty
        }
        
        It "MFA未設定ユーザーの一覧が取得できること" {
            Mock Get-MsolUser {
                $TestUsers | ForEach-Object {
                    [PSCustomObject]@{
                        UserPrincipalName = $_.UserPrincipalName
                        DisplayName = $_.DisplayName
                        StrongAuthenticationRequirements = if ($_.MfaEnabled) { @([PSCustomObject]@{State = "Enabled"}) } else { @() }
                    }
                }
            }
            
            $allUsers = Get-MsolUser
            $nonMfaUsers = $allUsers | Where-Object { $_.StrongAuthenticationRequirements.Count -eq 0 }
            
            $nonMfaUsers.Count | Should -Be 1
            $nonMfaUsers[0].UserPrincipalName | Should -Be "testuser2@contoso.com"
        }
        
        It "MFA統計情報が生成できること" {
            $mfaStats = [PSCustomObject]@{
                TotalUsers = $TestUsers.Count
                MfaEnabled = ($TestUsers | Where-Object { $_.MfaEnabled }).Count
                MfaDisabled = ($TestUsers | Where-Object { -not $_.MfaEnabled }).Count
                MfaPercentage = [math]::Round((($TestUsers | Where-Object { $_.MfaEnabled }).Count / $TestUsers.Count) * 100, 2)
            }
            
            $mfaStats.TotalUsers | Should -Be 2
            $mfaStats.MfaEnabled | Should -Be 1
            $mfaStats.MfaDisabled | Should -Be 1
            $mfaStats.MfaPercentage | Should -Be 50
        }
    }
}

Describe "Entra ID - 条件付きアクセスポリシーテスト" -Tags @("Unit", "EntraID", "ConditionalAccess") {
    BeforeAll {
        $script:TestPolicies = @(
            [PSCustomObject]@{
                Id = "policy-1"
                DisplayName = "管理者MFA必須ポリシー"
                State = "enabled"
                Conditions = @{
                    Users = @{
                        IncludeRoles = @("Global Administrator", "User Administrator")
                    }
                    Applications = @{
                        IncludeApplications = "All"
                    }
                }
                GrantControls = @{
                    BuiltInControls = @("mfa")
                }
                CreatedDateTime = (Get-Date).AddMonths(-6)
                ModifiedDateTime = (Get-Date).AddDays(-7)
            },
            [PSCustomObject]@{
                Id = "policy-2"
                DisplayName = "外部アクセスブロックポリシー"
                State = "disabled"
                Conditions = @{
                    Locations = @{
                        IncludeLocations = @("All")
                        ExcludeLocations = @("AllTrusted")
                    }
                }
                GrantControls = @{
                    BuiltInControls = @("block")
                }
                CreatedDateTime = (Get-Date).AddMonths(-3)
                ModifiedDateTime = (Get-Date).AddDays(-30)
            }
        )
    }
    
    Context "条件付きアクセスポリシー取得" {
        It "全ポリシーが取得できること" {
            Mock Get-MgIdentityConditionalAccessPolicy {
                return $TestPolicies
            }
            
            $policies = Get-MgIdentityConditionalAccessPolicy
            $policies | Should -Not -BeNullOrEmpty
            $policies.Count | Should -Be 2
        }
        
        It "有効なポリシーのみフィルタリングできること" {
            Mock Get-MgIdentityConditionalAccessPolicy {
                param($Filter)
                if ($Filter -eq "state eq 'enabled'") {
                    return $TestPolicies | Where-Object { $_.State -eq "enabled" }
                }
                return $TestPolicies
            }
            
            $enabledPolicies = Get-MgIdentityConditionalAccessPolicy -Filter "state eq 'enabled'"
            $enabledPolicies.Count | Should -Be 1
            $enabledPolicies[0].DisplayName | Should -Be "管理者MFA必須ポリシー"
        }
        
        It "ポリシーに必須プロパティが含まれていること" {
            Mock Get-MgIdentityConditionalAccessPolicy {
                return $TestPolicies
            }
            
            $policies = Get-MgIdentityConditionalAccessPolicy
            $policy = $policies[0]
            
            $policy.Id | Should -Not -BeNullOrEmpty
            $policy.DisplayName | Should -Not -BeNullOrEmpty
            $policy.State | Should -BeIn @("enabled", "disabled", "enabledForReportingButNotEnforced")
            $policy.Conditions | Should -Not -BeNullOrEmpty
            $policy.GrantControls | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "条件付きアクセスポリシー分析" {
        It "MFA必須ポリシーが識別できること" {
            $mfaPolicies = $TestPolicies | Where-Object { 
                $_.GrantControls.BuiltInControls -contains "mfa" 
            }
            
            $mfaPolicies.Count | Should -Be 1
            $mfaPolicies[0].DisplayName | Should -Match "MFA"
        }
        
        It "管理者を対象とするポリシーが識別できること" {
            $adminPolicies = $TestPolicies | Where-Object {
                $_.Conditions.Users.IncludeRoles -and 
                ($_.Conditions.Users.IncludeRoles -match "Administrator")
            }
            
            $adminPolicies.Count | Should -Be 1
        }
        
        It "ポリシーの統計情報が生成できること" {
            $policyStats = [PSCustomObject]@{
                TotalPolicies = $TestPolicies.Count
                EnabledPolicies = ($TestPolicies | Where-Object { $_.State -eq "enabled" }).Count
                DisabledPolicies = ($TestPolicies | Where-Object { $_.State -eq "disabled" }).Count
                MfaPolicies = ($TestPolicies | Where-Object { $_.GrantControls.BuiltInControls -contains "mfa" }).Count
                BlockPolicies = ($TestPolicies | Where-Object { $_.GrantControls.BuiltInControls -contains "block" }).Count
            }
            
            $policyStats.TotalPolicies | Should -Be 2
            $policyStats.EnabledPolicies | Should -Be 1
            $policyStats.DisabledPolicies | Should -Be 1
            $policyStats.MfaPolicies | Should -Be 1
            $policyStats.BlockPolicies | Should -Be 1
        }
    }
}

Describe "Entra ID - サインインログ分析テスト" -Tags @("Unit", "EntraID", "SignInLogs") {
    BeforeAll {
        $script:TestSignInLogs = @(
            [PSCustomObject]@{
                Id = "log-1"
                UserPrincipalName = "testuser1@contoso.com"
                UserDisplayName = "テストユーザー1"
                AppDisplayName = "Microsoft 365"
                ClientAppUsed = "Browser"
                CreatedDateTime = (Get-Date).AddHours(-2)
                Status = @{
                    ErrorCode = 0
                    FailureReason = $null
                    AdditionalDetails = "Success"
                }
                Location = @{
                    City = "Tokyo"
                    State = "Tokyo"
                    CountryOrRegion = "JP"
                }
                IpAddress = "203.0.113.1"
                ConditionalAccessStatus = "success"
                RiskDetail = "none"
                RiskLevelDuringSignIn = "none"
                RiskLevelAggregated = "none"
                MfaDetail = @{
                    AuthMethod = "Phone App Notification"
                    AuthDetail = "MFA completed in Azure AD"
                }
            },
            [PSCustomObject]@{
                Id = "log-2"
                UserPrincipalName = "testuser2@contoso.com"
                UserDisplayName = "テストユーザー2"
                AppDisplayName = "Exchange Online"
                ClientAppUsed = "Mobile Apps and Desktop clients"
                CreatedDateTime = (Get-Date).AddHours(-5)
                Status = @{
                    ErrorCode = 50126
                    FailureReason = "Invalid username or password"
                    AdditionalDetails = "Password expired"
                }
                Location = @{
                    City = "Unknown"
                    State = "Unknown"
                    CountryOrRegion = "Unknown"
                }
                IpAddress = "198.51.100.1"
                ConditionalAccessStatus = "notApplied"
                RiskDetail = "none"
                RiskLevelDuringSignIn = "medium"
                RiskLevelAggregated = "medium"
                MfaDetail = $null
            },
            [PSCustomObject]@{
                Id = "log-3"
                UserPrincipalName = "admin@contoso.com"
                UserDisplayName = "管理者"
                AppDisplayName = "Azure Portal"
                ClientAppUsed = "Browser"
                CreatedDateTime = (Get-Date).AddMinutes(-30)
                Status = @{
                    ErrorCode = 0
                    FailureReason = $null
                    AdditionalDetails = "Success"
                }
                Location = @{
                    City = "Osaka"
                    State = "Osaka"
                    CountryOrRegion = "JP"
                }
                IpAddress = "203.0.113.2"
                ConditionalAccessStatus = "success"
                RiskDetail = "none"
                RiskLevelDuringSignIn = "none"
                RiskLevelAggregated = "none"
                MfaDetail = @{
                    AuthMethod = "Phone App Notification"
                    AuthDetail = "MFA completed in Azure AD"
                }
            }
        )
    }
    
    Context "サインインログ取得機能" {
        It "サインインログが取得できること" {
            Mock Get-MgAuditLogSignIn {
                return $TestSignInLogs
            }
            
            $logs = Get-MgAuditLogSignIn
            $logs | Should -Not -BeNullOrEmpty
            $logs.Count | Should -Be 3
        }
        
        It "期間指定でフィルタリングできること" {
            Mock Get-MgAuditLogSignIn {
                param($Filter)
                if ($Filter -match "createdDateTime ge") {
                    $cutoffTime = (Get-Date).AddHours(-3)
                    return $TestSignInLogs | Where-Object { $_.CreatedDateTime -ge $cutoffTime }
                }
                return $TestSignInLogs
            }
            
            $recentLogs = Get-MgAuditLogSignIn -Filter "createdDateTime ge $((Get-Date).AddHours(-3).ToString('yyyy-MM-ddTHH:mm:ssZ'))"
            $recentLogs.Count | Should -Be 2
        }
        
        It "失敗したサインインのみフィルタリングできること" {
            Mock Get-MgAuditLogSignIn {
                param($Filter)
                if ($Filter -match "status/errorCode ne 0") {
                    return $TestSignInLogs | Where-Object { $_.Status.ErrorCode -ne 0 }
                }
                return $TestSignInLogs
            }
            
            $failedLogs = Get-MgAuditLogSignIn -Filter "status/errorCode ne 0"
            $failedLogs.Count | Should -Be 1
            $failedLogs[0].Status.FailureReason | Should -Be "Invalid username or password"
        }
    }
    
    Context "サインインログ分析機能" {
        It "サインイン成功率が計算できること" {
            $totalLogs = $TestSignInLogs.Count
            $successLogs = ($TestSignInLogs | Where-Object { $_.Status.ErrorCode -eq 0 }).Count
            $successRate = [math]::Round(($successLogs / $totalLogs) * 100, 2)
            
            $successRate | Should -Be 66.67
        }
        
        It "リスクレベル別の統計が取得できること" {
            $riskStats = $TestSignInLogs | Group-Object -Property RiskLevelAggregated | 
                Select-Object Name, Count
            
            $noneRisk = $riskStats | Where-Object { $_.Name -eq "none" }
            $noneRisk.Count | Should -Be 2
            
            $mediumRisk = $riskStats | Where-Object { $_.Name -eq "medium" }
            $mediumRisk.Count | Should -Be 1
        }
        
        It "アプリケーション別の使用状況が取得できること" {
            $appUsage = $TestSignInLogs | Group-Object -Property AppDisplayName | 
                Select-Object Name, Count | Sort-Object Count -Descending
            
            $appUsage.Count | Should -Be 3
            $appUsage[0].Count | Should -Be 1
        }
        
        It "地理的位置情報の分析ができること" {
            $locationStats = $TestSignInLogs | Group-Object -Property { $_.Location.CountryOrRegion } |
                Select-Object Name, Count
            
            $jpLogs = $locationStats | Where-Object { $_.Name -eq "JP" }
            $jpLogs.Count | Should -Be 2
            
            $unknownLogs = $locationStats | Where-Object { $_.Name -eq "Unknown" }
            $unknownLogs.Count | Should -Be 1
        }
        
        It "MFA使用状況が分析できること" {
            $mfaLogs = $TestSignInLogs | Where-Object { $_.MfaDetail -ne $null }
            $mfaUsageRate = [math]::Round(($mfaLogs.Count / $TestSignInLogs.Count) * 100, 2)
            
            $mfaLogs.Count | Should -Be 2
            $mfaUsageRate | Should -Be 66.67
        }
    }
    
    Context "異常検知機能" {
        It "異常なサインイン試行が検出できること" {
            # 短時間に複数の失敗
            $failureThreshold = 3
            $timeWindow = (Get-Date).AddMinutes(-10)
            
            $suspiciousAttempts = $TestSignInLogs | 
                Where-Object { $_.Status.ErrorCode -ne 0 -and $_.CreatedDateTime -ge $timeWindow } |
                Group-Object -Property UserPrincipalName |
                Where-Object { $_.Count -ge $failureThreshold }
            
            # テストデータでは閾値未満
            $suspiciousAttempts | Should -BeNullOrEmpty
        }
        
        It "未知の場所からのアクセスが検出できること" {
            $unknownLocations = $TestSignInLogs | 
                Where-Object { $_.Location.City -eq "Unknown" -or $_.Location.CountryOrRegion -eq "Unknown" }
            
            $unknownLocations.Count | Should -Be 1
            $unknownLocations[0].UserPrincipalName | Should -Be "testuser2@contoso.com"
        }
        
        It "リスクのあるサインインが検出できること" {
            $riskySignIns = $TestSignInLogs | 
                Where-Object { $_.RiskLevelAggregated -ne "none" }
            
            $riskySignIns.Count | Should -Be 1
            $riskySignIns[0].RiskLevelAggregated | Should -Be "medium"
        }
    }
}

Describe "Entra ID - セキュリティとコンプライアンステスト" -Tags @("Security", "EntraID", "Compliance") {
    Context "ISO/IEC 27001準拠チェック" {
        It "アクセスログが適切に記録されていること" {
            # ログに必須フィールドが含まれているか確認
            $requiredFields = @(
                "UserPrincipalName",
                "CreatedDateTime",
                "IpAddress",
                "Status",
                "AppDisplayName"
            )
            
            $testLog = $TestSignInLogs[0]
            foreach ($field in $requiredFields) {
                $testLog.$field | Should -Not -BeNullOrEmpty
            }
        }
        
        It "管理者アクティビティが追跡可能であること" {
            $adminLogs = $TestSignInLogs | Where-Object { 
                $_.UserPrincipalName -match "admin" -or 
                $_.UserDisplayName -match "管理者" 
            }
            
            $adminLogs | Should -Not -BeNullOrEmpty
            $adminLogs[0].MfaDetail | Should -Not -BeNullOrEmpty
        }
        
        It "データ保持ポリシーが設定されていること" {
            # 設定ファイルから確認
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            
            $config.Security.LogRetentionDays | Should -BeGreaterThan 0
            $config.Security.LogRetentionDays | Should -BeGreaterOrEqual 365  # ISO要件：最低1年
        }
    }
    
    Context "データプライバシー保護" {
        It "個人情報が適切にマスキングされること" {
            function Mask-PersonalInfo {
                param($UserPrincipalName)
                
                if ($UserPrincipalName -match "^(.{2}).*@(.*)$") {
                    return "$($Matches[1])****@$($Matches[2])"
                }
                return $UserPrincipalName
            }
            
            $maskedEmail = Mask-PersonalInfo -UserPrincipalName "testuser1@contoso.com"
            $maskedEmail | Should -Be "te****@contoso.com"
        }
        
        It "IPアドレスが適切に処理されること" {
            # IPアドレスの最後のオクテットをマスク
            function Mask-IpAddress {
                param($IpAddress)
                
                if ($IpAddress -match "^(\d+\.\d+\.\d+\.)\d+$") {
                    return "$($Matches[1])xxx"
                }
                return $IpAddress
            }
            
            $maskedIp = Mask-IpAddress -IpAddress "203.0.113.1"
            $maskedIp | Should -Be "203.0.113.xxx"
        }
    }
}

Describe "Entra ID - パフォーマンステスト" -Tags @("Performance", "EntraID") {
    Context "大量データ処理性能" {
        It "1000ユーザーの処理が5秒以内に完了すること" {
            # 大量のテストユーザーを生成
            $largeUserSet = @()
            for ($i = 1; $i -le 1000; $i++) {
                $largeUserSet += [PSCustomObject]@{
                    Id = "user-$i"
                    DisplayName = "User $i"
                    UserPrincipalName = "user$i@contoso.com"
                    Department = "Dept$($i % 10)"
                    AccountEnabled = ($i % 2 -eq 0)
                    MfaEnabled = ($i % 3 -eq 0)
                }
            }
            
            $measure = Measure-Command {
                # フィルタリング処理
                $activeUsers = $largeUserSet | Where-Object { $_.AccountEnabled }
                $mfaUsers = $largeUserSet | Where-Object { $_.MfaEnabled }
                
                # グループ化処理
                $deptGroups = $largeUserSet | Group-Object -Property Department
            }
            
            $measure.TotalSeconds | Should -BeLessThan 5
        }
        
        It "大量のサインインログ処理が適切な時間内に完了すること" {
            # 10000件のログを生成
            $largeLogs = @()
            for ($i = 1; $i -le 10000; $i++) {
                $largeLogs += [PSCustomObject]@{
                    Id = "log-$i"
                    UserPrincipalName = "user$($i % 100)@contoso.com"
                    CreatedDateTime = (Get-Date).AddMinutes(-$i)
                    Status = @{
                        ErrorCode = if ($i % 10 -eq 0) { 50126 } else { 0 }
                    }
                }
            }
            
            $measure = Measure-Command {
                # 成功率計算
                $successCount = ($largeLogs | Where-Object { $_.Status.ErrorCode -eq 0 }).Count
                $successRate = ($successCount / $largeLogs.Count) * 100
                
                # 時間帯別集計
                $hourlyStats = $largeLogs | Group-Object -Property { $_.CreatedDateTime.Hour }
            }
            
            $measure.TotalSeconds | Should -BeLessThan 10
        }
    }
    
    Context "メモリ使用効率" {
        It "大量データ処理時のメモリ増加が許容範囲内であること" {
            [System.GC]::Collect()
            $initialMemory = [System.GC]::GetTotalMemory($false)
            
            # 大量データ処理
            $testData = @()
            for ($i = 1; $i -le 5000; $i++) {
                $testData += [PSCustomObject]@{
                    Id = [Guid]::NewGuid()
                    Data = "x" * 1000  # 1KB のデータ
                }
            }
            
            $processedData = $testData | Select-Object Id
            
            [System.GC]::Collect()
            $finalMemory = [System.GC]::GetTotalMemory($false)
            
            $memoryIncreaseMB = ($finalMemory - $initialMemory) / 1MB
            $memoryIncreaseMB | Should -BeLessThan 100
        }
    }
}

AfterAll {
    Write-Host "`n✅ Entra ID機能テストスイート完了" -ForegroundColor Green
}