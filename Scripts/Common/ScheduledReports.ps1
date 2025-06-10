# ================================================================================
# ScheduledReports.ps1
# 定期レポート実行スクリプト（日次/週次/月次/年次）
# ITSM/ISO27001/27002準拠
# ================================================================================

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Daily", "Weekly", "Monthly", "Yearly")]
    [string]$ReportType
)

Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\ErrorHandling.psm1" -Force
Import-Module "$PSScriptRoot\Common.psm1" -Force
Import-Module "$PSScriptRoot\ReportGenerator.psm1" -Force

function Invoke-DailyReports {
    Write-Log "日次レポートを開始します" -Level "Info"
    
    $results = @{}
    
    try {
        # AD ログイン履歴
        . "$PSScriptRoot\..\AD\UserManagement.ps1"
        $results.ADLoginHistory = Get-ADLoginHistory
        
        # Exchange Online 容量監視
        . "$PSScriptRoot\..\EXO\MailboxManagement.ps1"
        $results.EXOCapacity = Get-EXOMailboxCapacityReport
        $results.EXOAttachment = Get-EXOAttachmentAnalysis
        
        # Exchange Online 配送レポート
        . "$PSScriptRoot\..\EXO\SecurityAnalysis.ps1"
        $results.EXODelivery = Get-EXOMailDeliveryReport
        
        # Entra ID サインイン分析
        . "$PSScriptRoot\..\EntraID\UserSecurityManagement.ps1"
        $results.EntraIDSignIn = Get-EntraIDSignInAnalysis
        
        # 日次HTMLレポート生成
        $reportSections = @()
        
        # ADログイン履歴セクション
        if ($results.ADLoginHistory) {
            $adSummary = New-SummaryStatistics -Data $results.ADLoginHistory -CountFields @{
                "総ログイン試行" = @{ Type = "Count"; Risk = "低" }
                "失敗ログイン" = @{ Type = "Count"; Filter = {$_.Result -eq "失敗"}; Risk = "中" }
                "成功ログイン" = @{ Type = "Count"; Filter = {$_.Result -eq "成功"}; Risk = "低" }
            }
            
            $alerts = @()
            $failedLogins = ($results.ADLoginHistory | Where-Object { $_.Result -eq "失敗" }).Count
            if ($failedLogins -gt 10) {
                $alerts += @{ Type = "Warning"; Message = "ログイン失敗が$failedLogins件発生しています。セキュリティ確認を推奨します。" }
            }
            
            $reportSections += @{
                Title = "Active Directory ログイン履歴"
                Summary = $adSummary
                Alerts = $alerts
                Data = $results.ADLoginHistory | Select-Object -First 50
            }
        }
        
        # Exchange Online容量監視セクション
        if ($results.EXOCapacity) {
            $exoSummary = New-SummaryStatistics -Data $results.EXOCapacity -CountFields @{
                "総メールボックス数" = @{ Type = "Count"; Risk = "低" }
                "容量警告" = @{ Type = "Count"; Filter = {$_.Status -eq "警告"}; Risk = "高" }
            }
            
            $alerts = @()
            $warningCount = ($results.EXOCapacity | Where-Object { $_.Status -eq "警告" }).Count
            if ($warningCount -gt 0) {
                $alerts += @{ Type = "Danger"; Message = "$warningCount件のメールボックスが容量警告レベルに達しています。" }
            }
            
            $reportSections += @{
                Title = "Exchange Online メールボックス容量監視"
                Summary = $exoSummary
                Alerts = $alerts
                Data = $results.EXOCapacity | Where-Object { $_.Status -eq "警告" } | Select-Object -First 20
            }
        }
        
        # Entra IDサインイン分析セクション
        if ($results.EntraIDSignIn -and $results.EntraIDSignIn.AllSignIns) {
            $signInSummary = New-SummaryStatistics -Data $results.EntraIDSignIn.AllSignIns -CountFields @{
                "総サインイン数" = @{ Type = "Count"; Risk = "低" }
                "失敗サインイン" = @{ Type = "Count"; Filter = {$_.Status -ne 0}; Risk = "中" }
                "リスクサインイン" = @{ Type = "Count"; Filter = {$_.RiskLevel -in @("medium", "high")}; Risk = "高" }
            }
            
            $reportSections += @{
                Title = "Entra ID サインイン分析"
                Summary = $signInSummary
                Data = $results.EntraIDSignIn.FailedSignIns | Select-Object -First 30
            }
        }
        
        # HTMLレポート生成
        $reportPath = Join-Path (New-ReportDirectory -ReportType "Daily") "DailyReport_$(Get-Date -Format 'yyyyMMdd').html"
        New-HTMLReport -Title "日次運用レポート" -DataSections $reportSections -OutputPath $reportPath
        
        Write-AuditLog -Action "日次レポート実行" -Target "全システム" -Result "成功" -Details "レポート生成: $reportPath"
        
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        Send-ErrorNotification -ErrorDetails $errorDetails
        Write-Log "日次レポート実行エラー: $($_.Exception.Message)" -Level "Error"
    }
}

