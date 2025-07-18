# ================================================================================
# マルチフォーマットレポートジェネレーター
# CSV、HTML、PDF形式でレポートを生成し、ポップアップ表示機能を提供
# ================================================================================

Import-Module "$PSScriptRoot\EnhancedHTMLTemplateEngine.psm1" -Force

function Convert-DataToJapaneseCSV {
    param(
        [array]$Data,
        [string]$ReportType
    )
    
    if (-not $Data -or $Data.Count -eq 0) {
        return @()
    }
    
    # 日本語フィールドマッピング
    $fieldMapping = @{
        "ServiceName" = "サービス名"
        "ActiveUsersCount" = "アクティブユーザー数"
        "TotalActivityCount" = "総アクティビティ数"
        "NewUsersCount" = "新規ユーザー数"
        "ErrorCount" = "エラー数"
        "ServiceStatus" = "サービス状況"
        "PerformanceScore" = "パフォーマンススコア"
        "LastCheck" = "最終チェック"
        "Status" = "ステータス"
        "UserName" = "ユーザー名"
        "UserPrincipalName" = "ユーザープリンシパル名"
        "DisplayName" = "表示名"
        "Email" = "メールアドレス"
        "Department" = "部署"
        "JobTitle" = "役職"
        "AccountStatus" = "アカウント状況"
        "LicenseStatus" = "ライセンス状況"
        "CreationDate" = "作成日"
        "LastSignIn" = "最終サインイン"
        "DailyLogins" = "日次ログイン"
        "DailyEmails" = "日次メール"
        "TeamsActivity" = "Teamsアクティビティ"
        "ActivityLevel" = "アクティビティレベル"
        "ActivityScore" = "アクティビティスコア"
        "LicenseName" = "ライセンス名"
        "SkuId" = "SKU ID"
        "PurchasedQuantity" = "購入数"
        "AssignedQuantity" = "割り当て済み"
        "AvailableQuantity" = "利用可能数"
        "UsageRate" = "利用率"
        "MonthlyUnitPrice" = "月額単価"
        "MonthlyCost" = "月額コスト"
        "MFAStatus" = "MFA状況"
        "AuthenticationMethod" = "認証方法"
        "FallbackMethod" = "フォールバック方法"
        "LastMFASetupDate" = "最終MFA設定日"
        "Compliance" = "コンプライアンス"
        "RiskLevel" = "リスクレベル"
        "LastAccess" = "最終アクセス"
        "MonthlyMeetingParticipation" = "月次会議参加"
        "MonthlyChatCount" = "月次チャット数"
        "StorageUsedMB" = "使用ストレージ(MB)"
        "AppUsageCount" = "アプリ使用数"
        "UsageLevel" = "使用レベル"
    }
    
    # データの各アイテムをマッピング
    $japaneseData = @()
    foreach ($item in $Data) {
        $japaneseItem = New-Object PSObject
        foreach ($property in $item.PSObject.Properties) {
            $japaneseFieldName = $fieldMapping[$property.Name]
            if ($japaneseFieldName) {
                $japaneseItem | Add-Member -MemberType NoteProperty -Name $japaneseFieldName -Value $property.Value
            } else {
                $japaneseItem | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
            }
        }
        $japaneseData += $japaneseItem
    }
    
    return $japaneseData
}

