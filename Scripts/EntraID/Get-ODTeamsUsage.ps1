# ================================================================================
# Get-ODTeamsUsage.ps1
# OneDrive容量・Teams利用状況確認
# ================================================================================

[CmdletBinding()]
param()

# 共通モジュールのインポート
$CommonPath = Join-Path $PSScriptRoot "..\Common"
Import-Module "$CommonPath\Logging.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$CommonPath\ErrorHandling.psm1" -Force -ErrorAction SilentlyContinue

function Generate-SampleOneDriveTeamsData {
    <#
    .SYNOPSIS
    OneDrive・Teams使用状況のサンプルデータ生成
    #>
    
    $sampleUsers = @(
        @{Name="荒木 厚史"; Email="a-araki@mirai-const.co.jp"; Dept="営業部"},
        @{Name="深澤 淳"; Email="a-fukazawa@mirai-const.co.jp"; Dept="技術部"},
        @{Name="蛭川 愛志"; Email="a-hirukawa@mirai-const.co.jp"; Dept="管理部"},
        @{Name="池田 彩夏"; Email="a-ikeda@mirai-const.co.jp"; Dept="営業部"},
        @{Name="加治屋 茜"; Email="a-kajiya@mirai-const.co.jp"; Dept="企画部"}
    )
    
    $data = @{
        OneDriveUsage = @()
        TeamsActivity = @()
        Summary = @{}
    }
    
    # OneDrive使用状況サンプル
    foreach ($user in $sampleUsers) {
        $usageGB = [math]::Round((Get-Random -Minimum 500 -Maximum 4500) / 1000, 2)
        $quotaGB = if ((Get-Random -Minimum 1 -Maximum 10) -le 2) { 5 } else { 1 }
        $usagePercent = [math]::Round(($usageGB / $quotaGB) * 100, 1)
        
        $data.OneDriveUsage += [PSCustomObject]@{
            DisplayName = $user.Name
            UserPrincipalName = $user.Email
            Department = $user.Dept
            StorageUsedGB = $usageGB
            StorageQuotaGB = $quotaGB
            UsagePercent = $usagePercent
            FileCount = Get-Random -Minimum 200 -Maximum 2000
            ShareCount = Get-Random -Minimum 0 -Maximum 50
            LastActivityDate = (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 30))
            Status = if ($usagePercent -ge 80) { "警告" } elseif ($usagePercent -ge 60) { "注意" } else { "正常" }
        }
    }
    
    # Teams活動サンプル
    foreach ($user in $sampleUsers) {
        $data.TeamsActivity += [PSCustomObject]@{
            DisplayName = $user.Name
            UserPrincipalName = $user.Email
            Department = $user.Dept
            TeamsMessageCount = Get-Random -Minimum 10 -Maximum 200
            CallCount = Get-Random -Minimum 0 -Maximum 50
            MeetingCount = Get-Random -Minimum 0 -Maximum 30
            LastActivityDate = (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 7))
            IsActive = (Get-Random -Minimum 1 -Maximum 10) -le 8
        }
    }
    
    # サマリー情報
    $data.Summary = @{
        TotalUsers = $sampleUsers.Count
        OneDriveHighUsage = ($data.OneDriveUsage | Where-Object {$_.UsagePercent -ge 80}).Count
        OneDriveWarning = ($data.OneDriveUsage | Where-Object {$_.UsagePercent -ge 60 -and $_.UsagePercent -lt 80}).Count
        TeamsActiveUsers = ($data.TeamsActivity | Where-Object {$_.IsActive}).Count
        AverageStorageUsage = [math]::Round(($data.OneDriveUsage | Measure-Object StorageUsedGB -Average).Average, 2)
    }
    
    return $data
}

