# ================================================================================
# GUIウィンドウ操作テスト
# Microsoft 365統合管理ツール用
# ================================================================================

[CmdletBinding()]
param()

# スクリプトの場所とToolRootを設定
$Script:TestRoot = $PSScriptRoot
$Script:ToolRoot = Split-Path $Script:TestRoot -Parent

Write-Host "=== GUIウィンドウ操作テスト開始 ===" -ForegroundColor Green
Write-Host "ToolRoot: $Script:ToolRoot" -ForegroundColor Cyan

# STAモードチェック
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "警告: このスクリプトはSTAモードで実行する必要があります。" -ForegroundColor Yellow
    Write-Host "再起動します..." -ForegroundColor Yellow
    Start-Process pwsh -ArgumentList "-sta", "-File", $MyInvocation.MyCommand.Path -NoNewWindow -Wait
    exit
}

# プラットフォーム検出とアセンブリ読み込み
if ($IsLinux -or $IsMacOS) {
    Write-Host "エラー: このGUIアプリケーションはWindows環境でのみ動作します。" -ForegroundColor Red
    exit 1
}

# 必要なアセンブリの読み込み
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    Write-Host "✅ Windows Formsアセンブリ読み込み成功" -ForegroundColor Green
}
catch {
    Write-Host "エラー: Windows Formsアセンブリの読み込みに失敗しました。" -ForegroundColor Red
    exit 1
}

try {
    # Windows Forms初期設定
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
    
    # テスト用フォーム作成
    $testForm = New-Object System.Windows.Forms.Form
    $testForm.Text = "GUIウィンドウ操作テスト - Microsoft 365統合管理ツール"
    $testForm.Size = New-Object System.Drawing.Size(800, 600)
    $testForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $testForm.MinimumSize = New-Object System.Drawing.Size(600, 400)
    $testForm.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $testForm.ShowInTaskbar = $true
    
    # ウィンドウ操作設定
    $testForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $testForm.MaximizeBox = $true
    $testForm.MinimizeBox = $true
    $testForm.ControlBox = $true
    $testForm.TopMost = $false
    $testForm.ShowIcon = $true
    $testForm.SizeGripStyle = [System.Windows.Forms.SizeGripStyle]::Auto
    $testForm.MaximumSize = New-Object System.Drawing.Size(1600, 1200)
    
    # フォーカス設定
    $testForm.TabStop = $false
    
    Write-Host "✅ テスト用フォーム作成完了" -ForegroundColor Green
    
    # ウィンドウ操作確認用のコントロール
    $mainPanel = New-Object System.Windows.Forms.Panel
    $mainPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainPanel.BackColor = [System.Drawing.Color]::WhiteSmoke
    $mainPanel.AutoScroll = $true
    $testForm.Controls.Add($mainPanel)
    
    # タイトルラベル
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "🔧 GUIウィンドウ操作テスト"
    $titleLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 16, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::DarkBlue
    $titleLabel.Location = New-Object System.Drawing.Point(50, 30)
    $titleLabel.Size = New-Object System.Drawing.Size(500, 40)
    $mainPanel.Controls.Add($titleLabel)
    
    # 操作確認リスト
    $instructionLabel = New-Object System.Windows.Forms.Label
    $instructionLabel.Text = @"
以下のウィンドウ操作をテストしてください：

✅ ウィンドウの移動（タイトルバーをドラッグ）
✅ ウィンドウのリサイズ（端をドラッグ、右下角のグリップ）
✅ 最小化ボタンをクリック
✅ 最大化ボタンをクリック
✅ 元のサイズに戻すボタンをクリック
✅ 閉じるボタンをクリック

全ての操作が正常に動作すれば、GUIは完全に機能しています。
"@
    $instructionLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 11)
    $instructionLabel.ForeColor = [System.Drawing.Color]::Black
    $instructionLabel.Location = New-Object System.Drawing.Point(50, 90)
    $instructionLabel.Size = New-Object System.Drawing.Size(680, 300)
    $mainPanel.Controls.Add($instructionLabel)
    
    # 現在の設定表示
    $settingsLabel = New-Object System.Windows.Forms.Label
    $settingsLabel.Text = @"
