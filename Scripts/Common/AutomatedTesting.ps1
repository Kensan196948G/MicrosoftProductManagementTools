# ================================================================================
# AutomatedTesting.ps1
# Microsoft製品運用管理ツール - 自動テストスクリプト
# ITSM/ISO27001/27002準拠 - 全機能の統合テスト・エラー修正ループ
# ================================================================================

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("All", "Common", "AD", "EXO", "EntraID", "Integration")]
    [string]$TestScope = "All",
    
    [Parameter(Mandatory = $false)]
    [int]$MaxRetryAttempts = 3,
    
    [Parameter(Mandatory = $false)]
    [switch]$FixErrors,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateReport
)

Import-Module "$PSScriptRoot\Common.psm1" -Force

$global:TestResults = @()
$global:TestStartTime = Get-Date

function Write-TestLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [TEST-$Level] $Message"
    
    switch ($Level) {
        "Error" { Write-Host $logEntry -ForegroundColor Red }
        "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
        "Success" { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry -ForegroundColor Cyan }
    }
    
    if ($global:LogPath) {
        Add-Content -Path $global:LogPath -Value $logEntry -Encoding UTF8
    }
}

function Test-ModuleAvailability {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$RequiredModules
    )
    
    Write-TestLog "必要なモジュールの可用性をテストしています..." -Level "Info"
    
    $testResult = @{
        TestName = "モジュール可用性テスト"
        StartTime = Get-Date
        Status = "Success"
        Details = @()
        Errors = @()
    }
    
    foreach ($module in $RequiredModules) {
        try {
            if (Get-Module -ListAvailable -Name $module) {
                $testResult.Details += "✓ $module モジュールが利用可能です"
                Write-TestLog "✓ $module モジュール確認完了" -Level "Success"
            } else {
                $testResult.Status = "Failed"
                $testResult.Errors += "✗ $module モジュールが見つかりません"
                Write-TestLog "✗ $module モジュールが見つかりません" -Level "Error"
            }
        }
        catch {
            $testResult.Status = "Failed"
            $testResult.Errors += "✗ $module モジュールチェックでエラー: $($_.Exception.Message)"
            Write-TestLog "✗ $module モジュールチェックエラー: $($_.Exception.Message)" -Level "Error"
        }
    }
    
    $testResult.EndTime = Get-Date
    $testResult.Duration = ($testResult.EndTime - $testResult.StartTime).TotalSeconds
    
    return $testResult
}

function Test-ConfigurationFile {
    Write-TestLog "設定ファイルのテストを開始します..." -Level "Info"
    
    $testResult = @{
        TestName = "設定ファイルテスト"
        StartTime = Get-Date
        Status = "Success"
        Details = @()
        Errors = @()
    }
    
    try {
        $configPath = "Config\appsettings.json"
        
        if (Test-Path $configPath) {
            $testResult.Details += "✓ 設定ファイルが存在します: $configPath"
            Write-TestLog "✓ 設定ファイル存在確認完了" -Level "Success"
            
            $config = Get-Content $configPath | ConvertFrom-Json
            
            # 必須セクションの確認
            $requiredSections = @("General", "EntraID", "ExchangeOnline", "ActiveDirectory", "Logging", "Reports")
            foreach ($section in $requiredSections) {
                if ($config.$section) {
                    $testResult.Details += "✓ $section セクションが存在します"
                    Write-TestLog "✓ $section セクション確認完了" -Level "Success"
                } else {
                    $testResult.Status = "Failed"
                    $testResult.Errors += "✗ $section セクションが見つかりません"
                    Write-TestLog "✗ $section セクションが見つかりません" -Level "Error"
                }
            }
            
            # 接続情報の検証
            if ($config.EntraID.TenantId -and $config.EntraID.ClientId) {
                $testResult.Details += "✓ Entra ID接続情報が設定されています"
                Write-TestLog "✓ Entra ID接続情報確認完了" -Level "Success"
            } else {
                $testResult.Status = "Warning"
                $testResult.Errors += "⚠ Entra ID接続情報が不完全です"
                Write-TestLog "⚠ Entra ID接続情報が不完全です" -Level "Warning"
            }
        } else {
            $testResult.Status = "Failed"
            $testResult.Errors += "✗ 設定ファイルが見つかりません: $configPath"
            Write-TestLog "✗ 設定ファイルが見つかりません" -Level "Error"
        }
    }
    catch {
        $testResult.Status = "Failed"
        $testResult.Errors += "✗ 設定ファイルテストエラー: $($_.Exception.Message)"
        Write-TestLog "✗ 設定ファイルテストエラー: $($_.Exception.Message)" -Level "Error"
    }
    
    $testResult.EndTime = Get-Date
    $testResult.Duration = ($testResult.EndTime - $testResult.StartTime).TotalSeconds
    
    return $testResult
}

