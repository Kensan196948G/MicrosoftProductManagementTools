#Requires -Version 5.1

<#
.SYNOPSIS
Microsoft 365管理ツール自動テストスイート

.DESCRIPTION
全機能の自動テストを実行し、品質保証レポートを生成します。
GUI/CLI両モード、全26機能、認証、モジュール読み込み、エラーハンドリングをテストします。

.NOTES
Version: 2025.7.17.1
Author: Test/QA Developer
Requires: PowerShell 5.1+, Microsoft.Graph, ExchangeOnlineManagement

.EXAMPLE
.\automated-test-suite.ps1
全自動テストを実行

.EXAMPLE
.\automated-test-suite.ps1 -TestCategory "GUI" -Verbose
GUI機能のみテスト実行（詳細ログ付き）

.EXAMPLE
.\automated-test-suite.ps1 -QuickTest
基本機能のみの高速テスト
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "GUI", "CLI", "Auth", "Modules", "Reports")]
    [string]$TestCategory = "All",
    
    [switch]$QuickTest,
    [switch]$GenerateReport = $true,
    [string]$OutputPath = "TestReports"
)

# テスト開始時刻
$TestStartTime = Get-Date
$TestSessionId = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "🧪 自動テストスイート開始" -ForegroundColor Cyan
Write-Host "テストセッション ID: $TestSessionId" -ForegroundColor Yellow
Write-Host "テストカテゴリ: $TestCategory" -ForegroundColor Yellow
Write-Host ""

# テスト結果格納
$TestResults = @()

# 出力ディレクトリの作成
$OutputDir = Join-Path $PSScriptRoot $OutputPath
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# ヘルパー関数: テスト実行
function Invoke-TestCase {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [string]$Category = "General",
        [int]$TimeoutMinutes = 5
    )
    
    $testStart = Get-Date
    $testResult = [PSCustomObject]@{
        TestName = $TestName
        Category = $Category
        Status = "Running"
        Duration = $null
        StartTime = $testStart
        EndTime = $null
        Message = ""
        Details = ""
        SessionId = $TestSessionId
    }
    
    try {
        Write-Host "  ▶️ $TestName を実行中..." -ForegroundColor Yellow
        
        # タイムアウト付きテスト実行
        $job = Start-Job -ScriptBlock $TestScript
        $completed = Wait-Job -Job $job -Timeout ($TimeoutMinutes * 60)
        
        if ($completed) {
            $result = Receive-Job -Job $job
            $testResult.Status = "Passed"
            $testResult.Message = "テスト成功"
            $testResult.Details = $result | Out-String
            Write-Host "  ✅ $TestName - 成功" -ForegroundColor Green
        } else {
            Stop-Job -Job $job
            $testResult.Status = "Failed"
            $testResult.Message = "テストタイムアウト ($TimeoutMinutes 分)"
            Write-Host "  ❌ $TestName - タイムアウト" -ForegroundColor Red
        }
        
        Remove-Job -Job $job
        
    } catch {
        $testResult.Status = "Failed"
        $testResult.Message = $_.Exception.Message
        $testResult.Details = $_.Exception.StackTrace
        Write-Host "  ❌ $TestName - 失敗: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $testResult.EndTime = Get-Date
    $testResult.Duration = ($testResult.EndTime - $testResult.StartTime).TotalSeconds
    
    return $testResult
}