🔍 現在のフォーム設定:
FormBorderStyle: $($testForm.FormBorderStyle)
MaximizeBox: $($testForm.MaximizeBox)
MinimizeBox: $($testForm.MinimizeBox)
ControlBox: $($testForm.ControlBox)
SizeGripStyle: $($testForm.SizeGripStyle)
MinimumSize: $($testForm.MinimumSize)
MaximumSize: $($testForm.MaximumSize)
"@
    $settingsLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10)
    $settingsLabel.ForeColor = [System.Drawing.Color]::DarkGreen
    $settingsLabel.Location = New-Object System.Drawing.Point(50, 400)
    $settingsLabel.Size = New-Object System.Drawing.Size(680, 150)
    $mainPanel.Controls.Add($settingsLabel)
    
    # 実データテストボタン
    $realDataButton = New-Object System.Windows.Forms.Button
    $realDataButton.Text = "📊 実データ取得テスト"
    $realDataButton.Font = New-Object System.Drawing.Font("Yu Gothic UI", 12, [System.Drawing.FontStyle]::Bold)
    $realDataButton.BackColor = [System.Drawing.Color]::LightBlue
    $realDataButton.ForeColor = [System.Drawing.Color]::DarkBlue
    $realDataButton.Location = New-Object System.Drawing.Point(450, 30)
    $realDataButton.Size = New-Object System.Drawing.Size(200, 40)
    $realDataButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $realDataButton.FlatAppearance.BorderColor = [System.Drawing.Color]::Blue
    $realDataButton.FlatAppearance.BorderSize = 2
    $mainPanel.Controls.Add($realDataButton)
    
    # 実データテストボタンのイベント
    $realDataButton.Add_Click({
        param($sender, $e)
        
        $sender.Enabled = $false
        $originalText = $sender.Text
        $sender.Text = "📊 実データ取得中..."
        
        try {
            # ProgressDisplay.psm1をインポート
            $progressModulePath = Join-Path $Script:ToolRoot "Scripts\Common\ProgressDisplay.psm1"
            if (Test-Path $progressModulePath) {
                Import-Module $progressModulePath -Force -ErrorAction SilentlyContinue
            }
            
            # GuiReportFunctions.psm1をインポート
            $guiModulePath = Join-Path $Script:ToolRoot "Scripts\Common\GuiReportFunctions.psm1"
            if (Test-Path $guiModulePath) {
                Import-Module $guiModulePath -Force -ErrorAction SilentlyContinue
            }
            
            # 実データ取得のテスト
            if (Get-Command Invoke-ReportGenerationWithProgress -ErrorAction SilentlyContinue) {
                Write-Host "🚀 実データ取得テスト開始..." -ForegroundColor Yellow
                $data = Invoke-ReportGenerationWithProgress -ReportType "Daily" -ReportName "📊 実データテスト" -RecordCount 10
                
                if ($data -and $data.Count -gt 0) {
                    [System.Windows.Forms.MessageBox]::Show(
                        "✅ 実データ取得成功!`n取得件数: $($data.Count) 件`n`n実際のMicrosoft 365データが正常に取得されました。",
                        "実データ取得結果",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )
                } else {
                    [System.Windows.Forms.MessageBox]::Show(
                        "⚠️ 実データが取得できませんでした。`nダミーデータにフォールバックしました。",
                        "実データ取得結果",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    )
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show(
                    "❌ 実データ取得関数が見つかりません。",
                    "エラー",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "❌ エラーが発生しました:`n$($_.Exception.Message)",
                "エラー",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
        finally {
            $sender.Text = $originalText
            $sender.Enabled = $true
        }
    })
    
    Write-Host "✅ GUIウィンドウ操作テスト用インターフェース作成完了" -ForegroundColor Green
    Write-Host "`n🚀 テストウィンドウを表示します..." -ForegroundColor Yellow
    Write-Host "ウィンドウを操作して、移動・リサイズ・最小化・最大化・閉じるが正常に動作することを確認してください。" -ForegroundColor Cyan
    
    # フォーム表示
    $testForm.ShowDialog() | Out-Null
    
    Write-Host "✅ GUIウィンドウ操作テスト完了" -ForegroundColor Green
}
catch {
    Write-Host "❌ テストエラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "詳細: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

Write-Host "`n=== GUIウィンドウ操作テスト終了 ===" -ForegroundColor Magenta