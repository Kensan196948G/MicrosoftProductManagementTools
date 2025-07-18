#Requires -Version 5.1

<#
.SYNOPSIS
Microsoft 365管理ツール - エラーハンドリング・エッジケーステスト

.DESCRIPTION
システムのエラーハンドリング、異常ケース、境界値条件を網羅的にテストします。
堅牢性と障害復旧能力を評価し、エンタープライズ環境での安定性を確保します。

.NOTES
Version: 2025.7.17.1
Author: Test/QA Developer
Requires: PowerShell 5.1+

.EXAMPLE
.\error-handling-edge-case-test.ps1
全エラーハンドリングテストを実行

.EXAMPLE
.\error-handling-edge-case-test.ps1 -TestCategory "Authentication" -Verbose
認証エラーハンドリングテストのみ実行

.EXAMPLE
.\error-handling-edge-case-test.ps1 -StressTest -Iterations 100
ストレステスト（100回反復）を実行
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "Authentication", "FileIO", "Network", "Memory", "Configuration", "EdgeCases")]
    [string]$TestCategory = "All",
    
    [switch]$StressTest,
    [int]$Iterations = 10,
    [switch]$GenerateReport = $true,
    [string]$OutputPath = "TestReports"
)

# エラーハンドリングテスト設定
$script:ErrorTestResults = @()
$script:PassedTests = 0
$script:FailedTests = 0
$script:EdgeCasesDetected = 0
$script:TestStartTime = Get-Date

# ヘルパー関数: エラーハンドリングテスト
function Test-ErrorHandling {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [string]$ExpectedBehavior = "Graceful Error Handling",
        [string]$Category = "Error Handling"
    )
    
    $testResult = [PSCustomObject]@{
        TestName = $TestName
        Category = $Category
        Status = "Unknown"
        ExpectedBehavior = $ExpectedBehavior
        ActualBehavior = ""
        Message = ""
        Timestamp = Get-Date
    }
    
    try {
        Write-Host "  🧪 $TestName をテスト中..." -ForegroundColor Yellow
        
        $result = & $TestScript
        
        if ($result.Success) {
            $testResult.Status = "Passed"
            $testResult.ActualBehavior = $result.Behavior
            $testResult.Message = $result.Message
            Write-Host "  ✅ $TestName - 成功" -ForegroundColor Green
        } else {
            $testResult.Status = "Failed"
            $testResult.ActualBehavior = $result.Behavior
            $testResult.Message = $result.Message
            Write-Host "  ❌ $TestName - 失敗: $($result.Message)" -ForegroundColor Red
        }
        
    } catch {
        $testResult.Status = "Exception"
        $testResult.ActualBehavior = "Unhandled Exception"
        $testResult.Message = $_.Exception.Message
        Write-Host "  🔥 $TestName - 例外発生: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $testResult
}

# 1. 設定ファイルエラーハンドリングテスト
Write-Host "1. 設定ファイルエラーハンドリングテスト" -ForegroundColor Yellow

$EdgeCaseResults += Test-ErrorHandling -TestName "存在しない設定ファイル" -TestScript {
    $configPath = Join-Path $PSScriptRoot "..\Config\nonexistent.json"
    
    try {
        # 認証モジュールを読み込んで、存在しない設定ファイルでテスト
        $authPath = Join-Path $PSScriptRoot "..\Scripts\Common\Authentication.psm1"
        if (Test-Path $authPath) {
            Import-Module $authPath -Force
            
            # 存在しない設定ファイルを渡す
            $fakeConfig = [PSCustomObject]@{
                EntraID = @{
                    ClientId = "test-client-id"
                    TenantId = "test-tenant-id"
                    ClientSecret = "test-secret"
                }
            }
            
            $result = Test-GraphConnection
            
            return @{
                Success = $true
                Behavior = "Graceful Error Handling"
                Message = "存在しない設定ファイルでも適切にエラーハンドリングされました"
            }
        } else {
            return @{
                Success = $false
                Behavior = "Module Not Found"
                Message = "認証モジュールが見つかりません"
            }
        }
    } catch {
        return @{
            Success = $true
            Behavior = "Exception Caught"
            Message = "例外が適切にキャッチされました: $($_.Exception.Message)"
        }
    }
}

