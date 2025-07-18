#Requires -Version 5.1

<#
.SYNOPSIS
Microsoft 365管理ツール - 拡張パフォーマンス・メモリテスト

.DESCRIPTION
Dev2 - Test/QA Developerによる包括的なパフォーマンステストとメモリリークテスト。
応答時間、スループット、メモリ使用量、リソース消費、負荷テストを実装。

.NOTES
Version: 2025.7.18.1
Author: Dev2 - Test/QA Developer
Framework: PowerShell 5.1+
Test Types: パフォーマンス、メモリリーク、負荷、ストレス
Quality Gate: 応答時間 < 5秒、メモリリーク < 50MB、CPU使用率 < 80%

.EXAMPLE
.\enhanced-performance-memory-test.ps1
包括的パフォーマンステストを実行

.EXAMPLE
.\enhanced-performance-memory-test.ps1 -TestType "Memory" -DetailedAnalysis
メモリ特化テストを詳細分析付きで実行
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "Performance", "Memory", "Load", "Stress")]
    [string]$TestType = "All",
    
    [string]$ProjectRoot = "E:\MicrosoftProductManagementTools",
    [string]$OutputPath = "TestReports",
    [switch]$GenerateReport = $true,
    [switch]$DetailedAnalysis = $true,
    [int]$LoadTestIterations = 100,
    [int]$MemoryTestDuration = 300
)

# パフォーマンステスト開始
$TestStartTime = Get-Date
$SessionId = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "⚡ Microsoft 365管理ツール - パフォーマンス・メモリテスト開始" -ForegroundColor Cyan
Write-Host "テストセッション ID: $SessionId" -ForegroundColor Yellow
Write-Host "テストタイプ: $TestType" -ForegroundColor Yellow
Write-Host "プロジェクトルート: $ProjectRoot" -ForegroundColor Gray
Write-Host ""

# 出力ディレクトリ作成
$OutputDir = Join-Path $PSScriptRoot $OutputPath
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# パフォーマンステスト結果
$PerformanceResults = @{
    ModuleLoadTimes = @()
    FunctionExecutionTimes = @()
    MemorySnapshots = @()
    CPUUsage = @()
    LoadTestResults = @()
    StressTestResults = @()
    MemoryLeakTests = @()
    ThroughputTests = @()
    QualityGates = @{
        ResponseTimeThreshold = 5000  # ms
        MemoryLeakThreshold = 50     # MB
        CPUUsageThreshold = 80       # %
        ThroughputThreshold = 10     # operations/second
    }
    TestMetrics = @{
        TotalTestDuration = 0
        TestsExecuted = 0
        PassedTests = 0
        FailedTests = 0
        PerformanceScore = 0
    }
}

