#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.3.0' }

<#
.SYNOPSIS
Microsoft 365管理ツールセキュリティ脆弱性スキャンテストスイート

.DESCRIPTION
OWASP Top 10、CWE/SANS Top 25、ISO/IEC 27001に基づく包括的なセキュリティテスト

.NOTES
Version: 2025.7.17.1
Author: Dev2 - Test/QA Developer
Security: 防御的セキュリティテスト専用（攻撃的テストは含まない）
#>

BeforeAll {
    $script:TestRootPath = Split-Path -Parent $PSScriptRoot
    $script:ScriptsPath = Join-Path $TestRootPath "Scripts"
    $script:ConfigPath = Join-Path $TestRootPath "Config\appsettings.json"
    $script:CertificatesPath = Join-Path $TestRootPath "Certificates"
    $script:LogsPath = Join-Path $TestRootPath "Logs"
    
    # セキュリティテスト結果格納
    $script:SecurityTestResults = @{
        StartTime = Get-Date
        EndTime = $null
        Vulnerabilities = @()
        ComplianceChecks = @()
        SecurityScore = 100  # 100点から減点方式
        CriticalIssues = 0
        HighIssues = 0
        MediumIssues = 0
        LowIssues = 0
    }
    
    # セキュリティ評価関数
    function Add-SecurityIssue {
        param(
            [string]$Category,
            [string]$Issue,
            [ValidateSet("Critical", "High", "Medium", "Low")]
            [string]$Severity,
            [string]$Description,
            [string]$Recommendation,
            [string]$CWE = "N/A",
            [string]$OWASP = "N/A"
        )
        
        $script:SecurityTestResults.Vulnerabilities += [PSCustomObject]@{
            Category = $Category
            Issue = $Issue
            Severity = $Severity
            Description = $Description
            Recommendation = $Recommendation
            CWE = $CWE
            OWASP = $OWASP
            DetectedAt = Get-Date
        }
        
        # スコア減点
        switch ($Severity) {
            "Critical" { 
                $script:SecurityTestResults.SecurityScore -= 25
                $script:SecurityTestResults.CriticalIssues++
            }
            "High" { 
                $script:SecurityTestResults.SecurityScore -= 15
                $script:SecurityTestResults.HighIssues++
            }
            "Medium" { 
                $script:SecurityTestResults.SecurityScore -= 10
                $script:SecurityTestResults.MediumIssues++
            }
            "Low" { 
                $script:SecurityTestResults.SecurityScore -= 5
                $script:SecurityTestResults.LowIssues++
            }
        }
        
        # スコアが0未満にならないように
        if ($script:SecurityTestResults.SecurityScore -lt 0) {
            $script:SecurityTestResults.SecurityScore = 0
        }
    }
}

