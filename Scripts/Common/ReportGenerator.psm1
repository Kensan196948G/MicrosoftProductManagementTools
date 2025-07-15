# ================================================================================
# ReportGenerator.psm1
# HTML/CSVレポート生成モジュール
# ITSM/ISO27001/27002準拠
# ================================================================================

Import-Module "$PSScriptRoot\Logging.psm1" -Force

function New-ReportDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Daily", "Weekly", "Monthly", "Yearly")]
        [string]$ReportType
    )
    
    $reportsRoot = Join-Path $PSScriptRoot "..\..\Reports"
    $reportDir = Join-Path $reportsRoot $ReportType
    
    if (-not (Test-Path $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
        Write-Log "レポートディレクトリを作成しました: $reportDir" -Level "Info"
    }
    
    return $reportDir
}

function New-HTMLReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $false)]
        [array]$DataSections = @(),
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    try {
        $timestamp = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
        
        $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$Title</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            min-height: 100vh;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background: white; 
            padding: 30px; 
            border-radius: 12px; 
            box-shadow: 0 10px 30px rgba(0,0,0,0.1); 
            position: relative;
            overflow: hidden;
        }
        .container::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: linear-gradient(90deg, #0078d4, #00bcf2, #40e0d0);
        }
        .header { 
            text-align: center; 
            padding-bottom: 25px; 
            margin-bottom: 35px; 
            position: relative;
        }
        .title { 
            color: #0078d4; 
            font-size: 32px; 
            margin-bottom: 10px; 
            font-weight: 600;
            letter-spacing: -0.5px;
        }
        .timestamp { 
            color: #666; 
            font-size: 14px; 
            background: #f8f9fa;
            padding: 8px 16px;
            border-radius: 20px;
            display: inline-block;
            border: 1px solid #e9ecef;
        }
        .section { 
            margin-bottom: 35px; 
            background: #ffffff;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        }
        .section-title { 
            color: white; 
            font-size: 18px; 
            padding: 15px 20px; 
            margin: 0;
            background: linear-gradient(135deg, #0078d4, #0056b3);
            font-weight: 600;
        }
        .summary { 
            background: #f8f9fa; 
            padding: 20px; 
            border-left: 4px solid #0078d4;
            margin: 0;
        }
        .summary p {
            margin: 8px 0;
            font-size: 14px;
        }
        .alert { 
            padding: 15px; 
            border-radius: 6px; 
            margin: 15px 20px; 
            border-left: 4px solid;
            font-weight: 500;
        }
        .alert-danger { 
            background: #f8d7da; 
            border-left-color: #dc3545; 
            color: #721c24; 
        }
        .alert-warning { 
            background: #fff3cd; 
            border-left-color: #ffc107; 
            color: #856404; 
        }
        .alert-info { 
            background: #d1ecf1; 
            border-left-color: #17a2b8; 
            color: #0c5460; 
        }
        .table-wrapper {
            overflow-x: auto;
            margin: 0;
        }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            font-size: 14px;
            margin: 0;
        }
        th, td { 
            padding: 12px 15px; 
            text-align: left; 
            border-bottom: 1px solid #e9ecef;
            vertical-align: top;
        }
        th { 
            background: linear-gradient(135deg, #0078d4, #0056b3); 
            color: white; 
            font-weight: 600;
            font-size: 13px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        tr:nth-child(even) { 
            background: #f8f9fa; 
        }
        tr:hover {
            background: #e3f2fd;
            transition: background-color 0.2s ease;
        }
        .footer { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 40px; 
            border-top: 1px solid #e9ecef; 
            padding-top: 20px; 
            background: #f8f9fa;
            margin-left: -30px;
            margin-right: -30px;
            margin-bottom: -30px;
            padding-left: 30px;
            padding-right: 30px;
            padding-bottom: 30px;
        }
        @media (max-width: 768px) {
            body { padding: 10px; }
            .container { padding: 20px; }
            .title { font-size: 24px; }
            th, td { padding: 8px 10px; font-size: 12px; }
            .section-title { font-size: 16px; }
        }
        @media print {
            /* PDF/印刷専用設定 */
            * {
                -webkit-print-color-adjust: exact !important;
                print-color-adjust: exact !important;
            }
            
            body { 
                background: white !important; 
                font-size: 10pt !important;
                line-height: 1.4 !important;
                margin: 0 !important;
                padding: 0 !important;
            }
            
            .container { 
                box-shadow: none !important; 
                max-width: 100% !important;
                margin: 0 !important;
                padding: 10mm !important;
                border-radius: 0 !important;
            }
            
            .container::before {
                display: none !important;
            }
            
            .header {
                page-break-after: avoid !important;
                margin-bottom: 5mm !important;
                padding-bottom: 5mm !important;
            }
            
            .title {
                font-size: 18pt !important;
                margin-bottom: 3mm !important;
                page-break-after: avoid !important;
            }
            
            .timestamp {
                font-size: 9pt !important;
                background: #f8f9fa !important;
                padding: 2mm 4mm !important;
                border: 1px solid #e9ecef !important;
                border-radius: 3mm !important;
            }
            
            .section {
                page-break-inside: avoid !important;
                margin-bottom: 5mm !important;
                box-shadow: none !important;
            }
            
            .section-title {
                background: linear-gradient(135deg, #0078d4, #0056b3) !important;
                color: white !important;
                font-size: 12pt !important;
                padding: 3mm 5mm !important;
                page-break-after: avoid !important;
            }
            
            .summary {
                background: #f8f9fa !important;
                padding: 3mm !important;
                border-left: 2mm solid #0078d4 !important;
                font-size: 9pt !important;
                page-break-inside: avoid !important;
            }
            
            .alert {
                padding: 3mm !important;
                margin: 3mm 5mm !important;
                border-left: 2mm solid !important;
                font-size: 9pt !important;
                page-break-inside: avoid !important;
            }
            
            .alert-danger {
                background: #f8d7da !important;
                border-left-color: #dc3545 !important;
                color: #721c24 !important;
            }
            
            .alert-warning {
                background: #fff3cd !important;
                border-left-color: #ffc107 !important;
                color: #856404 !important;
            }
            
            .alert-info {
                background: #d1ecf1 !important;
                border-left-color: #17a2b8 !important;
                color: #0c5460 !important;
            }
            
            .table-wrapper {
                overflow: visible !important;
                margin: 0 !important;
            }
            
            table {
                width: 100% !important;
                border-collapse: collapse !important;
                font-size: 8pt !important;
                margin: 0 !important;
                page-break-inside: auto !important;
            }
            
            th {
                background: linear-gradient(135deg, #0078d4, #0056b3) !important;
                color: white !important;
                font-weight: bold !important;
                font-size: 8pt !important;
                padding: 2mm 3mm !important;
                text-align: left !important;
                border: 1px solid #ddd !important;
                page-break-after: avoid !important;
                page-break-inside: avoid !important;
            }
            
            td {
                padding: 2mm 3mm !important;
                border: 1px solid #ddd !important;
                font-size: 8pt !important;
                page-break-inside: avoid !important;
                word-wrap: break-word !important;
                max-width: 40mm !important;
            }
            
            tbody tr {
                page-break-inside: avoid !important;
                page-break-after: auto !important;
            }
            
            tbody tr:nth-child(even) {
                background: #f8f9fa !important;
            }
            
            .footer {
                page-break-before: avoid !important;
                font-size: 8pt !important;
                color: #666 !important;
                border-top: 1px solid #e9ecef !important;
                padding-top: 3mm !important;
                margin-top: 5mm !important;
                text-align: center !important;
            }
            
            /* 改ページ制御 */
            .page-break {
                page-break-before: always !important;
            }
            
            .no-break {
                page-break-inside: avoid !important;
            }
            
            /* 孤立行・寡婦行の制御 */
            p {
                orphans: 2 !important;
                widows: 2 !important;
            }
            
            /* テーブルのヘッダー・フッター表示 */
            thead {
                display: table-header-group !important;
            }
            
            tfoot {
                display: table-footer-group !important;
            }
            
            tbody {
                display: table-row-group !important;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="title">$Title</div>
            <div class="timestamp">生成日時: $timestamp</div>
        </div>
"@

        if ($DataSections.Count -gt 0) {
            foreach ($section in $DataSections) {
                $htmlContent += "<div class='section'>"
                $htmlContent += "<div class='section-title'>$($section.Title)</div>"
                
                # サマリー表示
                if ($section.Summary) {
                    $htmlContent += "<div class='summary'>"
                    if ($section.Summary -is [array]) {
                        foreach ($item in $section.Summary) {
                            $htmlContent += "<p><strong>$($item.Label):</strong> $($item.Value)</p>"
                        }
                    }
                    $htmlContent += "</div>"
                }
                
                # アラート表示
                if ($section.Alerts) {
                    foreach ($alert in $section.Alerts) {
                        $alertClass = switch ($alert.Type) {
                            "Danger" { "alert-danger" }
                            "Warning" { "alert-warning" }
                            default { "alert-info" }
                        }
                        $htmlContent += "<div class='alert $alertClass'>$($alert.Message)</div>"
                    }
                }
                
                # データテーブル表示
                if ($section.Data -and $section.Data.Count -gt 0) {
                    $htmlContent += "<div class='table-wrapper'><table><thead><tr>"
                    
                    # ヘッダー生成
                    $properties = $section.Data[0].PSObject.Properties.Name
                    foreach ($prop in $properties) {
                        $htmlContent += "<th>$prop</th>"
                    }
                    $htmlContent += "</tr></thead><tbody>"
                    
                    # データ行生成
                    foreach ($row in $section.Data) {
                        $htmlContent += "<tr>"
                        foreach ($prop in $properties) {
                            $value = $row.$prop
                            if ($null -eq $value) { $value = "" }
                            # HTMLエスケープ処理
                            $value = $value -replace "&", "&amp;" -replace "<", "&lt;" -replace ">", "&gt;" -replace '"', "&quot;"
                            $htmlContent += "<td>$value</td>"
                        }
                        $htmlContent += "</tr>"
                    }
                    $htmlContent += "</tbody></table></div>"
                }
                
                $htmlContent += "</div>"
            }
        }
        else {
            $htmlContent += "<div class='section'>"
            $htmlContent += "<p>レポートデータを生成中です...</p>"
            $htmlContent += "<p>このレポートは Microsoft 365 運用管理ツールによって自動生成されました。</p>"
            $htmlContent += "</div>"
        }

        $htmlContent += @"
        <div class="footer">
            <p>Microsoft製品運用管理ツール - ITSM/ISO27001/27002準拠</p>
            <p>© 2025 All Rights Reserved</p>
        </div>
    </div>
</body>
</html>
"@

        # ファイル出力
        $outputDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }
        
        $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        
        Write-Log "HTMLレポートを生成しました: $OutputPath" -Level "Info"
        return $OutputPath
    }
    catch {
        Write-Log "HTMLレポート生成エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

function New-CSVReport {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    try {
        if ($Data -and $Data.Count -gt 0) {
            # Windows環境でのCSV文字化け対策：BOM付きUTF-8で出力
            $csvContent = $Data | ConvertTo-Csv -NoTypeInformation
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllLines($OutputPath, $csvContent, $utf8WithBom)
            Write-Log "CSVレポートを生成しました (BOM付きUTF-8): $OutputPath" -Level "Info"
        }
        else {
            $noDataContent = @('"Status"', '"No Data Available"')
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllLines($OutputPath, $noDataContent, $utf8WithBom)
            Write-Log "データなしのCSVレポートを生成しました (BOM付きUTF-8): $OutputPath" -Level "Info"
        }
        
        return $OutputPath
    }
    catch {
        Write-Log "CSVレポート生成エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

function New-SummaryStatistics {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$CountFields = @{}
    )
    
    $summary = @()
    
    try {
        if ($Data -and $Data.Count -gt 0) {
            foreach ($field in $CountFields.Keys) {
                $config = $CountFields[$field]
                $count = 0
                
                if ($config.Filter) {
                    $count = ($Data | Where-Object $config.Filter).Count
                }
                else {
                    $count = $Data.Count
                }
                
                $summary += @{
                    Label = $field
                    Value = $count
                    Risk = $config.Risk
                }
            }
        }
        else {
            $summary += @{
                Label = "データ"
                Value = "なし"
                Risk = "低"
            }
        }
        
        return $summary
    }
    catch {
        Write-Log "統計サマリー生成エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

function New-EnhancedHTMLReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportName,
        
        [Parameter(Mandatory = $true)]
        [array]$Data,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = "",
        
        [Parameter(Mandatory = $false)]
        [hashtable]$CustomSettings = @{}
    )
    
    try {
        # テンプレートファイルを読み込み
        $templatePath = Join-Path $PSScriptRoot "..\..\Templates\HTML\report-template.html"
        $jsPath = Join-Path $PSScriptRoot "..\..\Templates\JavaScript\report-functions.js"
        
        if (-not (Test-Path $templatePath)) {
            Write-Log "HTMLテンプレートファイルが見つかりません: $templatePath" -Level "Warning"
            # フォールバック: 従来のHTML生成を使用
            return New-HTMLReport -Title $ReportName -DataSections @(@{Title = $ReportName; Data = $Data}) -OutputPath $OutputPath
        }
        
        # テンプレートを読み込み
        $htmlTemplate = Get-Content $templatePath -Raw -Encoding UTF8
        
        # データをHTMLテーブル形式に変換
        $tableHeaders = ""
        $tableData = ""
        
        if ($Data -and $Data.Count -gt 0) {
            # ヘッダー生成
            $properties = $Data[0].PSObject.Properties.Name
            $tableHeaders = "<tr>"
            foreach ($prop in $properties) {
                $tableHeaders += "<th>$([System.Web.HttpUtility]::HtmlEncode($prop))</th>"
            }
            $tableHeaders += "</tr>"
            
            # データ行生成（最初の1000行のみ、残りはJavaScriptで制御）
            $displayData = $Data | Select-Object -First 1000
            foreach ($row in $displayData) {
                $tableData += "<tr>"
                foreach ($prop in $properties) {
                    $value = $row.$prop
                    if ($null -eq $value) { $value = "" }
                    
                    # 長いコンテンツの検出
                    $cellClass = ""
                    if ($value.ToString().Length -gt 50) {
                        $cellClass = " class='long-content'"
                    }
                    
                    # HTMLエスケープ
                    $escapedValue = [System.Web.HttpUtility]::HtmlEncode($value.ToString())
                    
                    # バッジスタイルの適用
                    if ($value -match "^(成功|OK|有効|アクティブ)$") {
                        $escapedValue = "<span class='badge badge-success'>$escapedValue</span>"
                    }
                    elseif ($value -match "^(警告|注意|期限切れ間近)$") {
                        $escapedValue = "<span class='badge badge-warning'>$escapedValue</span>"
                    }
                    elseif ($value -match "^(エラー|失敗|無効|非アクティブ)$") {
                        $escapedValue = "<span class='badge badge-danger'>$escapedValue</span>"
                    }
                    elseif ($value -match "^(情報|その他)$") {
                        $escapedValue = "<span class='badge badge-info'>$escapedValue</span>"
                    }
                    
                    $tableData += "<td$cellClass>$escapedValue</td>"
                }
                $tableData += "</tr>"
            }
        }
        else {
            $tableHeaders = "<tr><th>データがありません</th></tr>"
            $tableData = "<tr><td>表示するデータがありません</td></tr>"
        }
        
        # プレースホルダーを置換
        $timestamp = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
        $totalRecords = $Data.Count
        
        # JavaScriptパスを相対パスに変換
        $outputDir = Split-Path $OutputPath -Parent
        $jsRelativePath = Join-Path "..\..\Templates\JavaScript" "report-functions.js"
        
        $htmlContent = $htmlTemplate -replace "{{REPORT_NAME}}", $ReportName
        $htmlContent = $htmlContent -replace "{{GENERATED_DATE}}", $timestamp
        $htmlContent = $htmlContent -replace "{{TOTAL_RECORDS}}", $totalRecords
        $htmlContent = $htmlContent -replace "{{TABLE_HEADERS}}", $tableHeaders
        $htmlContent = $htmlContent -replace "{{TABLE_DATA}}", $tableData
        $htmlContent = $htmlContent -replace "{{PS_VERSION}}", $PSVersionTable.PSVersion.ToString()
        $htmlContent = $htmlContent -replace "{{TOOL_VERSION}}", "Microsoft 365管理ツール v1.0"
        $htmlContent = $htmlContent -replace "{{JS_PATH}}", $jsRelativePath
        
        # 出力ディレクトリを作成
        $outputDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }
        
        # HTMLファイルを出力
        $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        
        # JavaScriptファイルを出力先にコピー
        $jsOutputPath = Join-Path $outputDir "report-functions.js"
        if (Test-Path $jsPath) {
            Copy-Item $jsPath $jsOutputPath -Force
        }
        
        Write-Log "拡張HTMLレポートを生成しました: $OutputPath (件数: $totalRecords)" -Level "Info"
        
        return $OutputPath
    }
    catch {
        Write-Log "拡張HTMLレポート生成エラー: $($_.Exception.Message)" -Level "Error"
        return @()
    }
}

function Export-ReportsToArchive {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Daily", "Weekly", "Monthly", "Yearly")]
        [string]$ReportType,
        
        [Parameter(Mandatory = $false)]
        [int]$RetentionDays = 365
    )
    
    try {
        $reportsRoot = Join-Path $PSScriptRoot "..\..\Reports"
        $reportDir = Join-Path $reportsRoot $ReportType
        
        if (Test-Path $reportDir) {
            $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
            $oldReports = Get-ChildItem -Path $reportDir -Filter "*.html" | Where-Object { $_.LastWriteTime -lt $cutoffDate }
            
            if ($oldReports.Count -gt 0) {
                $archiveDir = Join-Path $reportsRoot "Archives"
                if (-not (Test-Path $archiveDir)) {
                    New-Item -Path $archiveDir -ItemType Directory -Force | Out-Null
                }
                
                $archivePath = Join-Path $archiveDir "${ReportType}_Reports_$(Get-Date -Format 'yyyyMMdd').zip"
                Compress-Archive -Path $oldReports.FullName -DestinationPath $archivePath -CompressionLevel Optimal -Force
                
                $oldReports | Remove-Item -Force
                
                Write-Log "$($oldReports.Count)個の${ReportType}レポートをアーカイブしました: $archivePath" -Level "Info"
            }
        }
    }
    catch {
        Write-Log "レポートアーカイブエラー: $($_.Exception.Message)" -Level "Error"
    }
}

# エクスポート関数
Export-ModuleMember -Function New-ReportDirectory, New-HTMLReport, New-CSVReport, New-SummaryStatistics, Export-ReportsToArchive, New-EnhancedHTMLReport