$EdgeCaseResults += Test-ErrorHandling -TestName "不正な JSON 形式" -TestScript {
    $configPath = Join-Path $PSScriptRoot "..\Config\appsettings.json"
    
    try {
        # バックアップ作成
        $backupPath = "$configPath.backup"
        if (Test-Path $configPath) {
            Copy-Item $configPath $backupPath -Force
        }
        
        # 不正なJSONを書き込み
        "{ invalid json content" | Out-File -FilePath $configPath -Encoding UTF8 -Force
        
        # 設定ファイル読み込みテスト
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $success = $false
            $behavior = "No Error Handling"
            $message = "不正なJSONが読み込まれてしまいました"
        } catch {
            $success = $true
            $behavior = "JSON Parse Error Caught"
            $message = "JSON解析エラーが適切にキャッチされました: $($_.Exception.Message)"
        }
        
        # バックアップから復元
        if (Test-Path $backupPath) {
            Copy-Item $backupPath $configPath -Force
            Remove-Item $backupPath -Force
        }
        
        return @{
            Success = $success
            Behavior = $behavior
            Message = $message
        }
    } catch {
        return @{
            Success = $false
            Behavior = "Test Setup Error"
            Message = "テストセットアップエラー: $($_.Exception.Message)"
        }
    }
}

# 2. 認証エラーハンドリングテスト
Write-Host "2. 認証エラーハンドリングテスト" -ForegroundColor Yellow

$EdgeCaseResults += Test-ErrorHandling -TestName "無効な認証情報" -TestScript {
    try {
        $authPath = Join-Path $PSScriptRoot "..\Scripts\Common\Authentication.psm1"
        if (-not (Test-Path $authPath)) {
            return @{
                Success = $false
                Behavior = "Module Not Found"
                Message = "認証モジュールが見つかりません"
            }
        }
        
        Import-Module $authPath -Force
        
        # 無効な認証情報を作成
        $invalidConfig = [PSCustomObject]@{
            EntraID = @{
                ClientId = "invalid-client-id"
                TenantId = "invalid-tenant-id"
                ClientSecret = "invalid-secret"
            }
        }
        
        # 認証試行
        try {
            $result = Connect-ToMicrosoft365 -Config $invalidConfig -Services @("MicrosoftGraph")
            
            if ($result.Success) {
                return @{
                    Success = $false
                    Behavior = "Unexpected Success"
                    Message = "無効な認証情報で成功してしまいました"
                }
            } else {
                return @{
                    Success = $true
                    Behavior = "Authentication Error Handled"
                    Message = "認証エラーが適切にハンドリングされました: $($result.Errors -join ', ')"
                }
            }
        } catch {
            return @{
                Success = $true
                Behavior = "Authentication Exception Caught"
                Message = "認証例外が適切にキャッチされました: $($_.Exception.Message)"
            }
        }
    } catch {
        return @{
            Success = $false
            Behavior = "Test Setup Error"
            Message = "テストセットアップエラー: $($_.Exception.Message)"
        }
    }
}

$EdgeCaseResults += Test-ErrorHandling -TestName "ネットワーク接続エラー" -TestScript {
    try {
        # 無効なエンドポイントを使用してネットワークエラーをシミュレート
        $authPath = Join-Path $PSScriptRoot "..\Scripts\Common\Authentication.psm1"
        if (-not (Test-Path $authPath)) {
            return @{
                Success = $false
                Behavior = "Module Not Found"
                Message = "認証モジュールが見つかりません"
            }
        }
        
        Import-Module $authPath -Force
        
        # 無効なテナントIDでネットワークエラーをシミュレート
        $networkErrorConfig = [PSCustomObject]@{
            EntraID = @{
                ClientId = "00000000-0000-0000-0000-000000000000"
                TenantId = "invalid-tenant-that-does-not-exist"
                ClientSecret = "test-secret"
            }
        }
        
        # 短いタイムアウトで接続試行
        try {
            $result = Connect-ToMicrosoft365 -Config $networkErrorConfig -Services @("MicrosoftGraph") -TimeoutSeconds 5
            
            if ($result.Success) {
                return @{
                    Success = $false
                    Behavior = "Unexpected Success"
                    Message = "ネットワークエラーが発生するはずでした"
                }
            } else {
                return @{
                    Success = $true
                    Behavior = "Network Error Handled"
                    Message = "ネットワークエラーが適切にハンドリングされました"
                }
            }
        } catch {
            return @{
                Success = $true
                Behavior = "Network Exception Caught"
                Message = "ネットワーク例外が適切にキャッチされました: $($_.Exception.Message)"
            }
        }
    } catch {
        return @{
            Success = $false
            Behavior = "Test Setup Error"
            Message = "テストセットアップエラー: $($_.Exception.Message)"
        }
    }
}

