# ================================================================================
# Microsoft 365統合管理ツール - シンプル版 GUI
# PowerShell 7.x での動作確認版
# ================================================================================

[CmdletBinding()]
param()

Write-Host "🚀 Microsoft 365統合管理ツール - シンプル版GUI" -ForegroundColor Cyan

# STAモードチェック
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "警告: このスクリプトはSTAモードで実行する必要があります。" -ForegroundColor Yellow
    Write-Host "再起動します..." -ForegroundColor Yellow
    Start-Process pwsh -ArgumentList "-sta", "-File", $MyInvocation.MyCommand.Path -NoNewWindow -Wait
    exit
}

# プラットフォーム検出
if ($IsLinux -or $IsMacOS) {
    Write-Host "エラー: このGUIアプリケーションはWindows環境でのみ動作します。" -ForegroundColor Red
    exit 1
}

# 必要なアセンブリの読み込み
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    Write-Host "✅ Windows Forms アセンブリ読み込み完了" -ForegroundColor Green
}
catch {
    Write-Host "エラー: Windows Formsアセンブリの読み込みに失敗しました。" -ForegroundColor Red
    Write-Host "詳細: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}

# Windows Forms初期設定
try {
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
    Write-Host "✅ Windows Forms 初期化完了" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Windows Forms 初期化警告: $($_.Exception.Message)" -ForegroundColor Yellow
}

# シンプルなフォーム作成関数
function New-SimpleMainForm {
    # メインフォーム作成
    $form = [System.Windows.Forms.Form](New-Object System.Windows.Forms.Form)
    $form.Text = "🚀 Microsoft 365統合管理ツール - テスト版"
    $form.Size = New-Object System.Drawing.Size(800, 600)
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox = $true
    $form.MinimizeBox = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
    
    # メインタイトル
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "🏢 Microsoft 365統合管理ツール - テスト版"
    $titleLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 16, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $titleLabel.Size = New-Object System.Drawing.Size(750, 40)
    $titleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($titleLabel)
    
    # テストボタン
    $testButton = New-Object System.Windows.Forms.Button
    $testButton.Text = "🧪 テスト実行"
    $testButton.Location = New-Object System.Drawing.Point(300, 100)
    $testButton.Size = New-Object System.Drawing.Size(200, 50)
    $testButton.Font = New-Object System.Drawing.Font("Yu Gothic UI", 12, [System.Drawing.FontStyle]::Bold)
    $testButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $testButton.ForeColor = [System.Drawing.Color]::White
    $testButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $testButton.Add_Click({
        [System.Windows.Forms.MessageBox]::Show("テスト実行完了！`nGUIが正常に動作しています。", "成功", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })
    $form.Controls.Add($testButton)
    
    # 終了ボタン
    $exitButton = New-Object System.Windows.Forms.Button
    $exitButton.Text = "🚪 終了"
    $exitButton.Location = New-Object System.Drawing.Point(300, 170)
    $exitButton.Size = New-Object System.Drawing.Size(200, 50)
    $exitButton.Font = New-Object System.Drawing.Font("Yu Gothic UI", 12, [System.Drawing.FontStyle]::Bold)
    $exitButton.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
    $exitButton.ForeColor = [System.Drawing.Color]::White
    $exitButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $exitButton.Add_Click({
        $form.Close()
    })
    $form.Controls.Add($exitButton)
    
    # ステータスラベル
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "✅ GUI テスト準備完了"
    $statusLabel.Location = New-Object System.Drawing.Point(20, 500)
    $statusLabel.Size = New-Object System.Drawing.Size(750, 30)
    $statusLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10)
    $statusLabel.ForeColor = [System.Drawing.Color]::Green
    $statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($statusLabel)
    
    return [System.Windows.Forms.Form]$form
}

# メイン処理
try {
    Write-Host "🎯 シンプルGUI初期化中..." -ForegroundColor Cyan
    
    # メインフォーム作成と表示
    $mainForm = New-SimpleMainForm
    Write-Host "✅ シンプルGUIが正常に初期化されました" -ForegroundColor Green
    
    # フォーム表示（PowerShell 7.x 対応の型キャスト）
    Write-Host "🖥️ GUIを表示中..." -ForegroundColor Cyan
    [System.Windows.Forms.Application]::Run([System.Windows.Forms.Form]$mainForm)
}
catch {
    Write-Host "❌ GUI初期化エラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "スタックトレース: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    [System.Windows.Forms.MessageBox]::Show("GUI初期化エラー: $($_.Exception.Message)", "エラー", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}
finally {
    Write-Host "🔚 シンプルGUIを終了します" -ForegroundColor Cyan
}