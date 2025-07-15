# Microsoft Graph認証テスト
Import-Module ./Scripts/Common/Logging.psm1 -Force
Import-Module ./Scripts/Common/ErrorHandling.psm1 -Force
Import-Module ./Scripts/Common/Authentication.psm1 -Force

try {
    Write-Host "設定ファイルを読み込み中..." -ForegroundColor Yellow
    
    # ローカル設定ファイルを優先的に読み込み
    $localConfigPath = "./Config/appsettings.local.json"
    $baseConfigPath = "./Config/appsettings.json"
    
    if (Test-Path $localConfigPath) {
        Write-Host "ローカル設定ファイルを使用: $localConfigPath" -ForegroundColor Green
        $configText = Get-Content $localConfigPath -Raw
        $config = $configText | ConvertFrom-Json
    }
    elseif (Test-Path $baseConfigPath) {
        Write-Host "ベース設定ファイルを使用: $baseConfigPath" -ForegroundColor Yellow
        $configText = Get-Content $baseConfigPath -Raw
        $config = $configText | ConvertFrom-Json
        
        # プレースホルダーチェック
        if ($config.EntraID.ClientId -like "*YOUR-*-HERE*" -or $config.EntraID.TenantId -like "*YOUR-*-HERE*") {
            Write-Host "⚠️  設定ファイルにプレースホルダーが含まれています" -ForegroundColor Yellow
            Write-Host "💡 実際の認証情報を Config/appsettings.local.json に設定してください" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "例: Config/appsettings.local.json" -ForegroundColor White
            Write-Host @"
{
  "EntraID": {
    "TenantId": "your-actual-tenant-id",
    "ClientId": "your-actual-client-id",
    "ClientSecret": "your-actual-client-secret"
  },
  "ExchangeOnline": {
    "AppId": "your-actual-app-id",
    "CertificateThumbprint": "your-actual-certificate-thumbprint"
  }
}
"@ -ForegroundColor Gray
            throw "設定ファイルの認証情報が未設定です"
        }
    }
    else {
        throw "設定ファイルが見つかりません: $baseConfigPath または $localConfigPath"
    }
    
    Write-Host "ClientId: $($config.EntraID.ClientId)" -ForegroundColor Green
    Write-Host "TenantId: $($config.EntraID.TenantId)" -ForegroundColor Green
    Write-Host "ClientSecret設定: $($config.EntraID.ClientSecret -ne '')" -ForegroundColor Green
    
    Write-Host "Microsoft Graph認証テスト開始..." -ForegroundColor Yellow
    $result = Connect-MicrosoftGraphService -Config $config
    
    if ($result) {
        Write-Host "認証成功!" -ForegroundColor Green
        
        # 接続確認
        $context = Get-MgContext
        if ($context) {
            Write-Host "テナントID: $($context.TenantId)" -ForegroundColor Green
            Write-Host "クライアントID: $($context.ClientId)" -ForegroundColor Green
            Write-Host "スコープ: $($context.Scopes -join ', ')" -ForegroundColor Green
        }
        
        # 簡単なAPI呼び出しテスト
        Write-Host "API呼び出しテスト中..." -ForegroundColor Yellow
        $user = Get-MgUser -Top 1
        if ($user) {
            Write-Host "API呼び出し成功: $($user.Count) ユーザー取得" -ForegroundColor Green
        }
    }
    else {
        Write-Host "認証失敗" -ForegroundColor Red
    }
}
catch {
    Write-Host "エラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "詳細: $($_.Exception.InnerException.Message)" -ForegroundColor Red
}