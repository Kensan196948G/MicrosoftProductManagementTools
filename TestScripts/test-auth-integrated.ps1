# 統合認証テストスクリプト（修正版）
# ローカル設定ファイル対応版

param(
    [switch]$SkipExchangeOnline
)

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                   Microsoft 365 統合認証テスト                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta

Write-Host ""
Write-Host "Microsoft 365サービスへの認証テストを実行します" -ForegroundColor Yellow
Write-Host ""

$testResult = @{
    ConfigurationCheck = $false
    ModuleCheck = $false
    MicrosoftGraphTest = $false
    ExchangeOnlineTest = $false
    OverallSuccess = $false
    Details = @()
}

try {
    # 1. 設定ファイル確認
    Write-Host "=== 1. 設定ファイル確認 ===" -ForegroundColor Yellow
    
    # ローカル設定ファイルを優先的に読み込み
    $baseConfigPath = "Config/appsettings.json"
    $localConfigPath = "Config/appsettings.local.json"
    
    $config = $null
    $usedConfigPath = ""
    
    if (Test-Path $localConfigPath) {
        try {
            $config = Get-Content $localConfigPath -Raw | ConvertFrom-Json
            $usedConfigPath = $localConfigPath
            Write-Host "  ✓ ローカル設定ファイル読み込み成功: appsettings.local.json" -ForegroundColor Green
            $testResult.ConfigurationCheck = $true
        }
        catch {
            Write-Host "  ✗ ローカル設定ファイルの読み込みに失敗: $($_.Exception.Message)" -ForegroundColor Red
            $testResult.Details += "ローカル設定ファイル読み込みエラー"
            Write-Host ""
            Read-Host "Enterキーを押して終了"
            return $false
        }
    }
    elseif (Test-Path $baseConfigPath) {
        try {
            $config = Get-Content $baseConfigPath -Raw | ConvertFrom-Json
            $usedConfigPath = $baseConfigPath
            
            # プレースホルダーチェック
            if ($config.EntraID.ClientId -like "*YOUR-*-HERE*" -or $config.EntraID.TenantId -like "*YOUR-*-HERE*") {
                Write-Host "  ✗ 設定ファイルにプレースホルダーが含まれています" -ForegroundColor Red
                Write-Host "    💡 Config/appsettings.local.json を作成して実際の認証情報を設定してください" -ForegroundColor Yellow
                $testResult.Details += "設定ファイルにプレースホルダーが含まれています"
                Write-Host ""
                Read-Host "Enterキーを押して終了"
                return $false
            }
            
            Write-Host "  ✓ ベース設定ファイル読み込み成功: appsettings.json" -ForegroundColor Green
            $testResult.ConfigurationCheck = $true
        }
        catch {
            Write-Host "  ✗ 設定ファイルの読み込みに失敗: $($_.Exception.Message)" -ForegroundColor Red
            $testResult.Details += "設定ファイル読み込みエラー"
            Write-Host ""
            Read-Host "Enterキーを押して終了"
            return $false
        }
    }
    else {
        Write-Host "  ✗ 設定ファイルが見つかりません" -ForegroundColor Red
        Write-Host "    チェック対象: appsettings.json, appsettings.local.json" -ForegroundColor Yellow
        $testResult.Details += "設定ファイルが存在しません"
        Write-Host ""
        Read-Host "Enterキーを押して終了"
        return $false
    }
    Write-Host ""
    
    # 2. 必要モジュール確認
    Write-Host "=== 2. 必要モジュール確認 ===" -ForegroundColor Yellow
    $requiredModules = @("Microsoft.Graph", "ExchangeOnlineManagement")
    $missingModules = @()
    
    foreach ($module in $requiredModules) {
        $installedModule = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending | Select-Object -First 1
        if ($installedModule) {
            Write-Host "  ✓ $module v$($installedModule.Version)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $module が見つかりません" -ForegroundColor Red
            $missingModules += $module
        }
    }
    
    if ($missingModules.Count -gt 0) {
        Write-Host ""
        Write-Host "  不足しているモジュール: $($missingModules -join ', ')" -ForegroundColor Red
        Write-Host "  以下のコマンドでインストールしてください:" -ForegroundColor Yellow
        foreach ($module in $missingModules) {
            Write-Host "    Install-Module $module -Scope CurrentUser" -ForegroundColor Cyan
        }
        $testResult.Details += "必要モジュールが不足"
        Write-Host ""
        Read-Host "Enterキーを押して終了"
        return $false
    }
    
    $testResult.ModuleCheck = $true
    Write-Host ""
    
    # 3. Microsoft Graph 認証テスト
    Write-Host "=== 3. Microsoft Graph 認証テスト ===" -ForegroundColor Yellow
    try {
        Import-Module Microsoft.Graph -Force -ErrorAction Stop
        
        # 既存接続の切断
        try {
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        } catch { }
        
        $graphConfig = $config.EntraID
        $connectionSuccessful = $false
        
        # クライアントシークレット認証テスト
        if ($graphConfig.ClientSecret -and $graphConfig.ClientSecret -ne "" -and $graphConfig.ClientSecret -notlike "*YOUR-*-HERE*") {
            Write-Host "  クライアントシークレット認証でテスト中..." -ForegroundColor Cyan
            try {
                $secureSecret = ConvertTo-SecureString $graphConfig.ClientSecret -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential ($graphConfig.ClientId, $secureSecret)
                
                Connect-MgGraph -TenantId $graphConfig.TenantId -ClientSecretCredential $credential -NoWelcome
                
                # 接続テスト
                $testUser = Get-MgUser -Top 1 -Property Id,DisplayName -ErrorAction Stop
                Write-Host "  ✓ Microsoft Graph クライアントシークレット認証成功" -ForegroundColor Green
                Write-Host "    テナント: $((Get-MgContext).TenantId)" -ForegroundColor Cyan
                Write-Host "    取得したユーザー数: 1" -ForegroundColor Cyan
                $connectionSuccessful = $true
                $testResult.MicrosoftGraphTest = $true
            }
            catch {
                Write-Host "  ✗ Microsoft Graph クライアントシークレット認証失敗: $($_.Exception.Message)" -ForegroundColor Red
                $testResult.Details += "Microsoft Graph クライアントシークレット認証失敗"
            }
        }
        # 証明書認証テスト
        elseif ($graphConfig.CertificateThumbprint -and $graphConfig.CertificateThumbprint -notlike "*YOUR-*-HERE*") {
            Write-Host "  証明書認証でテスト中..." -ForegroundColor Cyan
            try {
                Connect-MgGraph -TenantId $graphConfig.TenantId -ClientId $graphConfig.ClientId -CertificateThumbprint $graphConfig.CertificateThumbprint -NoWelcome
                
                # 接続テスト
                $testUser = Get-MgUser -Top 1 -Property Id,DisplayName -ErrorAction Stop
                Write-Host "  ✓ Microsoft Graph 証明書認証成功" -ForegroundColor Green
                Write-Host "    テナント: $((Get-MgContext).TenantId)" -ForegroundColor Cyan
                Write-Host "    取得したユーザー数: 1" -ForegroundColor Cyan
                $connectionSuccessful = $true
                $testResult.MicrosoftGraphTest = $true
            }
            catch {
                Write-Host "  ✗ Microsoft Graph 証明書認証失敗: $($_.Exception.Message)" -ForegroundColor Red
                $testResult.Details += "Microsoft Graph 証明書認証失敗"
            }
        }
        else {
            Write-Host "  ✗ Microsoft Graph の認証情報が設定されていません" -ForegroundColor Red
            $testResult.Details += "Microsoft Graph 認証情報未設定"
        }
        
        # 接続切断
        if ($connectionSuccessful) {
            try {
                Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            } catch { }
        }
    }
    catch {
        Write-Host "  ✗ Microsoft Graph テストエラー: $($_.Exception.Message)" -ForegroundColor Red
        $testResult.Details += "Microsoft Graph テストエラー"
    }
    Write-Host ""
    
    # 4. Exchange Online 認証テスト
    if (-not $SkipExchangeOnline) {
        Write-Host "=== 4. Exchange Online 認証テスト ===" -ForegroundColor Yellow
        try {
            Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop
            
            # 既存接続の切断
            try {
                Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            } catch { }
            
            # Exchange Online設定を再読み込み（確実性のため）
            $exoConfig = $config.ExchangeOnline
            $connectionSuccessful = $false
            
            # 証明書認証テスト（Thumbprint） - 条件を明示的に評価
            $hasValidThumbprint = ($exoConfig.CertificateThumbprint -and $exoConfig.CertificateThumbprint -notlike "*YOUR-*-HERE*")
            $hasValidOrganization = ($exoConfig.Organization -and $exoConfig.Organization -ne "")
            $hasValidAppId = ($exoConfig.AppId -and $exoConfig.AppId -ne "")
            
            if ($hasValidThumbprint -and $hasValidOrganization -and $hasValidAppId) {
                Write-Host "  証明書認証でテスト中..." -ForegroundColor Cyan
                try {
                    # WSL2環境チェック
                    if ($env:WSL_DISTRO_NAME) {
                        Write-Host "  ⚠️  WSL2環境のため証明書ストアにアクセスできません" -ForegroundColor Yellow
                        Write-Host "     Windows環境での実行を推奨します" -ForegroundColor Yellow
                        $testResult.Details += "Exchange Online WSL2制限"
                    }
                    else {
                        Connect-ExchangeOnline -Organization $exoConfig.Organization -AppId $exoConfig.AppId -CertificateThumbprint $exoConfig.CertificateThumbprint -ShowBanner:$false
                        
                        # 接続テスト
                        $testOrg = Get-OrganizationConfig -ErrorAction Stop | Select-Object -First 1
                        Write-Host "  ✓ Exchange Online 証明書認証成功" -ForegroundColor Green
                        Write-Host "    組織: $($testOrg.Name)" -ForegroundColor Cyan
                        $connectionSuccessful = $true
                        $testResult.ExchangeOnlineTest = $true
                    }
                }
                catch {
                    Write-Host "  ✗ Exchange Online 証明書認証失敗: $($_.Exception.Message)" -ForegroundColor Red
                    $testResult.Details += "Exchange Online 証明書認証失敗"
                }
            }
            else {
                Write-Host "  ✗ Exchange Online の認証情報が設定されていません" -ForegroundColor Red
                Write-Host "    設定状況:" -ForegroundColor Yellow
                Write-Host "      CertificateThumbprint: $(if ($hasValidThumbprint) { '✓' } else { '✗' })" -ForegroundColor Yellow
                Write-Host "      Organization: $(if ($hasValidOrganization) { '✓' } else { '✗' })" -ForegroundColor Yellow
                Write-Host "      AppId: $(if ($hasValidAppId) { '✓' } else { '✗' })" -ForegroundColor Yellow
                $testResult.Details += "Exchange Online 認証情報未設定"
            }
            
            # 接続切断
            if ($connectionSuccessful) {
                try {
                    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                } catch { }
            }
        }
        catch {
            Write-Host "  ✗ Exchange Online テストエラー: $($_.Exception.Message)" -ForegroundColor Red
            $testResult.Details += "Exchange Online テストエラー"
        }
        Write-Host ""
    }
    else {
        Write-Host "=== 4. Exchange Online 認証テスト ===" -ForegroundColor Yellow
        Write-Host "  ⏭️  Exchange Online テストはスキップされました" -ForegroundColor Yellow
        Write-Host ""
    }
    
    # 結果サマリー
    Write-Host "=== 認証テスト完了 ===" -ForegroundColor Green
    $successCount = 0
    $totalTests = 2 + ($SkipExchangeOnline ? 0 : 2)
    
    if ($testResult.ConfigurationCheck) { $successCount++ }
    if ($testResult.ModuleCheck) { $successCount++ }
    if ($testResult.MicrosoftGraphTest) { $successCount++ }
    if ($testResult.ExchangeOnlineTest -or $SkipExchangeOnline) { $successCount++ }
    
    Write-Host "成功テスト: $successCount/$totalTests" -ForegroundColor White
    Write-Host ""
    
    if ($successCount -eq $totalTests) {
        Write-Host "✅ 認証テストが完全に成功しました！" -ForegroundColor Green
        $testResult.OverallSuccess = $true
    } else {
        Write-Host "⚠ 認証テストが完全に成功していません" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "問題点:" -ForegroundColor Yellow
        foreach ($detail in $testResult.Details) {
            Write-Host "  - $detail" -ForegroundColor Yellow
        }
        Write-Host ""
        if ($testResult.Details -contains "Exchange Online WSL2制限") {
            Write-Host "💡 Exchange Online機能はWindows環境で正常に動作します" -ForegroundColor Cyan
        }
        Write-Host "設定を確認してください: $usedConfigPath" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Read-Host "Enterキーを押して終了"
    
    return $testResult.OverallSuccess
}
catch {
    Write-Host ""
    Write-Host "💥 予期しないエラーが発生しました" -ForegroundColor Red
    Write-Host "エラー詳細: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Read-Host "Enterキーを押して終了"
    return $false
}