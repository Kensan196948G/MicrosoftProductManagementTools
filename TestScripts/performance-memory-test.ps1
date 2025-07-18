#Requires -Version 5.1

<#
.SYNOPSIS
Microsoft 365管理ツール - パフォーマンス・メモリテスト

.DESCRIPTION
システムのパフォーマンス、メモリ使用量、応答時間を監視・測定します。
エンタープライズ環境での運用に適した性能指標を分析し、ボトルネックを特定します。

.NOTES
Version: 2025.7.17.1
Author: Test/QA Developer
Requires: PowerShell 5.1+

.EXAMPLE
.\performance-memory-test.ps1
基本パフォーマンステストを実行

.EXAMPLE
.\performance-memory-test.ps1 -TestType "Memory" -Duration 300
メモリテストを5分間実行

.EXAMPLE
.\performance-memory-test.ps1 -LoadTest -ConcurrentUsers 10
負荷テスト（10同時ユーザー）を実行
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "CPU", "Memory", "Disk", "Network", "Modules", "Functions")]
    [string]$TestType = "All",
    
    [int]$Duration = 60,
    [switch]$LoadTest,
    [int]$ConcurrentUsers = 5,
    [switch]$GenerateReport = $true,
    [string]$OutputPath = "TestReports"
)

Write-Host "⚡ パフォーマンステストとメモリリークチェック開始" -ForegroundColor Cyan
Write-Host "テスト時間: $Duration 秒" -ForegroundColor Yellow
Write-Host "サンプリング間隔: $SampleInterval 秒" -ForegroundColor Yellow
Write-Host ""

# パフォーマンス測定結果格納
$PerformanceResults = @()
$MemorySnapshots = @()

# 開始時刻
$TestStartTime = Get-Date

# 初期メモリ使用量
$InitialMemory = [System.GC]::GetTotalMemory($false)
Write-Host "初期メモリ使用量: $([math]::Round($InitialMemory / 1MB, 2)) MB" -ForegroundColor Cyan

# ヘルパー関数: メモリ使用量スナップショット
function Get-MemorySnapshot {
    param([string]$Stage)
    
    $snapshot = [PSCustomObject]@{
        Stage = $Stage
        Timestamp = Get-Date
        TotalMemory = [System.GC]::GetTotalMemory($false)
        Gen0Collections = [System.GC]::CollectionCount(0)
        Gen1Collections = [System.GC]::CollectionCount(1)
        Gen2Collections = [System.GC]::CollectionCount(2)
        ProcessWorkingSet = (Get-Process -Id $PID).WorkingSet64
        ProcessPrivateMemory = (Get-Process -Id $PID).PrivateMemorySize64
    }
    
    if ($DetailedOutput) {
        Write-Host "  📊 メモリスナップショット [$Stage]: $([math]::Round($snapshot.TotalMemory / 1MB, 2)) MB" -ForegroundColor Gray
    }
    
    return $snapshot
}

# ヘルパー関数: パフォーマンス測定
function Measure-Performance {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [int]$Iterations = 1
    )
    
    $testResults = @()
    
    for ($i = 1; $i -le $Iterations; $i++) {
        $beforeMemory = Get-MemorySnapshot -Stage "Before_$TestName"
        $startTime = Get-Date
        
        try {
            $result = & $TestScript
            $success = $true
            $errorMessage = $null
        } catch {
            $success = $false
            $errorMessage = $_.Exception.Message
        }
        
        $endTime = Get-Date
        $afterMemory = Get-MemorySnapshot -Stage "After_$TestName"
        
        $testResult = [PSCustomObject]@{
            TestName = $TestName
            Iteration = $i
            Success = $success
            ErrorMessage = $errorMessage
            Duration = ($endTime - $startTime).TotalMilliseconds
            MemoryBefore = $beforeMemory.TotalMemory
            MemoryAfter = $afterMemory.TotalMemory
            MemoryDelta = $afterMemory.TotalMemory - $beforeMemory.TotalMemory
            WorkingSetBefore = $beforeMemory.ProcessWorkingSet
            WorkingSetAfter = $afterMemory.ProcessWorkingSet
            WorkingSetDelta = $afterMemory.ProcessWorkingSet - $beforeMemory.ProcessWorkingSet
            Timestamp = $startTime
        }
        
        $testResults += $testResult
        
        if ($DetailedOutput) {
            Write-Host "  ⏱️  $TestName [$i/$Iterations]: $([math]::Round($testResult.Duration, 2)) ms, メモリ変化: $([math]::Round($testResult.MemoryDelta / 1KB, 2)) KB" -ForegroundColor Gray
        }
    }
    
    return $testResults
}

