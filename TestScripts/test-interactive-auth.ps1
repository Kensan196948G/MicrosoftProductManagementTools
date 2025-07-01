# Interactive認証テスト（実運用データ取得のため）
try {
    Write-Host "Microsoft Graph Interactive認証テストを開始します..."
    
    # Microsoft Graph モジュール確認・読み込み
    if (-not (Get-Module -Name Microsoft.Graph -ListAvailable)) {
        throw "Microsoft.Graph モジュールが利用できません"
    }
    
    Import-Module Microsoft.Graph.Authentication -Force
    Import-Module Microsoft.Graph.Users -Force
    Import-Module Microsoft.Graph.Reports -Force
    
    # 設定読み込み
    $configPath = "Config/appsettings.json"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        Write-Host "設定ファイル読み込み成功"
    } else {
        throw "設定ファイルが見つかりません: $configPath"
    }
    
    # Interactive認証でテスト
    Write-Host "Interactive認証でMicrosoft Graph に接続中..."
    
    $connectParams = @{
        TenantId = $config.EntraID.TenantId
        ClientId = $config.EntraID.ClientId
        Scopes = @(
            "User.Read.All",
            "Group.Read.All",
            "Directory.Read.All",
            "Reports.Read.All",
            "AuditLog.Read.All"
        )
        NoWelcome = $true
    }
    
    # Interactive接続実行
    Connect-MgGraph @connectParams
    
    # 接続テスト
    $context = Get-MgContext
    if ($context) {
        Write-Host "✅ Microsoft Graph 接続成功!" -ForegroundColor Green
        Write-Host "テナント ID: $($context.TenantId)"
        Write-Host "認証タイプ: $($context.AuthType)"
        Write-Host "スコープ数: $($context.Scopes.Count)"
        
        # 実データ取得テスト
        try {
            Write-Host "`n📊 実運用データ取得テスト中..."
            
            # ユーザー数
            $users = Get-MgUser -Top 10 -Property Id,DisplayName,UserPrincipalName,CreatedDateTime
            Write-Host "✅ ユーザー取得成功: $($users.Count)件" -ForegroundColor Green
            
            # グループ数
            $groups = Get-MgGroup -Top 10 -Property Id,DisplayName,CreatedDateTime
            Write-Host "✅ グループ取得成功: $($groups.Count)件" -ForegroundColor Green
            
            # アプリケーション登録
            $apps = Get-MgApplication -Top 10 -Property Id,DisplayName,CreatedDateTime
            Write-Host "✅ アプリケーション取得成功: $($apps.Count)件" -ForegroundColor Green
            
            Write-Host "`n🎉 実運用データの取得に成功しました！" -ForegroundColor Green
            Write-Host "これで実際のMicrosoft 365データを使用したレポート生成が可能です。" -ForegroundColor Green
            
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