Describe "セキュリティ - 認証と認可" -Tags @("Security", "Authentication", "OWASP-A07") {
    Context "認証メカニズムの検証" {
        It "多要素認証（MFA）が強制可能であること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            
            if (-not $config.Security.RequireMFAForAdmins) {
                Add-SecurityIssue -Category "認証" `
                    -Issue "管理者MFAが無効" `
                    -Severity "Critical" `
                    -Description "管理者アカウントでMFAが強制されていません" `
                    -Recommendation "Security.RequireMFAForAdmins を true に設定してください" `
                    -OWASP "A07:2021 - Identification and Authentication Failures"
            }
            
            $config.Security.RequireMFAForAdmins | Should -Be $true
        }
        
        It "証明書ベース認証が適切に設定されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            
            # 証明書パスの検証
            if ($config.EntraID.CertificatePath -and $config.EntraID.CertificatePath -ne '${ENTRA_CERTIFICATE_PATH}') {
                if (-not (Test-Path $config.EntraID.CertificatePath)) {
                    Add-SecurityIssue -Category "認証" `
                        -Issue "証明書ファイルが見つからない" `
                        -Severity "High" `
                        -Description "設定された証明書パスにファイルが存在しません" `
                        -Recommendation "有効な証明書パスを設定してください" `
                        -CWE "CWE-295"
                }
            }
            
            # 証明書の有効期限チェック（存在する場合）
            $certFiles = Get-ChildItem -Path $CertificatesPath -Filter "*.pfx" -ErrorAction SilentlyContinue
            foreach ($certFile in $certFiles) {
                # 証明書の検証（実際の読み込みは行わない）
                if ($certFile.LastWriteTime -lt (Get-Date).AddYears(-1)) {
                    Add-SecurityIssue -Category "認証" `
                        -Issue "古い証明書ファイル" `
                        -Severity "Medium" `
                        -Description "1年以上前の証明書ファイルが使用されています: $($certFile.Name)" `
                        -Recommendation "証明書を更新してください" `
                        -CWE "CWE-324"
                }
            }
        }
        
        It "認証トークンの適切な管理が行われていること" {
            # スクリプト内でのトークン管理パターンを検索
            $scriptFiles = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" -Recurse
            $tokenPatterns = @(
                '\$.*token.*=.*"[A-Za-z0-9+/]{20,}"',  # ハードコードされたトークン
                'ConvertTo-SecureString.*-AsPlainText',  # 平文パスワード
                'password\s*=\s*"[^$]'  # ハードコードされたパスワード
            )
            
            foreach ($file in $scriptFiles) {
                $content = Get-Content $file.FullName -Raw
                foreach ($pattern in $tokenPatterns) {
                    if ($content -match $pattern) {
                        Add-SecurityIssue -Category "認証" `
                            -Issue "潜在的な認証情報の露出" `
                            -Severity "High" `
                            -Description "ファイル $($file.Name) に認証情報がハードコードされている可能性があります" `
                            -Recommendation "認証情報は環境変数または安全な資格情報ストアを使用してください" `
                            -CWE "CWE-798"
                        break
                    }
                }
            }
        }
    }
    
    Context "アクセス制御の検証" {
        It "最小権限の原則が適用されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            
            # Graph API権限のチェック
            if ($config.EntraID.GraphScopes) {
                $dangerousScopes = @("Directory.ReadWrite.All", "User.ReadWrite.All", "Group.ReadWrite.All")
                $configuredScopes = $config.EntraID.GraphScopes -split ","
                
                foreach ($scope in $configuredScopes) {
                    if ($scope.Trim() -in $dangerousScopes) {
                        Add-SecurityIssue -Category "認可" `
                            -Issue "過剰な権限スコープ" `
                            -Severity "Medium" `
                            -Description "Graph APIで過剰な権限 '$scope' が要求されています" `
                            -Recommendation "必要最小限の権限スコープに変更してください" `
                            -CWE "CWE-250"
                    }
                }
            }
        }
        
        It "ロールベースアクセス制御（RBAC）が実装されていること" {
            # RBACの実装確認
            $hasRoleCheck = $false
            $authScripts = Get-ChildItem -Path $ScriptsPath -Filter "*auth*.ps1" -Recurse
            
            foreach ($script in $authScripts) {
                $content = Get-Content $script.FullName -Raw
                if ($content -match "role|permission|authorize") {
                    $hasRoleCheck = $true
                    break
                }
            }
            
            if (-not $hasRoleCheck) {
                Add-SecurityIssue -Category "認可" `
                    -Issue "RBACの実装不足" `
                    -Severity "Medium" `
                    -Description "ロールベースのアクセス制御が実装されていない可能性があります" `
                    -Recommendation "適切なRBAC実装を追加してください" `
                    -OWASP "A01:2021 - Broken Access Control"
            }
        }
    }
}

