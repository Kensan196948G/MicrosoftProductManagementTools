# ================================================================================
# 権限確認スクリプト
# check-permissions.ps1
# 現在の権限と必要な権限を詳細に確認
# ================================================================================

Write-Host "`n🔍 Microsoft 365 権限確認スクリプト" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor DarkGray

# 必要な権限の定義
$requiredGraphPermissions = @(
    "User.Read.All",
    "Group.Read.All", 
    "Directory.Read.All",
    "Directory.ReadWrite.All",
    "AuditLog.Read.All",
    "Reports.Read.All",
    "Files.Read.All",
    "Files.ReadWrite.All",
    "Sites.Read.All",
    "Sites.ReadWrite.All",
    "Mail.Read",
    "Mail.ReadWrite",
    "UserAuthenticationMethod.Read.All",
    "SecurityEvents.Read.All",
    "IdentityRiskEvent.Read.All",
    "Policy.Read.All"
)

$requiredExchangeRoles = @(
    "View-Only Recipients",
    "View-Only Configuration", 
    "View-Only Audit Logs",
    "Hygiene Management"
)

# モジュールパス設定
$rootPath = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $rootPath "Scripts\Common"

# モジュール読み込み
Import-Module "$modulePath\Authentication.psm1" -Force -ErrorAction SilentlyContinue

Write-Host "`n1️⃣ 現在の接続状態" -ForegroundColor Yellow

# 認証状態確認
$authStatus = Test-AuthenticationStatus -RequiredServices @("MicrosoftGraph", "ExchangeOnline")

if ($authStatus.IsValid) {
    Write-Host "✅ 認証済み" -ForegroundColor Green
    Write-Host "   接続サービス: $($authStatus.ConnectedServices -join ', ')" -ForegroundColor Gray
}
else {
    Write-Host "⚠️  未認証" -ForegroundColor Yellow
    Write-Host "   不足サービス: $($authStatus.MissingServices -join ', ')" -ForegroundColor Gray
    
    Write-Host "`n認証を試行しています..." -ForegroundColor Cyan
    
    # 設定読み込み
    $configPath = Join-Path $rootPath "Config\appsettings.local.json"
    if (-not (Test-Path $configPath)) {
        $configPath = Join-Path $rootPath "Config\appsettings.json"
    }
    
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $connectResult = Connect-ToMicrosoft365 -Config $config -Services @("MicrosoftGraph", "ExchangeOnline")
    
    if (-not $connectResult.Success) {
        Write-Host "❌ 認証失敗: $($connectResult.Errors -join ', ')" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n2️⃣ Microsoft Graph 権限分析" -ForegroundColor Yellow

try {
    # 現在のコンテキストを取得
    $context = Get-MgContext
    
    if ($context) {
        Write-Host "`n現在の権限:" -ForegroundColor Cyan
        $currentScopes = $context.Scopes -split ' ' | Where-Object { $_ } | Sort-Object
        
        foreach ($scope in $currentScopes) {
            Write-Host "  ✓ $scope" -ForegroundColor Green
        }
        
        Write-Host "`n必要な権限の確認:" -ForegroundColor Cyan
        $missingPermissions = @()
        
        foreach ($permission in $requiredGraphPermissions) {
            if ($currentScopes -contains $permission -or $currentScopes -contains "$permission.All") {
                Write-Host "  ✅ $permission - 付与済み" -ForegroundColor Green
            }
            else {
                # ReadWrite権限がある場合、Read権限は暗黙的に含まれる
                $readPermission = $permission -replace '\.ReadWrite', '.Read'
                $writePermission = $permission -replace '\.Read', '.ReadWrite'
                
                if ($permission -match '\.Read' -and $currentScopes -contains $writePermission) {
                    Write-Host "  ✅ $permission - 付与済み (ReadWrite権限により)" -ForegroundColor Green
                }
                else {
                    Write-Host "  ❌ $permission - 不足" -ForegroundColor Red
                    $missingPermissions += $permission
                }
            }
        }
        
        if ($missingPermissions.Count -gt 0) {
            Write-Host "`n⚠️  不足している権限:" -ForegroundColor Yellow
            foreach ($missing in $missingPermissions) {
                Write-Host "  - $missing" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "`n✅ すべての必要な権限が付与されています" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "❌ Microsoft Graph 権限確認エラー: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n3️⃣ Exchange Online 権限分析" -ForegroundColor Yellow

try {
    if (Test-ExchangeOnlineConnection) {
        Write-Host "✅ Exchange Online 接続確認" -ForegroundColor Green
        
        # 管理役割の確認（可能な場合）
        try {
            $currentUser = Get-ConnectionInformation | Select-Object -First 1
            Write-Host "   接続ユーザー: $($currentUser.UserPrincipalName)" -ForegroundColor Gray
            Write-Host "   接続タイプ: $($currentUser.ConnectionMethod)" -ForegroundColor Gray
        }
        catch {
            Write-Host "   役割情報の取得に失敗しました（権限不足の可能性）" -ForegroundColor Yellow
        }
        
        Write-Host "`n必要な Exchange Online 役割:" -ForegroundColor Cyan
        foreach ($role in $requiredExchangeRoles) {
            Write-Host "  - $role" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "⚠️  Exchange Online 未接続" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "❌ Exchange Online 権限確認エラー: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n4️⃣ 権限による機能への影響" -ForegroundColor Yellow

$featureImpact = @{
    "User.Read.All" = @(
        "Entra ID ユーザー一覧",
        "ユーザー詳細情報の取得",
        "ユーザーアクティビティレポート"
    )
    "Group.Read.All" = @(
        "グループメンバーシップ確認",
        "グループ管理レポート",
        "Teams チーム一覧"
    )
    "Directory.Read.All" = @(
        "組織構造の取得",
        "管理者役割の確認",
        "ディレクトリ オブジェクトの読み取り"
    )
    "Files.Read.All" = @(
        "OneDrive 使用状況分析",
        "SharePoint ファイル情報",
        "ファイル共有レポート"
    )
}

Write-Host "`n不足している権限による影響:" -ForegroundColor Cyan
foreach ($permission in $missingPermissions) {
    if ($featureImpact.ContainsKey($permission)) {
        Write-Host "`n  ❌ $permission の不足により以下の機能が制限されます:" -ForegroundColor Red
        foreach ($feature in $featureImpact[$permission]) {
            Write-Host "     - $feature" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n5️⃣ 推奨アクション" -ForegroundColor Yellow

if ($missingPermissions.Count -gt 0) {
    Write-Host @"

不足している権限を追加するには:

1. Azure Portal (https://portal.azure.com) にログイン
2. Azure Active Directory → アプリの登録
3. ClientId: 22e5d6e4-805f-4516-af09-ff09c7c224c4 を検索
4. API のアクセス許可 → アクセス許可の追加
5. Microsoft Graph → アプリケーションの許可
6. 不足している権限を追加
7. 管理者の同意を付与

詳細は以下のドキュメントを参照:
Docs\Azure-AD-権限設定ガイド.md

"@ -ForegroundColor Cyan
}
else {
    Write-Host "`n✅ すべての必要な権限が正しく設定されています" -ForegroundColor Green
}

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor DarkGray
Write-Host "権限確認完了" -ForegroundColor Cyan