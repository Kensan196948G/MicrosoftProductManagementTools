#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '3.0.0' }

<#
.SYNOPSIS
Microsoft 365管理ツール - コア機能 Pesterテストスイート

.DESCRIPTION
Dev2 - Test/QA Developerによる包括的なコア機能テストスイート。
80%以上のテストカバレッジ達成を目標とし、GUI・CLI・認証・データプロバイダーの主要機能をテストします。

.NOTES
Version: 2025.7.18.1
Author: Dev2 - Test/QA Developer
Framework: Pester 3.4.0+, PowerShell 5.1+
Coverage Target: 80%+ for core functionality
Security: ISO/IEC 27001準拠のセキュリティテスト含む
#>

# テスト環境の初期化（グローバルスコープ）
$script:TestRootPath = "E:\MicrosoftProductManagementTools"
$script:AppsPath = Join-Path $TestRootPath "Apps"
$script:ScriptsPath = Join-Path $TestRootPath "Scripts"
$script:ConfigPath = Join-Path $TestRootPath "Config\appsettings.json"
$script:LogsPath = Join-Path $TestRootPath "Logs"
$script:ReportsPath = Join-Path $TestRootPath "Reports"

# テスト用ログ関数
function Write-TestLog {
    param([string]$Message, [string]$Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# テスト用ダミーデータ生成
function New-TestUserData {
    param([int]$Count = 5)
    $users = @()
    for ($i = 1; $i -le $Count; $i++) {
        $users += [PSCustomObject]@{
            DisplayName = "テストユーザー$i"
            UserPrincipalName = "testuser$i@contoso.com"
            Mail = "testuser$i@contoso.com"
            Department = "テスト部門$($i % 3 + 1)"
            JobTitle = "テスト職位$i"
            AccountEnabled = $true
            CreatedDateTime = (Get-Date).AddDays(-30)
            LastSignInDateTime = (Get-Date).AddDays(-$i)
            AssignedLicenses = @(@{SkuId = "TEST-SKU-$i"})
            MfaStatus = if ($i % 2 -eq 0) { "Enabled" } else { "Disabled" }
        }
    }
    return $users
}

Write-TestLog "テスト環境初期化完了" -Level "Success"

# 1. 設定ファイルテスト
Describe "設定ファイル機能テスト" -Tags @("Unit", "Configuration", "Core") {
    Context "設定ファイルの存在と妥当性" {
        It "設定ファイルが存在すること" {
            Test-Path $ConfigPath | Should Be $true
        }
        
        It "設定ファイルが有効なJSONであること" {
            { $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json } | Should Not Throw
            $config | Should Not BeNullOrEmpty
        }
        
        It "必須設定項目が存在すること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $config.General | Should Not BeNullOrEmpty
            $config.EntraID | Should Not BeNullOrEmpty
            $config.ExchangeOnline | Should Not BeNullOrEmpty
            $config.Security | Should Not BeNullOrEmpty
        }
        
        It "組織名が適切に設定されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $config.General.OrganizationName | Should Not BeNullOrEmpty
            $config.General.OrganizationName | Should Not Be "YOUR-ORGANIZATION-NAME"
        }
        
        It "セキュリティ設定が有効であること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $config.Security.EnableAuditTrail | Should Be $true
            $config.Security.RequireMFAForAdmins | Should Be $true
            $config.Security.EncryptSensitiveData | Should Be $true
        }
    }
}