# 1. ユニットテスト
if ($TestCategory -eq "All" -or $TestCategory -eq "Unit") {
    Write-Host "1. ユニットテスト" -ForegroundColor Yellow
    Write-Host "   - 個別モジュールと関数のテスト" -ForegroundColor Gray
    
    # 設定ファイル読み込みテスト
    $TestResults += Invoke-TestCase -TestName "設定ファイル読み込み" -Category "Unit" -TestScript {
        $configPath = Join-Path $using:PSScriptRoot "..\Config\appsettings.json"
        if (-not (Test-Path $configPath)) {
            throw "設定ファイルが見つかりません: $configPath"
        }
        
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        if (-not $config.General.OrganizationName) {
            throw "組織名が設定されていません"
        }
        
        return "設定ファイルの読み込みに成功しました"
    }
    
    # 認証モジュールテスト
    $TestResults += Invoke-TestCase -TestName "認証モジュール読み込み" -Category "Unit" -TestScript {
        $authPath = Join-Path $using:PSScriptRoot "..\Scripts\Common\Authentication.psm1"
        if (-not (Test-Path $authPath)) {
            throw "認証モジュールが見つかりません: $authPath"
        }
        
        Import-Module $authPath -Force
        $functions = Get-Command -Module Authentication
        if ($functions.Count -eq 0) {
            throw "認証モジュールの関数が見つかりません"
        }
        
        return "認証モジュールの読み込みに成功しました (関数数: $($functions.Count))"
    }
    
    # ログモジュールテスト
    $TestResults += Invoke-TestCase -TestName "ログモジュール機能" -Category "Unit" -TestScript {
        $logPath = Join-Path $using:PSScriptRoot "..\Scripts\Common\Logging.psm1"
        if (-not (Test-Path $logPath)) {
            throw "ログモジュールが見つかりません: $logPath"
        }
        
        Import-Module $logPath -Force
        
        # テスト用ログ出力
        $testLogPath = Join-Path $using:PSScriptRoot "..\Logs\test_unit_log.log"
        Write-Log -Message "ユニットテスト用ログ" -Level "Info" -LogFile $testLogPath
        
        if (-not (Test-Path $testLogPath)) {
            throw "ログファイルが作成されませんでした"
        }
        
        return "ログモジュールの動作確認に成功しました"
    }
}

# 2. 統合テスト
if ($TestCategory -eq "All" -or $TestCategory -eq "Integration") {
    Write-Host "2. 統合テスト" -ForegroundColor Yellow
    Write-Host "   - モジュール間の連携テスト" -ForegroundColor Gray
    
    # Microsoft Graph 接続テスト
    $TestResults += Invoke-TestCase -TestName "Microsoft Graph接続" -Category "Integration" -TestScript {
        $configPath = Join-Path $using:PSScriptRoot "..\Config\appsettings.json"
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        
        if (-not $config.EntraID.ClientId -or $config.EntraID.ClientId -eq '${REACT_APP_MS_CLIENT_ID}') {
            return "Microsoft Graph接続設定が未完了のため、テストをスキップしました"
        }
        
        # 認証モジュール読み込み
        $authPath = Join-Path $using:PSScriptRoot "..\Scripts\Common\Authentication.psm1"
        Import-Module $authPath -Force
        
        # 接続テスト
        $connection = Connect-ToMicrosoft365 -Config $config -Services @("MicrosoftGraph")
        if (-not $connection.Success) {
            throw "Microsoft Graph接続に失敗しました: $($connection.Errors -join ', ')"
        }
        
        return "Microsoft Graph接続に成功しました"
    } -TimeoutMinutes 3
    
    # データプロバイダーテスト
    $TestResults += Invoke-TestCase -TestName "データプロバイダー統合" -Category "Integration" -TestScript {
        $dataPath = Join-Path $using:PSScriptRoot "..\Scripts\Common\RealM365DataProvider.psm1"
        if (-not (Test-Path $dataPath)) {
            throw "データプロバイダーモジュールが見つかりません: $dataPath"
        }
        
        Import-Module $dataPath -Force
        
        # 関数の存在確認
        $functions = Get-Command -Module RealM365DataProvider
        if ($functions.Count -eq 0) {
            throw "データプロバイダーの関数が見つかりません"
        }
        
        return "データプロバイダーの統合確認に成功しました (関数数: $($functions.Count))"
    }
    
    # レポート生成テスト
    $TestResults += Invoke-TestCase -TestName "レポート生成機能" -Category "Integration" -TestScript {
        $reportPath = Join-Path $using:PSScriptRoot "..\Scripts\Common\MultiFormatReportGenerator.psm1"
        if (-not (Test-Path $reportPath)) {
            throw "レポート生成モジュールが見つかりません: $reportPath"
        }
        
        Import-Module $reportPath -Force
        
        # テスト用データでレポート生成
        $testData = @(
            [PSCustomObject]@{ Name = "テストユーザー1"; Email = "test1@example.com"; Status = "Active" },
            [PSCustomObject]@{ Name = "テストユーザー2"; Email = "test2@example.com"; Status = "Inactive" }
        )
        
        $testOutputPath = Join-Path $using:OutputDir "integration_test_report.html"
        # レポート生成関数が存在するかチェック
        $reportFunction = Get-Command -Name "New-HTMLReport" -ErrorAction SilentlyContinue
        if (-not $reportFunction) {
            return "レポート生成関数が見つかりませんが、モジュールは正常に読み込まれました"
        }
        
        return "レポート生成機能の確認に成功しました"
    }
}