Describe "セキュリティ - データ保護" -Tags @("Security", "DataProtection", "OWASP-A02") {
    Context "機密データの暗号化" {
        It "保存データが暗号化されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            
            if (-not $config.Security.EncryptSensitiveData) {
                Add-SecurityIssue -Category "データ保護" `
                    -Issue "データ暗号化が無効" `
                    -Severity "High" `
                    -Description "機密データの暗号化が無効になっています" `
                    -Recommendation "Security.EncryptSensitiveData を true に設定してください" `
                    -OWASP "A02:2021 - Cryptographic Failures"
            }
            
            $config.Security.EncryptSensitiveData | Should -Be $true
        }
        
        It "通信が暗号化されていること" {
            # API通信の確認
            $scriptFiles = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" -Recurse
            $httpPattern = 'http://(?!localhost|127\.0\.0\.1)'
            
            foreach ($file in $scriptFiles) {
                $content = Get-Content $file.FullName -Raw
                if ($content -match $httpPattern) {
                    Add-SecurityIssue -Category "データ保護" `
                        -Issue "非暗号化通信" `
                        -Severity "High" `
                        -Description "ファイル $($file.Name) で非HTTPS通信が使用されています" `
                        -Recommendation "すべての外部通信にHTTPSを使用してください" `
                        -CWE "CWE-319"
                }
            }
        }
        
        It "証明書の保護が適切であること" {
            if (Test-Path $CertificatesPath) {
                $acl = Get-Acl $CertificatesPath
                $everyoneAccess = $acl.Access | Where-Object { 
                    $_.IdentityReference -match "Everyone|Users" -and 
                    $_.FileSystemRights -match "FullControl|Write|Modify"
                }
                
                if ($everyoneAccess) {
                    Add-SecurityIssue -Category "データ保護" `
                        -Issue "証明書ディレクトリの権限が緩い" `
                        -Severity "Critical" `
                        -Description "証明書ディレクトリに過剰なアクセス権限が設定されています" `
                        -Recommendation "証明書ディレクトリのアクセス権限を管理者のみに制限してください" `
                        -CWE "CWE-732"
                }
            }
        }
    }
    
    Context "データ漏洩防止" {
        It "ログファイルに機密情報が含まれていないこと" {
            if (Test-Path $LogsPath) {
                $logFiles = Get-ChildItem -Path $LogsPath -Filter "*.log" -ErrorAction SilentlyContinue | 
                    Select-Object -First 5  # 最新5ファイルのみチェック
                
                $sensitivePatterns = @(
                    'password\s*[:=]',
                    'token\s*[:=]',
                    'secret\s*[:=]',
                    'key\s*[:=]',
                    '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'  # メールアドレス
                )
                
                foreach ($logFile in $logFiles) {
                    $content = Get-Content $logFile.FullName -Raw -ErrorAction SilentlyContinue
                    foreach ($pattern in $sensitivePatterns) {
                        if ($content -match $pattern) {
                            Add-SecurityIssue -Category "データ保護" `
                                -Issue "ログファイルの機密情報" `
                                -Severity "High" `
                                -Description "ログファイル $($logFile.Name) に機密情報が含まれている可能性があります" `
                                -Recommendation "ログ出力時に機密情報をマスクまたは除外してください" `
                                -CWE "CWE-532"
                            break
                        }
                    }
                }
            }
        }
        
        It "エラーメッセージが詳細すぎないこと" {
            $errorHandlingFiles = Get-ChildItem -Path $ScriptsPath -Filter "*error*.ps1" -Recurse
            
            foreach ($file in $errorHandlingFiles) {
                $content = Get-Content $file.FullName -Raw
                
                # スタックトレースの露出チェック
                if ($content -match '\$Error\[0\]\.Exception\.StackTrace' -or 
                    $content -match '\$_.Exception.StackTrace') {
                    Add-SecurityIssue -Category "データ保護" `
                        -Issue "スタックトレースの露出" `
                        -Severity "Medium" `
                        -Description "エラー処理でスタックトレースが露出する可能性があります: $($file.Name)" `
                        -Recommendation "本番環境ではスタックトレースを非表示にしてください" `
                        -CWE "CWE-209"
                }
            }
        }
    }
}

Describe "セキュリティ - 入力検証とサニタイゼーション" -Tags @("Security", "InputValidation", "OWASP-A03") {
    Context "コマンドインジェクション対策" {
        It "動的コマンド実行が安全に実装されていること" {
            $scriptFiles = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" -Recurse
            $dangerousPatterns = @(
                'Invoke-Expression',
                'iex\s',
                '&\s*\$',  # & $variable
                'Start-Process.*-ArgumentList.*\$',
                'cmd\s*/c'
            )
            
            foreach ($file in $scriptFiles) {
                $content = Get-Content $file.FullName -Raw
                foreach ($pattern in $dangerousPatterns) {
                    if ($content -match $pattern) {
                        # コンテキストを確認（一部の使用は正当な場合がある）
                        $lines = $content -split "`n"
                        $lineNumber = 1
                        foreach ($line in $lines) {
                            if ($line -match $pattern -and $line -notmatch '#\s*Safe:') {
                                Add-SecurityIssue -Category "入力検証" `
                                    -Issue "潜在的なコマンドインジェクション" `
                                    -Severity "High" `
                                    -Description "ファイル $($file.Name) の行 $lineNumber で危険なコマンド実行パターンが検出されました" `
                                    -Recommendation "ユーザー入力を使用する場合は適切なサニタイゼーションを実装してください" `
                                    -CWE "CWE-78" `
                                    -OWASP "A03:2021 - Injection"
                                break
                            }
                            $lineNumber++
                        }
                    }
                }
            }
        }
        
        It "パスインジェクション対策が実装されていること" {
            $scriptFiles = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" -Recurse
            
            foreach ($file in $scriptFiles) {
                $content = Get-Content $file.FullName -Raw
                
                # パストラバーサルの可能性
                if ($content -match '\$.*Path.*\+.*\$' -and $content -notmatch 'Join-Path') {
                    Add-SecurityIssue -Category "入力検証" `
                        -Issue "パストラバーサルの可能性" `
                        -Severity "Medium" `
                        -Description "ファイル $($file.Name) でパス結合に文字列連結が使用されています" `
                        -Recommendation "Join-Path コマンドレットを使用してパスを安全に結合してください" `
                        -CWE "CWE-22"
                }
            }
        }
    }
    
    Context "データ検証" {
        It "メールアドレスの検証が実装されていること" {
            $hasEmailValidation = $false
            $scriptFiles = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" -Recurse
            
            foreach ($file in $scriptFiles) {
                $content = Get-Content $file.FullName -Raw
                if ($content -match 'UserPrincipalName|Email|Mail') {
                    # メール検証パターンの確認
                    if ($content -match '\[ValidatePattern.*@.*\]' -or 
                        $content -match '-match.*@') {
                        $hasEmailValidation = $true
                        break
                    }
                }
            }
            
            if (-not $hasEmailValidation) {
                Add-SecurityIssue -Category "入力検証" `
                    -Issue "メールアドレス検証の不足" `
                    -Severity "Low" `
                    -Description "メールアドレスの形式検証が実装されていない可能性があります" `
                    -Recommendation "メールアドレス入力に対して適切な検証を実装してください" `
                    -CWE "CWE-20"
            }
        }
        
        It "数値パラメータの範囲検証が実装されていること" {
            $scriptFiles = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" -Recurse
            
            foreach ($file in $scriptFiles) {
                $content = Get-Content $file.FullName -Raw
                
                # パラメータ定義の確認
                if ($content -match 'param\s*\(' ) {
                    # 数値パラメータで範囲検証がない場合
                    if ($content -match '\[int\]\s*\$\w+' -and 
                        $content -notmatch '\[ValidateRange') {
                        Add-SecurityIssue -Category "入力検証" `
                            -Issue "数値範囲検証の不足" `
                            -Severity "Low" `
                            -Description "ファイル $($file.Name) で数値パラメータの範囲検証が不足しています" `
                            -Recommendation "[ValidateRange] 属性を使用して適切な範囲を指定してください" `
                            -CWE "CWE-20"
                        break
                    }
                }
            }
        }
    }
}

Describe "セキュリティ - セッション管理" -Tags @("Security", "SessionManagement", "OWASP-A07") {
    Context "認証トークンの管理" {
        It "トークンの有効期限が適切に設定されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            
            # トークン有効期限の確認（存在する場合）
            if ($config.Security.TokenLifetime) {
                $lifetime = [int]$config.Security.TokenLifetime
                if ($lifetime -gt 86400) {  # 24時間以上
                    Add-SecurityIssue -Category "セッション管理" `
                        -Issue "トークン有効期限が長すぎる" `
                        -Severity "Medium" `
                        -Description "トークンの有効期限が24時間を超えています" `
                        -Recommendation "セキュリティとユーザビリティのバランスを考慮し、適切な有効期限を設定してください" `
                        -CWE "CWE-613"
                }
            }
        }
        
        It "セッション固定攻撃への対策が実装されていること" {
            # 認証後のセッション再生成確認
            $authScripts = Get-ChildItem -Path $ScriptsPath -Filter "*auth*.ps1" -Recurse
            $hasSessionRegeneration = $false
            
            foreach ($script in $authScripts) {
                $content = Get-Content $script.FullName -Raw
                if ($content -match "New-.*Session|Regenerate.*Token") {
                    $hasSessionRegeneration = $true
                    break
                }
            }
            
            if (-not $hasSessionRegeneration) {
                Add-SecurityIssue -Category "セッション管理" `
                    -Issue "セッション固定攻撃への対策不足" `
                    -Severity "Medium" `
                    -Description "認証後のセッション再生成が実装されていない可能性があります" `
                    -Recommendation "認証成功後に新しいセッションIDを生成してください" `
                    -CWE "CWE-384"
            }
        }
    }
}

Describe "セキュリティ - 監査とログ" -Tags @("Security", "Auditing", "ISO27001") {
    Context "監査ログの完全性" {
        It "監査ログが有効化されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            
            if (-not $config.Security.EnableAuditTrail) {
                Add-SecurityIssue -Category "監査" `
                    -Issue "監査ログが無効" `
                    -Severity "High" `
                    -Description "セキュリティ監査ログが無効になっています" `
                    -Recommendation "Security.EnableAuditTrail を true に設定してください" `
                    -CWE "CWE-778"
            }
            
            $config.Security.EnableAuditTrail | Should -Be $true
        }
        
        It "適切なログレベルが設定されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            
            if ($config.Logging.LogLevel -eq "None" -or $config.Logging.LogLevel -eq "Critical") {
                Add-SecurityIssue -Category "監査" `
                    -Issue "不適切なログレベル" `
                    -Severity "Medium" `
                    -Description "ログレベルが高すぎるため、重要なイベントが記録されない可能性があります" `
                    -Recommendation "ログレベルを 'Information' または 'Warning' に設定してください"
            }
        }
        
        It "ログの改ざん防止機構が実装されていること" {
            # ログファイルの権限確認
            if (Test-Path $LogsPath) {
                $logFiles = Get-ChildItem -Path $LogsPath -Filter "*.log" -ErrorAction SilentlyContinue | 
                    Select-Object -First 1
                
                foreach ($logFile in $logFiles) {
                    $acl = Get-Acl $logFile.FullName
                    $writeAccess = $acl.Access | Where-Object { 
                        $_.FileSystemRights -match "Write" -and 
                        $_.IdentityReference -notmatch "SYSTEM|Administrators"
                    }
                    
                    if ($writeAccess) {
                        Add-SecurityIssue -Category "監査" `
                            -Issue "ログファイルの書き込み権限" `
                            -Severity "Medium" `
                            -Description "管理者以外がログファイルを変更できる可能性があります" `
                            -Recommendation "ログファイルの書き込み権限を制限してください" `
                            -CWE "CWE-732"
                    }
                }
            }
        }
    }
    
    Context "コンプライアンス要件" {
        It "個人情報のマスキングが実装されていること" {
            $loggingModule = Join-Path $ScriptsPath "Common\Logging.psm1"
            if (Test-Path $loggingModule) {
                $content = Get-Content $loggingModule -Raw
                
                if ($content -notmatch "Mask|Sanitize|Redact") {
                    Add-SecurityIssue -Category "コンプライアンス" `
                        -Issue "PII マスキング機能の不足" `
                        -Severity "Medium" `
                        -Description "ログ出力時の個人情報マスキング機能が実装されていない可能性があります" `
                        -Recommendation "個人情報をログに記録する前にマスキング処理を実装してください" `
                        -CWE "CWE-359"
                }
            }
        }
        
        It "ログ保持期間が適切に設定されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            
            if ($config.Security.LogRetentionDays) {
                $retentionDays = [int]$config.Security.LogRetentionDays
                if ($retentionDays -lt 365) {
                    Add-SecurityIssue -Category "コンプライアンス" `
                        -Issue "ログ保持期間が短い" `
                        -Severity "Low" `
                        -Description "ログ保持期間が1年未満です（現在: $retentionDays 日）" `
                        -Recommendation "コンプライアンス要件に応じて、最低1年のログ保持を推奨します"
                }
            }
        }
    }
}

