# ================================================================================
# HTMLテンプレートエンジン
# Templates/Samples配下の既存HTMLテンプレートを活用してレポートを生成
# ================================================================================

# テンプレートマッピング定義
$Script:TemplateMapping = @{
    # 分析レポート
    "LicenseAnalysis" = "Analyticreport\license-analysis.html"
    "UsageAnalysis" = "Analyticreport\usage-analysis.html"
    "PerformanceAnalysis" = "Analyticreport\performance-analysis.html"
    "SecurityAnalysis" = "Analyticreport\security-analysis.html"
    "PermissionAudit" = "Analyticreport\permission-audit.html"
    
    # Entra ID管理
    "Users" = "EntraIDManagement\user-list.html"
    "MFAStatus" = "EntraIDManagement\mfa-status.html"
    "ConditionalAccess" = "EntraIDManagement\conditional-access.html"
    "SignInLogs" = "EntraIDManagement\signin-logs.html"
    
    # Exchange Online管理
    "MailboxAnalysis" = "ExchangeOnlineManagement\mailbox-management.html"
    "MailFlowAnalysis" = "ExchangeOnlineManagement\mail-flow-analysis.html"
    "SpamProtectionAnalysis" = "ExchangeOnlineManagement\spam-protection-analysis.html"
    "MailDeliveryAnalysis" = "ExchangeOnlineManagement\mail-delivery-analysis.html"
    
    # Teams管理
    "TeamsUsage" = "TeamsManagement\teams-usage.html"
    "TeamsSettings" = "TeamsManagement\teams-settings-analysis.html"
    "MeetingQuality" = "TeamsManagement\meeting-quality-analysis.html"
    "TeamsAppAnalysis" = "TeamsManagement\teams-app-analysis.html"
    
    # OneDrive管理
    "OneDriveAnalysis" = "OneDriveManagement\storage-analysis.html"
    "SharingAnalysis" = "OneDriveManagement\sharing-analysis.html"
    "SyncErrorAnalysis" = "OneDriveManagement\sync-error-analysis.html"
    "ExternalSharingAnalysis" = "OneDriveManagement\external-sharing-analysis.html"
    
    # 定期レポート
    "DailyReport" = "Regularreports\daily-report.html"
    "WeeklyReport" = "Regularreports\weekly-report.html"
    "MonthlyReport" = "Regularreports\monthly-report.html"
    "YearlyReport" = "Regularreports\yearly-report.html"
    "TestExecution" = "Regularreports\test-execution.html"
}

function Get-HTMLTemplate {
    <#
    .SYNOPSIS
    指定されたレポートタイプに対応するHTMLテンプレートを取得
    #>
    param(
        [string]$ReportType
    )
    
    if ($Script:TemplateMapping.ContainsKey($ReportType)) {
        $templatePath = Join-Path $PSScriptRoot "..\..\Templates\Samples\" $Script:TemplateMapping[$ReportType]
        
        if (Test-Path $templatePath) {
            return Get-Content $templatePath -Raw -Encoding UTF8
        }
        else {
            Write-Warning "テンプレートファイルが見つかりません: $templatePath"
            return $null
        }
    }
    else {
        Write-Warning "サポートされていないレポートタイプ: $ReportType"
        return $null
    }
}

function Convert-DataToHTML {
    <#
    .SYNOPSIS
    データをHTMLテーブル形式に変換（テンプレート用）
    #>
    param(
        [array]$Data,
        [string]$ReportType = "Generic"
    )
    
    if (-not $Data -or $Data.Count -eq 0) {
        return "<tr><td colspan='100%'>データがありません</td></tr>"
    }
    
    $html = ""
    
    # レポートタイプに応じたHTML生成
    switch ($ReportType) {
        "Users" {
            foreach ($item in $Data) {
                $html += "<tr>"
                $html += "<td>$($item.DisplayName)</td>"
                $html += "<td>$($item.UserPrincipalName)</td>"
                $html += "<td>$($item.UserPrincipalName)</td>"
                $html += "<td>$($item.Department)</td>"
                $html += "<td>$($item.JobTitle)</td>"
                $html += "<td>$($item.AccountStatus)</td>"
                $html += "<td>$($item.LicenseStatus)</td>"
                $html += "<td>$($item.CreationDate)</td>"
                $html += "<td>$($item.LastSignIn)</td>"
                $html += "</tr>"
            }
        }
        "LicenseAnalysis" {
            foreach ($item in $Data) {
                $html += "<tr>"
                $html += "<td>$($item.LicenseName)</td>"
                $html += "<td>$($item.SkuId)</td>"
                $html += "<td>$($item.PurchasedQuantity)</td>"
                $html += "<td>$($item.AssignedQuantity)</td>"
                $html += "<td>$($item.AvailableQuantity)</td>"
                $html += "<td>$($item.UsageRate)%</td>"
                $html += "<td>$($item.MonthlyUnitPrice)</td>"
                $html += "<td>$($item.MonthlyCost)</td>"
                $html += "<td>$($item.Status)</td>"
                $html += "</tr>"
            }
        }
        "MFAStatus" {
            foreach ($item in $Data) {
                $html += "<tr>"
                $html += "<td>$($item.UserName)</td>"
                $html += "<td>$($item.Email)</td>"
                $html += "<td>$($item.Department)</td>"
                $html += "<td>$($item.MFAStatus)</td>"
                $html += "<td>$($item.AuthenticationMethod)</td>"
                $html += "<td>$($item.FallbackMethod)</td>"
                $html += "<td>$($item.LastMFASetupDate)</td>"
                $html += "<td>$($item.Compliance)</td>"
                $html += "<td>$($item.RiskLevel)</td>"
                $html += "</tr>"
            }
        }
        "TeamsUsage" {
            foreach ($item in $Data) {
                $html += "<tr>"
                $html += "<td>$($item.UserName)</td>"
                $html += "<td>$($item.Department)</td>"
                $html += "<td>$($item.LastAccess)</td>"
                $html += "<td>$($item.MonthlyMeetingParticipation)</td>"
                $html += "<td>$($item.MonthlyChatCount)</td>"
                $html += "<td>$($item.StorageUsedMB)</td>"
                $html += "<td>$($item.AppUsageCount)</td>"
                $html += "<td>$($item.UsageLevel)</td>"
                $html += "<td>$($item.Status)</td>"
                $html += "</tr>"
            }
        }
        default {
            # 汎用テーブル生成
            foreach ($item in $Data) {
                $html += "<tr>"
                $properties = $item.PSObject.Properties.Name
                foreach ($prop in $properties) {
                    $value = $item.$prop
                    if ($null -eq $value) { $value = "-" }
                    $html += "<td>$value</td>"
                }
                $html += "</tr>"
            }
        }
    }
    
    return $html
}

