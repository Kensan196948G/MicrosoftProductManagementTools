# Exchange Online接続と会議室作成テスト

Write-Host "🔐 Exchange Online証明書ベース認証接続中..." -ForegroundColor Cyan

try {
    # 設定ファイル読み込み
    $config = Get-Content "Config\appsettings.json" | ConvertFrom-Json
    $exchangeConfig = $config.ExchangeOnline
    
    # 証明書ファイルから証明書を読み込み
    $certPath = $exchangeConfig.CertificatePath
    $certPassword = ConvertTo-SecureString $exchangeConfig.CertificatePassword -AsPlainText -Force
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $certPassword)
    
    # 証明書ベース認証で接続
    Connect-ExchangeOnline -AppId $exchangeConfig.AppId -Certificate $cert -Organization $exchangeConfig.Organization -ShowBanner:$false
    
    Write-Host "✅ Exchange Online接続成功" -ForegroundColor Green
    
    # 現在の権限確認
    Write-Host "📋 現在の権限を確認中..." -ForegroundColor Yellow
    
    # 読み取りテスト
    $existingRooms = Get-EXOMailbox -RecipientTypeDetails RoomMailbox -ResultSize 10
    Write-Host "✅ 既存会議室: $($existingRooms.Count)件" -ForegroundColor Green
    
    # 会議室作成テスト
    Write-Host "🏢 テスト会議室作成中..." -ForegroundColor Yellow
    
    $testRoomName = "テスト会議室_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $testRoomEmail = "test-room-$(Get-Date -Format 'yyyyMMddHHmmss')@miraiconst.onmicrosoft.com"
    
    $newRoom = New-Mailbox -Name $testRoomName -Room -PrimarySmtpAddress $testRoomEmail -ResourceCapacity 8
    
    if ($newRoom) {
        Write-Host "✅ 会議室作成成功!" -ForegroundColor Green
        Write-Host "   名前: $($newRoom.DisplayName)" -ForegroundColor Cyan
        Write-Host "   メール: $($newRoom.PrimarySmtpAddress)" -ForegroundColor Cyan
        
        # 会議室設定
        Write-Host "⚙️ 会議室の詳細設定中..." -ForegroundColor Yellow
        Set-CalendarProcessing -Identity $newRoom.PrimarySmtpAddress -AutomateProcessing AutoAccept -BookingWindowInDays 180 -MaximumDurationInMinutes 480
        
        Write-Host "✅ 会議室設定完了" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎉 会議室が正常に作成されました！" -ForegroundColor Green
        Write-Host "📊 会議室利用状況監査を再実行してください" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "❌ エラー: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -like "*Access*denied*" -or $_.Exception.Message -like "*権限*") {
        Write-Host ""
        Write-Host "🔧 権限不足の可能性があります" -ForegroundColor Yellow
        Write-Host "💡 対処方法:" -ForegroundColor Cyan
        Write-Host "   1. Azure AD管理センターでアプリ登録を確認" -ForegroundColor Gray
        Write-Host "   2. Exchange.ManageAsApp権限を追加" -ForegroundColor Gray
        Write-Host "   3. 管理者の同意を実行" -ForegroundColor Gray
    } elseif ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*既に存在*") {
        Write-Host "⚠️ 同名の会議室が既に存在します" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "🔍 詳細エラー情報:" -ForegroundColor Yellow
        Write-Host "   $($_.Exception.GetType().FullName)" -ForegroundColor Gray
        Write-Host "   $($_.ScriptStackTrace)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "📋 現在のアプリ設定:" -ForegroundColor Cyan
Write-Host "   AppId: $($exchangeConfig.AppId)" -ForegroundColor Gray
Write-Host "   証明書: $($exchangeConfig.CertificateThumbprint)" -ForegroundColor Gray
Write-Host "   組織: $($exchangeConfig.Organization)" -ForegroundColor Gray