Describe "セキュリティ - 脆弱な依存関係" -Tags @("Security", "Dependencies", "OWASP-A06") {
    Context "PowerShellモジュールの安全性" {
        It "使用しているモジュールが最新バージョンであること" {
            # 必須モジュールのバージョンチェック
            $requiredModules = @{
                "Microsoft.Graph" = "2.0.0"
                "ExchangeOnlineManagement" = "3.0.0"
            }
            
            foreach ($moduleName in $requiredModules.Keys) {
                $installedModule = Get-Module -Name $moduleName -ListAvailable | 
                    Sort-Object Version -Descending | Select-Object -First 1
                
                if ($installedModule) {
                    $minVersion = [Version]$requiredModules[$moduleName]
                    if ($installedModule.Version -lt $minVersion) {
                        Add-SecurityIssue -Category "依存関係" `
                            -Issue "古いモジュールバージョン" `
                            -Severity "Medium" `
                            -Description "$moduleName モジュールが古いバージョンです (現在: $($installedModule.Version), 推奨: $minVersion+)" `
                            -Recommendation "最新バージョンにアップデートしてください" `
                            -OWASP "A06:2021 - Vulnerable and Outdated Components"
                    }
                }
            }
        }
        
        It "信頼できないソースからのモジュールを使用していないこと" {
            $scriptFiles = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" -Recurse
            $untrustedSources = @("http://", "ftp://", "file://")
            
            foreach ($file in $scriptFiles) {
                $content = Get-Content $file.FullName -Raw
                
                foreach ($source in $untrustedSources) {
                    if ($content -match "Install-Module.*-Repository.*$source") {
                        Add-SecurityIssue -Category "依存関係" `
                            -Issue "信頼できないモジュールソース" `
                            -Severity "High" `
                            -Description "ファイル $($file.Name) で信頼できないソースからモジュールをインストールしています" `
                            -Recommendation "PSGallery などの信頼できるリポジトリを使用してください" `
                            -CWE "CWE-494"
                    }
                }
            }
        }
    }
}