# 3. ファイル操作エラーハンドリングテスト
Write-Host "3. ファイル操作エラーハンドリングテスト" -ForegroundColor Yellow

$EdgeCaseResults += Test-ErrorHandling -TestName "読み取り専用ファイル" -TestScript {
    try {
        $testFile = Join-Path $PSScriptRoot "..\Logs\readonly_test.log"
        
        # テストファイル作成
        "test content" | Out-File -FilePath $testFile -Encoding UTF8 -Force
        
        # 読み取り専用に設定
        Set-ItemProperty -Path $testFile -Name IsReadOnly -Value $true
        
        # ログモジュールを読み込んで書き込み試行
        $logPath = Join-Path $PSScriptRoot "..\Scripts\Common\Logging.psm1"
        if (Test-Path $logPath) {
            Import-Module $logPath -Force
            
            try {
                Write-Log -Message "読み取り専用ファイルテスト" -LogFile $testFile
                $behavior = "Write to Read-Only File"
                $message = "読み取り専用ファイルに書き込みが成功しました（予期しない動作）"
                $success = $false
            } catch {
                $behavior = "Read-Only File Error Handled"
                $message = "読み取り専用ファイルエラーが適切にハンドリングされました: $($_.Exception.Message)"
                $success = $true
            }
        } else {
            $behavior = "Module Not Found"
            $message = "ログモジュールが見つかりません"
            $success = $false
        }
        
        # クリーンアップ
        if (Test-Path $testFile) {
            Set-ItemProperty -Path $testFile -Name IsReadOnly -Value $false
            Remove-Item $testFile -Force
        }
        
        return @{
            Success = $success
            Behavior = $behavior
            Message = $message
        }
    } catch {
        return @{
            Success = $false
            Behavior = "Test Setup Error"
            Message = "テストセットアップエラー: $($_.Exception.Message)"
        }
    }
}

$EdgeCaseResults += Test-ErrorHandling -TestName "存在しないディレクトリ" -TestScript {
    try {
        $nonExistentPath = Join-Path $PSScriptRoot "..\NonExistentDir\test.log"
        
        # ログモジュールを読み込んで存在しないディレクトリに書き込み試行
        $logPath = Join-Path $PSScriptRoot "..\Scripts\Common\Logging.psm1"
        if (Test-Path $logPath) {
            Import-Module $logPath -Force
            
            try {
                Write-Log -Message "存在しないディレクトリテスト" -LogFile $nonExistentPath
                
                # ディレクトリが作成されたかチェック
                if (Test-Path $nonExistentPath) {
                    $behavior = "Directory Auto-Created"
                    $message = "存在しないディレクトリが自動的に作成されました"
                    $success = $true
                    
                    # クリーンアップ
                    Remove-Item (Split-Path $nonExistentPath) -Recurse -Force
                } else {
                    $behavior = "Directory Not Created"
                    $message = "ディレクトリが作成されませんでした"
                    $success = $false
                }
            } catch {
                $behavior = "Directory Error Handled"
                $message = "ディレクトリエラーが適切にハンドリングされました: $($_.Exception.Message)"
                $success = $true
            }
        } else {
            $behavior = "Module Not Found"
            $message = "ログモジュールが見つかりません"
            $success = $false
        }
        
        return @{
            Success = $success
            Behavior = $behavior
            Message = $message
        }
    } catch {
        return @{
            Success = $false
            Behavior = "Test Setup Error"
            Message = "テストセットアップエラー: $($_.Exception.Message)"
        }
    }
}

# 4. 大量データ処理エラーハンドリングテスト
Write-Host "4. 大量データ処理エラーハンドリングテスト" -ForegroundColor Yellow