# ヘルパー関数: パフォーマンスログ
function Write-PerformanceLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Critical", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Info" { "White" }
        "Warning" { "Yellow" }
        "Critical" { "Red" }
        "Success" { "Green" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# ヘルパー関数: メモリスナップショット取得
function Get-MemorySnapshot {
    param([string]$Phase)
    
    $memoryInfo = [PSCustomObject]@{
        Phase = $Phase
        Timestamp = Get-Date
        TotalMemory = [System.GC]::GetTotalMemory($false)
        Gen0Collections = [System.GC]::CollectionCount(0)
        Gen1Collections = [System.GC]::CollectionCount(1)
        Gen2Collections = [System.GC]::CollectionCount(2)
        WorkingSet = (Get-Process -Id $PID).WorkingSet64
        VirtualMemory = (Get-Process -Id $PID).VirtualMemorySize64
        PrivateMemory = (Get-Process -Id $PID).PrivateMemorySize64
    }
    
    $PerformanceResults.MemorySnapshots += $memoryInfo
    return $memoryInfo
}

# ヘルパー関数: CPU使用率取得
function Get-CPUUsage {
    $process = Get-Process -Id $PID
    $startTime = Get-Date
    $startCpuTime = $process.TotalProcessorTime
    
    Start-Sleep -Milliseconds 1000
    
    $process = Get-Process -Id $PID
    $endTime = Get-Date
    $endCpuTime = $process.TotalProcessorTime
    
    $cpuUsedMs = ($endCpuTime - $startCpuTime).TotalMilliseconds
    $totalMsPassed = ($endTime - $startTime).TotalMilliseconds
    $cpuUsagePercent = ($cpuUsedMs / $totalMsPassed) * 100
    
    return [math]::Round($cpuUsagePercent, 2)
}

Write-PerformanceLog "パフォーマンステストを開始します" -Level "Info"

# 初期メモリスナップショット
$initialMemory = Get-MemorySnapshot -Phase "Initial"

# 1. モジュール読み込みパフォーマンステスト
if ($TestType -eq "All" -or $TestType -eq "Performance") {
    Write-PerformanceLog "モジュール読み込みパフォーマンステスト中..." -Level "Info"
    
    $moduleFiles = @(
        "Scripts\Common\Authentication.psm1",
        "Scripts\Common\Logging.psm1",
        "Scripts\Common\RealM365DataProvider.psm1",
        "Scripts\Common\MultiFormatReportGenerator.psm1",
        "Scripts\Common\ErrorHandling.psm1"
    )
    
    foreach ($moduleFile in $moduleFiles) {
        $modulePath = Join-Path $ProjectRoot $moduleFile
        if (Test-Path $modulePath) {
            $memoryBefore = Get-MemorySnapshot -Phase "Before_$($moduleFile.Replace('\', '_').Replace('.psm1', ''))"
            
            $loadTime = Measure-Command {
                try {
                    Import-Module $modulePath -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-PerformanceLog "モジュール読み込みエラー: $moduleFile - $($_.Exception.Message)" -Level "Warning"
                }
            }
            
            $memoryAfter = Get-MemorySnapshot -Phase "After_$($moduleFile.Replace('\', '_').Replace('.psm1', ''))"
            $memoryIncrease = $memoryAfter.TotalMemory - $memoryBefore.TotalMemory
            
            $loadResult = [PSCustomObject]@{
                ModuleName = [System.IO.Path]::GetFileNameWithoutExtension($moduleFile)
                LoadTime = $loadTime.TotalMilliseconds
                MemoryIncrease = $memoryIncrease
                MemoryIncreaseMB = [math]::Round($memoryIncrease / 1MB, 2)
                Status = if ($loadTime.TotalMilliseconds -lt $PerformanceResults.QualityGates.ResponseTimeThreshold) { "Pass" } else { "Fail" }
                Timestamp = Get-Date
            }
            
            $PerformanceResults.ModuleLoadTimes += $loadResult
            $PerformanceResults.TestMetrics.TestsExecuted++
            
            if ($loadResult.Status -eq "Pass") {
                $PerformanceResults.TestMetrics.PassedTests++
                Write-PerformanceLog "✅ $($loadResult.ModuleName): $([math]::Round($loadTime.TotalMilliseconds, 2))ms, メモリ: $($loadResult.MemoryIncreaseMB)MB" -Level "Success"
            } else {
                $PerformanceResults.TestMetrics.FailedTests++
                Write-PerformanceLog "❌ $($loadResult.ModuleName): $([math]::Round($loadTime.TotalMilliseconds, 2))ms (閾値超過)" -Level "Critical"
            }
        }
    }
}

# 2. 関数実行パフォーマンステスト
if ($TestType -eq "All" -or $TestType -eq "Performance") {
    Write-PerformanceLog "関数実行パフォーマンステスト中..." -Level "Info"
    
    # テスト用データ生成関数
    $testFunctions = @(
        @{
            Name = "Large_Data_Processing"
            Code = {
                $testData = @()
                for ($i = 1; $i -le 10000; $i++) {
                    $testData += [PSCustomObject]@{
                        Id = $i
                        Name = "TestItem$i"
                        Description = "Test Description " * 10
                        Category = "Category$($i % 10)"
                        Value = Get-Random -Minimum 1 -Maximum 1000
                    }
                }
                $filtered = $testData | Where-Object { $_.Category -eq "Category1" }
                return $filtered.Count
            }
        },
        @{
            Name = "JSON_Parsing"
            Code = {
                $jsonData = @{
                    Users = @()
                    Settings = @{
                        Environment = "Test"
                        Version = "1.0.0"
                        Features = @("Feature1", "Feature2", "Feature3")
                    }
                }
                for ($i = 1; $i -le 1000; $i++) {
                    $jsonData.Users += @{
                        Id = $i
                        Name = "User$i"
                        Email = "user$i@test.com"
                        Active = ($i % 2 -eq 0)
                    }
                }
                $json = $jsonData | ConvertTo-Json -Depth 10
                $parsed = $json | ConvertFrom-Json
                return $parsed.Users.Count
            }
        },
        @{
            Name = "File_Operations"
            Code = {
                $tempFile = [System.IO.Path]::GetTempFileName()
                $testContent = "Test Content`n" * 1000
                
                $testContent | Out-File -FilePath $tempFile -Encoding UTF8
                $readContent = Get-Content $tempFile -Raw
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                
                return $readContent.Length
            }
        },
        @{
            Name = "RegEx_Processing"
            Code = {
                $testText = "This is a test email: user@example.com and another: test@domain.org " * 100
                $emailPattern = "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"
                $matches = [regex]::Matches($testText, $emailPattern)
                return $matches.Count
            }
        }
    )
    
    foreach ($testFunction in $testFunctions) {
        $memoryBefore = Get-MemorySnapshot -Phase "Before_$($testFunction.Name)"
        
        $executionTime = Measure-Command {
            $result = & $testFunction.Code
        }
        
        $memoryAfter = Get-MemorySnapshot -Phase "After_$($testFunction.Name)"
        $memoryIncrease = $memoryAfter.TotalMemory - $memoryBefore.TotalMemory
        
        $functionResult = [PSCustomObject]@{
            FunctionName = $testFunction.Name
            ExecutionTime = $executionTime.TotalMilliseconds
            MemoryIncrease = $memoryIncrease
            MemoryIncreaseMB = [math]::Round($memoryIncrease / 1MB, 2)
            Status = if ($executionTime.TotalMilliseconds -lt $PerformanceResults.QualityGates.ResponseTimeThreshold) { "Pass" } else { "Fail" }
            Timestamp = Get-Date
        }
        
        $PerformanceResults.FunctionExecutionTimes += $functionResult
        $PerformanceResults.TestMetrics.TestsExecuted++
        
        if ($functionResult.Status -eq "Pass") {
            $PerformanceResults.TestMetrics.PassedTests++
            Write-PerformanceLog "✅ $($functionResult.FunctionName): $([math]::Round($executionTime.TotalMilliseconds, 2))ms" -Level "Success"
        } else {
            $PerformanceResults.TestMetrics.FailedTests++
            Write-PerformanceLog "❌ $($functionResult.FunctionName): $([math]::Round($executionTime.TotalMilliseconds, 2))ms (閾値超過)" -Level "Critical"
        }
    }
}

# 3. メモリリークテスト
if ($TestType -eq "All" -or $TestType -eq "Memory") {
    Write-PerformanceLog "メモリリークテスト中..." -Level "Info"
    
    $memoryLeakTests = @(
        @{
            Name = "Repeated_Object_Creation"
            Description = "大量オブジェクト生成・破棄の繰り返し"
            Iterations = 50
            Code = {
                $objects = @()
                for ($i = 1; $i -le 1000; $i++) {
                    $objects += [PSCustomObject]@{
                        Id = $i
                        Data = "x" * 1000
                        Timestamp = Get-Date
                    }
                }
                $objects = $null
            }
        },
        @{
            Name = "Module_Import_Cycles"
            Description = "モジュールインポートサイクル"
            Iterations = 20
            Code = {
                $authPath = Join-Path $ProjectRoot "Scripts\Common\Authentication.psm1"
                if (Test-Path $authPath) {
                    Import-Module $authPath -Force -ErrorAction SilentlyContinue
                    Remove-Module Authentication -Force -ErrorAction SilentlyContinue
                }
            }
        },
        @{
            Name = "Large_Collections"
            Description = "大規模コレクション操作"
            Iterations = 30
            Code = {
                $collection = New-Object System.Collections.ArrayList
                for ($i = 1; $i -le 5000; $i++) {
                    $collection.Add("Item$i") | Out-Null
                }
                $collection.Clear()
                $collection = $null
            }
        }
    )
    
    foreach ($memoryTest in $memoryLeakTests) {
        Write-PerformanceLog "メモリリークテスト: $($memoryTest.Name)" -Level "Info"
        
        $memoryBefore = Get-MemorySnapshot -Phase "MemoryLeak_Before_$($memoryTest.Name)"
        
        # ガベージコレクション実行
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        
        $memoryBaseline = Get-MemorySnapshot -Phase "MemoryLeak_Baseline_$($memoryTest.Name)"
        
        # テスト実行
        $testDuration = Measure-Command {
            for ($i = 1; $i -le $memoryTest.Iterations; $i++) {
                & $memoryTest.Code
                
                if ($i % 10 -eq 0) {
                    $progressMemory = Get-MemorySnapshot -Phase "MemoryLeak_Progress_$($memoryTest.Name)_$i"
                }
            }
        }
        
        # 最終ガベージコレクション
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        
        $memoryAfter = Get-MemorySnapshot -Phase "MemoryLeak_After_$($memoryTest.Name)"
        
        $memoryLeak = $memoryAfter.TotalMemory - $memoryBaseline.TotalMemory
        $memoryLeakMB = [math]::Round($memoryLeak / 1MB, 2)
        
        $leakResult = [PSCustomObject]@{
            TestName = $memoryTest.Name
            Description = $memoryTest.Description
            Iterations = $memoryTest.Iterations
            Duration = $testDuration.TotalMilliseconds
            MemoryLeak = $memoryLeak
            MemoryLeakMB = $memoryLeakMB
            Status = if ($memoryLeakMB -lt $PerformanceResults.QualityGates.MemoryLeakThreshold) { "Pass" } else { "Fail" }
            Timestamp = Get-Date
        }
        
        $PerformanceResults.MemoryLeakTests += $leakResult
        $PerformanceResults.TestMetrics.TestsExecuted++
        
        if ($leakResult.Status -eq "Pass") {
            $PerformanceResults.TestMetrics.PassedTests++
            Write-PerformanceLog "✅ $($leakResult.TestName): メモリリーク $($leakResult.MemoryLeakMB)MB" -Level "Success"
        } else {
            $PerformanceResults.TestMetrics.FailedTests++
            Write-PerformanceLog "❌ $($leakResult.TestName): メモリリーク $($leakResult.MemoryLeakMB)MB (閾値超過)" -Level "Critical"
        }
    }
}

# 4. 負荷テスト
if ($TestType -eq "All" -or $TestType -eq "Load") {
    Write-PerformanceLog "負荷テスト中..." -Level "Info"
    
    $loadTests = @(
        @{
            Name = "Concurrent_Data_Processing"
            Description = "並行データ処理"
            Threads = 5
            OperationsPerThread = $LoadTestIterations / 5
        },
        @{
            Name = "Rapid_Function_Calls"
            Description = "高頻度関数呼び出し"
            CallsPerSecond = 50
            Duration = 10
        }
    )
    
    foreach ($loadTest in $loadTests) {
        Write-PerformanceLog "負荷テスト: $($loadTest.Name)" -Level "Info"
        
        $memoryBefore = Get-MemorySnapshot -Phase "Load_Before_$($loadTest.Name)"
        $cpuBefore = Get-CPUUsage
        
        $loadDuration = Measure-Command {
            if ($loadTest.Name -eq "Concurrent_Data_Processing") {
                $jobs = @()
                for ($t = 1; $t -le $loadTest.Threads; $t++) {
                    $job = Start-Job -ScriptBlock {
                        param($Operations)
                        $results = @()
                        for ($i = 1; $i -le $Operations; $i++) {
                            $data = @{
                                Id = $i
                                Value = Get-Random -Minimum 1 -Maximum 1000
                                Timestamp = Get-Date
                            }
                            $results += $data
                        }
                        return $results.Count
                    } -ArgumentList $loadTest.OperationsPerThread
                    $jobs += $job
                }
                
                $jobResults = $jobs | Wait-Job | Receive-Job
                $jobs | Remove-Job
                $totalOperations = ($jobResults | Measure-Object -Sum).Sum
                
            } elseif ($loadTest.Name -eq "Rapid_Function_Calls") {
                $operations = 0
                $endTime = (Get-Date).AddSeconds($loadTest.Duration)
                
                while ((Get-Date) -lt $endTime) {
                    $testData = @{
                        Id = $operations
                        Data = "Test" * 10
                        Random = Get-Random
                    }
                    $operations++
                    
                    if ($operations % 100 -eq 0) {
                        Start-Sleep -Milliseconds 10
                    }
                }
                $totalOperations = $operations
            }
        }
        
        $memoryAfter = Get-MemorySnapshot -Phase "Load_After_$($loadTest.Name)"
        $cpuAfter = Get-CPUUsage
        
        $throughput = $totalOperations / $loadDuration.TotalSeconds
        $memoryIncrease = $memoryAfter.TotalMemory - $memoryBefore.TotalMemory
        
        $loadResult = [PSCustomObject]@{
            TestName = $loadTest.Name
            Description = $loadTest.Description
            Duration = $loadDuration.TotalSeconds
            TotalOperations = $totalOperations
            Throughput = [math]::Round($throughput, 2)
            MemoryIncrease = [math]::Round($memoryIncrease / 1MB, 2)
            CPUUsage = [math]::Round(($cpuBefore + $cpuAfter) / 2, 2)
            Status = if ($throughput -gt $PerformanceResults.QualityGates.ThroughputThreshold -and 
                         ($cpuBefore + $cpuAfter) / 2 -lt $PerformanceResults.QualityGates.CPUUsageThreshold) { "Pass" } else { "Fail" }
            Timestamp = Get-Date
        }
        
        $PerformanceResults.LoadTestResults += $loadResult
        $PerformanceResults.TestMetrics.TestsExecuted++
        
        if ($loadResult.Status -eq "Pass") {
            $PerformanceResults.TestMetrics.PassedTests++
            Write-PerformanceLog "✅ $($loadResult.TestName): スループット $($loadResult.Throughput) ops/sec" -Level "Success"
        } else {
            $PerformanceResults.TestMetrics.FailedTests++
            Write-PerformanceLog "❌ $($loadResult.TestName): スループット $($loadResult.Throughput) ops/sec (閾値未達)" -Level "Critical"
        }
    }
}

# 5. ストレステスト
if ($TestType -eq "All" -or $TestType -eq "Stress") {
    Write-PerformanceLog "ストレステスト中..." -Level "Info"
    
    $stressTests = @(
        @{
            Name = "Memory_Pressure"
            Description = "メモリ圧迫テスト"
            AllocateSize = 100MB
        },
        @{
            Name = "CPU_Intensive"
            Description = "CPU集約的処理"
            Duration = 30
        }
    )
    
    foreach ($stressTest in $stressTests) {
        Write-PerformanceLog "ストレステスト: $($stressTest.Name)" -Level "Info"
        
        $memoryBefore = Get-MemorySnapshot -Phase "Stress_Before_$($stressTest.Name)"
        
        $stressDuration = Measure-Command {
            if ($stressTest.Name -eq "Memory_Pressure") {
                # 大量メモリ使用
                $largeArrays = @()
                for ($i = 1; $i -le 10; $i++) {
                    $largeArray = New-Object byte[] (10MB)
                    $largeArrays += $largeArray
                    
                    $progressMemory = Get-MemorySnapshot -Phase "Stress_Progress_$($stressTest.Name)_$i"
                    Start-Sleep -Milliseconds 500
                }
                
                # メモリ解放
                $largeArrays = $null
                [System.GC]::Collect()
                
            } elseif ($stressTest.Name -eq "CPU_Intensive") {
                # CPU集約的処理
                $endTime = (Get-Date).AddSeconds($stressTest.Duration)
                $calculations = 0
                
                while ((Get-Date) -lt $endTime) {
                    # 複雑な数値計算
                    for ($j = 1; $j -le 1000; $j++) {
                        $result = [Math]::Sqrt($j) * [Math]::Sin($j) * [Math]::Cos($j)
                        $calculations++
                    }
                }
            }
        }
        
        $memoryAfter = Get-MemorySnapshot -Phase "Stress_After_$($stressTest.Name)")
        $cpuUsage = Get-CPUUsage
        
        $stressResult = [PSCustomObject]@{
            TestName = $stressTest.Name
            Description = $stressTest.Description
            Duration = $stressDuration.TotalSeconds
            MemoryIncrease = [math]::Round(($memoryAfter.TotalMemory - $memoryBefore.TotalMemory) / 1MB, 2)
            CPUUsage = $cpuUsage
            Status = if ($cpuUsage -lt $PerformanceResults.QualityGates.CPUUsageThreshold) { "Pass" } else { "Fail" }
            Timestamp = Get-Date
        }
        
        $PerformanceResults.StressTestResults += $stressResult
        $PerformanceResults.TestMetrics.TestsExecuted++
        
        if ($stressResult.Status -eq "Pass") {
            $PerformanceResults.TestMetrics.PassedTests++
            Write-PerformanceLog "✅ $($stressResult.TestName): CPU使用率 $($stressResult.CPUUsage)%" -Level "Success"
        } else {
            $PerformanceResults.TestMetrics.FailedTests++
            Write-PerformanceLog "❌ $($stressResult.TestName): CPU使用率 $($stressResult.CPUUsage)% (閾値超過)" -Level "Critical"
        }
    }
}

