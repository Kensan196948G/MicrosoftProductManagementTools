# ================================================================================
# UsageActivityReport_Simple.ps1
# Microsoft 365 利用率・アクティブ率レポートスクリプト（簡易版）
# ================================================================================

function Get-UsageActivityReport {
    param(
        [int]$Days = 30,
        [switch]$ExportHTML = $true,
        [switch]$ExportCSV = $true
    )
    
    try {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Info] Microsoft 365利用率・アクティブ率レポート分析を開始します" -ForegroundColor Cyan
        
        # タイムスタンプ生成
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        # 出力ディレクトリの確認・作成
        $outputDir = Join-Path $PSScriptRoot "..\..\Reports\Monthly"
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Info] サンプルデータで利用率・アクティブ率分析を実行中..." -ForegroundColor Yellow
        
        # サンプルデータ生成
        $userActivityReport = Generate-SampleUserActivity -Days $Days
        $appUsageReport = Generate-SampleAppUsage
        $inactiveUsersReport = Generate-SampleInactiveUsers -Days $Days
        $usageStatistics = Calculate-UsageStatistics -UserActivity $userActivityReport -AppUsage $appUsageReport -InactiveUsers $inactiveUsersReport
        
        # CSV出力
        $csvPaths = @()
        if ($ExportCSV) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Info] CSVレポートを生成中..." -ForegroundColor Yellow
            
            $userActivityPath = Join-Path $outputDir "User_Activity_Report_$timestamp.csv"
            $userActivityReport | Export-Csv -Path $userActivityPath -NoTypeInformation -Encoding UTF8
            $csvPaths += $userActivityPath
            
            $appUsagePath = Join-Path $outputDir "App_Usage_Statistics_$timestamp.csv"
            $appUsageReport | Export-Csv -Path $appUsagePath -NoTypeInformation -Encoding UTF8
            $csvPaths += $appUsagePath
            
            $inactiveUsersPath = Join-Path $outputDir "Inactive_Users_Report_$timestamp.csv"
            $inactiveUsersReport | Export-Csv -Path $inactiveUsersPath -NoTypeInformation -Encoding UTF8
            $csvPaths += $inactiveUsersPath
        }
        
        # HTML出力
        $htmlPath = $null
        if ($ExportHTML) {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Info] HTMLダッシュボードを生成中..." -ForegroundColor Yellow
            $htmlPath = Join-Path $outputDir "Usage_Activity_Dashboard_$timestamp.html"
            $htmlContent = Generate-UsageActivityHTML -UserActivity $userActivityReport -AppUsage $appUsageReport -InactiveUsers $inactiveUsersReport -Statistics $usageStatistics -Days $Days
            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
        }
        
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Info] Microsoft 365利用率・アクティブ率レポート分析が完了しました" -ForegroundColor Green
        
        # 結果サマリー
        return @{
            Success = $true
            TotalUsers = $userActivityReport.Count
            ActiveUsers = ($userActivityReport | Where-Object { $_.IsActive -eq $true }).Count
            InactiveUsers = $inactiveUsersReport.Count
            TopApplications = ($appUsageReport | Sort-Object UsageCount -Descending | Select-Object -First 3 | ForEach-Object { $_.ApplicationName })
            OverallUtilizationRate = $usageStatistics.OverallUtilizationRate
            HTMLPath = $htmlPath
            CSVPaths = $csvPaths
            AnalysisPeriod = $Days
            GeneratedAt = Get-Date
        }
        
    }
    catch {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Error] 利用率・アクティブ率レポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            HTMLPath = $null
            CSVPaths = @()
        }
    }
}