# 1. モジュール読み込みパフォーマンステスト
Write-Host "1. モジュール読み込みパフォーマンステスト" -ForegroundColor Yellow

$modules = @(
    "Authentication.psm1",
    "Logging.psm1",
    "RealM365DataProvider.psm1",
    "ErrorHandling.psm1",
    "MultiFormatReportGenerator.psm1"
)

foreach ($module in $modules) {
    $modulePath = Join-Path $PSScriptRoot "..\Scripts\Common\$module"
    if (Test-Path $modulePath) {
        Write-Host "  📦 $module を測定中..." -ForegroundColor Yellow
        
        $moduleResults = Measure-Performance -TestName "Load_$module" -Iterations 5 -TestScript {
            # モジュールを削除してから再読み込み
            $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($using:module)
            Get-Module $moduleName -ErrorAction SilentlyContinue | Remove-Module -Force
            Import-Module $using:modulePath -Force
            return "Module loaded successfully"
        }
        
        $PerformanceResults += $moduleResults
        
        $avgDuration = ($moduleResults.Duration | Measure-Object -Average).Average
        $avgMemoryDelta = ($moduleResults.MemoryDelta | Measure-Object -Average).Average
        
        Write-Host "  ✅ $module - 平均読み込み時間: $([math]::Round($avgDuration, 2)) ms, 平均メモリ使用量: $([math]::Round($avgMemoryDelta / 1KB, 2)) KB" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ $module が見つかりません" -ForegroundColor Yellow
    }
}

# 2. 認証処理パフォーマンステスト
Write-Host "2. 認証処理パフォーマンステスト" -ForegroundColor Yellow

$authPath = Join-Path $PSScriptRoot "..\Scripts\Common\Authentication.psm1"
if (Test-Path $authPath) {
    Import-Module $authPath -Force
    
    # 認証状態テスト
    Write-Host "  🔐 認証状態テストを測定中..." -ForegroundColor Yellow
    
    $authResults = Measure-Performance -TestName "AuthenticationStatus_Test" -Iterations 10 -TestScript {
        $status = Test-AuthenticationStatus -RequiredServices @("MicrosoftGraph")
        return $status
    }
    
    $PerformanceResults += $authResults
    
    $avgDuration = ($authResults.Duration | Measure-Object -Average).Average
    Write-Host "  ✅ 認証状態テスト - 平均応答時間: $([math]::Round($avgDuration, 2)) ms" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ 認証モジュールが見つかりません" -ForegroundColor Yellow
}

# 3. ログ出力パフォーマンステスト
Write-Host "3. ログ出力パフォーマンステスト" -ForegroundColor Yellow

$logPath = Join-Path $PSScriptRoot "..\Scripts\Common\Logging.psm1"
if (Test-Path $logPath) {
    Import-Module $logPath -Force
    
    $testLogFile = Join-Path $PSScriptRoot "..\Logs\performance_test.log"
    
    # 大量ログ出力テスト
    Write-Host "  📝 大量ログ出力テストを測定中..." -ForegroundColor Yellow
    
    $logResults = Measure-Performance -TestName "Mass_Log_Output" -Iterations 3 -TestScript {
        for ($i = 1; $i -le 1000; $i++) {
            Write-Log -Message "パフォーマンステストログ #$i" -Level "Info" -LogFile $using:testLogFile
        }
        return "1000 log entries written"
    }
    
    $PerformanceResults += $logResults
    
    $avgDuration = ($logResults.Duration | Measure-Object -Average).Average
    $avgMemoryDelta = ($logResults.MemoryDelta | Measure-Object -Average).Average
    
    Write-Host "  ✅ ログ出力テスト - 1000件の平均時間: $([math]::Round($avgDuration, 2)) ms, 平均メモリ使用量: $([math]::Round($avgMemoryDelta / 1KB, 2)) KB" -ForegroundColor Green
    
    # クリーンアップ
    if (Test-Path $testLogFile) {
        Remove-Item $testLogFile -Force
    }
} else {
    Write-Host "  ⚠️ ログモジュールが見つかりません" -ForegroundColor Yellow
}

