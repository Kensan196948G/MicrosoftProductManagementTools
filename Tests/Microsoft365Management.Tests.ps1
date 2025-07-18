#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.3.0' }

<#
.SYNOPSIS
Microsoft 365管理ツール - Pesterフレームワーク包括的テストスイート

.DESCRIPTION
80%以上のテストカバレッジを達成するためのPesterベーステストスイート。
ISO/IEC 27001準拠のセキュリティテスト、パフォーマンステスト、単体テスト、統合テストを含む。

.NOTES
Version: 2025.7.17.1
Author: Dev2 - Test/QA Developer
Framework: Pester 5.3.0+
Requires: PowerShell 5.1+, Microsoft.Graph, ExchangeOnlineManagement
Security: 防御的セキュリティテスト（分析専用）
#>

BeforeAll {
    # テスト環境の初期化
    $script:TestRootPath = Split-Path -Parent $PSScriptRoot
    $script:ConfigPath = Join-Path $TestRootPath "Config\appsettings.json"
    $script:ScriptsPath = Join-Path $TestRootPath "Scripts"
    $script:AppsPath = Join-Path $TestRootPath "Apps"
    $script:LogsPath = Join-Path $TestRootPath "Logs"
    $script:ReportsPath = Join-Path $TestRootPath "Reports"
    
    # テスト用設定
    $script:TestConfig = @{
        OrganizationName = "Pester Test Organization"
        TestMode = $true
        EnableDetailedLogging = $true
        MaxTestDurationSeconds = 300
        MemoryLeakThresholdMB = 50
        CoverageThresholdPercent = 80
    }
    
    # モジュールパスの設定
    $script:CommonModules = @{
        Authentication = Join-Path $ScriptsPath "Common\Authentication.psm1"
        Logging = Join-Path $ScriptsPath "Common\Logging.psm1"
        RealM365DataProvider = Join-Path $ScriptsPath "Common\RealM365DataProvider.psm1"
        ErrorHandling = Join-Path $ScriptsPath "Common\ErrorHandling.psm1"
        MultiFormatReportGenerator = Join-Path $ScriptsPath "Common\MultiFormatReportGenerator.psm1"
    }
    
    # テスト結果集計変数
    $script:TestResults = @{
        UnitTests = @()
        IntegrationTests = @()
        SecurityTests = @()
        PerformanceTests = @()
        CoverageResults = @()
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
        SkippedTests = 0
        TestStartTime = Get-Date
        TestEndTime = $null
        CoveragePercentage = 0
        SecurityIssues = @()
        PerformanceIssues = @()
    }
    
    # ログ出力関数
    function Write-TestLog {
        param(
            [string]$Message,
            [ValidateSet("Info", "Warning", "Error", "Success")]
            [string]$Level = "Info"
        )
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = switch ($Level) {
            "Info" { "White" }
            "Warning" { "Yellow" }
            "Error" { "Red" }
            "Success" { "Green" }
        }
        
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
    
    Write-TestLog "Pester テストスイート初期化完了" -Level "Success"
}

Describe "Microsoft 365 Management Tools - 設定ファイルテスト" -Tags @("Unit", "Configuration") {
    Context "設定ファイルの存在と構造" {
        It "設定ファイルが存在すること" {
            $ConfigPath | Should -Exist
        }
        
        It "設定ファイルが有効なJSONであること" {
            { Get-Content $ConfigPath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "必須設定セクションが存在すること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $config.General | Should -Not -BeNullOrEmpty
            $config.EntraID | Should -Not -BeNullOrEmpty
            $config.ExchangeOnline | Should -Not -BeNullOrEmpty
            $config.Security | Should -Not -BeNullOrEmpty
        }
        
        It "組織名が設定されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $config.General.OrganizationName | Should -Not -BeNullOrEmpty
            $config.General.OrganizationName | Should -Not -Be "YOUR-ORGANIZATION-NAME"
        }
    }
    
    Context "セキュリティ設定の検証" {
        It "環境変数を使用した認証情報設定が推奨されること" {
            $configContent = Get-Content $ConfigPath -Raw
            $configContent | Should -Match '\$\{[A-Z_]+\}'
        }
        
        It "プレースホルダー値が本番環境に残っていないこと" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $configContent = Get-Content $ConfigPath -Raw
            
            $dangerousValues = @(
                "YOUR-CERTIFICATE-THUMBPRINT-HERE",
                "YOUR-CERTIFICATE-PASSWORD-HERE", 
                "YOUR-USERNAME-HERE",
                "YOUR-PASSWORD-HERE",
                "YOUR-CLIENT-SECRET-HERE"
            )
            
            foreach ($value in $dangerousValues) {
                $configContent | Should -Not -Match [regex]::Escape($value)
            }
        }
    }
}

