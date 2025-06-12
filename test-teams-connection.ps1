# ================================================================================
# test-teams-connection.ps1
# Microsoft Graph Teams接続テストスクリプト
# ================================================================================

Write-Host "📋 Microsoft Graph Teams接続テストを開始します" -ForegroundColor Cyan

try {
    # 設定ファイル読み込み
    $configPath = Join-Path $PWD "Config\appsettings.json"
    if (-not (Test-Path $configPath)) {
        throw "設定ファイルが見つかりません: $configPath"
    }
    
    $config = Get-Content $configPath | ConvertFrom-Json
    $graphConfig = $config.EntraID
    
    Write-Host "🔧 設定情報:" -ForegroundColor Yellow
    Write-Host "   TenantId: $($graphConfig.TenantId)" -ForegroundColor Gray
    Write-Host "   ClientId: $($graphConfig.ClientId)" -ForegroundColor Gray
    Write-Host "   証明書パス: $($graphConfig.CertificatePath)" -ForegroundColor Gray
    
    # 証明書確認
    $fullCertPath = if ([System.IO.Path]::IsPathRooted($graphConfig.CertificatePath)) {
        $graphConfig.CertificatePath
    } else {
        Join-Path $PWD $graphConfig.CertificatePath
    }
    
    Write-Host "📜 証明書確認中..." -ForegroundColor Cyan
    if (-not (Test-Path $fullCertPath)) {
        throw "証明書ファイルが見つかりません: $fullCertPath"
    }
    Write-Host "   ✅ 証明書ファイル存在確認: $fullCertPath" -ForegroundColor Green
    
    # 証明書読み込み
    try {
        $certPassword = ConvertTo-SecureString $graphConfig.CertificatePassword -AsPlainText -Force
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($fullCertPath, $certPassword)
        Write-Host "   ✅ 証明書読み込み成功" -ForegroundColor Green
        Write-Host "   証明書サブジェクト: $($cert.Subject)" -ForegroundColor Gray
        Write-Host "   証明書有効期限: $($cert.NotAfter)" -ForegroundColor Gray
    }
    catch {
        throw "証明書読み込みエラー: $($_.Exception.Message)"
    }
    
    # Microsoft Graph接続
    Write-Host "🔌 Microsoft Graph接続中..." -ForegroundColor Cyan
    try {
        # 認証方式の選択
        if ($graphConfig.ClientSecret -and $graphConfig.ClientSecret.Trim() -ne "") {
            Write-Host "   ClientSecret認証を使用..." -ForegroundColor Gray
            $secureSecret = ConvertTo-SecureString $graphConfig.ClientSecret -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($graphConfig.ClientId, $secureSecret)
            Connect-MgGraph -TenantId $graphConfig.TenantId -ClientSecretCredential $credential -NoWelcome
        } else {
            Write-Host "   証明書認証を使用..." -ForegroundColor Gray
            Connect-MgGraph -ClientId $graphConfig.ClientId -Certificate $cert -TenantId $graphConfig.TenantId -NoWelcome
        }
        
        $context = Get-MgContext
        if ($context) {
            Write-Host "   ✅ Microsoft Graph接続成功!" -ForegroundColor Green
            Write-Host "   テナント: $($context.TenantId)" -ForegroundColor Green
            Write-Host "   アプリケーション: $($context.ClientId)" -ForegroundColor Green
            Write-Host "   認証方式: $($context.AuthType)" -ForegroundColor Green
            Write-Host "   スコープ: $($context.Scopes -join ', ')" -ForegroundColor Green
        } else {
            throw "接続後にコンテキストが取得できませんでした"
        }
    }
    catch {
        throw "Microsoft Graph接続エラー: $($_.Exception.Message)"
    }
    
    # Teams情報取得テスト
    Write-Host "📋 Teams情報取得テスト中..." -ForegroundColor Cyan
    try {
        Write-Host "   チーム一覧取得中..." -ForegroundColor Gray
        $teams = Get-MgTeam -All -Property Id,DisplayName,Description,Visibility,IsArchived,CreatedDateTime -ErrorAction Stop
        Write-Host "   ✅ チーム取得成功: $($teams.Count)個のチーム" -ForegroundColor Green
        
        if ($teams.Count -gt 0) {
            Write-Host "   📊 チーム情報例:" -ForegroundColor Yellow
            $sampleTeam = $teams[0]
            Write-Host "     チーム名: $($sampleTeam.DisplayName)" -ForegroundColor Gray
            Write-Host "     ID: $($sampleTeam.Id)" -ForegroundColor Gray
            Write-Host "     プライバシー: $($sampleTeam.Visibility)" -ForegroundColor Gray
            Write-Host "     作成日: $($sampleTeam.CreatedDateTime)" -ForegroundColor Gray
            
            # メンバー情報取得テスト
            Write-Host "   チームメンバー情報取得テスト中..." -ForegroundColor Gray
            try {
                $members = Get-MgTeamMember -TeamId $sampleTeam.Id -ErrorAction Stop
                Write-Host "   ✅ メンバー取得成功: $($members.Count)名" -ForegroundColor Green
                
                $owners = $members | Where-Object { $_.Roles -contains "owner" }
                $guests = $members | Where-Object { $_.AdditionalProperties.userType -eq "Guest" }
                Write-Host "     オーナー: $($owners.Count)名" -ForegroundColor Gray
                Write-Host "     ゲスト: $($guests.Count)名" -ForegroundColor Gray
            }
            catch {
                Write-Host "   ⚠️ メンバー情報取得制限: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            
            # チャンネル情報取得テスト
            Write-Host "   チャンネル情報取得テスト中..." -ForegroundColor Gray
            try {
                $channels = Get-MgTeamChannel -TeamId $sampleTeam.Id -ErrorAction Stop
                Write-Host "   ✅ チャンネル取得成功: $($channels.Count)個" -ForegroundColor Green
            }
            catch {
                Write-Host "   ⚠️ チャンネル情報取得制限: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
    }
    catch {
        Write-Host "   ❌ Teams情報取得エラー: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   権限または設定に問題がある可能性があります" -ForegroundColor Red
    }
    
    # ユーザー情報取得テスト
    Write-Host "👤 ユーザー情報取得テスト中..." -ForegroundColor Cyan
    try {
        $users = Get-MgUser -All -Property Id,UserPrincipalName,DisplayName,AccountEnabled -Top 5 -ErrorAction Stop
        Write-Host "   ✅ ユーザー取得成功: $($users.Count)名（サンプル）" -ForegroundColor Green
    }
    catch {
        Write-Host "   ❌ ユーザー情報取得エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "🎉 Microsoft Graph Teams接続テスト完了" -ForegroundColor Green
    Write-Host ""
    
    if ($teams.Count -gt 0) {
        Write-Host "✅ 実際のTeamsデータ取得が可能です！" -ForegroundColor Green
        Write-Host "   TeamsConfigurationAnalysis.ps1で実データが使用されます" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Teamsが存在しないか、アクセス権限に制限があります" -ForegroundColor Yellow
        Write-Host "   テストデータが使用される可能性があります" -ForegroundColor Yellow
    }
    
}
catch {
    Write-Host ""
    Write-Host "❌ 接続テストでエラーが発生しました" -ForegroundColor Red
    Write-Host "エラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 トラブルシューティング:" -ForegroundColor Yellow
    Write-Host "1. 証明書ファイルの存在と有効性を確認" -ForegroundColor Gray
    Write-Host "2. Azure ADアプリの権限設定を確認" -ForegroundColor Gray
    Write-Host "3. 管理者の同意が必要な権限があるか確認" -ForegroundColor Gray
    Write-Host "4. テナントIDとクライアントIDが正しいか確認" -ForegroundColor Gray
}
finally {
    # 接続を切断
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Host "🔌 Microsoft Graph接続を切断しました" -ForegroundColor Gray
    } catch {
        # 無視
    }
}