function Test-DirectoryStructure {
    Write-TestLog "ディレクトリ構造のテストを開始します..." -Level "Info"
    
    $testResult = @{
        TestName = "ディレクトリ構造テスト"
        StartTime = Get-Date
        Status = "Success"
        Details = @()
        Errors = @()
    }
    
    $requiredDirectories = @(
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
    
    foreach ($dir in $requiredDirectories) {
        if (Test-Path $dir) {
            $testResult.Details += "✓ ディレクトリが存在します: $dir"
            Write-TestLog "✓ $dir ディレクトリ確認完了" -Level "Success"
        } else {
            $testResult.Status = "Failed"
            $testResult.Errors += "✗ ディレクトリが見つかりません: $dir"
            Write-TestLog "✗ $dir ディレクトリが見つかりません" -Level "Error"
            
            if ($FixErrors) {
                try {
                    New-Item -Path $dir -ItemType Directory -Force | Out-Null
                    $testResult.Details += "✓ ディレクトリを自動作成しました: $dir"
                    Write-TestLog "✓ $dir ディレクトリを自動作成しました" -Level "Success"
                    $testResult.Status = "Success"
                    $testResult.Errors = $testResult.Errors | Where-Object { $_ -notlike "*$dir*" }
                }
                catch {
                    $testResult.Errors += "✗ ディレクトリ自動作成に失敗: $dir - $($_.Exception.Message)"
                    Write-TestLog "✗ $dir ディレクトリ自動作成失敗: $($_.Exception.Message)" -Level "Error"
                }
            }
        }
    }
    
    $testResult.EndTime = Get-Date
    $testResult.Duration = ($testResult.EndTime - $testResult.StartTime).TotalSeconds
    
    return $testResult
}

function Test-ScriptSyntax {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptCategory
    )
    
    Write-TestLog "$ScriptCategory スクリプトの構文テストを開始します..." -Level "Info"
    
    $testResult = @{
        TestName = "$ScriptCategory スクリプト構文テスト"
        StartTime = Get-Date
        Status = "Success"
        Details = @()
        Errors = @()
    }
    
    $scriptPath = "Scripts\$ScriptCategory"
    
    if (Test-Path $scriptPath) {
        $scriptFiles = Get-ChildItem -Path $scriptPath -Filter "*.ps1" -Recurse
        
        foreach ($file in $scriptFiles) {
            try {
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $file.FullName -Raw), [ref]$null)
                $testResult.Details += "✓ 構文チェック完了: $($file.Name)"
                Write-TestLog "✓ $($file.Name) 構文チェック完了" -Level "Success"
            }
            catch {
                $testResult.Status = "Failed"
                $testResult.Errors += "✗ 構文エラー: $($file.Name) - $($_.Exception.Message)"
                Write-TestLog "✗ $($file.Name) 構文エラー: $($_.Exception.Message)" -Level "Error"
            }
        }
    } else {
        $testResult.Status = "Failed"
        $testResult.Errors += "✗ スクリプトディレクトリが見つかりません: $scriptPath"
        Write-TestLog "✗ $scriptPath ディレクトリが見つかりません" -Level "Error"
    }
    
    $testResult.EndTime = Get-Date
    $testResult.Duration = ($testResult.EndTime - $testResult.StartTime).TotalSeconds
    
    return $testResult
}