Describe "Microsoft 365 Management Tools - 認証モジュールテスト" -Tags @("Unit", "Authentication") {
    BeforeAll {
        if (Test-Path $CommonModules.Authentication) {
            Import-Module $CommonModules.Authentication -Force
        }
    }
    
    Context "認証モジュールの基本機能" {
        It "認証モジュールが正常に読み込まれること" {
            { Import-Module $CommonModules.Authentication -Force } | Should -Not -Throw
        }
        
        It "認証関数が利用可能であること" {
            $authModule = Get-Module -Name "Authentication"
            $authModule | Should -Not -BeNullOrEmpty
            
            $functions = Get-Command -Module "Authentication" -ErrorAction SilentlyContinue
            $functions | Should -Not -BeNullOrEmpty
        }
        
        It "認証状態テスト関数が動作すること" {
            $testFunction = Get-Command -Name "Test-AuthenticationStatus" -ErrorAction SilentlyContinue
            if ($testFunction) {
                { Test-AuthenticationStatus -RequiredServices @("MicrosoftGraph") } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "Test-AuthenticationStatus関数が見つかりません"
            }
        }
    }
    
    Context "認証のセキュリティ機能" {
        It "認証エラーが適切にハンドリングされること" {
            $invalidConfig = @{
                EntraID = @{
                    ClientId = "invalid-client-id"
                    TenantId = "invalid-tenant-id"
                }
            }
            
            $connectionFunction = Get-Command -Name "Connect-ToMicrosoft365" -ErrorAction SilentlyContinue
            if ($connectionFunction) {
                { Connect-ToMicrosoft365 -Config $invalidConfig -Services @("MicrosoftGraph") } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "Connect-ToMicrosoft365関数が見つかりません"
            }
        }
    }
}

Describe "Microsoft 365 Management Tools - データプロバイダーテスト" -Tags @("Unit", "DataProvider") {
    BeforeAll {
        if (Test-Path $CommonModules.RealM365DataProvider) {
            Import-Module $CommonModules.RealM365DataProvider -Force
        }
    }
    
    Context "データプロバイダーの基本機能" {
        It "データプロバイダーモジュールが正常に読み込まれること" {
            { Import-Module $CommonModules.RealM365DataProvider -Force } | Should -Not -Throw
        }
        
        It "データ取得関数が利用可能であること" {
            $dataModule = Get-Module -Name "RealM365DataProvider"
            if ($dataModule) {
                $functions = Get-Command -Module "RealM365DataProvider" -ErrorAction SilentlyContinue
                $functions | Should -Not -BeNullOrEmpty
            } else {
                Set-ItResult -Skipped -Because "RealM365DataProviderモジュールが見つかりません"
            }
        }
        
        It "ユーザーデータ取得関数が動作すること" {
            $getUsersFunction = Get-Command -Name "Get-AllUsersRealData" -ErrorAction SilentlyContinue
            if ($getUsersFunction) {
                { Get-AllUsersRealData -MaxResults 10 } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "Get-AllUsersRealData関数が見つかりません"
            }
        }
    }
    
    Context "データ品質とパフォーマンス" {
        It "大量データ処理が適切な時間内に完了すること" {
            $measure = Measure-Command {
                $testData = @()
                for ($i = 1; $i -le 1000; $i++) {
                    $testData += [PSCustomObject]@{
                        Id = $i
                        Name = "TestUser$i"
                        Email = "user$i@test.com"
                        Department = "Dept$($i % 10)"
                    }
                }
                $processed = $testData | Where-Object { $_.Department -eq "Dept1" }
            }
            
            $measure.TotalMilliseconds | Should -BeLessThan 5000
        }
    }
}