function Display-OneDriveTeamsReport {
    param(
        [Parameter(Mandatory = $true)]
        $Data,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsSample = $false
    )
    
    if ($IsSample) {
        Write-Host "📊 テストデータを使用したレポート" -ForegroundColor Yellow
        Write-Host ""
    }
    
    # OneDrive使用状況サマリー
    Write-Host "💾 OneDrive使用状況サマリー" -ForegroundColor Cyan
    Write-Host "  総ユーザー数: $($Data.Summary.TotalUsers)" -ForegroundColor White
    Write-Host "  平均使用量: $($Data.Summary.AverageStorageUsage) GB" -ForegroundColor White
    Write-Host "  ⚠️  警告レベル(80%以上): $($Data.Summary.OneDriveHighUsage) ユーザー" -ForegroundColor Yellow
    Write-Host "  📋 注意レベル(60-79%): $($Data.Summary.OneDriveWarning) ユーザー" -ForegroundColor White
    Write-Host ""
    
    # OneDrive使用率上位
    Write-Host "📈 OneDrive使用率上位ユーザー" -ForegroundColor Cyan
    $topUsers = $Data.OneDriveUsage | Sort-Object UsagePercent -Descending | Select-Object -First 5
    foreach ($user in $topUsers) {
        $statusColor = switch ($user.Status) {
            "警告" { "Red" }
            "注意" { "Yellow" }
            default { "Green" }
        }
        Write-Host "  $($user.DisplayName)" -ForegroundColor White
        Write-Host "    💾 $($user.StorageUsedGB)GB / $($user.StorageQuotaGB)GB ($($user.UsagePercent)%)" -ForegroundColor $statusColor
        Write-Host "    📁 ファイル数: $($user.FileCount), 共有数: $($user.ShareCount)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Teams活動サマリー
    Write-Host "👥 Teams活動サマリー" -ForegroundColor Cyan
    Write-Host "  アクティブユーザー: $($Data.Summary.TeamsActiveUsers) / $($Data.Summary.TotalUsers)" -ForegroundColor White
    
    $activeUsers = $Data.TeamsActivity | Where-Object {$_.IsActive} | Sort-Object TeamsMessageCount -Descending | Select-Object -First 3
    Write-Host "  📱 活発なユーザー:" -ForegroundColor White
    foreach ($user in $activeUsers) {
        Write-Host "    - $($user.DisplayName): メッセージ$($user.TeamsMessageCount)件, 通話$($user.CallCount)件, 会議$($user.MeetingCount)件" -ForegroundColor Gray
    }
    Write-Host ""
}

function Get-OneDriveTeamsUsageStats {
    <#
    .SYNOPSIS
    OneDrive容量とTeams利用状況の確認
    
    .DESCRIPTION
    Microsoft Graph APIを使用してOneDriveの容量使用状況と
    Teamsの利用統計を取得・分析します
    
    .EXAMPLE
    Get-OneDriveTeamsUsageStats
    #>
    
    Write-Host "☁️ OneDrive & Teams 利用状況確認" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Microsoft Graph接続確認
        Write-Host "📡 Microsoft Graph API 接続確認中..." -ForegroundColor Yellow
        
        try {
            $context = Get-MgContext -ErrorAction SilentlyContinue
            if (-not $context) {
                Write-Host "⚠️  Microsoft Graph未接続 - ダミーデータで処理を継続します" -ForegroundColor Yellow
                Write-Host "   テストデータを生成しています..." -ForegroundColor Gray
                
                # ダミーデータ生成と表示
                $sampleData = Generate-SampleOneDriveTeamsData
                Display-OneDriveTeamsReport -Data $sampleData -IsSample $true
                return
            }
            
            Write-Host "✅ Microsoft Graph接続確認完了" -ForegroundColor Green
            Write-Host "   テナント: $($context.TenantId)" -ForegroundColor Gray
            Write-Host ""
        }
        catch {
            Write-Host "❌ Microsoft Graph接続エラー - ダミーデータで処理を継続します" -ForegroundColor Yellow
            Write-Host "   エラー詳細: $($_.Exception.Message)" -ForegroundColor Gray
            
            # ダミーデータ生成と表示
            $sampleData = Generate-SampleOneDriveTeamsData
            Display-OneDriveTeamsReport -Data $sampleData -IsSample $true
            return
        }
        
        # OneDrive使用状況の取得
        Write-Host "💾 OneDrive 使用状況を確認中..." -ForegroundColor Yellow
        
        try {
            # OneDrive使用状況レポート（過去30日）
            $oneDriveReport = Get-MgReportOneDriveUsageAccountDetail -Period D30 | ConvertFrom-Csv
            
            if ($oneDriveReport) {
                Write-Host "📊 OneDrive統計 (過去30日間):" -ForegroundColor Cyan
                
                $totalSites = $oneDriveReport.Count
                $activeSites = ($oneDriveReport | Where-Object {$_.IsDeleted -eq "False" -and [int64]$_.StorageUsedInBytes -gt 0}).Count
                $totalStorageGB = [math]::Round(($oneDriveReport | Measure-Object -Property {[int64]$_.StorageUsedInBytes} -Sum).Sum / 1GB, 2)
                $totalAllocatedGB = [math]::Round(($oneDriveReport | Measure-Object -Property {[int64]$_.StorageAllocatedInBytes} -Sum).Sum / 1GB, 2)
                
                Write-Host "   📁 総OneDriveサイト数: $totalSites" -ForegroundColor White
                Write-Host "   ✅ アクティブサイト数: $activeSites" -ForegroundColor Green
                Write-Host "   💾 総使用容量: $totalStorageGB GB" -ForegroundColor White
                Write-Host "   📏 総割り当て容量: $totalAllocatedGB GB" -ForegroundColor White
                
                if ($totalAllocatedGB -gt 0) {
                    $usagePercentage = [math]::Round(($totalStorageGB / $totalAllocatedGB) * 100, 1)
                    Write-Host "   📈 使用率: $usagePercentage%" -ForegroundColor $(if ($usagePercentage -gt 80) { "Red" } elseif ($usagePercentage -gt 60) { "Yellow" } else { "Green" })
                }
                
                # 容量上位ユーザー
                $topUsers = $oneDriveReport | 
                    Where-Object {[int64]$_.StorageUsedInBytes -gt 0} |
                    Sort-Object {[int64]$_.StorageUsedInBytes} -Descending |
                    Select-Object -First 10
                
                if ($topUsers) {
                    Write-Host ""
                    Write-Host "📈 OneDrive容量使用量上位ユーザー:" -ForegroundColor Cyan
                    
                    foreach ($user in $topUsers) {
                        $userStorageGB = [math]::Round([int64]$user.StorageUsedInBytes / 1GB, 2)
                        $userAllocatedGB = [math]::Round([int64]$user.StorageAllocatedInBytes / 1GB, 2)
                        $userUsagePercentage = if ($userAllocatedGB -gt 0) { [math]::Round(($userStorageGB / $userAllocatedGB) * 100, 1) } else { 0 }
                        
                        $statusColor = if ($userUsagePercentage -gt 90) { "Red" } elseif ($userUsagePercentage -gt 75) { "Yellow" } else { "Green" }
                        
                        Write-Host "   👤 $($user.UserPrincipalName)" -ForegroundColor White
                        Write-Host "     💾 使用量: $userStorageGB GB / $userAllocatedGB GB ($userUsagePercentage%)" -ForegroundColor $statusColor
                        Write-Host "     📅 最終活動: $($user.LastActivityDate)" -ForegroundColor Gray
                    }
                }
                
                Write-Host ""
            }
            else {
                Write-Host "   ℹ️  OneDrive使用状況データが取得できませんでした" -ForegroundColor Blue
                Write-Host ""
            }
        }
        catch {
            Write-Host "❌ OneDrive使用状況取得エラー: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
        }
        
        # Teams使用状況の取得
        Write-Host "👥 Teams 利用状況を確認中..." -ForegroundColor Yellow
        
        try {
            # Teams使用状況レポート（過去30日）
            $teamsReport = Get-MgReportTeamsUserActivityUserDetail -Period D30 | ConvertFrom-Csv
            
            if ($teamsReport) {
                Write-Host "📊 Teams統計 (過去30日間):" -ForegroundColor Cyan
                
                $totalUsers = $teamsReport.Count
                $activeUsers = ($teamsReport | Where-Object {$_.LastActivityDate -ne ""}).Count
                $totalMessages = ($teamsReport | Measure-Object -Property {if ($_.TeamChatMessageCount -ne "") {[int]$_.TeamChatMessageCount} else {0}} -Sum).Sum
                $totalPrivateMessages = ($teamsReport | Measure-Object -Property {if ($_.PrivateChatMessageCount -ne "") {[int]$_.PrivateChatMessageCount} else {0}} -Sum).Sum
                $totalCalls = ($teamsReport | Measure-Object -Property {if ($_.CallCount -ne "") {[int]$_.CallCount} else {0}} -Sum).Sum
                $totalMeetings = ($teamsReport | Measure-Object -Property {if ($_.MeetingCount -ne "") {[int]$_.MeetingCount} else {0}} -Sum).Sum
                
                Write-Host "   👥 総ユーザー数: $totalUsers" -ForegroundColor White
                Write-Host "   ✅ アクティブユーザー数: $activeUsers" -ForegroundColor Green
                Write-Host "   💬 チームチャットメッセージ数: $totalMessages" -ForegroundColor White
                Write-Host "   🔒 プライベートチャット数: $totalPrivateMessages" -ForegroundColor White
                Write-Host "   📞 通話数: $totalCalls" -ForegroundColor White
                Write-Host "   📅 会議数: $totalMeetings" -ForegroundColor White
                
                if ($totalUsers -gt 0) {
                    $activeUserPercentage = [math]::Round(($activeUsers / $totalUsers) * 100, 1)
                    Write-Host "   📈 アクティブ率: $activeUserPercentage%" -ForegroundColor $(if ($activeUserPercentage -gt 70) { "Green" } elseif ($activeUserPercentage -gt 40) { "Yellow" } else { "Red" })
                }
                
                # アクティブユーザー上位
                $topTeamsUsers = $teamsReport | 
                    Where-Object {$_.LastActivityDate -ne ""} |
                    Sort-Object {
                        $chatCount = if ($_.TeamChatMessageCount -ne "") {[int]$_.TeamChatMessageCount} else {0}
                        $privateCount = if ($_.PrivateChatMessageCount -ne "") {[int]$_.PrivateChatMessageCount} else {0}
                        $chatCount + $privateCount
                    } -Descending |
                    Select-Object -First 10
                
                if ($topTeamsUsers) {
                    Write-Host ""
                    Write-Host "📈 Teams活動量上位ユーザー:" -ForegroundColor Cyan
                    
                    foreach ($user in $topTeamsUsers) {
                        $userChatCount = if ($user.TeamChatMessageCount -ne "") {[int]$user.TeamChatMessageCount} else {0}
                        $userPrivateCount = if ($user.PrivateChatMessageCount -ne "") {[int]$user.PrivateChatMessageCount} else {0}
                        $userCallCount = if ($user.CallCount -ne "") {[int]$user.CallCount} else {0}
                        $userMeetingCount = if ($user.MeetingCount -ne "") {[int]$user.MeetingCount} else {0}
                        
                        Write-Host "   👤 $($user.UserPrincipalName)" -ForegroundColor White
                        Write-Host "     💬 チャット: $userChatCount | 🔒 プライベート: $userPrivateCount" -ForegroundColor Gray
                        Write-Host "     📞 通話: $userCallCount | 📅 会議: $userMeetingCount" -ForegroundColor Gray
                        Write-Host "     📅 最終活動: $($user.LastActivityDate)" -ForegroundColor Gray
                    }
                }
                
                Write-Host ""
            }
            else {
                Write-Host "   ℹ️  Teams使用状況データが取得できませんでした" -ForegroundColor Blue
                Write-Host ""
            }
        }
        catch {
            Write-Host "❌ Teams使用状況取得エラー: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
        }
        
        # デバイス使用状況の取得
        Write-Host "📱 Teams デバイス使用状況を確認中..." -ForegroundColor Yellow
        
        try {
            $teamsDeviceReport = Get-MgReportTeamsDeviceUsageUserDetail -Period D30 | ConvertFrom-Csv
            
            if ($teamsDeviceReport) {
                $webUsers = ($teamsDeviceReport | Where-Object {$_.UsedWeb -eq "Yes"}).Count
                $windowsUsers = ($teamsDeviceReport | Where-Object {$_.UsedWindows -eq "Yes"}).Count
                $macUsers = ($teamsDeviceReport | Where-Object {$_.UsedMac -eq "Yes"}).Count
                $mobileUsers = ($teamsDeviceReport | Where-Object {$_.UsedMobile -eq "Yes"}).Count
                
                Write-Host "📊 デバイス使用統計:" -ForegroundColor Cyan
                Write-Host "   🌐 Web版利用者: $webUsers 人" -ForegroundColor White
                Write-Host "   🖥️ Windows版利用者: $windowsUsers 人" -ForegroundColor White
                Write-Host "   🍎 Mac版利用者: $macUsers 人" -ForegroundColor White
                Write-Host "   📱 モバイル版利用者: $mobileUsers 人" -ForegroundColor White
                Write-Host ""
            }
        }
        catch {
            Write-Host "❌ デバイス使用状況取得エラー: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
        }
        
        # 推奨アクション
        Write-Host "💡 推奨アクション:" -ForegroundColor Cyan
        Write-Host "   1. OneDrive容量が90%を超えるユーザーには容量削減指導" -ForegroundColor White
        Write-Host "   2. Teams未利用ユーザーに対する利用促進・トレーニング" -ForegroundColor White
        Write-Host "   3. 高使用量ユーザーのベストプラクティス共有" -ForegroundColor White
        Write-Host "   4. 定期的な利用状況モニタリングの実施" -ForegroundColor White
        Write-Host ""
        
        # レポート生成
        $reportData = [PSCustomObject]@{
            ReportDate = Get-Date
            OneDriveTotalSites = if ($oneDriveReport) { $oneDriveReport.Count } else { 0 }
            OneDriveActiveSites = if ($oneDriveReport) { ($oneDriveReport | Where-Object {$_.IsDeleted -eq "False" -and [int64]$_.StorageUsedInBytes -gt 0}).Count } else { 0 }
            OneDriveTotalStorageGB = if ($oneDriveReport) { [math]::Round(($oneDriveReport | Measure-Object -Property {[int64]$_.StorageUsedInBytes} -Sum).Sum / 1GB, 2) } else { 0 }
            TeamsTotalUsers = if ($teamsReport) { $teamsReport.Count } else { 0 }
            TeamsActiveUsers = if ($teamsReport) { ($teamsReport | Where-Object {$_.LastActivityDate -ne ""}).Count } else { 0 }
            TeamsTotalMessages = if ($teamsReport) { ($teamsReport | Measure-Object -Property {if ($_.TeamChatMessageCount -ne "") {[int]$_.TeamChatMessageCount} else {0}} -Sum).Sum } else { 0 }
            TeamsTotalCalls = if ($teamsReport) { ($teamsReport | Measure-Object -Property {if ($_.CallCount -ne "") {[int]$_.CallCount} else {0}} -Sum).Sum } else { 0 }
            TeamsTotalMeetings = if ($teamsReport) { ($teamsReport | Measure-Object -Property {if ($_.MeetingCount -ne "") {[int]$_.MeetingCount} else {0}} -Sum).Sum } else { 0 }
        }
        
        # CSV・HTMLレポート生成
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $reportBaseName = "OneDrive_Teams_Usage_$timestamp"
        $csvPath = "Reports\Daily\$reportBaseName.csv"
        $htmlPath = "Reports\Daily\$reportBaseName.html"
        
        $reportDir = Split-Path $csvPath -Parent
        if (-not (Test-Path $reportDir)) {
            New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
        }
        
        # CSV出力
        $reportData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "📊 CSVレポートを出力しました: $csvPath" -ForegroundColor Green
        
        # HTMLレポート生成
        $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OneDrive & Teams 利用状況レポート</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 1400px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; padding-bottom: 20px; border-bottom: 3px solid #0078d4; }
        .header h1 { color: #0078d4; margin: 0; font-size: 28px; }
        .header .subtitle { color: #666; margin: 10px 0 0 0; font-size: 16px; }
        .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .status-card { padding: 20px; border-radius: 8px; text-align: center; }
        .status-success { background: linear-gradient(135deg, #4CAF50, #45a049); color: white; }
        .status-warning { background: linear-gradient(135deg, #ff9800, #f57c00); color: white; }
        .status-info { background: linear-gradient(135deg, #2196F3, #1976D2); color: white; }
        .status-purple { background: linear-gradient(135deg, #9C27B0, #7B1FA2); color: white; }
        .status-card h3 { margin: 0 0 10px 0; font-size: 16px; }
        .status-card .value { font-size: 24px; font-weight: bold; margin: 10px 0; }
        .details-section { margin: 30px 0; }
        .details-title { font-size: 20px; color: #0078d4; margin-bottom: 15px; padding-bottom: 5px; border-bottom: 2px solid #e0e0e0; }
        .details-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 30px; margin: 20px 0; }
        .details-card { background: #f8f9fa; padding: 20px; border-radius: 8px; }
        .details-card h4 { color: #0078d4; margin: 0 0 15px 0; }
        .stats-list { list-style: none; padding: 0; }
        .stats-list li { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #e0e0e0; }
        .stats-list li:last-child { border-bottom: none; }
        .timestamp { text-align: center; color: #666; font-size: 14px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e0e0e0; }
        .icon { font-size: 2em; margin-bottom: 10px; }
        .recommendations { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
        @media (max-width: 768px) { .details-grid { grid-template-columns: 1fr; } }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>☁️ OneDrive & Teams 利用状況レポート</h1>
            <div class="subtitle">Microsoft 365統合管理ツール - ITSM/ISO27001/27002準拠</div>
        </div>
        
        <div class="status-grid">
            <div class="status-card status-info">
                <div class="icon">💾</div>
                <h3>OneDrive サイト数</h3>
                <div class="value">$($reportData.OneDriveTotalSites)</div>
            </div>
            
            <div class="status-card status-success">
                <div class="icon">✅</div>
                <h3>アクティブサイト</h3>
                <div class="value">$($reportData.OneDriveActiveSites)</div>
            </div>
            
            <div class="status-card status-warning">
                <div class="icon">📦</div>
                <h3>使用容量</h3>
                <div class="value">$($reportData.OneDriveTotalStorageGB) GB</div>
            </div>
            
            <div class="status-card status-purple">
                <div class="icon">👥</div>
                <h3>Teams ユーザー数</h3>
                <div class="value">$($reportData.TeamsTotalUsers)</div>
            </div>
            
            <div class="status-card status-success">
                <div class="icon">🎯</div>
                <h3>Teams アクティブ</h3>
                <div class="value">$($reportData.TeamsActiveUsers)</div>
            </div>
        </div>
        
        <div class="details-grid">
            <div class="details-card">
                <h4>💾 OneDrive 統計</h4>
                <ul class="stats-list">
                    <li><span>📁 総サイト数</span><span>$($reportData.OneDriveTotalSites)</span></li>
                    <li><span>✅ アクティブサイト</span><span>$($reportData.OneDriveActiveSites)</span></li>
                    <li><span>📦 総使用容量</span><span>$($reportData.OneDriveTotalStorageGB) GB</span></li>
                    <li><span>📊 利用率</span><span>$(if ($reportData.OneDriveTotalSites -gt 0) { [math]::Round(($reportData.OneDriveActiveSites / $reportData.OneDriveTotalSites) * 100, 1) } else { 0 })%</span></li>
                </ul>
            </div>
            
            <div class="details-card">
                <h4>👥 Teams 統計</h4>
                <ul class="stats-list">
                    <li><span>👥 総ユーザー数</span><span>$($reportData.TeamsTotalUsers)</span></li>
                    <li><span>🎯 アクティブユーザー</span><span>$($reportData.TeamsActiveUsers)</span></li>
                    <li><span>💬 総メッセージ数</span><span>$($reportData.TeamsTotalMessages)</span></li>
                    <li><span>📞 総通話数</span><span>$($reportData.TeamsTotalCalls)</span></li>
                    <li><span>📅 総会議数</span><span>$($reportData.TeamsTotalMeetings)</span></li>
                    <li><span>📊 アクティブ率</span><span>$(if ($reportData.TeamsTotalUsers -gt 0) { [math]::Round(($reportData.TeamsActiveUsers / $reportData.TeamsTotalUsers) * 100, 1) } else { 0 })%</span></li>
                </ul>
            </div>
        </div>
        
        <div class="recommendations">
            <div class="details-title">💡 推奨アクション</div>
            <ul style="line-height: 1.8;">
                <li>💾 <strong>OneDrive容量が90%を超えるユーザーには容量削減指導</strong></li>
                <li>👥 <strong>Teams未利用ユーザーに対する利用促進・トレーニング</strong></li>
                <li>📚 <strong>高使用量ユーザーのベストプラクティス共有</strong></li>
                <li>📊 <strong>定期的な利用状況モニタリングの実施</strong></li>
            </ul>
        </div>
        
        <div class="timestamp">
            📅 レポート生成日時: $($reportData.ReportDate.ToString('yyyy年MM月dd日 HH:mm:ss'))<br>
            🤖 Microsoft 365統合管理ツール v2.0 | ITSM/ISO27001/27002準拠
        </div>
    </div>
</body>
</html>
"@
        
        $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
        Write-Host "📊 HTMLレポートを出力しました: $htmlPath" -ForegroundColor Green
        
    }
    catch {
        Write-Host "❌ 予期しないエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "スタックトレース: $($_.ScriptStackTrace)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "☁️ OneDrive & Teams 利用状況確認が完了しました" -ForegroundColor Green
}

# メイン実行
if ($MyInvocation.InvocationName -ne '.') {
    Get-OneDriveTeamsUsageStats
}