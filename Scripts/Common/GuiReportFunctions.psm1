# ================================================================================
# GuiReportFunctions.psm1
# GUI用レポート生成関数群（実データ対応版）
# 実データ取得とフォールバック機能を提供
# ================================================================================

Import-Module "$PSScriptRoot\Common.psm1" -Force
Import-Module "$PSScriptRoot\Authentication.psm1" -Force
Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\ErrorHandling.psm1" -Force
Import-Module "$PSScriptRoot\ReportGenerator.psm1" -Force -ErrorAction SilentlyContinue

# 新しい実データモジュールをインポート
try {
    Import-Module "$PSScriptRoot\DailyReportData.psm1" -Force -ErrorAction Stop
    Write-Host "DailyReportData.psm1 インポート完了" -ForegroundColor Green
} catch {
    Write-Host "警告: DailyReportData.psm1 インポート失敗: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    Import-Module "$PSScriptRoot\WeeklyReportData.psm1" -Force -ErrorAction Stop
    Write-Host "WeeklyReportData.psm1 インポート完了" -ForegroundColor Green
} catch {
    Write-Host "警告: WeeklyReportData.psm1 インポート失敗: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    Import-Module "$PSScriptRoot\MonthlyReportData.psm1" -Force -ErrorAction Stop
    Write-Host "MonthlyReportData.psm1 インポート完了" -ForegroundColor Green
} catch {
    Write-Host "警告: MonthlyReportData.psm1 インポート失敗: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    Import-Module "$PSScriptRoot\YearlyReportData.psm1" -Force -ErrorAction Stop
    Write-Host "YearlyReportData.psm1 インポート完了" -ForegroundColor Green
} catch {
    Write-Host "警告: YearlyReportData.psm1 インポート失敗: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    Import-Module "$PSScriptRoot\AnalysisReportData.psm1" -Force -ErrorAction Stop
    Write-Host "AnalysisReportData.psm1 インポート完了" -ForegroundColor Green
} catch {
    Write-Host "警告: AnalysisReportData.psm1 インポート失敗: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    Import-Module "$PSScriptRoot\..\EntraID\EntraIDManagementData.psm1" -Force -ErrorAction Stop
    Write-Host "EntraIDManagementData.psm1 インポート完了" -ForegroundColor Green
} catch {
    Write-Host "警告: EntraIDManagementData.psm1 インポート失敗: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    Import-Module "$PSScriptRoot\..\EXO\ExchangeManagementData.psm1" -Force -ErrorAction Stop
    Write-Host "ExchangeManagementData.psm1 インポート完了" -ForegroundColor Green
} catch {
    Write-Host "警告: ExchangeManagementData.psm1 インポート失敗: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    Import-Module "$PSScriptRoot\..\Teams\TeamsManagementData.psm1" -Force -ErrorAction Stop
    Write-Host "TeamsManagementData.psm1 インポート完了" -ForegroundColor Green
} catch {
    Write-Host "警告: TeamsManagementData.psm1 インポート失敗: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    Import-Module "$PSScriptRoot\..\OneDrive\OneDriveManagementData.psm1" -Force -ErrorAction Stop
    Write-Host "OneDriveManagementData.psm1 インポート完了" -ForegroundColor Green
} catch {
    Write-Host "警告: OneDriveManagementData.psm1 インポート失敗: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 共通のレポート実行関数
function Invoke-GuiReportGeneration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportType,
        
        [Parameter(Mandatory = $true)]
        [string]$ReportName,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$FallbackDataGenerator,
        
        [Parameter(Mandatory = $false)]
        [string]$ReportFolder = $ReportType,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalParams = @{}
    )
    
    Write-Host "$ReportName の生成を開始します..." -ForegroundColor Yellow
    
    try {
        # 実データ取得を試行
        $success = $false
        $reportPath = $null
        $realData = $null
        
        switch ($ReportType) {
            "Daily" { 
                $realData = Get-DailyReportRealData
                # 日次レポートは複数のデータセットを含むため、個別に出力
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $toolRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
                $reportDir = Join-Path $toolRoot "Reports\Daily"
                if (-not (Test-Path $reportDir)) {
                    New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
                }
                
                # ユーザーアクティビティレポート
                if ($realData.UserActivity -and $realData.UserActivity.Count -gt 0) {
                    Export-GuiReport -Data $realData.UserActivity -ReportName "日次レポート_ユーザーアクティビティ" -Action "Daily"
                }
                
                # メールボックス容量レポート
                if ($realData.MailboxCapacity -and $realData.MailboxCapacity.Count -gt 0) {
                    Export-GuiReport -Data $realData.MailboxCapacity -ReportName "日次レポート_メールボックス容量" -Action "Daily"
                }
                
                # セキュリティアラートレポート
                if ($realData.SecurityAlerts -and $realData.SecurityAlerts.Count -gt 0) {
                    Export-GuiReport -Data $realData.SecurityAlerts -ReportName "日次レポート_セキュリティアラート" -Action "Daily"
                }
                
                # MFA状況レポート
                if ($realData.MFAStatus -and $realData.MFAStatus.Count -gt 0) {
                    Export-GuiReport -Data $realData.MFAStatus -ReportName "日次レポート_MFA状況" -Action "Daily"
                }
                
                # サマリーレポート
                $summaryData = @([PSCustomObject]$realData.Summary)
                Export-GuiReport -Data $summaryData -ReportName "日次レポート_サマリー" -Action "Daily"
                
                $success = $true
            }
            "Weekly" { 
                $realData = Get-WeeklyReportRealData
                # 週次レポートも複数のデータセットを含むため、個別に出力
                if ($realData.GroupChangeReport -and $realData.GroupChangeReport.Count -gt 0) {
                    Export-GuiReport -Data $realData.GroupChangeReport -ReportName "週次レポート_グループ変更" -Action "Weekly"
                }
                if ($realData.ExternalSharingReport -and $realData.ExternalSharingReport.Count -gt 0) {
                    Export-GuiReport -Data $realData.ExternalSharingReport -ReportName "週次レポート_外部共有" -Action "Weekly"
                }
                if ($realData.LicenseChangeReport -and $realData.LicenseChangeReport.Count -gt 0) {
                    Export-GuiReport -Data $realData.LicenseChangeReport -ReportName "週次レポート_ライセンス変更" -Action "Weekly"
                }
                if ($realData.MFAStatusReport -and $realData.MFAStatusReport.Count -gt 0) {
                    Export-GuiReport -Data $realData.MFAStatusReport -ReportName "週次レポート_MFA状況" -Action "Weekly"
                }
                # サマリーレポート
                $summaryData = @([PSCustomObject]$realData.Summary)
                Export-GuiReport -Data $summaryData -ReportName "週次レポート_サマリー" -Action "Weekly"
                $success = $true
            }
            "Monthly" { 
                $realData = Get-MonthlyReportRealData
                # 月次レポートも複数のデータセットを含むため、個別に出力
                if ($realData.LicenseUsageReport -and $realData.LicenseUsageReport.Count -gt 0) {
                    Export-GuiReport -Data $realData.LicenseUsageReport -ReportName "月次レポート_ライセンス使用状況" -Action "Monthly"
                }
                if ($realData.PermissionChangeReport -and $realData.PermissionChangeReport.Count -gt 0) {
                    Export-GuiReport -Data $realData.PermissionChangeReport -ReportName "月次レポート_権限変更" -Action "Monthly"
                }
                if ($realData.ServiceHealthReport -and $realData.ServiceHealthReport.Count -gt 0) {
                    Export-GuiReport -Data $realData.ServiceHealthReport -ReportName "月次レポート_サービス健全性" -Action "Monthly"
                }
                if ($realData.CostAnalysisReport -and $realData.CostAnalysisReport.Count -gt 0) {
                    Export-GuiReport -Data $realData.CostAnalysisReport -ReportName "月次レポート_コスト分析" -Action "Monthly"
                }
                # サマリーレポート
                $summaryData = @([PSCustomObject]$realData.Summary)
                Export-GuiReport -Data $summaryData -ReportName "月次レポート_サマリー" -Action "Monthly"
                $success = $true
            }
            "Yearly" { 
                $realData = Get-YearlyReportRealData
                # 年次レポートも複数のデータセットを含むため、個別に出力
                if ($realData.LicenseTrendReport -and $realData.LicenseTrendReport.Count -gt 0) {
                    Export-GuiReport -Data $realData.LicenseTrendReport -ReportName "年次レポート_ライセンストレンド" -Action "Yearly"
                }
                if ($realData.IncidentStatistics -and $realData.IncidentStatistics.Count -gt 0) {
                    Export-GuiReport -Data $realData.IncidentStatistics -ReportName "年次レポート_インシデント統計" -Action "Yearly"
                }
                if ($realData.ComplianceReport -and $realData.ComplianceReport.Count -gt 0) {
                    Export-GuiReport -Data $realData.ComplianceReport -ReportName "年次レポート_コンプライアンス" -Action "Yearly"
                }
                if ($realData.AnnualCostReport -and $realData.AnnualCostReport.Count -gt 0) {
                    Export-GuiReport -Data $realData.AnnualCostReport -ReportName "年次レポート_年間コスト" -Action "Yearly"
                }
                # サマリーレポート
                $summaryData = @([PSCustomObject]$realData.Summary)
                Export-GuiReport -Data $summaryData -ReportName "年次レポート_サマリー" -Action "Yearly"
                $success = $true
            }
            
            # 分析レポート
            "License" {
                $realData = Get-LicenseAnalysisRealData
                $reportPath = Export-GuiReport -Data $realData -ReportName "ライセンス分析（実データ）" -Action "License"
                $success = $true
            }
            "Usage" {
                $realData = Get-M365UsageAnalysisData
                $reportPath = Export-GuiReport -Data $realData -ReportName "使用状況分析（実データ）" -Action "Usage"
                $success = $true
            }
            "Performance" {
                $realData = Get-PerformanceMonitoringData
                $reportPath = Export-GuiReport -Data $realData -ReportName "パフォーマンス監視（実データ）" -Action "Performance"
                $success = $true
            }
            "Security" {
                $realData = Get-M365SecurityAnalysisData
                $reportPath = Export-GuiReport -Data $realData -ReportName "セキュリティ分析（実データ）" -Action "Security"
                $success = $true
            }
            "Permissions" {
                $realData = Get-PermissionAuditData
                $reportPath = Export-GuiReport -Data $realData -ReportName "権限監査（実データ）" -Action "Permissions"
                $success = $true
            }
            
            # EntraID管理
            "EntraIDUsers" {
                $realData = Get-M365RealUserData
                $reportPath = Export-GuiReport -Data $realData -ReportName "Entra IDユーザー一覧（実データ）" -Action "EntraIDUsers"
                $success = $true
            }
            "EntraIDMFA" {
                $realData = Get-MFAStatusRealData
                $reportPath = Export-GuiReport -Data $realData -ReportName "Entra ID MFA状況（実データ）" -Action "EntraIDMFA"
                $success = $true
            }
            "ConditionalAccess" {
                $realData = Get-ConditionalAccessPoliciesData
                $reportPath = Export-GuiReport -Data $realData -ReportName "条件付きアクセス（実データ）" -Action "ConditionalAccess"
                $success = $true
            }
            "SignInLogs" {
                $realData = Get-SignInLogsData
                $reportPath = Export-GuiReport -Data $realData -ReportName "サインインログ（実データ）" -Action "SignInLogs"
                $success = $true
            }
            
            # Exchange Online管理
            "ExchangeMailbox" {
                $realData = Get-MailboxCapacityRealData
                $reportPath = Export-GuiReport -Data $realData -ReportName "Exchangeメールボックス（実データ）" -Action "ExchangeMailbox"
                $success = $true
            }
            "MailFlow" {
                $realData = Get-MailFlowAnalysisData
                $reportPath = Export-GuiReport -Data $realData -ReportName "メールフロー分析（実データ）" -Action "MailFlow"
                $success = $true
            }
            "AntiSpam" {
                $realData = Get-AntiSpamAnalysisData
                $reportPath = Export-GuiReport -Data $realData -ReportName "スパム対策分析（実データ）" -Action "AntiSpam"
                $success = $true
            }
            "MailDelivery" {
                $realData = Get-MailDeliveryAnalysisData
                $reportPath = Export-GuiReport -Data $realData -ReportName "メール配信分析（実データ）" -Action "MailDelivery"
                $success = $true
            }
            
            # Teams管理（ダミーデータ）
            "TeamsUsage" {
                $realData = Get-TeamsUsageData
                $reportPath = Export-GuiReport -Data $realData -ReportName "Teams使用状況（ダミーデータ）" -Action "TeamsUsage"
                $success = $true
            }
            "TeamsConfig" {
                $realData = Get-TeamsConfigAnalysisData
                $reportPath = Export-GuiReport -Data $realData -ReportName "Teams設定分析（ダミーデータ）" -Action "TeamsConfig"
                $success = $true
            }
            "MeetingQuality" {
                $realData = Get-MeetingQualityAnalysisData
                $reportPath = Export-GuiReport -Data $realData -ReportName "会議品質分析（ダミーデータ）" -Action "MeetingQuality"
                $success = $true
            }
            "TeamsApps" {
                $realData = Get-TeamsAppsAnalysisData
                $reportPath = Export-GuiReport -Data $realData -ReportName "Teamsアプリ分析（ダミーデータ）" -Action "TeamsApps"
                $success = $true
            }
            
            # OneDrive管理
            "OneDriveStorage" {
                $realData = Get-OneDriveStorageAnalysisData
                $reportPath = Export-GuiReport -Data $realData -ReportName "OneDriveストレージ（実データ）" -Action "OneDriveStorage"
                $success = $true
            }
            "OneDriveSharing" {
                $realData = Get-OneDriveSharingAnalysisData
                $reportPath = Export-GuiReport -Data $realData -ReportName "OneDrive共有分析（実データ）" -Action "OneDriveSharing"
                $success = $true
            }
            "SyncErrors" {
                $realData = Get-OneDriveSyncErrorAnalysisData
                $reportPath = Export-GuiReport -Data $realData -ReportName "OneDrive同期エラー（実データ）" -Action "SyncErrors"
                $success = $true
            }
            "ExternalSharing" {
                $realData = Get-OneDriveExternalSharingAnalysisData
                $reportPath = Export-GuiReport -Data $realData -ReportName "外部共有分析（実データ）" -Action "ExternalSharing"
                $success = $true
            }
            
            default {
                # 未対応の場合はフォールバックを実行
                $success = $false
            }
        }
        
        if ($success) {
            Write-Host "レポート生成完了: $ReportName" -ForegroundColor Green
            
            try {
                [System.Windows.Forms.MessageBox]::Show(
                    "$ReportName の生成が完了しました。`n`n実データを使用してレポートを生成しました。", 
                    "成功", 
                    [System.Windows.Forms.MessageBoxButtons]::OK, 
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            } catch {
                Write-Host "$ReportName の生成が完了しました。実データを使用してレポートを生成しました。" -ForegroundColor Green
            }
            return $true
        }
        else {
            throw "実データの取得に失敗しました"
        }
    }
    catch {
        Write-Host "実データ取得エラー: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "サンプルデータでレポートを生成します..." -ForegroundColor Yellow
        
        # フォールバックデータ生成
        try {
            & $FallbackDataGenerator
            
            try {
                [System.Windows.Forms.MessageBox]::Show(
                    "実データの取得に失敗したため、サンプルデータでレポートを生成しました。`n`nエラー: $($_.Exception.Message)", 
                    "警告", 
                    [System.Windows.Forms.MessageBoxButtons]::OK, 
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
            } catch {
                Write-Host "実データの取得に失敗したため、サンプルデータでレポートを生成しました。エラー: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        catch {
            try {
                [System.Windows.Forms.MessageBox]::Show(
                    "レポート生成に失敗しました。`n`nエラー: $($_.Exception.Message)", 
                    "エラー", 
                    [System.Windows.Forms.MessageBoxButtons]::OK, 
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            } catch {
                Write-Host "レポート生成に失敗しました。エラー: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

# レポート出力関数（PDF生成対応）
function Export-GuiReport {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Data,
        
        [Parameter(Mandatory = $true)]
        [string]$ReportName,
        
        [Parameter(Mandatory = $false)]
        [string]$Action = "General",
        
        [Parameter(Mandatory = $false)]
        [switch]$EnablePDF = $true
    )
    
    try {
        # ツールルートパスの取得
        $toolRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        
        # 出力先ディレクトリの決定
        $reportDir = switch ($Action) {
            "Daily" { "Reports\Daily" }
            "Weekly" { "Reports\Weekly" }
            "Monthly" { "Reports\Monthly" }
            "Yearly" { "Reports\Yearly" }
            "License" { "Analysis\License" }
            "UsageAnalysis" { "Analysis\Usage" }
            "PerformanceMonitor" { "Analysis\Performance" }
            "SecurityAnalysis" { "General" }
            "PermissionAudit" { "General" }
            "EntraIDUsers" { "Reports\EntraID\Users" }
            "ExchangeMailbox" { "Reports\Exchange\Mailbox" }
            "TeamsUsage" { "Reports\Teams\Usage" }
            "OneDriveStorage" { "Reports\OneDrive\Storage" }
            default { "General" }
        }
        
        $fullReportDir = Join-Path $toolRoot $reportDir
        if (-not (Test-Path $fullReportDir)) {
            New-Item -Path $fullReportDir -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        # CSV出力
        $csvPath = Join-Path $fullReportDir "${ReportName}_${timestamp}.csv"
        $Data | Export-Csv -Path $csvPath -Encoding UTF8BOM -NoTypeInformation
        
        # HTML出力
        $htmlPath = Join-Path $fullReportDir "${ReportName}_${timestamp}.html"
        $htmlContent = New-HTMLReport -Data $Data -ReportName $ReportName
        Set-Content -Path $htmlPath -Value $htmlContent -Encoding UTF8
        
        # PDF生成（オプション）
        $pdfPath = $null
        $pdfResult = $null
        
        if ($EnablePDF) {
            try {
                # PuppeteerPDFモジュールの動的インポート
                $pdfModulePath = Join-Path $PSScriptRoot "PuppeteerPDF.psm1"
                if (Test-Path $pdfModulePath) {
                    Import-Module $pdfModulePath -Force -ErrorAction SilentlyContinue
                    
                    $pdfPath = Join-Path $fullReportDir "${ReportName}_${timestamp}.pdf"
                    
                    # PDF生成設定
                    $pdfOptions = @{
                        format = "A4"
                        margin = @{
                            top = "20mm"
                            right = "15mm"
                            bottom = "20mm"
                            left = "15mm"
                        }
                        printBackground = $true
                        preferCSSPageSize = $false
                        displayHeaderFooter = $true
                        timeout = 30000
                        waitForNetworkIdle = $true
                    }
                    
                    Write-Host "PDF生成を開始します..." -ForegroundColor Yellow
                    $pdfResult = ConvertTo-PDFFromHTML -InputHtmlPath $htmlPath -OutputPdfPath $pdfPath -Options $pdfOptions
                    
                    if ($pdfResult.Success) {
                        Write-Host "PDF生成が完了しました: $pdfPath" -ForegroundColor Green
                        Write-Host "ファイルサイズ: $($pdfResult.FileSize)" -ForegroundColor Cyan
                        Write-Host "処理時間: $([math]::Round($pdfResult.ProcessingTime, 2))秒" -ForegroundColor Cyan
                    } else {
                        Write-Host "PDF生成に失敗しました" -ForegroundColor Red
                        $pdfPath = $null
                    }
                } else {
                    Write-Host "PuppeteerPDFモジュールが見つかりません。HTMLのみ生成します。" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "PDF生成でエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "HTMLとCSVのみ生成します。" -ForegroundColor Yellow
                $pdfPath = $null
            }
        }
        
        # ファイルを非同期で開く（GUIフリーズ防止）
        $openFileJobs = @()
        
        if (Test-Path $csvPath) {
            $openFileJobs += Start-Job -ScriptBlock {
                param($filePath)
                try {
                    if ($PSVersionTable.PSVersion.Major -ge 6) {
                        Start-Process $filePath -NoNewWindow -PassThru | Out-Null
                    } else {
                        Start-Process -FilePath $filePath -UseShellExecute -PassThru | Out-Null
                    }
                } catch {
                    Write-Warning "CSVファイルを開けませんでした: $($_.Exception.Message)"
                }
            } -ArgumentList $csvPath
        }
        
        if (Test-Path $htmlPath) {
            $openFileJobs += Start-Job -ScriptBlock {
                param($filePath)
                try {
                    if ($PSVersionTable.PSVersion.Major -ge 6) {
                        Start-Process $filePath -NoNewWindow -PassThru | Out-Null
                    } else {
                        Start-Process -FilePath $filePath -UseShellExecute -PassThru | Out-Null
                    }
                } catch {
                    Write-Warning "HTMLファイルを開けませんでした: $($_.Exception.Message)"
                }
            } -ArgumentList $htmlPath
        }
        
        if ($pdfPath -and (Test-Path $pdfPath)) {
            $openFileJobs += Start-Job -ScriptBlock {
                param($filePath)
                try {
                    if ($PSVersionTable.PSVersion.Major -ge 6) {
                        Start-Process $filePath -NoNewWindow -PassThru | Out-Null
                    } else {
                        Start-Process -FilePath $filePath -UseShellExecute -PassThru | Out-Null
                    }
                } catch {
                    Write-Warning "PDFファイルを開けませんでした: $($_.Exception.Message)"
                }
            } -ArgumentList $pdfPath
        }
        
        # ジョブのクリーンアップ（バックグラウンドで実行）
        if ($openFileJobs.Count -gt 0) {
            Start-Job -ScriptBlock {
                param($jobs)
                Start-Sleep -Seconds 10
                foreach ($job in $jobs) {
                    if ($job.State -eq 'Running') {
                        Stop-Job $job -Force
                    }
                    Remove-Job $job -Force
                }
            } -ArgumentList (,$openFileJobs) | Out-Null
        }
        
        return @{
            Success = $true
            CsvPath = $csvPath
            HtmlPath = $htmlPath
            PdfPath = $pdfPath
            PdfResult = $pdfResult
            DataCount = $Data.Count
        }
    }
    catch {
        Write-Log "レポート出力エラー: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# HTML生成関数（拡張版テンプレート対応）
function New-HTMLReport {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Data,
        
        [Parameter(Mandatory = $true)]
        [string]$ReportName
    )
    
    # テンプレートパスの確認
    $toolRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $templatePath = Join-Path $toolRoot "Templates\HTML\report-template.html"
    
    # テンプレートが存在する場合は使用、なければ従来の方法
    if (Test-Path $templatePath) {
        try {
            # テンプレート読み込み
            $template = Get-Content $templatePath -Raw -Encoding UTF8
            
            # ヘッダー生成
            $headers = ""
            if ($Data.Count -gt 0) {
                $properties = $Data[0].PSObject.Properties.Name
                foreach ($prop in $properties) {
                    $headers += "<th>$prop</th>`n"
                }
            }
            
            # データ行生成
            $tableData = ""
            foreach ($item in $Data) {
                $tableData += "<tr>"
                foreach ($prop in $properties) {
                    $value = $item.$prop
                    if ($value -eq $null) { $value = "" }
                    
                    # ステータスやレベルに応じてバッジ適用
                    $cellContent = switch -Regex ($value) {
                        "^(正常|アクティブ|有効|低|成功|完了)$" { "<span class='badge badge-success'>$value</span>" }
                        "^(警告|中|保留|確認中)$" { "<span class='badge badge-warning'>$value</span>" }
                        "^(エラー|非アクティブ|無効|高|失敗|異常)$" { "<span class='badge badge-danger'>$value</span>" }
                        "^(重大|緊急|ブロック)$" { "<span class='badge badge-danger'>$value</span>" }
                        "^(情報|通知)$" { "<span class='badge badge-info'>$value</span>" }
                        default { $value }
                    }
                    $tableData += "<td>$cellContent</td>"
                }
                $tableData += "</tr>`n"
            }
            
            # JavaScriptパス（相対パス）
            $jsPath = "../../Templates/JavaScript/report-functions.js"
            
            # テンプレート置換
            $html = $template -replace "{{REPORT_NAME}}", $ReportName
            $html = $html -replace "{{GENERATED_DATE}}", (Get-Date).ToString("yyyy年MM月dd日 HH:mm:ss")
            $html = $html -replace "{{TOTAL_RECORDS}}", $Data.Count
            $html = $html -replace "{{TABLE_HEADERS}}", "<tr>$headers</tr>"
            $html = $html -replace "{{TABLE_DATA}}", $tableData
            $html = $html -replace "{{PS_VERSION}}", $PSVersionTable.PSVersion
            $html = $html -replace "{{TOOL_VERSION}}", "v2.0"
            $html = $html -replace "{{JS_PATH}}", $jsPath
            
            return $html
        }
        catch {
            Write-Log "テンプレート使用エラー: $($_.Exception.Message)" -Level "Warning"
            # エラー時は従来の方法にフォールバック
        }
    }
    
    # 従来のHTML生成（フォールバック）
    $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ReportName - Microsoft 365統合管理ツール</title>
    <style>
        body { 
            font-family: 'Yu Gothic', 'Meiryo', 'MS Gothic', sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5;
        }
        .container {
            width: 95%;
            max-width: 100%;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            overflow-x: auto;
        }
        .header {
            background: linear-gradient(135deg, #0078d4, #106ebe);
            color: white;
            padding: 20px;
            margin: -20px -20px 20px -20px;
            border-radius: 8px 8px 0 0;
        }
        .table-wrapper {
            overflow-x: auto;
            margin-top: 20px;
        }
        table {
            width: auto;
            min-width: 100%;
            border-collapse: collapse;
            table-layout: auto;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 10px 15px;
            text-align: left;
            white-space: normal;
            word-wrap: break-word;
            max-width: 300px;
        }
        th {
            background-color: #0078d4;
            color: white;
            font-weight: bold;
        }
        tr:nth-child(even) {
            background-color: #f9f9f9;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        .footer {
            margin-top: 20px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            text-align: center;
            color: #666;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>$ReportName</h1>
            <p>生成日時: $(Get-Date -Format 'yyyy年MM月dd日 HH:mm:ss')</p>
            <p>データ件数: $($Data.Count) 件</p>
        </div>
"@

    if ($Data.Count -gt 0) {
        # テーブルヘッダー
        $htmlContent += "<div class='table-wrapper'><table><thead><tr>"
        $properties = $Data[0].PSObject.Properties.Name
        foreach ($prop in $properties) {
            $htmlContent += "<th>$prop</th>"
        }
        $htmlContent += "</tr></thead><tbody>"
        
        # テーブルデータ
        foreach ($item in $Data) {
            $htmlContent += "<tr>"
            foreach ($prop in $properties) {
                $value = $item.$prop
                if ($value -eq $null) { $value = "" }
                $htmlContent += "<td>$value</td>"
            }
            $htmlContent += "</tr>"
        }
        $htmlContent += "</tbody></table></div>"
    } else {
        $htmlContent += "<p>データがありません。</p>"
    }

    $htmlContent += @"
        <div class="footer">
            <p>Microsoft 365統合管理ツール - PowerShell $($PSVersionTable.PSVersion)</p>
        </div>
    </div>
</body>
</html>
"@

    return $htmlContent
}

# エクスポート
Export-ModuleMember -Function @(
    'Invoke-GuiReportGeneration',
    'Export-GuiReport',
    'New-HTMLReport'
)