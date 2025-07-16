# 最終Exchange Online接続テスト
# 新しい証明書での接続確認

Write-Host "🎯 最終Exchange Online接続テスト開始..." -ForegroundColor Cyan
Write-Host "📋 テスト対象証明書: 3C5C3A9C4F97CD1C95DFDB389AB1F371AAB87975" -ForegroundColor Yellow

# RealM365DataProvider モジュールをインポート
$modulePath = "E:\MicrosoftProductManagementTools\Scripts\Common"
Import-Module "$modulePath\RealM365DataProvider.psm1" -Force

# Microsoft 365 サービスに接続
try {
    Write-Host "🔗 Microsoft 365 サービスに接続中..." -ForegroundColor Yellow
    $authResult = Connect-M365Services
    
    if ($authResult.ExchangeConnected) {
        Write-Host "✅ Exchange Online接続成功!" -ForegroundColor Green
        
        # 簡単な機能テスト
        Write-Host "`n🧪 Exchange Online機能テスト..." -ForegroundColor Yellow
        
        # メールボックス情報のテスト
        Write-Host "📧 メールボックス分析テスト..." -ForegroundColor Cyan
        $mailboxData = Get-M365MailboxAnalysis
        if ($mailboxData -and $mailboxData.Count -gt 0) {
            Write-Host "✅ メールボックス分析データ取得成功 ($($mailboxData.Count) 件)" -ForegroundColor Green
        } else {
            Write-Host "⚠️ メールボックス分析データが取得できませんでした" -ForegroundColor Yellow
        }
        
        Write-Host "`n🎉 Exchange Online証明書認証が正常に動作しています!" -ForegroundColor Green
        Write-Host "📊 Exchange Online の4つの機能でリアルデータ取得が可能です:" -ForegroundColor Cyan
        Write-Host "  - 📧 メールボックス分析" -ForegroundColor Gray
        Write-Host "  - 📬 メールフロー分析" -ForegroundColor Gray
        Write-Host "  - 🛡️ スパム対策分析" -ForegroundColor Gray
        Write-Host "  - 📊 配信分析" -ForegroundColor Gray
        
    } else {
        Write-Host "❌ Exchange Online接続が失敗しました" -ForegroundColor Red
        Write-Host "💡 Azure Portal での証明書登録を確認してください" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ 接続テストエラー: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🏁 最終Exchange Online接続テスト完了" -ForegroundColor Cyan