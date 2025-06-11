# ================================================================================
# レポート生成テストスクリプト
# ================================================================================

# パラメータ
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Daily", "Weekly", "Monthly", "Yearly")]
    [string]$ReportType = "Daily",
    
    [Parameter(Mandatory = $false)]
    [switch]$TestMode = $true
)

# 必要なモジュールのインポート
try {
    Import-Module "$PSScriptRoot\Scripts\Common\Common.psm1" -Force
    Import-Module "$PSScriptRoot\Scripts\Common\Logging.psm1" -Force
    Import-Module "$PSScriptRoot\Scripts\Common\ReportGenerator.psm1" -Force
    Write-Host "✓ モジュールインポート成功" -ForegroundColor Green
}
catch {
    Write-Host "✗ モジュールインポートエラー: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 設定読み込み
try {
    $config = Initialize-ManagementTools
    if (-not $config) {
        throw "設定ファイルの読み込みに失敗しました"
    }
    Write-Host "✓ 設定ファイル読み込み成功" -ForegroundColor Green
}
catch {
    Write-Host "✗ 設定読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# レポートディレクトリ準備
$reportDir = New-ReportDirectory -ReportType $ReportType
Write-Host "✓ レポートディレクトリ: $reportDir" -ForegroundColor Cyan

# テストデータ生成
function New-TestData {
    return @{
        GeneralInfo = @{
            OrganizationName = $config.General.OrganizationName
            ReportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
            ReportType = $ReportType
            Environment = $config.General.Environment
        }
        
        SystemSummary = @{
            TotalUsers = 125
            ActiveUsers = 118
            InactiveUsers = 7
            TotalMailboxes = 142
            LargeMailboxes = 23
            FailedLogins = 5
            SuccessfulLogins = 1847
        }
        
        SecurityAlerts = @(
            @{
                Level = "High"
                Message = "管理者アカウントでの異常なサインイン検出"
                Count = 2
                LastOccurred = (Get-Date).AddHours(-3)
            },
            @{
                Level = "Medium"
                Message = "大容量添付ファイル送信"
                Count = 15
                LastOccurred = (Get-Date).AddHours(-1)
            },
            @{
                Level = "Low"
                Message = "パスワード期限切れ間近のユーザー"
                Count = 8
                LastOccurred = (Get-Date).AddDays(-1)
            }
        )
        
        CapacityReport = @(
            @{
                MailboxName = "山田太郎"
                EmailAddress = "t-yamada@mirai-const.co.jp"
                TotalSize = "8.2 GB"
                UsagePercent = 82
                ItemCount = 12547
                Status = "Warning"
            },
            @{
                MailboxName = "田中花子"
                EmailAddress = "h-tanaka@mirai-const.co.jp"
                TotalSize = "9.8 GB"
                UsagePercent = 98
                ItemCount = 18234
                Status = "Critical"
            },
            @{
                MailboxName = "佐藤次郎"
                EmailAddress = "j-sato@mirai-const.co.jp"
                TotalSize = "2.1 GB"
                UsagePercent = 21
                ItemCount = 3421
                Status = "Normal"
            }
        )
    }
}

# HTMLレポート生成
try {
    Write-Host "`n=== ${ReportType}レポート生成テスト ===" -ForegroundColor Yellow
    
    $testData = New-TestData
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportFileName = "TestReport_${ReportType}_${timestamp}.html"
    $reportPath = Join-Path $reportDir $reportFileName
    
    # HTMLテンプレート読み込み
    $templatePath = Join-Path $PSScriptRoot "Templates\ReportTemplate.html"
    if (Test-Path $templatePath) {
        $htmlTemplate = Get-Content $templatePath -Raw
        Write-Host "✓ HTMLテンプレート読み込み成功" -ForegroundColor Green
    }
    else {
        Write-Host "✗ HTMLテンプレートが見つかりません: $templatePath" -ForegroundColor Red
        exit 1
    }
    
    # テンプレート置換
    $reportTitle = "$($config.General.OrganizationName) ${ReportType}運用レポート（テスト版）"
    $htmlContent = $htmlTemplate -replace '{{REPORT_TITLE}}', $reportTitle
    $htmlContent = $htmlContent -replace '{{REPORT_DATE}}', $testData.GeneralInfo.ReportDate
    $htmlContent = $htmlContent -replace '{{SYSTEM_INFO}}', $env:COMPUTERNAME
    $htmlContent = $htmlContent -replace '{{PS_VERSION}}', $PSVersionTable.PSVersion.ToString()
    
    # セクション生成
    $sectionsHtml = ""
    
    # サマリーセクション
    $sectionsHtml += @"
    <div class="section">
        <div class="section-header">
            <h2>📊 システムサマリー</h2>
        </div>
        <div class="section-content">
            <div class="summary-grid">
                <div class="summary-card">
                    <h3>総ユーザー数</h3>
                    <div class="value">$($testData.SystemSummary.TotalUsers)</div>
                    <div class="description">アクティブ: $($testData.SystemSummary.ActiveUsers), 非アクティブ: $($testData.SystemSummary.InactiveUsers)</div>
                </div>
                <div class="summary-card">
                    <h3>メールボックス</h3>
                    <div class="value">$($testData.SystemSummary.TotalMailboxes)</div>
                    <div class="description">大容量メールボックス: $($testData.SystemSummary.LargeMailboxes)</div>
                </div>
                <div class="summary-card">
                    <h3>ログイン成功</h3>
                    <div class="value">$($testData.SystemSummary.SuccessfulLogins)</div>
                    <div class="description">24時間以内</div>
                </div>
                <div class="summary-card risk-medium">
                    <h3>ログイン失敗</h3>
                    <div class="value">$($testData.SystemSummary.FailedLogins)</div>
                    <div class="description">24時間以内</div>
                </div>
            </div>
        </div>
    </div>
"@

    # セキュリティアラートセクション
    $alertsHtml = ""
    foreach ($alert in $testData.SecurityAlerts) {
        $alertClass = switch ($alert.Level) {
            "High" { "alert-danger" }
            "Medium" { "alert-warning" }
            "Low" { "alert-info" }
            default { "alert-info" }
        }
        
        $alertsHtml += @"
        <div class="alert $alertClass">
            <strong>[$($alert.Level)]</strong> $($alert.Message) - 発生回数: $($alert.Count) - 最終発生: $($alert.LastOccurred.ToString("yyyy/MM/dd HH:mm"))
        </div>
"@
    }
    
    $sectionsHtml += @"
    <div class="section">
        <div class="section-header">
            <h2>🚨 セキュリティアラート</h2>
        </div>
        <div class="section-content">
            $alertsHtml
        </div>
    </div>
"@

    # 容量レポートセクション
    $capacityTableHtml = @"
    <div class="table-container">
        <table>
            <thead>
                <tr>
                    <th>ユーザー名</th>
                    <th>メールアドレス</th>
                    <th>総容量</th>
                    <th>使用率</th>
                    <th>アイテム数</th>
                    <th>ステータス</th>
                </tr>
            </thead>
            <tbody>
"@

    foreach ($mailbox in $testData.CapacityReport) {
        $statusClass = switch ($mailbox.Status) {
            "Critical" { "risk-high" }
            "Warning" { "risk-medium" }
            "Normal" { "risk-low" }
            default { "" }
        }
        
        $capacityTableHtml += @"
                <tr>
                    <td>$($mailbox.MailboxName)</td>
                    <td>$($mailbox.EmailAddress)</td>
                    <td>$($mailbox.TotalSize)</td>
                    <td class="$statusClass">$($mailbox.UsagePercent)%</td>
                    <td>$($mailbox.ItemCount.ToString("N0"))</td>
                    <td class="$statusClass">$($mailbox.Status)</td>
                </tr>
"@
    }
    
    $capacityTableHtml += @"
            </tbody>
        </table>
    </div>
"@

    $sectionsHtml += @"
    <div class="section">
        <div class="section-header">
            <h2>📈 容量監視レポート</h2>
        </div>
        <div class="section-content">
            $capacityTableHtml
        </div>
    </div>
"@

    # 最終HTML生成
    $htmlContent = $htmlContent -replace '{{CONTENT_SECTIONS}}', $sectionsHtml
    
    # ファイル出力
    $htmlContent | Out-File -FilePath $reportPath -Encoding UTF8
    
    Write-Host "✓ レポート生成完了" -ForegroundColor Green
    Write-Host "  ファイル: $reportPath" -ForegroundColor Cyan
    Write-Host "  サイズ: $((Get-Item $reportPath).Length) bytes" -ForegroundColor Cyan
    
    # CSVレポートも生成
    $csvPath = $reportPath -replace "\.html$", ".csv"
    $testData.CapacityReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "✓ CSVレポート生成完了: $csvPath" -ForegroundColor Green
    
    return @{
        Success = $true
        HtmlPath = $reportPath
        CsvPath = $csvPath
        Data = $testData
    }
}
catch {
    Write-Host "✗ レポート生成エラー: $($_.Exception.Message)" -ForegroundColor Red
    return @{
        Success = $false
        Error = $_.Exception.Message
    }
}