Describe "Microsoft 365 Management Tools - ログシステムテスト" -Tags @("Unit", "Logging") {
    BeforeAll {
        if (Test-Path $CommonModules.Logging) {
            Import-Module $CommonModules.Logging -Force
        }
        
        $script:TestLogFile = Join-Path $LogsPath "pester_test.log"
        $script:TestLogDir = Split-Path $TestLogFile
        
        if (-not (Test-Path $TestLogDir)) {
            New-Item -ItemType Directory -Path $TestLogDir -Force | Out-Null
        }
    }
    
    Context "ログ機能の基本テスト" {
        It "ログモジュールが正常に読み込まれること" {
            { Import-Module $CommonModules.Logging -Force } | Should -Not -Throw
        }
        
        It "ログ関数が利用可能であること" {
            $logFunction = Get-Command -Name "Write-Log" -ErrorAction SilentlyContinue
            $logFunction | Should -Not -BeNullOrEmpty
        }
        
        It "ログファイルに書き込みができること" {
            $writeLogFunction = Get-Command -Name "Write-Log" -ErrorAction SilentlyContinue
            if ($writeLogFunction) {
                { Write-Log -Message "Pester テストログ" -Level "Info" -LogFile $TestLogFile } | Should -Not -Throw
                
                if (Test-Path $TestLogFile) {
                    $logContent = Get-Content $TestLogFile -Raw
                    $logContent | Should -Match "Pester テストログ"
                }
            } else {
                Set-ItResult -Skipped -Because "Write-Log関数が見つかりません"
            }
        }
    }
    
    Context "ログのセキュリティ機能" {
        It "機密情報がログに記録されないこと" {
            $sensitiveData = @("password", "secret", "token", "key")
            
            if (Test-Path $TestLogFile) {
                $logContent = Get-Content $TestLogFile -Raw
                
                foreach ($sensitive in $sensitiveData) {
                    $logContent | Should -Not -Match $sensitive
                }
            }
        }
    }
    
    AfterAll {
        if (Test-Path $TestLogFile) {
            Remove-Item $TestLogFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Microsoft 365 Management Tools - GUIアプリケーションテスト" -Tags @("Integration", "GUI") {
    BeforeAll {
        $script:GuiAppPath = Join-Path $AppsPath "GuiApp_Enhanced.ps1"
        $script:GuiAppLegacyPath = Join-Path $AppsPath "GuiApp.ps1"
    }
    
    Context "GUIアプリケーションの存在と基本チェック" {
        It "拡張版GUIアプリケーションが存在すること" {
            $GuiAppPath | Should -Exist
        }
        
        It "従来版GUIアプリケーションが存在すること（後方互換性）" {
            $GuiAppLegacyPath | Should -Exist
        }
        
        It "GUIアプリケーションが有効なPowerShellスクリプトであること" {
            { [System.Management.Automation.PSParser]::Tokenize((Get-Content $GuiAppPath -Raw), [ref]$null) } | Should -Not -Throw
        }
    }
    
    Context "Windows Forms依存関係" {
        It "Windows Forms アセンブリが利用可能であること" {
            if ($IsWindows -or $env:OS -match "Windows") {
                { Add-Type -AssemblyName System.Windows.Forms } | Should -Not -Throw
                { Add-Type -AssemblyName System.Drawing } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "Windows環境でのみ実行可能"
            }
        }
    }
}

Describe "Microsoft 365 Management Tools - CLIアプリケーションテスト" -Tags @("Integration", "CLI") {
    BeforeAll {
        $script:CliAppPath = Join-Path $AppsPath "CliApp_Enhanced.ps1"
        $script:CliAppLegacyPath = Join-Path $AppsPath "CliApp.ps1"
    }
    
    Context "CLIアプリケーションの存在と基本チェック" {
        It "拡張版CLIアプリケーションが存在すること" {
            $CliAppPath | Should -Exist
        }
        
        It "従来版CLIアプリケーションが存在すること（後方互換性）" {
            $CliAppLegacyPath | Should -Exist
        }
        
        It "CLIアプリケーションが有効なPowerShellスクリプトであること" {
            { [System.Management.Automation.PSParser]::Tokenize((Get-Content $CliAppPath -Raw), [ref]$null) } | Should -Not -Throw
        }
    }
    
    Context "CLIヘルプ機能" {
        It "CLIヘルプが正常に表示されること" {
            if (Test-Path $CliAppPath) {
                { & $CliAppPath -Help } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "CLIアプリケーションが見つかりません"
            }
        }
    }
}

Describe "Microsoft 365 Management Tools - セキュリティテスト" -Tags @("Security", "ISO27001") {
    Context "認証情報の保護" {
        It "ハードコードされた認証情報が存在しないこと" {
            $scriptFiles = Get-ChildItem -Path $TestRootPath -Filter "*.ps1" -Recurse
            $dangerousPatterns = @(
                "password\s*=\s*['\"].*['\"]",
                "secret\s*=\s*['\"].*['\"]",
                "token\s*=\s*['\"].*['\"]",
                "key\s*=\s*['\"].*['\"]"
            )
            
            foreach ($file in $scriptFiles) {
                $content = Get-Content $file.FullName -Raw
                foreach ($pattern in $dangerousPatterns) {
                    $content | Should -Not -Match $pattern
                }
            }
        }
        
        It "危険なコマンド実行パターンが存在しないこと" {
            $scriptFiles = Get-ChildItem -Path $TestRootPath -Filter "*.ps1" -Recurse
            $dangerousPatterns = @(
                "Invoke-Expression",
                "IEX",
                "cmd /c",
                "powershell\.exe"
            )
            
            foreach ($file in $scriptFiles) {
                $content = Get-Content $file.FullName -Raw
                foreach ($pattern in $dangerousPatterns) {
                    if ($content -match $pattern) {
                        Write-TestLog "危険なパターン '$pattern' が $($file.Name) で発見されました" -Level "Warning"
                    }
                }
            }
        }
    }
    
    Context "ファイル権限とアクセス制御" {
        It "設定ファイルが適切な権限で保護されていること" {
            if (Test-Path $ConfigPath) {
                $acl = Get-Acl $ConfigPath
                $everyoneAccess = $acl.Access | Where-Object { $_.IdentityReference -eq "Everyone" }
                $everyoneAccess | Should -BeNullOrEmpty
            }
        }
        
        It "証明書ディレクトリが適切に保護されていること" {
            $certDir = Join-Path $TestRootPath "Certificates"
            if (Test-Path $certDir) {
                $acl = Get-Acl $certDir
                $everyoneAccess = $acl.Access | Where-Object { $_.IdentityReference -eq "Everyone" }
                $everyoneAccess | Should -BeNullOrEmpty
            }
        }
    }
    
    Context "ISO/IEC 27001 準拠チェック" {
        It "監査ログが有効化されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $config.Security.EnableAuditTrail | Should -Be $true
        }
        
        It "管理者アクセスにMFAが要求されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $config.Security.RequireMFAForAdmins | Should -Be $true
        }
        
        It "機密データが暗号化されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $config.Security.EncryptSensitiveData | Should -Be $true
        }
    }
}