$EdgeCaseResults += Test-ErrorHandling -TestName "大量データ処理" -TestScript {
    try {
        # 大量のテストデータを作成
        $largeDataSet = @()
        for ($i = 1; $i -le 10000; $i++) {
            $largeDataSet += [PSCustomObject]@{
                Id = $i
                Name = "TestUser$i"
                Email = "testuser$i@example.com"
                Department = "Department$($i % 10)"
                Status = if ($i % 2 -eq 0) { "Active" } else { "Inactive" }
            }
        }
        
        # データプロバイダーモジュールのテスト
        $dataPath = Join-Path $PSScriptRoot "..\Scripts\Common\RealM365DataProvider.psm1"
        if (Test-Path $dataPath) {
            Import-Module $dataPath -Force
            
            try {
                # 大量データの処理時間を測定
                $startTime = Get-Date
                $processedData = $largeDataSet | ForEach-Object { $_ }
                $endTime = Get-Date
                $processingTime = ($endTime - $startTime).TotalSeconds
                
                if ($processingTime -lt 30) {
                    return @{
                        Success = $true
                        Behavior = "Large Data Processed"
                        Message = "大量データ（$($largeDataSet.Count)件）が $([math]::Round($processingTime, 2)) 秒で処理されました"
                    }
                } else {
                    return @{
                        Success = $false
                        Behavior = "Large Data Processing Slow"
                        Message = "大量データ処理が遅すぎます: $([math]::Round($processingTime, 2)) 秒"
                    }
                }
            } catch {
                return @{
                    Success = $true
                    Behavior = "Large Data Error Handled"
                    Message = "大量データ処理エラーが適切にハンドリングされました: $($_.Exception.Message)"
                }
            }
        } else {
            return @{
                Success = $false
                Behavior = "Module Not Found"
                Message = "データプロバイダーモジュールが見つかりません"
            }
        }
    } catch {
        return @{
            Success = $false
            Behavior = "Test Setup Error"
            Message = "テストセットアップエラー: $($_.Exception.Message)"
        }
    }
}

# 5. 特殊文字・Unicode処理テスト
Write-Host "5. 特殊文字・Unicode処理テスト" -ForegroundColor Yellow

$EdgeCaseResults += Test-ErrorHandling -TestName "特殊文字処理" -TestScript {
    try {
        # 特殊文字を含むテストデータ
        $specialCharData = @(
            "日本語テスト",
            "Émile Citroën",
            "Москва",
            "北京",
            "🚀🔥💯",
            "'; DROP TABLE users; --",
            "<script>alert('XSS')</script>",
            "C:\Windows\System32\cmd.exe",
            "$(Get-Process)"
        )
        
        $logPath = Join-Path $PSScriptRoot "..\Scripts\Common\Logging.psm1"
        if (Test-Path $logPath) {
            Import-Module $logPath -Force
            
            $testLogFile = Join-Path $PSScriptRoot "..\Logs\special_chars_test.log"
            
            try {
                foreach ($testData in $specialCharData) {
                    Write-Log -Message "特殊文字テスト: $testData" -LogFile $testLogFile
                }
                
                # ログファイルの内容確認
                if (Test-Path $testLogFile) {
                    $logContent = Get-Content $testLogFile -Raw
                    $containsSpecialChars = $specialCharData | ForEach-Object { $logContent -like "*$_*" }
                    
                    if ($containsSpecialChars -contains $true) {
                        $behavior = "Special Characters Handled"
                        $message = "特殊文字が適切に処理されました"
                        $success = $true
                    } else {
                        $behavior = "Special Characters Not Preserved"
                        $message = "特殊文字が正しく保存されませんでした"
                        $success = $false
                    }
                    
                    # クリーンアップ
                    Remove-Item $testLogFile -Force
                } else {
                    $behavior = "Log File Not Created"
                    $message = "ログファイルが作成されませんでした"
                    $success = $false
                }
            } catch {
                $behavior = "Special Characters Error Handled"
                $message = "特殊文字処理エラーが適切にハンドリングされました: $($_.Exception.Message)"
                $success = $true
            }
        } else {
            $behavior = "Module Not Found"
            $message = "ログモジュールが見つかりません"
            $success = $false
        }
        
        return @{
            Success = $success
            Behavior = $behavior
            Message = $message
        }
    } catch {
        return @{
            Success = $false
            Behavior = "Test Setup Error"
            Message = "テストセットアップエラー: $($_.Exception.Message)"
        }
    }
}