function Test-FunctionAvailability {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModulePath,
        
        [Parameter(Mandatory = $true)]
        [string[]]$ExpectedFunctions
    )
    
    Write-TestLog "$ModulePath モジュールの関数可用性テストを開始します..." -Level "Info"
    
    $testResult = @{
        TestName = "$ModulePath 関数可用性テスト"
        StartTime = Get-Date
        Status = "Success"
        Details = @()
        Errors = @()
    }
    
    try {
        if (Test-Path $ModulePath) {
            Import-Module $ModulePath -Force
            
            foreach ($function in $ExpectedFunctions) {
                if (Get-Command $function -ErrorAction SilentlyContinue) {
                    $testResult.Details += "✓ 関数が利用可能です: $function"
                    Write-TestLog "✓ $function 関数確認完了" -Level "Success"
                } else {
                    $testResult.Status = "Failed"
                    $testResult.Errors += "✗ 関数が見つかりません: $function"
                    Write-TestLog "✗ $function 関数が見つかりません" -Level "Error"
                }
            }
        } else {
            $testResult.Status = "Failed"
            $testResult.Errors += "✗ モジュールファイルが見つかりません: $ModulePath"
            Write-TestLog "✗ $ModulePath モジュールファイルが見つかりません" -Level "Error"
        }
    }
    catch {
        $testResult.Status = "Failed"
        $testResult.Errors += "✗ 関数可用性テストエラー: $($_.Exception.Message)"
        Write-TestLog "✗ 関数可用性テストエラー: $($_.Exception.Message)" -Level "Error"
    }
    
    $testResult.EndTime = Get-Date
    $testResult.Duration = ($testResult.EndTime - $testResult.StartTime).TotalSeconds
    
    return $testResult
}

function Test-ReportGeneration {
    Write-TestLog "レポート生成テストを開始します..." -Level "Info"
    
    $testResult = @{
        TestName = "レポート生成テスト"
        StartTime = Get-Date
        Status = "Success"
        Details = @()
        Errors = @()
    }
    
    try {
        Import-Module "Scripts\Common\ReportGenerator.psm1" -Force
        
        # テストデータの作成
        $testData = @(
            [PSCustomObject]@{ Name = "テストユーザー1"; Status = "アクティブ"; LastLogin = "2024-01-01" }
            [PSCustomObject]@{ Name = "テストユーザー2"; Status = "非アクティブ"; LastLogin = "2023-12-01" }
        )
        
        $testSections = @(
            @{
                Title = "テストセクション"
                Summary = @(
                    @{ Label = "総ユーザー数"; Value = 2; Risk = "低" }
                    @{ Label = "非アクティブユーザー"; Value = 1; Risk = "中" }
                )
                Data = $testData
                Alerts = @(
                    @{ Type = "Warning"; Message = "これはテストアラートです" }
                )
            }
        )
        
        $testReportPath = "Reports\Daily\AutoTest_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
        
        $result = New-HTMLReport -Title "自動テストレポート" -DataSections $testSections -OutputPath $testReportPath
        
        if ($result -and (Test-Path $testReportPath)) {
            $testResult.Details += "✓ HTMLレポート生成完了: $testReportPath"
            Write-TestLog "✓ HTMLレポート生成完了" -Level "Success"
            
            # ファイルサイズチェック
            $fileSize = (Get-Item $testReportPath).Length
            if ($fileSize -gt 1KB) {
                $testResult.Details += "✓ レポートファイルサイズ正常: $([math]::Round($fileSize/1KB, 2))KB"
                Write-TestLog "✓ レポートファイルサイズ正常" -Level "Success"
            } else {
                $testResult.Status = "Warning"
                $testResult.Errors += "⚠ レポートファイルサイズが小さすぎます: $fileSize bytes"
                Write-TestLog "⚠ レポートファイルサイズが小さすぎます" -Level "Warning"
            }
            
            # テストファイルの削除
            Remove-Item $testReportPath -Force -ErrorAction SilentlyContinue
        } else {
            $testResult.Status = "Failed"
            $testResult.Errors += "✗ HTMLレポート生成に失敗しました"
            Write-TestLog "✗ HTMLレポート生成に失敗しました" -Level "Error"
        }
    }
    catch {
        $testResult.Status = "Failed"
        $testResult.Errors += "✗ レポート生成テストエラー: $($_.Exception.Message)"
        Write-TestLog "✗ レポート生成テストエラー: $($_.Exception.Message)" -Level "Error"
    }
    
    $testResult.EndTime = Get-Date
    $testResult.Duration = ($testResult.EndTime - $testResult.StartTime).TotalSeconds
    
    return $testResult
}