# 最終メモリスナップショット
$finalMemory = Get-MemorySnapshot -Phase "Final"

# パフォーマンススコア計算
$passRate = if ($PerformanceResults.TestMetrics.TestsExecuted -gt 0) {
    ($PerformanceResults.TestMetrics.PassedTests / $PerformanceResults.TestMetrics.TestsExecuted) * 100
} else { 0 }

$PerformanceResults.TestMetrics.PerformanceScore = [math]::Round($passRate, 2)

# テスト結果表示
$TestEndTime = Get-Date
$TotalDuration = ($TestEndTime - $TestStartTime).TotalSeconds
$PerformanceResults.TestMetrics.TotalTestDuration = $TotalDuration

Write-Host ""
Write-Host "=== パフォーマンステスト結果 ===" -ForegroundColor Cyan
Write-Host "テスト時間: $([math]::Round($TotalDuration, 2)) 秒" -ForegroundColor White
Write-Host "実行テスト数: $($PerformanceResults.TestMetrics.TestsExecuted)" -ForegroundColor White
Write-Host ""

Write-Host "📊 テスト結果統計:" -ForegroundColor Yellow
Write-Host "  成功: $($PerformanceResults.TestMetrics.PassedTests)" -ForegroundColor Green
Write-Host "  失敗: $($PerformanceResults.TestMetrics.FailedTests)" -ForegroundColor Red
Write-Host "  成功率: $($PerformanceResults.TestMetrics.PerformanceScore)%" -ForegroundColor $(if ($PerformanceResults.TestMetrics.PerformanceScore -ge 80) { "Green" } else { "Red" })
Write-Host ""

