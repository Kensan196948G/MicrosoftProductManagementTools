# ================================================================================
# MonthlyReportData.psm1
# 月次レポート用実データ取得モジュール
# Microsoft 365 E3ライセンス対応版
# ================================================================================

Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\ErrorHandling.psm1" -Force
Import-Module "$PSScriptRoot\Authentication.psm1" -Force

# 月次レポート用統合データ取得（実データ優先）
function Get-MonthlyReportRealData {
    param(
        [switch]$ForceRealData = $false,
        [switch]$UseSampleData = $false
    )
    
    Write-Log "月次レポートデータ取得を開始します" -Level "Info"
    
    $reportData = @{
        LicenseUsage = @()
        CostAnalysis = @()
        PermissionReview = @()
        ServiceAdoption = @()
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
                    # ライセンス使用状況データ
                    Write-Log "ライセンス使用状況データを取得中..." -Level "Info"
                    $reportData.LicenseUsage = Get-MonthlyLicenseUsageData
                    
                    # コスト分析データ
                    Write-Log "コスト分析データを取得中..." -Level "Info"
                    $reportData.CostAnalysis = Get-MonthlyCostAnalysisData
                    
                    # 権限レビューデータ
                    Write-Log "権限レビューデータを取得中..." -Level "Info"
                    $reportData.PermissionReview = Get-MonthlyPermissionReviewData
                    
                    # サービス採用率データ
                    Write-Log "サービス採用率データを取得中..." -Level "Info"
                    $reportData.ServiceAdoption = Get-MonthlyServiceAdoptionData
                    
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
            
            $reportData.LicenseUsage = Get-MonthlyLicenseUsageSampleData
            $reportData.CostAnalysis = Get-MonthlyCostAnalysisSampleData
            $reportData.PermissionReview = Get-MonthlyPermissionReviewSampleData
            $reportData.ServiceAdoption = Get-MonthlyServiceAdoptionSampleData
        }
        
        # サマリー情報生成
        $totalLicenses = ($reportData.LicenseUsage | Measure-Object -Property 購入数 -Sum).Sum
        $usedLicenses = ($reportData.LicenseUsage | Measure-Object -Property 使用数 -Sum).Sum
        $totalCost = ($reportData.CostAnalysis | Measure-Object -Property 月額コスト -Sum).Sum
        
        $reportData.Summary = @{
            TotalLicenses = $totalLicenses
            UsedLicenses = $usedLicenses
            UnusedLicenses = $totalLicenses - $usedLicenses
            LicenseUtilization = if ($totalLicenses -gt 0) { [Math]::Round(($usedLicenses / $totalLicenses) * 100, 2) } else { 0 }
            TotalMonthlyCost = $totalCost
            HighPrivilegeUsers = ($reportData.PermissionReview | Where-Object { $_.リスクレベル -eq "高" }).Count
            ServiceCount = $reportData.ServiceAdoption.Count
            DataSource = $reportData.DataSource
            ReportDate = $reportData.GeneratedAt.ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        Write-Log "月次レポートデータ取得完了 (ソース: $($reportData.DataSource))" -Level "Info"
        return $reportData
    }
    catch {
        Write-Log "月次レポートデータ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# ライセンス使用状況実データ取得（月次）
function Get-MonthlyLicenseUsageData {
    try {
        $licenseUsage = @()
        $subscribedSkus = Get-MgSubscribedSku -All
        
        foreach ($sku in $subscribedSkus) {
            # ライセンス名のマッピング
            $friendlyName = switch ($sku.SkuPartNumber) {
                "SPE_E3" { "Microsoft 365 E3" }
                "SPE_E5" { "Microsoft 365 E5" }
                "ENTERPRISEPACK" { "Office 365 E3" }
                "ENTERPRISEPREMIUM" { "Office 365 E5" }
                "EXCHANGESTANDARD" { "Exchange Online (Plan 1)" }
                "EXCHANGEENTERPRISE" { "Exchange Online (Plan 2)" }
                "TEAMS_EXPLORATORY" { "Teams Exploratory" }
                "STREAM" { "Microsoft Stream" }
                "POWER_BI_STANDARD" { "Power BI (無料)" }
                "POWER_BI_PRO" { "Power BI Pro" }
                default { $sku.SkuPartNumber }
            }
            
            $prepaidUnits = $sku.PrepaidUnits
            $consumedUnits = $sku.ConsumedUnits
            $availableUnits = $prepaidUnits.Enabled - $consumedUnits
            $utilizationRate = if ($prepaidUnits.Enabled -gt 0) {
                [Math]::Round(($consumedUnits / $prepaidUnits.Enabled) * 100, 2)
            } else { 0 }
            
            # 月額コスト推定（仮の値）
            $unitCost = switch ($sku.SkuPartNumber) {
                "SPE_E3" { 4500 }
                "SPE_E5" { 6700 }
                "ENTERPRISEPACK" { 3000 }
                "ENTERPRISEPREMIUM" { 4800 }
                "EXCHANGESTANDARD" { 500 }
                "EXCHANGEENTERPRISE" { 1000 }
                default { 0 }
            }
            
            $licenseUsage += [PSCustomObject]@{
                ライセンス名 = $friendlyName
                SKU = $sku.SkuPartNumber
                購入数 = $prepaidUnits.Enabled
                使用数 = $consumedUnits
                未使用数 = $availableUnits
                使用率 = $utilizationRate
                状態 = if ($utilizationRate -ge 95) { "フル使用" }
                       elseif ($utilizationRate -ge 80) { "高使用" }
                       elseif ($utilizationRate -ge 50) { "中使用" }
                       else { "低使用" }
                月額コスト = $unitCost * $prepaidUnits.Enabled
                推定年間コスト = $unitCost * $prepaidUnits.Enabled * 12
                推奨アクション = if ($availableUnits -gt 10) { "ライセンス数の見直しを推奨" }
                                elseif ($utilizationRate -ge 95) { "追加購入を検討" }
                                else { "現状維持" }
            }
        }
        
        return $licenseUsage | Sort-Object 使用率 -Descending
    }
    catch {
        Write-Log "月次ライセンス使用状況実データ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# コスト分析実データ取得（月次）
function Get-MonthlyCostAnalysisData {
    try {
        $costAnalysis = @()
        
        # ライセンスベースのコスト分析
        $subscribedSkus = Get-MgSubscribedSku -All
        $users = Get-MgUser -All -Property Id,Department,UserPrincipalName,AssignedLicenses -Top 500
        
        # 部署別のライセンス使用状況を集計
        $departmentCosts = @{}
        
        foreach ($user in $users) {
            $dept = if ($user.Department) { $user.Department } else { "未設定" }
            
            if (-not $departmentCosts.ContainsKey($dept)) {
                $departmentCosts[$dept] = @{
                    UserCount = 0
                    LicenseCost = 0
                    Licenses = @{}
                }
            }
            
            $departmentCosts[$dept].UserCount++
            
            # ユーザーのライセンス確認
            foreach ($license in $user.AssignedLicenses) {
                $sku = $subscribedSkus | Where-Object { $_.SkuId -eq $license.SkuId }
                if ($sku) {
                    $unitCost = switch ($sku.SkuPartNumber) {
                        "SPE_E3" { 4500 }
                        "SPE_E5" { 6700 }
                        "ENTERPRISEPACK" { 3000 }
                        "ENTERPRISEPREMIUM" { 4800 }
                        "EXCHANGESTANDARD" { 500 }
                        "EXCHANGEENTERPRISE" { 1000 }
                        default { 0 }
                    }
                    
                    $departmentCosts[$dept].LicenseCost += $unitCost
                    
                    if (-not $departmentCosts[$dept].Licenses.ContainsKey($sku.SkuPartNumber)) {
                        $departmentCosts[$dept].Licenses[$sku.SkuPartNumber] = 0
                    }
                    $departmentCosts[$dept].Licenses[$sku.SkuPartNumber]++
                }
            }
        }
        
        # 部署別コスト分析レポート作成
        foreach ($dept in $departmentCosts.Keys) {
            $deptData = $departmentCosts[$dept]
            $avgCostPerUser = if ($deptData.UserCount -gt 0) {
                [Math]::Round($deptData.LicenseCost / $deptData.UserCount, 0)
            } else { 0 }
            
            $costAnalysis += [PSCustomObject]@{
                部署 = $dept
                ユーザー数 = $deptData.UserCount
                月額コスト = $deptData.LicenseCost
                ユーザー単価 = $avgCostPerUser
                年間予測コスト = $deptData.LicenseCost * 12
                主要ライセンス = ($deptData.Licenses.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
                コスト効率 = if ($avgCostPerUser -le 3000) { "良好" }
                            elseif ($avgCostPerUser -le 5000) { "標準" }
                            else { "要改善" }
                最適化提案 = if ($avgCostPerUser -gt 5000) { "ライセンスのダウングレードを検討" }
                            elseif ($deptData.UserCount -lt 5) { "部署統合を検討" }
                            else { "現状維持" }
            }
        }
        
        return $costAnalysis | Sort-Object 月額コスト -Descending
    }
    catch {
        Write-Log "月次コスト分析実データ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# 権限レビュー実データ取得（月次）
function Get-MonthlyPermissionReviewData {
    try {
        $permissionReview = @()
        
        # 管理者ロールの取得
        $adminRoles = Get-MgDirectoryRole -All
        
        foreach ($role in $adminRoles) {
            try {
                $members = Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -All
                $memberCount = @($members).Count
                
                if ($memberCount -gt 0) {
                    # リスクレベルの判定
                    $riskLevel = switch ($role.DisplayName) {
                        "Global Administrator" { "高" }
                        "Privileged Role Administrator" { "高" }
                        "Security Administrator" { "高" }
                        "Exchange Administrator" { "中" }
                        "SharePoint Administrator" { "中" }
                        "Teams Administrator" { "中" }
                        "User Administrator" { "中" }
                        default { "低" }
                    }
                    
                    # メンバーの詳細情報取得（最初の5名まで）
                    $memberDetails = @()
                    $count = 0
                    foreach ($member in $members) {
                        $count++
                        if ($count -le 5) {
                            try {
                                $user = Get-MgUser -UserId $member.Id -Property DisplayName,UserPrincipalName -ErrorAction Stop
                                $memberDetails += $user.UserPrincipalName
                            }
                            catch {
                                $memberDetails += "不明なユーザー"
                            }
                        }
                    }
                    
                    $permissionReview += [PSCustomObject]@{
                        ロール名 = $role.DisplayName
                        説明 = if ($role.Description) { $role.Description } else { "説明なし" }
                        メンバー数 = $memberCount
                        メンバー = if ($memberDetails.Count -gt 0) { $memberDetails -join "; " } else { "なし" }
                        リスクレベル = $riskLevel
                        推奨人数 = switch ($role.DisplayName) {
                            "Global Administrator" { "2-3名" }
                            "Privileged Role Administrator" { "1-2名" }
                            "Security Administrator" { "2-3名" }
                            default { "必要に応じて" }
                        }
                        評価 = if ($role.DisplayName -eq "Global Administrator" -and $memberCount -gt 5) { "過剰" }
                               elseif ($role.DisplayName -eq "Global Administrator" -and $memberCount -eq 1) { "不足" }
                               else { "適正" }
                        推奨事項 = if ($role.DisplayName -eq "Global Administrator" -and $memberCount -gt 5) { "権限の削減を推奨" }
                                  elseif ($role.DisplayName -eq "Global Administrator" -and $memberCount -eq 1) { "バックアップ管理者の追加を推奨" }
                                  else { "定期的な見直しを継続" }
                    }
                }
            }
            catch {
                Write-Log "ロール $($role.DisplayName) のメンバー情報取得エラー" -Level "Debug"
            }
        }
        
        return $permissionReview | Sort-Object リスクレベル, メンバー数 -Descending
    }
    catch {
        Write-Log "月次権限レビュー実データ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# サービス採用率実データ取得（月次）
function Get-MonthlyServiceAdoptionData {
    try {
        $serviceAdoption = @()
        
        # 基本的なサービス使用状況（E3ライセンスで取得可能な範囲）
        $totalUsers = (Get-MgUser -All -Filter "accountEnabled eq true").Count
        
        # Exchange Online使用状況
        if (Test-ExchangeOnlineConnection) {
            $mailboxCount = (Get-Mailbox -ResultSize Unlimited).Count
            $serviceAdoption += [PSCustomObject]@{
                サービス名 = "Exchange Online"
                総ユーザー数 = $totalUsers
                アクティブユーザー数 = $mailboxCount
                採用率 = if ($totalUsers -gt 0) { [Math]::Round(($mailboxCount / $totalUsers) * 100, 2) } else { 0 }
                状態 = if ($mailboxCount -ge $totalUsers * 0.9) { "完全採用" }
                       elseif ($mailboxCount -ge $totalUsers * 0.7) { "高採用" }
                       elseif ($mailboxCount -ge $totalUsers * 0.5) { "中採用" }
                       else { "低採用" }
                トレンド = "安定"
                推奨アクション = if ($mailboxCount -lt $totalUsers * 0.9) { "未使用ユーザーへの展開を推進" } else { "現状維持" }
            }
        }
        
        # SharePoint/OneDrive使用状況（推定）
        $sharePointUsers = [Math]::Round($totalUsers * 0.75)  # 推定値
        $serviceAdoption += [PSCustomObject]@{
            サービス名 = "SharePoint/OneDrive"
            総ユーザー数 = $totalUsers
            アクティブユーザー数 = $sharePointUsers
            採用率 = if ($totalUsers -gt 0) { [Math]::Round(($sharePointUsers / $totalUsers) * 100, 2) } else { 0 }
            状態 = "推定値"
            トレンド = "増加傾向"
            推奨アクション = "実際の使用状況分析を推奨"
        }
        
        # Teams使用状況（推定）
        $teamsUsers = [Math]::Round($totalUsers * 0.85)  # 推定値
        $serviceAdoption += [PSCustomObject]@{
            サービス名 = "Microsoft Teams"
            総ユーザー数 = $totalUsers
            アクティブユーザー数 = $teamsUsers
            採用率 = if ($totalUsers -gt 0) { [Math]::Round(($teamsUsers / $totalUsers) * 100, 2) } else { 0 }
            状態 = "推定値"
            トレンド = "増加傾向"
            推奨アクション = "Teams分析ライセンスの検討"
        }
        
        # グループ使用状況
        $groups = Get-MgGroup -All
        $m365Groups = $groups | Where-Object { $_.GroupTypes -contains "Unified" }
        $serviceAdoption += [PSCustomObject]@{
            サービス名 = "Microsoft 365 Groups"
            総ユーザー数 = $totalUsers
            アクティブユーザー数 = $m365Groups.Count  # グループ数で代替
            採用率 = "N/A"
            状態 = "$($m365Groups.Count) グループ"
            トレンド = "安定"
            推奨アクション = "グループの利用状況を定期確認"
        }
        
        return $serviceAdoption
    }
    catch {
        Write-Log "月次サービス採用率実データ取得エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# サンプルデータ生成関数群
function Get-MonthlyLicenseUsageSampleData {
    $licenses = @(
        @{Name="Microsoft 365 E3"; SKU="SPE_E3"; Total=500; Cost=4500},
        @{Name="Microsoft 365 E5"; SKU="SPE_E5"; Total=50; Cost=6700},
        @{Name="Exchange Online Plan 1"; SKU="EXCHANGESTANDARD"; Total=100; Cost=500},
        @{Name="Power BI Pro"; SKU="POWER_BI_PRO"; Total=150; Cost=1200},
        @{Name="Teams Exploratory"; SKU="TEAMS_EXPLORATORY"; Total=200; Cost=0}
    )
    
    $licenseUsage = @()
    foreach ($license in $licenses) {
        $used = Get-Random -Minimum ([Math]::Floor($license.Total * 0.5)) -Maximum $license.Total
        $available = $license.Total - $used
        $utilization = [Math]::Round(($used / $license.Total) * 100, 2)
        
        $licenseUsage += [PSCustomObject]@{
            ライセンス名 = $license.Name
            SKU = $license.SKU
            購入数 = $license.Total
            使用数 = $used
            未使用数 = $available
            使用率 = $utilization
            状態 = if ($utilization -ge 95) { "フル使用" }
                   elseif ($utilization -ge 80) { "高使用" }
                   elseif ($utilization -ge 50) { "中使用" }
                   else { "低使用" }
            月額コスト = $license.Cost * $license.Total
            推定年間コスト = $license.Cost * $license.Total * 12
            推奨アクション = if ($available -gt 10) { "ライセンス数の見直しを推奨" }
                            elseif ($utilization -ge 95) { "追加購入を検討" }
                            else { "現状維持" }
        }
    }
    
    return $licenseUsage | Sort-Object 使用率 -Descending
}

function Get-MonthlyCostAnalysisSampleData {
    $departments = @("営業部", "開発部", "総務部", "マーケティング部", "経理部", "人事部", "IT部", "製造部")
    $costAnalysis = @()
    
    foreach ($dept in $departments) {
        $userCount = Get-Random -Minimum 10 -Maximum 100
        $avgCost = Get-Random -Minimum 2000 -Maximum 6000
        $totalCost = $userCount * $avgCost
        
        $costAnalysis += [PSCustomObject]@{
            部署 = $dept
            ユーザー数 = $userCount
            月額コスト = $totalCost
            ユーザー単価 = $avgCost
            年間予測コスト = $totalCost * 12
            主要ライセンス = @("SPE_E3", "SPE_E5", "ENTERPRISEPACK") | Get-Random
            コスト効率 = if ($avgCost -le 3000) { "良好" }
                        elseif ($avgCost -le 5000) { "標準" }
                        else { "要改善" }
            最適化提案 = if ($avgCost -gt 5000) { "ライセンスのダウングレードを検討" }
                        elseif ($userCount -lt 5) { "部署統合を検討" }
                        else { "現状維持" }
        }
    }
    
    return $costAnalysis | Sort-Object 月額コスト -Descending
}

function Get-MonthlyPermissionReviewSampleData {
    $roles = @(
        @{Name="Global Administrator"; Risk="高"; Recommended="2-3名"},
        @{Name="Security Administrator"; Risk="高"; Recommended="2-3名"},
        @{Name="Exchange Administrator"; Risk="中"; Recommended="3-5名"},
        @{Name="SharePoint Administrator"; Risk="中"; Recommended="3-5名"},
        @{Name="Teams Administrator"; Risk="中"; Recommended="3-5名"},
        @{Name="User Administrator"; Risk="中"; Recommended="5-10名"},
        @{Name="Helpdesk Administrator"; Risk="低"; Recommended="10-20名"},
        @{Name="Reports Reader"; Risk="低"; Recommended="必要に応じて"}
    )
    
    $permissionReview = @()
    foreach ($role in $roles) {
        $memberCount = Get-Random -Minimum 1 -Maximum 15
        
        $permissionReview += [PSCustomObject]@{
            ロール名 = $role.Name
            説明 = "Microsoft 365 $($role.Name)の権限"
            メンバー数 = $memberCount
            メンバー = (1..$([Math]::Min($memberCount, 5)) | ForEach-Object { "admin$_@miraiconst.onmicrosoft.com" }) -join "; "
            リスクレベル = $role.Risk
            推奨人数 = $role.Recommended
            評価 = if ($role.Name -eq "Global Administrator" -and $memberCount -gt 5) { "過剰" }
                   elseif ($role.Name -eq "Global Administrator" -and $memberCount -eq 1) { "不足" }
                   else { "適正" }
            推奨事項 = if ($role.Name -eq "Global Administrator" -and $memberCount -gt 5) { "権限の削減を推奨" }
                      elseif ($role.Name -eq "Global Administrator" -and $memberCount -eq 1) { "バックアップ管理者の追加を推奨" }
                      else { "定期的な見直しを継続" }
        }
    }
    
    return $permissionReview | Sort-Object リスクレベル, メンバー数 -Descending
}

function Get-MonthlyServiceAdoptionSampleData {
    $services = @(
        @{Name="Exchange Online"; Adoption=98},
        @{Name="SharePoint/OneDrive"; Adoption=75},
        @{Name="Microsoft Teams"; Adoption=85},
        @{Name="Microsoft 365 Groups"; Adoption=60},
        @{Name="Power BI"; Adoption=45},
        @{Name="Planner"; Adoption=30},
        @{Name="Stream"; Adoption=25},
        @{Name="Yammer"; Adoption=15}
    )
    
    $totalUsers = 500
    $serviceAdoption = @()
    
    foreach ($service in $services) {
        $activeUsers = [Math]::Round($totalUsers * $service.Adoption / 100)
        
        $serviceAdoption += [PSCustomObject]@{
            サービス名 = $service.Name
            総ユーザー数 = $totalUsers
            アクティブユーザー数 = $activeUsers
            採用率 = $service.Adoption
            状態 = if ($service.Adoption -ge 90) { "完全採用" }
                   elseif ($service.Adoption -ge 70) { "高採用" }
                   elseif ($service.Adoption -ge 50) { "中採用" }
                   else { "低採用" }
            トレンド = @("増加傾向", "安定", "減少傾向") | Get-Random
            推奨アクション = if ($service.Adoption -lt 50) { "利用促進キャンペーンを推奨" }
                            elseif ($service.Adoption -lt 80) { "トレーニングの実施を推奨" }
                            else { "現状維持" }
        }
    }
    
    return $serviceAdoption | Sort-Object 採用率 -Descending
}

# エクスポート
Export-ModuleMember -Function @(
    'Get-MonthlyReportRealData',
    'Get-MonthlyLicenseUsageData',
    'Get-MonthlyCostAnalysisData',
    'Get-MonthlyPermissionReviewData',
    'Get-MonthlyServiceAdoptionData'
)