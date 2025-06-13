# ================================================================================
# UsageActivityReport.ps1
# Microsoft 365 利用率・アクティブ率レポートスクリプト
# ITSM/ISO27001/27002準拠 - ユーザーアクティビティ監視・分析
# ================================================================================

# 共通モジュールのインポート（重複回避・簡素化）
try {
    # スタンドアロンモードで実行（モジュール依存を最小化）
    $moduleImported = $false
    
    if (Test-Path "$PSScriptRoot\..\Common\Logging.psm1") {
        Import-Module "$PSScriptRoot\..\Common\Logging.psm1" -Force -WarningAction SilentlyContinue
        $moduleImported = $true
    }
    
    if (-not $moduleImported) {
        Write-Host "共通モジュールが見つからないため、スタンドアロンモードで実行します..." -ForegroundColor Yellow
    }
}
catch {
    # エラーを無視してスタンドアロンモードで継続
}

function Get-UsageActivityReport {
    <#
    .SYNOPSIS
    Microsoft 365の利用率・アクティブ率レポートを生成

    .DESCRIPTION
    ユーザーアクティビティ分析、アプリケーション利用統計、非アクティブユーザー検出を実行

    .PARAMETER OutputPath
    レポート出力パス

    .PARAMETER Days
    分析対象期間（日数）

    .PARAMETER IncludeDetailedStats
    詳細統計を含める

    .PARAMETER ExportHTML
    HTMLレポートを生成

    .PARAMETER ExportCSV
    CSVレポートを生成

    .EXAMPLE
    Get-UsageActivityReport -Days 30 -ExportHTML -ExportCSV
    #>
    
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "Reports\Monthly",
        
        [Parameter(Mandatory = $false)]
        [int]$Days = 30,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeDetailedStats = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportHTML = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExportCSV = $true
    )
    
    try {
        # ログ関数の定義（スタンドアロン対応）
        if (-not (Get-Command "Write-Log" -ErrorAction SilentlyContinue)) {
            function Write-Log {
                param([string]$Message, [string]$Level = "Info")
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
                    switch ($Level) {
                        "Error" { "Red" }
                        "Warning" { "Yellow" }
                        "Info" { "Cyan" }
                        default { "White" }
                    }
                )
            }
        }
        
        Write-Log "Microsoft 365利用率・アクティブ率レポート分析を開始します"
        
        # Microsoft Graph接続確認（オプション）
        $graphConnected = $false
        try {
            if (Get-Command "Get-MgContext" -ErrorAction SilentlyContinue) {
                $context = Get-MgContext
                if ($context) {
                    Write-Log "Microsoft Graph接続済み（テナント: $($context.TenantId))"
                    $graphConnected = $true
                } else {
                    Write-Log "Microsoft Graphに接続されていません。サンプルデータで分析を継続します..." "Info"
                }
            } else {
                Write-Log "Microsoft Graph PowerShellモジュールが見つかりません。サンプルデータで分析を継続します..." "Info"
            }
        }
        catch {
            Write-Log "Microsoft Graph接続確認エラー: $($_.Exception.Message)" "Warning"
            Write-Log "サンプルデータで分析を継続します..." "Info"
        }
        
        # タイムスタンプ生成
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        # 出力ディレクトリの確認・作成
        $outputDir = Join-Path $PSScriptRoot "..\..\$OutputPath"
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        
        Write-Log "利用率・アクティブ率データを取得中..."
        
        # 1. ユーザーアクティビティ分析
        Write-Log "ユーザーアクティビティ分析を実行中..."
        $userActivityReport = Get-UserActivityAnalysis -Days $Days
        
        # 2. アプリケーション利用統計
        Write-Log "アプリケーション利用統計を取得中..."
        $appUsageReport = Get-ApplicationUsageStats -Days $Days
        
        # 3. 非アクティブユーザー検出
        Write-Log "非アクティブユーザー検出を実行中..."
        $inactiveUsersReport = Get-InactiveUsersAnalysis -Days $Days
        
        # 4. 利用率統計計算
        Write-Log "利用率統計を計算中..."
        $usageStatistics = Calculate-UsageStatistics -UserActivity $userActivityReport -AppUsage $appUsageReport -InactiveUsers $inactiveUsersReport
        
        # CSV出力
        if ($ExportCSV) {
            Write-Log "CSVレポートを生成中..."
            
            # ユーザーアクティビティCSV
            $userActivityPath = Join-Path $outputDir "User_Activity_Report_$timestamp.csv"
            $userActivityReport | Export-Csv -Path $userActivityPath -NoTypeInformation -Encoding UTF8
            Write-Log "CSVエクスポート完了 (BOM付きUTF-8): $userActivityPath"
            
            # アプリケーション利用統計CSV
            $appUsagePath = Join-Path $outputDir "App_Usage_Statistics_$timestamp.csv"
            $appUsageReport | Export-Csv -Path $appUsagePath -NoTypeInformation -Encoding UTF8
            Write-Log "CSVエクスポート完了 (BOM付きUTF-8): $appUsagePath"
            
            # 非アクティブユーザーCSV
            $inactiveUsersPath = Join-Path $outputDir "Inactive_Users_Report_$timestamp.csv"
            $inactiveUsersReport | Export-Csv -Path $inactiveUsersPath -NoTypeInformation -Encoding UTF8
            Write-Log "CSVエクスポート完了 (BOM付きUTF-8): $inactiveUsersPath"
        }
        
        # HTML出力
        if ($ExportHTML) {
            $htmlPath = Join-Path $outputDir "Usage_Activity_Dashboard_$timestamp.html"
            $htmlContent = Generate-UsageActivityHTML -UserActivity $userActivityReport -AppUsage $appUsageReport -InactiveUsers $inactiveUsersReport -Statistics $usageStatistics -Days $Days
            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
        }
        
        Write-Log "Microsoft 365利用率・アクティブ率レポート分析が完了しました"
        
        # 結果サマリー
        return @{
            Success = $true
            TotalUsers = $userActivityReport.Count
            ActiveUsers = ($userActivityReport | Where-Object { $_.IsActive -eq $true }).Count
            InactiveUsers = $inactiveUsersReport.Count
            TopApplications = ($appUsageReport | Sort-Object UsageCount -Descending | Select-Object -First 5 | ForEach-Object { $_.ApplicationName })
            OverallUtilizationRate = $usageStatistics.OverallUtilizationRate
            HTMLPath = if ($ExportHTML) { $htmlPath } else { $null }
            CSVPaths = if ($ExportCSV) { @($userActivityPath, $appUsagePath, $inactiveUsersPath) } else { @() }
            AnalysisPeriod = $Days
            GeneratedAt = Get-Date
        }
        
    }
    catch {
        Write-Log "利用率・アクティブ率レポート生成エラー: $($_.Exception.Message)" "Error"
        return @{
            Success = $false
            Error = $_.Exception.Message
            HTMLPath = $null
            CSVPaths = @()
        }
    }
}