# 4. データ処理パフォーマンステスト
Write-Host "4. データ処理パフォーマンステスト" -ForegroundColor Yellow

Write-Host "  📊 大量データ処理テストを測定中..." -ForegroundColor Yellow

$dataResults = Measure-Performance -TestName "Large_Data_Processing" -Iterations 3 -TestScript {
    # 大量のテストデータを生成
    $testData = @()
    for ($i = 1; $i -le 10000; $i++) {
        $testData += [PSCustomObject]@{
            Id = $i
            Name = "User$i"
            Email = "user$i@example.com"
            Department = "Dept$($i % 10)"
            LastLogin = (Get-Date).AddDays(-($i % 30))
        }
    }
    
    # データを処理
    $processedData = $testData | Where-Object { $_.LastLogin -gt (Get-Date).AddDays(-7) } | Sort-Object Name
    
    return "Processed $($processedData.Count) records from $($testData.Count) total"
}

$PerformanceResults += $dataResults

$avgDuration = ($dataResults.Duration | Measure-Object -Average).Average
$avgMemoryDelta = ($dataResults.MemoryDelta | Measure-Object -Average).Average

Write-Host "  ✅ データ処理テスト - 10,000件の平均処理時間: $([math]::Round($avgDuration, 2)) ms, 平均メモリ使用量: $([math]::Round($avgMemoryDelta / 1MB, 2)) MB" -ForegroundColor Green

# 5. 継続的メモリ監視テスト
Write-Host "5. 継続的メモリ監視テスト" -ForegroundColor Yellow
Write-Host "  ⏰ $Duration 秒間のメモリ使用量を監視中..." -ForegroundColor Yellow

$monitoringStartTime = Get-Date
$monitoringEndTime = $monitoringStartTime.AddSeconds($Duration)

while ((Get-Date) -lt $monitoringEndTime) {
    $currentSnapshot = Get-MemorySnapshot -Stage "Monitoring"
    $MemorySnapshots += $currentSnapshot
    
    # CPU使用率もサンプリング
    $process = Get-Process -Id $PID
    $cpuUsage = $process.CPU
    
    if ($DetailedOutput) {
        $elapsedTime = ((Get-Date) - $monitoringStartTime).TotalSeconds
        Write-Host "  📈 監視時間: $([math]::Round($elapsedTime, 1))s, メモリ: $([math]::Round($currentSnapshot.TotalMemory / 1MB, 2)) MB, WS: $([math]::Round($currentSnapshot.ProcessWorkingSet / 1MB, 2)) MB" -ForegroundColor Gray
    }
    
    Start-Sleep -Seconds $SampleInterval
}

# 6. メモリリーク検出分析
Write-Host "6. メモリリーク検出分析" -ForegroundColor Yellow

$finalMemory = [System.GC]::GetTotalMemory($false)
$totalMemoryIncrease = $finalMemory - $InitialMemory

# ガベージコレクション後のメモリ使用量
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
[System.GC]::Collect()

$memoryAfterGC = [System.GC]::GetTotalMemory($false)
$memoryNotReclaimed = $memoryAfterGC - $InitialMemory

