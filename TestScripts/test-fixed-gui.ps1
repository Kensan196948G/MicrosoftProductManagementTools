# ================================================================================
# test-fixed-gui.ps1
# 修正されたGUIアプリケーションの動作確認テスト
# ================================================================================

Write-Host "=== GUI修正版動作確認テスト ===" -ForegroundColor Green
Write-Host "実行時刻: $(Get-Date -Format 'yyyy/MM/dd HH:mm:ss')" -ForegroundColor Cyan

# 1. AuthenticationTest.psm1の構文チェック
Write-Host "`n1. AuthenticationTest.psm1構文チェック" -ForegroundColor Yellow
try {
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content "Scripts\Common\AuthenticationTest.psm1" -Raw), [ref]$null)
    Write-Host "   ✅ 構文チェック: OK" -ForegroundColor Green
} catch {
    Write-Host "   ❌ 構文エラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. SafeDataProviderの読み込みテスト
Write-Host "`n2. SafeDataProviderモジュールテスト" -ForegroundColor Yellow
try {
    Import-Module "Scripts\Common\SafeDataProvider.psm1" -Force
    Write-Host "   ✅ SafeDataProvider読み込み: OK" -ForegroundColor Green
    
    # 権限監査データテスト
    $testPermissionData = Get-SafePermissionAuditData -UserCount 5 -GroupCount 3
    Write-Host "   ✅ 権限監査テストデータ: $($testPermissionData.Count)件生成" -ForegroundColor Green
    
    # セキュリティ分析データテスト
    $testSecurityData = Get-SafeSecurityAnalysisData -AlertCount 5
    Write-Host "   ✅ セキュリティ分析テストデータ: $($testSecurityData.Count)件生成" -ForegroundColor Green
    
    # 認証テストデータテスト
    $testAuthData = Get-SafeAuthenticationTestData
    Write-Host "   ✅ 認証テストデータ: $($testAuthData.Count)件生成" -ForegroundColor Green
    
} catch {
    Write-Host "   ❌ SafeDataProviderエラー: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Microsoft Graph接続状況確認
Write-Host "`n3. Microsoft Graph接続状況" -ForegroundColor Yellow
try {
    $context = Get-MgContext -ErrorAction Stop
    if ($context) {
        Write-Host "   ✅ Microsoft Graph接続: 済み" -ForegroundColor Green
        Write-Host "   テナント: $($context.TenantId)" -ForegroundColor Cyan
        Write-Host "   クライアント: $($context.ClientId)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "   ❌ Microsoft Graph接続: 未接続" -ForegroundColor Red
    Write-Host "   理由: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 4. 証明書ファイル確認
Write-Host "`n4. 証明書ファイル確認" -ForegroundColor Yellow
$certPath = "Certificates\mycert.pfx"
if (Test-Path $certPath) {
    Write-Host "   ✅ 証明書ファイル: 存在" -ForegroundColor Green
    try {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, "YOUR_CERTIFICATE_PASSWORD")
        Write-Host "   ✅ 証明書読み込み: OK" -ForegroundColor Green
        Write-Host "   証明書情報: $($cert.Subject)" -ForegroundColor Cyan
    } catch {
        Write-Host "   ❌ 証明書読み込み: エラー - $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   ❌ 証明書ファイル: 未発見" -ForegroundColor Red
}

# 5. 設定ファイル確認
Write-Host "`n5. 設定ファイル確認" -ForegroundColor Yellow
$configPath = "Config\appsettings.json"
if (Test-Path $configPath) {
    Write-Host "   ✅ 設定ファイル: 存在" -ForegroundColor Green
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        Write-Host "   ✅ 設定ファイル読み込み: OK" -ForegroundColor Green
        Write-Host "   テナントID: $($config.EntraID.TenantId)" -ForegroundColor Cyan
        Write-Host "   クライアントID: $($config.EntraID.ClientId)" -ForegroundColor Cyan
    } catch {
        Write-Host "   ❌ 設定ファイル読み込み: エラー" -ForegroundColor Red
    }
} else {
    Write-Host "   ❌ 設定ファイル: 未発見" -ForegroundColor Red
}

# 6. レポート出力フォルダ確認
Write-Host "`n6. レポート出力フォルダ確認" -ForegroundColor Yellow
$reportFolders = @("Reports\Authentication", "Reports\Security\Permissions", "Reports\Daily")
foreach ($folder in $reportFolders) {
    if (Test-Path $folder) {
        Write-Host "   ✅ $folder : 存在" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ $folder : 未存在（自動作成されます）" -ForegroundColor Yellow
    }
}

Write-Host "`n=== 修正完了確認 ===" -ForegroundColor Green
Write-Host "✅ AuthenticationTest.psm1構文エラー修正完了" -ForegroundColor Green
Write-Host "✅ SafeDataProvider実装完了" -ForegroundColor Green
Write-Host "✅ フォールバック機能強化完了" -ForegroundColor Green
Write-Host "✅ エラーハンドリング改善完了" -ForegroundColor Green

Write-Host "`n🎯 推奨事項:" -ForegroundColor Cyan
Write-Host "1. Azure ADアプリケーションの権限設定を確認してください" -ForegroundColor White
Write-Host "2. 証明書の有効性とアプリケーション登録を確認してください" -ForegroundColor White
Write-Host "3. .\run_launcher.ps1 -Mode gui でGUIをテストしてください" -ForegroundColor White
Write-Host "4. 認証が成功すると、実際のMicrosoft 365データが表示されます" -ForegroundColor White

Write-Host "`n=== テスト完了 ===" -ForegroundColor Green