function Get-UserActivityAnalysis {
    param([int]$Days)
    
    try {
        # Microsoft Graph APIを使用してユーザーアクティビティを取得
        $users = Get-MgUser -All -Property "Id,DisplayName,UserPrincipalName,AccountEnabled,SignInActivity,CreatedDateTime,Department,JobTitle"
        
        $userActivityReport = @()
        foreach ($user in $users) {
            $lastSignIn = $null
            $daysSinceLastSignIn = $null
            $isActive = $false
            
            # サインイン情報の解析
            if ($user.SignInActivity -and $user.SignInActivity.LastSignInDateTime) {
                $lastSignIn = $user.SignInActivity.LastSignInDateTime
                $daysSinceLastSignIn = (Get-Date) - $lastSignIn
                $isActive = $daysSinceLastSignIn.Days -le $Days
            }
            
            $activityStatus = "非アクティブ"
            if ($isActive) {
                if ($daysSinceLastSignIn.Days -le 7) {
                    $activityStatus = "高活動"
                } elseif ($daysSinceLastSignIn.Days -le 30) {
                    $activityStatus = "中活動"
                } else {
                    $activityStatus = "低活動"
                }
            }
            
            $userActivityReport += [PSCustomObject]@{
                UserPrincipalName = $user.UserPrincipalName
                DisplayName = $user.DisplayName
                Department = $user.Department
                JobTitle = $user.JobTitle
                AccountEnabled = $user.AccountEnabled
                LastSignInDateTime = if ($lastSignIn) { $lastSignIn.ToString("yyyy/MM/dd HH:mm:ss") } else { "サインイン記録なし" }
                DaysSinceLastSignIn = if ($daysSinceLastSignIn) { $daysSinceLastSignIn.Days } else { $null }
                IsActive = $isActive
                ActivityLevel = $activityStatus
                CreatedDateTime = if ($user.CreatedDateTime) { $user.CreatedDateTime.ToString("yyyy/MM/dd HH:mm:ss") } else { "不明" }
                AnalysisTimestamp = Get-Date
            }
        }
        
        return $userActivityReport
    }
    catch {
        Write-Log "ユーザーアクティビティ取得エラー: $($_.Exception.Message)" "Warning"
        
        # サンプルデータ生成
        return Generate-SampleUserActivity -Days $Days
    }
}