Write-Host "  📊 メモリ使用量分析:" -ForegroundColor Cyan
Write-Host "    初期メモリ: $([math]::Round($InitialMemory / 1MB, 2)) MB" -ForegroundColor White
Write-Host "    最終メモリ: $([math]::Round($finalMemory / 1MB, 2)) MB" -ForegroundColor White
Write-Host "    総増加量: $([math]::Round($totalMemoryIncrease / 1MB, 2)) MB" -ForegroundColor White
Write-Host "    GC後メモリ: $([math]::Round($memoryAfterGC / 1MB, 2)) MB" -ForegroundColor White
Write-Host "    回収できないメモリ: $([math]::Round($memoryNotReclaimed / 1MB, 2)) MB" -ForegroundColor White

# メモリリークの判定
$memoryLeakThreshold = 50MB  # 50MB以上の回収できないメモリ増加をリークとみなす
$hasMemoryLeak = $memoryNotReclaimed -gt $memoryLeakThreshold

if ($hasMemoryLeak) {
    Write-Host "  ⚠️ メモリリークの可能性が検出されました!" -ForegroundColor Red
    Write-Host "    回収できないメモリ: $([math]::Round($memoryNotReclaimed / 1MB, 2)) MB" -ForegroundColor Red
} else {
    Write-Host "  ✅ メモリリークは検出されませんでした" -ForegroundColor Green
}

# 7. パフォーマンス統計の生成
Write-Host "7. パフォーマンス統計の生成" -ForegroundColor Yellow

$TestEndTime = Get-Date
$TotalTestDuration = ($TestEndTime - $TestStartTime).TotalSeconds

Write-Host ""
Write-Host "=== パフォーマンステスト結果サマリー ===" -ForegroundColor Cyan
Write-Host "総テスト時間: $([math]::Round($TotalTestDuration, 2)) 秒" -ForegroundColor White
Write-Host "実行されたテスト: $($PerformanceResults.Count)" -ForegroundColor White
Write-Host "メモリスナップショット: $($MemorySnapshots.Count)" -ForegroundColor White

# パフォーマンス統計
if ($PerformanceResults.Count -gt 0) {
    $avgDuration = ($PerformanceResults.Duration | Measure-Object -Average).Average
    $maxDuration = ($PerformanceResults.Duration | Measure-Object -Maximum).Maximum
    $minDuration = ($PerformanceResults.Duration | Measure-Object -Minimum).Minimum
    
    Write-Host "応答時間統計:" -ForegroundColor White
    Write-Host "  平均: $([math]::Round($avgDuration, 2)) ms" -ForegroundColor Green
    Write-Host "  最大: $([math]::Round($maxDuration, 2)) ms" -ForegroundColor Yellow
    Write-Host "  最小: $([math]::Round($minDuration, 2)) ms" -ForegroundColor Green
    
    # 遅いテストの特定
    $slowTests = $PerformanceResults | Where-Object { $_.Duration -gt ($avgDuration * 2) }
    if ($slowTests.Count -gt 0) {
        Write-Host "遅いテスト:" -ForegroundColor Yellow
        foreach ($slowTest in $slowTests) {
            Write-Host "  - $($slowTest.TestName): $([math]::Round($slowTest.Duration, 2)) ms" -ForegroundColor Yellow
        }
    }
}

# メモリ使用量統計
if ($MemorySnapshots.Count -gt 0) {
    $memoryUsages = $MemorySnapshots | ForEach-Object { $_.TotalMemory }
    $avgMemory = ($memoryUsages | Measure-Object -Average).Average
    $maxMemory = ($memoryUsages | Measure-Object -Maximum).Maximum
    $minMemory = ($memoryUsages | Measure-Object -Minimum).Minimum
    
    Write-Host "メモリ使用量統計:" -ForegroundColor White
    Write-Host "  平均: $([math]::Round($avgMemory / 1MB, 2)) MB" -ForegroundColor Green
    Write-Host "  最大: $([math]::Round($maxMemory / 1MB, 2)) MB" -ForegroundColor Yellow
    Write-Host "  最小: $([math]::Round($minMemory / 1MB, 2)) MB" -ForegroundColor Green
}