function Invoke-WeeklyReports {
    Write-Log "週次レポートを開始します" -Level "Info"
    
    $results = @{}
    
    try {
        # AD 非アクティブユーザー・パスワード期限
        . "$PSScriptRoot\..\AD\UserManagement.ps1"
        $results.ADInactiveUsers = Get-ADInactiveUsers
        $results.ADPasswordExpiry = Get-ADPasswordExpiryReport
        $results.ADUserChanges = Get-ADUserAttributeChanges
        
        # Exchange Online 転送ルール・スパム分析
        . "$PSScriptRoot\..\EXO\MailboxManagement.ps1"
        $results.EXOForwarding = Get-EXOForwardingRules
        
        . "$PSScriptRoot\..\EXO\SecurityAnalysis.ps1"
        $results.EXOSpamPhishing = Get-EXOSpamPhishingAnalysis
        
        # Entra ID MFA状況
        . "$PSScriptRoot\..\EntraID\UserSecurityManagement.ps1"
        $results.EntraIDMFA = Get-EntraIDMFAStatus
        
        # OneDrive 外部共有
        . "$PSScriptRoot\..\EntraID\TeamsOneDriveManagement.ps1"
        $results.OneDriveSharing = Get-OneDriveSharingReport
        
        # 週次HTMLレポート生成
        $reportSections = @()
        
        # AD非アクティブユーザーセクション
        if ($results.ADInactiveUsers) {
            $adSummary = New-SummaryStatistics -Data $results.ADInactiveUsers -CountFields @{
                "非アクティブユーザー数" = @{ Type = "Count"; Risk = "中" }
            }
            
            $reportSections += @{
                Title = "Active Directory 非アクティブユーザー"
                Summary = $adSummary
                Data = $results.ADInactiveUsers | Select-Object -First 30
            }
        }
        
        # MFA状況セクション
        if ($results.EntraIDMFA) {
            $mfaSummary = New-SummaryStatistics -Data $results.EntraIDMFA -CountFields @{
                "総ユーザー数" = @{ Type = "Count"; Risk = "低" }
                "MFA未設定" = @{ Type = "Count"; Filter = {$_.HasMFA -eq $false -and $_.AccountEnabled -eq $true}; Risk = "高" }
            }
            
            $alerts = @()
            $noMFACount = ($results.EntraIDMFA | Where-Object { $_.HasMFA -eq $false -and $_.AccountEnabled -eq $true }).Count
            if ($noMFACount -gt 0) {
                $alerts += @{ Type = "Danger"; Message = "$noMFACount人のアクティブユーザーがMFAを設定していません。" }
            }
            
            $reportSections += @{
                Title = "Entra ID MFA設定状況"
                Summary = $mfaSummary
                Alerts = $alerts
                Data = $results.EntraIDMFA | Where-Object { $_.HasMFA -eq $false -and $_.AccountEnabled -eq $true } | Select-Object -First 50
            }
        }
        
        # スパム・フィッシング分析セクション
        if ($results.EXOSpamPhishing) {
            $spamSummary = New-SummaryStatistics -Data ($results.EXOSpamPhishing.SpamMessages + $results.EXOSpamPhishing.PhishingMessages) -CountFields @{
                "スパムメール" = @{ Type = "Count"; Filter = {$_.Status -eq "FilteredAsSpam"}; Risk = "中" }
                "フィッシングメール" = @{ Type = "Count"; Filter = {$_.Status -eq "FilteredAsPhish"}; Risk = "高" }
            }
            
            $reportSections += @{
                Title = "Exchange Online セキュリティ分析"
                Summary = $spamSummary
                Data = $results.EXOSpamPhishing.SuspiciousSenders | Select-Object -First 20
            }
        }
        
        # HTMLレポート生成
        $reportPath = Join-Path (New-ReportDirectory -ReportType "Weekly") "WeeklyReport_$(Get-Date -Format 'yyyyMMdd').html"
        New-HTMLReport -Title "週次運用レポート" -DataSections $reportSections -OutputPath $reportPath
        
        Write-AuditLog -Action "週次レポート実行" -Target "全システム" -Result "成功" -Details "レポート生成: $reportPath"
        
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        Send-ErrorNotification -ErrorDetails $errorDetails
        Write-Log "週次レポート実行エラー: $($_.Exception.Message)" -Level "Error"
    }
}

