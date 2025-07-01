# Microsoft Graph認証で各機能をテスト
Import-Module Microsoft.Graph.Authentication -Force

try {
    Write-Host "=== Microsoft Graph 機能テスト ===" -ForegroundColor Cyan
    
    # ClientSecret認証
    $clientId = "22e5d6e4-805f-4516-af09-ff09c7c224c4"
    $tenantId = "a7232f7a-a9e5-4f71-9372-dc8b1c6645ea"
    $clientSecret = "YOUR_CLIENT_SECRET"
    
    Write-Host "Microsoft Graphに接続中..." -ForegroundColor Yellow
    $secureSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($clientId, $secureSecret)
    Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $credential -NoWelcome
    
    $context = Get-MgContext
    Write-Host "✅ 認証成功: $($context.AuthType)" -ForegroundColor Green
    Write-Host ""
    
    # 1. ユーザー取得テスト
    Write-Host "1. ユーザー取得テスト" -ForegroundColor Yellow
    try {
        $users = Get-MgUser -Top 5 -Property DisplayName,UserPrincipalName,Department,JobTitle
        Write-Host "   ✅ 成功: $($users.Count) ユーザー取得" -ForegroundColor Green
        foreach ($user in $users) {
            Write-Host "     - $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   ❌ エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
    
    # 2. グループ取得テスト
    Write-Host "2. グループ取得テスト" -ForegroundColor Yellow
    try {
        $groups = Get-MgGroup -Top 5 -Property DisplayName,GroupTypes,SecurityEnabled
        Write-Host "   ✅ 成功: $($groups.Count) グループ取得" -ForegroundColor Green
        foreach ($group in $groups) {
            Write-Host "     - $($group.DisplayName) (Security: $($group.SecurityEnabled))" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   ❌ エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
    
    # 3. ディレクトリ情報取得テスト
    Write-Host "3. ディレクトリ情報取得テスト" -ForegroundColor Yellow
    try {
        $organization = Get-MgOrganization
        Write-Host "   ✅ 成功: 組織情報取得" -ForegroundColor Green
        Write-Host "     - 組織名: $($organization.DisplayName)" -ForegroundColor Gray
        Write-Host "     - ドメイン: $($organization.VerifiedDomains[0].Name)" -ForegroundColor Gray
    } catch {
        Write-Host "   ❌ エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
    
    # 4. OneDrive/SharePointテスト
    Write-Host "4. OneDrive/SharePointテスト" -ForegroundColor Yellow
    try {
        $sites = Get-MgSite -Top 3
        Write-Host "   ✅ 成功: $($sites.Count) サイト取得" -ForegroundColor Green
        foreach ($site in $sites) {
            Write-Host "     - $($site.DisplayName) ($($site.WebUrl))" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   ❌ エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
    
    # 5. Teamsテスト
    Write-Host "5. Microsoft Teamsテスト" -ForegroundColor Yellow
    try {
        # Teams モジュールが必要な場合があります
        $teams = Get-MgTeam -Top 3
        Write-Host "   ✅ 成功: $($teams.Count) チーム取得" -ForegroundColor Green
        foreach ($team in $teams) {
            Write-Host "     - $($team.DisplayName)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "   ❌ エラー: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "     注意: Teams機能には追加の権限が必要な場合があります" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # 6. セキュリティレポートテスト
    Write-Host "6. セキュリティレポートテスト" -ForegroundColor Yellow
    try {
        # セキュリティレポートの取得を試行
        $securityScores = Get-MgSecuritySecureScore -Top 1
        Write-Host "   ✅ 成功: セキュリティスコア取得" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ エラー: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "     注意: セキュリティレポートには特定の権限が必要です" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # 7. 監査ログテスト
    Write-Host "7. 監査ログテスト" -ForegroundColor Yellow
    try {
        $auditLogs = Get-MgAuditLogSignIn -Top 1
        Write-Host "   ✅ 成功: 監査ログ取得" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ エラー: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "     注意: 監査ログには特定の権限が必要です" -ForegroundColor Yellow
    }
    Write-Host ""
    
    Write-Host "=== テスト完了 ===" -ForegroundColor Green
    
    # 権限確認
    Write-Host "現在の権限スコープ:" -ForegroundColor Cyan
    $context.Scopes | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    
} catch {
    Write-Host "❌ 認証エラー: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # 接続をクリーンアップ
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
    } catch {
        # エラーは無視
    }
}