# 8. レポート生成
if ($GenerateReport) {
    Write-Host ""
    Write-Host "📊 パフォーマンスレポートを生成中..." -ForegroundColor Cyan
    
    $reportDir = Join-Path $PSScriptRoot "TestReports"
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    # CSV レポート
    $csvPath = Join-Path $reportDir "performance-test-results_$timestamp.csv"
    $PerformanceResults | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    
    # メモリスナップショット CSV
    $memoryCsvPath = Join-Path $reportDir "memory-snapshots_$timestamp.csv"
    $MemorySnapshots | Export-Csv -Path $memoryCsvPath -NoTypeInformation -Encoding UTF8
    
    # HTML レポート
    $htmlPath = Join-Path $reportDir "performance-test-report_$timestamp.html"
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>パフォーマンステストレポート - $timestamp</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .success { color: green; }
        .warning { color: orange; }
        .error { color: red; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .chart { margin: 20px 0; }
    </style>
</head>
<body>
    <h1>パフォーマンステストレポート</h1>
    <h2>概要</h2>
    <p>テスト実行時間: $([math]::Round($TotalTestDuration, 2)) 秒</p>
    <p>総テスト数: $($PerformanceResults.Count)</p>
    <p>メモリスナップショット数: $($MemorySnapshots.Count)</p>
    
    <h2>メモリ使用量</h2>
    <p>初期メモリ: $([math]::Round($InitialMemory / 1MB, 2)) MB</p>
    <p>最終メモリ: $([math]::Round($finalMemory / 1MB, 2)) MB</p>
    <p>総増加量: $([math]::Round($totalMemoryIncrease / 1MB, 2)) MB</p>
    <p>GC後メモリ: $([math]::Round($memoryAfterGC / 1MB, 2)) MB</p>
    <p class="$(if ($hasMemoryLeak) { 'error' } else { 'success' })">
        メモリリーク: $(if ($hasMemoryLeak) { '検出されました' } else { '検出されませんでした' })
    </p>
    
    <h2>パフォーマンス結果</h2>
    <table>
        <tr>
            <th>テスト名</th>
            <th>実行時間 (ms)</th>
            <th>メモリ変化 (KB)</th>
            <th>成功</th>
            <th>エラー</th>
        </tr>
"@
    
    foreach ($result in $PerformanceResults) {
        $successClass = if ($result.Success) { "success" } else { "error" }
        $memoryDelta = [math]::Round($result.MemoryDelta / 1KB, 2)
        $duration = [math]::Round($result.Duration, 2)
        
        $htmlContent += @"
        <tr>
            <td>$($result.TestName)</td>
            <td>$duration</td>
            <td>$memoryDelta</td>
            <td class="$successClass">$($result.Success)</td>
            <td>$($result.ErrorMessage)</td>
        </tr>
"@
    }
    
    $htmlContent += @"
    </table>
    
    <h2>推奨事項</h2>
    <ul>
        $(if ($hasMemoryLeak) { '<li class="error">メモリリークの調査と修正が必要です</li>' })
        $(if ($slowTests.Count -gt 0) { '<li class="warning">遅いテストの最適化を検討してください</li>' })
        <li>定期的なパフォーマンス監視を実施してください</li>
        <li>メモリ使用量が異常に高い場合は、ガベージコレクションの最適化を検討してください</li>
    </ul>
</body>
</html>
"@
    
    $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
    
    Write-Host "✅ パフォーマンスレポートを生成しました:" -ForegroundColor Green
    Write-Host "  テスト結果CSV: $csvPath" -ForegroundColor Gray
    Write-Host "  メモリスナップショットCSV: $memoryCsvPath" -ForegroundColor Gray
    Write-Host "  HTML レポート: $htmlPath" -ForegroundColor Gray
}

Write-Host ""
Write-Host "⚡ パフォーマンステストとメモリリークチェック完了" -ForegroundColor Green

# 終了ステータス
if ($hasMemoryLeak) {
    Write-Host "🔴 メモリリークが検出されました" -ForegroundColor Red
    exit 1
} else {
    Write-Host "🟢 パフォーマンステストが正常に完了しました" -ForegroundColor Green
    exit 0
}