# Microsoft Graph認証修復テスト
Import-Module "./Scripts/Common/Logging.psm1" -Force
Import-Module "./Scripts/Common/Authentication.psm1" -Force

try {
    Write-Host "Microsoft Graph認証テストを開始します..."
    
    # 設定読み込み
    $configPath = "Config/appsettings.json"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        Write-Host "設定ファイル読み込み成功"
    } else {
        throw "設定ファイルが見つかりません: $configPath"
    }
    
    # 証明書ファイル確認
    $certPath = "Certificates/mycert.pfx"
    if (Test-Path $certPath) {
        Write-Host "証明書ファイル確認成功: $certPath"
    } else {
        throw "証明書ファイルが見つかりません: $certPath"
    }
    
    # Microsoft Graph モジュール確認
    if (Get-Module -Name Microsoft.Graph -ListAvailable) {
        Write-Host "Microsoft.Graph モジュール確認成功"
    } else {
        throw "Microsoft.Graph モジュールが利用できません"
    }
    
    # 手動認証テスト
    Write-Host "Microsoft Graph に証明書認証で接続中..."
    
    # 証明書読み込み
    $securePassword = ConvertTo-SecureString $config.EntraID.CertificatePassword -AsPlainText -Force
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $securePassword)
    
    # 接続パラメータ
    $connectParams = @{
        TenantId = $config.EntraID.TenantId
        ClientId = $config.EntraID.ClientId
        Certificate = $cert
        NoWelcome = $true
    }
    
    # 接続実行
    Connect-MgGraph @connectParams
    
    # 接続テスト
    $context = Get-MgContext
    if ($context) {
        Write-Host "✅ Microsoft Graph 接続成功!" -ForegroundColor Green
        Write-Host "テナント ID: $($context.TenantId)"
        Write-Host "認証タイプ: $($context.AuthType)"
        Write-Host "スコープ数: $($context.Scopes.Count)"
        
        # 簡単なAPI呼び出しテスト
        try {
            $testUser = Get-MgUser -Top 1 -Property Id,DisplayName
            Write-Host "✅ API呼び出しテスト成功" -ForegroundColor Green
            Write-Host "テストユーザー: $($testUser.DisplayName)"
        } catch {
            Write-Host "⚠️ API呼び出しに失敗: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Microsoft Graph 接続に失敗" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ 認証テストエラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "詳細: $($_.Exception.ToString())" -ForegroundColor Red
}