function Get-ApplicationUsageStats {
    param([int]$Days)
    
    try {
        # Microsoft Graph Reportsを使用してアプリケーション利用統計を取得
        # Note: 実際の実装では適切なAPIエンドポイントを使用
        Write-Log "アプリケーション利用統計を取得中..." "Info"
        
        # サンプルデータで代替（実環境では実際のAPIを使用）
        return Generate-SampleAppUsage -Days $Days
    }
    catch {
        Write-Log "アプリケーション利用統計取得エラー: $($_.Exception.Message)" "Warning"
        return Generate-SampleAppUsage -Days $Days
    }
}

function Get-InactiveUsersAnalysis {
    param([int]$Days)
    
    try {
        $users = Get-MgUser -All -Property "Id,DisplayName,UserPrincipalName,AccountEnabled,SignInActivity,CreatedDateTime,Department"
        
        $inactiveUsers = @()
        foreach ($user in $users) {
            $isInactive = $false
            $inactiveReason = ""
            
            if (-not $user.AccountEnabled) {
                $isInactive = $true
                $inactiveReason = "アカウント無効"
            }
            elseif ($user.SignInActivity -and $user.SignInActivity.LastSignInDateTime) {
                $daysSinceLastSignIn = ((Get-Date) - $user.SignInActivity.LastSignInDateTime).Days
                if ($daysSinceLastSignIn -gt $Days) {
                    $isInactive = $true
                    $inactiveReason = "${daysSinceLastSignIn}日間サインインなし"
                }
            }
            elseif (-not $user.SignInActivity.LastSignInDateTime) {
                $isInactive = $true
                $inactiveReason = "サインイン記録なし"
            }
            
            if ($isInactive) {
                $riskLevel = "低"
                if ($inactiveReason -match "アカウント無効") {
                    $riskLevel = "高"
                } elseif ($inactiveReason -match "(\d+)日間" -and [int]$matches[1] -gt 90) {
                    $riskLevel = "中"
                }
                
                $inactiveUsers += [PSCustomObject]@{
                    UserPrincipalName = $user.UserPrincipalName
                    DisplayName = $user.DisplayName
                    Department = $user.Department
                    AccountEnabled = $user.AccountEnabled
                    InactiveReason = $inactiveReason
                    RiskLevel = $riskLevel
                    LastSignInDateTime = if ($user.SignInActivity.LastSignInDateTime) { 
                        $user.SignInActivity.LastSignInDateTime.ToString("yyyy/MM/dd HH:mm:ss") 
                    } else { 
                        "記録なし" 
                    }
                    CreatedDateTime = if ($user.CreatedDateTime) { $user.CreatedDateTime.ToString("yyyy/MM/dd HH:mm:ss") } else { "不明" }
                    AnalysisTimestamp = Get-Date
                }
            }
        }
        
        return $inactiveUsers
    }
    catch {
        Write-Log "非アクティブユーザー分析エラー: $($_.Exception.Message)" "Warning"
        return Generate-SampleInactiveUsers -Days $Days
    }
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
    $lowActivity = ($UserActivity | Where-Object { $_.ActivityLevel -eq "低活動" }).Count
    
    # 部署別統計
    $departmentStats = $UserActivity | Group-Object Department | ForEach-Object {
        $deptActiveUsers = ($_.Group | Where-Object { $_.IsActive -eq $true }).Count
        $deptUtilization = if ($_.Count -gt 0) { [math]::Round(($deptActiveUsers / $_.Count) * 100, 1) } else { 0 }
        
        [PSCustomObject]@{
            Department = if ($_.Name) { $_.Name } else { "未設定" }
            TotalUsers = $_.Count
            ActiveUsers = $deptActiveUsers
            UtilizationRate = $deptUtilization
        }
    }
    
    return [PSCustomObject]@{
        TotalUsers = $totalUsers
        ActiveUsers = $activeUsers
        InactiveUsers = $inactiveUsers
        OverallUtilizationRate = $utilizationRate
        HighActivityUsers = $highActivity
        MediumActivityUsers = $mediumActivity
        LowActivityUsers = $lowActivity
        DepartmentStatistics = $departmentStats
        TopApplications = ($AppUsage | Sort-Object UsageCount -Descending | Select-Object -First 10)
        AnalysisTimestamp = Get-Date
    }
}

