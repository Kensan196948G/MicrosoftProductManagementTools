# ================================================================================
# test-auth-status.ps1
# Microsoft 365接続状況の詳細確認テスト
# ================================================================================

Write-Host "=== Microsoft 365 接続状況詳細テスト ===" -ForegroundColor Green
Write-Host "実行時刻: $(Get-Date -Format 'yyyy/MM/dd HH:mm:ss')" -ForegroundColor Cyan

# 1. Microsoft Graph接続確認
Write-Host "`n1. Microsoft Graph接続確認" -ForegroundColor Yellow
try {
    $context = Get-MgContext -ErrorAction Stop
    if ($context) {
        Write-Host "   ✅ Microsoft Graph Context発見" -ForegroundColor Green
        Write-Host "   テナントID: $($context.TenantId)" -ForegroundColor Cyan
        Write-Host "   クライアントID: $($context.ClientId)" -ForegroundColor Cyan
        Write-Host "   認証タイプ: $($context.AuthType)" -ForegroundColor Cyan
        Write-Host "   スコープ数: $($context.Scopes.Count)" -ForegroundColor Cyan
        
        # 実際のAPI呼び出しテスト
        try {
            $testUser = Get-MgUser -Top 1 -Property Id,DisplayName -ErrorAction Stop
            Write-Host "   ✅ API呼び出しテスト: 成功" -ForegroundColor Green
            Write-Host "   取得ユーザー例: $($testUser.DisplayName)" -ForegroundColor Cyan
        } catch {
            Write-Host "   ❌ API呼び出しテスト: 失敗 - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   ❌ Microsoft Graph未接続" -ForegroundColor Red
    Write-Host "   エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Exchange Online接続確認
Write-Host "`n2. Exchange Online接続確認" -ForegroundColor Yellow
try {
    $connectionInfo = Get-ConnectionInformation -ErrorAction Stop
    if ($connectionInfo) {
        Write-Host "   ✅ Exchange Online接続確認: 成功" -ForegroundColor Green
        Write-Host "   接続ユーザー: $($connectionInfo.UserPrincipalName)" -ForegroundColor Cyan
        Write-Host "   接続状態: $($connectionInfo.State)" -ForegroundColor Cyan
        
        # 組織情報取得テスト
        try {
            $orgConfig = Get-OrganizationConfig -ErrorAction Stop
            Write-Host "   ✅ 組織設定取得: 成功" -ForegroundColor Green
            Write-Host "   組織名: $($orgConfig.DisplayName)" -ForegroundColor Cyan
        } catch {
            Write-Host "   ❌ 組織設定取得: 失敗 - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   ❌ Exchange Online未接続" -ForegroundColor Red
    Write-Host "   エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. PowerShellセッション確認
Write-Host "`n3. PowerShellセッション確認" -ForegroundColor Yellow
try {
    $allSessions = Get-PSSession
    $exoSessions = $allSessions | Where-Object { 
        ($_.Name -like "*ExchangeOnline*" -or $_.ConfigurationName -eq "Microsoft.Exchange") -and 
        $_.State -eq "Opened" 
    }
    
    Write-Host "   総セッション数: $($allSessions.Count)" -ForegroundColor Cyan
    if ($exoSessions) {
        Write-Host "   ✅ Exchange Onlineセッション: $($exoSessions.Count)個 発見" -ForegroundColor Green
        foreach ($session in $exoSessions) {
            Write-Host "     - $($session.Name) ($($session.State))" -ForegroundColor Cyan
        }
    } else {
        Write-Host "   ❌ Exchange Onlineセッション: 未発見" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ セッション確認エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. モジュール確認
Write-Host "`n4. 必要モジュール確認" -ForegroundColor Yellow
$requiredModules = @("Microsoft.Graph", "ExchangeOnlineManagement")
foreach ($module in $requiredModules) {
    try {
        $moduleInfo = Get-Module -Name $module -ListAvailable | Select-Object -First 1
        if ($moduleInfo) {
            $loadedModule = Get-Module -Name $module
            $status = if ($loadedModule) { "読み込み済み" } else { "インストール済み（未読み込み）" }
            Write-Host "   ✅ $module : $status (v$($moduleInfo.Version))" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $module : 未インストール" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ $module : 確認エラー - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 5. 設定ファイル確認
Write-Host "`n5. 設定ファイル確認" -ForegroundColor Yellow
$configPath = "Config\appsettings.json"
if (Test-Path $configPath) {
    Write-Host "   ✅ 設定ファイル発見: $configPath" -ForegroundColor Green
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        Write-Host "   テナントID: $($config.EntraID.TenantId)" -ForegroundColor Cyan
        Write-Host "   クライアントID: $($config.EntraID.ClientId)" -ForegroundColor Cyan
        Write-Host "   証明書パス: $($config.EntraID.CertificatePath)" -ForegroundColor Cyan
        
        # 証明書ファイル確認
        if ($config.EntraID.CertificatePath) {
            if (Test-Path $config.EntraID.CertificatePath) {
                Write-Host "   ✅ 証明書ファイル確認: 存在" -ForegroundColor Green
            } else {
                Write-Host "   ❌ 証明書ファイル確認: 未発見" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "   ❌ 設定ファイル読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   ❌ 設定ファイル未発見: $configPath" -ForegroundColor Red
}

Write-Host "`n=== 接続状況確認完了 ===" -ForegroundColor Green
Write-Host "このテスト結果を参考に認証テストの問題を確認してください。" -ForegroundColor White