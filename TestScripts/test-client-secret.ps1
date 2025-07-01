# Microsoft Graph ClientSecret認証テスト
Import-Module Microsoft.Graph.Authentication -Force

try {
    Write-Host "ClientSecret認証テスト開始..." -ForegroundColor Yellow
    
    $clientId = "22e5d6e4-805f-4516-af09-ff09c7c224c4"
    $tenantId = "a7232f7a-a9e5-4f71-9372-dc8b1c6645ea"
    $clientSecret = "ULG8Q~u2zTYsHLPQJak9yxh8obxZa4erSgGezaWZ"
    
    Write-Host "認証情報:" -ForegroundColor Green
    Write-Host "  ClientId: $clientId"
    Write-Host "  TenantId: $tenantId"
    Write-Host "  ClientSecret: $(if($clientSecret) {'設定済み'} else {'未設定'})"
    
    # 既存接続をクリア
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Host "既存接続をクリアしました" -ForegroundColor Yellow
    } catch {
        # エラーは無視
    }
    
    # ClientSecret認証
    $secureSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($clientId, $secureSecret)
    
    Write-Host "Microsoft Graphに接続中..." -ForegroundColor Yellow
    Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $credential -NoWelcome
    
    # 接続確認
    $context = Get-MgContext
    if ($context) {
        Write-Host "接続成功!" -ForegroundColor Green
        Write-Host "  テナントID: $($context.TenantId)" -ForegroundColor Green
        Write-Host "  クライアントID: $($context.ClientId)" -ForegroundColor Green
        Write-Host "  認証タイプ: $($context.AuthType)" -ForegroundColor Green
        
        # 基本的なAPI呼び出しテスト
        Write-Host "API呼び出しテスト中..." -ForegroundColor Yellow
        try {
            $users = Get-MgUser -Top 5 -Property DisplayName,UserPrincipalName
            Write-Host "ユーザー取得成功: $($users.Count) 件" -ForegroundColor Green
            foreach ($user in $users) {
                Write-Host "  - $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Cyan
            }
        } catch {
            Write-Host "API呼び出しエラー: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "接続失敗: コンテキストが取得できません" -ForegroundColor Red
    }
    
} catch {
    Write-Host "認証エラー: $($_.Exception.Message)" -ForegroundColor Red
    
    # エラーの詳細分析
    $errorMessage = $_.Exception.Message
    if ($errorMessage -match "AADSTS70011|invalid_client") {
        Write-Host "診断: ClientIdまたはClientSecretが無効です" -ForegroundColor Red
    } elseif ($errorMessage -match "AADSTS50034") {
        Write-Host "診断: テナントIDが無効です" -ForegroundColor Red
    } elseif ($errorMessage -match "AADSTS65001") {
        Write-Host "診断: アプリケーションに管理者の同意が必要です" -ForegroundColor Red
    } elseif ($errorMessage -match "AADSTS7000215") {
        Write-Host "診断: ClientSecretが無効または期限切れです" -ForegroundColor Red
    }
}