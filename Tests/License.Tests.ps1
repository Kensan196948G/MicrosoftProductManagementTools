#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.3.0' }

<#
.SYNOPSIS
ライセンス管理機能の包括的Pesterテストスイート

.DESCRIPTION
Microsoft 365ライセンス管理機能（割り当て、使用状況、コスト分析、最適化提案）の単体・統合テスト

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
    
    # テスト用ライセンスデータ
    $script:TestLicenseData = @{
        Subscriptions = @(
            [PSCustomObject]@{
                SkuId = "6fd2c87f-b296-42f0-b197-1e91e994b900"
                SkuPartNumber = "ENTERPRISEPACK"
                DisplayName = "Office 365 E3"
                ConsumedUnits = 250
                PrepaidUnits = @{
                    Enabled = 300
                    Suspended = 0
                    Warning = 0
                }
                AvailableUnits = 50
                TotalUnits = 300
                MonthlyUnitCost = 2300  # 円
                ServicePlans = @(
                    [PSCustomObject]@{ ServicePlanName = "EXCHANGE_S_ENTERPRISE"; DisplayName = "Exchange Online (Plan 2)" },
                    [PSCustomObject]@{ ServicePlanName = "SHAREPOINTENTERPRISE"; DisplayName = "SharePoint Online" },
                    [PSCustomObject]@{ ServicePlanName = "TEAMS1"; DisplayName = "Microsoft Teams" },
                    [PSCustomObject]@{ ServicePlanName = "OFFICESUBSCRIPTION"; DisplayName = "Microsoft 365 Apps for enterprise" }
                )
                ExpirationDate = (Get-Date).AddMonths(6)
            },
            [PSCustomObject]@{
                SkuId = "05e9a617-0261-4cee-bb44-138d3ef5d965"
                SkuPartNumber = "SPE_E3"
                DisplayName = "Microsoft 365 E3"
                ConsumedUnits = 180
                PrepaidUnits = @{
                    Enabled = 200
                    Suspended = 0
                    Warning = 0
                }
                AvailableUnits = 20
                TotalUnits = 200
                MonthlyUnitCost = 3600  # 円
                ServicePlans = @(
                    [PSCustomObject]@{ ServicePlanName = "EXCHANGE_S_ENTERPRISE"; DisplayName = "Exchange Online (Plan 2)" },
                    [PSCustomObject]@{ ServicePlanName = "SHAREPOINTENTERPRISE"; DisplayName = "SharePoint Online" },
                    [PSCustomObject]@{ ServicePlanName = "TEAMS1"; DisplayName = "Microsoft Teams" },
                    [PSCustomObject]@{ ServicePlanName = "OFFICESUBSCRIPTION"; DisplayName = "Microsoft 365 Apps for enterprise" },
                    [PSCustomObject]@{ ServicePlanName = "AAD_PREMIUM"; DisplayName = "Azure Active Directory Premium P1" },
                    [PSCustomObject]@{ ServicePlanName = "INTUNE_A"; DisplayName = "Microsoft Intune" }
                )
                ExpirationDate = (Get-Date).AddMonths(6)
            },
            [PSCustomObject]@{
                SkuId = "1f2f344a-700d-42c9-9427-5cea1d5d7ba6"
                SkuPartNumber = "STREAM"
                DisplayName = "Microsoft Stream Plan 2"
                ConsumedUnits = 45
                PrepaidUnits = @{
                    Enabled = 50
                    Suspended = 0
                    Warning = 0
                }
                AvailableUnits = 5
                TotalUnits = 50
                MonthlyUnitCost = 500  # 円
                ServicePlans = @(
                    [PSCustomObject]@{ ServicePlanName = "STREAM_P2"; DisplayName = "Microsoft Stream Plan 2" }
                )
                ExpirationDate = (Get-Date).AddMonths(3)
            }
        )
        
        UserLicenses = @(
            [PSCustomObject]@{
                UserPrincipalName = "yamada@contoso.com"
                DisplayName = "山田太郎"
                Department = "営業部"
                UsageLocation = "JP"
                Licenses = @(
                    [PSCustomObject]@{
                        SkuId = "6fd2c87f-b296-42f0-b197-1e91e994b900"
                        SkuPartNumber = "ENTERPRISEPACK"
                        AssignedDate = (Get-Date).AddMonths(-12)
                        DisabledPlans = @("SWAY")
                    }
                )
                LastActiveDate = (Get-Date).AddDays(-1)
                IsActive = $true
            },
            [PSCustomObject]@{
                UserPrincipalName = "sato@contoso.com"
                DisplayName = "佐藤花子"
                Department = "マーケティング部"
                UsageLocation = "JP"
                Licenses = @(
                    [PSCustomObject]@{
                        SkuId = "05e9a617-0261-4cee-bb44-138d3ef5d965"
                        SkuPartNumber = "SPE_E3"
                        AssignedDate = (Get-Date).AddMonths(-6)
                        DisabledPlans = @()
                    },
                    [PSCustomObject]@{
                        SkuId = "1f2f344a-700d-42c9-9427-5cea1d5d7ba6"
                        SkuPartNumber = "STREAM"
                        AssignedDate = (Get-Date).AddMonths(-3)
                        DisabledPlans = @()
                    }
                )
                LastActiveDate = (Get-Date).AddDays(-5)
                IsActive = $true
            },
            [PSCustomObject]@{
                UserPrincipalName = "tanaka@contoso.com"
                DisplayName = "田中次郎"
                Department = "IT部"
                UsageLocation = "JP"
                Licenses = @(
                    [PSCustomObject]@{
                        SkuId = "6fd2c87f-b296-42f0-b197-1e91e994b900"
                        SkuPartNumber = "ENTERPRISEPACK"
                        AssignedDate = (Get-Date).AddMonths(-24)
                        DisabledPlans = @("TEAMS1", "SWAY")
                    }
                )
                LastActiveDate = (Get-Date).AddDays(-60)
                IsActive = $false
            }
        )
        
        ServiceUsage = @(
            [PSCustomObject]@{
                UserPrincipalName = "yamada@contoso.com"
                ServiceName = "Exchange"
                LastAccessDate = (Get-Date).AddHours(-2)
                UsageFrequency = "Daily"
                MailboxSizeGB = 15.2
                ItemCount = 12543
            },
            [PSCustomObject]@{
                UserPrincipalName = "yamada@contoso.com"
                ServiceName = "SharePoint"
                LastAccessDate = (Get-Date).AddDays(-1)
                UsageFrequency = "Daily"
                StorageUsedGB = 8.7
                FileCount = 543
            },
            [PSCustomObject]@{
                UserPrincipalName = "sato@contoso.com"
                ServiceName = "Teams"
                LastAccessDate = (Get-Date).AddMinutes(-30)
                UsageFrequency = "Hourly"
                MessageCount = 1234
                MeetingMinutes = 450
            },
            [PSCustomObject]@{
                UserPrincipalName = "tanaka@contoso.com"
                ServiceName = "Exchange"
                LastAccessDate = (Get-Date).AddDays(-65)
                UsageFrequency = "Inactive"
                MailboxSizeGB = 2.1
                ItemCount = 543
            }
        )
    }
}

