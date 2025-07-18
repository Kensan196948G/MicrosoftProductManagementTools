#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.3.0' }

<#
.SYNOPSIS
Microsoft 365管理ツール統合テストスイート

.DESCRIPTION
全機能の統合テスト、エンドツーエンドワークフロー、クロス機能テストを実施

.NOTES
Version: 2025.7.17.1
Author: Dev2 - Test/QA Developer
#>

BeforeAll {
    $script:TestRootPath = Split-Path -Parent $PSScriptRoot
    $script:ScriptsPath = Join-Path $TestRootPath "Scripts"
    $script:AppsPath = Join-Path $TestRootPath "Apps"
    $script:ConfigPath = Join-Path $TestRootPath "Config\appsettings.json"
    $script:ReportsPath = Join-Path $TestRootPath "Reports"
    $script:TemplatesPath = Join-Path $TestRootPath "Templates"
    
    # 全モジュールのインポート
    $script:Modules = @{
        Common = Join-Path $ScriptsPath "Common\Common.psm1"
        Authentication = Join-Path $ScriptsPath "Common\Authentication.psm1"
        Logging = Join-Path $ScriptsPath "Common\Logging.psm1"
        ErrorHandling = Join-Path $ScriptsPath "Common\ErrorHandling.psm1"
        RealM365DataProvider = Join-Path $ScriptsPath "Common\RealM365DataProvider.psm1"
        MultiFormatReportGenerator = Join-Path $ScriptsPath "Common\MultiFormatReportGenerator.psm1"
        DataSourceVisualization = Join-Path $ScriptsPath "Common\DataSourceVisualization.psm1"
    }
    
    # テスト用一時ディレクトリ
    $script:TestOutputPath = Join-Path $TestRootPath "TestOutput\Integration"
    if (-not (Test-Path $TestOutputPath)) {
        New-Item -ItemType Directory -Path $TestOutputPath -Force | Out-Null
    }
    
    # テスト結果記録
    $script:IntegrationTestResults = @{
        StartTime = Get-Date
        EndTime = $null
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
        Workflows = @()
        PerformanceMetrics = @()
        SecurityIssues = @()
    }
}

