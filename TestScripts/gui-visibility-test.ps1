# ================================================================================
# GUI可視性テストスクリプト
# Windows FormsのGUIが正しく表示されるかテスト
# ================================================================================

# STAモードチェック
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "⚠️ STAモードで再起動します..." -ForegroundColor Yellow
    Start-Process pwsh -ArgumentList "-sta", "-File", $MyInvocation.MyCommand.Path -NoNewWindow -Wait
    exit
}

Write-Host "🔍 GUI可視性をテスト中..." -ForegroundColor Cyan

# 必要なアセンブリの読み込み
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Write-Host "✅ Windows Formsアセンブリ読み込み完了" -ForegroundColor Green
} catch {
    Write-Host "❌ アセンブリ読み込み失敗: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Visual Stylesを有効化
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# 簡単なテストフォームを作成
$form = New-Object System.Windows.Forms.Form
$form.Text = "GUI可視性テスト"
$form.Size = New-Object System.Drawing.Size(400, 300)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $true

# ラベルを追加
$label = New-Object System.Windows.Forms.Label
$label.Text = "このウィンドウが見えていればGUI表示は正常です。"
$label.Size = New-Object System.Drawing.Size(350, 50)
$label.Location = New-Object System.Drawing.Point(25, 50)
$label.TextAlign = "MiddleCenter"
$form.Controls.Add($label)

# OKボタンを追加
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK - テスト完了"
$okButton.Size = New-Object System.Drawing.Size(120, 30)
$okButton.Location = New-Object System.Drawing.Point(140, 120)
$okButton.DialogResult = "OK"
$form.Controls.Add($okButton)

# 自動クローズ用タイマー（10秒後）
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 10000
$timer.Add_Tick({
    Write-Host "⏰ 10秒経過したため自動でフォームを閉じます" -ForegroundColor Yellow
    $form.Close()
    $timer.Stop()
})
$timer.Start()

Write-Host "📋 フォーム情報:" -ForegroundColor Yellow
Write-Host "  サイズ: $($form.Size)" -ForegroundColor White
Write-Host "  位置: $($form.Location)" -ForegroundColor White
Write-Host "  表示: $($form.Visible)" -ForegroundColor White
Write-Host "  TopMost: $($form.TopMost)" -ForegroundColor White

Write-Host "🚀 GUIテストフォームを表示中..." -ForegroundColor Green
Write-Host "   このフォームが表示されない場合は、タスクバーを確認してください。" -ForegroundColor Cyan
Write-Host "   10秒後に自動で閉じます。" -ForegroundColor Cyan

# フォームを表示
$result = $form.ShowDialog()

if ($result -eq "OK") {
    Write-Host "✅ GUI表示テスト成功: ユーザーがOKボタンをクリックしました" -ForegroundColor Green
} else {
    Write-Host "ℹ️ GUI表示テスト完了: フォームが自動で閉じられました" -ForegroundColor Yellow
}

$timer.Dispose()
$form.Dispose()

Write-Host "📋 テスト結果:" -ForegroundColor Blue
Write-Host "  Windows Formsアセンブリ: ✅ 正常" -ForegroundColor Green
Write-Host "  STAモード: ✅ 正常" -ForegroundColor Green
Write-Host "  フォーム作成: ✅ 正常" -ForegroundColor Green
Write-Host "  GUI表示: $(if ($result -eq 'OK') { '✅ 正常' } else { '⚠️ 確認が必要' })" -ForegroundColor $(if ($result -eq 'OK') { 'Green' } else { 'Yellow' })

Write-Host "`n🎯 次のステップ:" -ForegroundColor Cyan
Write-Host "  1. このテストフォームが表示された場合 → GUI環境は正常です" -ForegroundColor White
Write-Host "  2. フォームが表示されなかった場合 → Windowsの表示設定を確認してください" -ForegroundColor White
Write-Host "  3. 正常な場合は、メインのGUIアプリケーションを起動してください" -ForegroundColor White