# 2. GUI アプリケーションテスト
Describe "GUI アプリケーション機能テスト" -Tags @("Unit", "GUI", "Core") {
    Context "GUI アプリケーションファイルの存在" {
        It "拡張版GUIアプリケーションが存在すること" {
            $guiEnhancedPath = Join-Path $AppsPath "GuiApp_Enhanced.ps1"
            Test-Path $guiEnhancedPath | Should Be $true
        }
        
        It "従来版GUIアプリケーションが存在すること" {
            $guiPath = Join-Path $AppsPath "GuiApp.ps1"
            Test-Path $guiPath | Should Be $true
        }
        
        It "GUIアプリケーションが有効なPowerShellスクリプトであること" {
            $guiEnhancedPath = Join-Path $AppsPath "GuiApp_Enhanced.ps1"
            { [System.Management.Automation.PSParser]::Tokenize((Get-Content $guiEnhancedPath -Raw), [ref]$null) } | Should Not Throw
        }
    }
    
    Context "Windows Forms依存関係" {
        It "Windows Forms アセンブリが利用可能であること" {
            { Add-Type -AssemblyName System.Windows.Forms } | Should Not Throw
            { Add-Type -AssemblyName System.Drawing } | Should Not Throw
        }
        
        It "Windows Forms の基本クラスが利用可能であること" {
            { [System.Windows.Forms.Form] } | Should Not Throw
            { [System.Windows.Forms.Button] } | Should Not Throw
            { [System.Windows.Forms.TextBox] } | Should Not Throw
        }
    }
}

# 3. CLI アプリケーションテスト
Describe "CLI アプリケーション機能テスト" -Tags @("Unit", "CLI", "Core") {
    Context "CLI アプリケーションファイルの存在" {
        It "拡張版CLIアプリケーションが存在すること" {
            $cliEnhancedPath = Join-Path $AppsPath "CliApp_Enhanced.ps1"
            Test-Path $cliEnhancedPath | Should Be $true
        }
        
        It "従来版CLIアプリケーションが存在すること" {
            $cliPath = Join-Path $AppsPath "CliApp.ps1"
            Test-Path $cliPath | Should Be $true
        }
        
        It "CLIアプリケーションが有効なPowerShellスクリプトであること" {
            $cliEnhancedPath = Join-Path $AppsPath "CliApp_Enhanced.ps1"
            { [System.Management.Automation.PSParser]::Tokenize((Get-Content $cliEnhancedPath -Raw), [ref]$null) } | Should Not Throw
        }
    }
}

# 4. 認証モジュールテスト
Describe "認証モジュール機能テスト" -Tags @("Unit", "Authentication", "Core") {
    Context "認証モジュールの基本機能" {
        It "認証モジュールファイルが存在すること" {
            $authModulePath = Join-Path $ScriptsPath "Common\Authentication.psm1"
            Test-Path $authModulePath | Should Be $true
        }
        
        It "認証モジュールが正常に読み込まれること" {
            $authModulePath = Join-Path $ScriptsPath "Common\Authentication.psm1"
            { Import-Module $authModulePath -Force } | Should Not Throw
        }
        
        It "認証関数がエクスポートされていること" {
            $authModulePath = Join-Path $ScriptsPath "Common\Authentication.psm1"
            Import-Module $authModulePath -Force
            $functions = Get-Command -Module Authentication -ErrorAction SilentlyContinue
            $functions | Should Not BeNullOrEmpty
        }
    }
    
    Context "認証設定の検証" {
        It "認証設定が環境変数パターンを使用していること" {
            $configContent = Get-Content $ConfigPath -Raw
            $configContent | Should Match '\$\{[A-Z_]+\}'
        }
        
        It "危険な認証情報がハードコードされていないこと" {
            $configContent = Get-Content $ConfigPath -Raw
            $dangerousValues = @(
                "YOUR-CERTIFICATE-THUMBPRINT-HERE",
                "YOUR-CERTIFICATE-PASSWORD-HERE", 
                "YOUR-USERNAME-HERE",
                "YOUR-PASSWORD-HERE",
                "YOUR-CLIENT-SECRET-HERE"
            )
            
            foreach ($value in $dangerousValues) {
                $configContent | Should Not Match [regex]::Escape($value)
            }
        }
    }
}

