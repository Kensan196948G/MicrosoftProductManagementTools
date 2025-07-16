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
    "UserDailyActivity" = "Regularreports\user-daily-activity.html"
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
            # HTMLテンプレートのヘッダー順序に合わせて出力
            foreach ($item in $Data) {
                $html += "<tr>"
                $html += "<td>$($item.DisplayName ?? '不明')</td>"  # 表示名
                $html += "<td>$($item.UserPrincipalName ?? '不明')</td>"  # ユーザープリンシパル名
                $html += "<td>$($item.Email ?? '不明')</td>"  # メールアドレス
                $html += "<td>$($item.Department ?? '不明')</td>"  # 部署
                $html += "<td>$($item.JobTitle ?? '不明')</td>"  # 職種
                $html += "<td><span class='badge badge-$(if($item.AccountStatus -eq '有効') { 'active' } else { 'inactive' })'>$($item.AccountStatus)</span></td>"  # アカウントステータス
                $html += "<td><span class='badge badge-enabled'>$($item.LicenseStatus ?? '不明')</span></td>"  # ライセンス状況
                $html += "<td>$($item.CreationDate ?? '不明')</td>"  # 作成日
                $html += "<td>$($item.LastSignIn ?? '不明')</td>"  # 最終サインイン
                $html += "</tr>"
            }
        }
        "LicenseAnalysis" {
            # HTMLテンプレートのヘッダー順序に合わせて出力
            foreach ($item in $Data) {
                $html += "<tr>"
                $html += "<td>$($item.LicenseName ?? '不明')</td>"  # ライセンス名
                $html += "<td>$($item.SkuId ?? '不明')</td>"  # SKU ID
                $html += "<td>$($item.PurchasedQuantity ?? 0)</td>"  # 購入数
                $html += "<td>$($item.AssignedQuantity ?? 0)</td>"  # 割り当て済み
                $html += "<td>$($item.AvailableQuantity ?? 0)</td>"  # 利用可能
                $html += "<td>$($item.UsageRate ?? 0)%</td>"  # 利用率
                $html += "<td>$($item.MonthlyUnitPrice ?? '¥0')</td>"  # 月額単価
                $html += "<td>$($item.MonthlyCost ?? '¥0')</td>"  # 月額コスト
                $html += "<td><span class='badge badge-$(if($item.Status -eq '利用可能') { 'active' } else { 'inactive' })'>$($item.Status ?? '不明')</span></td>"  # ステータス
                $html += "</tr>"
            }
        }
        "MFAStatus" {
            # HTMLテンプレートのヘッダー順序に合わせて出力
            foreach ($item in $Data) {
                $html += "<tr>"
                $html += "<td>$($item.UserName ?? '不明')</td>"  # ユーザー名
                $html += "<td>$($item.Email ?? '不明')</td>"  # メールアドレス
                $html += "<td>$($item.Department ?? '不明')</td>"  # 部署
                $html += "<td><span class='badge badge-$(if($item.MFAStatus -eq '有効') { 'active' } else { 'inactive' })'>$($item.MFAStatus ?? '不明')</span></td>"  # MFAステータス
                $html += "<td>$($item.AuthenticationMethod ?? '不明')</td>"  # 認証方法
                $html += "<td>$($item.FallbackMethod ?? '不明')</td>"  # フォールバック方法
                $html += "<td>$($item.LastMFASetupDate ?? '不明')</td>"  # 最終MFA設定日
                $html += "<td>$($item.Compliance ?? '不明')</td>"  # コンプライアンス
                $html += "<td>$($item.RiskLevel ?? '不明')</td>"  # リスクレベル
                $html += "</tr>"
            }
        }
        "TeamsUsage" {
            # HTMLテンプレートのヘッダー順序に合わせて出力
            foreach ($item in $Data) {
                $html += "<tr>"
                $html += "<td>$($item.UserName ?? '不明')</td>"  # ユーザー名
                $html += "<td>$($item.Department ?? '不明')</td>"  # 部署
                $html += "<td>$($item.LastAccess ?? '不明')</td>"  # 最終アクセス
                $html += "<td>$($item.MonthlyMeetingParticipation ?? 0)</td>"  # 月次会議参加
                $html += "<td>$($item.MonthlyChatCount ?? 0)</td>"  # 月次チャット数
                $html += "<td>$($item.StorageUsedMB ?? 0)</td>"  # 使用ストレージ
                $html += "<td>$($item.AppUsageCount ?? 0)</td>"  # アプリ使用数
                $html += "<td>$($item.UsageLevel ?? '不明')</td>"  # 使用レベル
                $html += "<td><span class='badge badge-$(if($item.Status -eq '正常') { 'normal' } else { 'alert' })'>$($item.Status ?? '不明')</span></td>"  # ステータス
                $html += "</tr>"
            }
        }
        "DailyReport" {
            # データ構造を確認して適切なテーブルを生成
            if ($Data.Count -gt 0) {
                $firstItem = $Data[0]
                if ($firstItem.PSObject.Properties.Name -contains "ServiceName") {
                    # サービスサマリーデータの場合
                    foreach ($item in $Data) {
                        $html += "<tr>"
                        $html += "<td>$($item.ServiceName ?? '不明')</td>"
                        $html += "<td>$($item.ActiveUsersCount ?? 0)</td>"
                        $html += "<td>$($item.TotalActivityCount ?? 0)</td>"
                        $html += "<td>$($item.NewUsersCount ?? 0)</td>"
                        $html += "<td>$($item.ErrorCount ?? 0)</td>"
                        $html += "<td><span class='badge badge-$(if($item.ServiceStatus -eq '正常') { 'normal' } else { 'alert' })'>$($item.ServiceStatus ?? '不明')</span></td>"
                        $html += "<td>$($item.PerformanceScore ?? 0)</td>"
                        $html += "<td>$($item.LastCheck ?? '不明')</td>"
                        $html += "<td><span class='badge badge-$(if($item.Status -eq '正常') { 'normal' } else { 'alert' })'>$($item.Status ?? '不明')</span></td>"
                        $html += "</tr>"
                    }
                } elseif ($firstItem.PSObject.Properties.Name -contains "UserName") {
                    # 個別ユーザーアクティビティデータの場合（不要項目を除去）
                    foreach ($item in $Data) {
                        $html += "<tr>"
                        $html += "<td>$($item.UserName ?? '不明')</td>"  # ユーザー名
                        $html += "<td>$($item.UserPrincipalName ?? '不明')</td>"  # UPN
                        $html += "<td>$($item.DailyLogins ?? 0)</td>"  # 日次ログイン
                        $html += "<td>$($item.DailyEmails ?? 0)</td>"  # 日次メール
                        $html += "<td>$($item.TeamsActivity ?? 0)</td>"  # Teamsアクティビティ
                        $html += "<td><span class='badge badge-$(if($item.ActivityLevel -eq '高') { 'active' } elseif($item.ActivityLevel -eq '中') { 'warning' } else { 'inactive' })'>$($item.ActivityLevel ?? '不明')</span></td>"  # アクティビティレベル
                        $html += "<td>$($item.ActivityScore ?? 0)</td>"  # アクティビティスコア
                        $html += "<td><span class='badge badge-$(if($item.Status -eq 'アクティブ') { 'active' } else { 'inactive' })'>$($item.Status ?? '不明')</span></td>"  # ステータス
                        $html += "</tr>"
                    }
                }
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
        
        # レポートタイプ別の変数を準備
        $variables = @{
            "Title" = $Title
            "REPORT_DATE" = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
            "REPORT_TIME" = Get-Date -Format "HH:mm:ss"
            "SYSTEM_INFO" = "Microsoft 365統合管理ツール v2.0"
            "TOTAL_COUNT" = $Data.Count
            "ChartLabels" = ($chartData.labels | ConvertTo-Json)
            "ChartData" = ($chartData.data | ConvertTo-Json)
        }
        
        # レポートタイプ別の特定変数を設定
        switch ($ReportType) {
            "Users" {
                $variables["USER_DATA"] = $htmlTable
                $variables["TOTAL_USERS"] = $Data.Count
                $variables["ACTIVE_USERS"] = ($Data | Where-Object { $_.AccountStatus -eq "有効" }).Count
            }
            "LicenseAnalysis" {
                $variables["LICENSE_DATA"] = $htmlTable
                $variables["TOTAL_LICENSES"] = $Data.Count
                $variables["ACTIVE_USERS"] = ($Data | Measure-Object AssignedQuantity -Sum).Sum
            }
            "DailyReport" {
                $variables["DAILY_ACTIVITY_DATA"] = $htmlTable
                # データ構造に応じて変数を設定
                if ($Data.Count -gt 0 -and $Data[0].PSObject.Properties.Name -contains "UserName") {
                    # 個別ユーザーデータの場合
                    $variables["TOTAL_USERS"] = $Data.Count
                    $variables["ACTIVE_USERS"] = ($Data | Where-Object { $_.ActivityLevel -ne "低" }).Count
                    $variables["DAILY_LOGINS"] = ($Data | Measure-Object DailyLogins -Sum).Sum
                    $variables["DAILY_EMAILS"] = ($Data | Measure-Object DailyEmails -Sum).Sum
                    $variables["DAILY_ALERTS"] = 0  # ユーザーデータにはアラート情報なし
                } else {
                    # サービスサマリーデータの場合
                    $variables["TOTAL_USERS"] = ($Data | Measure-Object ActiveUsersCount -Sum).Sum
                    $variables["ACTIVE_USERS"] = ($Data | Measure-Object ActiveUsersCount -Sum).Sum
                    $variables["DAILY_LOGINS"] = ($Data | Measure-Object ActiveUsersCount -Sum).Sum
                    $variables["DAILY_EMAILS"] = ($Data | Measure-Object TotalActivityCount -Sum).Sum
                    $variables["DAILY_ALERTS"] = ($Data | Measure-Object ErrorCount -Sum).Sum
                }
            }
            "MFAStatus" {
                $variables["MFA_DATA"] = $htmlTable
                $variables["TOTAL_USERS"] = $Data.Count
                $variables["ACTIVE_USERS"] = ($Data | Where-Object { $_.MFAStatus -eq "有効" }).Count
            }
            "TeamsUsage" {
                $variables["TEAMS_DATA"] = $htmlTable
                $variables["TOTAL_USERS"] = $Data.Count
                $variables["ACTIVE_USERS"] = ($Data | Where-Object { $_.UsageLevel -ne "未使用" }).Count
            }
            default {
                # デフォルトの汎用変数
                $variables["USER_DATA"] = $htmlTable
                $variables["LICENSE_DATA"] = $htmlTable
                $variables["MFA_DATA"] = $htmlTable
                $variables["TEAMS_DATA"] = $htmlTable
                $variables["DAILY_ACTIVITY_DATA"] = $htmlTable
                $variables["TOTAL_USERS"] = $Data.Count
                $variables["ACTIVE_USERS"] = $Data.Count
                $variables["TOTAL_LICENSES"] = $Data.Count
                $variables["DAILY_LOGINS"] = 0
                $variables["DAILY_EMAILS"] = 0
                $variables["DAILY_ALERTS"] = 0
            }
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