function Invoke-MonthlyReports {
    Write-Log "月次レポートを開始します" -Level "Info"
    
    $results = @{}
    
    try {
        # AD グループ管理
        . "$PSScriptRoot\..\AD\GroupManagement.ps1"
        $results.ADGroups = Get-ADGroupInventory
        $results.ADGroupMembership = Get-ADGroupMembershipReport
        $results.ADEmptyGroups = Get-ADEmptyGroups
        
        # Exchange Online 配布グループ・会議室
        . "$PSScriptRoot\..\EXO\MailboxManagement.ps1"
        $results.EXODistributionGroups = Get-EXODistributionGroupReport
        
        . "$PSScriptRoot\..\EXO\SecurityAnalysis.ps1"
        $results.EXORoomResources = Get-EXORoomResourceReport
        
        # Entra ID ライセンス・アプリケーション
        . "$PSScriptRoot\..\EntraID\UserSecurityManagement.ps1"
        $results.EntraIDLicense = Get-EntraIDLicenseReport
        $results.EntraIDApplications = Get-EntraIDApplicationReport
        
        # Teams・OneDrive
        . "$PSScriptRoot\..\EntraID\TeamsOneDriveManagement.ps1"
        $results.TeamsReport = Get-TeamsReport
        $results.OneDriveUsage = Get-OneDriveUsageReport
        $results.M365Utilization = Get-M365LicenseUtilizationReport
        
        # 月次HTMLレポート生成
        $reportSections = @()
        
        # ADグループ管理セクション
        if ($results.ADGroups) {
            $groupSummary = New-SummaryStatistics -Data $results.ADGroups -CountFields @{
                "総グループ数" = @{ Type = "Count"; Risk = "低" }
                "空グループ数" = @{ Type = "Count"; Filter = {$_.MemberCount -eq 0}; Risk = "中" }
            }
            
            $reportSections += @{
                Title = "Active Directory グループ管理"
                Summary = $groupSummary
                Data = $results.ADEmptyGroups
            }
        }
        
        # ライセンス管理セクション
        if ($results.EntraIDLicense -and $results.EntraIDLicense.UserLicenses) {
            $licenseSummary = New-SummaryStatistics -Data $results.EntraIDLicense.UserLicenses -CountFields @{
                "総ユーザー数" = @{ Type = "Count"; Risk = "低" }
                "ライセンス未付与" = @{ Type = "Count"; Filter = {$_.LicenseCount -eq 0 -and $_.AccountEnabled -eq $true}; Risk = "中" }
            }
            
            $reportSections += @{
                Title = "Microsoft 365 ライセンス管理"
                Summary = $licenseSummary
                Data = $results.EntraIDLicense.Subscriptions
            }
        }
        
        # Teams管理セクション
        if ($results.TeamsReport) {
            $teamsSummary = New-SummaryStatistics -Data $results.TeamsReport -CountFields @{
                "総チーム数" = @{ Type = "Count"; Risk = "低" }
                "オーナー不在チーム" = @{ Type = "Count"; Filter = {$_.OwnerCount -eq 0}; Risk = "高" }
            }
            
            $alerts = @()
            $orphanedTeams = ($results.TeamsReport | Where-Object { $_.OwnerCount -eq 0 }).Count
            if ($orphanedTeams -gt 0) {
                $alerts += @{ Type = "Warning"; Message = "$orphanedTeams個のチームにオーナーが設定されていません。" }
            }
            
            $reportSections += @{
                Title = "Microsoft Teams 管理"
                Summary = $teamsSummary
                Alerts = $alerts
                Data = $results.TeamsReport | Where-Object { $_.OwnerCount -eq 0 } | Select-Object -First 20
            }
        }
        
        # OneDrive使用状況セクション
        if ($results.OneDriveUsage) {
            $onedriveSummary = New-SummaryStatistics -Data $results.OneDriveUsage -CountFields @{
                "OneDriveユーザー数" = @{ Type = "Count"; Risk = "低" }
                "高使用率ユーザー" = @{ Type = "Count"; Filter = {$_.UsagePercent -gt 80}; Risk = "中" }
                "非アクティブユーザー" = @{ Type = "Count"; Filter = {$_.DaysSinceLastActivity -gt 90 -and $_.DaysSinceLastActivity -ne "不明"}; Risk = "低" }
            }
            
            $reportSections += @{
                Title = "OneDrive 使用状況"
                Summary = $onedriveSummary
                Data = $results.OneDriveUsage | Where-Object { $_.UsagePercent -gt 80 } | Select-Object -First 20
            }
        }
        
        # HTMLレポート生成
        $reportPath = Join-Path (New-ReportDirectory -ReportType "Monthly") "MonthlyReport_$(Get-Date -Format 'yyyyMMdd').html"
        New-HTMLReport -Title "月次運用レポート" -DataSections $reportSections -OutputPath $reportPath
        
        Write-AuditLog -Action "月次レポート実行" -Target "全システム" -Result "成功" -Details "レポート生成: $reportPath"
        
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        Send-ErrorNotification -ErrorDetails $errorDetails
        Write-Log "月次レポート実行エラー: $($_.Exception.Message)" -Level "Error"
    }
}

