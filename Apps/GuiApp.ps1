# ================================================================================
# Microsoft 365統合管理ツール - GUI アプリケーション
# GuiApp.ps1
# System.Windows.Forms ベースのGUIインターフェース
# PowerShell 7.5.1専用
# ================================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Debug = $false
)

# 必要なアセンブリの読み込み
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.ComponentModel

# グローバル変数
$Script:ToolRoot = Split-Path $PSScriptRoot -Parent
$Script:Form = $null
$Script:StatusLabel = $null
$Script:LogTextBox = $null
$Script:ProgressBar = $null

# 共通モジュールの読み込み
try {
    Import-Module "$Script:ToolRoot\Scripts\Common\Common.psm1" -Force -ErrorAction Stop
    Import-Module "$Script:ToolRoot\Scripts\Common\Logging.psm1" -Force -ErrorAction Stop
    Import-Module "$Script:ToolRoot\Scripts\Common\Authentication.psm1" -Force -ErrorAction Stop
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "必要なモジュールの読み込みに失敗しました:`n$($_.Exception.Message)",
        "エラー",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

# GUI ログ出力関数
function Write-GuiLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $formattedMessage = "[$timestamp] [$Level] $Message"
    
    if ($Script:LogTextBox) {
        $Script:LogTextBox.Invoke([Action[string]]{
            param($msg)
            $Script:LogTextBox.AppendText("$msg`r`n")
            $Script:LogTextBox.ScrollToCaret()
        }, $formattedMessage)
    }
    
    # 通常のログにも出力
    Write-LogMessage -Message $Message -Level $Level
}

# ステータス更新関数
function Update-Status {
    param([string]$Message)
    
    if ($Script:StatusLabel) {
        $Script:StatusLabel.Invoke([Action[string]]{
            param($msg)
            $Script:StatusLabel.Text = $msg
        }, $Message)
    }
}

# プログレスバー更新関数
function Update-Progress {
    param(
        [int]$Value,
        [string]$Status = ""
    )
    
    if ($Script:ProgressBar) {
        $Script:ProgressBar.Invoke([Action[int]]{
            param($val)
            $Script:ProgressBar.Value = [Math]::Min([Math]::Max($val, 0), 100)
        }, $Value)
    }
    
    if ($Status) {
        Update-Status $Status
    }
}

