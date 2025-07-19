# Microsoft Graph証明書ベース認証テスト
Import-Module Microsoft.Graph.Authentication -Force

Write-Host "=== Microsoft Graph 証明書ベース認証テスト ===" -ForegroundColor Cyan
Write-Host ""

try {
    # 証明書ベース認証設定
    $clientId = "22e5d6e4-805f-4516-af09-ff09c7c224c4"
    $tenantId = "a7232f7a-a9e5-4f71-9372-dc8b1c6645ea"
    $certThumbprint = "94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6"
    $certPath = "Certificates/mycert.pfx"
    $certPassword = "armageddon2002"
    
    Write-Host "🔑 Microsoft Graph証明書ベース認証開始..." -ForegroundColor Yellow
    
    # 証明書読み込み
    if (Test-Path $certPath) {
        Write-Host "✅ 証明書ファイル発見: $certPath" -ForegroundColor Green
        $securePassword = ConvertTo-SecureString -String $certPassword -AsPlainText -Force
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $securePassword)
        
        # 証明書ベース認証でConnect-MgGraph
        $connectParams = @{
            ClientId = $clientId
            TenantId = $tenantId
            Certificate = $cert
            NoWelcome = $true
        }
        
        Write-Host "🔧 Connect-MgGraph実行中..." -ForegroundColor Yellow
        Connect-MgGraph @connectParams
        
        Write-Host "✅ Microsoft Graph証明書ベース認証成功" -ForegroundColor Green
        
        # 認証確認
        $context = Get-MgContext
        Write-Host "認証タイプ: $($context.AuthType)" -ForegroundColor Gray
        Write-Host "テナント: $($context.TenantId)" -ForegroundColor Gray
        Write-Host ""
        
        # API テスト
        Write-Host "🧪 API接続テスト..." -ForegroundColor Yellow
        $users = Get-MgUser -Top 3 -Property DisplayName,UserPrincipalName
        Write-Host "✅ ユーザー取得成功: $($users.Count) 件" -ForegroundColor Green
        foreach ($user in $users) {
            Write-Host "  - $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Gray
        }
        
    } else {
        Write-Host "❌ 証明書ファイルが見つかりません: $certPath" -ForegroundColor Red
        
        # フォールバック: 証明書拇印による認証
        Write-Host "🔄 証明書拇印による認証を試行..." -ForegroundColor Yellow
        $connectParams = @{
            ClientId = $clientId
            TenantId = $tenantId
            CertificateThumbprint = $certThumbprint
            NoWelcome = $true
        }
        Connect-MgGraph @connectParams
        
        Write-Host "✅ Microsoft Graph証明書拇印認証成功" -ForegroundColor Green
        
        # 認証確認
        $context = Get-MgContext
        Write-Host "認証タイプ: $($context.AuthType)" -ForegroundColor Gray
        Write-Host "テナント: $($context.TenantId)" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "❌ 認証エラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "エラータイプ: $($_.Exception.GetType().FullName)" -ForegroundColor Yellow
} finally {
    # 接続をクリーンアップ
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Host "🧹 認証セッションをクリーンアップしました" -ForegroundColor Gray
    } catch {
        # エラーは無視
    }
}

Write-Host ""
Write-Host "=== 証明書ベース認証テスト完了 ===" -ForegroundColor Green