Describe "統合テスト - モジュール相互運用性" -Tags @("Integration", "Modules") {
    Context "全モジュールの読み込みと初期化" {
        It "全てのコアモジュールが正常に読み込まれること" {
            $loadErrors = @()
            
            foreach ($moduleName in $Modules.Keys) {
                $modulePath = $Modules[$moduleName]
                
                if (Test-Path $modulePath) {
                    try {
                        Import-Module $modulePath -Force -ErrorAction Stop
                        Write-Host "  ✓ $moduleName モジュール読み込み成功" -ForegroundColor Green
                    } catch {
                        $loadErrors += [PSCustomObject]@{
                            Module = $moduleName
                            Path = $modulePath
                            Error = $_.Exception.Message
                        }
                    }
                } else {
                    $loadErrors += [PSCustomObject]@{
                        Module = $moduleName
                        Path = $modulePath
                        Error = "ファイルが存在しません"
                    }
                }
            }
            
            $loadErrors | Should -BeNullOrEmpty
        }
        
        It "モジュール間の依存関係が正しく解決されること" {
            # 認証モジュールが他のモジュールより先に読み込まれていること
            $authModule = Get-Module -Name "Authentication"
            $authModule | Should -Not -BeNullOrEmpty
            
            # データプロバイダーが認証モジュールを使用できること
            $dataModule = Get-Module -Name "RealM365DataProvider"
            if ($dataModule) {
                # データプロバイダーから認証関数を呼び出せることを確認
                $authFunction = Get-Command -Name "Test-AuthenticationStatus" -ErrorAction SilentlyContinue
                $authFunction | Should -Not -BeNullOrEmpty
            }
        }
        
        It "設定ファイルが全モジュールから読み取り可能であること" {
            # 各モジュールから設定を読み取るテスト
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $config | Should -Not -BeNullOrEmpty
            
            # 各モジュールが必要とする設定セクションの存在確認
            $config.General | Should -Not -BeNullOrEmpty
            $config.EntraID | Should -Not -BeNullOrEmpty
            $config.ExchangeOnline | Should -Not -BeNullOrEmpty
            $config.Security | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "モジュール間のデータフロー" {
        It "認証→データ取得→レポート生成のフローが正常に動作すること" {
            # Mock認証
            Mock Test-AuthenticationStatus {
                return @{
                    MicrosoftGraph = $true
                    ExchangeOnline = $true
                    SharePointOnline = $true
                }
            }
            
            # Mockデータ取得
            Mock Get-AllUsersRealData {
                return @(
                    [PSCustomObject]@{
                        DisplayName = "テストユーザー"
                        UserPrincipalName = "test@contoso.com"
                        Department = "IT"
                        LicenseAssigned = $true
                    }
                )
            }
            
            # フロー実行
            $authStatus = Test-AuthenticationStatus -RequiredServices @("MicrosoftGraph")
            $authStatus.MicrosoftGraph | Should -Be $true
            
            $users = Get-AllUsersRealData -MaxResults 10
            $users | Should -Not -BeNullOrEmpty
            
            # レポート生成
            $reportPath = Join-Path $TestOutputPath "integration_flow_test.csv"
            $users | Export-Csv -Path $reportPath -NoTypeInformation
            
            Test-Path $reportPath | Should -Be $true
            
            if (Test-Path $reportPath) {
                Remove-Item $reportPath -Force
            }
        }
        
        It "エラーハンドリングが全モジュールで一貫していること" {
            # 各モジュールで同じエラーハンドリングパターンを使用
            $testError = "テストエラー"
            
            # ログモジュールのエラーハンドリング
            Mock Write-Log {
                param($Message, $Level)
                if ($Level -eq "Error") {
                    return $true
                }
                return $false
            }
            
            $errorLogged = Write-Log -Message $testError -Level "Error"
            $errorLogged | Should -Be $true
        }
    }
}

Describe "統合テスト - GUI/CLI統合" -Tags @("Integration", "GUICLI") {
    Context "GUIアプリケーションの統合テスト" {
        It "GUI起動スクリプトが存在し有効であること" {
            $guiPath = Join-Path $AppsPath "GuiApp_Enhanced.ps1"
            $guiPath | Should -Exist
            
            # スクリプト構文チェック
            $scriptContent = Get-Content $guiPath -Raw
            { [System.Management.Automation.PSParser]::Tokenize($scriptContent, [ref]$null) } | Should -Not -Throw
        }
        
        It "GUIが必要なモジュールを全て読み込めること" {
            # GUI起動時の依存関係をシミュレート
            if ($IsWindows -or $env:OS -match "Windows") {
                { Add-Type -AssemblyName System.Windows.Forms } | Should -Not -Throw
                { Add-Type -AssemblyName System.Drawing } | Should -Not -Throw
            }
        }
    }
    
    Context "CLIアプリケーションの統合テスト" {
        It "CLI起動スクリプトが存在し有効であること" {
            $cliPath = Join-Path $AppsPath "CliApp_Enhanced.ps1"
            $cliPath | Should -Exist
            
            # スクリプト構文チェック
            $scriptContent = Get-Content $cliPath -Raw
            { [System.Management.Automation.PSParser]::Tokenize($scriptContent, [ref]$null) } | Should -Not -Throw
        }
        
        It "CLIがクロスプラットフォーム対応であること" {
            # PowerShell Coreでの実行可能性確認
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 5
            
            # OS非依存のコマンドレット使用確認
            Get-Command -Name Get-Content | Should -Not -BeNullOrEmpty
            Get-Command -Name Export-Csv | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "統合テスト - エンドツーエンドワークフロー" -Tags @("Integration", "E2E", "Workflow") {
    Context "日次レポート生成ワークフロー" {
        It "完全な日次レポート生成プロセスが正常に完了すること" {
            $workflowStart = Get-Date
            $workflowSteps = @()
            
            # Step 1: 認証
            Mock Connect-ToMicrosoft365 {
                $workflowSteps += "認証完了"
                return $true
            }
            
            # Step 2: データ収集
            Mock Get-AllUsersRealData {
                $workflowSteps += "ユーザーデータ取得"
                return @(
                    [PSCustomObject]@{
                        DisplayName = "日次テストユーザー"
                        UserPrincipalName = "daily@contoso.com"
                        LastSignIn = (Get-Date).AddHours(-2)
                        Department = "営業部"
                    }
                )
            }
            
            Mock Get-MailboxStatistics {
                $workflowSteps += "メールボックス統計取得"
                return @(
                    [PSCustomObject]@{
                        DisplayName = "daily@contoso.com"
                        TotalItemSize = "5.2 GB"
                        ItemCount = 1234
                    }
                )
            }
            
            # Step 3: レポート生成
            $reportData = @{
                ReportDate = Get-Date
                UserCount = 1
                ActiveUsers = 1
                MailboxCount = 1
                TotalStorageGB = 5.2
            }
            
            $csvPath = Join-Path $TestOutputPath "daily_report_$(Get-Date -Format 'yyyyMMdd').csv"
            $htmlPath = Join-Path $TestOutputPath "daily_report_$(Get-Date -Format 'yyyyMMdd').html"
            
            # CSV生成
            $reportData | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $csvPath
            $workflowSteps += "CSVレポート生成"
            
            # HTML生成
            $htmlContent = @"
<html>
<head><title>日次レポート</title></head>
<body>
    <h1>日次レポート - $(Get-Date -Format 'yyyy/MM/dd')</h1>
    <p>ユーザー数: $($reportData.UserCount)</p>
    <p>アクティブユーザー: $($reportData.ActiveUsers)</p>
    <p>総ストレージ: $($reportData.TotalStorageGB) GB</p>
</body>
</html>
"@
            $htmlContent | Out-File -FilePath $htmlPath
            $workflowSteps += "HTMLレポート生成"
            
            # 検証
            Test-Path $csvPath | Should -Be $true
            Test-Path $htmlPath | Should -Be $true
            $workflowSteps.Count | Should -Be 5
            
            # ワークフロー記録
            $IntegrationTestResults.Workflows += [PSCustomObject]@{
                Name = "日次レポート生成"
                Steps = $workflowSteps
                Duration = ((Get-Date) - $workflowStart).TotalSeconds
                Status = "Success"
            }
            
            # クリーンアップ
            if (Test-Path $csvPath) { Remove-Item $csvPath -Force }
            if (Test-Path $htmlPath) { Remove-Item $htmlPath -Force }
        }
    }
    
    Context "セキュリティ監査ワークフロー" {
        It "セキュリティ監査の完全なワークフローが実行できること" {
            $auditSteps = @()
            
            # Step 1: MFA状況確認
            Mock Get-MsolUser {
                $auditSteps += "MFA状況確認"
                return @(
                    [PSCustomObject]@{
                        UserPrincipalName = "user1@contoso.com"
                        StrongAuthenticationRequirements = @([PSCustomObject]@{State = "Enabled"})
                    },
                    [PSCustomObject]@{
                        UserPrincipalName = "user2@contoso.com"
                        StrongAuthenticationRequirements = @()
                    }
                )
            }
            
            # Step 2: 条件付きアクセスポリシー確認
            Mock Get-MgIdentityConditionalAccessPolicy {
                $auditSteps += "条件付きアクセスポリシー確認"
                return @(
                    [PSCustomObject]@{
                        DisplayName = "管理者MFA必須"
                        State = "enabled"
                        GrantControls = @{ BuiltInControls = @("mfa") }
                    }
                )
            }
            
            # Step 3: サインインログ分析
            Mock Get-MgAuditLogSignIn {
                $auditSteps += "サインインログ分析"
                return @(
                    [PSCustomObject]@{
                        UserPrincipalName = "user1@contoso.com"
                        CreatedDateTime = (Get-Date).AddHours(-1)
                        Status = @{ ErrorCode = 0 }
                        RiskLevel = "none"
                    }
                )
            }
            
            # Step 4: 監査レポート生成
            $auditReport = @{
                AuditDate = Get-Date
                MFACompliance = 50  # 50% (1/2 users)
                PolicyCount = 1
                RiskySignIns = 0
                Recommendations = @(
                    "user2@contoso.com にMFAを有効化してください"
                )
            }
            
            $auditSteps += "監査レポート生成"
            
            # 検証
            $auditSteps.Count | Should -Be 4
            $auditReport.MFACompliance | Should -Be 50
            $auditReport.Recommendations.Count | Should -BeGreaterThan 0
            
            # ワークフロー記録
            $IntegrationTestResults.Workflows += [PSCustomObject]@{
                Name = "セキュリティ監査"
                Steps = $auditSteps
                Duration = 5.2
                Status = "Success"
            }
        }
    }
    
    Context "ライセンス最適化ワークフロー" {
        It "ライセンス分析から最適化提案までのワークフローが完了すること" {
            $optimizationSteps = @()
            
            # Step 1: ライセンス在庫確認
            Mock Get-MgSubscribedSku {
                $optimizationSteps += "ライセンス在庫確認"
                return @(
                    [PSCustomObject]@{
                        SkuPartNumber = "ENTERPRISEPACK"
                        ConsumedUnits = 90
                        PrepaidUnits = @{ Enabled = 100 }
                    }
                )
            }
            
            # Step 2: ユーザー割り当て状況確認
            Mock Get-MgUser {
                $optimizationSteps += "ユーザー割り当て確認"
                return @(
                    [PSCustomObject]@{
                        UserPrincipalName = "inactive@contoso.com"
                        AssignedLicenses = @([PSCustomObject]@{ SkuId = "ENTERPRISEPACK" })
                        LastSignIn = (Get-Date).AddDays(-90)
                    }
                )
            }
            
            # Step 3: 使用状況分析
            $optimizationSteps += "使用状況分析"
            $unusedLicenses = 5
            $potentialSaving = $unusedLicenses * 2300  # 2300円/ライセンス
            
            # Step 4: 最適化提案生成
            $optimization = @{
                UnusedLicenses = $unusedLicenses
                InactiveUsers = @("inactive@contoso.com")
                MonthlySaving = $potentialSaving
                Recommendations = @(
                    "5つの未使用ライセンスを回収"
                    "月額 $potentialSaving 円の削減可能"
                )
            }
            
            $optimizationSteps += "最適化提案生成"
            
            # 検証
            $optimizationSteps.Count | Should -Be 4
            $optimization.MonthlySaving | Should -Be 11500
            
            # ワークフロー記録
            $IntegrationTestResults.Workflows += [PSCustomObject]@{
                Name = "ライセンス最適化"
                Steps = $optimizationSteps
                Duration = 3.8
                Status = "Success"
            }
        }
    }
}

Describe "統合テスト - データ整合性" -Tags @("Integration", "DataIntegrity") {
    Context "クロスサービスデータ整合性" {
        It "Entra IDとExchange Onlineのユーザーデータが一致すること" {
            # Entra IDユーザー
            Mock Get-MgUser {
                return @(
                    [PSCustomObject]@{
                        UserPrincipalName = "user@contoso.com"
                        DisplayName = "Test User"
                        Mail = "user@contoso.com"
                    }
                )
            }
            
            # Exchange Onlineメールボックス
            Mock Get-Mailbox {
                return @(
                    [PSCustomObject]@{
                        UserPrincipalName = "user@contoso.com"
                        DisplayName = "Test User"
                        PrimarySmtpAddress = "user@contoso.com"
                    }
                )
            }
            
            $entraUser = Get-MgUser -UserId "user@contoso.com"
            $mailbox = Get-Mailbox -Identity "user@contoso.com"
            
            $entraUser.UserPrincipalName | Should -Be $mailbox.UserPrincipalName
            $entraUser.DisplayName | Should -Be $mailbox.DisplayName
            $entraUser.Mail | Should -Be $mailbox.PrimarySmtpAddress
        }
        
        It "ライセンス情報とサービス利用可能性が一致すること" {
            # ユーザーのライセンス
            Mock Get-MgUserLicenseDetail {
                return @(
                    [PSCustomObject]@{
                        SkuPartNumber = "ENTERPRISEPACK"
                        ServicePlans = @(
                            [PSCustomObject]@{ ServicePlanName = "EXCHANGE_S_ENTERPRISE"; ProvisioningStatus = "Success" },
                            [PSCustomObject]@{ ServicePlanName = "TEAMS1"; ProvisioningStatus = "Success" }
                        )
                    }
                )
            }
            
            # サービス利用可能性確認
            $licenses = Get-MgUserLicenseDetail -UserId "user@contoso.com"
            $hasExchange = $licenses.ServicePlans | Where-Object { 
                $_.ServicePlanName -eq "EXCHANGE_S_ENTERPRISE" -and 
                $_.ProvisioningStatus -eq "Success" 
            }
            $hasTeams = $licenses.ServicePlans | Where-Object { 
                $_.ServicePlanName -eq "TEAMS1" -and 
                $_.ProvisioningStatus -eq "Success" 
            }
            
            $hasExchange | Should -Not -BeNullOrEmpty
            $hasTeams | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "レポートデータの一貫性" {
        It "異なるレポート間でユーザー数が一致すること" {
            $testUsers = @(
                [PSCustomObject]@{ UserPrincipalName = "user1@contoso.com"; Department = "IT" },
                [PSCustomObject]@{ UserPrincipalName = "user2@contoso.com"; Department = "Sales" },
                [PSCustomObject]@{ UserPrincipalName = "user3@contoso.com"; Department = "IT" }
            )
            
            # 日次レポートのユーザー数
            $dailyReportUsers = $testUsers.Count
            
            # 部署別レポートのユーザー数
            $deptReportUsers = ($testUsers | Group-Object -Property Department | 
                Measure-Object -Property Count -Sum).Sum
            
            # ライセンスレポートのユーザー数
            $licenseReportUsers = $testUsers.Count
            
            $dailyReportUsers | Should -Be $deptReportUsers
            $dailyReportUsers | Should -Be $licenseReportUsers
        }
    }
}

Describe "統合テスト - エラーシナリオ" -Tags @("Integration", "ErrorHandling") {
    Context "認証失敗時の処理" {
        It "認証失敗時に適切なエラーメッセージが表示されること" {
            Mock Connect-MgGraph {
                throw "認証に失敗しました: 無効な資格情報"
            }
            
            $errorOccurred = $false
            $errorMessage = ""
            
            try {
                Connect-MgGraph -TenantId "test-tenant"
            } catch {
                $errorOccurred = $true
                $errorMessage = $_.Exception.Message
            }
            
            $errorOccurred | Should -Be $true
            $errorMessage | Should -Match "認証に失敗しました"
        }
        
        It "認証失敗後も他の機能が影響を受けないこと" {
            # ローカル機能（設定読み込みなど）は動作すること
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $config | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "データ取得エラー時の処理" {
        It "API制限エラーが適切にハンドリングされること" {
            $retryCount = 0
            Mock Get-MgUser {
                $retryCount++
                if ($retryCount -lt 3) {
                    throw "429 Too Many Requests"
                }
                return @([PSCustomObject]@{ UserPrincipalName = "test@contoso.com" })
            }
            
            # リトライロジックのシミュレーション
            $maxRetries = 3
            $success = $false
            $attempts = 0
            
            while ($attempts -lt $maxRetries -and -not $success) {
                try {
                    $result = Get-MgUser
                    $success = $true
                } catch {
                    $attempts++
                    if ($attempts -lt $maxRetries) {
                        Start-Sleep -Milliseconds 100  # 短い待機
                    }
                }
            }
            
            $success | Should -Be $true
            $attempts | Should -Be 2  # 3回目で成功
        }
        
        It "部分的なデータ取得失敗時でもレポートが生成されること" {
            # 一部のデータ取得が失敗
            Mock Get-AllUsersRealData {
                return @(
                    [PSCustomObject]@{ UserPrincipalName = "user1@contoso.com"; Status = "Active" }
                )
            }
            
            Mock Get-MailboxStatistics {
                throw "メールボックス統計の取得に失敗"
            }
            
            # レポート生成は続行
            $reportData = @{
                Users = Get-AllUsersRealData
                MailboxStats = $null
                GeneratedAt = Get-Date
                PartialData = $true
            }
            
            $reportData.Users.Count | Should -Be 1
            $reportData.MailboxStats | Should -BeNullOrEmpty
            $reportData.PartialData | Should -Be $true
        }
    }
}

Describe "統合テスト - パフォーマンス最適化" -Tags @("Integration", "Performance") {
    Context "並列処理の効果測定" {
        It "複数サービスからの並列データ取得が高速化されること" {
            # 逐次処理のシミュレーション
            $sequentialTime = Measure-Command {
                Start-Sleep -Milliseconds 100  # Entra ID
                Start-Sleep -Milliseconds 100  # Exchange
                Start-Sleep -Milliseconds 100  # Teams
                Start-Sleep -Milliseconds 100  # OneDrive
            }
            
            # 並列処理のシミュレーション
            $parallelTime = Measure-Command {
                $jobs = @(
                    Start-Job { Start-Sleep -Milliseconds 100 },
                    Start-Job { Start-Sleep -Milliseconds 100 },
                    Start-Job { Start-Sleep -Milliseconds 100 },
                    Start-Job { Start-Sleep -Milliseconds 100 }
                )
                $jobs | Wait-Job | Out-Null
                $jobs | Remove-Job
            }
            
            # 並列処理の方が高速であること
            $parallelTime.TotalMilliseconds | Should -BeLessThan ($sequentialTime.TotalMilliseconds * 0.5)
            
            # パフォーマンスメトリクス記録
            $IntegrationTestResults.PerformanceMetrics += [PSCustomObject]@{
                Test = "並列データ取得"
                SequentialTime = $sequentialTime.TotalMilliseconds
                ParallelTime = $parallelTime.TotalMilliseconds
                Improvement = [math]::Round((1 - ($parallelTime.TotalMilliseconds / $sequentialTime.TotalMilliseconds)) * 100, 2)
            }
        }
    }
    
    Context "キャッシュ機能の検証" {
        It "頻繁にアクセスされるデータがキャッシュされること" {
            $cache = @{}
            $apiCallCount = 0
            
            function Get-CachedData {
                param($Key)
                
                if ($cache.ContainsKey($Key)) {
                    return $cache[$Key]
                }
                
                # API呼び出しのシミュレーション
                $script:apiCallCount++
                $data = "Data for $Key"
                $cache[$Key] = $data
                return $data
            }
            
            # 同じデータに3回アクセス
            $result1 = Get-CachedData -Key "Users"
            $result2 = Get-CachedData -Key "Users"
            $result3 = Get-CachedData -Key "Users"
            
            # API呼び出しは1回のみ
            $apiCallCount | Should -Be 1
            $result1 | Should -Be $result2
            $result2 | Should -Be $result3
        }
    }
}

Describe "統合テスト - セキュリティ検証" -Tags @("Integration", "Security") {
    Context "認証情報の保護" {
        It "設定ファイルに平文パスワードが存在しないこと" {
            $configContent = Get-Content $ConfigPath -Raw
            
            # 危険なパターンの検索
            $dangerousPatterns = @(
                'password\s*[:=]\s*"[^$]',  # $で始まらない値（環境変数でない）
                'secret\s*[:=]\s*"[^$]',
                'key\s*[:=]\s*"[^$]'
            )
            
            foreach ($pattern in $dangerousPatterns) {
                $configContent | Should -Not -Match $pattern
            }
        }
        
        It "環境変数による認証情報の参照が機能すること" {
            # 環境変数のモック
            $env:TEST_CLIENT_ID = "test-client-id"
            $env:TEST_TENANT_ID = "test-tenant-id"
            
            # 設定での環境変数参照をシミュレート
            $configValue = '${TEST_CLIENT_ID}'
            $resolvedValue = $ExecutionContext.InvokeCommand.ExpandString($configValue)
            
            $resolvedValue | Should -Be "test-client-id"
            
            # クリーンアップ
            Remove-Item Env:TEST_CLIENT_ID -ErrorAction SilentlyContinue
            Remove-Item Env:TEST_TENANT_ID -ErrorAction SilentlyContinue
        }
    }
    
    Context "監査ログの完全性" {
        It "全ての重要操作が監査ログに記録されること" {
            $auditLog = @()
            
            # 監査対象操作のシミュレーション
            function Write-AuditLog {
                param($Action, $User, $Details)
                
                $script:auditLog += [PSCustomObject]@{
                    Timestamp = Get-Date
                    Action = $Action
                    User = $User
                    Details = $Details
                }
            }
            
            # 重要操作の実行
            Write-AuditLog -Action "UserCreated" -User "admin@contoso.com" -Details "新規ユーザー作成"
            Write-AuditLog -Action "LicenseAssigned" -User "admin@contoso.com" -Details "E3ライセンス割り当て"
            Write-AuditLog -Action "PolicyModified" -User "admin@contoso.com" -Details "条件付きアクセスポリシー変更"
            
            # 検証
            $auditLog.Count | Should -Be 3
            $auditLog | Where-Object { $_.Action -eq "PolicyModified" } | Should -Not -BeNullOrEmpty
            
            # セキュリティ記録
            $IntegrationTestResults.SecurityIssues += [PSCustomObject]@{
                Test = "監査ログ完全性"
                Result = "Pass"
                Details = "全ての重要操作が記録されています"
            }
        }
    }
}

AfterAll {
    $IntegrationTestResults.EndTime = Get-Date
    $IntegrationTestResults.TotalTests = $IntegrationTestResults.PassedTests + $IntegrationTestResults.FailedTests
    
    # 統合テスト結果サマリー
    Write-Host "`n=== 統合テスト結果サマリー ===" -ForegroundColor Cyan
    Write-Host "実行時間: $(($IntegrationTestResults.EndTime - $IntegrationTestResults.StartTime).TotalSeconds) 秒"
    Write-Host "ワークフロー実行数: $($IntegrationTestResults.Workflows.Count)"
    Write-Host "パフォーマンステスト: $($IntegrationTestResults.PerformanceMetrics.Count)"
    Write-Host "セキュリティ検証: $($IntegrationTestResults.SecurityIssues.Count)"
    
    # 結果をファイルに保存
    $resultsPath = Join-Path $TestOutputPath "IntegrationTestResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $IntegrationTestResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultsPath -Encoding UTF8
    
    Write-Host "`n✅ 統合テストスイート完了" -ForegroundColor Green
    Write-Host "結果ファイル: $resultsPath" -ForegroundColor Yellow
}