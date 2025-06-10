# ================================================================================
# ManualTestReport.ps1 
# 手動テスト結果レポート生成スクリプト
# PowerShell実行環境がない場合の代替手段
# ================================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "Reports\Daily\ManualTestReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
)

function Test-AllFiles {
    $testResults = @()
    
    # スクリプトファイル存在確認
    $scriptFiles = @(
        "Scripts\AD\GroupManagement.ps1",
        "Scripts\AD\UserManagement.ps1", 
        "Scripts\EXO\MailboxManagement.ps1",
        "Scripts\EXO\SecurityAnalysis.ps1",
        "Scripts\EntraID\TeamsOneDriveManagement.ps1",
        "Scripts\EntraID\UserSecurityManagement.ps1",
        "Scripts\Common\ScheduledReports.ps1",
        "Scripts\Common\AutomatedTesting.ps1"
    )
    
    foreach ($file in $scriptFiles) {
        if (Test-Path $file) {
            $testResults += [PSCustomObject]@{
                ファイル名 = $file
                ステータス = "存在"
                サイズKB = [math]::Round((Get-Item $file).Length / 1KB, 2)
                最終更新日 = (Get-Item $file).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        } else {
            $testResults += [PSCustomObject]@{
                ファイル名 = $file
                ステータス = "不存在"
                サイズKB = 0
                最終更新日 = "N/A"
            }
        }
    }
    
    # モジュールファイル存在確認
    $moduleFiles = @(
        "Scripts\Common\Common.psm1",
        "Scripts\Common\Authentication.psm1",
        "Scripts\Common\Logging.psm1", 
        "Scripts\Common\ErrorHandling.psm1",
        "Scripts\Common\ReportGenerator.psm1"
    )
    
    foreach ($file in $moduleFiles) {
        if (Test-Path $file) {
            $testResults += [PSCustomObject]@{
                ファイル名 = $file
                ステータス = "存在"
                サイズKB = [math]::Round((Get-Item $file).Length / 1KB, 2)
                最終更新日 = (Get-Item $file).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        } else {
            $testResults += [PSCustomObject]@{
                ファイル名 = $file
                ステータス = "不存在"
                サイズKB = 0
                最終更新日 = "N/A"
            }
        }
    }
    
    return $testResults
}

function Test-DirectoryStructure {
    $directories = @(
        "Scripts\Common",
        "Scripts\AD",
        "Scripts\EXO", 
        "Scripts\EntraID",
        "Config",
        "Reports\Daily",
        "Reports\Weekly",
        "Reports\Monthly", 
        "Reports\Yearly",
        "Logs",
        "Templates"
    )
    
    $dirResults = @()
    
    foreach ($dir in $directories) {
        if (Test-Path $dir) {
            $dirResults += [PSCustomObject]@{
                ディレクトリ = $dir
                ステータス = "存在"
                作成日時 = (Get-Item $dir).CreationTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        } else {
            $dirResults += [PSCustomObject]@{
                ディレクトリ = $dir
                ステータス = "不存在"
                作成日時 = "N/A"
            }
        }
    }
    
    return $dirResults
}

function Test-ConfigFiles {
    $configResults = @()
    
    $configFiles = @(
        "Config\appsettings.json",
        "Templates\ReportTemplate.html",
        "CLAUDE.md",
        "README.md"
    )
    
    foreach ($file in $configFiles) {
        if (Test-Path $file) {
            $configResults += [PSCustomObject]@{
                設定ファイル = $file
                ステータス = "存在"
                サイズKB = [math]::Round((Get-Item $file).Length / 1KB, 2)
                最終更新日 = (Get-Item $file).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        } else {
            $configResults += [PSCustomObject]@{
                設定ファイル = $file
                ステータス = "不存在"
                サイズKB = 0
                最終更新日 = "N/A"
            }
        }
    }
    
    return $configResults
}

function Generate-ManualTestReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    $fileTests = Test-AllFiles
    $dirTests = Test-DirectoryStructure
    $configTests = Test-ConfigFiles
    
    $totalFiles = $fileTests.Count
    $existingFiles = ($fileTests | Where-Object { $_.ステータス -eq "存在" }).Count
    $missingFiles = $totalFiles - $existingFiles
    
    $totalDirs = $dirTests.Count
    $existingDirs = ($dirTests | Where-Object { $_.ステータス -eq "存在" }).Count
    $missingDirs = $totalDirs - $existingDirs
    
    $totalConfigs = $configTests.Count
    $existingConfigs = ($configTests | Where-Object { $_.ステータス -eq "存在" }).Count
    $missingConfigs = $totalConfigs - $existingConfigs
    
    $reportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
    $systemInfo = "$env:COMPUTERNAME ($env:OS)"
    
    $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft製品運用管理ツール - 手動テスト結果レポート</title>
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
        .success { border-left-color: #388e3c; }
        .success .value { color: #388e3c; }
        .warning { border-left-color: #f57c00; }
        .warning .value { color: #f57c00; }
        .error { border-left-color: #d32f2f; }
        .error .value { color: #d32f2f; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #0078d4; color: white; }
        tr:nth-child(even) { background-color: #f8f9fa; }
        .status-ok { color: #388e3c; font-weight: bold; }
        .status-ng { color: #d32f2f; font-weight: bold; }
        .footer { text-align: center; margin-top: 30px; padding: 20px; background-color: #333; color: white; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Microsoft製品運用管理ツール - 手動テスト結果レポート</h1>
        <div class="subtitle">
            レポート生成日時: $reportDate<br>
            実行システム: $systemInfo<br>
            テスト種別: 構成ファイル・ディレクトリ存在確認
        </div>
    </div>

    <div class="section">
        <h2>テスト実行サマリー</h2>
        <div class="summary-grid">
            <div class="summary-card $(if ($missingFiles -eq 0) { 'success' } else { 'error' })">
                <h3>スクリプトファイル</h3>
                <div class="value">$existingFiles / $totalFiles</div>
            </div>
            <div class="summary-card $(if ($missingDirs -eq 0) { 'success' } else { 'error' })">
                <h3>ディレクトリ</h3>
                <div class="value">$existingDirs / $totalDirs</div>
            </div>
            <div class="summary-card $(if ($missingConfigs -eq 0) { 'success' } else { 'warning' })">
                <h3>設定ファイル</h3>
                <div class="value">$existingConfigs / $totalConfigs</div>
            </div>
            <div class="summary-card success">
                <h3>全体ステータス</h3>
                <div class="value">$(if ($missingFiles -eq 0 -and $missingDirs -eq 0) { '正常' } else { '要確認' })</div>
            </div>
        </div>
    </div>

    <div class="section">
        <h2>スクリプト・モジュールファイル詳細</h2>
        <table>
            <tr>
                <th>ファイル名</th>
                <th>ステータス</th>
                <th>サイズ(KB)</th>
                <th>最終更新日</th>
            </tr>
"@

    foreach ($file in $fileTests) {
        $statusClass = if ($file.ステータス -eq "存在") { "status-ok" } else { "status-ng" }
        $htmlContent += @"
            <tr>
                <td>$($file.ファイル名)</td>
                <td class="$statusClass">$($file.ステータス)</td>
                <td>$($file.サイズKB)</td>
                <td>$($file.最終更新日)</td>
            </tr>
"@
    }

    $htmlContent += @"
        </table>
    </div>

    <div class="section">
        <h2>ディレクトリ構造詳細</h2>
        <table>
            <tr>
                <th>ディレクトリ</th>
                <th>ステータス</th>
                <th>作成日時</th>
            </tr>
"@

    foreach ($dir in $dirTests) {
        $statusClass = if ($dir.ステータス -eq "存在") { "status-ok" } else { "status-ng" }
        $htmlContent += @"
            <tr>
                <td>$($dir.ディレクトリ)</td>
                <td class="$statusClass">$($dir.ステータス)</td>
                <td>$($dir.作成日時)</td>
            </tr>
"@
    }

    $htmlContent += @"
        </table>
    </div>

    <div class="section">
        <h2>設定ファイル詳細</h2>
        <table>
            <tr>
                <th>設定ファイル</th>
                <th>ステータス</th>
                <th>サイズ(KB)</th>
                <th>最終更新日</th>
            </tr>
"@

    foreach ($config in $configTests) {
        $statusClass = if ($config.ステータス -eq "存在") { "status-ok" } else { "status-ng" }
        $htmlContent += @"
            <tr>
                <td>$($config.設定ファイル)</td>
                <td class="$statusClass">$($config.ステータス)</td>
                <td>$($config.サイズKB)</td>
                <td>$($config.最終更新日)</td>
            </tr>
"@
    }

    $htmlContent += @"
        </table>
    </div>

    <div class="footer">
        Microsoft製品運用管理ツール - ITSM/ISO27001/27002準拠<br>
        このレポートは手動テストにより自動生成されました。
    </div>
</body>
</html>
"@

    $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host "手動テスト結果レポートを生成しました: $OutputPath" -ForegroundColor Green
    
    return @{
        ReportPath = $OutputPath
        TotalFiles = $totalFiles
        ExistingFiles = $existingFiles
        MissingFiles = $missingFiles
        TotalDirectories = $totalDirs
        ExistingDirectories = $existingDirs
        MissingDirectories = $missingDirs
        TotalConfigs = $totalConfigs
        ExistingConfigs = $existingConfigs
        MissingConfigs = $missingConfigs
    }
}

# メイン実行部分
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Microsoft製品運用管理ツール - 手動テストを開始します..." -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    
    # レポートディレクトリが存在しない場合は作成
    $reportDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
        Write-Host "レポートディレクトリを作成しました: $reportDir" -ForegroundColor Yellow
    }
    
    try {
        $testResult = Generate-ManualTestReport -OutputPath $OutputPath
        
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "手動テスト結果サマリー:" -ForegroundColor Cyan
        Write-Host "スクリプトファイル: $($testResult.ExistingFiles)/$($testResult.TotalFiles) (不足: $($testResult.MissingFiles))" -ForegroundColor $(if ($testResult.MissingFiles -eq 0) { 'Green' } else { 'Red' })
        Write-Host "ディレクトリ: $($testResult.ExistingDirectories)/$($testResult.TotalDirectories) (不足: $($testResult.MissingDirectories))" -ForegroundColor $(if ($testResult.MissingDirectories -eq 0) { 'Green' } else { 'Red' })
        Write-Host "設定ファイル: $($testResult.ExistingConfigs)/$($testResult.TotalConfigs) (不足: $($testResult.MissingConfigs))" -ForegroundColor $(if ($testResult.MissingConfigs -eq 0) { 'Green' } else { 'Yellow' })
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "詳細レポート: $($testResult.ReportPath)" -ForegroundColor Cyan
        
        if ($testResult.MissingFiles -eq 0 -and $testResult.MissingDirectories -eq 0) {
            Write-Host "✓ 全ての必須ファイルとディレクトリが正常に配置されています。" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "⚠ 一部のファイルまたはディレクトリが不足しています。詳細レポートを確認してください。" -ForegroundColor Yellow
            exit 1
        }
    }
    catch {
        Write-Host "手動テスト実行中にエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
        exit 99
    }
}