function Invoke-IntegrationTest {
    Write-TestLog "統合テストを開始します..." -Level "Info"
    
    $testResult = @{
        TestName = "統合テスト"
        StartTime = Get-Date
        Status = "Success"
        Details = @()
        Errors = @()
    }
    
    try {
        # 初期化テスト
        $config = Initialize-ManagementTools
        if ($config) {
            $testResult.Details += "✓ 管理ツール初期化完了"
            Write-TestLog "✓ 管理ツール初期化完了" -Level "Success"
        } else {
            $testResult.Status = "Warning"
            $testResult.Errors += "⚠ 設定ファイルが見つかりませんが、初期化は完了しました"
            Write-TestLog "⚠ 設定ファイルなしで初期化完了" -Level "Warning"
        }
        
        # システム要件テスト
        $sysCheck = Test-SystemRequirements
        if ($sysCheck.Overall) {
            $testResult.Details += "✓ システム要件チェック完了"
            Write-TestLog "✓ システム要件チェック完了" -Level "Success"
        } else {
            $testResult.Status = "Warning"
            $testResult.Errors += "⚠ システム要件の一部が満たされていません"
            Write-TestLog "⚠ システム要件の一部が未達" -Level "Warning"
        }
        
        # ディレクトリ作成テスト
        $testDir = New-ReportDirectory -ReportType "Daily"
        if (Test-Path $testDir) {
            $testResult.Details += "✓ レポートディレクトリ作成完了: $testDir"
            Write-TestLog "✓ レポートディレクトリ作成完了" -Level "Success"
        } else {
            $testResult.Status = "Failed"
            $testResult.Errors += "✗ レポートディレクトリ作成に失敗しました"
            Write-TestLog "✗ レポートディレクトリ作成に失敗" -Level "Error"
        }
        
        # CSVエクスポートテスト
        $testData = @([PSCustomObject]@{ Test = "Data"; Value = 123 })
        $testCsvPath = "Reports\Daily\AutoTest_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        
        $csvResult = Export-DataToCSV -Data $testData -FilePath $testCsvPath
        if ($csvResult -and (Test-Path $testCsvPath)) {
            $testResult.Details += "✓ CSVエクスポート完了: $testCsvPath"
            Write-TestLog "✓ CSVエクスポート完了" -Level "Success"
            Remove-Item $testCsvPath -Force -ErrorAction SilentlyContinue
        } else {
            $testResult.Status = "Failed"
            $testResult.Errors += "✗ CSVエクスポートに失敗しました"
            Write-TestLog "✗ CSVエクスポートに失敗" -Level "Error"
        }
    }
    catch {
        $testResult.Status = "Failed"
        $testResult.Errors += "✗ 統合テストエラー: $($_.Exception.Message)"
        Write-TestLog "✗ 統合テストエラー: $($_.Exception.Message)" -Level "Error"
    }
    
    $testResult.EndTime = Get-Date
    $testResult.Duration = ($testResult.EndTime - $testResult.StartTime).TotalSeconds
    
    return $testResult
}

function Invoke-ErrorFixLoop {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$FailedTests
    )
    
    Write-TestLog "エラー修正ループを開始します..." -Level "Info"
    
    $fixResults = @()
    
    foreach ($test in $FailedTests) {
        $attemptCount = 0
        $fixed = $false
        
        while ($attemptCount -lt $MaxRetryAttempts -and -not $fixed) {
            $attemptCount++
            Write-TestLog "エラー修正試行 $attemptCount/$MaxRetryAttempts : $($test.TestName)" -Level "Info"
            
            try {
                switch ($test.TestName) {
                    "ディレクトリ構造テスト" {
                        $retryResult = Test-DirectoryStructure
                        if ($retryResult.Status -eq "Success") {
                            $fixed = $true
                            Write-TestLog "✓ ディレクトリ構造エラーを修正しました" -Level "Success"
                        }
                    }
                    
                    "モジュール可用性テスト" {
                        # モジュールの自動インストール試行
                        foreach ($error in $test.Errors) {
                            if ($error -like "*モジュールが見つかりません*") {
                                $moduleName = ($error -split " ")[1]
                                try {
                                    Install-Module $moduleName -Force -Scope CurrentUser -ErrorAction Stop
                                    Write-TestLog "✓ $moduleName モジュールをインストールしました" -Level "Success"
                                    $fixed = $true
                                }
                                catch {
                                    Write-TestLog "✗ $moduleName モジュールインストール失敗: $($_.Exception.Message)" -Level "Error"
                                }
                            }
                        }
                    }
                    
                    default {
                        Write-TestLog "⚠ $($test.TestName) の自動修正方法が定義されていません" -Level "Warning"
                        break
                    }
                }
            }
            catch {
                Write-TestLog "✗ エラー修正試行でエラー: $($_.Exception.Message)" -Level "Error"
            }
            
            if (-not $fixed -and $attemptCount -lt $MaxRetryAttempts) {
                Start-Sleep -Seconds 5
            }
        }
        
        $fixResults += [PSCustomObject]@{
            TestName = $test.TestName
            AttemptCount = $attemptCount
            Fixed = $fixed
            Status = if ($fixed) { "修正完了" } else { "修正失敗" }
        }
    }
    
    return $fixResults
}