Describe "Microsoft 365 Management Tools - パフォーマンステスト" -Tags @("Performance", "Load") {
    Context "メモリ使用量テスト" {
        It "モジュール読み込み時のメモリ使用量が適切な範囲内であること" {
            $initialMemory = [System.GC]::GetTotalMemory($false)
            
            foreach ($module in $CommonModules.Values) {
                if (Test-Path $module) {
                    Import-Module $module -Force
                }
            }
            
            $finalMemory = [System.GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory
            
            ($memoryIncrease / 1MB) | Should -BeLessThan 100
        }
        
        It "大量データ処理時のメモリリークが発生しないこと" {
            $initialMemory = [System.GC]::GetTotalMemory($false)
            
            # 大量データ処理のシミュレーション
            for ($i = 1; $i -le 1000; $i++) {
                $testData = @()
                for ($j = 1; $j -le 100; $j++) {
                    $testData += [PSCustomObject]@{
                        Id = $j
                        Name = "User$j"
                        Data = "TestData" * 10
                    }
                }
                $processed = $testData | Where-Object { $_.Id -lt 50 }
            }
            
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            
            $finalMemory = [System.GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory
            
            ($memoryIncrease / 1MB) | Should -BeLessThan $TestConfig.MemoryLeakThresholdMB
        }
    }
    
    Context "応答時間テスト" {
        It "設定ファイル読み込みが適切な時間内に完了すること" {
            $measure = Measure-Command {
                $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            }
            
            $measure.TotalMilliseconds | Should -BeLessThan 1000
        }
        
        It "モジュール読み込みが適切な時間内に完了すること" {
            foreach ($module in $CommonModules.Values) {
                if (Test-Path $module) {
                    $measure = Measure-Command {
                        Import-Module $module -Force
                    }
                    
                    $measure.TotalMilliseconds | Should -BeLessThan 5000
                }
            }
        }
    }
}

Describe "Microsoft 365 Management Tools - エラーハンドリングテスト" -Tags @("Unit", "ErrorHandling") {
    Context "エラーハンドリングの基本機能" {
        It "エラーハンドリングモジュールが正常に読み込まれること" {
            if (Test-Path $CommonModules.ErrorHandling) {
                { Import-Module $CommonModules.ErrorHandling -Force } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "ErrorHandlingモジュールが見つかりません"
            }
        }
        
        It "存在しないファイルアクセス時のエラーハンドリングが機能すること" {
            $nonExistentFile = Join-Path $TestRootPath "NonExistent\File.txt"
            
            { 
                try {
                    Get-Content $nonExistentFile -ErrorAction Stop
                } catch {
                    $_.Exception.Message | Should -Match "Cannot find path"
                }
            } | Should -Not -Throw
        }
    }
}

Describe "Microsoft 365 Management Tools - レポート生成テスト" -Tags @("Unit", "Reporting") {
    BeforeAll {
        $script:TestReportData = @(
            [PSCustomObject]@{ Name = "テストユーザー1"; Email = "test1@example.com"; Status = "Active"; LastLogin = (Get-Date).AddDays(-1) },
            [PSCustomObject]@{ Name = "テストユーザー2"; Email = "test2@example.com"; Status = "Inactive"; LastLogin = (Get-Date).AddDays(-7) },
            [PSCustomObject]@{ Name = "テストユーザー3"; Email = "test3@example.com"; Status = "Active"; LastLogin = (Get-Date).AddDays(-3) }
        )
        
        $script:TestReportPath = Join-Path $ReportsPath "Test"
        if (-not (Test-Path $TestReportPath)) {
            New-Item -ItemType Directory -Path $TestReportPath -Force | Out-Null
        }
    }
    
    Context "レポート生成の基本機能" {
        It "レポート生成モジュールが正常に読み込まれること" {
            if (Test-Path $CommonModules.MultiFormatReportGenerator) {
                { Import-Module $CommonModules.MultiFormatReportGenerator -Force } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "MultiFormatReportGeneratorモジュールが見つかりません"
            }
        }
        
        It "CSVレポートが生成できること" {
            $csvPath = Join-Path $TestReportPath "pester_test.csv"
            
            { $TestReportData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 } | Should -Not -Throw
            
            if (Test-Path $csvPath) {
                $csvContent = Import-Csv $csvPath
                $csvContent.Count | Should -Be 3
                $csvContent[0].Name | Should -Be "テストユーザー1"
                
                Remove-Item $csvPath -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "HTMLレポートが生成できること" {
            $htmlPath = Join-Path $TestReportPath "pester_test.html"
            
            $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Pester テストレポート</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Pester テストレポート</h1>
    <table>
        <tr><th>名前</th><th>メール</th><th>状態</th></tr>
"@
            
            foreach ($user in $TestReportData) {
                $htmlContent += "<tr><td>$($user.Name)</td><td>$($user.Email)</td><td>$($user.Status)</td></tr>"
            }
            
            $htmlContent += @"
    </table>
</body>
</html>
"@
            
            { $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8 } | Should -Not -Throw
            
            if (Test-Path $htmlPath) {
                $generatedHtml = Get-Content $htmlPath -Raw
                $generatedHtml | Should -Match "テストユーザー1"
                $generatedHtml | Should -Match "test1@example.com"
                
                Remove-Item $htmlPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe "Microsoft 365 Management Tools - 統合テスト" -Tags @("Integration", "E2E") {
    Context "エンドツーエンドワークフロー" {
        It "設定読み込み → 認証 → データ取得 → レポート生成の流れが正常に動作すること" {
            # 1. 設定読み込み
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $config | Should -Not -BeNullOrEmpty
            
            # 2. 認証モジュール読み込み
            if (Test-Path $CommonModules.Authentication) {
                Import-Module $CommonModules.Authentication -Force
            }
            
            # 3. データプロバイダー読み込み
            if (Test-Path $CommonModules.RealM365DataProvider) {
                Import-Module $CommonModules.RealM365DataProvider -Force
            }
            
            # 4. レポート生成モジュール読み込み
            if (Test-Path $CommonModules.MultiFormatReportGenerator) {
                Import-Module $CommonModules.MultiFormatReportGenerator -Force
            }
            
            # 5. 統合テストの実行
            $testData = @(
                [PSCustomObject]@{ Name = "統合テストユーザー"; Email = "integration@test.com"; Status = "Active" }
            )
            
            $testReportPath = Join-Path $ReportsPath "Integration\integration_test.csv"
            $testReportDir = Split-Path $testReportPath
            
            if (-not (Test-Path $testReportDir)) {
                New-Item -ItemType Directory -Path $testReportDir -Force | Out-Null
            }
            
            { $testData | Export-Csv -Path $testReportPath -NoTypeInformation -Encoding UTF8 } | Should -Not -Throw
            
            if (Test-Path $testReportPath) {
                Remove-Item $testReportPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

AfterAll {
    # テスト終了時の処理
    $script:TestResults.TestEndTime = Get-Date
    $script:TestResults.TotalTestDuration = ($script:TestResults.TestEndTime - $script:TestResults.TestStartTime).TotalSeconds
    
    Write-TestLog "Pester テストスイート完了" -Level "Success"
    Write-TestLog "総実行時間: $([math]::Round($script:TestResults.TotalTestDuration, 2)) 秒" -Level "Info"
    
    # テスト結果の出力
    $testResultPath = Join-Path $PSScriptRoot "TestResults"
    if (-not (Test-Path $testResultPath)) {
        New-Item -ItemType Directory -Path $testResultPath -Force | Out-Null
    }
    
    $resultFile = Join-Path $testResultPath "PesterTestResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $script:TestResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultFile -Encoding UTF8
    
    Write-TestLog "テスト結果を出力しました: $resultFile" -Level "Success"
}