# 認証実行
function Invoke-Authentication {
    try {
        Update-Status "認証を実行中..."
        Update-Progress 10 "設定ファイルを読み込み中..."
        
        $config = Get-Configuration
        if (-not $config) {
            throw "設定ファイルの読み込みに失敗しました"
        }
        
        Update-Progress 30 "Microsoft Graph に接続中..."
        Write-GuiLog "Microsoft Graph認証を開始します" -Level Info
        
        $authResult = Connect-ToMicrosoftGraph -Config $config
        if ($authResult) {
            Update-Progress 100 "認証完了"
            Write-GuiLog "Microsoft Graph認証が成功しました" -Level Success
            [System.Windows.Forms.MessageBox]::Show(
                "Microsoft 365への認証が成功しました！",
                "認証成功",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        } else {
            throw "認証に失敗しました"
        }
    }
    catch {
        Update-Progress 0 "認証エラー"
        Write-GuiLog "認証エラー: $($_.Exception.Message)" -Level Error
        [System.Windows.Forms.MessageBox]::Show(
            "認証に失敗しました:`n$($_.Exception.Message)",
            "認証エラー",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

# レポート生成実行
function Invoke-ReportGeneration {
    param([string]$ReportType)
    
    try {
        Update-Status "レポートを生成中..."
        Write-GuiLog "$ReportType レポートの生成を開始します" -Level Info
        
        Update-Progress 20 "レポートモジュールを読み込み中..."
        Import-Module "$Script:ToolRoot\Scripts\Common\ScheduledReports.ps1" -Force
        
        Update-Progress 50 "レポートを生成中..."
        
        # レポート生成の実行
        $reportResult = switch ($ReportType) {
            "Daily" {
                & "$Script:ToolRoot\Scripts\Common\ScheduledReports.ps1" -ReportType "Daily"
            }
            "Weekly" {
                & "$Script:ToolRoot\Scripts\Common\ScheduledReports.ps1" -ReportType "Weekly"
            }
            "Monthly" {
                & "$Script:ToolRoot\Scripts\Common\ScheduledReports.ps1" -ReportType "Monthly"
            }
            "Yearly" {
                & "$Script:ToolRoot\Scripts\Common\ScheduledReports.ps1" -ReportType "Yearly"
            }
            default {
                throw "不明なレポートタイプ: $ReportType"
            }
        }
        
        Update-Progress 100 "レポート生成完了"
        Write-GuiLog "$ReportType レポートの生成が完了しました" -Level Success
        
        [System.Windows.Forms.MessageBox]::Show(
            "$ReportType レポートの生成が完了しました！`nレポートはReportsフォルダに保存されています。",
            "レポート生成完了",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        Update-Progress 0 "レポート生成エラー"
        Write-GuiLog "レポート生成エラー: $($_.Exception.Message)" -Level Error
        [System.Windows.Forms.MessageBox]::Show(
            "レポート生成に失敗しました:`n$($_.Exception.Message)",
            "レポート生成エラー",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

# ライセンス分析実行
function Invoke-LicenseAnalysis {
    try {
        Update-Status "ライセンス分析を実行中..."
        Write-GuiLog "ライセンス分析を開始します" -Level Info
        
        Update-Progress 30 "ライセンス情報を取得中..."
        & "$Script:ToolRoot\New-LicenseDashboard.ps1"
        
        Update-Progress 100 "ライセンス分析完了"
        Write-GuiLog "ライセンス分析が完了しました" -Level Success
        
        [System.Windows.Forms.MessageBox]::Show(
            "ライセンス分析が完了しました！`nダッシュボードファイルが生成されています。",
            "ライセンス分析完了",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        Update-Progress 0 "ライセンス分析エラー"
        Write-GuiLog "ライセンス分析エラー: $($_.Exception.Message)" -Level Error
        [System.Windows.Forms.MessageBox]::Show(
            "ライセンス分析に失敗しました:`n$($_.Exception.Message)",
            "ライセンス分析エラー",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

# レポートフォルダを開く
function Open-ReportsFolder {
    try {
        $reportsPath = Join-Path $Script:ToolRoot "Reports"
        if (Test-Path $reportsPath) {
            Start-Process explorer.exe -ArgumentList $reportsPath
            Write-GuiLog "レポートフォルダを開きました: $reportsPath" -Level Info
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "レポートフォルダが見つかりません: $reportsPath",
                "フォルダエラー",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }
    }
    catch {
        Write-GuiLog "レポートフォルダを開く際にエラーが発生しました: $($_.Exception.Message)" -Level Error
    }
}

# メインフォーム作成
function New-MainForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Microsoft 365統合管理ツール - GUI版"
    $form.Size = New-Object System.Drawing.Size(800, 600)
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $form.MaximizeBox = $false
    $form.Icon = [System.Drawing.SystemIcons]::Application
    
    # メインパネル
    $mainPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $mainPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainPanel.RowCount = 4
    $mainPanel.ColumnCount = 1
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 80)))
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 200)))
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    
    # ヘッダーパネル
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.BackColor = [System.Drawing.Color]::Navy
    $headerPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    
    $headerLabel = New-Object System.Windows.Forms.Label
    $headerLabel.Text = "Microsoft 365統合管理ツール"
    $headerLabel.Font = New-Object System.Drawing.Font("MS Gothic", 16, [System.Drawing.FontStyle]::Bold)
    $headerLabel.ForeColor = [System.Drawing.Color]::White
    $headerLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $headerLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $headerPanel.Controls.Add($headerLabel)
    
    # ボタンパネル
    $buttonPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $buttonPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $buttonPanel.RowCount = 2
    $buttonPanel.ColumnCount = 3
    $buttonPanel.Padding = New-Object System.Windows.Forms.Padding(10)
    
    # ボタン作成関数
    function New-ActionButton {
        param([string]$Text, [string]$Action)
        
        $button = New-Object System.Windows.Forms.Button
        $button.Text = $Text
        $button.Size = New-Object System.Drawing.Size(120, 40)
        $button.Anchor = [System.Windows.Forms.AnchorStyles]::None
        $button.UseVisualStyleBackColor = $true
        $button.Font = New-Object System.Drawing.Font("MS Gothic", 9)
        
        $button.Add_Click({
            [System.Windows.Forms.Application]::DoEvents()
            switch ($Action) {
                "Auth" { Invoke-Authentication }
                "Daily" { Invoke-ReportGeneration -ReportType "Daily" }
                "Weekly" { Invoke-ReportGeneration -ReportType "Weekly" }
                "Monthly" { Invoke-ReportGeneration -ReportType "Monthly" }
                "License" { Invoke-LicenseAnalysis }
                "OpenReports" { Open-ReportsFolder }
            }
        })
        
        return $button
    }
    
    # ボタン追加
    $buttonPanel.Controls.Add((New-ActionButton "認証テスト" "Auth"), 0, 0)
    $buttonPanel.Controls.Add((New-ActionButton "日次レポート" "Daily"), 1, 0)
    $buttonPanel.Controls.Add((New-ActionButton "週次レポート" "Weekly"), 2, 0)
    $buttonPanel.Controls.Add((New-ActionButton "月次レポート" "Monthly"), 0, 1)
    $buttonPanel.Controls.Add((New-ActionButton "ライセンス分析" "License"), 1, 1)
    $buttonPanel.Controls.Add((New-ActionButton "レポートを開く" "OpenReports"), 2, 1)
    
    # ログ表示エリア
    $logPanel = New-Object System.Windows.Forms.Panel
    $logPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $logPanel.Padding = New-Object System.Windows.Forms.Padding(10)
    
    $logLabel = New-Object System.Windows.Forms.Label
    $logLabel.Text = "実行ログ:"
    $logLabel.Dock = [System.Windows.Forms.DockStyle]::Top
    $logLabel.Height = 20
    $logLabel.Font = New-Object System.Drawing.Font("MS Gothic", 9, [System.Drawing.FontStyle]::Bold)
    
    $Script:LogTextBox = New-Object System.Windows.Forms.TextBox
    $Script:LogTextBox.Multiline = $true
    $Script:LogTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $Script:LogTextBox.ReadOnly = $true
    $Script:LogTextBox.BackColor = [System.Drawing.Color]::Black
    $Script:LogTextBox.ForeColor = [System.Drawing.Color]::White
    $Script:LogTextBox.Font = New-Object System.Drawing.Font("Consolas", 8)
    $Script:LogTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    
    $logPanel.Controls.Add($logLabel)
    $logPanel.Controls.Add($Script:LogTextBox)
    
    # ステータスバー
    $statusPanel = New-Object System.Windows.Forms.Panel
    $statusPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $statusPanel.BackColor = [System.Drawing.Color]::LightGray
    
    $Script:StatusLabel = New-Object System.Windows.Forms.Label
    $Script:StatusLabel.Text = "準備完了"
    $Script:StatusLabel.Dock = [System.Windows.Forms.DockStyle]::Left
    $Script:StatusLabel.Width = 300
    $Script:StatusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $Script:StatusLabel.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
    
    $Script:ProgressBar = New-Object System.Windows.Forms.ProgressBar
    $Script:ProgressBar.Dock = [System.Windows.Forms.DockStyle]::Right
    $Script:ProgressBar.Width = 200
    $Script:ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $Script:ProgressBar.Margin = New-Object System.Windows.Forms.Padding(0, 5, 10, 5)
    
    $statusPanel.Controls.Add($Script:StatusLabel)
    $statusPanel.Controls.Add($Script:ProgressBar)
    
    # パネルをフォームに追加
    $mainPanel.Controls.Add($headerPanel, 0, 0)
    $mainPanel.Controls.Add($buttonPanel, 0, 1)
    $mainPanel.Controls.Add($logPanel, 0, 2)
    $mainPanel.Controls.Add($statusPanel, 0, 3)
    
    $form.Controls.Add($mainPanel)
    
    return $form
}

# アプリケーション初期化
function Initialize-GuiApp {
    try {
        Write-GuiLog "Microsoft 365統合管理ツール GUI版を起動しています..." -Level Info
        Write-GuiLog "PowerShell バージョン: $($PSVersionTable.PSVersion)" -Level Info
        Write-GuiLog "実行ポリシー: $(Get-ExecutionPolicy)" -Level Info
        
        # 設定ファイル確認
        $configPath = Join-Path $Script:ToolRoot "Config\appsettings.json"
        if (Test-Path $configPath) {
            Write-GuiLog "設定ファイルが見つかりました: $configPath" -Level Success
        } else {
            Write-GuiLog "設定ファイルが見つかりません: $configPath" -Level Warning
        }
        
        Write-GuiLog "GUI初期化完了。操作ボタンをクリックして機能をご利用ください。" -Level Success
        Update-Status "準備完了 - ボタンをクリックして開始してください"
    }
    catch {
        Write-GuiLog "初期化エラー: $($_.Exception.Message)" -Level Error
    }
}

# メイン実行
function Main {
    try {
        # Windows Forms アプリケーションの設定
        [System.Windows.Forms.Application]::EnableVisualStyles()
        [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
        
        # メインフォーム作成
        $Script:Form = New-MainForm
        
        # フォーム表示イベント
        $Script:Form.Add_Shown({
            Initialize-GuiApp
        })
        
        # フォーム終了イベント
        $Script:Form.Add_FormClosing({
            param($sender, $e)
            Write-GuiLog "Microsoft 365統合管理ツール GUI版を終了します" -Level Info
        })
        
        # アプリケーション実行
        [System.Windows.Forms.Application]::Run($Script:Form)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "アプリケーション起動エラー:`n$($_.Exception.Message)",
            "エラー",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        exit 1
    }
}

# 実行開始
if ($PSVersionTable.PSVersion -lt [Version]"7.0.0") {
    [System.Windows.Forms.MessageBox]::Show(
        "このGUIアプリケーションはPowerShell 7.0以上が必要です。`n現在のバージョン: $($PSVersionTable.PSVersion)",
        "バージョンエラー",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

Main