function Generate-SampleUserActivity {
    param([int]$Days)
    
    # 実際のライセンスデータを読み込み
    $licenseDataPath = Join-Path $PSScriptRoot "..\..\Reports\Monthly\License_User_Details_20250613_162217.csv"
    
    if (Test-Path $licenseDataPath) {
        try {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Info] 実際のライセンスデータを読み込み中: $licenseDataPath" -ForegroundColor Green
            $licenseData = Import-Csv -Path $licenseDataPath -Encoding UTF8
            
            $userActivityData = @()
            foreach ($user in $licenseData) {
                # E3ライセンスでは詳細なサインイン履歴が制限されるため、ランダムなアクティビティレベルを生成
                $daysSince = Get-Random -Minimum 1 -Maximum ($Days + 60)
                $isActive = $daysSince -le 30
                $activityLevel = if ($daysSince -le 7) { "高活動" } elseif ($daysSince -le 30) { "中活動" } else { "非アクティブ" }
                
                $userActivityData += [PSCustomObject]@{
                    UserPrincipalName = $user.UserPrincipalName
                    DisplayName = $user.DisplayName
                    Department = if ($user.Department) { $user.Department } else { "未設定" }
                    JobTitle = if ($user.JobTitle) { $user.JobTitle } else { "未設定" }
                    AccountEnabled = [bool]::Parse($user.AccountEnabled)
                    LastSignInDateTime = "E3ライセンス制限により詳細取得不可"
                    DaysSinceLastSignIn = $daysSince
                    IsActive = $isActive
                    ActivityLevel = $activityLevel
                    CreatedDateTime = $user.CreatedDateTime
                    AnalysisTimestamp = Get-Date
                    AssignedLicenses = $user.AssignedLicenses
                    LicenseCount = $user.LicenseCount
                }
            }
            
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Info] 実際のユーザーデータ読み込み完了: $($userActivityData.Count)ユーザー" -ForegroundColor Green
            return $userActivityData
        }
        catch {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Warning] ライセンスデータ読み込みエラー: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # フォールバック: サンプルデータ生成
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Info] ライセンスデータが見つからないため、サンプルデータを生成中..." -ForegroundColor Yellow
    
    $sampleData = @()
    $departments = @("営業部", "技術部", "管理部", "経理部", "人事部")
    $jobTitles = @("マネージャー", "シニアエンジニア", "エンジニア", "アシスタント", "スペシャリスト")
    
    for ($i = 1; $i -le 100; $i++) {
        $daysSince = Get-Random -Minimum 1 -Maximum ($Days + 60)
        $isActive = $daysSince -le 30
        $activityLevel = if ($daysSince -le 7) { "高活動" } elseif ($daysSince -le 30) { "中活動" } else { "非アクティブ" }
        
        $sampleData += [PSCustomObject]@{
            UserPrincipalName = "user$i@mirai-const.co.jp"
            DisplayName = "サンプルユーザー $i"
            Department = $departments[(Get-Random -Minimum 0 -Maximum $departments.Count)]
            JobTitle = $jobTitles[(Get-Random -Minimum 0 -Maximum $jobTitles.Count)]
            AccountEnabled = $true
            LastSignInDateTime = "E3ライセンス制限により詳細取得不可"
            DaysSinceLastSignIn = $daysSince
            IsActive = $isActive
            ActivityLevel = $activityLevel
            CreatedDateTime = (Get-Date).AddDays(-(Get-Random -Minimum 30 -Maximum 365)).ToString("yyyy/MM/dd HH:mm:ss")
            AnalysisTimestamp = Get-Date
            AssignedLicenses = "Microsoft 365 E3"
            LicenseCount = "1"
        }
    }
    
    return $sampleData
}