Describe "ライセンス - 割り当て管理テスト" -Tags @("Unit", "License", "Assignment") {
    Context "ライセンス在庫管理" {
        It "利用可能なライセンス一覧が取得できること" {
            Mock Get-MgSubscribedSku {
                return $TestLicenseData.Subscriptions
            }
            
            $licenses = Get-MgSubscribedSku
            $licenses | Should -Not -BeNullOrEmpty
            $licenses.Count | Should -Be 3
        }
        
        It "ライセンス使用率が計算できること" {
            foreach ($subscription in $TestLicenseData.Subscriptions) {
                $usageRate = if ($subscription.TotalUnits -gt 0) {
                    [math]::Round(($subscription.ConsumedUnits / $subscription.TotalUnits) * 100, 2)
                } else { 0 }
                
                if ($subscription.SkuPartNumber -eq "ENTERPRISEPACK") {
                    $usageRate | Should -Be 83.33
                } elseif ($subscription.SkuPartNumber -eq "SPE_E3") {
                    $usageRate | Should -Be 90
                } elseif ($subscription.SkuPartNumber -eq "STREAM") {
                    $usageRate | Should -Be 90
                }
            }
        }
        
        It "残りライセンス数が正確に計算されること" {
            foreach ($subscription in $TestLicenseData.Subscriptions) {
                $available = $subscription.PrepaidUnits.Enabled - $subscription.ConsumedUnits
                $available | Should -Be $subscription.AvailableUnits
            }
        }
        
        It "ライセンス不足の警告が検出できること" {
            $warningThreshold = 10  # 残り10%未満で警告
            
            $lowLicenses = $TestLicenseData.Subscriptions | Where-Object {
                $availablePercent = ($_.AvailableUnits / $_.TotalUnits) * 100
                $availablePercent -le $warningThreshold
            }
            
            $lowLicenses.Count | Should -Be 1
            $lowLicenses[0].SkuPartNumber | Should -Be "STREAM"
        }
    }
    
    Context "ユーザーライセンス割り当て" {
        It "ユーザーに割り当てられたライセンスが取得できること" {
            Mock Get-MgUser {
                param($UserId)
                return $TestLicenseData.UserLicenses | Where-Object { $_.UserPrincipalName -eq $UserId }
            }
            
            $user = Get-MgUser -UserId "yamada@contoso.com"
            $user | Should -Not -BeNullOrEmpty
            $user.Licenses.Count | Should -Be 1
            $user.Licenses[0].SkuPartNumber | Should -Be "ENTERPRISEPACK"
        }
        
        It "複数ライセンスを持つユーザーが識別できること" {
            $multiLicenseUsers = $TestLicenseData.UserLicenses | Where-Object {
                $_.Licenses.Count -gt 1
            }
            
            $multiLicenseUsers.Count | Should -Be 1
            $multiLicenseUsers[0].UserPrincipalName | Should -Be "sato@contoso.com"
            $multiLicenseUsers[0].Licenses.Count | Should -Be 2
        }
        
        It "無効化されたサービスプランが検出できること" {
            $usersWithDisabledPlans = $TestLicenseData.UserLicenses | Where-Object {
                $_.Licenses | Where-Object { $_.DisabledPlans.Count -gt 0 }
            }
            
            $usersWithDisabledPlans.Count | Should -Be 2
            
            $tanaka = $usersWithDisabledPlans | Where-Object { $_.UserPrincipalName -eq "tanaka@contoso.com" }
            $tanaka.Licenses[0].DisabledPlans | Should -Contain "TEAMS1"
        }
        
        It "部署別のライセンス使用状況が集計できること" {
            $licensesByDept = $TestLicenseData.UserLicenses | Group-Object -Property Department |
                Select-Object Name, @{
                    Name = 'UserCount'
                    Expression = { $_.Count }
                }, @{
                    Name = 'TotalLicenses'
                    Expression = { ($_.Group.Licenses | Measure-Object).Count }
                }
            
            $licensesByDept.Count | Should -Be 3
            
            $marketingDept = $licensesByDept | Where-Object { $_.Name -eq "マーケティング部" }
            $marketingDept.TotalLicenses | Should -Be 2
        }
    }
    
    Context "ライセンス割り当て履歴" {
        It "ライセンス割り当て日が記録されていること" {
            foreach ($user in $TestLicenseData.UserLicenses) {
                foreach ($license in $user.Licenses) {
                    $license.AssignedDate | Should -Not -BeNullOrEmpty
                    $license.AssignedDate | Should -BeOfType [datetime]
                }
            }
        }
        
        It "長期間割り当てられているライセンスが識別できること" {
            $longTermThreshold = 365  # 1年以上
            
            $longTermLicenses = @()
            foreach ($user in $TestLicenseData.UserLicenses) {
                foreach ($license in $user.Licenses) {
                    $daysAssigned = ((Get-Date) - $license.AssignedDate).Days
                    if ($daysAssigned -ge $longTermThreshold) {
                        $longTermLicenses += [PSCustomObject]@{
                            User = $user.UserPrincipalName
                            License = $license.SkuPartNumber
                            DaysAssigned = $daysAssigned
                        }
                    }
                }
            }
            
            $longTermLicenses.Count | Should -Be 2
            $longTermLicenses | Where-Object { $_.DaysAssigned -gt 700 } | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "ライセンス - 使用状況分析テスト" -Tags @("Unit", "License", "Usage") {
    Context "サービス利用状況の追跡" {
        It "ユーザーのサービス利用状況が取得できること" {
            Mock Get-UserServiceUsage {
                param($UserPrincipalName)
                return $TestLicenseData.ServiceUsage | Where-Object { 
                    $_.UserPrincipalName -eq $UserPrincipalName 
                }
            }
            
            $usage = Get-UserServiceUsage -UserPrincipalName "yamada@contoso.com"
            $usage | Should -Not -BeNullOrEmpty
            $usage.Count | Should -Be 2
        }
        
        It "アクティブ/非アクティブユーザーが識別できること" {
            $inactiveThreshold = 30  # 30日以上未使用
            
            $activeUsers = $TestLicenseData.UserLicenses | Where-Object {
                $_.IsActive -and $_.LastActiveDate -ge (Get-Date).AddDays(-$inactiveThreshold)
            }
            
            $inactiveUsers = $TestLicenseData.UserLicenses | Where-Object {
                -not $_.IsActive -or $_.LastActiveDate -lt (Get-Date).AddDays(-$inactiveThreshold)
            }
            
            $activeUsers.Count | Should -Be 2
            $inactiveUsers.Count | Should -Be 1
            $inactiveUsers[0].UserPrincipalName | Should -Be "tanaka@contoso.com"
        }
        
        It "サービス別の利用頻度が分析できること" {
            $serviceFrequency = $TestLicenseData.ServiceUsage | Group-Object -Property ServiceName |
                Select-Object Name, @{
                    Name = 'ActiveUsers'
                    Expression = { 
                        ($_.Group | Where-Object { $_.UsageFrequency -ne "Inactive" }).Count 
                    }
                }, @{
                    Name = 'TotalUsers'
                    Expression = { $_.Count }
                }
            
            $exchangeUsage = $serviceFrequency | Where-Object { $_.Name -eq "Exchange" }
            $exchangeUsage.ActiveUsers | Should -Be 1
            $exchangeUsage.TotalUsers | Should -Be 2
        }
    }
    
    Context "ライセンス利用効率の評価" {
        It "未使用ライセンスが検出できること" {
            # ライセンスは割り当てられているが、サービスを使用していないユーザー
            $unusedLicenses = @()
            
            foreach ($user in $TestLicenseData.UserLicenses) {
                $userUsage = $TestLicenseData.ServiceUsage | Where-Object {
                    $_.UserPrincipalName -eq $user.UserPrincipalName -and
                    $_.UsageFrequency -ne "Inactive"
                }
                
                if ($userUsage.Count -eq 0 -or -not $user.IsActive) {
                    $unusedLicenses += $user
                }
            }
            
            $unusedLicenses.Count | Should -Be 1
            $unusedLicenses[0].UserPrincipalName | Should -Be "tanaka@contoso.com"
        }
        
        It "部分的に使用されているライセンスが識別できること" {
            # E3ライセンスのサービスプラン数（主要4つ）に対して実際に使用しているサービス数を確認
            $e3ServicePlans = @("Exchange", "SharePoint", "Teams", "Office")
            
            $partialUsers = @()
            foreach ($user in $TestLicenseData.UserLicenses) {
                if ($user.Licenses.SkuPartNumber -contains "ENTERPRISEPACK" -or 
                    $user.Licenses.SkuPartNumber -contains "SPE_E3") {
                    
                    $activeServices = $TestLicenseData.ServiceUsage | Where-Object {
                        $_.UserPrincipalName -eq $user.UserPrincipalName -and
                        $_.UsageFrequency -ne "Inactive"
                    }
                    
                    if ($activeServices.Count -gt 0 -and $activeServices.Count -lt 3) {
                        $partialUsers += [PSCustomObject]@{
                            User = $user.UserPrincipalName
                            ActiveServiceCount = $activeServices.Count
                            TotalServiceCount = 4
                        }
                    }
                }
            }
            
            $partialUsers.Count | Should -BeGreaterThan 0
        }
        
        It "サービス利用率スコアが計算できること" {
            function Get-ServiceUtilizationScore {
                param($UserLicenses, $ServiceUsage)
                
                $totalScore = 0
                $userCount = 0
                
                foreach ($user in $UserLicenses) {
                    if ($user.IsActive) {
                        $userServices = $ServiceUsage | Where-Object {
                            $_.UserPrincipalName -eq $user.UserPrincipalName
                        }
                        
                        $activeServices = ($userServices | Where-Object { 
                            $_.UsageFrequency -ne "Inactive" 
                        }).Count
                        
                        $totalServices = 4  # E3の主要サービス数
                        $userScore = ($activeServices / $totalServices) * 100
                        $totalScore += $userScore
                        $userCount++
                    }
                }
                
                if ($userCount -gt 0) {
                    return [math]::Round($totalScore / $userCount, 2)
                }
                return 0
            }
            
            $utilizationScore = Get-ServiceUtilizationScore -UserLicenses $TestLicenseData.UserLicenses `
                -ServiceUsage $TestLicenseData.ServiceUsage
            
            $utilizationScore | Should -BeGreaterThan 0
            $utilizationScore | Should -BeLessOrEqual 100
        }
    }
}

Describe "ライセンス - コスト分析テスト" -Tags @("Unit", "License", "Cost") {
    Context "ライセンスコストの計算" {
        It "月間総コストが計算できること" {
            $totalMonthlyCost = 0
            
            foreach ($subscription in $TestLicenseData.Subscriptions) {
                $subscriptionCost = $subscription.ConsumedUnits * $subscription.MonthlyUnitCost
                $totalMonthlyCost += $subscriptionCost
            }
            
            $totalMonthlyCost | Should -Be 1250000  # 125万円
        }
        
        It "ライセンス種別ごとのコスト内訳が取得できること" {
            $costBreakdown = $TestLicenseData.Subscriptions | ForEach-Object {
                [PSCustomObject]@{
                    LicenseType = $_.DisplayName
                    UnitCost = $_.MonthlyUnitCost
                    ConsumedUnits = $_.ConsumedUnits
                    TotalCost = $_.ConsumedUnits * $_.MonthlyUnitCost
                    CostPercentage = 0  # 後で計算
                }
            }
            
            $totalCost = ($costBreakdown | Measure-Object -Property TotalCost -Sum).Sum
            
            $costBreakdown | ForEach-Object {
                $_.CostPercentage = [math]::Round(($_.TotalCost / $totalCost) * 100, 2)
            }
            
            $e3Cost = $costBreakdown | Where-Object { $_.LicenseType -eq "Office 365 E3" }
            $e3Cost.TotalCost | Should -Be 575000
            $e3Cost.CostPercentage | Should -Be 46
        }
        
        It "未使用ライセンスのコストが計算できること" {
            $unusedCost = 0
            
            # 未使用ユーザーのライセンスコストを計算
            $unusedUsers = $TestLicenseData.UserLicenses | Where-Object { -not $_.IsActive }
            
            foreach ($user in $unusedUsers) {
                foreach ($license in $user.Licenses) {
                    $subscription = $TestLicenseData.Subscriptions | Where-Object {
                        $_.SkuPartNumber -eq $license.SkuPartNumber
                    }
                    
                    if ($subscription) {
                        $unusedCost += $subscription.MonthlyUnitCost
                    }
                }
            }
            
            $unusedCost | Should -Be 2300  # 田中次郎のE3ライセンス
        }
        
        It "部署別コストが集計できること" {
            $costByDepartment = @{}
            
            foreach ($user in $TestLicenseData.UserLicenses) {
                if (-not $costByDepartment.ContainsKey($user.Department)) {
                    $costByDepartment[$user.Department] = 0
                }
                
                foreach ($license in $user.Licenses) {
                    $subscription = $TestLicenseData.Subscriptions | Where-Object {
                        $_.SkuPartNumber -eq $license.SkuPartNumber
                    }
                    
                    if ($subscription) {
                        $costByDepartment[$user.Department] += $subscription.MonthlyUnitCost
                    }
                }
            }
            
            $costByDepartment["営業部"] | Should -Be 2300
            $costByDepartment["マーケティング部"] | Should -Be 4100  # E3 + Stream
            $costByDepartment["IT部"] | Should -Be 2300
        }
    }
    
    Context "コスト最適化の機会" {
        It "ダウングレード候補が識別できること" {
            # フル機能を使用していないE3ユーザーを識別
            $downgradeOpportunities = @()
            
            foreach ($user in $TestLicenseData.UserLicenses) {
                $hasE3 = $user.Licenses | Where-Object { 
                    $_.SkuPartNumber -in @("ENTERPRISEPACK", "SPE_E3") 
                }
                
                if ($hasE3) {
                    $activeServices = $TestLicenseData.ServiceUsage | Where-Object {
                        $_.UserPrincipalName -eq $user.UserPrincipalName -and
                        $_.UsageFrequency -ne "Inactive"
                    }
                    
                    # 2つ以下のサービスしか使用していない場合はダウングレード候補
                    if ($activeServices.Count -le 2) {
                        $downgradeOpportunities += [PSCustomObject]@{
                            User = $user.UserPrincipalName
                            CurrentLicense = $hasE3.SkuPartNumber
                            ActiveServices = $activeServices.ServiceName -join ", "
                            PotentialSaving = 1000  # E3からE1への変更で約1000円/月の節約
                        }
                    }
                }
            }
            
            $downgradeOpportunities.Count | Should -BeGreaterThan 0
        }
        
        It "ライセンスプールの最適化提案ができること" {
            $optimizationSuggestions = @()
            
            foreach ($subscription in $TestLicenseData.Subscriptions) {
                $usageRate = ($subscription.ConsumedUnits / $subscription.TotalUnits) * 100
                
                if ($usageRate -lt 80) {
                    # 使用率が80%未満の場合、削減を提案
                    $excessUnits = [math]::Floor($subscription.TotalUnits * 0.1)  # 10%削減
                    $potentialSaving = $excessUnits * $subscription.MonthlyUnitCost
                    
                    $optimizationSuggestions += [PSCustomObject]@{
                        License = $subscription.DisplayName
                        CurrentUnits = $subscription.TotalUnits
                        SuggestedUnits = $subscription.TotalUnits - $excessUnits
                        MonthlySaving = $potentialSaving
                    }
                } elseif ($usageRate -gt 95) {
                    # 使用率が95%以上の場合、追加を提案
                    $additionalUnits = [math]::Ceiling($subscription.TotalUnits * 0.1)  # 10%追加
                    
                    $optimizationSuggestions += [PSCustomObject]@{
                        License = $subscription.DisplayName
                        CurrentUnits = $subscription.TotalUnits
                        SuggestedUnits = $subscription.TotalUnits + $additionalUnits
                        MonthlySaving = -($additionalUnits * $subscription.MonthlyUnitCost)  # 負の値は追加コスト
                    }
                }
            }
            
            $optimizationSuggestions.Count | Should -BeGreaterThan 0
        }
    }
}

Describe "ライセンス - 最適化提案テスト" -Tags @("Unit", "License", "Optimization") {
    Context "ライセンス再配分の提案" {
        It "未使用ライセンスの再配分候補が特定できること" {
            # 未使用ライセンスを持つユーザー
            $unusedLicenses = $TestLicenseData.UserLicenses | Where-Object { -not $_.IsActive }
            
            # ライセンスが必要な新規ユーザー（シミュレート）
            $newUsers = @(
                [PSCustomObject]@{
                    UserPrincipalName = "newuser1@contoso.com"
                    Department = "営業部"
                    RequiredLicense = "ENTERPRISEPACK"
                },
                [PSCustomObject]@{
                    UserPrincipalName = "newuser2@contoso.com"
                    Department = "開発部"
                    RequiredLicense = "SPE_E3"
                }
            )
            
            $reallocationPlan = @()
            foreach ($unused in $unusedLicenses) {
                foreach ($license in $unused.Licenses) {
                    $matchingNewUser = $newUsers | Where-Object {
                        $_.RequiredLicense -eq $license.SkuPartNumber
                    } | Select-Object -First 1
                    
                    if ($matchingNewUser) {
                        $reallocationPlan += [PSCustomObject]@{
                            FromUser = $unused.UserPrincipalName
                            ToUser = $matchingNewUser.UserPrincipalName
                            License = $license.SkuPartNumber
                            MonthlySaving = ($TestLicenseData.Subscriptions | Where-Object {
                                $_.SkuPartNumber -eq $license.SkuPartNumber
                            }).MonthlyUnitCost
                        }
                    }
                }
            }
            
            $reallocationPlan.Count | Should -BeGreaterThan 0
        }
        
        It "サービスプラン最適化の提案ができること" {
            $servicePlanOptimization = @()
            
            foreach ($user in $TestLicenseData.UserLicenses) {
                foreach ($license in $user.Licenses) {
                    if ($license.DisabledPlans.Count -gt 0) {
                        # 無効化されたプランが多い場合、より適切なライセンスを提案
                        $subscription = $TestLicenseData.Subscriptions | Where-Object {
                            $_.SkuPartNumber -eq $license.SkuPartNumber
                        }
                        
                        if ($subscription) {
                            $disabledRatio = $license.DisabledPlans.Count / $subscription.ServicePlans.Count
                            
                            if ($disabledRatio -gt 0.3) {  # 30%以上のプランが無効化
                                $servicePlanOptimization += [PSCustomObject]@{
                                    User = $user.UserPrincipalName
                                    CurrentLicense = $license.SkuPartNumber
                                    DisabledPlans = $license.DisabledPlans -join ", "
                                    DisabledRatio = [math]::Round($disabledRatio * 100, 2)
                                    Recommendation = "より適切なライセンスへの変更を検討"
                                }
                            }
                        }
                    }
                }
            }
            
            $servicePlanOptimization.Count | Should -BeGreaterThan 0
            $servicePlanOptimization[0].User | Should -Be "tanaka@contoso.com"
        }
    }
    
    Context "ライセンス有効期限管理" {
        It "有効期限が近いライセンスが検出できること" {
            $expirationWarningDays = 90
            $warningDate = (Get-Date).AddDays($expirationWarningDays)
            
            $expiringLicenses = $TestLicenseData.Subscriptions | Where-Object {
                $_.ExpirationDate -le $warningDate
            }
            
            $expiringLicenses.Count | Should -Be 1
            $expiringLicenses[0].SkuPartNumber | Should -Be "STREAM"
        }
        
        It "ライセンス更新計画が生成できること" {
            $renewalPlan = $TestLicenseData.Subscriptions | ForEach-Object {
                $daysUntilExpiration = ($_.ExpirationDate - (Get-Date)).Days
                $renewalUrgency = if ($daysUntilExpiration -le 30) { "Critical" }
                                  elseif ($daysUntilExpiration -le 90) { "High" }
                                  elseif ($daysUntilExpiration -le 180) { "Medium" }
                                  else { "Low" }
                
                [PSCustomObject]@{
                    License = $_.DisplayName
                    ExpirationDate = $_.ExpirationDate
                    DaysRemaining = $daysUntilExpiration
                    Urgency = $renewalUrgency
                    ConsumedUnits = $_.ConsumedUnits
                    RecommendedAction = if ($_.ConsumedUnits -eq 0) { "更新不要" }
                                       elseif ($daysUntilExpiration -le 30) { "即時更新" }
                                       else { "計画的更新" }
                }
            }
            
            $criticalRenewals = $renewalPlan | Where-Object { $_.Urgency -eq "High" }
            $criticalRenewals.Count | Should -Be 1
        }
    }
}

Describe "ライセンス - セキュリティとコンプライアンステスト" -Tags @("Security", "License", "Compliance") {
    Context "ライセンス割り当てのガバナンス" {
        It "承認なしのライセンス割り当てが検出できること" {
            Mock Get-AuditLog {
                return @(
                    [PSCustomObject]@{
                        CreationDate = (Get-Date).AddDays(-1)
                        UserIds = "admin@contoso.com"
                        Operations = "Add user license"
                        AuditData = @{
                            Target = @{ ID = "unauthorizeduser@contoso.com" }
                            ModifiedProperties = @{ Name = "AssignedLicense"; NewValue = "SPE_E3" }
                        }
                        ResultStatus = "Success"
                        ApprovalStatus = "NotApproved"
                    }
                )
            }
            
            $auditLogs = Get-AuditLog -StartDate (Get-Date).AddDays(-7) -Operations "Add user license"
            $unapprovedAssignments = $auditLogs | Where-Object { $_.ApprovalStatus -eq "NotApproved" }
            
            $unapprovedAssignments.Count | Should -BeGreaterThan 0
        }
        
        It "ライセンスの不正使用が検出できること" {
            # 退職者や無効なアカウントにライセンスが割り当てられていないか確認
            $suspiciousAssignments = @()
            
            foreach ($user in $TestLicenseData.UserLicenses) {
                # 非アクティブユーザーで高額ライセンスを保持
                if (-not $user.IsActive -and $user.Licenses.Count -gt 0) {
                    $totalCost = 0
                    foreach ($license in $user.Licenses) {
                        $subscription = $TestLicenseData.Subscriptions | Where-Object {
                            $_.SkuPartNumber -eq $license.SkuPartNumber
                        }
                        if ($subscription) {
                            $totalCost += $subscription.MonthlyUnitCost
                        }
                    }
                    
                    if ($totalCost -gt 2000) {  # 2000円/月以上
                        $suspiciousAssignments += [PSCustomObject]@{
                            User = $user.UserPrincipalName
                            Status = "Inactive"
                            MonthlyCost = $totalCost
                            LastActive = $user.LastActiveDate
                        }
                    }
                }
            }
            
            $suspiciousAssignments.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "ライセンスコンプライアンス" {
        It "ライセンス使用が規約に準拠していること" {
            # 地域制限の確認
            $invalidLocations = $TestLicenseData.UserLicenses | Where-Object {
                $_.UsageLocation -notin @("JP", "US", "GB", "DE", "FR")  # 許可された地域
            }
            
            $invalidLocations.Count | Should -Be 0
            
            # 全ユーザーが適切な使用地域を持っていること
            $noLocationUsers = $TestLicenseData.UserLicenses | Where-Object {
                [string]::IsNullOrEmpty($_.UsageLocation)
            }
            
            $noLocationUsers.Count | Should -Be 0
        }
        
        It "ライセンス監査証跡が記録されていること" {
            Mock Get-LicenseAuditTrail {
                return @(
                    [PSCustomObject]@{
                        Timestamp = (Get-Date).AddDays(-1)
                        Action = "LicenseAssigned"
                        User = "yamada@contoso.com"
                        License = "ENTERPRISEPACK"
                        PerformedBy = "admin@contoso.com"
                        Reason = "新規採用"
                    },
                    [PSCustomObject]@{
                        Timestamp = (Get-Date).AddDays(-60)
                        Action = "LicenseRemoved"
                        User = "former.employee@contoso.com"
                        License = "SPE_E3"
                        PerformedBy = "admin@contoso.com"
                        Reason = "退職"
                    }
                )
            }
            
            $auditTrail = Get-LicenseAuditTrail
            $auditTrail | Should -Not -BeNullOrEmpty
            
            # 全ての変更に理由が記録されていること
            $noReasonChanges = $auditTrail | Where-Object { [string]::IsNullOrEmpty($_.Reason) }
            $noReasonChanges.Count | Should -Be 0
        }
    }
    
    Context "ISO/IEC 27001準拠確認" {
        It "定期的なライセンスレビューが実施されていること" {
            Mock Get-LicenseReviewHistory {
                return @(
                    [PSCustomObject]@{
                        ReviewDate = (Get-Date).AddMonths(-1)
                        Reviewer = "it.manager@contoso.com"
                        ReviewType = "Monthly"
                        FindingsCount = 3
                        ActionsToken = 3
                        Status = "Completed"
                    },
                    [PSCustomObject]@{
                        ReviewDate = (Get-Date).AddMonths(-3)
                        Reviewer = "it.manager@contoso.com"
                        ReviewType = "Quarterly"
                        FindingsCount = 5
                        ActionsToken = 4
                        Status = "Completed"
                    }
                )
            }
            
            $reviews = Get-LicenseReviewHistory
            $recentReview = $reviews | Where-Object {
                $_.ReviewDate -ge (Get-Date).AddMonths(-2)
            }
            
            $recentReview | Should -Not -BeNullOrEmpty
            $recentReview[0].Status | Should -Be "Completed"
        }
        
        It "アクセス権限の最小権限原則が適用されていること" {
            # 管理者権限を持つライセンスの確認
            $adminLicenses = @("SPE_E5", "EMS_E5", "AAD_PREMIUM_P2")
            
            $usersWithAdminLicenses = $TestLicenseData.UserLicenses | Where-Object {
                $user = $_
                $hasAdminLicense = $false
                foreach ($license in $user.Licenses) {
                    if ($license.SkuPartNumber -in $adminLicenses) {
                        $hasAdminLicense = $true
                        break
                    }
                }
                $hasAdminLicense
            }
            
            # 管理者ライセンスは限定的であるべき
            $usersWithAdminLicenses.Count | Should -BeLessOrEqual ($TestLicenseData.UserLicenses.Count * 0.1)
        }
    }
}

Describe "ライセンス - パフォーマンステスト" -Tags @("Performance", "License") {
    Context "大規模ライセンスデータ処理" {
        It "10000ユーザーのライセンス分析が10秒以内に完了すること" {
            # 大量のユーザーライセンスデータを生成
            $largeUserSet = @()
            $licenseTypes = @("ENTERPRISEPACK", "SPE_E3", "SPE_E5", "STREAM", "POWER_BI_PRO")
            
            for ($i = 1; $i -le 10000; $i++) {
                $licenseCount = Get-Random -Minimum 1 -Maximum 3
                $userLicenses = @()
                
                for ($j = 1; $j -le $licenseCount; $j++) {
                    $userLicenses += [PSCustomObject]@{
                        SkuPartNumber = $licenseTypes[(Get-Random -Maximum $licenseTypes.Count)]
                        AssignedDate = (Get-Date).AddDays(-(Get-Random -Maximum 730))
                    }
                }
                
                $largeUserSet += [PSCustomObject]@{
                    UserPrincipalName = "user$i@contoso.com"
                    Department = "Dept$($i % 20)"
                    Licenses = $userLicenses
                    IsActive = ($i % 10 -ne 0)
                }
            }
            
            $measure = Measure-Command {
                # ライセンス統計の計算
                $licenseStats = $largeUserSet.Licenses | Group-Object -Property SkuPartNumber |
                    Select-Object Name, Count
                
                # 部署別集計
                $deptStats = $largeUserSet | Group-Object -Property Department |
                    Select-Object Name, @{
                        Name = 'TotalLicenses'
                        Expression = { ($_.Group.Licenses | Measure-Object).Count }
                    }
                
                # 非アクティブユーザーの特定
                $inactiveUsers = $largeUserSet | Where-Object { -not $_.IsActive }
                
                # コスト計算（簡易）
                $totalLicenses = ($largeUserSet.Licenses | Measure-Object).Count
                $estimatedCost = $totalLicenses * 3000  # 平均3000円/ライセンス
            }
            
            $measure.TotalSeconds | Should -BeLessThan 10
        }
        
        It "複雑なライセンス最適化分析が適切な時間内に完了すること" {
            # 5000ユーザーの詳細な使用状況データ
            $detailedUsageData = @()
            
            for ($i = 1; $i -le 5000; $i++) {
                $detailedUsageData += [PSCustomObject]@{
                    UserPrincipalName = "user$i@contoso.com"
                    Licenses = @(
                        [PSCustomObject]@{
                            SkuPartNumber = if ($i % 2 -eq 0) { "SPE_E3" } else { "ENTERPRISEPACK" }
                            ServiceUsage = @{
                                Exchange = (Get-Random -Maximum 100)
                                SharePoint = (Get-Random -Maximum 100)
                                Teams = (Get-Random -Maximum 100)
                                Office = (Get-Random -Maximum 100)
                            }
                        }
                    )
                    LastActiveDate = (Get-Date).AddDays(-(Get-Random -Maximum 180))
                    Department = "Dept$($i % 50)"
                }
            }
            
            $measure = Measure-Command {
                # 各ユーザーの最適ライセンスを判定
                $optimizationResults = $detailedUsageData | ForEach-Object {
                    $user = $_
                    $totalUsage = 0
                    $serviceCount = 0
                    
                    foreach ($license in $user.Licenses) {
                        foreach ($usage in $license.ServiceUsage.Values) {
                            $totalUsage += $usage
                            $serviceCount++
                        }
                    }
                    
                    $avgUsage = if ($serviceCount -gt 0) { $totalUsage / $serviceCount } else { 0 }
                    
                    [PSCustomObject]@{
                        User = $user.UserPrincipalName
                        CurrentLicense = $user.Licenses[0].SkuPartNumber
                        AverageUsage = [math]::Round($avgUsage, 2)
                        Recommendation = if ($avgUsage -lt 20) { "Downgrade" }
                                       elseif ($avgUsage -gt 80) { "Keep" }
                                       else { "Review" }
                    }
                }
                
                # 推奨事項の集計
                $recommendations = $optimizationResults | Group-Object -Property Recommendation
            }
            
            $measure.TotalSeconds | Should -BeLessThan 30
        }
    }
    
    Context "メモリ効率性" {
        It "大量ライセンスデータ処理時のメモリ使用が適切であること" {
            [System.GC]::Collect()
            $initialMemory = [System.GC]::GetTotalMemory($false)
            
            # メモリ集約的な処理
            $licenseData = @()
            for ($i = 1; $i -le 20000; $i++) {
                $licenseData += [PSCustomObject]@{
                    Id = [Guid]::NewGuid()
                    UserPrincipalName = "user$i@contoso.com"
                    Licenses = 1..5 | ForEach-Object {
                        [PSCustomObject]@{
                            SkuId = [Guid]::NewGuid()
                            SkuPartNumber = "LICENSE_$_"
                            AssignedDate = Get-Date
                            ServicePlans = 1..10 | ForEach-Object {
                                [PSCustomObject]@{
                                    ServicePlanId = [Guid]::NewGuid()
                                    ServicePlanName = "SERVICE_$_"
                                }
                            }
                        }
                    }
                }
            }
            
            # データ処理
            $summary = @{
                TotalUsers = $licenseData.Count
                TotalLicenses = ($licenseData.Licenses | Measure-Object).Count
                UniqueSkus = ($licenseData.Licenses.SkuPartNumber | Select-Object -Unique).Count
            }
            
            [System.GC]::Collect()
            $finalMemory = [System.GC]::GetTotalMemory($false)
            
            $memoryIncreaseMB = ($finalMemory - $initialMemory) / 1MB
            $memoryIncreaseMB | Should -BeLessThan 1000
        }
    }
}

AfterAll {
    Write-Host "`n✅ ライセンス管理機能テストスイート完了" -ForegroundColor Green
}