function Export-MultiFormatReport {
    <#
    .SYNOPSIS
    Exports report data in multiple formats (CSV, HTML, PDF) with popup display
    #>
    param(
        [array]$Data,
        [string]$ReportName,
        [string]$ReportType,
        [string]$BaseDirectory = $null,
        [switch]$ShowPopup = $true
    )
    
    if (-not $Data -or $Data.Count -eq 0) {
        Write-Host "⚠️ 出力するデータがありません" -ForegroundColor Yellow
        return $null
    }
    
    try {
        $timestamp = Get-Date -Format "yyyyMMddHHmm"
        
        # レポートタイプに応じた出力ディレクトリを決定
        $outputDir = Get-ReportOutputDirectory -ReportType $ReportType -BaseDirectory $BaseDirectory
        
        if (-not (Test-Path $outputDir)) {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }
        
        # ファイルパスを生成
        $csvPath = Join-Path $outputDir "${ReportName}_${timestamp}.csv"
        $htmlPath = Join-Path $outputDir "${ReportName}_${timestamp}.html"
        $pdfPath = Join-Path $outputDir "${ReportName}_${timestamp}.pdf"
        
        Write-Host "📁 出力ディレクトリ: $outputDir" -ForegroundColor Cyan
        Write-Host "📄 ファイル生成中..." -ForegroundColor Yellow
        
        # CSV出力（日本語ヘッダー対応）
        Write-Host "  📊 CSV出力中..." -ForegroundColor Gray
        $csvData = Convert-DataToJapaneseCSV -Data $Data -ReportType $ReportType
        $csvData | Export-Csv -Path $csvPath -Encoding UTF8BOM -NoTypeInformation
        Write-Host "  ✅ CSV出力完了: $(Split-Path $csvPath -Leaf)" -ForegroundColor Green
        
        # HTML出力（インタラクティブ機能付き）
        Write-Host "  🌐 HTML出力中..." -ForegroundColor Gray
        $htmlContent = Generate-InteractiveHTMLReport -Data $Data -ReportType $ReportType -Title $ReportName -OutputPath $htmlPath
        Write-Host "  ✅ HTML出力完了: $(Split-Path $htmlPath -Leaf)" -ForegroundColor Green
        
        # PDF出力（HTML to PDF変換）
        Write-Host "  📄 PDF出力中..." -ForegroundColor Gray
        $pdfGenerated = Generate-PDFReport -HtmlContent $htmlContent -OutputPath $pdfPath -Title $ReportName
        if ($pdfGenerated) {
            Write-Host "  ✅ PDF出力完了: $(Split-Path $pdfPath -Leaf)" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️ PDF出力をスキップしました" -ForegroundColor Yellow
        }
        
        # ファイルサイズの確認
        $csvSize = (Get-Item $csvPath).Length
        $htmlSize = (Get-Item $htmlPath).Length
        $pdfSize = if (Test-Path $pdfPath) { (Get-Item $pdfPath).Length } else { 0 }
        
        Write-Host "`n📊 出力結果:" -ForegroundColor Cyan
        Write-Host "  📁 出力ディレクトリ: $outputDir" -ForegroundColor White
        Write-Host "  📊 CSV: $(Split-Path $csvPath -Leaf) ($csvSize bytes)" -ForegroundColor White
        Write-Host "  🌐 HTML: $(Split-Path $htmlPath -Leaf) ($htmlSize bytes)" -ForegroundColor White
        if ($pdfSize -gt 0) {
            Write-Host "  📄 PDF: $(Split-Path $pdfPath -Leaf) ($pdfSize bytes)" -ForegroundColor White
        }
        
        # ポップアップ表示
        if ($ShowPopup) {
            Show-ReportPopup -CsvPath $csvPath -HtmlPath $htmlPath -PdfPath $pdfPath -ReportName $ReportName -DataCount $Data.Count
        }
        
        return @{
            CsvPath = $csvPath
            HtmlPath = $htmlPath
            PdfPath = if (Test-Path $pdfPath) { $pdfPath } else { $null }
            OutputDirectory = $outputDir
            DataCount = $Data.Count
        }
    }
    catch {
        Write-Host "❌ マルチフォーマット出力エラー: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Get-ReportOutputDirectory {
    param(
        [string]$ReportType,
        [string]$BaseDirectory
    )
    
    $directoryMapping = @{
        "DailyReport" = "Regularreports"
        "WeeklyReport" = "Regularreports"
        "MonthlyReport" = "Regularreports"
        "YearlyReport" = "Regularreports"
        "TestExecution" = "Regularreports"
        "Users" = "EntraIDManagement"
        "MFAStatus" = "EntraIDManagement"
        "ConditionalAccess" = "EntraIDManagement"
        "SignInLogs" = "EntraIDManagement"
        "LicenseAnalysis" = "Analyticreport"
        "UsageAnalysis" = "Analyticreport"
        "PerformanceAnalysis" = "Analyticreport"
        "SecurityAnalysis" = "Analyticreport"
        "PermissionAudit" = "Analyticreport"
        "MailboxAnalysis" = "ExchangeOnlineManagement"
        "MailFlowAnalysis" = "ExchangeOnlineManagement"
        "SpamProtectionAnalysis" = "ExchangeOnlineManagement"
        "MailDeliveryAnalysis" = "ExchangeOnlineManagement"
        "TeamsUsage" = "TeamsManagement"
        "TeamsSettings" = "TeamsManagement"
        "MeetingQuality" = "TeamsManagement"
        "TeamsAppAnalysis" = "TeamsManagement"
        "OneDriveAnalysis" = "OneDriveManagement"
        "SharingAnalysis" = "OneDriveManagement"
        "SyncErrorAnalysis" = "OneDriveManagement"
        "ExternalSharingAnalysis" = "OneDriveManagement"
    }
    
    $subDirectory = $directoryMapping[$ReportType]
    if (-not $subDirectory) {
        $subDirectory = "General"
    }
    
    # BaseDirectoryがnullまたは空の場合、相対パスを設定
    if ([string]::IsNullOrEmpty($BaseDirectory)) {
        # プロジェクトルートから相対的にReportsディレクトリを設定
        $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $BaseDirectory = Join-Path $projectRoot "Reports"
    }
    
    return Join-Path $BaseDirectory $subDirectory
}

function Generate-PDFReport {
    param(
        [string]$HtmlContent,
        [string]$OutputPath,
        [string]$Title
    )
    
    # HTMLコンテンツをPDFに変換（簡易版）
    # 実際の実装では、wkhtmltopdfやPuppeteerを使用することを推奨
    try {
        # PDF生成用の簡易HTMLファイルを作成
        $tempHtmlPath = [System.IO.Path]::GetTempFileName() + ".html"
        
        # PDF用にHTMLを最適化（JavaScriptを除去し、印刷スタイルを適用）
        $pdfHtmlContent = $HtmlContent -replace '<script.*?</script>', '' -replace 'class="actions-bar"[^>]*>.*?</div>', ''
        $pdfHtmlContent = $pdfHtmlContent -replace '<div class="pdf-controls">.*?</div>', ''
        
        $pdfHtmlContent | Out-File -FilePath $tempHtmlPath -Encoding UTF8
        
        # wkhtmltopdfが利用可能かチェック
        $wkhtmltopdfPath = Get-Command "wkhtmltopdf" -ErrorAction SilentlyContinue
        if (-not $wkhtmltopdfPath) {
            $wkhtmltopdfPath = Get-Command "C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe" -ErrorAction SilentlyContinue
        }
        if ($wkhtmltopdfPath) {
            $arguments = @(
                "--page-size", "A4",
                "--orientation", "Landscape",
                "--margin-top", "0.5in",
                "--margin-right", "0.5in",
                "--margin-bottom", "0.5in",
                "--margin-left", "0.5in",
                "--encoding", "UTF-8",
                "--javascript-delay", "1000",
                $tempHtmlPath,
                $OutputPath
            )
            
            Start-Process -FilePath $wkhtmltopdfPath.Source -ArgumentList $arguments -Wait -NoNewWindow
            
            if (Test-Path $OutputPath) {
                Remove-Item $tempHtmlPath -Force
                return $true
            }
        }
        
        # wkhtmltopdfが利用できない場合、PDF生成をスキップ
        Write-Host "  ℹ️ wkhtmltopdfが見つかりません。PDF生成をスキップしました" -ForegroundColor Yellow
        Write-Host "  💡 PDFを生成するには、wkhtmltopdfをインストールしてください" -ForegroundColor Yellow
        
        Remove-Item $tempHtmlPath -Force -ErrorAction SilentlyContinue
        return $false
    }
    catch {
        Write-Host "  ⚠️ PDF生成エラー: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

function Show-ReportPopup {
    param(
        [string]$CsvPath,
        [string]$HtmlPath,
        [string]$PdfPath,
        [string]$ReportName,
        [int]$DataCount
    )
    
    try {
        # Windows Forms を使用してポップアップ表示
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        # Windows Forms初期設定は既にメインスクリプトで完了済み
        
        # メインフォームを作成
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "レポート生成完了"
        $form.Size = New-Object System.Drawing.Size(600, 400)
        $form.StartPosition = "CenterScreen"
        $form.FormBorderStyle = "FixedDialog"
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false
        $form.Icon = [System.Drawing.SystemIcons]::Information
        
        # アイコンラベル
        $iconLabel = New-Object System.Windows.Forms.Label
        $iconLabel.Text = "✅"
        $iconLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 24)
        $iconLabel.ForeColor = [System.Drawing.Color]::Green
        $iconLabel.Location = New-Object System.Drawing.Point(50, 30)
        $iconLabel.Size = New-Object System.Drawing.Size(50, 50)
        $form.Controls.Add($iconLabel)
        
        # タイトルラベル
        $titleLabel = New-Object System.Windows.Forms.Label
        $titleLabel.Text = "レポート生成完了"
        $titleLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 16, [System.Drawing.FontStyle]::Bold)
        $titleLabel.Location = New-Object System.Drawing.Point(120, 40)
        $titleLabel.Size = New-Object System.Drawing.Size(400, 30)
        $form.Controls.Add($titleLabel)
        
        # 情報ラベル
        $infoLabel = New-Object System.Windows.Forms.Label
        $infoLabel.Text = "$ReportName が正常に生成されました`n$DataCount 件のデータを出力しました"
        $infoLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10)
        $infoLabel.Location = New-Object System.Drawing.Point(50, 90)
        $infoLabel.Size = New-Object System.Drawing.Size(500, 40)
        $form.Controls.Add($infoLabel)
        
        # ファイル一覧
        $fileListLabel = New-Object System.Windows.Forms.Label
        $fileListLabel.Text = "生成されたファイル:"
        $fileListLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10, [System.Drawing.FontStyle]::Bold)
        $fileListLabel.Location = New-Object System.Drawing.Point(50, 140)
        $fileListLabel.Size = New-Object System.Drawing.Size(200, 20)
        $form.Controls.Add($fileListLabel)
        
        # CSVファイルボタン
        $csvButton = New-Object System.Windows.Forms.Button
        $csvButton.Text = "📊 CSV を開く"
        $csvButton.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10)
        $csvButton.Location = New-Object System.Drawing.Point(50, 170)
        $csvButton.Size = New-Object System.Drawing.Size(150, 35)
        $csvButton.FlatStyle = "Flat"
        $csvButton.BackColor = [System.Drawing.Color]::LightBlue
        $csvButton.Add_Click({
            Start-Process $CsvPath
        })
        $form.Controls.Add($csvButton)
        
        # HTMLファイルボタン
        $htmlButton = New-Object System.Windows.Forms.Button
        $htmlButton.Text = "🌐 HTML を開く"
        $htmlButton.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10)
        $htmlButton.Location = New-Object System.Drawing.Point(220, 170)
        $htmlButton.Size = New-Object System.Drawing.Size(150, 35)
        $htmlButton.FlatStyle = "Flat"
        $htmlButton.BackColor = [System.Drawing.Color]::LightGreen
        $htmlButton.Add_Click({
            Start-Process $HtmlPath
        })
        $form.Controls.Add($htmlButton)
        
        # PDFファイルボタン（PDFが存在する場合のみ）
        if ($PdfPath -and (Test-Path $PdfPath)) {
            $pdfButton = New-Object System.Windows.Forms.Button
            $pdfButton.Text = "📄 PDF を開く"
            $pdfButton.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10)
            $pdfButton.Location = New-Object System.Drawing.Point(390, 170)
            $pdfButton.Size = New-Object System.Drawing.Size(150, 35)
            $pdfButton.FlatStyle = "Flat"
            $pdfButton.BackColor = [System.Drawing.Color]::LightCoral
            $pdfButton.Add_Click({
                Start-Process $PdfPath
            })
            $form.Controls.Add($pdfButton)
        }
        
        # フォルダを開くボタン
        $folderButton = New-Object System.Windows.Forms.Button
        $folderButton.Text = "📁 フォルダを開く"
        $folderButton.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10)
        $folderButton.Location = New-Object System.Drawing.Point(50, 220)
        $folderButton.Size = New-Object System.Drawing.Size(150, 35)
        $folderButton.FlatStyle = "Flat"
        $folderButton.BackColor = [System.Drawing.Color]::LightGray
        $folderButton.Add_Click({
            Start-Process (Split-Path $HtmlPath -Parent)
        })
        $form.Controls.Add($folderButton)
        
        # 閉じるボタン
        $closeButton = New-Object System.Windows.Forms.Button
        $closeButton.Text = "閉じる"
        $closeButton.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10)
        $closeButton.Location = New-Object System.Drawing.Point(450, 310)
        $closeButton.Size = New-Object System.Drawing.Size(100, 35)
        $closeButton.FlatStyle = "Flat"
        $closeButton.BackColor = [System.Drawing.Color]::LightSteelBlue
        $closeButton.Add_Click({
            $form.Close()
        })
        $form.Controls.Add($closeButton)
        
        # 自動的にHTMLファイルを開く
        Start-Process $HtmlPath
        
        # フォームを表示
        $form.ShowDialog() | Out-Null
    }
    catch {
        Write-Host "⚠️ ポップアップ表示エラー: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "📁 出力ファイル:" -ForegroundColor Cyan
        Write-Host "  CSV: $CsvPath" -ForegroundColor White
        Write-Host "  HTML: $HtmlPath" -ForegroundColor White
        if ($PdfPath -and (Test-Path $PdfPath)) {
            Write-Host "  PDF: $PdfPath" -ForegroundColor White
        }
        
        # フォールバック: ファイルを直接開く
        Start-Process $HtmlPath
        Start-Process $CsvPath
    }
}

Export-ModuleMember -Function Export-MultiFormatReport, Get-ReportOutputDirectory