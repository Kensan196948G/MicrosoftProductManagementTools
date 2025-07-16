# ================================================================================
# Microsoft 365接続確認スクリプト
# Azure AD認証とMicrosoft Graph API接続をテスト
# ================================================================================

Write-Host "🔍 Microsoft 365接続状況を確認中..." -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Blue

# 1. 必要なモジュールの確認
Write-Host "📦 必要なモジュールを確認中..." -ForegroundColor Yellow

$requiredModules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users", "ExchangeOnlineManagement")
$missingModules = @()

foreach ($module in $requiredModules) {
    if (Get-Module -ListAvailable -Name $module) {
        Write-Host "  ✅ $module - インストール済み" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $module - 未インストール" -ForegroundColor Red
        $missingModules += $module
    }
}

if ($missingModules.Count -gt 0) {
    Write-Host "📥 不足しているモジュールをインストールします..." -ForegroundColor Yellow
    foreach ($module in $missingModules) {
        try {
            Install-Module $module -Scope CurrentUser -Force -AllowClobber
            Write-Host "  ✅ $module - インストール完了" -ForegroundColor Green
        } catch {
            Write-Host "  ❌ $module - インストール失敗: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# 2. 設定ファイルの確認
Write-Host "`n🔧 設定ファイルを確認中..." -ForegroundColor Yellow

$toolRoot = Split-Path $PSScriptRoot -Parent
$configPath = Join-Path $toolRoot "Config\appsettings.json"
$localConfigPath = Join-Path $toolRoot "Config\appsettings.local.json"

if (Test-Path $localConfigPath) {
    try {
        $config = Get-Content $localConfigPath | ConvertFrom-Json
        $tenantId = $config.EntraID.TenantId
        $clientId = $config.EntraID.ClientId
        $clientSecret = $config.EntraID.ClientSecret
        
        if ($tenantId -and $tenantId -ne "YOUR-TENANT-ID-HERE" -and 
            $clientId -and $clientId -ne "YOUR-CLIENT-ID-HERE" -and
            $clientSecret -and $clientSecret -ne "YOUR-CLIENT-SECRET-HERE") {
            Write-Host "  ✅ appsettings.local.json - 設定済み" -ForegroundColor Green
            Write-Host "    📋 テナントID: $($tenantId.Substring(0,8))..." -ForegroundColor White
            Write-Host "    📋 クライアントID: $($clientId.Substring(0,8))..." -ForegroundColor White
        } else {
            Write-Host "  ⚠️ appsettings.local.json - 設定が不完全です" -ForegroundColor Yellow
            Write-Host "    📝 Docs\Microsoft365認証設定ガイド.md を参照してください" -ForegroundColor Cyan
            return
        }
    } catch {
        Write-Host "  ❌ appsettings.local.json - 読み込みエラー: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
} else {
    Write-Host "  ❌ appsettings.local.json が見つかりません" -ForegroundColor Red
    Write-Host "    📝 Docs\Microsoft365認証設定ガイド.md を参照して設定してください" -ForegroundColor Cyan
    return
}

# 3. Microsoft Graph認証テスト
Write-Host "`n🔐 Microsoft Graph認証をテスト中..." -ForegroundColor Yellow

try {
    # 現在の接続状態を確認
    $context = Get-MgContext -ErrorAction SilentlyContinue
    if ($context) {
        Write-Host "  ✅ 既存の接続が見つかりました" -ForegroundColor Green
        Write-Host "    📋 テナント: $($context.TenantId)" -ForegroundColor White
        Write-Host "    📋 アカウント: $($context.Account)" -ForegroundColor White
    } else {
        Write-Host "  🔌 Microsoft Graphに接続中..." -ForegroundColor Cyan
        
        # クライアントシークレット認証
        $secureSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($clientId, $secureSecret)
        
        Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $credential -NoWelcome
        Write-Host "  ✅ Microsoft Graph認証成功" -ForegroundColor Green
    }
} catch {
    Write-Host "  ❌ Microsoft Graph認証失敗: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# 4. ユーザーデータ取得テスト
Write-Host "`n👥 ユーザーデータ取得をテスト中..." -ForegroundColor Yellow

try {
    Write-Host "  📊 ユーザー数を取得中..." -ForegroundColor Cyan
    $userCount = (Get-MgUser -Top 5 -Property Id,DisplayName,UserPrincipalName).Count
    Write-Host "  ✅ ユーザーデータ取得成功" -ForegroundColor Green
    Write-Host "    📋 テストユーザー数: $userCount 件 (最初の5件のみ)" -ForegroundColor White
    
    Write-Host "  📊 全ユーザー数を確認中..." -ForegroundColor Cyan
    $allUserCount = (Get-MgUser -ConsistencyLevel eventual -CountVariable userCount).Count
    Write-Host "  ✅ 全ユーザー数取得成功" -ForegroundColor Green
    Write-Host "    📋 総ユーザー数: $allUserCount 件" -ForegroundColor White
    
} catch {
    Write-Host "  ❌ ユーザーデータ取得失敗: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    💡 権限不足の可能性があります。管理者同意を確認してください。" -ForegroundColor Yellow
}

# 5. Exchange Online接続テスト（オプション）
Write-Host "`n📧 Exchange Online接続をテスト中..." -ForegroundColor Yellow

try {
    $exoSession = Get-PSSession | Where-Object { $_.ConfigurationName -eq "Microsoft.Exchange" }
    if ($exoSession) {
        Write-Host "  ✅ Exchange Online既存セッション確認" -ForegroundColor Green
    } else {
        Write-Host "  🔌 Exchange Onlineに接続中..." -ForegroundColor Cyan
        Connect-ExchangeOnline -AppId $clientId -CertificateThumbprint $config.ExchangeOnline.CertificateThumbprint -Organization $config.ExchangeOnline.Organization -ShowBanner:$false -ErrorAction Stop
        Write-Host "  ✅ Exchange Online接続成功" -ForegroundColor Green
    }
    
    $mailboxCount = (Get-Mailbox -ResultSize 5).Count
    Write-Host "  ✅ メールボックスデータ取得成功" -ForegroundColor Green
    Write-Host "    📋 テストメールボックス数: $mailboxCount 件 (最初の5件のみ)" -ForegroundColor White
    
} catch {
    Write-Host "  ⚠️ Exchange Online接続スキップ（証明書認証が必要）" -ForegroundColor Yellow
    Write-Host "    💡 Exchange Online機能を使用する場合は証明書認証を設定してください" -ForegroundColor Cyan
}

# 6. 結果サマリー
Write-Host "`n" + "=" * 60 -ForegroundColor Blue
Write-Host "🎯 Microsoft 365接続確認結果" -ForegroundColor Blue
Write-Host "=" * 60 -ForegroundColor Blue

$context = Get-MgContext -ErrorAction SilentlyContinue
if ($context) {
    Write-Host "✅ Microsoft Graph: 接続済み" -ForegroundColor Green
    Write-Host "✅ ユーザーデータ取得: 利用可能" -ForegroundColor Green
    Write-Host "📊 実ユーザーデータ取得が可能です！" -ForegroundColor Green
    Write-Host ""
    Write-Host "🚀 次のステップ:" -ForegroundColor Cyan
    Write-Host "  1. GUIで「📊 実データ日次」ボタンをクリック" -ForegroundColor White
    Write-Host "  2. または PowerShell で Get-DailyReportRealData -ForceRealData を実行" -ForegroundColor White
} else {
    Write-Host "❌ Microsoft Graph: 未接続" -ForegroundColor Red
    Write-Host "❌ 実ユーザーデータ取得: 利用不可" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 修正が必要です:" -ForegroundColor Yellow
    Write-Host "  1. Azure ADアプリ登録の確認" -ForegroundColor White
    Write-Host "  2. API権限と管理者同意の確認" -ForegroundColor White
    Write-Host "  3. appsettings.local.json の認証情報確認" -ForegroundColor White
}

Write-Host "=" * 60 -ForegroundColor Blue