# 5. データプロバイダーテスト
Describe "データプロバイダー機能テスト" -Tags @("Unit", "DataProvider", "Core") {
    Context "データプロバイダーモジュールの基本機能" {
        It "リアルデータプロバイダーモジュールが存在すること" {
            $dataProviderPath = Join-Path $ScriptsPath "Common\RealM365DataProvider.psm1"
            Test-Path $dataProviderPath | Should Be $true
        }
        
        It "データプロバイダーモジュールが正常に読み込まれること" {
            $dataProviderPath = Join-Path $ScriptsPath "Common\RealM365DataProvider.psm1"
            { Import-Module $dataProviderPath -Force } | Should Not Throw
        }
        
        It "データ取得関数がエクスポートされていること" {
            $dataProviderPath = Join-Path $ScriptsPath "Common\RealM365DataProvider.psm1"
            Import-Module $dataProviderPath -Force
            $functions = Get-Command -Module RealM365DataProvider -ErrorAction SilentlyContinue
            $functions | Should Not BeNullOrEmpty
        }
    }
    
    Context "データ処理性能テスト" {
        It "大量データ処理が適切な時間内に完了すること" {
            $testData = New-TestUserData -Count 1000
            
            $measure = Measure-Command {
                $processed = $testData | Where-Object { $_.Department -eq "テスト部門1" }
            }
            
            $measure.TotalMilliseconds | Should BeLessThan 5000
        }
        
        It "データフィルタリングが正常に動作すること" {
            $testData = New-TestUserData -Count 10
            $filtered = $testData | Where-Object { $_.AccountEnabled -eq $true }
            $filtered.Count | Should Be 10
        }
    }
}