function Generate-TestReport {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$TestResults,
        
        [Parameter(Mandatory = $false)]
        [object[]]$FixResults = @()
    )
    
    Write-TestLog "テスト結果レポートを生成します..." -Level "Info"
    
    $totalTests = $TestResults.Count
    $passedTests = ($TestResults | Where-Object { $_.Status -eq "Success" }).Count
    $failedTests = ($TestResults | Where-Object { $_.Status -eq "Failed" }).Count
    $warningTests = ($TestResults | Where-Object { $_.Status -eq "Warning" }).Count
    
    $testSummary = @(
        @{ Label = "総テスト数"; Value = $totalTests; Risk = "低" }
        @{ Label = "成功"; Value = $passedTests; Risk = "低" }
        @{ Label = "警告"; Value = $warningTests; Risk = "中" }
        @{ Label = "失敗"; Value = $failedTests; Risk = if ($failedTests -gt 0) { "高" } else { "低" } }
    )
    
    $testSections = @(
        @{
            Title = "テスト実行サマリー"
            Summary = $testSummary
            Data = $TestResults | Select-Object TestName, Status, Duration, @{Name="エラー数";Expression={$_.Errors.Count}}
            Alerts = if ($failedTests -gt 0) { 
                @(@{ Type = "Danger"; Message = "$failedTests 件のテストが失敗しました。詳細を確認してください。" })
            } else { @() }
        }
    )
    
    if ($FixResults.Count -gt 0) {
        $testSections += @{
            Title = "エラー修正結果"
            Data = $FixResults
            Alerts = @()
        }
    }
    
    # 詳細な失敗テスト情報
    $failedTestDetails = foreach ($test in ($TestResults | Where-Object { $_.Status -eq "Failed" })) {
        [PSCustomObject]@{
            TestName = $test.TestName
            Duration = $test.Duration
            ErrorCount = $test.Errors.Count
            FirstError = if ($test.Errors.Count -gt 0) { $test.Errors[0] } else { "エラーなし" }
        }
    }
    
    if ($failedTestDetails.Count -gt 0) {
        $testSections += @{
            Title = "失敗テスト詳細"
            Data = $failedTestDetails
            Alerts = @()
        }
    }
    
    $reportPath = "Reports\Daily\AutoTestReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    
    try {
        Import-Module "Scripts\Common\ReportGenerator.psm1" -Force
        $result = New-HTMLReport -Title "自動テスト実行結果レポート" -DataSections $testSections -OutputPath $reportPath
        
        if ($result) {
            Write-TestLog "✓ テスト結果レポートを生成しました: $reportPath" -Level "Success"
            return $reportPath
        } else {
            Write-TestLog "✗ テスト結果レポート生成に失敗しました" -Level "Error"
            return $null
        }
    }
    catch {
        Write-TestLog "✗ テスト結果レポート生成エラー: $($_.Exception.Message)" -Level "Error"
        return $null
    }
}