function Invoke-YearlyReports {
    Write-Log "年次レポートを開始します" -Level "Info"
    
    try {
        # ログファイルの年次アーカイブ
        Export-LogsToArchive -ArchivePath "Archives\Logs_$(Get-Date -Format 'yyyy').zip" -RetentionDays 365
        
        # レポートファイルの年次アーカイブ
        Export-ReportsToArchive -ReportType "Daily" -RetentionDays 365
        Export-ReportsToArchive -ReportType "Weekly" -RetentionDays 365
        Export-ReportsToArchive -ReportType "Monthly" -RetentionDays 365
        
        # 年次統計レポート生成
        $yearlyStats = @{
            Year = (Get-Date).Year
            TotalLogFiles = (Get-LogFiles -DaysBack 365).Count
            TotalReports = 0
            ArchiveCreated = Get-Date
        }
        
        $reportSections = @(
            @{
                Title = "年次統計サマリー"
                Summary = @(
                    @{ Label = "対象年度"; Value = $yearlyStats.Year; Risk = "低" }
                    @{ Label = "生成ログファイル数"; Value = $yearlyStats.TotalLogFiles; Risk = "低" }
                    @{ Label = "アーカイブ作成日"; Value = $yearlyStats.ArchiveCreated.ToString("yyyy-MM-dd"); Risk = "低" }
                )
                Data = @()
            }
        )
        
        $reportPath = Join-Path (New-ReportDirectory -ReportType "Yearly") "YearlyReport_$(Get-Date -Format 'yyyy').html"
        New-HTMLReport -Title "年次運用統計レポート" -DataSections $reportSections -OutputPath $reportPath
        
        Write-AuditLog -Action "年次レポート実行" -Target "全システム" -Result "成功" -Details "年次アーカイブ・統計レポート生成完了"
        
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        Send-ErrorNotification -ErrorDetails $errorDetails
        Write-Log "年次レポート実行エラー: $($_.Exception.Message)" -Level "Error"
    }
}

# メイン実行部分
if ($MyInvocation.InvocationName -ne '.') {
    $config = Initialize-ManagementTools
    
    Write-Log "$ReportType レポートスクリプトを開始します" -Level "Info"
    
    try {
        switch ($ReportType) {
            "Daily" { Invoke-DailyReports }
            "Weekly" { Invoke-WeeklyReports }
            "Monthly" { Invoke-MonthlyReports }
            "Yearly" { Invoke-YearlyReports }
        }
        
        Write-Log "$ReportType レポートスクリプトが正常に完了しました" -Level "Info"
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        Send-ErrorNotification -ErrorDetails $errorDetails
        throw $_
    }
    finally {
        Disconnect-AllServices
    }
}