Write-Host "🧠 メモリ使用量:" -ForegroundColor Yellow
$totalMemoryIncrease = $finalMemory.TotalMemory - $initialMemory.TotalMemory
Write-Host "  初期メモリ: $([math]::Round($initialMemory.TotalMemory / 1MB, 2)) MB" -ForegroundColor White
Write-Host "  最終メモリ: $([math]::Round($finalMemory.TotalMemory / 1MB, 2)) MB" -ForegroundColor White
Write-Host "  メモリ増加: $([math]::Round($totalMemoryIncrease / 1MB, 2)) MB" -ForegroundColor $(if (($totalMemoryIncrease / 1MB) -lt 50) { "Green" } else { "Red" })
Write-Host ""

# パフォーマンス問題の表示
$failedTests = @()
$failedTests += $PerformanceResults.ModuleLoadTimes | Where-Object { $_.Status -eq "Fail" }
$failedTests += $PerformanceResults.FunctionExecutionTimes | Where-Object { $_.Status -eq "Fail" }
$failedTests += $PerformanceResults.MemoryLeakTests | Where-Object { $_.Status -eq "Fail" }
$failedTests += $PerformanceResults.LoadTestResults | Where-Object { $_.Status -eq "Fail" }
$failedTests += $PerformanceResults.StressTestResults | Where-Object { $_.Status -eq "Fail" }