# メイン実行部分
if ($MyInvocation.InvocationName -ne '.') {
    $config = Initialize-ManagementTools
    
    Write-TestLog "=====================================================================" -Level "Info"
    Write-TestLog "Microsoft製品運用管理ツール 自動テストを開始します" -Level "Info"
    Write-TestLog "テストスコープ: $TestScope" -Level "Info"
    Write-TestLog "=====================================================================" -Level "Info"
    
    try {
        # 基本テストの実行
        if ($TestScope -in @("All", "Common")) {
            $global:TestResults += Test-ConfigurationFile
            $global:TestResults += Test-DirectoryStructure
            $global:TestResults += Test-ModuleAvailability -RequiredModules @("ActiveDirectory", "ExchangeOnlineManagement", "Microsoft.Graph")
            $global:TestResults += Test-ReportGeneration
        }
        
        # スクリプト構文テスト
        if ($TestScope -in @("All", "Common")) {
            $global:TestResults += Test-ScriptSyntax -ScriptCategory "Common"
        }
        
        if ($TestScope -in @("All", "AD")) {
            $global:TestResults += Test-ScriptSyntax -ScriptCategory "AD"
        }
        
        if ($TestScope -in @("All", "EXO")) {
            $global:TestResults += Test-ScriptSyntax -ScriptCategory "EXO"
        }
        
        if ($TestScope -in @("All", "EntraID")) {
            $global:TestResults += Test-ScriptSyntax -ScriptCategory "EntraID"
        }
        
        # 関数可用性テスト
        if ($TestScope -in @("All", "Common")) {
            $global:TestResults += Test-FunctionAvailability -ModulePath "Scripts\Common\Common.psm1" -ExpectedFunctions @("Initialize-ManagementTools", "Get-SystemInfo", "Test-SystemRequirements")
            $global:TestResults += Test-FunctionAvailability -ModulePath "Scripts\Common\Authentication.psm1" -ExpectedFunctions @("Connect-EntraID", "Connect-ExchangeOnlineService", "Connect-ActiveDirectory")
            $global:TestResults += Test-FunctionAvailability -ModulePath "Scripts\Common\Logging.psm1" -ExpectedFunctions @("Initialize-Logging", "Write-Log", "Write-AuditLog")
            $global:TestResults += Test-FunctionAvailability -ModulePath "Scripts\Common\ErrorHandling.psm1" -ExpectedFunctions @("Invoke-WithRetry", "Invoke-SafeOperation", "Test-Prerequisites")
            $global:TestResults += Test-FunctionAvailability -ModulePath "Scripts\Common\ReportGenerator.psm1" -ExpectedFunctions @("New-HTMLReport", "ConvertTo-HTMLTable", "New-SummaryStatistics")
        }
        
        # 統合テスト
        if ($TestScope -in @("All", "Integration")) {
            $global:TestResults += Invoke-IntegrationTest
        }
        
        # 結果の分析
        $failedTests = $global:TestResults | Where-Object { $_.Status -eq "Failed" }
        $warningTests = $global:TestResults | Where-Object { $_.Status -eq "Warning" }
        $successTests = $global:TestResults | Where-Object { $_.Status -eq "Success" }
        
        Write-TestLog "=====================================================================" -Level "Info"
        Write-TestLog "テスト実行結果サマリー:" -Level "Info"
        Write-TestLog "総テスト数: $($global:TestResults.Count)" -Level "Info"
        Write-TestLog "成功: $($successTests.Count)" -Level "Success"
        Write-TestLog "警告: $($warningTests.Count)" -Level "Warning"
        Write-TestLog "失敗: $($failedTests.Count)" -Level "Error"
        Write-TestLog "=====================================================================" -Level "Info"
        
        # エラー修正ループ
        $fixResults = @()
        if ($FixErrors -and $failedTests.Count -gt 0) {
            Write-TestLog "エラー修正ループを実行します..." -Level "Info"
            $fixResults = Invoke-ErrorFixLoop -FailedTests $failedTests
            
            # 修正後の再テスト
            Write-TestLog "修正後の再テストを実行します..." -Level "Info"
            foreach ($fixResult in ($fixResults | Where-Object { $_.Fixed })) {
                switch ($fixResult.TestName) {
                    "ディレクトリ構造テスト" {
                        $retestResult = Test-DirectoryStructure
                        if ($retestResult.Status -eq "Success") {
                            Write-TestLog "✓ $($fixResult.TestName) 再テスト成功" -Level "Success"
                        }
                    }
                }
            }
        }
        
        # レポート生成
        if ($GenerateReport) {
            $reportPath = Generate-TestReport -TestResults $global:TestResults -FixResults $fixResults
            if ($reportPath) {
                Write-TestLog "テスト結果レポート: $reportPath" -Level "Info"
            }
        }
        
        # 実行時間の計算
        $totalDuration = ((Get-Date) - $global:TestStartTime).TotalSeconds
        Write-TestLog "総実行時間: $([math]::Round($totalDuration, 2)) 秒" -Level "Info"
        
        # 終了コードの設定
        if ($failedTests.Count -gt 0) {
            Write-TestLog "テストが失敗しました。詳細なエラー情報を確認してください。" -Level "Error"
            exit 1
        } elseif ($warningTests.Count -gt 0) {
            Write-TestLog "テストは完了しましたが、警告があります。" -Level "Warning"
            exit 2
        } else {
            Write-TestLog "すべてのテストが正常に完了しました。" -Level "Success"
            exit 0
        }
    }
    catch {
        $errorDetails = Get-ErrorDetails -ErrorRecord $_
        Send-ErrorNotification -ErrorDetails $errorDetails
        Write-TestLog "自動テスト実行中に予期しないエラーが発生しました: $($_.Exception.Message)" -Level "Error"
        exit 99
    }
}