function Convert-DataToChartData {
    <#
    .SYNOPSIS
    データをChart.js用のJSON形式に変換
    #>
    param(
        [array]$Data,
        [string]$LabelProperty,
        [string]$ValueProperty
    )
    
    if (-not $Data -or $Data.Count -eq 0) {
        return @{
            labels = @()
            data = @()
        }
    }
    
    $labels = @()
    $values = @()
    
    foreach ($item in $Data) {
        $labels += $item.$LabelProperty
        $values += $item.$ValueProperty
    }
    
    return @{
        labels = $labels
        data = $values
    }
}

function Replace-TemplateVariables {
    <#
    .SYNOPSIS
    HTMLテンプレート内の変数を実際の値に置換
    #>
    param(
        [string]$Template,
        [hashtable]$Variables
    )
    
    $result = $Template
    
    # 現在の日時情報を追加
    $Variables["CurrentDateTime"] = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
    $Variables["CurrentDate"] = Get-Date -Format "yyyy年MM月dd日"
    $Variables["CurrentTime"] = Get-Date -Format "HH:mm:ss"
    $Variables["ReportGeneratedBy"] = "Microsoft 365統合管理ツール"
    
    # 変数の置換
    foreach ($key in $Variables.Keys) {
        $pattern = "{{$key}}"
        $value = $Variables[$key]
        $result = $result -replace [regex]::Escape($pattern), $value
    }
    
    return $result
}

function Generate-EnhancedHTMLReport {
    <#
    .SYNOPSIS
    既存のHTMLテンプレートを使用してレポートを生成
    #>
    param(
        [array]$Data,
        [string]$ReportType,
        [string]$Title = $ReportType,
        [hashtable]$AdditionalVariables = @{}
    )
    
    try {
        # テンプレートを取得
        $template = Get-HTMLTemplate -ReportType $ReportType
        
        if (-not $template) {
            Write-Warning "テンプレートが見つからないため、基本的なHTMLレポートを生成します"
            return Generate-BasicHTMLReport -Data $Data -Title $Title
        }
        
        # データをHTMLテーブルに変換
        $htmlTable = Convert-DataToHTML -Data $Data -ReportType $ReportType
        
        # チャートデータを生成（必要に応じて）
        $chartData = @{}
        if ($Data.Count -gt 0) {
            $properties = $Data[0].PSObject.Properties.Name
            if ($properties.Count -ge 2) {
                $chartData = Convert-DataToChartData -Data $Data -LabelProperty $properties[0] -ValueProperty $properties[1]
            }
        }
        
        # 変数を準備（テンプレートファイルの変数名に合わせる）
        $variables = @{
            "Title" = $Title
            "USER_DATA" = $htmlTable
            "LICENSE_DATA" = $htmlTable
            "MFA_DATA" = $htmlTable
            "TEAMS_DATA" = $htmlTable
            "REPORT_DATE" = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
            "REPORT_TIME" = Get-Date -Format "HH:mm:ss"
            "SYSTEM_INFO" = "Microsoft 365統合管理ツール v2.0"
            "TOTAL_COUNT" = $Data.Count
            "ChartLabels" = ($chartData.labels | ConvertTo-Json)
            "ChartData" = ($chartData.data | ConvertTo-Json)
        }
        
        # 追加変数をマージ
        foreach ($key in $AdditionalVariables.Keys) {
            $variables[$key] = $AdditionalVariables[$key]
        }
        
        # テンプレートの変数を置換
        $result = Replace-TemplateVariables -Template $template -Variables $variables
        
        return $result
    }
    catch {
        Write-Error "HTMLレポート生成中にエラーが発生しました: $_"
        return Generate-BasicHTMLReport -Data $Data -Title $Title
    }
}

function Generate-BasicHTMLReport {
    <#
    .SYNOPSIS
    基本的なHTMLレポートを生成（テンプレートが見つからない場合のフォールバック）
    #>
    param(
        [array]$Data,
        [string]$Title
    )
    
    $timestamp = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
    $htmlTable = Convert-DataToHTML -Data $Data
    
    return @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$Title</title>
    <style>
        body { font-family: 'Noto Sans JP', sans-serif; margin: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; margin-bottom: 20px; }
        .data-table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        .data-table th, .data-table td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        .data-table th { background-color: #f2f2f2; }
        .data-table tr:nth-child(even) { background-color: #f9f9f9; }
    </style>
</head>
<body>
    <div class="header">
        <h1>$Title</h1>
        <p>生成日時: $timestamp</p>
    </div>
    <div class="content">
        $htmlTable
    </div>
</body>
</html>
"@
}

# エクスポートする関数
Export-ModuleMember -Function Generate-EnhancedHTMLReport, Get-HTMLTemplate, Convert-DataToHTML