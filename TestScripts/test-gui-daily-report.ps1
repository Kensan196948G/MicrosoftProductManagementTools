# ================================================================================
# GUI日次レポートテスト
# test-gui-daily-report.ps1
# 日次レポートボタンが正しく動作するかテスト
# ================================================================================

Write-Host "`n🔍 GUI日次レポート機能テスト開始" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor DarkGray

# テスト環境準備
$rootPath = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $rootPath "Apps\GuiApp.ps1"
$reportPath = Join-Path $rootPath "Reports\Daily"

Write-Host "`n1️⃣ GUI起動前の準備" -ForegroundColor Yellow
Write-Host "   GUIパス: $guiPath" -ForegroundColor Gray
Write-Host "   レポートパス: $reportPath" -ForegroundColor Gray

# レポートディレクトリの存在確認
if (-not (Test-Path $reportPath)) {
    Write-Host "   レポートディレクトリを作成します" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
}

# 既存レポートのカウント
$existingReports = Get-ChildItem -Path $reportPath -Filter "*.html" -ErrorAction SilentlyContinue
$initialCount = if ($existingReports) { $existingReports.Count } else { 0 }
Write-Host "   既存レポート数: $initialCount" -ForegroundColor Gray

Write-Host "`n2️⃣ GUI起動方法" -ForegroundColor Yellow
Write-Host @"
以下のコマンドでGUIを起動してください:

    pwsh -File "$guiPath"

起動後の手順:
1. 「📊 定期レポート」セクションを確認
2. 「日次レポート」ボタンをクリック
3. レポート生成の進行状況を確認
4. 生成完了メッセージの表示を確認
5. HTMLレポートが自動的に開かれることを確認

"@ -ForegroundColor Cyan

Write-Host "3️⃣ 確認ポイント" -ForegroundColor Yellow
Write-Host "   ✓ 実データ取得の試行メッセージが表示されるか" -ForegroundColor Gray
Write-Host "   ✓ 認証失敗時はサンプルデータで生成されるか" -ForegroundColor Gray
Write-Host "   ✓ レポートファイルが Reports\Daily に生成されるか" -ForegroundColor Gray
Write-Host "   ✓ HTMLファイルが自動的に開かれるか" -ForegroundColor Gray
Write-Host "   ✓ ポップアップメッセージが表示されるか" -ForegroundColor Gray

Write-Host "`n4️⃣ 代替テスト（スクリプトから直接実行）" -ForegroundColor Yellow
$confirm = Read-Host "GUIを起動せずに直接テストしますか？ (y/n)"

if ($confirm -eq 'y') {
    Write-Host "`n日次レポート生成を直接実行します..." -ForegroundColor Cyan
    
    try {
        # モジュールパスの設定
        $modulePath = Join-Path $rootPath "Scripts\Common"
        
        # 必要なモジュールをインポート
        Import-Module "$modulePath\Common.psm1" -Force
        Import-Module "$modulePath\ScheduledReports.ps1" -Force
        
        # 日次レポート生成を実行
        Write-Host "Invoke-DailyReports を実行中..." -ForegroundColor Yellow
        Invoke-DailyReports
        
        # 新規生成されたレポートの確認
        $newReports = Get-ChildItem -Path $reportPath -Filter "*.html" | 
            Sort-Object CreationTime -Descending | 
            Select-Object -First 1
        
        if ($newReports -and $newReports.CreationTime -gt (Get-Date).AddMinutes(-1)) {
            Write-Host "`n✅ レポート生成成功" -ForegroundColor Green
            Write-Host "   ファイル名: $($newReports.Name)" -ForegroundColor Gray
            Write-Host "   作成日時: $($newReports.CreationTime)" -ForegroundColor Gray
            Write-Host "   サイズ: $([Math]::Round($newReports.Length / 1KB, 2)) KB" -ForegroundColor Gray
            
            $openReport = Read-Host "`nレポートを開きますか？ (y/n)"
            if ($openReport -eq 'y') {
                Start-Process $newReports.FullName
            }
        }
        else {
            Write-Host "`n⚠️  新しいレポートが生成されませんでした" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "`n❌ エラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.Exception.StackTrace -ForegroundColor DarkRed
    }
}

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor DarkGray
Write-Host "テスト準備完了" -ForegroundColor Cyan