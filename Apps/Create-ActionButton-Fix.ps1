function Create-ActionButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [string]$Action
    )
    
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size(190, 50)
    $button.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10, [System.Drawing.FontStyle]::Bold)
    $button.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.FlatStyle = "Flat"
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(0, 90, 180)
    $button.Cursor = "Hand"
    
    # ホバー効果
    $button.Add_MouseEnter({
        try {
            $this.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 240)
        } catch { }
    })
    
    $button.Add_MouseLeave({
        try {
            if ($this.Enabled) {
                $this.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
            }
        } catch { }
    })
    
    $button.Add_MouseDown({
        try {
            $this.BackColor = [System.Drawing.Color]::FromArgb(0, 90, 180)
        } catch { }
    })
    
    $button.Add_MouseUp({
        try {
            if ($this.ClientRectangle.Contains($this.PointToClient([System.Windows.Forms.Cursor]::Position))) {
                $this.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 240)
            } else {
                $this.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
            }
        } catch { }
    })
    
    # HTMLテンプレートマッピング辞書
    $templateMapping = @{
        # 定期レポート (Regularreports)
        "DailyReport" = "daily-report.html"
        "WeeklyReport" = "weekly-report.html"
        "MonthlyReport" = "monthly-report.html"
        "YearlyReport" = "yearly-report.html"
        "TestExecution" = "test-execution.html"
        "ShowLatestDailyReport" = "user-daily-activity.html"
        
        # 分析レポート (Analyticreport)
        "LicenseAnalysis" = "LicenseAnalysis.html"
        "UsageAnalysis" = "usage-analysis.html"
        "PerformanceAnalysis" = "performance-analysis.html"
        "SecurityAnalysis" = "security-analysis.html"
        "PermissionAudit" = "permission-audit.html"
        
        # Entra ID管理 (EntraIDManagement)
        "UserList" = "user-list.html"
        "MFAStatus" = "mfa-status.html"
        "ConditionalAccess" = "conditional-access.html"
        "SignInLogs" = "signin-logs.html"
        
        # Exchange Online管理 (ExchangeOnlineManagement)
        "MailboxManagement" = "mailbox-management.html"
        "MailFlowAnalysis" = "mail-flow-analysis.html"
        "SpamProtectionAnalysis" = "spam-protection-analysis.html"
        "MailDeliveryAnalysis" = "mail-delivery-analysis.html"
        
        # Teams管理 (TeamsManagement)
        "TeamsUsage" = "teams-usage.html"
        "TeamsSettingsAnalysis" = "teams-settings-analysis.html"
        "MeetingQualityAnalysis" = "meeting-quality-analysis.html"
        "TeamsAppAnalysis" = "teams-app-analysis.html"
        
        # OneDrive管理 (OneDriveManagement)
        "StorageAnalysis" = "storage-analysis.html"
        "SharingAnalysis" = "sharing-analysis.html"
        "SyncErrorAnalysis" = "sync-error-analysis.html"
        "ExternalSharingAnalysis" = "external-sharing-analysis.html"
    }
    
    # テンプレートサブフォルダマッピング
    $folderMapping = @{
        "DailyReport" = "Regularreports"; "WeeklyReport" = "Regularreports"; "MonthlyReport" = "Regularreports"
        "YearlyReport" = "Regularreports"; "TestExecution" = "Regularreports"; "ShowLatestDailyReport" = "Regularreports"
        "LicenseAnalysis" = "Analyticreport"; "UsageAnalysis" = "Analyticreport"; "PerformanceAnalysis" = "Analyticreport"
        "SecurityAnalysis" = "Analyticreport"; "PermissionAudit" = "Analyticreport"
        "UserList" = "EntraIDManagement"; "MFAStatus" = "EntraIDManagement"; "ConditionalAccess" = "EntraIDManagement"; "SignInLogs" = "EntraIDManagement"
        "MailboxManagement" = "ExchangeOnlineManagement"; "MailFlowAnalysis" = "ExchangeOnlineManagement"; "SpamProtectionAnalysis" = "ExchangeOnlineManagement"; "MailDeliveryAnalysis" = "ExchangeOnlineManagement"
        "TeamsUsage" = "TeamsManagement"; "TeamsSettingsAnalysis" = "TeamsManagement"; "MeetingQualityAnalysis" = "TeamsManagement"; "TeamsAppAnalysis" = "TeamsManagement"
        "StorageAnalysis" = "OneDriveManagement"; "SharingAnalysis" = "OneDriveManagement"; "SyncErrorAnalysis" = "OneDriveManagement"; "ExternalSharingAnalysis" = "OneDriveManagement"
    }
    
    # ボタンクリックイベント
    $actionRef = $Action
    $button.Add_Click({
        param($sender, $e)
        
        if ($sender -and $sender.GetType().Name -eq 'Button') {
            $originalText = $sender.Text
            Write-GuiLog "🔽 ボタンクリック開始: $originalText" "INFO"
            $sender.Text = "🔄 処理中..."
            $sender.Enabled = $false
            
            try {
                Set-GuiProgress -Value 20 -Status "データ処理中..."
                
                # データ取得
                $data = switch ($actionRef) {
                    "DailyReport" { 
                        Get-RealM365Data -DataType "DailyActivity" -MaxUsers 999999
                    }
                    default {
                        Get-RealM365Data -DataType "DailyActivity" -MaxUsers 999999
                    }
                }
                
                if ($data -and $data.Count -gt 0) {
                    Set-GuiProgress -Value 50 -Status "HTMLテンプレート処理中..."
                    
                    # レポート名とファイルパス設定
                    $reportName = "${actionRef}日次レポート"
                    $safeReportName = $reportName -replace '[\\/:*?"<>|]', '_'
                    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                    $reportsDir = Join-Path $PSScriptRoot "..\Reports\General"
                    
                    if (-not (Test-Path $reportsDir)) {
                        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
                    }
                    
                    $csvPath = Join-Path $reportsDir "${safeReportName}_${timestamp}.csv"
                    $htmlPath = Join-Path $reportsDir "${safeReportName}_${timestamp}.html"
                    
                    # CSV出力
                    $data | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8BOM
                    Write-GuiLog "✅ CSVファイル出力完了: $csvPath" "SUCCESS"
                    
                    # HTMLテンプレート処理
                    $templateFile = $templateMapping[$actionRef]
                    $templateFolder = $folderMapping[$actionRef]
                    
                    if ($templateFile -and $templateFolder) {
                        $templatePath = Join-Path $PSScriptRoot "..\Templates\Samples\$templateFolder\$templateFile"
                        
                        if (Test-Path $templatePath) {
                            Set-GuiProgress -Value 80 -Status "HTMLレポート生成中..."
                            
                            $htmlContent = Get-Content $templatePath -Raw -Encoding UTF8
                            
                            # プレースホルダー置換
                            $reportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
                            $dataSource = "実データ（Microsoft 365）"
                            
                            $htmlContent = $htmlContent -replace "{{REPORT_DATE}}", $reportDate
                            $htmlContent = $htmlContent -replace "{{TOTAL_USERS}}", $data.Count
                            $htmlContent = $htmlContent -replace "{{DATA_SOURCE}}", $dataSource
                            $htmlContent = $htmlContent -replace "{{REPORT_TYPE}}", $actionRef
                            
                            # テーブルデータ生成
                            $tableData = ""
                            foreach ($row in $data) {
                                $tableData += "<tr>"
                                $tableData += "<td>$([System.Web.HttpUtility]::HtmlEncode($row.'ユーザー名' ?? ''))</td>"
                                $tableData += "<td>$([System.Web.HttpUtility]::HtmlEncode($row.'ユーザープリンシパル名' ?? ''))</td>"
                                $tableData += "<td>$([System.Web.HttpUtility]::HtmlEncode($row.'Teams活動' ?? '0'))</td>"
                                $tableData += "<td><span class='badge badge-info'>$([System.Web.HttpUtility]::HtmlEncode($row.'活動レベル' ?? '低'))</span></td>"
                                $tableData += "<td>$([System.Web.HttpUtility]::HtmlEncode($row.'活動スコア' ?? '0'))</td>"
                                $tableData += "<td><span class='badge badge-success'>$([System.Web.HttpUtility]::HtmlEncode($row.'ステータス' ?? 'アクティブ'))</span></td>"
                                $tableData += "<td>$([System.Web.HttpUtility]::HtmlEncode($row.'レポート日' ?? (Get-Date -Format 'yyyy-MM-dd')))</td>"
                                $tableData += "</tr>"
                            }
                            
                            $htmlContent = $htmlContent -replace "{{TABLE_DATA}}", $tableData
                            $htmlContent = $htmlContent -replace "{{DAILY_ACTIVITY_DATA}}", $tableData
                            $htmlContent = $htmlContent -replace "{{USER_DATA}}", $tableData
                            $htmlContent = $htmlContent -replace "{{REPORT_DATA}}", $tableData
                            
                            # HTMLファイル出力
                            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8 -Force
                            Write-GuiLog "✅ HTMLファイル出力完了: $htmlPath" "SUCCESS"
                            
                            # ファイル自動表示
                            try {
                                Start-Process $htmlPath -ErrorAction Stop
                                Write-GuiLog "✅ レポートを開きました" "SUCCESS"
                            } catch {
                                Write-GuiLog "⚠️ ファイルを開けませんでした: $($_.Exception.Message)" "WARNING"
                            }
                            
                            Set-GuiProgress -Value 100 -Status "完了"
                            Write-GuiLog "$reportName が正常に生成されました" "SUCCESS" -ShowNotification
                            
                        } else {
                            Write-GuiLog "⚠️ テンプレートファイルが見つかりません: $templatePath" "WARNING"
                        }
                    } else {
                        Write-GuiLog "⚠️ テンプレートマッピングが見つかりません: $actionRef" "WARNING"
                    }
                } else {
                    Write-GuiLog "⚠️ データの取得に失敗しました" "WARNING"
                }
                
            } catch {
                Write-GuiLog "❌ レポート生成エラー: $($_.Exception.Message)" "ERROR" -ShowNotification
            } finally {
                $sender.Text = $originalText
                $sender.Enabled = $true
                $sender.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
                Set-GuiProgress -Hide
                Write-GuiLog "🔼 ボタンクリック完了: $originalText" "INFO"
            }
        }
    }.GetNewClosure())
    
    return $button
}