# 基本的なGUIテスト

# STAモードチェック
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "STAモードで再起動します..." -ForegroundColor Yellow
    Start-Process pwsh -ArgumentList "-sta", "-File", $MyInvocation.MyCommand.Path -NoNewWindow -Wait
    exit
}

Write-Host "基本的なGUIテストを開始します..." -ForegroundColor Green

# アセンブリ読み込み
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Write-Host "アセンブリ読み込み成功" -ForegroundColor Green
}
catch {
    Write-Host "アセンブリ読み込みエラー: $_" -ForegroundColor Red
    exit 1
}

# 基本的なフォーム作成
try {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "テストフォーム"
    $form.Size = New-Object System.Drawing.Size(400, 300)
    $form.StartPosition = "CenterScreen"
    
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "これはテストフォームです"
    $label.Location = New-Object System.Drawing.Point(100, 100)
    $label.Size = New-Object System.Drawing.Size(200, 30)
    $form.Controls.Add($label)
    
    $button = New-Object System.Windows.Forms.Button
    $button.Text = "閉じる"
    $button.Location = New-Object System.Drawing.Point(150, 150)
    $button.Size = New-Object System.Drawing.Size(100, 30)
    $button.Add_Click({ $form.Close() })
    $form.Controls.Add($button)
    
    Write-Host "フォーム作成成功" -ForegroundColor Green
    Write-Host "フォームを表示します..." -ForegroundColor Yellow
    
    # フォーム表示
    $result = $form.ShowDialog()
    Write-Host "フォームが閉じられました。結果: $result" -ForegroundColor Green
}
catch {
    Write-Host "エラー: $_" -ForegroundColor Red
    Write-Host "スタックトレース: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}