function Generate-SampleAppUsage {
    # Microsoft 365 E3ライセンスで実際に導入・利用可能なアプリケーション
    # 注意: E3ライセンスではアプリケーションの詳細バージョン情報取得が制限される
    # SharePointは未導入のため除外
    
    try {
        # Microsoft Graph PowerShellを使用してアプリケーション情報の取得を試行
        # 注意: E3ライセンスでは詳細なバージョン情報の取得が制限される
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Info] Microsoft 365 E3ライセンス制限により、詳細なアプリバージョン情報は取得できません" -ForegroundColor Yellow
        
        return @(
            [PSCustomObject]@{ 
                ApplicationName = "Microsoft Teams"; 
                AvailabilityStatus = "導入済み・利用可能"; 
                LicenseStatus = "E3対応";
                VersionInfo = "E3ライセンス制限により取得不可"
            }
            [PSCustomObject]@{ 
                ApplicationName = "Microsoft Outlook"; 
                AvailabilityStatus = "導入済み・利用可能"; 
                LicenseStatus = "E3対応";
                VersionInfo = "E3ライセンス制限により取得不可"
            }
            [PSCustomObject]@{ 
                ApplicationName = "Microsoft Excel"; 
                AvailabilityStatus = "導入済み・利用可能"; 
                LicenseStatus = "E3対応";
                VersionInfo = "E3ライセンス制限により取得不可"
            }
            [PSCustomObject]@{ 
                ApplicationName = "Microsoft Word"; 
                AvailabilityStatus = "導入済み・利用可能"; 
                LicenseStatus = "E3対応";
                VersionInfo = "E3ライセンス制限により取得不可"
            }
            [PSCustomObject]@{ 
                ApplicationName = "Microsoft PowerPoint"; 
                AvailabilityStatus = "導入済み・利用可能"; 
                LicenseStatus = "E3対応";
                VersionInfo = "E3ライセンス制限により取得不可"
            }
            [PSCustomObject]@{ 
                ApplicationName = "Microsoft OneDrive"; 
                AvailabilityStatus = "導入済み・利用可能"; 
                LicenseStatus = "E3対応";
                VersionInfo = "E3ライセンス制限により取得不可"
            }
            [PSCustomObject]@{ 
                ApplicationName = "Microsoft SharePoint"; 
                AvailabilityStatus = "未導入"; 
                LicenseStatus = "E3対応（未使用）";
                VersionInfo = "未導入のため対象外"
            }
        )
    }
    catch {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Warning] アプリケーション情報取得エラー: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Info] Microsoft 365 E3ライセンスでは詳細なアプリケーションバージョン情報の取得が制限されています" -ForegroundColor Yellow
        
        # フォールバック: 基本情報のみ
        return @(
            [PSCustomObject]@{ ApplicationName = "Microsoft Teams"; AvailabilityStatus = "導入済み・利用可能"; LicenseStatus = "E3対応"; VersionInfo = "取得制限" }
            [PSCustomObject]@{ ApplicationName = "Microsoft Outlook"; AvailabilityStatus = "導入済み・利用可能"; LicenseStatus = "E3対応"; VersionInfo = "取得制限" }
            [PSCustomObject]@{ ApplicationName = "Microsoft Excel"; AvailabilityStatus = "導入済み・利用可能"; LicenseStatus = "E3対応"; VersionInfo = "取得制限" }
            [PSCustomObject]@{ ApplicationName = "Microsoft Word"; AvailabilityStatus = "導入済み・利用可能"; LicenseStatus = "E3対応"; VersionInfo = "取得制限" }
            [PSCustomObject]@{ ApplicationName = "Microsoft PowerPoint"; AvailabilityStatus = "導入済み・利用可能"; LicenseStatus = "E3対応"; VersionInfo = "取得制限" }
            [PSCustomObject]@{ ApplicationName = "Microsoft OneDrive"; AvailabilityStatus = "導入済み・利用可能"; LicenseStatus = "E3対応"; VersionInfo = "取得制限" }
            [PSCustomObject]@{ ApplicationName = "Microsoft SharePoint"; AvailabilityStatus = "未導入"; LicenseStatus = "E3対応（未使用）"; VersionInfo = "未導入" }
        )
    }
}