Describe "セキュリティ - セキュアコーディング" -Tags @("Security", "SecureCoding") {
    Context "エラーハンドリング" {
        It "Try-Catchブロックが適切に実装されていること" {
            $scriptFiles = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" -Recurse
            $filesWithoutErrorHandling = @()
            
            foreach ($file in $scriptFiles) {
                $content = Get-Content $file.FullName -Raw
                
                # API呼び出しやファイル操作があるが、try-catchがない
                if (($content -match "Get-Mg|Connect-|Invoke-RestMethod|Get-Content|Set-Content") -and
                    ($content -notmatch "try\s*{")) {
                    $filesWithoutErrorHandling += $file.Name
                }
            }
            
            if ($filesWithoutErrorHandling.Count -gt 0) {
                Add-SecurityIssue -Category "エラーハンドリング" `
                    -Issue "不適切なエラーハンドリング" `
                    -Severity "Low" `
                    -Description "以下のファイルでエラーハンドリングが不足: $($filesWithoutErrorHandling -join ', ')" `
                    -Recommendation "重要な処理には try-catch ブロックを追加してください" `
                    -CWE "CWE-755"
            }
        }
    }
    
    Context "セキュアなデフォルト設定" {
        It "セキュアバイデザインの原則が適用されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            
            # デフォルトでセキュアな設定になっているか確認
            $insecureDefaults = @()
            
            if ($config.Security.EnableAuditTrail -eq $false) {
                $insecureDefaults += "監査ログがデフォルトで無効"
            }
            
            if ($config.Security.RequireMFAForAdmins -eq $false) {
                $insecureDefaults += "管理者MFAがデフォルトで無効"
            }
            
            if ($config.Security.EncryptSensitiveData -eq $false) {
                $insecureDefaults += "データ暗号化がデフォルトで無効"
            }
            
            if ($insecureDefaults.Count -gt 0) {
                Add-SecurityIssue -Category "設定" `
                    -Issue "セキュアでないデフォルト設定" `
                    -Severity "Medium" `
                    -Description "以下の設定がデフォルトでセキュアではありません: $($insecureDefaults -join ', ')" `
                    -Recommendation "セキュリティ設定をデフォルトで有効にしてください" `
                    -CWE "CWE-1188"
            }
        }
    }
}