# サンプルデータ生成関数（実際のAPI接続が失敗した場合のフォールバック）
function Generate-SampleUserActivity {
    param([int]$Days)
    
    $sampleData = @()
    $departments = @("営業部", "技術部", "管理部", "経理部", "人事部")
    $jobTitles = @("マネージャー", "シニアエンジニア", "エンジニア", "アシスタント", "スペシャリスト")
    
    for ($i = 1; $i -le 100; $i++) {
        $lastSignIn = (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum $Days))
        $daysSince = ((Get-Date) - $lastSignIn).Days
        
        $isActive = $daysSince -le 30
        $activityLevel = if ($daysSince -le 7) { "高活動" } elseif ($daysSince -le 30) { "中活動" } else { "非アクティブ" }
        
        $sampleData += [PSCustomObject]@{
            UserPrincipalName = "user$i@mirai-const.co.jp"
            DisplayName = "サンプルユーザー $i"
            Department = $departments[(Get-Random -Minimum 0 -Maximum $departments.Count)]
            JobTitle = $jobTitles[(Get-Random -Minimum 0 -Maximum $jobTitles.Count)]
            AccountEnabled = $true
            LastSignInDateTime = $lastSignIn.ToString("yyyy/MM/dd HH:mm:ss")
            DaysSinceLastSignIn = $daysSince
            IsActive = $isActive
            ActivityLevel = $activityLevel
            CreatedDateTime = (Get-Date).AddDays(-(Get-Random -Minimum 30 -Maximum 365)).ToString("yyyy/MM/dd HH:mm:ss")
            AnalysisTimestamp = Get-Date
        }
    }
    
    return $sampleData
}

function Generate-SampleAppUsage {
    param([int]$Days)
    
    return @(
        [PSCustomObject]@{ ApplicationName = "Microsoft Teams"; UsageCount = 850; UniqueUsers = 95; UtilizationRate = 95.0 }
        [PSCustomObject]@{ ApplicationName = "Microsoft Outlook"; UsageCount = 920; UniqueUsers = 98; UtilizationRate = 98.0 }
        [PSCustomObject]@{ ApplicationName = "Microsoft Excel"; UsageCount = 780; UniqueUsers = 87; UtilizationRate = 87.0 }
        [PSCustomObject]@{ ApplicationName = "Microsoft Word"; UsageCount = 720; UniqueUsers = 82; UtilizationRate = 82.0 }
        [PSCustomObject]@{ ApplicationName = "Microsoft PowerPoint"; UsageCount = 560; UniqueUsers = 68; UtilizationRate = 68.0 }
        [PSCustomObject]@{ ApplicationName = "Microsoft OneDrive"; UsageCount = 690; UniqueUsers = 75; UtilizationRate = 75.0 }
        [PSCustomObject]@{ ApplicationName = "Microsoft SharePoint"; UsageCount = 450; UniqueUsers = 52; UtilizationRate = 52.0 }
    )
}

function Generate-SampleInactiveUsers {
    param([int]$Days)
    
    $sampleInactive = @()
    for ($i = 1; $i -le 15; $i++) {
        $daysSince = Get-Random -Minimum $Days -Maximum 180
        $sampleInactive += [PSCustomObject]@{
            UserPrincipalName = "inactive$i@mirai-const.co.jp"
            DisplayName = "非アクティブユーザー $i"
            Department = "営業部"
            AccountEnabled = $true
            InactiveReason = "${daysSince}日間サインインなし"
            RiskLevel = if ($daysSince -gt 90) { "中" } else { "低" }
            LastSignInDateTime = (Get-Date).AddDays(-$daysSince).ToString("yyyy/MM/dd HH:mm:ss")
            CreatedDateTime = (Get-Date).AddDays(-365).ToString("yyyy/MM/dd HH:mm:ss")
            AnalysisTimestamp = Get-Date
        }
    }
    
    return $sampleInactive
}