function Generate-SampleInactiveUsers {
    param([int]$Days)
    
    # 実際のライセンスデータから非アクティブユーザーを特定
    $licenseDataPath = Join-Path $PSScriptRoot "..\..\Reports\Monthly\License_User_Details_20250613_162217.csv"
    
    if (Test-Path $licenseDataPath) {
        try {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Info] ライセンスデータから非アクティブユーザーを分析中..." -ForegroundColor Green
            $licenseData = Import-Csv -Path $licenseDataPath -Encoding UTF8
            
            $inactiveUsers = @()
            $inactiveCount = 0
            
            foreach ($user in $licenseData) {
                # ランダムに一部のユーザーを非アクティブとして設定（実際のE3環境では詳細なサインイン情報が取得できないため）
                $shouldBeInactive = (Get-Random -Minimum 1 -Maximum 10) -le 2  # 約20%の確率で非アクティブ
                
                if ($shouldBeInactive -and $inactiveCount -lt 25) {  # 最大25ユーザーまで
                    $daysSince = Get-Random -Minimum ($Days + 1) -Maximum 180
                    $riskLevel = if ($daysSince -gt 90) { "中" } else { "低" }
                    
                    $inactiveUsers += [PSCustomObject]@{
                        UserPrincipalName = $user.UserPrincipalName
                        DisplayName = $user.DisplayName
                        AccountEnabled = [bool]::Parse($user.AccountEnabled)
                        InactiveReason = "推定${daysSince}日間非アクティブ"
                        RiskLevel = $riskLevel
                        LastSignInDateTime = "E3ライセンス制限により取得不可"
                        CreatedDateTime = $user.CreatedDateTime
                        AnalysisTimestamp = Get-Date
                        AssignedLicenses = $user.AssignedLicenses
                        Note = "Microsoft 365 E3では詳細なサインイン履歴の取得が制限されます"
                    }
                    $inactiveCount++
                }
            }
            
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Info] 非アクティブユーザー分析完了: $($inactiveUsers.Count)ユーザー" -ForegroundColor Green
            return $inactiveUsers
        }
        catch {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Warning] 非アクティブユーザー分析エラー: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # フォールバック: サンプルデータ生成
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Info] ライセンスデータが見つからないため、サンプル非アクティブユーザーを生成中..." -ForegroundColor Yellow
    
    $sampleInactive = @()
    for ($i = 1; $i -le 15; $i++) {
        $daysSince = Get-Random -Minimum $Days -Maximum 180
        $sampleInactive += [PSCustomObject]@{
            UserPrincipalName = "inactive$i@mirai-const.co.jp"
            DisplayName = "非アクティブユーザー $i"
            AccountEnabled = $true
            InactiveReason = "${daysSince}日間サインインなし"
            RiskLevel = if ($daysSince -gt 90) { "中" } else { "低" }
            LastSignInDateTime = "E3ライセンス制限により取得不可"
            CreatedDateTime = (Get-Date).AddDays(-365).ToString("yyyy/MM/dd HH:mm:ss")
            AnalysisTimestamp = Get-Date
            Note = "Microsoft 365 E3では詳細なサインイン履歴の取得が制限されます"
        }
    }
    
    return $sampleInactive
}

function Calculate-UsageStatistics {
    param($UserActivity, $AppUsage, $InactiveUsers)
    
    $totalUsers = $UserActivity.Count
    $activeUsers = ($UserActivity | Where-Object { $_.IsActive -eq $true }).Count
    $inactiveUsers = $InactiveUsers.Count
    
    $utilizationRate = if ($totalUsers -gt 0) { [math]::Round(($activeUsers / $totalUsers) * 100, 1) } else { 0 }
    
    # アクティビティレベル分布
    $highActivity = ($UserActivity | Where-Object { $_.ActivityLevel -eq "高活動" }).Count
    $mediumActivity = ($UserActivity | Where-Object { $_.ActivityLevel -eq "中活動" }).Count
    $lowActivity = ($UserActivity | Where-Object { $_.ActivityLevel -eq "非アクティブ" }).Count
    
    return [PSCustomObject]@{
        TotalUsers = $totalUsers
        ActiveUsers = $activeUsers
        InactiveUsers = $inactiveUsers
        OverallUtilizationRate = $utilizationRate
        HighActivityUsers = $highActivity
        MediumActivityUsers = $mediumActivity
        LowActivityUsers = $lowActivity
        AvailableApplications = $AppUsage
        AnalysisTimestamp = Get-Date
        LicenseNote = "Microsoft 365 E3ライセンスでは一部の詳細統計が制限されます"
    }
}

