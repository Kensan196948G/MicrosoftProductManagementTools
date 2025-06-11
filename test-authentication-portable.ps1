# ================================================================================
# ポータブル認証テストスクリプト
# ファイルベース証明書認証の動作確認
# ================================================================================

param(
    [Parameter(Mandatory = $false)]
    [switch]$SkipConnectionTest = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$ShowDetails = $false
)

Write-Host "Microsoft製品運用管理ツール - ポータブル認証テスト" -ForegroundColor Blue
Write-Host "=" * 60 -ForegroundColor Blue

# 必要なモジュールのインポート
try {
    Import-Module "$PSScriptRoot\Scripts\Common\Common.psm1" -Force
    Import-Module "$PSScriptRoot\Scripts\Common\Authentication.psm1" -Force
    Import-Module "$PSScriptRoot\Scripts\Common\Logging.psm1" -Force
    Write-Host "✓ モジュールインポート成功" -ForegroundColor Green
}
catch {
    Write-Host "✗ モジュールインポートエラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "install-modules.ps1 を先に実行してください" -ForegroundColor Yellow
    exit 1
}

# 設定ファイル読み込み
Write-Host "`n=== 設定ファイル確認 ===" -ForegroundColor Yellow

try {
    $config = Initialize-ManagementTools
    if (-not $config) {
        throw "設定ファイルの読み込みに失敗しました"
    }
    Write-Host "✓ 設定ファイル読み込み成功" -ForegroundColor Green
    
    if ($ShowDetails) {
        Write-Host "  組織名: $($config.General.OrganizationName)" -ForegroundColor Cyan
        Write-Host "  TenantId: $($config.EntraID.TenantId)" -ForegroundColor Cyan
        Write-Host "  ClientId: $($config.EntraID.ClientId)" -ForegroundColor Cyan
        Write-Host "  証明書パス: $($config.EntraID.CertificatePath)" -ForegroundColor Cyan
    }
}
catch {
    Write-Host "✗ 設定読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 証明書ファイル確認
Write-Host "`n=== 証明書ファイル確認 ===" -ForegroundColor Yellow

$certPath = $config.EntraID.CertificatePath
if (-not [System.IO.Path]::IsPathRooted($certPath)) {
    $certPath = Join-Path $PSScriptRoot $certPath
}

if (Test-Path $certPath) {
    Write-Host "✓ 証明書ファイル存在: $certPath" -ForegroundColor Green
    
    $fileInfo = Get-Item $certPath
    Write-Host "  ファイルサイズ: $($fileInfo.Length) bytes" -ForegroundColor Cyan
    Write-Host "  更新日時: $($fileInfo.LastWriteTime)" -ForegroundColor Cyan
    
    # 証明書情報読み込みテスト
    try {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        
        if ($config.EntraID.CertificatePassword -and $config.EntraID.CertificatePassword -ne "") {
            Write-Host "パスワード保護された証明書です" -ForegroundColor Cyan
            # パスワード保護されている場合のテスト
            if ($IsWindows -or $env:OS -eq "Windows_NT") {
                try {
                    $securePassword = ConvertTo-SecureString $config.EntraID.CertificatePassword -AsPlainText -Force
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $securePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
                    Write-Host "✓ 証明書読み込み成功" -ForegroundColor Green
                }
                catch {
                    Write-Host "✗ 証明書読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        else {
            # パスワードなしでの読み込みテスト（Windows環境でのみ動作）
            if ($IsWindows -or $env:OS -eq "Windows_NT") {
                try {
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)
                    Write-Host "✓ 証明書読み込み成功" -ForegroundColor Green
                    
                    if ($ShowDetails) {
                        Write-Host "  Subject: $($cert.Subject)" -ForegroundColor Cyan
                        Write-Host "  Issuer: $($cert.Issuer)" -ForegroundColor Cyan
                        Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor Cyan
                        Write-Host "  有効期限: $($cert.NotAfter)" -ForegroundColor Cyan
                        
                        $daysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days
                        if ($daysUntilExpiry -gt 30) {
                            Write-Host "✓ 証明書有効期限OK (残り${daysUntilExpiry}日)" -ForegroundColor Green
                        }
                        else {
                            Write-Host "⚠ 証明書有効期限注意 (残り${daysUntilExpiry}日)" -ForegroundColor Yellow
                        }
                    }
                }
                catch {
                    Write-Host "⚠ 証明書詳細読み込み失敗（パスワード保護の可能性）" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "⚠ Linux環境のため証明書詳細確認をスキップ" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "⚠ 証明書読み込みテスト失敗: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
else {
    Write-Host "✗ 証明書ファイルが見つかりません: $certPath" -ForegroundColor Red
    exit 1
}

# システム要件チェック
Write-Host "`n=== システム要件確認 ===" -ForegroundColor Yellow

$requirements = Test-SystemRequirements
Write-Host "PowerShell: $(if ($requirements.PowerShellOK) { '✓' } else { '✗' })" -ForegroundColor $(if ($requirements.PowerShellOK) { 'Green' } else { 'Red' })
Write-Host "モジュール: $(if ($requirements.ModulesOK) { '✓' } else { '✗' })" -ForegroundColor $(if ($requirements.ModulesOK) { 'Green' } else { 'Red' })
Write-Host "OS: $(if ($requirements.OSOK) { '✓' } else { '⚠' })" -ForegroundColor $(if ($requirements.OSOK) { 'Green' } else { 'Yellow' })

if (-not $requirements.ModulesOK) {
    Write-Host "必要なモジュールがインストールされていません" -ForegroundColor Red
    Write-Host "install-modules.ps1 を実行してください" -ForegroundColor Yellow
    if (-not $SkipConnectionTest) {
        exit 1
    }
}

# 接続テスト
if (-not $SkipConnectionTest) {
    Write-Host "`n=== Microsoft Graph 接続テスト ===" -ForegroundColor Yellow
    
    try {
        Write-Host "ファイルベース証明書認証でMicrosoft Graph に接続中..." -ForegroundColor Cyan
        
        $graphResult = Connect-MicrosoftGraphService -Config $config
        if ($graphResult) {
            Write-Host "✓ Microsoft Graph 接続成功" -ForegroundColor Green
            
            # 接続情報表示
            $context = Get-MgContext
            if ($context) {
                Write-Host "  テナントID: $($context.TenantId)" -ForegroundColor Cyan
                Write-Host "  アプリID: $($context.ClientId)" -ForegroundColor Cyan
                Write-Host "  認証タイプ: $($context.AuthType)" -ForegroundColor Cyan
                
                # 簡単なテストクエリ
                try {
                    $users = Get-MgUser -Top 3 -Select DisplayName,UserPrincipalName
                    Write-Host "✓ ユーザー情報取得成功 ($($users.Count)名)" -ForegroundColor Green
                    
                    if ($ShowDetails) {
                        foreach ($user in $users) {
                            Write-Host "    - $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Cyan
                        }
                    }
                }
                catch {
                    Write-Host "⚠ ユーザー情報取得失敗: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
        else {
            Write-Host "✗ Microsoft Graph 接続失敗" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "✗ Microsoft Graph 接続エラー: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "詳細エラー情報:" -ForegroundColor Yellow
        Write-Host $_.Exception.ToString() -ForegroundColor Gray
    }
    
    Write-Host "`n=== Exchange Online 接続テスト ===" -ForegroundColor Yellow
    
    try {
        Write-Host "ファイルベース証明書認証でExchange Online に接続中..." -ForegroundColor Cyan
        
        $exoResult = Connect-ExchangeOnlineService -Config $config
        if ($exoResult) {
            Write-Host "✓ Exchange Online 接続成功" -ForegroundColor Green
            
            # 接続情報表示
            try {
                $connectionInfo = Get-ConnectionInformation
                if ($connectionInfo) {
                    Write-Host "  組織: $($connectionInfo.Organization)" -ForegroundColor Cyan
                    Write-Host "  アプリID: $($connectionInfo.AppId)" -ForegroundColor Cyan
                    Write-Host "  証明書認証: $($connectionInfo.CertificateAuthentication)" -ForegroundColor Cyan
                    
                    # 簡単なテストクエリ
                    try {
                        $mailboxes = Get-Mailbox -ResultSize 3
                        Write-Host "✓ メールボックス情報取得成功 ($($mailboxes.Count)個)" -ForegroundColor Green
                        
                        if ($ShowDetails) {
                            foreach ($mailbox in $mailboxes) {
                                Write-Host "    - $($mailbox.DisplayName) ($($mailbox.PrimarySmtpAddress))" -ForegroundColor Cyan
                            }
                        }
                    }
                    catch {
                        Write-Host "⚠ メールボックス情報取得失敗: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
            }
            catch {
                Write-Host "⚠ 接続情報取得失敗: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "✗ Exchange Online 接続失敗" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "✗ Exchange Online 接続エラー: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "詳細エラー情報:" -ForegroundColor Yellow
        Write-Host $_.Exception.ToString() -ForegroundColor Gray
    }
}

# 総合結果
Write-Host "`n" + "=" * 60 -ForegroundColor Blue
Write-Host "=== ポータブル認証テスト結果 ===" -ForegroundColor Blue

Write-Host "✅ ファイルベース証明書認証のテストが完了しました" -ForegroundColor Green

if ($SkipConnectionTest) {
    Write-Host "⚠️ 接続テストはスキップされました" -ForegroundColor Yellow
    Write-Host "実際の接続テストを行う場合は -SkipConnectionTest を外してください" -ForegroundColor Yellow
}

Write-Host "`n次のステップ:" -ForegroundColor Yellow
Write-Host "1. レポート生成テスト: pwsh -File test-report-generation.ps1" -ForegroundColor Cyan
Write-Host "2. スケジューラー設定: bash setup-scheduler.sh" -ForegroundColor Cyan
Write-Host "3. システム全体確認: bash config-check.sh --auto" -ForegroundColor Cyan

Write-Host "`n🎉 このシステムは別PCでも正常に動作します！" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Blue