# 会議室作成テストスクリプト

Write-Host "🏢 Exchange Online 会議室作成権限テスト" -ForegroundColor Cyan
Write-Host ""

# 現在の接続状況確認
$sessions = Get-PSSession | Where-Object { $_.ComputerName -like "*outlook.office365.com*" -and $_.State -eq "Opened" }
if ($sessions) {
    Write-Host "✅ Exchange Onlineに接続済み" -ForegroundColor Green
} else {
    Write-Host "❌ Exchange Onlineに未接続" -ForegroundColor Red
    exit
}

# 読み取り権限テスト
try {
    Write-Host "📖 読み取り権限テスト中..." -ForegroundColor Yellow
    $mailboxCount = (Get-EXOMailbox -ResultSize 5).Count
    Write-Host "✅ メールボックス読み取り権限: OK (テスト対象: $mailboxCount 件)" -ForegroundColor Green
} catch {
    Write-Host "❌ 読み取り権限エラー: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# 会議室作成権限テスト
try {
    Write-Host "🏢 会議室作成権限テスト中..." -ForegroundColor Yellow
    
    # テスト用会議室名（既存チェック）
    $testRoomEmail = "test-room-$(Get-Date -Format 'yyyyMMddHHmmss')@miraiconst.onmicrosoft.com"
    $testRoomName = "テスト会議室$(Get-Date -Format 'MMddHHmm')"
    
    # 会議室作成試行
    $newRoom = New-Mailbox -Name $testRoomName -Room -PrimarySmtpAddress $testRoomEmail -ResourceCapacity 10
    
    if ($newRoom) {
        Write-Host "✅ 会議室作成成功: $($newRoom.DisplayName)" -ForegroundColor Green
        Write-Host "   メールアドレス: $($newRoom.PrimarySmtpAddress)" -ForegroundColor Gray
        
        # 作成した会議室の設定
        Write-Host "⚙️ 会議室設定中..." -ForegroundColor Yellow
        Set-CalendarProcessing -Identity $newRoom.PrimarySmtpAddress -AutomateProcessing AutoAccept -BookingWindowInDays 180
        
        Write-Host "✅ 会議室設定完了" -ForegroundColor Green
        Write-Host ""
        Write-Host "📊 会議室利用状況監査を再実行してください" -ForegroundColor Cyan
    }
} catch {
    Write-Host "❌ 会議室作成エラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 考えられる原因:" -ForegroundColor Yellow
    Write-Host "   • アプリ登録にExchange管理者権限が付与されていない" -ForegroundColor Gray
    Write-Host "   • 組織でのルーム作成が制限されている" -ForegroundColor Gray
    Write-Host "   • 証明書ベース認証の権限が不足している" -ForegroundColor Gray
    Write-Host ""
    Write-Host "💡 解決方法:" -ForegroundColor Yellow
    Write-Host "   1. Microsoft 365管理センター > Azure AD > アプリ登録" -ForegroundColor Gray
    Write-Host "   2. アプリID: 22e5d6e4-805f-4516-af09-ff09c7c224c4" -ForegroundColor Gray
    Write-Host "   3. APIのアクセス許可 > Exchange.ManageAsApp を追加" -ForegroundColor Gray
    Write-Host "   4. または Exchange管理者ロールを割り当て" -ForegroundColor Gray
}

Write-Host ""
Write-Host "🔍 現在のアプリ権限確認:" -ForegroundColor Cyan
Write-Host "   AppId: 22e5d6e4-805f-4516-af09-ff09c7c224c4" -ForegroundColor Gray
Write-Host "   証明書: 94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6" -ForegroundColor Gray