Describe "セキュリティ - ISO/IEC 27001 コンプライアンス" -Tags @("Security", "ISO27001", "Compliance") {
    Context "アクセス制御 (A.9)" {
        It "ユーザーアクセス管理プロセスが文書化されていること" {
            $docsPath = Join-Path $TestRootPath "Docs"
            $accessControlDocs = Get-ChildItem -Path $docsPath -Filter "*access*" -ErrorAction SilentlyContinue
            
            if ($accessControlDocs.Count -eq 0) {
                Add-SecurityIssue -Category "ISO27001" `
                    -Issue "アクセス制御文書の不足" `
                    -Severity "Low" `
                    -Description "アクセス制御に関する文書が見つかりません" `
                    -Recommendation "ISO/IEC 27001 A.9 に準拠したアクセス制御文書を作成してください"
            }
            
            $script:SecurityTestResults.ComplianceChecks += [PSCustomObject]@{
                Standard = "ISO/IEC 27001"
                Control = "A.9 - Access Control"
                Status = if ($accessControlDocs.Count -gt 0) { "Compliant" } else { "Non-Compliant" }
            }
        }
        
        It "特権アクセス管理が実装されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $hasPrivilegedAccessControl = $config.Security.RequireMFAForAdmins -eq $true
            
            $script:SecurityTestResults.ComplianceChecks += [PSCustomObject]@{
                Standard = "ISO/IEC 27001"
                Control = "A.9.2 - User access management"
                Status = if ($hasPrivilegedAccessControl) { "Compliant" } else { "Non-Compliant" }
            }
            
            $hasPrivilegedAccessControl | Should -Be $true
        }
    }
    
    Context "暗号化 (A.10)" {
        It "暗号化ポリシーが実装されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $encryptionEnabled = $config.Security.EncryptSensitiveData -eq $true
            
            $script:SecurityTestResults.ComplianceChecks += [PSCustomObject]@{
                Standard = "ISO/IEC 27001"
                Control = "A.10 - Cryptography"
                Status = if ($encryptionEnabled) { "Compliant" } else { "Non-Compliant" }
            }
            
            $encryptionEnabled | Should -Be $true
        }
    }
    
    Context "運用セキュリティ (A.12)" {
        It "ログ記録と監視が実装されていること" {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $loggingEnabled = $config.Security.EnableAuditTrail -eq $true -and
                             $config.Logging.Enabled -ne $false
            
            $script:SecurityTestResults.ComplianceChecks += [PSCustomObject]@{
                Standard = "ISO/IEC 27001"
                Control = "A.12.4 - Logging and monitoring"
                Status = if ($loggingEnabled) { "Compliant" } else { "Non-Compliant" }
            }
            
            $loggingEnabled | Should -Be $true
        }
        
        It "脆弱性管理プロセスが存在すること" {
            # セキュリティテストスクリプトの存在確認
            $securityTests = Get-ChildItem -Path $TestScriptsPath -Filter "*security*" -ErrorAction SilentlyContinue
            $hasVulnerabilityManagement = $securityTests.Count -gt 0
            
            $script:SecurityTestResults.ComplianceChecks += [PSCustomObject]@{
                Standard = "ISO/IEC 27001"
                Control = "A.12.6 - Technical vulnerability management"
                Status = if ($hasVulnerabilityManagement) { "Compliant" } else { "Non-Compliant" }
            }
        }
    }
    
    Context "インシデント管理 (A.16)" {
        It "セキュリティインシデント対応手順が定義されていること" {
            $incidentResponseDoc = Get-ChildItem -Path $TestRootPath -Filter "*incident*" -Recurse -ErrorAction SilentlyContinue
            $hasIncidentResponse = $incidentResponseDoc.Count -gt 0
            
            if (-not $hasIncidentResponse) {
                Add-SecurityIssue -Category "ISO27001" `
                    -Issue "インシデント対応手順の不足" `
                    -Severity "Medium" `
                    -Description "セキュリティインシデント対応手順が文書化されていません" `
                    -Recommendation "ISO/IEC 27001 A.16 に準拠したインシデント対応手順を作成してください"
            }
            
            $script:SecurityTestResults.ComplianceChecks += [PSCustomObject]@{
                Standard = "ISO/IEC 27001"
                Control = "A.16 - Information security incident management"
                Status = if ($hasIncidentResponse) { "Compliant" } else { "Non-Compliant" }
            }
        }
    }
}