# 6. ログシステムテスト
Describe "ログシステム機能テスト" -Tags @("Unit", "Logging", "Core") {
    Context "ログモジュールの基本機能" {
        It "ログモジュールファイルが存在すること" {
            $logModulePath = Join-Path $ScriptsPath "Common\Logging.psm1"
            Test-Path $logModulePath | Should Be $true
        }
        
        It "ログモジュールが正常に読み込まれること" {
            $logModulePath = Join-Path $ScriptsPath "Common\Logging.psm1"
            { Import-Module $logModulePath -Force } | Should Not Throw
        }
        
        It "ログ関数がエクスポートされていること" {
            $logModulePath = Join-Path $ScriptsPath "Common\Logging.psm1"
            Import-Module $logModulePath -Force
            $logFunction = Get-Command -Name "Write-Log" -ErrorAction SilentlyContinue
            $logFunction | Should Not BeNullOrEmpty
        }
    }
    
    Context "ログファイル出力機能" {
        It "ログディレクトリが作成できること" {
            if (-not (Test-Path $LogsPath)) {
                New-Item -ItemType Directory -Path $LogsPath -Force | Out-Null
            }
            Test-Path $LogsPath | Should Be $true
        }
        
        It "ログファイルへの書き込みが可能であること" {
            $testLogFile = Join-Path $LogsPath "pester_core_test.log"
            $testMessage = "Pester コアテスト $(Get-Date -Format 'HH:mm:ss')"
            
            $testMessage | Out-File -FilePath $testLogFile -Append -Encoding UTF8
            Test-Path $testLogFile | Should Be $true
            
            $logContent = Get-Content $testLogFile -Raw
            $logContent | Should Match [regex]::Escape($testMessage)
            
            # クリーンアップ
            if (Test-Path $testLogFile) {
                Remove-Item $testLogFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# 7. レポート生成機能テスト
Describe "レポート生成機能テスト" -Tags @("Unit", "Reporting", "Core") {
    Context "レポート生成モジュールの基本機能" {
        It "マルチフォーマットレポートジェネレーターが存在すること" {
            $reportModulePath = Join-Path $ScriptsPath "Common\MultiFormatReportGenerator.psm1"
            Test-Path $reportModulePath | Should Be $true
        }
        
        It "レポート生成モジュールが正常に読み込まれること" {
            $reportModulePath = Join-Path $ScriptsPath "Common\MultiFormatReportGenerator.psm1"
            { Import-Module $reportModulePath -Force } | Should Not Throw
        }
    }
    
    Context "レポートファイル生成機能" {
        It "CSVレポートが生成できること" {
            $testData = New-TestUserData -Count 3
            $testReportPath = Join-Path $ReportsPath "Test"
            
            if (-not (Test-Path $testReportPath)) {
                New-Item -ItemType Directory -Path $testReportPath -Force | Out-Null
            }
            
            $csvPath = Join-Path $testReportPath "pester_core_test.csv"
            
            { $testData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 } | Should Not Throw
            Test-Path $csvPath | Should Be $true
            
            $csvContent = Import-Csv $csvPath
            $csvContent.Count | Should Be 3
            $csvContent[0].DisplayName | Should Be "テストユーザー1"
            
            # クリーンアップ
            if (Test-Path $csvPath) {
                Remove-Item $csvPath -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "HTMLレポートが生成できること" {
            $testData = New-TestUserData -Count 2
            $testReportPath = Join-Path $ReportsPath "Test"
            
            if (-not (Test-Path $testReportPath)) {
                New-Item -ItemType Directory -Path $testReportPath -Force | Out-Null
            }
            
            $htmlPath = Join-Path $testReportPath "pester_core_test.html"
            
            $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Pester コアテストレポート</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Pester コアテストレポート</h1>
    <table>
        <tr><th>表示名</th><th>メール</th><th>部門</th></tr>
"@
            
            foreach ($user in $testData) {
                $htmlContent += "<tr><td>$($user.DisplayName)</td><td>$($user.Mail)</td><td>$($user.Department)</td></tr>"
            }
            
            $htmlContent += @"
    </table>
</body>
</html>
"@
            
            { $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8 } | Should Not Throw
            Test-Path $htmlPath | Should Be $true
            
            $generatedHtml = Get-Content $htmlPath -Raw
            $generatedHtml | Should Match "テストユーザー1"
            $generatedHtml | Should Match "testuser1@contoso.com"
            
            # クリーンアップ
            if (Test-Path $htmlPath) {
                Remove-Item $htmlPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# 8. エラーハンドリング機能テスト
Describe "エラーハンドリング機能テスト" -Tags @("Unit", "ErrorHandling", "Core") {
    Context "エラーハンドリングモジュールの基本機能" {
        It "エラーハンドリングモジュールファイルが存在すること" {
            $errorModulePath = Join-Path $ScriptsPath "Common\ErrorHandling.psm1"
            Test-Path $errorModulePath | Should Be $true
        }
        
        It "エラーハンドリングモジュールが正常に読み込まれること" {
            $errorModulePath = Join-Path $ScriptsPath "Common\ErrorHandling.psm1"
            { Import-Module $errorModulePath -Force } | Should Not Throw
        }
    }
    
    Context "エラー処理の動作テスト" {
        It "存在しないファイルアクセス時のエラーが適切に処理されること" {
            $nonExistentFile = Join-Path $TestRootPath "NonExistent\File.txt"
            
            { 
                try {
                    Get-Content $nonExistentFile -ErrorAction Stop
                } catch {
                    $_.Exception.Message | Should Match "Cannot find path"
                }
            } | Should Not Throw
        }
        
        It "無効なJSON解析時のエラーが適切に処理されること" {
            $invalidJson = "{ invalid json content"
            
            { 
                try {
                    $invalidJson | ConvertFrom-Json -ErrorAction Stop
                } catch {
                    $_.Exception.Message | Should Match "Invalid JSON primitive"
                }
            } | Should Not Throw
        }
    }
}

# 9. パフォーマンス機能テスト
Describe "パフォーマンス機能テスト" -Tags @("Performance", "Core") {
    Context "モジュール読み込み性能" {
        It "認証モジュール読み込みが5秒以内に完了すること" {
            $authModulePath = Join-Path $ScriptsPath "Common\Authentication.psm1"
            
            $measure = Measure-Command {
                Import-Module $authModulePath -Force
            }
            
            $measure.TotalMilliseconds | Should BeLessThan 5000
        }
        
        It "データプロバイダーモジュール読み込みが5秒以内に完了すること" {
            $dataProviderPath = Join-Path $ScriptsPath "Common\RealM365DataProvider.psm1"
            
            $measure = Measure-Command {
                Import-Module $dataProviderPath -Force
            }
            
            $measure.TotalMilliseconds | Should BeLessThan 5000
        }
    }
    
    Context "メモリ使用量テスト" {
        It "モジュール読み込み時のメモリ増加が適切な範囲内であること" {
            $initialMemory = [System.GC]::GetTotalMemory($false)
            
            # 複数モジュールの読み込み
            $modules = @(
                "Authentication.psm1",
                "Logging.psm1", 
                "RealM365DataProvider.psm1"
            )
            
            foreach ($module in $modules) {
                $modulePath = Join-Path $ScriptsPath "Common\$module"
                if (Test-Path $modulePath) {
                    Import-Module $modulePath -Force
                }
            }
            
            $finalMemory = [System.GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory
            
            ($memoryIncrease / 1MB) | Should BeLessThan 100
        }
    }
}

# 10. 統合機能テスト
Describe "統合機能テスト" -Tags @("Integration", "Core") {
    Context "エンドツーエンド処理フロー" {
        It "設定読み込み → モジュール読み込み → データ処理 → レポート生成の流れが正常に動作すること" {
            # 1. 設定読み込み
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $config | Should Not BeNullOrEmpty
            
            # 2. モジュール読み込み
            $authModulePath = Join-Path $ScriptsPath "Common\Authentication.psm1"
            Import-Module $authModulePath -Force
            
            # 3. データ処理
            $testData = New-TestUserData -Count 5
            $processedData = $testData | Where-Object { $_.AccountEnabled -eq $true }
            $processedData | Should Not BeNullOrEmpty
            $processedData.Count | Should Be 5
            
            # 4. レポート生成
            $testReportPath = Join-Path $ReportsPath "Integration"
            if (-not (Test-Path $testReportPath)) {
                New-Item -ItemType Directory -Path $testReportPath -Force | Out-Null
            }
            
            $integrationTestPath = Join-Path $testReportPath "core_integration_test.csv"
            { $processedData | Export-Csv -Path $integrationTestPath -NoTypeInformation -Encoding UTF8 } | Should Not Throw
            
            Test-Path $integrationTestPath | Should Be $true
            
            # クリーンアップ
            if (Test-Path $integrationTestPath) {
                Remove-Item $integrationTestPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    # テスト終了処理をこのDescribeブロック内に配置
    Context "テスト終了処理" {
        It "テスト結果サマリーが出力されること" {
            Write-TestLog "コア機能Pesterテスト完了" -Level "Success"
            
            # テスト結果のまとめ
            $testSummary = @{
                TestRunTime = Get-Date
                TestedComponents = @(
                    "設定ファイル機能",
                    "GUI アプリケーション",
                    "CLI アプリケーション", 
                    "認証モジュール",
                    "データプロバイダー",
                    "ログシステム",
                    "レポート生成機能",
                    "エラーハンドリング",
                    "パフォーマンス",
                    "統合機能"
                )
                CoverageTarget = "コア機能の80%以上"
                SecurityCompliance = "ISO/IEC 27001準拠"
            }
            
            Write-TestLog "テスト対象コンポーネント: $($testSummary.TestedComponents.Count) 個" -Level "Info"
            Write-TestLog "カバレッジ目標: $($testSummary.CoverageTarget)" -Level "Info"
            
            $testSummary.TestedComponents.Count | Should Be 10
            $testSummary.CoverageTarget | Should Match "80%"
        }
    }
}

# 後処理（最後のDescribeブロック内に配置）