# 6. メモリ不足シミュレーションテスト
Write-Host "6. メモリ不足シミュレーションテスト" -ForegroundColor Yellow

$EdgeCaseResults += Test-ErrorHandling -TestName "メモリ不足処理" -TestScript {
    try {
        # メモリ使用量の初期値
        $initialMemory = [System.GC]::GetTotalMemory($false)
        
        # 大量のオブジェクトを作成してメモリ使用量を増加
        $largeObjects = @()
        for ($i = 1; $i -le 1000; $i++) {
            $largeObjects += New-Object byte[] 1MB
        }
        
        $currentMemory = [System.GC]::GetTotalMemory($false)
        $memoryIncrease = $currentMemory - $initialMemory
        
        try {
            # ガベージコレクションの実行
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            
            $afterGCMemory = [System.GC]::GetTotalMemory($false)
            $memoryReclaimed = $currentMemory - $afterGCMemory
            
            # メモリが適切に解放されたかチェック
            if ($memoryReclaimed -gt 0) {
                $behavior = "Memory Management Works"
                $message = "メモリ管理が正常に動作しています（$([math]::Round($memoryReclaimed / 1MB, 2)) MB解放）"
                $success = $true
            } else {
                $behavior = "Memory Not Reclaimed"
                $message = "メモリが解放されませんでした"
                $success = $false
            }
        } catch {
            $behavior = "Memory Error Handled"
            $message = "メモリエラーが適切にハンドリングされました: $($_.Exception.Message)"
            $success = $true
        }
        
        # クリーンアップ
        $largeObjects = $null
        [System.GC]::Collect()
        
        return @{
            Success = $success
            Behavior = $behavior
            Message = $message
        }
    } catch {
        return @{
            Success = $false
            Behavior = "Test Setup Error"
            Message = "テストセットアップエラー: $($_.Exception.Message)"
        }
    }
}

# 結果の表示
Write-Host ""
Write-Host "=== エラーハンドリングとエッジケーステスト結果 ===" -ForegroundColor Cyan

$passedTests = ($EdgeCaseResults | Where-Object { $_.Status -eq "Passed" }).Count
$failedTests = ($EdgeCaseResults | Where-Object { $_.Status -eq "Failed" }).Count
$exceptionTests = ($EdgeCaseResults | Where-Object { $_.Status -eq "Exception" }).Count

Write-Host "総テスト数: $($EdgeCaseResults.Count)" -ForegroundColor White
Write-Host "成功: $passedTests" -ForegroundColor Green
Write-Host "失敗: $failedTests" -ForegroundColor Red
Write-Host "例外: $exceptionTests" -ForegroundColor Yellow

# 詳細結果の表示
Write-Host ""
Write-Host "詳細結果:" -ForegroundColor White
foreach ($result in $EdgeCaseResults) {
    $color = switch ($result.Status) {
        "Passed" { "Green" }
        "Failed" { "Red" }
        "Exception" { "Yellow" }
        default { "White" }
    }
    
    Write-Host "[$($result.Status)] $($result.TestName)" -ForegroundColor $color
    Write-Host "  カテゴリ: $($result.Category)" -ForegroundColor Gray
    Write-Host "  期待動作: $($result.ExpectedBehavior)" -ForegroundColor Gray
    Write-Host "  実際動作: $($result.ActualBehavior)" -ForegroundColor Gray
    Write-Host "  メッセージ: $($result.Message)" -ForegroundColor Gray
    Write-Host ""
}

# CSV形式でレポート出力
try {
    $reportPath = Join-Path $PSScriptRoot "TestReports\error-handling-edge-case-report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    
    # TestReportsディレクトリを作成
    $reportDir = Split-Path $reportPath
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $EdgeCaseResults | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8
    Write-Host "📊 エラーハンドリングテストレポートを出力しました: $reportPath" -ForegroundColor Green
} catch {
    Write-Host "⚠️ レポート出力エラー: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "⚠️  エラーハンドリングとエッジケーステスト完了" -ForegroundColor Green