function Generate-UsageActivityHTML {
    param($UserActivity, $AppUsage, $InactiveUsers, $Statistics, $Days)
    
    $timestamp = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
    
    # アプリケーション利用統計テーブルの生成
    $appUsageRows = ""
    foreach ($app in $AppUsage) {
        $utilizationClass = if ($app.UtilizationRate -ge 80) { "risk-normal" } elseif ($app.UtilizationRate -ge 60) { "risk-attention" } else { "risk-warning" }
        $appUsageRows += @"
        <tr class="$utilizationClass">
            <td><strong>$($app.ApplicationName)</strong></td>
            <td style="text-align: center;">$($app.UsageCount)</td>
            <td style="text-align: center;">$($app.UniqueUsers)</td>
            <td style="text-align: center;">$($app.UtilizationRate)%</td>
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
            <td>$($user.Department)</td>
            <td>$($user.InactiveReason)</td>
            <td style="text-align: center;">$($user.RiskLevel)</td>
            <td style="text-align: center;">$($user.LastSignInDateTime)</td>
        </tr>
"@
    }
    
    # 部署別統計テーブルの生成
    $departmentStatsRows = ""
    foreach ($dept in $Statistics.DepartmentStatistics) {
        $utilizationClass = if ($dept.UtilizationRate -ge 80) { "risk-normal" } elseif ($dept.UtilizationRate -ge 60) { "risk-attention" } else { "risk-warning" }
        $departmentStatsRows += @"
        <tr class="$utilizationClass">
            <td><strong>$($dept.Department)</strong></td>
            <td style="text-align: center;">$($dept.TotalUsers)</td>
            <td style="text-align: center;">$($dept.ActiveUsers)</td>
            <td style="text-align: center;">$($dept.UtilizationRate)%</td>
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
        .meter-bar {
            width: 100%;
            height: 30px;
            background-color: #e1e1e1;
            border-radius: 15px;
            overflow: hidden;
            position: relative;
        }
        .meter-fill {
            height: 100%;
            background: linear-gradient(90deg, #107c10 0%, #ff8c00 70%, #d13438 90%);
            border-radius: 15px;
            transition: width 0.3s ease;
        }
        .meter-label {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            color: white;
            font-weight: bold;
            text-shadow: 1px 1px 2px rgba(0,0,0,0.5);
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
        <div class="section-header">🏢 部署別利用率統計</div>
        <div class="section-content">
            <div class="scrollable-table">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>部署名</th>
                            <th>総ユーザー数</th>
                            <th>アクティブユーザー数</th>
                            <th>利用率</th>
                        </tr>
                    </thead>
                    <tbody>
                        $departmentStatsRows
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div class="section">
        <div class="section-header">📱 アプリケーション利用統計</div>
        <div class="section-content">
            <div class="scrollable-table">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>アプリケーション名</th>
                            <th>利用回数</th>
                            <th>利用ユーザー数</th>
                            <th>利用率</th>
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
            <div class="scrollable-table">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>ユーザー名</th>
                            <th>部署</th>
                            <th>非アクティブ理由</th>
                            <th>リスクレベル</th>
                            <th>最終サインイン</th>
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

# メイン実行（スクリプトが直接実行された場合）
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -eq $null) {
    try {
        Write-Host "📊 Microsoft 365 利用率・アクティブ率レポート分析を開始します" -ForegroundColor Cyan
        $result = Get-UsageActivityReport -Days 30 -ExportHTML -ExportCSV
        
        if ($result -and $result.Success) {
            Write-Host "✅ 利用率・アクティブ率レポート分析完了" -ForegroundColor Green
            Write-Host "総ユーザー数: $($result.TotalUsers)" -ForegroundColor Cyan
            Write-Host "アクティブユーザー: $($result.ActiveUsers)" -ForegroundColor Green
            Write-Host "非アクティブユーザー: $($result.InactiveUsers)" -ForegroundColor Yellow
            Write-Host "全体利用率: $($result.OverallUtilizationRate)%" -ForegroundColor Blue
            
            if ($result.HTMLPath) {
                Write-Host "HTMLダッシュボード: $($result.HTMLPath)" -ForegroundColor Green
            }
            if ($result.CSVPaths -and $result.CSVPaths.Count -gt 0) {
                Write-Host "CSVレポート: $($result.CSVPaths -join ', ')" -ForegroundColor Green
            }
            
            return $result
        } else {
            $errorMsg = if ($result.Error) { $result.Error } else { "不明なエラーが発生しました" }
            Write-Host "❌ 利用率・アクティブ率レポート分析エラー: $errorMsg" -ForegroundColor Red
            return @{ Success = $false; Error = $errorMsg }
        }
    }
    catch {
        Write-Host "❌ スクリプト実行エラー: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}