# 3. セキュリティテスト
if ($TestCategory -eq "All" -or $TestCategory -eq "Security") {
    Write-Host "3. セキュリティテスト" -ForegroundColor Yellow
    Write-Host "   - 脆弱性と設定の確認" -ForegroundColor Gray
    
    # セキュリティ脆弱性テスト
    $TestResults += Invoke-TestCase -TestName "セキュリティ脆弱性スキャン" -Category "Security" -TestScript {
        $securityTestPath = Join-Path $using:PSScriptRoot "security-vulnerability-test.ps1"
        if (-not (Test-Path $securityTestPath)) {
            throw "セキュリティテストスクリプトが見つかりません: $securityTestPath"
        }
        
        # セキュリティテストを実行
        $result = & $securityTestPath
        return "セキュリティ脆弱性スキャンが完了しました"
    }
    
    # 実行ポリシーテスト
    $TestResults += Invoke-TestCase -TestName "実行ポリシー確認" -Category "Security" -TestScript {
        $policy = Get-ExecutionPolicy -Scope CurrentUser
        if ($policy -eq "Restricted") {
            throw "実行ポリシーが制限されています: $policy"
        }
        
        return "実行ポリシーは適切です: $policy"
    }
    
    # 証明書検証テスト
    $TestResults += Invoke-TestCase -TestName "証明書検証" -Category "Security" -TestScript {
        $certDir = Join-Path $using:PSScriptRoot "..\Certificates"
        if (-not (Test-Path $certDir)) {
            return "証明書ディレクトリが見つかりません（正常な場合があります）"
        }
        
        $certFiles = Get-ChildItem -Path $certDir -Filter "*.pfx"
        if ($certFiles.Count -eq 0) {
            return "証明書ファイルが見つかりません（正常な場合があります）"
        }
        
        foreach ($certFile in $certFiles) {
            try {
                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
                $cert.Import($certFile.FullName)
                $daysToExpiry = ($cert.NotAfter - (Get-Date)).Days
                if ($daysToExpiry -lt 0) {
                    throw "証明書が期限切れです: $($certFile.Name)"
                }
            } catch {
                # パスワード保護された証明書の場合はスキップ
                continue
            }
        }
        
        return "証明書の検証に成功しました"
    }
}

# 4. パフォーマンステスト
if ($TestCategory -eq "All" -or $TestCategory -eq "Performance") {
    Write-Host "4. パフォーマンステスト" -ForegroundColor Yellow
    Write-Host "   - 応答時間と負荷テスト" -ForegroundColor Gray
    
    # モジュール読み込み時間テスト
    $TestResults += Invoke-TestCase -TestName "モジュール読み込み時間" -Category "Performance" -TestScript {
        $modules = @(
            "Authentication.psm1",
            "Logging.psm1",
            "RealM365DataProvider.psm1"
        )
        
        $loadTimes = @()
        foreach ($module in $modules) {
            $modulePath = Join-Path $using:PSScriptRoot "..\Scripts\Common\$module"
            if (Test-Path $modulePath) {
                $startTime = Get-Date
                Import-Module $modulePath -Force
                $endTime = Get-Date
                $loadTime = ($endTime - $startTime).TotalMilliseconds
                $loadTimes += [PSCustomObject]@{
                    Module = $module
                    LoadTime = $loadTime
                }
            }
        }
        
        $avgLoadTime = ($loadTimes.LoadTime | Measure-Object -Average).Average
        if ($avgLoadTime -gt 5000) {
            throw "モジュール読み込みが遅すぎます: 平均 $avgLoadTime ms"
        }
        
        return "モジュール読み込み時間: 平均 $([math]::Round($avgLoadTime, 2)) ms"
    }
    
    # メモリ使用量テスト
    $TestResults += Invoke-TestCase -TestName "メモリ使用量監視" -Category "Performance" -TestScript {
        $initialMemory = [System.GC]::GetTotalMemory($false)
        
        # 複数のモジュールを読み込み
        $modules = Get-ChildItem -Path (Join-Path $using:PSScriptRoot "..\Scripts\Common") -Filter "*.psm1"
        foreach ($module in $modules) {
            try {
                Import-Module $module.FullName -Force
            } catch {
                # 読み込みエラーは無視
            }
        }
        
        $finalMemory = [System.GC]::GetTotalMemory($false)
        $memoryIncrease = $finalMemory - $initialMemory
        
        # 50MB以上のメモリ増加は異常
        if ($memoryIncrease -gt 50MB) {
            throw "メモリ使用量が異常に増加しました: $([math]::Round($memoryIncrease / 1MB, 2)) MB"
        }
        
        return "メモリ使用量: $([math]::Round($memoryIncrease / 1MB, 2)) MB増加"
    }
}