AfterAll {
    $SecurityTestResults.EndTime = Get-Date
    
    # セキュリティスコアの最終調整
    if ($SecurityTestResults.SecurityScore -lt 0) {
        $SecurityTestResults.SecurityScore = 0
    }
    
    # レポート生成
    $reportPath = Join-Path $TestRootPath "TestOutput"
    if (-not (Test-Path $reportPath)) {
        New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
    }
    
    $reportFile = Join-Path $reportPath "SecurityTestReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    
    # HTMLレポート生成
    $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>セキュリティテストレポート</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        .summary { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .score { font-size: 48px; font-weight: bold; color: $(if ($SecurityTestResults.SecurityScore -ge 80) { "#28a745" } elseif ($SecurityTestResults.SecurityScore -ge 60) { "#ffc107" } else { "#dc3545" }); }
        .critical { color: #dc3545; font-weight: bold; }
        .high { color: #fd7e14; font-weight: bold; }
        .medium { color: #ffc107; }
        .low { color: #6c757d; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #007bff; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .recommendation { background-color: #e7f3ff; padding: 10px; border-left: 4px solid #007bff; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔒 セキュリティテストレポート</h1>
        
        <div class="summary">
            <h2>エグゼクティブサマリー</h2>
            <p>テスト実行日時: $(Get-Date -Format "yyyy年MM月dd日 HH:mm:ss")</p>
            <p>実行時間: $(($SecurityTestResults.EndTime - $SecurityTestResults.StartTime).TotalSeconds) 秒</p>
            <div class="score">セキュリティスコア: $($SecurityTestResults.SecurityScore)/100</div>
            <p>
                <span class="critical">Critical: $($SecurityTestResults.CriticalIssues)</span> | 
                <span class="high">High: $($SecurityTestResults.HighIssues)</span> | 
                <span class="medium">Medium: $($SecurityTestResults.MediumIssues)</span> | 
                <span class="low">Low: $($SecurityTestResults.LowIssues)</span>
            </p>
        </div>
        
        <h2>🚨 検出された脆弱性</h2>
        <table>
            <tr>
                <th>カテゴリ</th>
                <th>問題</th>
                <th>深刻度</th>
                <th>説明</th>
                <th>CWE/OWASP</th>
            </tr>
"@
    
    foreach ($vuln in ($SecurityTestResults.Vulnerabilities | Sort-Object @{Expression={
        switch($_.Severity) {"Critical"{"1"}"High"{"2"}"Medium"{"3"}"Low"{"4"}}
    }})) {
        $severityClass = $vuln.Severity.ToLower()
        $htmlReport += @"
            <tr>
                <td>$($vuln.Category)</td>
                <td>$($vuln.Issue)</td>
                <td class="$severityClass">$($vuln.Severity)</td>
                <td>$($vuln.Description)</td>
                <td>$($vuln.CWE) / $($vuln.OWASP)</td>
            </tr>
"@
    }
    
    $htmlReport += @"
        </table>
        
        <h2>✅ ISO/IEC 27001 コンプライアンスチェック</h2>
        <table>
            <tr>
                <th>標準</th>
                <th>管理策</th>
                <th>ステータス</th>
            </tr>
"@
    
    foreach ($check in $SecurityTestResults.ComplianceChecks) {
        $statusColor = if ($check.Status -eq "Compliant") { "color: green;" } else { "color: red;" }
        $htmlReport += @"
            <tr>
                <td>$($check.Standard)</td>
                <td>$($check.Control)</td>
                <td style="$statusColor">$($check.Status)</td>
            </tr>
"@
    }
    
    $htmlReport += @"
        </table>
        
        <h2>📋 推奨事項</h2>
"@
    
    # 重要度別に推奨事項を整理
    $criticalRecommendations = $SecurityTestResults.Vulnerabilities | Where-Object { $_.Severity -eq "Critical" }
    if ($criticalRecommendations) {
        $htmlReport += "<h3>緊急対応が必要な項目</h3>"
        foreach ($rec in $criticalRecommendations) {
            $htmlReport += @"
            <div class="recommendation">
                <strong>$($rec.Issue)</strong><br>
                $($rec.Recommendation)
            </div>
"@
        }
    }
    
    $htmlReport += @"
    </div>
</body>
</html>
"@
    
    $htmlReport | Out-File -FilePath $reportFile -Encoding UTF8
    
    # コンソール出力
    Write-Host "`n=== セキュリティテスト結果 ===" -ForegroundColor Cyan
    Write-Host "セキュリティスコア: $($SecurityTestResults.SecurityScore)/100" -ForegroundColor $(
        if ($SecurityTestResults.SecurityScore -ge 80) { "Green" }
        elseif ($SecurityTestResults.SecurityScore -ge 60) { "Yellow" }
        else { "Red" }
    )
    Write-Host "Critical 問題: $($SecurityTestResults.CriticalIssues)" -ForegroundColor Red
    Write-Host "High 問題: $($SecurityTestResults.HighIssues)" -ForegroundColor DarkYellow
    Write-Host "Medium 問題: $($SecurityTestResults.MediumIssues)" -ForegroundColor Yellow
    Write-Host "Low 問題: $($SecurityTestResults.LowIssues)" -ForegroundColor Gray
    Write-Host "`nレポートファイル: $reportFile" -ForegroundColor Green
    
    # JSON形式でも保存
    $jsonReport = Join-Path $reportPath "SecurityTestReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $SecurityTestResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonReport -Encoding UTF8
    
    Write-Host "JSONレポート: $jsonReport" -ForegroundColor Green
    Write-Host "`n✅ セキュリティテストスイート完了" -ForegroundColor Green
}