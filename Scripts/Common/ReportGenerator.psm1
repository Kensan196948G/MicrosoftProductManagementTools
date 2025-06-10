# ================================================================================
# ReportGenerator.psm1
# Microsoft製品運用管理ツール - レポート生成モジュール
# ITSM/ISO27001/27002準拠
# ================================================================================

function New-HTMLReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $true)]
        [hashtable[]]$DataSections,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [string]$TemplatePath = "Templates\ReportTemplate.html"
    )
    
    try {
        $reportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
        $systemInfo = Get-SystemInfo
        
        $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$Title</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #0078d4; color: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .header h1 { margin: 0; }
        .header .subtitle { margin-top: 10px; opacity: 0.9; }
        .section { background-color: white; margin-bottom: 20px; padding: 20px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .section h2 { color: #0078d4; border-bottom: 2px solid #0078d4; padding-bottom: 10px; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }
        .summary-card { background-color: #f8f9fa; padding: 15px; border-radius: 5px; border-left: 4px solid #0078d4; }
        .summary-card h3 { margin: 0 0 10px 0; color: #333; font-size: 14px; }
        .summary-card .value { font-size: 24px; font-weight: bold; color: #0078d4; }
        .risk-high { border-left-color: #d32f2f; }
        .risk-high .value { color: #d32f2f; }
        .risk-medium { border-left-color: #f57c00; }
        .risk-medium .value { color: #f57c00; }
        .risk-low { border-left-color: #388e3c; }
        .risk-low .value { color: #388e3c; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #0078d4; color: white; }
        tr:nth-child(even) { background-color: #f8f9fa; }
        .alert { padding: 15px; margin: 10px 0; border-radius: 5px; }
        .alert-danger { background-color: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; }
        .alert-warning { background-color: #fff3cd; border: 1px solid #ffeaa7; color: #856404; }
        .alert-info { background-color: #d1ecf1; border: 1px solid #bee5eb; color: #0c5460; }
        .footer { text-align: center; margin-top: 30px; padding: 20px; background-color: #333; color: white; border-radius: 5px; }
        .no-data { text-align: center; color: #666; font-style: italic; padding: 40px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>$Title</h1>
        <div class="subtitle">
            レポート生成日時: $reportDate<br>
            実行システム: $($systemInfo.MachineName) ($($systemInfo.OSVersion))<br>
            PowerShell バージョン: $($systemInfo.PowerShellVersion)
        </div>
    </div>
"@
        
        foreach ($section in $DataSections) {
            $htmlContent += "<div class='section'>"
            $htmlContent += "<h2>$($section.Title)</h2>"
            
            if ($section.Summary) {
                $htmlContent += "<div class='summary-grid'>"
                foreach ($summaryItem in $section.Summary) {
                    $riskClass = switch ($summaryItem.Risk) {
                        "高" { "risk-high" }
                        "中" { "risk-medium" }
                        "低" { "risk-low" }
                        default { "" }
                    }
                    
                    $htmlContent += @"
                    <div class='summary-card $riskClass'>
                        <h3>$($summaryItem.Label)</h3>
                        <div class='value'>$($summaryItem.Value)</div>
                    </div>
"@
                }
                $htmlContent += "</div>"
            }
            
            if ($section.Alerts) {
                foreach ($alert in $section.Alerts) {
                    $alertClass = switch ($alert.Type) {
                        "Danger" { "alert-danger" }
                        "Warning" { "alert-warning" }
                        "Info" { "alert-info" }
                        default { "alert-info" }
                    }
                    
                    $htmlContent += "<div class='alert $alertClass'>$($alert.Message)</div>"
                }
            }
            
            if ($section.Data -and $section.Data.Count -gt 0) {
                $htmlContent += "<table>"
                
                $properties = $section.Data[0].PSObject.Properties.Name
                $htmlContent += "<tr>"
                foreach ($prop in $properties) {
                    $htmlContent += "<th>$prop</th>"
                }
                $htmlContent += "</tr>"
                
                foreach ($row in $section.Data) {
                    $htmlContent += "<tr>"
                    foreach ($prop in $properties) {
                        $value = $row.$prop
                        if ($null -eq $value) { $value = "" }
                        $htmlContent += "<td>$value</td>"
                    }
                    $htmlContent += "</tr>"
                }
                
                $htmlContent += "</table>"
            }
            elseif ($section.Data) {
                $htmlContent += "<div class='no-data'>データがありません</div>"
            }
            
            $htmlContent += "</div>"
        }
        
        $htmlContent += @"
    <div class="footer">
        Microsoft製品運用管理ツール - ITSM/ISO27001/27002準拠<br>
        このレポートは自動生成されました。機密情報として適切に管理してください。
    </div>
</body>
</html>
"@
        
        $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Log "HTMLレポートを生成しました: $OutputPath" -Level "Info"
        
        return $true
    }
    catch {
        Write-Log "HTMLレポート生成エラー: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function ConvertTo-HTMLTable {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Data,
        
        [Parameter(Mandatory = $false)]
        [string]$TableClass = "data-table"
    )
    
    if (-not $Data -or $Data.Count -eq 0) {
        return "<p class='no-data'>データがありません</p>"
    }
    
    $html = "<table class='$TableClass'>"
    
    $properties = $Data[0].PSObject.Properties.Name
    $html += "<tr>"
    foreach ($prop in $properties) {
        $html += "<th>$prop</th>"
    }
    $html += "</tr>"
    
    foreach ($row in $Data) {
        $html += "<tr>"
        foreach ($prop in $properties) {
            $value = $row.$prop
            if ($null -eq $value) { $value = "" }
            $html += "<td>$value</td>"
        }
        $html += "</tr>"
    }
    
    $html += "</table>"
    
    return $html
}

function New-SummaryStatistics {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Data,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$CountFields
    )
    
    $summary = @()
    
    foreach ($field in $CountFields.GetEnumerator()) {
        $count = switch ($field.Value.Type) {
            "Count" {
                if ($field.Value.Filter) {
                    ($Data | Where-Object $field.Value.Filter).Count
                } else {
                    $Data.Count
                }
            }
            "Sum" {
                ($Data | Measure-Object -Property $field.Value.Property -Sum).Sum
            }
            "Average" {
                [math]::Round(($Data | Measure-Object -Property $field.Value.Property -Average).Average, 2)
            }
            default { 0 }
        }
        
        $summary += @{
            Label = $field.Key
            Value = $count
            Risk = $field.Value.Risk
        }
    }
    
    return $summary
}

function Export-ReportsToArchive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportType,
        
        [Parameter(Mandatory = $false)]
        [int]$RetentionDays = 90,
        
        [Parameter(Mandatory = $false)]
        [string]$ArchiveBasePath = "Archives"
    )
    
    try {
        $reportPath = "Reports\$ReportType"
        if (-not (Test-Path $reportPath)) {
            Write-Log "レポートパスが存在しません: $reportPath" -Level "Warning"
            return $false
        }
        
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
        $oldReports = Get-ChildItem -Path $reportPath -Recurse -File | 
                     Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        if ($oldReports.Count -gt 0) {
            $archivePath = Join-Path $ArchiveBasePath "$ReportType"
            if (-not (Test-Path $archivePath)) {
                New-Item -Path $archivePath -ItemType Directory -Force | Out-Null
            }
            
            $archiveFile = Join-Path $archivePath "$ReportType`_Archive_$(Get-Date -Format 'yyyyMMdd').zip"
            
            Compress-Archive -Path $oldReports.FullName -DestinationPath $archiveFile -Force
            Write-Log "レポートをアーカイブしました: $archiveFile ($($oldReports.Count)ファイル)" -Level "Info"
            
            $oldReports | Remove-Item -Force
            Write-Log "古いレポートファイルを削除しました" -Level "Info"
        }
        
        return $true
    }
    catch {
        Write-Log "レポートアーカイブエラー: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

Export-ModuleMember -Function New-HTMLReport, ConvertTo-HTMLTable, New-SummaryStatistics, Export-ReportsToArchive