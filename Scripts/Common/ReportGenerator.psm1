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
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 2px solid #0078d4; padding-bottom: 20px; margin-bottom: 30px; }
        .title { color: #0078d4; font-size: 28px; margin-bottom: 10px; }
        .timestamp { color: #666; font-size: 14px; }
        .section { margin-bottom: 30px; }
        .section-title { color: #0078d4; font-size: 20px; border-bottom: 1px solid #ddd; padding-bottom: 5px; margin-bottom: 15px; }
        .summary { background: #f8f9fa; padding: 15px; border-radius: 4px; margin-bottom: 15px; }
        .alert { padding: 10px; border-radius: 4px; margin: 10px 0; }
        .alert-danger { background: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; }
        .alert-warning { background: #fff3cd; border: 1px solid #ffeaa7; color: #856404; }
        .alert-info { background: #d1ecf1; border: 1px solid #bee5eb; color: #0c5460; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 8px 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #0078d4; color: white; font-weight: 600; }
        tr:nth-child(even) { background: #f8f9fa; }
        .footer { text-align: center; color: #666; font-size: 12px; margin-top: 40px; border-top: 1px solid #ddd; padding-top: 20px; }
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
                    $htmlContent += "<table><thead><tr>"
                    
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
                            $htmlContent += "<td>$value</td>"
                        }
                        $htmlContent += "</tr>"
                    }
                    $htmlContent += "</tbody></table>"
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
            $Data | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
            Write-Log "CSVレポートを生成しました: $OutputPath" -Level "Info"
        }
        else {
            "No Data Available" | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
            Write-Log "データなしのCSVレポートを生成しました: $OutputPath" -Level "Info"
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
Export-ModuleMember -Function New-ReportDirectory, New-HTMLReport, New-CSVReport, New-SummaryStatistics, Export-ReportsToArchive