if ($failedTests.Count -gt 0) {
    Write-Host "⚠️  パフォーマンス問題 ($($failedTests.Count) 件):" -ForegroundColor Red
    foreach ($failedTest in $failedTests | Select-Object -First 5) {
        if ($failedTest.ModuleName) {
            Write-Host "  • モジュール '$($failedTest.ModuleName)': 読み込み時間 $([math]::Round($failedTest.LoadTime, 2))ms" -ForegroundColor Red
        } elseif ($failedTest.FunctionName) {
            Write-Host "  • 関数 '$($failedTest.FunctionName)': 実行時間 $([math]::Round($failedTest.ExecutionTime, 2))ms" -ForegroundColor Red
        } elseif ($failedTest.TestName) {
            Write-Host "  • テスト '$($failedTest.TestName)': パフォーマンス問題" -ForegroundColor Red
        }
    }
    Write-Host ""
}

# レポート生成
if ($GenerateReport) {
    Write-PerformanceLog "パフォーマンスレポートを生成しています" -Level "Info"
    
    # CSV レポート
    $csvPath = Join-Path $OutputDir "performance-test-results_$SessionId.csv"
    $allResults = @()
    $allResults += $PerformanceResults.ModuleLoadTimes | Select-Object @{n="Type";e={"ModuleLoad"}}, @{n="Name";e={$_.ModuleName}}, @{n="Duration";e={$_.LoadTime}}, @{n="MemoryMB";e={$_.MemoryIncreaseMB}}, Status
    $allResults += $PerformanceResults.FunctionExecutionTimes | Select-Object @{n="Type";e={"Function"}}, @{n="Name";e={$_.FunctionName}}, @{n="Duration";e={$_.ExecutionTime}}, @{n="MemoryMB";e={$_.MemoryIncreaseMB}}, Status
    $allResults += $PerformanceResults.MemoryLeakTests | Select-Object @{n="Type";e={"MemoryLeak"}}, @{n="Name";e={$_.TestName}}, @{n="Duration";e={$_.Duration}}, @{n="MemoryMB";e={$_.MemoryLeakMB}}, Status
    $allResults += $PerformanceResults.LoadTestResults | Select-Object @{n="Type";e={"Load"}}, @{n="Name";e={$_.TestName}}, @{n="Duration";e={$_.Duration}}, @{n="MemoryMB";e={$_.MemoryIncrease}}, Status
    $allResults += $PerformanceResults.StressTestResults | Select-Object @{n="Type";e={"Stress"}}, @{n="Name";e={$_.TestName}}, @{n="Duration";e={$_.Duration}}, @{n="MemoryMB";e={$_.MemoryIncrease}}, Status
    
    $allResults | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    
    # メモリスナップショットCSV
    $memoryCsvPath = Join-Path $OutputDir "memory-snapshots_$SessionId.csv"
    $PerformanceResults.MemorySnapshots | Export-Csv -Path $memoryCsvPath -NoTypeInformation -Encoding UTF8
    
    # HTML レポート
    $htmlPath = Join-Path $OutputDir "performance-test-report_$SessionId.html"
    $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>パフォーマンステストレポート - $SessionId</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f8f9fa; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1, h2, h3 { color: #007bff; }
        .metric { display: inline-block; margin: 10px; padding: 15px; border-radius: 5px; text-align: center; min-width: 120px; color: white; }
        .metric-success { background-color: #28a745; }
        .metric-warning { background-color: #ffc107; color: #212529; }
        .metric-danger { background-color: #dc3545; }
        .metric-info { background-color: #17a2b8; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #007bff; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .status-pass { background-color: #d4edda; color: #155724; }
        .status-fail { background-color: #f8d7da; color: #721c24; }
        .chart { width: 100%; height: 300px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚡ パフォーマンステストレポート</h1>
        <p><strong>テストセッション:</strong> $SessionId</p>
        <p><strong>実行時間:</strong> $([math]::Round($TotalDuration, 2)) 秒</p>
        <p><strong>テスト日時:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p><strong>テストタイプ:</strong> $TestType</p>
        
        <h2>📊 テスト結果概要</h2>
        <div>
            <div class="metric metric-info">
                <div style="font-size: 24px;">$($PerformanceResults.TestMetrics.TestsExecuted)</div>
                <div>総テスト数</div>
            </div>
            <div class="metric metric-success">
                <div style="font-size: 24px;">$($PerformanceResults.TestMetrics.PassedTests)</div>
                <div>成功</div>
            </div>
            <div class="metric metric-danger">
                <div style="font-size: 24px;">$($PerformanceResults.TestMetrics.FailedTests)</div>
                <div>失敗</div>
            </div>
            <div class="metric $(if ($PerformanceResults.TestMetrics.PerformanceScore -ge 80) { 'metric-success' } else { 'metric-danger' })">
                <div style="font-size: 24px;">$($PerformanceResults.TestMetrics.PerformanceScore)%</div>
                <div>成功率</div>
            </div>
        </div>
        
        <h2>🧠 メモリ使用量分析</h2>
        <div>
            <div class="metric metric-info">
                <div style="font-size: 20px;">$([math]::Round($initialMemory.TotalMemory / 1MB, 2)) MB</div>
                <div>初期メモリ</div>
            </div>
            <div class="metric metric-info">
                <div style="font-size: 20px;">$([math]::Round($finalMemory.TotalMemory / 1MB, 2)) MB</div>
                <div>最終メモリ</div>
            </div>
            <div class="metric $(if (($totalMemoryIncrease / 1MB) -lt 50) { 'metric-success' } else { 'metric-danger' })">
                <div style="font-size: 20px;">$([math]::Round($totalMemoryIncrease / 1MB, 2)) MB</div>
                <div>メモリ増加</div>
            </div>
        </div>
        
        <h2>⏱️ モジュール読み込み性能</h2>
        <table>
            <tr>
                <th>モジュール名</th>
                <th>読み込み時間 (ms)</th>
                <th>メモリ増加 (MB)</th>
                <th>ステータス</th>
            </tr>
"@
    
    foreach ($moduleLoad in $PerformanceResults.ModuleLoadTimes) {
        $statusClass = if ($moduleLoad.Status -eq "Pass") { "status-pass" } else { "status-fail" }
        $htmlContent += @"
            <tr>
                <td>$($moduleLoad.ModuleName)</td>
                <td>$([math]::Round($moduleLoad.LoadTime, 2))</td>
                <td>$($moduleLoad.MemoryIncreaseMB)</td>
                <td class="$statusClass">$($moduleLoad.Status)</td>
            </tr>
"@
    }
    
    $htmlContent += @"
        </table>
        
        <h2>🔧 関数実行性能</h2>
        <table>
            <tr>
                <th>関数名</th>
                <th>実行時間 (ms)</th>
                <th>メモリ増加 (MB)</th>
                <th>ステータス</th>
            </tr>
"@
    
    foreach ($functionExec in $PerformanceResults.FunctionExecutionTimes) {
        $statusClass = if ($functionExec.Status -eq "Pass") { "status-pass" } else { "status-fail" }
        $htmlContent += @"
            <tr>
                <td>$($functionExec.FunctionName)</td>
                <td>$([math]::Round($functionExec.ExecutionTime, 2))</td>
                <td>$($functionExec.MemoryIncreaseMB)</td>
                <td class="$statusClass">$($functionExec.Status)</td>
            </tr>
"@
    }
    
    $htmlContent += @"
        </table>
        
        <h2>🔍 品質ゲート</h2>
        <table>
            <tr>
                <th>メトリック</th>
                <th>閾値</th>
                <th>説明</th>
            </tr>
            <tr>
                <td>応答時間</td>
                <td>&lt; $($PerformanceResults.QualityGates.ResponseTimeThreshold) ms</td>
                <td>関数・モジュール読み込み時間</td>
            </tr>
            <tr>
                <td>メモリリーク</td>
                <td>&lt; $($PerformanceResults.QualityGates.MemoryLeakThreshold) MB</td>
                <td>テスト実行後のメモリ増加</td>
            </tr>
            <tr>
                <td>CPU使用率</td>
                <td>&lt; $($PerformanceResults.QualityGates.CPUUsageThreshold) %</td>
                <td>プロセスのCPU使用率</td>
            </tr>
            <tr>
                <td>スループット</td>
                <td>&gt; $($PerformanceResults.QualityGates.ThroughputThreshold) ops/sec</td>
                <td>秒あたりの処理数</td>
            </tr>
        </table>
        
        <footer style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; text-align: center; color: #6c757d;">
            <p>Generated by Dev2 - Test/QA Developer | Microsoft 365管理ツール パフォーマンステスト</p>
            <p>Report ID: $SessionId | Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
            <p>Quality Gates: Response Time, Memory Leak, CPU Usage, Throughput</p>
        </footer>
    </div>
</body>
</html>
"@
    
    $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
    
    Write-PerformanceLog "パフォーマンスレポートを生成しました:" -Level "Success"
    Write-PerformanceLog "  結果CSV: $csvPath" -Level "Info"
    Write-PerformanceLog "  メモリCSV: $memoryCsvPath" -Level "Info"
    Write-PerformanceLog "  HTML: $htmlPath" -Level "Info"
}

# 終了ステータス
Write-Host ""
if ($PerformanceResults.TestMetrics.PerformanceScore -ge 80) {
    Write-Host "🟢 パフォーマンステストが合格しました ($($PerformanceResults.TestMetrics.PerformanceScore)%)" -ForegroundColor Green
    $exitCode = 0
} elseif ($PerformanceResults.TestMetrics.PerformanceScore -ge 60) {
    Write-Host "🟡 パフォーマンステストに注意が必要です ($($PerformanceResults.TestMetrics.PerformanceScore)%)" -ForegroundColor Yellow
    $exitCode = 1
} else {
    Write-Host "🔴 パフォーマンステストが不合格です ($($PerformanceResults.TestMetrics.PerformanceScore)%)" -ForegroundColor Red
    $exitCode = 2
}

Write-Host "テスト実行時間: $([math]::Round($TotalDuration, 2)) 秒" -ForegroundColor Gray
Write-Host "パフォーマンススコア: $($PerformanceResults.TestMetrics.PerformanceScore)%" -ForegroundColor $(if ($PerformanceResults.TestMetrics.PerformanceScore -ge 80) { "Green" } else { "Red" })

exit $exitCode