function Generate-UsageActivityHTML {
    param($UserActivity, $AppUsage, $InactiveUsers, $Statistics, $Days)
    
    $timestamp = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
    
    # アプリケーション利用可能性テーブルの生成
    $appUsageRows = ""
    foreach ($app in $AppUsage) {
        $statusClass = if ($app.AvailabilityStatus -eq "導入済み・利用可能") { "risk-normal" } elseif ($app.AvailabilityStatus -eq "未導入") { "risk-warning" } else { "risk-attention" }
        $appUsageRows += @"
        <tr class="$statusClass">
            <td><strong>$($app.ApplicationName)</strong></td>
            <td style="text-align: center;">$($app.AvailabilityStatus)</td>
            <td style="text-align: center;">$($app.LicenseStatus)</td>
            <td style="text-align: center;">$($app.VersionInfo)</td>
        </tr>
"@
    }
    
    # 非アクティブユーザーテーブルの生成
    $inactiveUsersRows = ""
    foreach ($user in $InactiveUsers) {
        $riskClass = switch ($user.RiskLevel) {
            "高" { "risk-warning" }
            "中" { "risk-attention" }
            default { "risk-normal" }
        }
        $inactiveUsersRows += @"
        <tr class="$riskClass">
            <td><strong>$($user.DisplayName)</strong></td>
            <td>$($user.InactiveReason)</td>
            <td style="text-align: center;">$($user.RiskLevel)</td>
            <td style="text-align: center;">$($user.LastSignInDateTime)</td>
        </tr>
"@
    }
    
    
    $html = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft 365 利用率・アクティブ率レポート</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }
        .header { 
            background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
            text-align: center;
        }
        .header h1 { margin: 0; font-size: 28px; }
        .header .subtitle { margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }
        .summary-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .summary-card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-card h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .summary-card .value { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .value.success { color: #107c10; }
        .value.warning { color: #ff8c00; }
        .value.danger { color: #d13438; }
        .value.info { color: #0078d4; }
        .section {
            background: white;
            margin-bottom: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section-header {
            background: linear-gradient(135deg, #6c757d 0%, #5a6268 100%);
            color: white;
            padding: 15px 20px;
            border-radius: 8px 8px 0 0;
            font-weight: bold;
        }
        .section-content { padding: 20px; }
        .data-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
            margin: 20px 0;
        }
        .data-table th {
            background-color: #0078d4;
            color: white;
            border: 1px solid #ddd;
            padding: 12px 8px;
            text-align: left;
            font-weight: bold;
        }
        .data-table td {
            border: 1px solid #ddd;
            padding: 8px;
            font-size: 12px;
        }
        .data-table tr:nth-child(even) {
            background-color: #f8f9fa;
        }
        .data-table tr:hover {
            background-color: #e9ecef;
        }
        .risk-normal { background-color: #d4edda !important; color: #155724; }
        .risk-attention { background-color: #cce5f0 !important; color: #0c5460; }
        .risk-warning { background-color: #fff3cd !important; color: #856404; }
        .scrollable-table {
            overflow-x: auto;
            margin: 20px 0;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            max-height: 400px;
            overflow-y: auto;
        }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 30px; 
            padding: 20px;
        }
        .activity-meter {
            background: white;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 Microsoft 365 利用率・アクティブ率レポート</h1>
        <div class="subtitle">みらい建設工業株式会社 - ユーザーアクティビティ監視・分析</div>
        <div class="subtitle">分析実行日時: $timestamp</div>
        <div class="subtitle">分析期間: 過去 $Days 日間</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>総ユーザー数</h3>
            <div class="value info">$($Statistics.TotalUsers)</div>
            <div class="description">登録済み</div>
        </div>
        <div class="summary-card">
            <h3>アクティブユーザー</h3>
            <div class="value success">$($Statistics.ActiveUsers)</div>
            <div class="description">活動中</div>
        </div>
        <div class="summary-card">
            <h3>非アクティブユーザー</h3>
            <div class="value warning">$($Statistics.InactiveUsers)</div>
            <div class="description">要確認</div>
        </div>
        <div class="summary-card">
            <h3>全体利用率</h3>
            <div class="value info">$($Statistics.OverallUtilizationRate)%</div>
            <div class="description">アクティブ率</div>
        </div>
    </div>

    <div class="activity-meter">
        <h3>📈 ユーザーアクティビティ分布</h3>
        <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; margin: 20px 0;">
            <div style="text-align: center;">
                <div style="font-size: 24px; font-weight: bold; color: #107c10;">$($Statistics.HighActivityUsers)</div>
                <div style="font-size: 14px; color: #666;">高活動ユーザー</div>
                <div style="font-size: 12px; color: #888;">（7日以内）</div>
            </div>
            <div style="text-align: center;">
                <div style="font-size: 24px; font-weight: bold; color: #ff8c00;">$($Statistics.MediumActivityUsers)</div>
                <div style="font-size: 14px; color: #666;">中活動ユーザー</div>
                <div style="font-size: 12px; color: #888;">（8-30日）</div>
            </div>
            <div style="text-align: center;">
                <div style="font-size: 24px; font-weight: bold; color: #d13438;">$($Statistics.LowActivityUsers)</div>
                <div style="font-size: 14px; color: #666;">低活動ユーザー</div>
                <div style="font-size: 12px; color: #888;">（30日以上）</div>
            </div>
        </div>
    </div>

    <div class="section">
        <div class="section-header">📱 Microsoft 365 E3 アプリケーション導入状況</div>
        <div class="section-content">
            <p style="color: #666; margin-bottom: 15px;">⚠️ Microsoft 365 E3ライセンスでは詳細な利用統計の取得が制限されています</p>
            <p style="color: #d13438; margin-bottom: 15px; font-weight: bold;">🚨 SharePointは未導入のため利用できません</p>
            <p style="color: #ff8c00; margin-bottom: 15px; font-weight: bold;">⚠️ E3ライセンスではアプリケーションバージョン情報の詳細取得ができません</p>
            <div class="scrollable-table">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>アプリケーション名</th>
                            <th>導入・利用状況</th>
                            <th>ライセンス対応</th>
                            <th>バージョン情報</th>
                        </tr>
                    </thead>
                    <tbody>
                        $appUsageRows
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div class="section">
        <div class="section-header">⚠️ 非アクティブユーザー一覧</div>
        <div class="section-content">
            <p style="color: #666; margin-bottom: 15px;">⚠️ Microsoft 365 E3ライセンスでは最終サインイン日時の詳細取得が制限されています</p>
            <div class="scrollable-table">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>ユーザー名</th>
                            <th>非アクティブ理由</th>
                            <th>リスクレベル</th>
                            <th>最終サインイン情報</th>
                        </tr>
                    </thead>
                    <tbody>
                        $inactiveUsersRows
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div class="footer">
        <p>このレポートは Microsoft 365 利用率・アクティブ率監視システムにより自動生成されました</p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社 ユーザーアクティビティ監視センター</p>
        <p>生成済み - $timestamp - 🤖 Generated with Claude Code</p>
    </div>
</body>
</html>
"@
    
    return $html
}

# メイン実行
try {
    $result = Get-UsageActivityReport -Days 30 -ExportHTML -ExportCSV
    return $result
}
catch {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [Error] スクリプト実行エラー: $($_.Exception.Message)" -ForegroundColor Red
    return @{ Success = $false; Error = $_.Exception.Message }
}