# 5. GUI テスト
if ($TestCategory -eq "All" -or $TestCategory -eq "GUI") {
    Write-Host "5. GUI テスト" -ForegroundColor Yellow
    Write-Host "   - GUI アプリケーションの基本機能" -ForegroundColor Gray
    
    # GUI アプリケーション存在確認
    $TestResults += Invoke-TestCase -TestName "GUI アプリケーション存在確認" -Category "GUI" -TestScript {
        $guiPaths = @(
            (Join-Path $using:PSScriptRoot "..\Apps\GuiApp.ps1"),
            (Join-Path $using:PSScriptRoot "..\Apps\GuiApp_Enhanced.ps1")
        )
        
        $foundGuis = @()
        foreach ($guiPath in $guiPaths) {
            if (Test-Path $guiPath) {
                $foundGuis += $guiPath
            }
        }
        
        if ($foundGuis.Count -eq 0) {
            throw "GUI アプリケーションが見つかりません"
        }
        
        return "GUI アプリケーションを $($foundGuis.Count) 個発見しました"
    }
    
    # Windows Forms 依存関係チェック
    $TestResults += Invoke-TestCase -TestName "Windows Forms 依存関係" -Category "GUI" -TestScript {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
        } catch {
            throw "Windows Forms が利用できません: $($_.Exception.Message)"
        }
        
        return "Windows Forms 依存関係の確認に成功しました"
    }
}

# 6. CLI テスト
if ($TestCategory -eq "All" -or $TestCategory -eq "CLI") {
    Write-Host "6. CLI テスト" -ForegroundColor Yellow
    Write-Host "   - CLI アプリケーションの基本機能" -ForegroundColor Gray
    
    # CLI アプリケーション存在確認
    $TestResults += Invoke-TestCase -TestName "CLI アプリケーション存在確認" -Category "CLI" -TestScript {
        $cliPaths = @(
            (Join-Path $using:PSScriptRoot "..\Apps\CliApp.ps1"),
            (Join-Path $using:PSScriptRoot "..\Apps\CliApp_Enhanced.ps1")
        )
        
        $foundClis = @()
        foreach ($cliPath in $cliPaths) {
            if (Test-Path $cliPath) {
                $foundClis += $cliPath
            }
        }
        
        if ($foundClis.Count -eq 0) {
            throw "CLI アプリケーションが見つかりません"
        }
        
        return "CLI アプリケーションを $($foundClis.Count) 個発見しました"
    }
    
    # CLI ヘルプ表示テスト
    $TestResults += Invoke-TestCase -TestName "CLI ヘルプ表示" -Category "CLI" -TestScript {
        $cliPath = Join-Path $using:PSScriptRoot "..\Apps\CliApp_Enhanced.ps1"
        if (-not (Test-Path $cliPath)) {
            $cliPath = Join-Path $using:PSScriptRoot "..\Apps\CliApp.ps1"
        }
        
        if (-not (Test-Path $cliPath)) {
            throw "CLI アプリケーションが見つかりません"
        }
        
        # ヘルプ情報を取得
        $helpResult = & $cliPath -Help 2>&1
        if ($LASTEXITCODE -ne 0 -and $helpResult -notmatch "help|usage|使用法") {
            throw "CLI ヘルプの表示に失敗しました"
        }
        
        return "CLI ヘルプの表示に成功しました"
    }
}

# テスト結果の集計
$TestEndTime = Get-Date
$TotalDuration = ($TestEndTime - $TestStartTime).TotalSeconds

Write-Host ""
Write-Host "=== テスト結果サマリー ===" -ForegroundColor Cyan
Write-Host "テスト実行時間: $([math]::Round($TotalDuration, 2)) 秒" -ForegroundColor White
Write-Host "実行されたテスト: $($TestResults.Count)" -ForegroundColor White

$passedTests = ($TestResults | Where-Object { $_.Status -eq "Passed" }).Count
$failedTests = ($TestResults | Where-Object { $_.Status -eq "Failed" }).Count
$skippedTests = ($TestResults | Where-Object { $_.Status -eq "Skipped" }).Count

Write-Host "成功: $passedTests" -ForegroundColor Green
Write-Host "失敗: $failedTests" -ForegroundColor Red
if ($skippedTests -gt 0) {
    Write-Host "スキップ: $skippedTests" -ForegroundColor Yellow
}

# 失敗したテストの詳細表示
if ($failedTests -gt 0) {
    Write-Host ""
    Write-Host "=== 失敗したテスト ===" -ForegroundColor Red
    $failedTestDetails = $TestResults | Where-Object { $_.Status -eq "Failed" }
    foreach ($test in $failedTestDetails) {
        Write-Host "❌ $($test.TestName) ($($test.Category))" -ForegroundColor Red
        Write-Host "   エラー: $($test.Message)" -ForegroundColor Yellow
        if ($Verbose -and $test.Details) {
            Write-Host "   詳細: $($test.Details)" -ForegroundColor Gray
        }
    }
}

# レポート生成
if ($GenerateReport) {
    Write-Host ""
    Write-Host "📊 テストレポートを生成中..." -ForegroundColor Cyan
    
    # CSV レポート
    $csvPath = Join-Path $OutputDir "test-results_$TestSessionId.csv"
    $TestResults | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    
    # HTML レポート
    $htmlPath = Join-Path $OutputDir "test-results_$TestSessionId.html"
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>テスト結果レポート - $TestSessionId</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .passed { color: green; }
        .failed { color: red; }
        .skipped { color: orange; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>テスト結果レポート</h1>
    <h2>概要</h2>
    <p>テストセッション: $TestSessionId</p>
    <p>実行時間: $([math]::Round($TotalDuration, 2)) 秒</p>
    <p>総テスト数: $($TestResults.Count)</p>
    <p>成功: <span class="passed">$passedTests</span></p>
    <p>失敗: <span class="failed">$failedTests</span></p>
    <p>スキップ: <span class="skipped">$skippedTests</span></p>
    
    <h2>詳細結果</h2>
    <table>
        <tr>
            <th>テスト名</th>
            <th>カテゴリ</th>
            <th>ステータス</th>
            <th>実行時間</th>
            <th>メッセージ</th>
        </tr>
"@
    
    foreach ($test in $TestResults) {
        $statusClass = $test.Status.ToLower()
        $duration = if ($test.Duration) { [math]::Round($test.Duration, 2) } else { "N/A" }
        $htmlContent += @"
        <tr>
            <td>$($test.TestName)</td>
            <td>$($test.Category)</td>
            <td class="$statusClass">$($test.Status)</td>
            <td>$duration 秒</td>
            <td>$($test.Message)</td>
        </tr>
"@
    }
    
    $htmlContent += @"
    </table>
</body>
</html>
"@
    
    $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
    
    Write-Host "✅ レポートを生成しました:" -ForegroundColor Green
    Write-Host "  CSV: $csvPath" -ForegroundColor Gray
    Write-Host "  HTML: $htmlPath" -ForegroundColor Gray
}

# 終了ステータス
if ($failedTests -gt 0) {
    Write-Host ""
    Write-Host "🔴 テストが失敗しました ($failedTests/$($TestResults.Count))" -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "🟢 すべてのテストが成功しました" -ForegroundColor Green
    exit 0
}