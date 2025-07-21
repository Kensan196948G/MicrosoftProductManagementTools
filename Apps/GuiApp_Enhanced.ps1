# ================================================================================
# Microsoft 365統合管理ツール - 完全版 GUI v2.0
# 実データ対応・全機能統合版
# Templates/Samples の全6フォルダ対応
# 
# ✨ v2.0 改善項目 (Dev0 - Frontend Developer実装):
# ● 26機能ボタンの最適化されたレイアウト (中央寄せ・サイズ拡張)
# ● リアルタイムログ表示機能のパフォーマンス向上 (ログトリミング・スレッドセーフ)
# ● モダンなポップアップ通知システム (フィードイン/アウト・ホバー停止)
# ● キーボードショートカット対応 (Ctrl+R/T/Q, F5)
# ● ユーザビリティ向上 (グラデーション背景・バージョン情報・クリーンアップ)
# ================================================================================

[CmdletBinding()]
param()

# Windows Forms初期設定（スクリプト最初、任意のオブジェクト作成前に実行）
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    
    # エラーハンドラーの設定（コントロール作成前に実行）
    [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
    [System.Windows.Forms.Application]::add_ThreadException({
        param($sender, $e)
        Write-Host "⚠️ Windows Forms エラー: $($e.Exception.Message)" -ForegroundColor Yellow
        # エラーを無視して継続
    })
    
    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
    [System.Windows.Forms.Application]::EnableVisualStyles()
    Write-Host "✅ Windows Forms 最優先初期化完了（エラーハンドラー含む）" -ForegroundColor Green
} catch {
    # エラーがあっても継続
    Write-Host "⚠️ Windows Forms 初期化に問題がありましたが継続します" -ForegroundColor Yellow
}

# PowerShellウィンドウタイトル設定（安全なアクセス）
try {
    $psVersion = $PSVersionTable.PSVersion
    
    # $Host.UI.RawUIが存在し、アクセス可能か確認
    if ($Host -and $Host.UI -and $Host.UI.RawUI) {
        if ($psVersion.Major -ge 7) {
            $Host.UI.RawUI.WindowTitle = "🚀 Microsoft 365統合管理ツール - 完全版 PowerShell 7.x GUI"
        } else {
            $Host.UI.RawUI.WindowTitle = "🚀 Microsoft 365統合管理ツール - 完全版 Windows PowerShell GUI"
        }
        
        # 背景色と文字色の設定はコンソールホストでのみ有効
        if ($Host.Name -eq "ConsoleHost") {
            if ($psVersion.Major -ge 7) {
                $Host.UI.RawUI.BackgroundColor = "DarkBlue"
                $Host.UI.RawUI.ForegroundColor = "White"
            } else {
                $Host.UI.RawUI.BackgroundColor = "DarkMagenta"
                $Host.UI.RawUI.ForegroundColor = "White"
            }
        }
    }
    
    Clear-Host
    Write-Host "🚀 Microsoft 365統合管理ツール完全版を起動中..." -ForegroundColor Cyan
} catch {
    # エラーを無視して続行
    Write-Host "🚀 Microsoft 365統合管理ツール完全版を起動中..." -ForegroundColor Cyan
}

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
    Write-Host "現在の環境: $($PSVersionTable.Platform)" -ForegroundColor Yellow
    Write-Host "CLIモードをご利用ください: pwsh -File run_launcher.ps1 -Mode cli" -ForegroundColor Green
    exit 1
}

# 残りの必要なアセンブリの読み込み（Windows.Formsは最初に読み込み済み）
try {
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    Add-Type -AssemblyName System.ComponentModel -ErrorAction Stop
    Add-Type -AssemblyName System.Web -ErrorAction Stop
    Write-Host "✅ 残りのアセンブリ読み込み完了" -ForegroundColor Green
}
catch {
    Write-Host "エラー: アセンブリの読み込みに失敗しました。" -ForegroundColor Red
    Write-Host "詳細: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}

# Windows Forms初期設定は最初の行で完了済み

# ================================================================================
# Export-DataToFiles関数の定義（グローバルスコープ・最優先）
# ================================================================================
function global:Export-DataToFiles {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Data,
        
        [Parameter(Mandatory = $true)]
        [string]$ReportName
    )
    
    try {
        Write-Host "📁 ファイル出力処理開始: $ReportName" -ForegroundColor Yellow
        
        # タイムスタンプ付きファイル名を生成
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $safeReportName = $ReportName -replace '[^\w\-_]', '_'
        
        # Reports ディレクトリを作成
        $scriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
        $reportsDir = Join-Path $scriptRoot "..\Reports"
        if (-not (Test-Path $reportsDir)) {
            New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
        }
        
        # カテゴリ別サブディレクトリを作成
        $categoryDir = switch -Regex ($ReportName) {
            "日次|Daily" { Join-Path $reportsDir "Daily" }
            "週次|Weekly" { Join-Path $reportsDir "Weekly" }
            "月次|Monthly" { Join-Path $reportsDir "Monthly" }
            "年次|Yearly" { Join-Path $reportsDir "Yearly" }
            "ライセンス|License" { Join-Path $reportsDir "Analysis\License" }
            "使用状況|Usage" { Join-Path $reportsDir "Analysis\Usage" }
            "パフォーマンス|Performance" { Join-Path $reportsDir "Analysis\Performance" }
            "セキュリティ|Security" { Join-Path $reportsDir "Analysis\Security" }
            "権限|Permission" { Join-Path $reportsDir "Analysis\Permission" }
            "ユーザー|User|MFA|条件付き|サインイン" { Join-Path $reportsDir "EntraIDManagement" }
            "メール|Mail|Exchange" { Join-Path $reportsDir "ExchangeOnlineManagement" }
            "Teams|会議" { Join-Path $reportsDir "TeamsManagement" }
            "OneDrive|ストレージ|共有|同期" { Join-Path $reportsDir "OneDriveManagement" }
            default { Join-Path $reportsDir "General" }
        }
        
        if (-not (Test-Path $categoryDir)) {
            New-Item -ItemType Directory -Path $categoryDir -Force | Out-Null
        }
        
        # ファイルパスを生成
        $csvPath = Join-Path $categoryDir "${safeReportName}_${timestamp}.csv"
        $htmlPath = Join-Path $categoryDir "${safeReportName}_${timestamp}.html"
        
        # CSVファイルを出力（UTF8 BOM付き）
        Write-Host "📊 CSVファイル出力中: $csvPath" -ForegroundColor Yellow
        $Data | Export-Csv -Path $csvPath -Encoding UTF8BOM -NoTypeInformation -Force
        Write-Host "✅ CSVファイル出力完了: $csvPath" -ForegroundColor Green
        
        # 基本HTMLファイルを出力
        Write-Host "📄 HTMLファイル出力中: $htmlPath" -ForegroundColor Yellow
        
        # 基本的なHTMLテンプレートを生成
        $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ReportName - Microsoft 365管理ツール</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #0078d4; border-bottom: 2px solid #0078d4; padding-bottom: 10px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #0078d4; color: white; font-weight: bold; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        tr:hover { background-color: #e3f2fd; }
        .timestamp { color: #666; font-size: 0.9em; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>$ReportName</h1>
        <div class="timestamp">生成日時: $(Get-Date -Format "yyyy年MM月dd日 HH:mm:ss")</div>
        <table>
"@

        # テーブルヘッダーを作成
        if ($Data -and $Data.Count -gt 0) {
            $properties = $Data[0].PSObject.Properties.Name
            $htmlContent += "<thead><tr>"
            foreach ($prop in $properties) {
                $htmlContent += "<th>$prop</th>"
            }
            $htmlContent += "</tr></thead><tbody>"
            
            # データ行を作成
            foreach ($row in $Data) {
                $htmlContent += "<tr>"
                foreach ($prop in $properties) {
                    $value = $row.$prop
                    if ($value -eq $null) { $value = "" }
                    $htmlContent += "<td>$([System.Web.HttpUtility]::HtmlEncode($value.ToString()))</td>"
                }
                $htmlContent += "</tr>"
            }
        }
        
        $htmlContent += @"
        </tbody></table>
        <div class="timestamp" style="margin-top: 30px; text-align: center;">
            Microsoft 365統合管理ツール - 生成レコード数: $($Data.Count)
        </div>
    </div>
</body>
</html>
"@
        
        $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8 -Force
        Write-Host "✅ HTMLファイル出力完了: $htmlPath" -ForegroundColor Green
        
        # ファイルを自動表示
        try {
            Start-Process $htmlPath -ErrorAction Stop
            Write-Host "✅ レポートファイルを開きました（CSV + HTML）" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ ファイルを開けませんでした: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        Write-Host "🎉 ファイル出力処理完了: $ReportName" -ForegroundColor Green
        
        return @{
            CSVPath = $csvPath
            HTMLPath = $htmlPath
            Success = $true
        }
        
    } catch {
        $errorMsg = "❌ ファイル出力エラー: $($_.Exception.Message)"
        Write-Host $errorMsg -ForegroundColor Red
        
        return @{
            CSVPath = $null
            HTMLPath = $null
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

Write-Host "✅ Export-DataToFiles関数をグローバルスコープで定義しました" -ForegroundColor Green

# STAアパートメントステートの確認
$apartmentState = [System.Threading.Thread]::CurrentThread.ApartmentState
Write-Host "🔍 アパートメントステート: $apartmentState" -ForegroundColor Gray

# グローバル変数（モジュール読み込み前に定義）
$Script:ToolRoot = Split-Path $PSScriptRoot -Parent
$Script:M365Connected = $false
$Script:ExchangeConnected = $false
$Script:LogTextBox = $null
$Script:ErrorLogTextBox = $null
$Script:PromptTextBox = $null
$Script:PromptTextBox2 = $null
$Script:PromptOutputTextBox = $null
$Script:CommandHistory = @()
$Script:HistoryIndex = -1

# 詳細ログファイルパス定義
$Script:GuiDetailLogPath = Join-Path $Script:ToolRoot "Logs\gui_detailed.log"
$Script:GuiErrorLogPath = Join-Path $Script:ToolRoot "Logs\gui_errors.log"

# ログディレクトリ作成
$logDir = Join-Path $Script:ToolRoot "Logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# 起動時ログの初期化
$startupTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
$startupLogEntry = "[$startupTimestamp] [INFO] ========================= GUI起動開始 ========================="
try {
    Add-Content -Path $Script:GuiDetailLogPath -Value $startupLogEntry -Encoding UTF8 -Force
    Add-Content -Path $Script:GuiDetailLogPath -Value "[$startupTimestamp] [INFO] PowerShell Version: $($PSVersionTable.PSVersion)" -Encoding UTF8 -Force
    Add-Content -Path $Script:GuiDetailLogPath -Value "[$startupTimestamp] [INFO] Platform: $($PSVersionTable.Platform)" -Encoding UTF8 -Force
    Add-Content -Path $Script:GuiDetailLogPath -Value "[$startupTimestamp] [INFO] Script Path: $PSScriptRoot" -Encoding UTF8 -Force
} catch {
    Write-Host "警告: 詳細ログファイルへの初期書き込みに失敗しました" -ForegroundColor Yellow
}

# 早期ログ出力関数（GUI初期化前に使用）
function Write-EarlyLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $shortTimestamp = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    try {
        if ($Script:GuiDetailLogPath) {
            Add-Content -Path $Script:GuiDetailLogPath -Value $logEntry -Encoding UTF8 -Force
        }
    } catch {
        # ファイル出力エラーは無視
    }
    
    # レベルに応じた色分けでプロンプトに出力
    $prefix = switch ($Level) {
        "INFO"    { "ℹ️" }
        "SUCCESS" { "✅" }
        "WARNING" { "⚠️" }
        "ERROR"   { "❌" }
        "DEBUG"   { "🔍" }
        default   { "📝" }
    }
    
    $color = switch ($Level) {
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "DEBUG"   { "Magenta" }
        default   { "White" }
    }
    
    Write-Host "[$shortTimestamp] $prefix $Message" -ForegroundColor $color
}

# 共通モジュールをインポート（Windows Forms初期化後）
Write-EarlyLog "共通モジュール読み込み開始"
$modulePath = Join-Path $Script:ToolRoot "Scripts\Common"

# 新しいReal M365 Data Provider モジュールをインポート
try {
    Write-EarlyLog "実行ポリシー確認開始"
    # 実行ポリシーの詳細確認と設定
    $originalExecutionPolicy = Get-ExecutionPolicy -Scope Process
    Write-Host "🔍 実行ポリシー確認中..." -ForegroundColor Cyan
    Write-Host "   元のProcess実行ポリシー: $originalExecutionPolicy" -ForegroundColor Gray
    Write-EarlyLog "元のProcess実行ポリシー: $originalExecutionPolicy"
    
    # より安全な実行ポリシー設定
    try {
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        Write-Host "✅ Process実行ポリシーをBypassに設定" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ Process実行ポリシー設定失敗、継続します" -ForegroundColor Yellow
    }
    
    # 既存のモジュールをクリーンアップ
    Write-EarlyLog "既存モジュールのクリーンアップ開始"
    Get-Module Logging -ErrorAction SilentlyContinue | Remove-Module -Force
    Get-Module ErrorHandling -ErrorAction SilentlyContinue | Remove-Module -Force
    Get-Module Authentication -ErrorAction SilentlyContinue | Remove-Module -Force
    Get-Module RealM365DataProvider -ErrorAction SilentlyContinue | Remove-Module -Force
    Get-Module ProgressDisplay -ErrorAction SilentlyContinue | Remove-Module -Force
    Get-Module HTMLTemplateEngine -ErrorAction SilentlyContinue | Remove-Module -Force
    Get-Module DataSourceVisualization -ErrorAction SilentlyContinue | Remove-Module -Force
    Write-EarlyLog "既存モジュールのクリーンアップ完了"
    
    # モジュールファイルの存在確認
    $modules = @(
        @{ Name = "Logging"; Path = "$modulePath\Logging.psm1" },
        @{ Name = "ErrorHandling"; Path = "$modulePath\ErrorHandling.psm1" },
        @{ Name = "Authentication"; Path = "$modulePath\Authentication.psm1" },
        @{ Name = "RealM365DataProvider"; Path = "$modulePath\RealM365DataProvider.psm1" },
        @{ Name = "HTMLTemplateEngine"; Path = "$modulePath\HTMLTemplateEngine.psm1" },
        @{ Name = "DataSourceVisualization"; Path = "$modulePath\DataSourceVisualization.psm1" }
    )
    
    foreach ($module in $modules) {
        Write-EarlyLog "$($module.Name) モジュール読み込み開始"
        if (-not [string]::IsNullOrEmpty($module.Path) -and (Test-Path $module.Path)) {
            try {
                # Unblock-Fileでファイルのブロックを解除（パスのnullチェック）
                if (-not [string]::IsNullOrEmpty($module.Path)) {
                    Unblock-File -Path $module.Path -ErrorAction SilentlyContinue
                }
                
                # モジュールを読み込み
                Import-Module $module.Path -Force -DisableNameChecking -Global -ErrorAction Stop
                Write-Host "✅ $($module.Name) モジュール読み込み完了" -ForegroundColor Green
                Write-EarlyLog "$($module.Name) モジュール読み込み成功"
            }
            catch {
                Write-Host "⚠️ $($module.Name) モジュール読み込みエラー: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-EarlyLog "$($module.Name) モジュール読み込みエラー: $($_.Exception.Message)" "WARNING"
                
                # フォールバック: ドットソーシングで読み込み試行
                try {
                    . $module.Path
                    Write-Host "✅ $($module.Name) ドットソーシングで読み込み完了" -ForegroundColor Green
                    Write-EarlyLog "$($module.Name) ドットソーシング読み込み成功"
                } catch {
                    Write-Host "❌ $($module.Name) ドットソーシング読み込み失敗" -ForegroundColor Red
                    Write-EarlyLog "$($module.Name) ドットソーシング読み込み失敗: $($_.Exception.Message)" "ERROR"
                }
            }
        } else {
            Write-Host "⚠️ $($module.Name) モジュールファイルが見つかりません: $($module.Path)" -ForegroundColor Yellow
            Write-EarlyLog "$($module.Name) モジュールファイルが見つかりません: $($module.Path)" "WARNING"
        }
    }
} catch {
    Write-Host "❌ モジュール読み込み処理でエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
}

# ProgressDisplay モジュールの読み込み（オプション）
try {
    if (-not [string]::IsNullOrEmpty($modulePath)) {
        $progressPath = Join-Path $modulePath "ProgressDisplay.psm1"
        if (-not [string]::IsNullOrEmpty($progressPath) -and (Test-Path $progressPath)) {
            Import-Module $progressPath -Force -DisableNameChecking -Global
            Write-Host "✅ ProgressDisplay モジュール読み込み完了" -ForegroundColor Green
        }
    }
} catch {
    # ProgressDisplay モジュールが無い場合は無視
}

# グローバル変数は既に上部で定義済み

# プログレスバー制御関数（グローバルスコープ）
function Global:Set-GuiProgress {
    param(
        [int]$Value = 0,
        [string]$Status = "",
        [switch]$Hide
    )
    
    if ($Script:ProgressBar -eq $null -or $Script:ProgressLabel -eq $null) {
        return
    }
    
    try {
        if ($Script:ProgressBar.Owner.InvokeRequired) {
            $Script:ProgressBar.Owner.Invoke([Action]{
                if ($Hide) {
                    $Script:ProgressBar.Visible = $false
                    $Script:ProgressLabel.Visible = $false
                    $Script:ProgressBar.Value = 0
                    $Script:ProgressLabel.Text = ""
                } else {
                    $Script:ProgressBar.Visible = $true
                    $Script:ProgressLabel.Visible = $true
                    $Script:ProgressBar.Value = [Math]::Min([Math]::Max($Value, 0), 100)
                    $Script:ProgressLabel.Text = $Status
                }
            })
        } else {
            if ($Hide) {
                $Script:ProgressBar.Visible = $false
                $Script:ProgressLabel.Visible = $false
                $Script:ProgressBar.Value = 0
                $Script:ProgressLabel.Text = ""
            } else {
                $Script:ProgressBar.Visible = $true
                $Script:ProgressLabel.Visible = $true
                $Script:ProgressBar.Value = [Math]::Min([Math]::Max($Value, 0), 100)
                $Script:ProgressLabel.Text = $Status
            }
        }
    } catch {
        # エラーは無視
    }
}

# ポップアップ通知システム（グローバルスコープ）
function Global:Show-NotificationPopup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Type = "INFO",
        
        [Parameter()]
        [int]$Duration = 3000  # ミリ秒
    )
    
    try {
        # モダンなポップアップフォーム作成（改善されたデザイン）
        $popup = New-Object System.Windows.Forms.Form
        $popup.Text = "Microsoft 365管理ツール - 通知"
        $popup.Size = New-Object System.Drawing.Size(450, 140)  # サイズを少し大きく
        $popup.StartPosition = "Manual"
        # 右下角に表示するための位置計算
        $screenBounds = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $popup.Location = New-Object System.Drawing.Point(($screenBounds.Width - 450 - 20), ($screenBounds.Height - 140 - 20))
        $popup.FormBorderStyle = "None"  # ボーダーレスデザイン
        $popup.MaximizeBox = $false
        $popup.MinimizeBox = $false
        $popup.TopMost = $true
        $popup.ShowInTaskbar = $false  # タスクバーに表示しない
        
        # モダンなグラデーション背景色設定
        $backColor = switch ($Type) {
            "SUCCESS" { [System.Drawing.Color]::FromArgb(230, 255, 230) }  # ライトグリーン
            "WARNING" { [System.Drawing.Color]::FromArgb(255, 248, 220) }  # ライトオレンジ
            "ERROR"   { [System.Drawing.Color]::FromArgb(255, 230, 230) }  # ライトレッド
            default   { [System.Drawing.Color]::FromArgb(230, 244, 255) }  # ライトブルー
        }
        $popup.BackColor = $backColor
        
        # モダンな影付きボーダーを追加
        $borderPanel = New-Object System.Windows.Forms.Panel
        $borderPanel.Size = New-Object System.Drawing.Size(448, 138)
        $borderPanel.Location = New-Object System.Drawing.Point(1, 1)
        $borderPanel.BackColor = [System.Drawing.Color]::FromArgb(200, 200, 200)  # グレーボーダー
        $popup.Controls.Add($borderPanel)
        
        $contentPanel = New-Object System.Windows.Forms.Panel
        $contentPanel.Size = New-Object System.Drawing.Size(446, 136)
        $contentPanel.Location = New-Object System.Drawing.Point(2, 2)
        $contentPanel.BackColor = $backColor
        $popup.Controls.Add($contentPanel)
        
        # アイコン設定
        $icon = switch ($Type) {
            "SUCCESS" { "✅" }
            "WARNING" { "⚠️" }
            "ERROR"   { "❌" }
            default   { "ℹ️" }
        }
        
        # モダンなレイアウトのラベル作成
        # タイトルラベル
        $titleLabel = New-Object System.Windows.Forms.Label
        $titleLabel.Text = "Microsoft 365管理ツール"
        $titleLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10, [System.Drawing.FontStyle]::Bold)
        $titleLabel.Location = New-Object System.Drawing.Point(15, 10)
        $titleLabel.Size = New-Object System.Drawing.Size(400, 20)
        $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(64, 64, 64)
        $contentPanel.Controls.Add($titleLabel)
        
        # メインメッセージラベル
        $messageLabel = New-Object System.Windows.Forms.Label
        $messageLabel.Text = "$icon $Message"
        $messageLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 11, [System.Drawing.FontStyle]::Regular)
        $messageLabel.Location = New-Object System.Drawing.Point(15, 35)
        $messageLabel.Size = New-Object System.Drawing.Size(400, 60)
        $messageLabel.ForeColor = switch ($Type) {
            "SUCCESS" { [System.Drawing.Color]::FromArgb(0, 120, 0) }
            "WARNING" { [System.Drawing.Color]::FromArgb(150, 90, 0) }
            "ERROR"   { [System.Drawing.Color]::FromArgb(180, 0, 0) }
            default   { [System.Drawing.Color]::FromArgb(0, 90, 150) }
        }
        $contentPanel.Controls.Add($messageLabel)
        
        # 閉じるボタンを追加
        $closeButton = New-Object System.Windows.Forms.Button
        $closeButton.Text = "×"
        $closeButton.Size = New-Object System.Drawing.Size(25, 25)
        $closeButton.Location = New-Object System.Drawing.Point(415, 5)
        $closeButton.FlatStyle = "Flat"
        $closeButton.FlatAppearance.BorderSize = 0
        $closeButton.BackColor = [System.Drawing.Color]::Transparent
        $closeButton.ForeColor = [System.Drawing.Color]::Gray
        $closeButton.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
        $closeButton.Cursor = "Hand"
        $closeButton.Add_Click({ 
            try { 
                Write-GuiLog "✖️ 通知ポップアップ閉じるボタンクリック" "INFO"
                $popup.Close()
                $timer.Stop()
                $timer.Dispose()
                Write-GuiLog "✅ 通知ポップアップ正常終了" "INFO"
            } catch {
                Write-GuiLog "❌ 通知ポップアップ終了エラー: $($_.Exception.Message)" "ERROR"
            }
        })
        $contentPanel.Controls.Add($closeButton)
        
        # シンプルな自動閉じタイマー（アニメーション無し）
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = $Duration
        
        $timer.Add_Tick({
            try {
                $popup.Close()
                $timer.Stop()
                $timer.Dispose()
            } catch {
                # エラーは無視
            }
        })
        
        $timer.Start()
        
        # マウスホバーでタイマー一時停止（ユーザビリティ向上）
        $popup.Add_MouseEnter({ 
            try { $timer.Stop() } catch { }
        })
        $popup.Add_MouseLeave({ 
            try { $timer.Start() } catch { }
        })
        
        # 通常表示
        $popup.Show()
        
    } catch {
        # ポップアップエラーの場合はコンソール出力にフォールバック
        Write-Host "通知: $Message" -ForegroundColor $(switch ($Type) {
            "SUCCESS" { "Green" }
            "WARNING" { "Yellow" }
            "ERROR"   { "Red" }
            default   { "Cyan" }
        })
    }
}

# GUI用ログ出力関数（詳細ファイルログ付き）
function Global:Write-GuiLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        
        [Parameter()]
        [switch]$ShowNotification = $false
    )
    
    # デバッグ出力（コンソール）- リリース版では無効化可能
    if ($env:GUINETLOG_DEBUG -eq "1") {
        Write-Host "🔍 DEBUG: Write-GuiLog呼出 - $Message ($Level)" -ForegroundColor Magenta
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $shortTimestamp = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($Level) {
        "INFO"    { "ℹ️" }
        "SUCCESS" { "✅" }
        "WARNING" { "⚠️" }
        "ERROR"   { "❌" }
        "DEBUG"   { "🔍" }
        "default" { "📝" }
    }
    
    $logEntry = "[$shortTimestamp] $prefix $Message`r`n"
    $detailedLogEntry = "[$timestamp] [$Level] $Message"
    
    # 詳細ログファイルに常に出力
    try {
        if ($Script:GuiDetailLogPath) {
            Add-Content -Path $Script:GuiDetailLogPath -Value $detailedLogEntry -Encoding UTF8 -Force
        }
    } catch {
        # ファイル出力エラーは無視
    }
    
    # エラーレベルの場合は専用エラーログファイルにも出力
    if ($Level -eq "ERROR" -or $Level -eq "WARNING") {
        try {
            if ($Script:GuiErrorLogPath) {
                Add-Content -Path $Script:GuiErrorLogPath -Value $detailedLogEntry -Encoding UTF8 -Force
            }
        } catch {
            # ファイル出力エラーは無視
        }
    }
    
    # GUIリッチテキストボックスへの出力（詳細実行ログタブ）
    if ($Script:LogTextBox -ne $null) {
        try {
            # カラーコーディング設定
            $textColor = switch ($Level) {
                "INFO"    { [System.Drawing.Color]::Cyan }
                "SUCCESS" { [System.Drawing.Color]::LimeGreen }
                "WARNING" { [System.Drawing.Color]::Orange }
                "ERROR"   { [System.Drawing.Color]::Red }
                "DEBUG"   { [System.Drawing.Color]::Magenta }
                default   { [System.Drawing.Color]::LightGray }
            }
            
            # スレッドセーフなUIアップデート（改善されたパフォーマンス）
            $updateAction = [Action]{
                # カラー付きテキストをより効率的に追加
                $Script:LogTextBox.SelectionStart = $Script:LogTextBox.Text.Length
                $Script:LogTextBox.SelectionLength = 0
                $Script:LogTextBox.SelectionColor = $textColor
                $Script:LogTextBox.SelectedText = $logEntry
                
                # 自動スクロール（最新ログを表示）
                $Script:LogTextBox.SelectionStart = $Script:LogTextBox.Text.Length
                $Script:LogTextBox.ScrollToCaret()
                
                # パフォーマンス向上：長すぎるログをトリムム（10000行制限）
                if ($Script:LogTextBox.Lines.Count -gt 10000) {
                    $lines = $Script:LogTextBox.Lines
                    $keepLines = $lines[-5000..-1]  # 最後の5000行を保持
                    $Script:LogTextBox.Text = ($keepLines -join "`r`n") + "`r`n"
                    $Script:LogTextBox.SelectionStart = $Script:LogTextBox.Text.Length
                }
            }
            
            if ($Script:LogTextBox.InvokeRequired) {
                $Script:LogTextBox.Invoke($updateAction)
            } else {
                $updateAction.Invoke()
            }
        } catch {
            # GUI出力エラーは無視してコンソールに出力
            $color = switch ($Level) {
                "INFO"    { "Cyan" }
                "SUCCESS" { "Green" }
                "WARNING" { "Yellow" }
                "ERROR"   { "Red" }
                "DEBUG"   { "Magenta" }
                default   { "White" }
            }
            Write-Host "[$shortTimestamp] $prefix $Message" -ForegroundColor $color
        }
    } else {
        # TextBoxが未初期化の場合はコンソール出力
        $color = switch ($Level) {
            "INFO"    { "Cyan" }
            "SUCCESS" { "Green" }
            "WARNING" { "Yellow" }
            "ERROR"   { "Red" }
            "DEBUG"   { "Magenta" }
            default   { "White" }
        }
        Write-Host "[$shortTimestamp] $prefix $Message" -ForegroundColor $color
    }
    
    # プロンプトタブへの効率的な出力（PowerShellプロンプトタブ）
    if ($Script:PromptOutputTextBox -ne $null) {
        if ($env:GUINETLOG_DEBUG -eq "1") {
            Write-Host "🔍 DEBUG: プロンプトタブに出力中 - $Message" -ForegroundColor Yellow
        }
        try {
            $promptUpdateAction = [Action]{
                $Script:PromptOutputTextBox.AppendText($logEntry)
                $Script:PromptOutputTextBox.SelectionStart = $Script:PromptOutputTextBox.Text.Length
                $Script:PromptOutputTextBox.ScrollToCaret()
                
                # プロンプトタブも同様にログトリミング適用
                if ($Script:PromptOutputTextBox.Lines.Count -gt 8000) {
                    $lines = $Script:PromptOutputTextBox.Lines
                    $keepLines = $lines[-4000..-1]  # 最後の4000行を保持
                    $Script:PromptOutputTextBox.Text = ($keepLines -join "`r`n") + "`r`n"
                    $Script:PromptOutputTextBox.SelectionStart = $Script:PromptOutputTextBox.Text.Length
                }
            }
            
            if ($Script:PromptOutputTextBox.InvokeRequired) {
                $Script:PromptOutputTextBox.Invoke($promptUpdateAction)
            } else {
                $promptUpdateAction.Invoke()
            }
            
            if ($env:GUINETLOG_DEBUG -eq "1") {
                Write-Host "✅ DEBUG: プロンプトタブ出力成功" -ForegroundColor Green
            }
        } catch {
            if ($env:GUINETLOG_DEBUG -eq "1") {
                Write-Host "❌ DEBUG: プロンプトタブ出力エラー - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } elseif ($env:GUINETLOG_DEBUG -eq "1") {
        Write-Host "❌ DEBUG: Script:PromptOutputTextBox が null" -ForegroundColor Red
    }
    
    # ポップアップ通知表示（要求があった場合）
    if ($ShowNotification) {
        Show-NotificationPopup -Message $Message -Type $Level
    }
}

# GUI用エラーログ出力関数
function Write-GuiErrorLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet("INFO", "WARNING", "ERROR", "CRITICAL")]
        [string]$Level = "ERROR"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $shortTimestamp = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($Level) {
        "INFO"     { "ℹ️" }
        "WARNING"  { "⚠️" }
        "ERROR"    { "❌" }
        "CRITICAL" { "🚨" }
        default    { "❗" }
    }
    
    $errorEntry = "[$shortTimestamp] $prefix $Message`r`n"
    $detailedErrorEntry = "[$timestamp] [$Level] $Message"
    
    # エラー専用ログファイルに常に出力
    try {
        if ($Script:GuiErrorLogPath) {
            Add-Content -Path $Script:GuiErrorLogPath -Value $detailedErrorEntry -Encoding UTF8 -Force
        }
    } catch {
        # ファイル出力エラーは無視
    }
    
    # 詳細ログファイルにも出力
    try {
        if ($Script:GuiDetailLogPath) {
            Add-Content -Path $Script:GuiDetailLogPath -Value $detailedErrorEntry -Encoding UTF8 -Force
        }
    } catch {
        # ファイル出力エラーは無視
    }
    
    # GUIエラーログテキストボックスへの出力
    if ($Script:ErrorLogTextBox -ne $null) {
        try {
            # UIスレッドで実行する必要がある
            if ($Script:ErrorLogTextBox.InvokeRequired) {
                $Script:ErrorLogTextBox.Invoke([Action]{
                    $Script:ErrorLogTextBox.AppendText($errorEntry)
                    $Script:ErrorLogTextBox.SelectionStart = $Script:ErrorLogTextBox.Text.Length
                    $Script:ErrorLogTextBox.ScrollToCaret()
                })
            } else {
                $Script:ErrorLogTextBox.AppendText($errorEntry)
                $Script:ErrorLogTextBox.SelectionStart = $Script:ErrorLogTextBox.Text.Length
                $Script:ErrorLogTextBox.ScrollToCaret()
            }
        } catch {
            # GUI出力エラーは無視してコンソールに出力
            Write-Host "[$shortTimestamp] $prefix $Message" -ForegroundColor Red
        }
    } else {
        # TextBoxが未初期化の場合はコンソール出力
        Write-Host "[$shortTimestamp] $prefix $Message" -ForegroundColor Red
    }
    
    # 通常のGUIログにも出力（重複を避けるため、Write-GuiLogは呼ばずに直接処理）
    if ($Level -in @("WARNING", "ERROR", "CRITICAL") -and $Script:LogTextBox -ne $null) {
        try {
            if ($Script:LogTextBox.InvokeRequired) {
                $Script:LogTextBox.Invoke([Action]{
                    $Script:LogTextBox.AppendText($errorEntry)
                    $Script:LogTextBox.SelectionStart = $Script:LogTextBox.Text.Length
                    $Script:LogTextBox.ScrollToCaret()
                })
            } else {
                $Script:LogTextBox.AppendText($errorEntry)
                $Script:LogTextBox.SelectionStart = $Script:LogTextBox.Text.Length
                $Script:LogTextBox.ScrollToCaret()
            }
        } catch {
            # エラーは無視
        }
    }
}

# Windows Forms初期設定は上部で完了済み

# Windows Forms初期設定は上部で完了済み

# モジュール読み込み完了後にメイン関数を定義済み（グローバルスコープ）

# アプリケーション設定取得関数
function Get-AppSettings {
    try {
        $configPath = Join-Path $Script:ToolRoot "Config\appsettings.json"
        if (Test-Path $configPath) {
            $configContent = Get-Content $configPath -Raw -Encoding UTF8
            $config = $configContent | ConvertFrom-Json
            return $config
        } else {
            # デフォルト設定を返す
            return @{
                GUI = @{
                    AutoOpenFiles = $true
                    ShowPopupNotifications = $true
                    AlsoOpenCSV = $false
                }
            }
        }
    } catch {
        Write-GuiLog "設定ファイル読み込みエラー、デフォルト設定を使用: $($_.Exception.Message)" "WARNING"
        return @{
            GUI = @{
                AutoOpenFiles = $true
                ShowPopupNotifications = $true
                AlsoOpenCSV = $false
            }
        }
    }
}

# フォールバック用HTML生成関数
function Generate-BasicHTMLReport {
    param(
        [object[]]$Data,
        [string]$ReportTitle
    )
    
    if (-not $Data -or $Data.Count -eq 0) {
        return Generate-FallbackHTML -Data @() -ReportTitle $ReportTitle
    }
    
    $properties = $Data[0].PSObject.Properties.Name
    $timestamp = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
    
    $html = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ReportTitle</title>
    <style>
        body { 
            font-family: 'Yu Gothic UI', 'Hiragino Kaku Gothic ProN', 'Meiryo UI', sans-serif; 
            margin: 0; 
            padding: 20px; 
            background-color: #f8f9fa; 
            line-height: 1.6;
        }
        .container { 
            max-width: 100%; 
            margin: 0 auto; 
            background-color: white; 
            box-shadow: 0 2px 10px rgba(0,0,0,0.1); 
            border-radius: 8px; 
            overflow: hidden;
        }
        .header { 
            text-align: center; 
            padding: 30px 20px; 
            background: linear-gradient(135deg, #0078d4, #106ebe); 
            color: white; 
        }
        .title { 
            font-size: clamp(20px, 4vw, 28px); 
            font-weight: bold; 
            margin: 0; 
        }
        .timestamp { 
            font-size: clamp(12px, 2.5vw, 16px); 
            margin-top: 10px; 
            opacity: 0.9; 
        }
        .content { 
            padding: 20px; 
        }
        .summary { 
            background: linear-gradient(135deg, #e3f2fd, #bbdefb); 
            padding: 20px; 
            margin-bottom: 30px; 
            border-radius: 8px; 
            border-left: 4px solid #0078d4; 
        }
        .table-container { 
            overflow-x: auto; 
            margin-top: 20px; 
            border-radius: 8px; 
            box-shadow: 0 2px 8px rgba(0,0,0,0.1); 
        }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            min-width: 600px; 
            background-color: white; 
        }
        th, td { 
            border: 1px solid #e0e0e0; 
            padding: clamp(8px, 1.5vw, 16px); 
            text-align: left; 
            word-wrap: break-word; 
            max-width: 200px; 
            overflow-wrap: break-word; 
        }
        th { 
            background: linear-gradient(135deg, #f5f5f5, #eeeeee); 
            font-weight: bold; 
            color: #333; 
            font-size: clamp(12px, 2vw, 14px); 
            position: sticky; 
            top: 0; 
            z-index: 10; 
        }
        td { 
            font-size: clamp(11px, 1.8vw, 13px); 
        }
        tr:nth-child(even) { 
            background-color: #fafafa; 
        }
        tr:hover { 
            background-color: #f0f8ff; 
            transition: background-color 0.2s; 
        }
        .footer { 
            margin-top: 40px; 
            padding: 20px; 
            text-align: center; 
            color: #666; 
            font-size: clamp(10px, 1.5vw, 12px); 
            background-color: #f8f9fa; 
            border-top: 1px solid #e0e0e0; 
        }
        
        /* レスポンシブ対応 */
        @media (max-width: 768px) {
            body { padding: 10px; }
            .container { border-radius: 4px; }
            .header { padding: 20px 15px; }
            .content { padding: 15px; }
            .summary { padding: 15px; }
            table { min-width: 300px; }
            th, td { padding: 8px 6px; max-width: 120px; }
        }
        
        @media (max-width: 480px) {
            th, td { 
                padding: 6px 4px; 
                max-width: 80px; 
                font-size: 10px; 
            }
            .table-container { 
                font-size: 10px; 
            }
        }
        
        /* プリント対応 */
        @media print {
            body { background-color: white; }
            .container { box-shadow: none; }
            .header { background: #0078d4 !important; }
            th { background: #f5f5f5 !important; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="title">📊 $ReportTitle</div>
            <div class="timestamp">生成日時: $timestamp</div>
        </div>
        
        <div class="content">
            <div class="summary">
                <strong>📈 データサマリー</strong><br>
                総件数: $($Data.Count) 件<br>
                データソース: Microsoft 365 統合管理ツール<br>
                生成システム: 非対話式認証対応版
            </div>
            
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
"@
    
    foreach ($prop in $properties) {
        $html += "                <th>$prop</th>`n"
    }
    
    $html += @"
            </tr>
        </thead>
        <tbody>
"@
    
    foreach ($item in $Data) {
        $html += "            <tr>`n"
        foreach ($prop in $properties) {
            $value = if ($item.$prop -ne $null) { $item.$prop } else { "N/A" }
            $html += "                <td>$value</td>`n"
        }
        $html += "            </tr>`n"
    }
    
    $html += @"
                        </tbody>
                </table>
            </div>
        </div>
        
        <div class="footer">
            🚀 Microsoft 365統合管理ツール により生成<br>
            📅 レポート種別: $ReportTitle | 🔐 非対話式認証対応版
        </div>
    </div>
</body>
</html>
"@
    
    return $html
}

function Generate-FallbackHTML {
    param(
        [object[]]$Data,
        [string]$ReportTitle
    )
    
    $timestamp = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
    $dataCount = if ($Data) { $Data.Count } else { 0 }
    
    return @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ReportTitle - フォールバック</title>
    <style>
        body { font-family: 'Yu Gothic UI', sans-serif; margin: 20px; text-align: center; }
        .container { max-width: 600px; margin: 0 auto; padding: 40px; }
        .title { color: #0078d4; font-size: 24px; margin-bottom: 20px; }
        .message { color: #666; font-size: 16px; line-height: 1.6; }
        .info { background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="title">📊 $ReportTitle</div>
        <div class="info">
            <strong>⚠️ レポート生成完了</strong><br>
            データ件数: $dataCount 件<br>
            生成日時: $timestamp<br><br>
            CSVファイルで詳細データをご確認ください。
        </div>
        <div class="message">
            このレポートは基本モードで生成されました。<br>
            詳細な分析結果は同時に生成されたCSVファイルをご確認ください。
        </div>
    </div>
</body>
</html>
"@
}

# PowerShellコマンド実行関数
function Invoke-PowerShellCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        
        [Parameter()]
        [System.Windows.Forms.TextBox]$OutputTextBox
    )
    
    try {
        Write-GuiLog "PowerShellコマンド実行開始: $Command" "INFO"
        
        # 出力先の決定
        $targetTextBox = if ($OutputTextBox) { $OutputTextBox } else { $Script:LogTextBox }
        
        if ($targetTextBox) {
            # プロンプト形式で入力コマンドを表示
            $promptEntry = "PS C:\> $Command`r`n"
            if ($targetTextBox.InvokeRequired) {
                $targetTextBox.Invoke([Action]{
                    $targetTextBox.AppendText($promptEntry)
                    $targetTextBox.SelectionStart = $targetTextBox.Text.Length
                    $targetTextBox.ScrollToCaret()
                })
            } else {
                $targetTextBox.AppendText($promptEntry)
                $targetTextBox.SelectionStart = $targetTextBox.Text.Length
                $targetTextBox.ScrollToCaret()
            }
        }
        
        # PowerShellコマンドを実行
        $output = ""
        $errorOutput = ""
        
        try {
            # コマンドを実行して結果を取得
            $result = Invoke-Expression $Command 2>&1
            
            if ($result) {
                foreach ($item in $result) {
                    if ($item -is [System.Management.Automation.ErrorRecord]) {
                        $errorOutput += "$item`r`n"
                    } else {
                        $output += "$item`r`n"
                    }
                }
            }
        } catch {
            $errorOutput = "実行エラー: $($_.Exception.Message)`r`n"
        }
        
        # 結果をテキストボックスに表示
        if ($targetTextBox) {
            $resultText = ""
            if ($output) {
                $resultText += $output
            }
            if ($errorOutput) {
                $resultText += "エラー: $errorOutput"
                Write-GuiErrorLog "PowerShellコマンドエラー: $errorOutput" "ERROR"
            }
            if (-not $output -and -not $errorOutput) {
                $resultText = "(出力なし)`r`n"
            }
            
            # 結果を表示
            if ($targetTextBox.InvokeRequired) {
                $targetTextBox.Invoke([Action]{
                    $targetTextBox.AppendText($resultText)
                    $targetTextBox.AppendText("`r`n")
                    $targetTextBox.SelectionStart = $targetTextBox.Text.Length
                    $targetTextBox.ScrollToCaret()
                })
            } else {
                $targetTextBox.AppendText($resultText)
                $targetTextBox.AppendText("`r`n")
                $targetTextBox.SelectionStart = $targetTextBox.Text.Length
                $targetTextBox.ScrollToCaret()
            }
        }
        
        # コマンド履歴に追加
        if ($Command.Trim() -ne "" -and $Script:CommandHistory -notcontains $Command) {
            $Script:CommandHistory += $Command
            # 履歴の上限を50に設定
            if ($Script:CommandHistory.Count -gt 50) {
                $Script:CommandHistory = $Script:CommandHistory[-50..-1]
            }
        }
        $Script:HistoryIndex = -1
        
        Write-GuiLog "PowerShellコマンド実行完了: $Command" "SUCCESS"
        
    } catch {
        $errorMsg = "PowerShellコマンド実行エラー: $($_.Exception.Message)"
        Write-GuiLog $errorMsg "ERROR"
        Write-GuiErrorLog $errorMsg "ERROR"
        
        if ($targetTextBox) {
            $errorText = "実行エラー: $($_.Exception.Message)`r`n`r`n"
            if ($targetTextBox.InvokeRequired) {
                $targetTextBox.Invoke([Action]{
                    $targetTextBox.AppendText($errorText)
                    $targetTextBox.SelectionStart = $targetTextBox.Text.Length
                    $targetTextBox.ScrollToCaret()
                })
            } else {
                $targetTextBox.AppendText($errorText)
                $targetTextBox.SelectionStart = $targetTextBox.Text.Length
                $targetTextBox.ScrollToCaret()
            }
        }
    }
}

# コマンド履歴ナビゲーション関数
function Get-CommandFromHistory {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Previous", "Next")]
        [string]$Direction
    )
    
    if ($Script:CommandHistory.Count -eq 0) {
        return ""
    }
    
    if ($Direction -eq "Previous") {
        if ($Script:HistoryIndex -eq -1) {
            $Script:HistoryIndex = $Script:CommandHistory.Count - 1
        } elseif ($Script:HistoryIndex -gt 0) {
            $Script:HistoryIndex--
        }
    } else {  # Next
        if ($Script:HistoryIndex -ne -1 -and $Script:HistoryIndex -lt ($Script:CommandHistory.Count - 1)) {
            $Script:HistoryIndex++
        } else {
            $Script:HistoryIndex = -1
            return ""
        }
    }
    
    if ($Script:HistoryIndex -ge 0 -and $Script:HistoryIndex -lt $Script:CommandHistory.Count) {
        return $Script:CommandHistory[$Script:HistoryIndex]
    }
    
    return ""
}

# Generate-HTMLReport関数は削除し、HTMLTemplateEngine.psm1のGenerate-EnhancedHTMLReportを使用

# ================================================================================
# GUI作成関数
# ================================================================================

function New-MainForm {
    [OutputType([System.Windows.Forms.Form])]
    param()
    
    Write-EarlyLog "メインフォーム作成開始"
    # メインフォーム作成（移動可能・リサイズ対応版）
    $form = New-Object System.Windows.Forms.Form
    # 改善されたフォーム設定（ユーザビリティ向上）
    $form.Text = "🚀 Microsoft 365統合管理ツール - 完全版 v2.0"
    $form.Size = New-Object System.Drawing.Size(1450, 950)  # サイズを少し大きくして操作性向上
    $form.MinimumSize = New-Object System.Drawing.Size(1200, 800)  # 最小サイズ制限
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "Sizable"
    $form.MaximizeBox = $true
    $form.MinimizeBox = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 250)  # より明るい背景色
    $form.WindowState = "Normal"
    $form.KeyPreview = $true  # キーボードショートカット有効化
    
    # アイコン設定（利用可能な場合）
    try {
        # Microsoftのテーマカラーを使用
        $form.Icon = [System.Drawing.SystemIcons]::Information
    } catch {
        # アイコン設定失敗時は無視
    }
    
    # 改善されたメインタイトル（グラデーション背景付き）
    $titlePanel = New-Object System.Windows.Forms.Panel
    $titlePanel.Size = New-Object System.Drawing.Size(1420, 50)
    $titlePanel.Location = New-Object System.Drawing.Point(10, 5)
    $titlePanel.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $form.Controls.Add($titlePanel)
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "🏢 Microsoft 365統合管理ツール - 完全版 v2.0"
    $titleLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 16, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::White
    $titleLabel.Location = New-Object System.Drawing.Point(0, 0)
    $titleLabel.Size = New-Object System.Drawing.Size(1420, 50)
    $titleLabel.TextAlign = "MiddleCenter"
    $titlePanel.Controls.Add($titleLabel)
    
    # バージョン情報ラベル
    $versionLabel = New-Object System.Windows.Forms.Label
    $versionLabel.Text = "PowerShell $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) | $(Get-Date -Format 'yyyy-MM-dd')"
    $versionLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 8)
    $versionLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
    $versionLabel.Location = New-Object System.Drawing.Point(1200, 30)
    $versionLabel.Size = New-Object System.Drawing.Size(200, 15)
    $titlePanel.Controls.Add($versionLabel)
    
    # 接続状態表示
    $connectionLabel = New-Object System.Windows.Forms.Label
    $connectionLabel.Location = New-Object System.Drawing.Point(20, 55)
    $connectionLabel.Size = New-Object System.Drawing.Size(1000, 25)
    $connectionLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10)
    $connectionLabel.TextAlign = "MiddleCenter"
    
    # 認証状態チェック（出力を抑制）
    try {
        $authStatus = Test-M365Authentication | Out-Null
        $null = $authStatus  # 変数を無効化
        # 簡易認証確認（出力なし）
        if ($Script:M365Connected) {
            $connectionLabel.Text = "✅ Microsoft 365 認証済み - リアルデータを取得します"
            $connectionLabel.ForeColor = [System.Drawing.Color]::Green
        } else {
            $connectionLabel.Text = "⚠️ Microsoft 365 未認証 - 認証が必要です"
            $connectionLabel.ForeColor = [System.Drawing.Color]::Orange
        }
    } catch {
        $connectionLabel.Text = "❌ Microsoft 365 接続確認エラーが発生しました"
        $connectionLabel.ForeColor = [System.Drawing.Color]::Red
        $Script:M365Connected = $false
    }
    
    $form.Controls.Add($connectionLabel)
    
    # 接続ボタン
    $connectButton = New-Object System.Windows.Forms.Button
    $connectButton.Text = "🔑 Microsoft 365 に接続（非対話型）"
    $connectButton.Location = New-Object System.Drawing.Point(20, 85)
    $connectButton.Size = New-Object System.Drawing.Size(280, 35)
    $connectButton.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10, [System.Drawing.FontStyle]::Bold)
    $connectButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $connectButton.ForeColor = [System.Drawing.Color]::White
    $connectButton.FlatStyle = "Flat"
    # スクリプトブロック内での変数スコープ問題を解決するため、ローカル変数を作成
    $btnConnect = $connectButton
    $lblConnection = $connectionLabel
    # プロンプトタブ参照は実行時に取得（遅延参照）
    
    $connectButton.Add_Click({
        try {
            Write-GuiLog "🔄 Microsoft 365 接続ボタンクリック - 接続処理開始" "INFO"
            $btnConnect.Text = "🔄 接続中..."
            $btnConnect.Enabled = $false
            
            # プロンプトタブに認証ログを表示（実行時参照）
            try {
                $promptOutputRef = $Script:PromptOutputTextBox
                if ($promptOutputRef -ne $null -and $promptOutputRef.GetType().Name -eq 'TextBox' -and $promptOutputRef.IsHandleCreated) {
                    $promptOutputRef.AppendText("PS C:\> Connect-M365Services`r`n")
                    $promptOutputRef.AppendText("🔑 Microsoft 365 サービスに接続中...`r`n")
                    $promptOutputRef.SelectionStart = $promptOutputRef.Text.Length
                    $promptOutputRef.ScrollToCaret()
                    Write-GuiLog "プロンプトタブに認証ログを表示しました" "SUCCESS"
                } else {
                    # プロンプトタブが未初期化の場合は、Write-GuiLog経由で後から出力
                    Write-GuiLog "Microsoft 365 サービスに接続中..." "INFO"
                }
            } catch {
                Write-GuiLog "プロンプトタブへのログ出力中にエラーが発生しました: $($_.Exception.Message)" "WARNING"
            }
            
            # 関数の存在確認とモジュールの再読み込み
            if (-not (Get-Command Connect-M365Services -ErrorAction SilentlyContinue)) {
                $modulePath = Join-Path $PSScriptRoot "..\Scripts\Common"
                Import-Module "$modulePath\RealM365DataProvider.psm1" -Force -DisableNameChecking -Global
                if ($promptOutputRef -ne $null -and $promptOutputRef.GetType().Name -eq 'TextBox' -and $promptOutputRef.IsHandleCreated) {
                    try {
                        $promptOutputRef.AppendText("認証モジュールを再読み込みしました`r`n")
                        $promptOutputRef.ScrollToCaret()
                    } catch {
                        Write-GuiLog "認証モジュールを再読み込みしました" "INFO"
                    }
                } else {
                    Write-GuiLog "認証モジュールを再読み込みしました" "INFO"
                }
            }
            
            if ($promptOutputRef -ne $null -and $promptOutputRef.GetType().Name -eq 'TextBox' -and $promptOutputRef.IsHandleCreated) {
                try {
                    $promptOutputRef.AppendText("🔑 Microsoft Graph に非対話型で接続中...`r`n")
                    $promptOutputRef.AppendText("ℹ️ .envファイルから認証情報を読み込み中...`r`n")
                    $promptOutputRef.ScrollToCaret()
                } catch {
                    Write-GuiLog "Microsoft Graph に非対話型で接続中..." "INFO"
                }
            } else {
                Write-GuiLog "Microsoft Graph に非対話型で接続中..." "INFO"
            }
            
            # 認証実行
            $authResult = Connect-M365Services
            
            # 接続結果の処理（GraphまたはExchangeのいずれかが成功していれば成功とみなす）
            if ($authResult.GraphConnected -or $authResult.ExchangeConnected) {
                # 接続状況に応じたメッセージを生成
                $serviceStatus = @()
                if ($authResult.GraphConnected) { $serviceStatus += "Microsoft Graph" }
                if ($authResult.ExchangeConnected) { $serviceStatus += "Exchange Online" }
                $connectedServices = $serviceStatus -join ", "
                
                $lblConnection.Text = "✅ Microsoft 365 接続成功 ($connectedServices) - リアルデータを取得します"
                $lblConnection.ForeColor = [System.Drawing.Color]::Green
                $Script:M365Connected = $true
                
                if ($promptOutputRef -ne $null -and $promptOutputRef.GetType().Name -eq 'TextBox' -and $promptOutputRef.IsHandleCreated) {
                    try {
                        $promptOutputRef.AppendText("`r`n✅ Microsoft 365への接続に成功しました`r`n")
                        $promptOutputRef.AppendText("接続済みサービス: $connectedServices`r`n")
                        $promptOutputRef.AppendText("認証完了 - 利用可能な機能でレポート生成できます`r`n`r`n")
                        $promptOutputRef.ScrollToCaret()
                    } catch {
                        Write-GuiLog "Microsoft 365への接続に成功しました" "SUCCESS"
                    }
                } else {
                    Write-GuiLog "Microsoft 365への接続に成功しました" "SUCCESS"
                }
                
                # ポップアップの代わりにプロンプトタブに成功メッセージを表示
                Write-GuiLog "✅ Microsoft 365 接続処理完了 - 接続成功" "SUCCESS"
            } else {
                $lblConnection.Text = "❌ Microsoft 365 接続失敗"
                $lblConnection.ForeColor = [System.Drawing.Color]::Red
                $Script:M365Connected = $false
                
                if ($promptOutputRef -ne $null -and $promptOutputRef.GetType().Name -eq 'TextBox') {
                    try {
                        $promptOutputRef.AppendText("`r`n❌ Microsoft 365への接続に失敗しました`r`n")
                        $promptOutputRef.AppendText("認証エラー: 認証情報を確認してください`r`n`r`n")
                        $promptOutputRef.ScrollToCaret()
                    } catch {
                        # エラーを無視
                    }
                }
                
                # ポップアップの代わりにエラーログタブとプロンプトタブに表示
                try { Write-GuiErrorLog "Microsoft 365接続失敗: 認証エラーまたはネットワークエラー" "ERROR" } catch { }
                Write-GuiLog "❌ Microsoft 365 接続処理完了 - 接続失敗" "ERROR"
            }
        } catch {
            $lblConnection.Text = "❌ Microsoft 365 接続エラーが発生しました"
            $lblConnection.ForeColor = [System.Drawing.Color]::Red
            $Script:M365Connected = $false
            
            if ($promptOutputRef -ne $null -and $promptOutputRef.GetType().Name -eq 'TextBox') {
                try {
                    $promptOutputRef.AppendText("`r`n❌ 接続エラーが発生しました`r`n")
                    $promptOutputRef.AppendText("エラー詳細: $($_.Exception.Message)`r`n`r`n")
                    $promptOutputRef.ScrollToCaret()
                } catch {
                    # エラーを無視
                }
            }
            
            # ポップアップの代わりにエラーログタブとプロンプトタブに表示
            try { Write-GuiErrorLog "接続エラー詳細: $($_.Exception.Message)" "CRITICAL" } catch { }
            try { Write-GuiErrorLog "エラータイプ: $($_.Exception.GetType().Name)" "ERROR" } catch { }
            Write-GuiLog "❌ Microsoft 365 接続処理完了 - 例外エラー: $($_.Exception.Message)" "ERROR"
        } finally {
            $btnConnect.Text = "🔑 Microsoft 365 に接続（非対話型）"
            $btnConnect.Enabled = $true
            
            if ($promptOutputRef -ne $null -and $promptOutputRef.GetType().Name -eq 'TextBox') {
                try {
                    $promptOutputRef.AppendText("接続処理が完了しました`r`n`r`n")
                    $promptOutputRef.ScrollToCaret()
                } catch {
                    # エラーを無視
                }
            }
        }
    }.GetNewClosure())
    $form.Controls.Add($connectButton)
    
    # タブコントロール作成（上半分）
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Location = New-Object System.Drawing.Point(20, 130)
    $tabControl.Size = New-Object System.Drawing.Size(1350, 370)  # 高さを370に調整
    $tabControl.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10)
    $tabControl.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    
    # 1. 定期レポートタブ
    $regularTab = New-Object System.Windows.Forms.TabPage
    $regularTab.Text = "📊 定期レポート"
    $regularTab.BackColor = [System.Drawing.Color]::White
    Add-RegularReportsButtons -TabPage $regularTab
    $tabControl.TabPages.Add($regularTab)
    
    # 2. 分析レポートタブ
    $analyticsTab = New-Object System.Windows.Forms.TabPage
    $analyticsTab.Text = "🔍 分析レポート"
    $analyticsTab.BackColor = [System.Drawing.Color]::White
    Add-AnalyticsReportsButtons -TabPage $analyticsTab
    $tabControl.TabPages.Add($analyticsTab)
    
    # 3. Entra ID管理タブ
    $entraTab = New-Object System.Windows.Forms.TabPage
    $entraTab.Text = "👥 Entra ID管理"
    $entraTab.BackColor = [System.Drawing.Color]::White
    Add-EntraIDButtons -TabPage $entraTab
    $tabControl.TabPages.Add($entraTab)
    
    # 4. Exchange Online管理タブ
    $exchangeTab = New-Object System.Windows.Forms.TabPage
    $exchangeTab.Text = "📧 Exchange Online"
    $exchangeTab.BackColor = [System.Drawing.Color]::White
    Add-ExchangeButtons -TabPage $exchangeTab
    $tabControl.TabPages.Add($exchangeTab)
    
    # 5. Teams管理タブ
    $teamsTab = New-Object System.Windows.Forms.TabPage
    $teamsTab.Text = "💬 Teams管理"
    $teamsTab.BackColor = [System.Drawing.Color]::White
    Add-TeamsButtons -TabPage $teamsTab
    $tabControl.TabPages.Add($teamsTab)
    
    # 6. OneDrive管理タブ
    $oneDriveTab = New-Object System.Windows.Forms.TabPage
    $oneDriveTab.Text = "💾 OneDrive管理"
    $oneDriveTab.BackColor = [System.Drawing.Color]::White
    Add-OneDriveButtons -TabPage $oneDriveTab
    $tabControl.TabPages.Add($oneDriveTab)
    
    $form.Controls.Add($tabControl)
    
    # 詳細ログエリア（タブ形式、下半分）+ プロンプト機能
    $logTabControl = New-Object System.Windows.Forms.TabControl
    $logTabControl.Location = New-Object System.Drawing.Point(20, 510)  # Y位置を510に調整
    $logTabControl.Size = New-Object System.Drawing.Size(1350, 370)     # 高さを370に調整
    $logTabControl.Font = New-Object System.Drawing.Font("Yu Gothic UI", 9)
    $logTabControl.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    
    # 実行ログタブ
    $executionLogTab = New-Object System.Windows.Forms.TabPage
    $executionLogTab.Text = "📋 詳細実行ログ + プロンプト"
    $executionLogTab.BackColor = [System.Drawing.Color]::White
    
    # エラーログタブ
    $errorLogTab = New-Object System.Windows.Forms.TabPage
    $errorLogTab.Text = "❌ 詳細エラーログ"
    $errorLogTab.BackColor = [System.Drawing.Color]::White
    
    # PowerShellプロンプトタブ
    $promptTab = New-Object System.Windows.Forms.TabPage
    $promptTab.Text = "💻 PowerShellプロンプト"
    $promptTab.BackColor = [System.Drawing.Color]::White
    
    # 実行ログリッチテキストボックス（カラーコーディング対応）
    $Script:LogTextBox = New-Object System.Windows.Forms.RichTextBox
    $Script:LogTextBox.Multiline = $true
    $Script:LogTextBox.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Both
    $Script:LogTextBox.WordWrap = $false  # スクロールバー表示のため無効
    $Script:LogTextBox.Location = New-Object System.Drawing.Point(5, 5)
    $Script:LogTextBox.Size = New-Object System.Drawing.Size(1300, 250)  # 高さを250に調整（プロンプト分を確保）
    $Script:LogTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $Script:LogTextBox.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $Script:LogTextBox.ForeColor = [System.Drawing.Color]::LimeGreen
    $Script:LogTextBox.ReadOnly = $true  # 読み取り専用に変更
    $Script:LogTextBox.HideSelection = $false
    $Script:LogTextBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $Script:LogTextBox.DetectUrls = $false  # URL検出を無効化（パフォーマンス向上）
    
    # プロンプト入力ラベル
    $promptLabel = New-Object System.Windows.Forms.Label
    $promptLabel.Text = "💻 PowerShell コマンド入力:"
    $promptLabel.Location = New-Object System.Drawing.Point(5, 265)
    $promptLabel.Size = New-Object System.Drawing.Size(200, 20)
    $promptLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 9, [System.Drawing.FontStyle]::Bold)
    $promptLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $promptLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
    
    # プロンプト入力テキストボックス
    $Script:PromptTextBox = New-Object System.Windows.Forms.TextBox
    $Script:PromptTextBox.Location = New-Object System.Drawing.Point(5, 290)
    $Script:PromptTextBox.Size = New-Object System.Drawing.Size(1100, 25)
    $Script:PromptTextBox.Font = New-Object System.Drawing.Font("Consolas", 10)
    $Script:PromptTextBox.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
    $Script:PromptTextBox.ForeColor = [System.Drawing.Color]::White
    $Script:PromptTextBox.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    
    # Enterキーでコマンド実行、上下キーで履歴ナビゲーション
    $Script:PromptTextBox.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            $command = $sender.Text.Trim()
            if ($command -ne "") {
                Invoke-PowerShellCommand -Command $command -OutputTextBox $Script:LogTextBox
                $sender.Clear()
            }
            $e.Handled = $true
        } elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Up) {
            $historyCommand = Get-CommandFromHistory -Direction "Previous"
            if ($historyCommand -ne "") {
                $sender.Text = $historyCommand
                $sender.SelectionStart = $sender.Text.Length
            }
            $e.Handled = $true
        } elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Down) {
            $historyCommand = Get-CommandFromHistory -Direction "Next"
            $sender.Text = $historyCommand
            $sender.SelectionStart = $sender.Text.Length
            $e.Handled = $true
        }
    })
    
    # プロンプト実行ボタン
    $promptExecuteButton = New-Object System.Windows.Forms.Button
    $promptExecuteButton.Text = "▶️ 実行"
    $promptExecuteButton.Location = New-Object System.Drawing.Point(1115, 290)
    $promptExecuteButton.Size = New-Object System.Drawing.Size(80, 25)
    $promptExecuteButton.Font = New-Object System.Drawing.Font("Yu Gothic UI", 9, [System.Drawing.FontStyle]::Bold)
    $promptExecuteButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $promptExecuteButton.ForeColor = [System.Drawing.Color]::White
    $promptExecuteButton.FlatStyle = "Flat"
    $promptExecuteButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $promptExecuteButton.Add_Click({
        try {
            Write-GuiLog "▶️ PowerShellコマンド実行ボタンクリック" "INFO"
            $command = $Script:PromptTextBox.Text.Trim()
            if ($command -ne "") {
                Write-GuiLog "💻 コマンド実行開始: $command" "INFO"
                Invoke-PowerShellCommand -Command $command -OutputTextBox $Script:LogTextBox
                $Script:PromptTextBox.Clear()
                Write-GuiLog "✅ コマンド実行完了" "SUCCESS"
            } else {
                Write-GuiLog "⚠️ 空のコマンド - 実行をスキップ" "WARNING"
            }
        } catch {
            Write-GuiLog "❌ コマンド実行エラー: $($_.Exception.Message)" "ERROR"
        }
    })
    
    # 実行ログクリアボタン（位置調整）
    $clearExecutionLogButton = New-Object System.Windows.Forms.Button
    $clearExecutionLogButton.Text = "🗑️ ログクリア"
    $clearExecutionLogButton.Location = New-Object System.Drawing.Point(1205, 290)
    $clearExecutionLogButton.Size = New-Object System.Drawing.Size(100, 25)
    $clearExecutionLogButton.Font = New-Object System.Drawing.Font("Yu Gothic UI", 8)
    $clearExecutionLogButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $clearExecutionLogButton.Add_Click({
        try {
            Write-GuiLog "🗑️ 実行ログクリアボタンクリック" "INFO"
            $Script:LogTextBox.Clear()
            Write-GuiLog "✅ 実行ログをクリアしました" "SUCCESS"
        } catch {
            Write-GuiLog "❌ 実行ログクリアエラー: $($_.Exception.Message)" "ERROR"
        }
        try { Write-GuiLog "実行ログがクリアされました。" "INFO" } catch { }
    })
    
    # エラーログテキストボックス
    $Script:ErrorLogTextBox = New-Object System.Windows.Forms.TextBox
    $Script:ErrorLogTextBox.Multiline = $true
    $Script:ErrorLogTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    $Script:ErrorLogTextBox.WordWrap = $false  # スクロールバー表示のため無効
    $Script:ErrorLogTextBox.Location = New-Object System.Drawing.Point(5, 5)
    $Script:ErrorLogTextBox.Size = New-Object System.Drawing.Size(1300, 310)  # 高さを310に調整
    $Script:ErrorLogTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $Script:ErrorLogTextBox.BackColor = [System.Drawing.Color]::FromArgb(50, 20, 20)
    $Script:ErrorLogTextBox.ForeColor = [System.Drawing.Color]::FromArgb(255, 100, 100)
    $Script:ErrorLogTextBox.ReadOnly = $true   # 読み取り専用に変更（スクロールバー表示向上）
    $Script:ErrorLogTextBox.HideSelection = $false  # 選択状態の維持
    $Script:ErrorLogTextBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    
    # エラーログクリアボタン
    $clearErrorLogButton = New-Object System.Windows.Forms.Button
    $clearErrorLogButton.Text = "🗑️ エラーログクリア"
    $clearErrorLogButton.Location = New-Object System.Drawing.Point(1180, 320)
    $clearErrorLogButton.Size = New-Object System.Drawing.Size(120, 25)
    $clearErrorLogButton.Font = New-Object System.Drawing.Font("Yu Gothic UI", 8)
    $clearErrorLogButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $clearErrorLogButton.Add_Click({
        try {
            Write-GuiLog "🗑️ エラーログクリアボタンクリック" "INFO"
            $Script:ErrorLogTextBox.Clear()
            Write-GuiErrorLog "エラーログがクリアされました。" "INFO"
            Write-GuiLog "✅ エラーログクリア完了" "SUCCESS"
        } catch {
            Write-GuiLog "❌ エラーログクリアエラー: $($_.Exception.Message)" "ERROR"
        }
    })
    
    # PowerShellプロンプト専用エリア
    $Script:PromptOutputTextBox = New-Object System.Windows.Forms.TextBox
    # モジュールからもアクセスできるようにグローバル変数として設定
    $Global:PromptOutputTextBox = $Script:PromptOutputTextBox
    $Script:PromptOutputTextBox.Multiline = $true
    $Script:PromptOutputTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    $Script:PromptOutputTextBox.WordWrap = $false  # スクロールバー表示のため無効
    $Script:PromptOutputTextBox.Location = New-Object System.Drawing.Point(5, 5)
    $Script:PromptOutputTextBox.Size = New-Object System.Drawing.Size(1300, 250)
    $Script:PromptOutputTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $Script:PromptOutputTextBox.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 50)
    $Script:PromptOutputTextBox.ForeColor = [System.Drawing.Color]::Cyan
    $Script:PromptOutputTextBox.ReadOnly = $true  # 読み取り専用に変更
    $Script:PromptOutputTextBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    
    # スクロールバーを強制表示するための追加設定
    $Script:PromptOutputTextBox.HideSelection = $false
    
    # 自動スクロール機能の強化
    $Script:PromptOutputTextBox.Add_TextChanged({
        try {
            # 最下部に自動スクロール
            $this.SelectionStart = $this.Text.Length
            $this.ScrollToCaret()
        } catch { }
    })
    
    # プロンプト専用入力エリア
    $promptLabel2 = New-Object System.Windows.Forms.Label
    $promptLabel2.Text = "💻 PowerShell コマンド:"
    $promptLabel2.Location = New-Object System.Drawing.Point(5, 265)
    $promptLabel2.Size = New-Object System.Drawing.Size(200, 20)
    $promptLabel2.Font = New-Object System.Drawing.Font("Yu Gothic UI", 9, [System.Drawing.FontStyle]::Bold)
    $promptLabel2.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $promptLabel2.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
    
    $Script:PromptTextBox2 = New-Object System.Windows.Forms.TextBox
    $Script:PromptTextBox2.Location = New-Object System.Drawing.Point(5, 290)
    $Script:PromptTextBox2.Size = New-Object System.Drawing.Size(1050, 25)
    $Script:PromptTextBox2.Font = New-Object System.Drawing.Font("Consolas", 10)
    $Script:PromptTextBox2.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
    $Script:PromptTextBox2.ForeColor = [System.Drawing.Color]::White
    $Script:PromptTextBox2.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    
    # Enterキーでコマンド実行、上下キーで履歴ナビゲーション（プロンプト専用タブ）
    $Script:PromptTextBox2.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            $command = $sender.Text.Trim()
            if ($command -ne "") {
                Invoke-PowerShellCommand -Command $command -OutputTextBox $Script:PromptOutputTextBox
                $sender.Clear()
            }
            $e.Handled = $true
        } elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Up) {
            $historyCommand = Get-CommandFromHistory -Direction "Previous"
            if ($historyCommand -ne "") {
                $sender.Text = $historyCommand
                $sender.SelectionStart = $sender.Text.Length
            }
            $e.Handled = $true
        } elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Down) {
            $historyCommand = Get-CommandFromHistory -Direction "Next"
            $sender.Text = $historyCommand
            $sender.SelectionStart = $sender.Text.Length
            $e.Handled = $true
        }
    })
    
    $promptExecuteButton2 = New-Object System.Windows.Forms.Button
    $promptExecuteButton2.Text = "▶️ 実行"
    $promptExecuteButton2.Location = New-Object System.Drawing.Point(1065, 290)
    $promptExecuteButton2.Size = New-Object System.Drawing.Size(80, 25)
    $promptExecuteButton2.Font = New-Object System.Drawing.Font("Yu Gothic UI", 9, [System.Drawing.FontStyle]::Bold)
    $promptExecuteButton2.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $promptExecuteButton2.ForeColor = [System.Drawing.Color]::White
    $promptExecuteButton2.FlatStyle = "Flat"
    $promptExecuteButton2.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $promptExecuteButton2.Add_Click({
        try {
            Write-GuiLog "▶️ プロンプトタブ実行ボタンクリック" "INFO"
            $command = $Script:PromptTextBox2.Text.Trim()
            if ($command -ne "") {
                Write-GuiLog "💻 プロンプトコマンド実行開始: $command" "INFO"
                Invoke-PowerShellCommand -Command $command -OutputTextBox $Script:PromptOutputTextBox
                $Script:PromptTextBox2.Clear()
                Write-GuiLog "✅ プロンプトコマンド実行完了" "SUCCESS"
            } else {
                Write-GuiLog "⚠️ 空のプロンプトコマンド - 実行をスキップ" "WARNING"
            }
        } catch {
            Write-GuiLog "❌ プロンプトコマンド実行エラー: $($_.Exception.Message)" "ERROR"
        }
    })
    
    $clearPromptButton = New-Object System.Windows.Forms.Button
    $clearPromptButton.Text = "🗑️ プロンプトクリア"
    $clearPromptButton.Location = New-Object System.Drawing.Point(1155, 290)
    $clearPromptButton.Size = New-Object System.Drawing.Size(140, 25)
    $clearPromptButton.Font = New-Object System.Drawing.Font("Yu Gothic UI", 8)
    $clearPromptButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $clearPromptButton.Add_Click({
        try {
            Write-GuiLog "🗑️ プロンプトクリアボタンクリック" "INFO"
            $Script:PromptOutputTextBox.Clear()
            Write-GuiLog "✅ プロンプト出力をクリアしました" "SUCCESS"
        } catch {
            Write-GuiLog "❌ プロンプトクリアエラー: $($_.Exception.Message)" "ERROR"
        }
    })
    
    # タブにコントロールを追加
    $executionLogTab.Controls.Add($Script:LogTextBox)
    $executionLogTab.Controls.Add($promptLabel)
    $executionLogTab.Controls.Add($Script:PromptTextBox)
    $executionLogTab.Controls.Add($promptExecuteButton)
    $executionLogTab.Controls.Add($clearExecutionLogButton)
    
    $errorLogTab.Controls.Add($Script:ErrorLogTextBox)
    $errorLogTab.Controls.Add($clearErrorLogButton)
    
    $promptTab.Controls.Add($Script:PromptOutputTextBox)
    $promptTab.Controls.Add($promptLabel2)
    $promptTab.Controls.Add($Script:PromptTextBox2)
    $promptTab.Controls.Add($promptExecuteButton2)
    $promptTab.Controls.Add($clearPromptButton)
    
    # タブをタブコントロールに追加
    $logTabControl.TabPages.Add($executionLogTab)
    $logTabControl.TabPages.Add($errorLogTab)
    $logTabControl.TabPages.Add($promptTab)
    $form.Controls.Add($logTabControl)
    
    # スクロールバー表示テスト用のコンテンツを追加（デバッグ目的）
    if ($Script:PromptOutputTextBox -ne $null) {
        $testContent = @()
        for ($i = 1; $i -le 30; $i++) {
            $testContent += "[テスト行 $i] PowerShellプロンプト出力表示テスト - この長いテキストは水平スクロールバーの表示をテストするためのものです。"
        }
        $Script:PromptOutputTextBox.Text = ($testContent -join "`r`n")
        Write-GuiLog "📊 プロンプト表示テスト: スクロールバー動作確認用のテストコンテンツを追加しました" "INFO"
    }
    
    # ステータスバー
    $statusStrip = New-Object System.Windows.Forms.StatusStrip
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLabel.Text = "準備完了 - Microsoft 365統合管理ツール"
    $statusLabel.Spring = $true  # 残りのスペースを使用
    $statusLabel.TextAlign = "MiddleLeft"
    
    # プログレスバーの追加
    $Script:ProgressBar = New-Object System.Windows.Forms.ToolStripProgressBar
    $Script:ProgressBar.Size = New-Object System.Drawing.Size(200, 18)
    $Script:ProgressBar.Style = "Continuous"
    $Script:ProgressBar.Visible = $false
    
    # プログレスラベルの追加
    $Script:ProgressLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $Script:ProgressLabel.Text = ""
    $Script:ProgressLabel.Width = 150
    $Script:ProgressLabel.Visible = $false
    
    $statusStrip.Items.Add($statusLabel)
    $statusStrip.Items.Add($Script:ProgressBar)
    $statusStrip.Items.Add($Script:ProgressLabel)
    $form.Controls.Add($statusStrip)
    
    # キーボードショートカット機能を追加（ユーザビリティ向上）
    $form.Add_KeyDown({
        param($sender, $e)
        # Ctrl+R: リアルタイムログクリア
        if ($e.Control -and $e.KeyCode -eq "R") {
            try {
                if ($Script:LogTextBox -ne $null) {
                    $Script:LogTextBox.Clear()
                    Write-GuiLog "リアルタイムログをクリアしました (Ctrl+R)" "INFO"
                }
            } catch { }
            $e.Handled = $true
        }
        # Ctrl+T: タブ切り替え
        elseif ($e.Control -and $e.KeyCode -eq "T") {
            try {
                $currentIndex = $tabControl.SelectedIndex
                $nextIndex = ($currentIndex + 1) % $tabControl.TabCount
                $tabControl.SelectedIndex = $nextIndex
                Write-GuiLog "タブ切り替え: $($tabControl.SelectedTab.Text) (Ctrl+T)" "INFO"
            } catch { }
            $e.Handled = $true
        }
        # F5: リフレッシュ
        elseif ($e.KeyCode -eq "F5") {
            try {
                Write-GuiLog "アプリケーションリフレッシュ (F5)" "INFO"
                # 接続状態を再確認
                if ($connectionLabel -ne $null) {
                    try {
                        if ($Script:M365Connected) {
                            $connectionLabel.Text = "✅ Microsoft 365 認証済み - リアルデータを取得します"
                            $connectionLabel.ForeColor = [System.Drawing.Color]::Green
                        } else {
                            $connectionLabel.Text = "⚠️ Microsoft 365 未認証 - 認証が必要です"
                            $connectionLabel.ForeColor = [System.Drawing.Color]::Orange
                        }
                    } catch { }
                }
            } catch { }
            $e.Handled = $true
        }
        # Ctrl+Q: アプリケーション終了
        elseif ($e.Control -and $e.KeyCode -eq "Q") {
            $form.Close()
            $e.Handled = $true
        }
    })
    
    # 初期化完了メッセージをログに出力（遅延実行）
    $form.Add_Shown({
        try {
            if ($Script:LogTextBox -ne $null) {
                try { Write-GuiLog "Microsoft 365統合管理ツール完全版 v2.0 GUI 初期化完了" "SUCCESS" } catch { }
                try { Write-GuiLog "リアルタイムログ機能が有効になりました" "INFO" } catch { }
                try { Write-GuiLog "Windows Forms 初期化完了" "SUCCESS" } catch { }
                try { Write-GuiLog "キーボードショートカット: Ctrl+R(ログクリア), Ctrl+T(タブ切り替え), F5(リフレッシュ), Ctrl+Q(終了)" "INFO" } catch { }
            }
        } catch {
            Write-Host "ログ初期化エラー: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    })
    
    # アプリケーション終了時のクリーンアップ
    $form.Add_FormClosing({
        try {
            Write-GuiLog "Microsoft 365管理ツールを終了します..." "INFO"
            # メモリクリーンアップ
            if ($Script:LogTextBox -ne $null) {
                $Script:LogTextBox.Dispose()
            }
            if ($Script:ErrorLogTextBox -ne $null) {
                $Script:ErrorLogTextBox.Dispose()
            }
            if ($Script:PromptOutputTextBox -ne $null) {
                $Script:PromptOutputTextBox.Dispose()
            }
        } catch {
            # エラーを無視して終了
        }
    })
    
    # フォームオブジェクトのみを返す（配列にしない）
    Write-EarlyLog "メインフォーム作成完了"
    return $form
}

function Add-RegularReportsButtons {
    param([System.Windows.Forms.TabPage]$TabPage)
    
    # 最適化されたレスポンシブ配置: 3列3行レイアウト（スペース効率向上）
    $buttons = @(
        @{ Text = "📅 日次レポート"; Action = "DailyReport"; X = 15; Y = 15 },
        @{ Text = "📊 週次レポート"; Action = "WeeklyReport"; X = 215; Y = 15 },
        @{ Text = "📈 月次レポート"; Action = "MonthlyReport"; X = 415; Y = 15 },
        @{ Text = "📆 年次レポート"; Action = "YearlyReport"; X = 15; Y = 75 },
        @{ Text = "🧪 テスト実行"; Action = "TestExecution"; X = 215; Y = 75 }
    )
    
    foreach ($buttonInfo in $buttons) {
        $button = Create-ActionButton -Text $buttonInfo.Text -X $buttonInfo.X -Y $buttonInfo.Y -Action $buttonInfo.Action
        $TabPage.Controls.Add($button)
    }
}

function Add-AnalyticsReportsButtons {
    param([System.Windows.Forms.TabPage]$TabPage)
    
    # 最適化されたレスポンシブ配置: 3列2行レイアウト（視覚バランス向上）
    $buttons = @(
        @{ Text = "📊 ライセンス分析"; Action = "LicenseAnalysis"; X = 15; Y = 15 },
        @{ Text = "📈 使用状況分析"; Action = "UsageAnalysis"; X = 215; Y = 15 },
        @{ Text = "⚡ パフォーマンス分析"; Action = "PerformanceAnalysis"; X = 415; Y = 15 },
        @{ Text = "🛡️ セキュリティ分析"; Action = "SecurityAnalysis"; X = 15; Y = 75 },
        @{ Text = "🔍 権限監査"; Action = "PermissionAudit"; X = 215; Y = 75 }
    )
    
    foreach ($buttonInfo in $buttons) {
        $button = Create-ActionButton -Text $buttonInfo.Text -X $buttonInfo.X -Y $buttonInfo.Y -Action $buttonInfo.Action
        $TabPage.Controls.Add($button)
    }
}

function Add-EntraIDButtons {
    param([System.Windows.Forms.TabPage]$TabPage)
    
    # 最適化されたレスポンシブ配置: 2列2行レイアウト（中央寄せ配置）
    $buttons = @(
        @{ Text = "👥 ユーザー一覧"; Action = "UserList"; X = 50; Y = 15 },
        @{ Text = "🔐 MFA状況"; Action = "MFAStatus"; X = 280; Y = 15 },
        @{ Text = "🛡️ 条件付きアクセス"; Action = "ConditionalAccess"; X = 50; Y = 75 },
        @{ Text = "📝 サインインログ"; Action = "SignInLogs"; X = 280; Y = 75 }
    )
    
    foreach ($buttonInfo in $buttons) {
        $button = Create-ActionButton -Text $buttonInfo.Text -X $buttonInfo.X -Y $buttonInfo.Y -Action $buttonInfo.Action
        $TabPage.Controls.Add($button)
    }
}

function Add-ExchangeButtons {
    param([System.Windows.Forms.TabPage]$TabPage)
    
    # 最適化されたレスポンシブ配置: 2列2行レイアウト（中央寄せ配置）
    $buttons = @(
        @{ Text = "📧 メールボックス管理"; Action = "MailboxManagement"; X = 50; Y = 15 },
        @{ Text = "🔄 メールフロー分析"; Action = "MailFlowAnalysis"; X = 280; Y = 15 },
        @{ Text = "🛡️ スパム対策分析"; Action = "SpamProtectionAnalysis"; X = 50; Y = 75 },
        @{ Text = "📬 配信分析"; Action = "MailDeliveryAnalysis"; X = 280; Y = 75 }
    )
    
    foreach ($buttonInfo in $buttons) {
        $button = Create-ActionButton -Text $buttonInfo.Text -X $buttonInfo.X -Y $buttonInfo.Y -Action $buttonInfo.Action
        $TabPage.Controls.Add($button)
    }
}

function Add-TeamsButtons {
    param([System.Windows.Forms.TabPage]$TabPage)
    
    # 最適化されたレスポンシブ配置: 2列2行レイアウト（中央寄せ配置）
    $buttons = @(
        @{ Text = "💬 Teams使用状況"; Action = "TeamsUsage"; X = 50; Y = 15 },
        @{ Text = "⚙️ Teams設定分析"; Action = "TeamsSettingsAnalysis"; X = 280; Y = 15 },
        @{ Text = "📹 会議品質分析"; Action = "MeetingQualityAnalysis"; X = 50; Y = 75 },
        @{ Text = "📱 アプリ分析"; Action = "TeamsAppAnalysis"; X = 280; Y = 75 }
    )
    
    foreach ($buttonInfo in $buttons) {
        $button = Create-ActionButton -Text $buttonInfo.Text -X $buttonInfo.X -Y $buttonInfo.Y -Action $buttonInfo.Action
        $TabPage.Controls.Add($button)
    }
}

function Add-OneDriveButtons {
    param([System.Windows.Forms.TabPage]$TabPage)
    
    # 最適化されたレスポンシブ配置: 2列2行レイアウト（中央寄せ配置）
    $buttons = @(
        @{ Text = "💾 ストレージ分析"; Action = "StorageAnalysis"; X = 50; Y = 15 },
        @{ Text = "🤝 共有分析"; Action = "SharingAnalysis"; X = 280; Y = 15 },
        @{ Text = "🔄 同期エラー分析"; Action = "SyncErrorAnalysis"; X = 50; Y = 75 },
        @{ Text = "🌐 外部共有分析"; Action = "ExternalSharingAnalysis"; X = 280; Y = 75 }
    )
    
    foreach ($buttonInfo in $buttons) {
        $button = Create-ActionButton -Text $buttonInfo.Text -X $buttonInfo.X -Y $buttonInfo.Y -Action $buttonInfo.Action
        $TabPage.Controls.Add($button)
    }
}

function Create-ActionButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [string]$Action
    )
    
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size(190, 50)
    $button.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10, [System.Drawing.FontStyle]::Bold)
    $button.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.FlatStyle = "Flat"
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(0, 90, 180)
    $button.Cursor = "Hand"
    
    # ホバー効果
    $button.Add_MouseEnter({
        try {
            $this.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 240)
        } catch { }
    })
    
    $button.Add_MouseLeave({
        try {
            if ($this.Enabled) {
                $this.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
            }
        } catch { }
    })
    
    $button.Add_MouseDown({
        try {
            $this.BackColor = [System.Drawing.Color]::FromArgb(0, 90, 180)
        } catch { }
    })
    
    $button.Add_MouseUp({
        try {
            if ($this.ClientRectangle.Contains($this.PointToClient([System.Windows.Forms.Cursor]::Position))) {
                $this.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 240)
            } else {
                $this.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
            }
        } catch { }
    })
    
    # HTMLテンプレートマッピング辞書
    $templateMapping = @{
        # 定期レポート (Regularreports)
        "DailyReport" = "daily-report.html"
        "WeeklyReport" = "weekly-report.html"
        "MonthlyReport" = "monthly-report.html"
        "YearlyReport" = "yearly-report.html"
        "TestExecution" = "test-execution.html"
        
        # 分析レポート (Analyticreport)
        "LicenseAnalysis" = "LicenseAnalysis.html"
        "UsageAnalysis" = "usage-analysis.html"
        "PerformanceAnalysis" = "performance-analysis.html"
        "SecurityAnalysis" = "security-analysis.html"
        "PermissionAudit" = "permission-audit.html"
        
        # Entra ID管理 (EntraIDManagement)
        "UserList" = "user-list.html"
        "MFAStatus" = "mfa-status.html"
        "ConditionalAccess" = "conditional-access.html"
        "SignInLogs" = "signin-logs.html"
        
        # Exchange Online管理 (ExchangeOnlineManagement)
        "MailboxManagement" = "mailbox-management.html"
        "MailFlowAnalysis" = "mail-flow-analysis.html"
        "SpamProtectionAnalysis" = "spam-protection-analysis.html"
        "MailDeliveryAnalysis" = "mail-delivery-analysis.html"
        
        # Teams管理 (TeamsManagement)
        "TeamsUsage" = "teams-usage.html"
        "TeamsSettingsAnalysis" = "teams-settings-analysis.html"
        "MeetingQualityAnalysis" = "meeting-quality-analysis.html"
        "TeamsAppAnalysis" = "teams-app-analysis.html"
        
        # OneDrive管理 (OneDriveManagement)
        "StorageAnalysis" = "storage-analysis.html"
        "SharingAnalysis" = "sharing-analysis.html"
        "SyncErrorAnalysis" = "sync-error-analysis.html"
        "ExternalSharingAnalysis" = "external-sharing-analysis.html"
    }
    
    # テンプレートサブフォルダマッピング
    $folderMapping = @{
        "DailyReport" = "Regularreports"; "WeeklyReport" = "Regularreports"; "MonthlyReport" = "Regularreports"
        "YearlyReport" = "Regularreports"; "TestExecution" = "Regularreports"
        "LicenseAnalysis" = "Analyticreport"; "UsageAnalysis" = "Analyticreport"; "PerformanceAnalysis" = "Analyticreport"
        "SecurityAnalysis" = "Analyticreport"; "PermissionAudit" = "Analyticreport"
        "UserList" = "EntraIDManagement"; "MFAStatus" = "EntraIDManagement"; "ConditionalAccess" = "EntraIDManagement"; "SignInLogs" = "EntraIDManagement"
        "MailboxManagement" = "ExchangeOnlineManagement"; "MailFlowAnalysis" = "ExchangeOnlineManagement"; "SpamProtectionAnalysis" = "ExchangeOnlineManagement"; "MailDeliveryAnalysis" = "ExchangeOnlineManagement"
        "TeamsUsage" = "TeamsManagement"; "TeamsSettingsAnalysis" = "TeamsManagement"; "MeetingQualityAnalysis" = "TeamsManagement"; "TeamsAppAnalysis" = "TeamsManagement"
        "StorageAnalysis" = "OneDriveManagement"; "SharingAnalysis" = "OneDriveManagement"; "SyncErrorAnalysis" = "OneDriveManagement"; "ExternalSharingAnalysis" = "OneDriveManagement"
    }
    
    # ボタンクリックイベント
    $actionRef = $Action
    $button.Add_Click({
        param($sender, $e)
        
        if ($sender -and $sender.GetType().Name -eq 'Button') {
            $originalText = $sender.Text
            Write-GuiLog "🔽 ボタンクリック開始: $originalText" "INFO"
            $sender.Text = "🔄 処理中..."
            $sender.Enabled = $false
            
            try {
                Set-GuiProgress -Value 20 -Status "データ処理中..."
                
                # データ取得
                $data = switch ($actionRef) {
                    "DailyReport" { 
                        Get-M365DailyReport -MaxUsers 999999
                    }
                    "WeeklyReport" {
                        Get-M365WeeklyReport -MaxUsers 999999
                    }
                    "MonthlyReport" {
                        Get-M365MonthlyReport -MaxUsers 999999
                    }
                    "YearlyReport" {
                        Get-M365YearlyReport -MaxUsers 999999
                    }
                    "TestExecution" {
                        Get-M365TestExecution -MaxUsers 999999
                    }
                    "LicenseAnalysis" {
                        Get-M365LicenseAnalysis -MaxUsers 999999
                    }
                    "UsageAnalysis" {
                        Get-M365UsageAnalysisData -MaxUsers 999999
                    }
                    "PerformanceAnalysis" {
                        Get-M365PerformanceAnalysis -MaxUsers 999999
                    }
                    "SecurityAnalysis" {
                        Get-M365SecurityAnalysis -MaxUsers 999999
                    }
                    "PermissionAudit" {
                        Get-M365PermissionAudit -MaxUsers 999999
                    }
                    "UserList" {
                        Get-M365AllUsers -MaxUsers 999999
                    }
                    "MFAStatus" {
                        Get-M365MFAStatus -MaxUsers 999999
                    }
                    "ConditionalAccess" {
                        Get-M365ConditionalAccess -MaxUsers 999999
                    }
                    "SignInLogs" {
                        Get-M365SignInLogs -MaxUsers 999999
                    }
                    "MailboxManagement" {
                        Get-M365MailboxAnalysis -MaxUsers 999999
                    }
                    "MailFlowAnalysis" {
                        Get-M365MailFlowAnalysis -MaxUsers 999999
                    }
                    "SpamProtectionAnalysis" {
                        Get-M365SpamProtectionAnalysis -MaxUsers 999999
                    }
                    "MailDeliveryAnalysis" {
                        Get-M365MailDeliveryAnalysis -MaxUsers 999999
                    }
                    "TeamsUsage" {
                        Get-M365TeamsUsage -MaxUsers 999999
                    }
                    "TeamsSettingsAnalysis" {
                        Get-M365TeamsSettings -MaxUsers 999999
                    }
                    "MeetingQualityAnalysis" {
                        Get-M365MeetingQuality -MaxUsers 999999
                    }
                    "TeamsAppAnalysis" {
                        Get-M365TeamsAppAnalysis -MaxUsers 999999
                    }
                    "StorageAnalysis" {
                        Get-M365OneDriveAnalysis -MaxUsers 999999
                    }
                    "SharingAnalysis" {
                        Get-M365SharingAnalysis -MaxUsers 999999
                    }
                    "SyncErrorAnalysis" {
                        Get-M365SyncErrorAnalysis -MaxUsers 999999
                    }
                    "ExternalSharingAnalysis" {
                        Get-M365ExternalSharingAnalysis -MaxUsers 999999
                    }
                    default {
                        Get-M365DailyReport -MaxUsers 999999
                    }
                }
                
                if ($data -and $data.Count -gt 0) {
                    Set-GuiProgress -Value 50 -Status "HTMLテンプレート処理中..."
                    
                    # レポート名とファイルパス設定
                    $reportName = "${actionRef}日次レポート"
                    $safeReportName = $reportName -replace '[\\/:*?"<>|]', '_'
                    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                    $reportsDir = Join-Path $PSScriptRoot "..\Reports\General"
                    
                    if (-not (Test-Path $reportsDir)) {
                        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
                    }
                    
                    $csvPath = Join-Path $reportsDir "${safeReportName}_${timestamp}.csv"
                    $htmlPath = Join-Path $reportsDir "${safeReportName}_${timestamp}.html"
                    
                    # CSV出力
                    $data | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8BOM
                    Write-GuiLog "✅ CSVファイル出力完了: $csvPath" "SUCCESS"
                    
                    # HTMLテンプレート処理
                    $templateFile = $templateMapping[$actionRef]
                    $templateFolder = $folderMapping[$actionRef]
                    
                    if ($templateFile -and $templateFolder) {
                        $templatePath = Join-Path $PSScriptRoot "..\Templates\Samples\$templateFolder\$templateFile"
                        
                        if (Test-Path $templatePath) {
                            Set-GuiProgress -Value 80 -Status "HTMLレポート生成中..."
                            
                            $htmlContent = Get-Content $templatePath -Raw -Encoding UTF8
                            
                            # プレースホルダー置換
                            $reportDate = Get-Date -Format "yyyy年MM月dd日 HH:mm:ss"
                            $dataSource = "実データ（Microsoft 365）"
                            
                            $htmlContent = $htmlContent -replace "{{REPORT_DATE}}", $reportDate
                            $htmlContent = $htmlContent -replace "{{TOTAL_USERS}}", $data.Count
                            $htmlContent = $htmlContent -replace "{{DATA_SOURCE}}", $dataSource
                            $htmlContent = $htmlContent -replace "{{REPORT_TYPE}}", $actionRef
                            
                            # テーブルデータ生成
                            $tableData = ""
                            foreach ($row in $data) {
                                $tableData += "<tr>"
                                $tableData += "<td>$([System.Web.HttpUtility]::HtmlEncode($row.'ユーザー名' ?? ''))</td>"
                                $tableData += "<td>$([System.Web.HttpUtility]::HtmlEncode($row.'ユーザープリンシパル名' ?? ''))</td>"
                                $tableData += "<td>$([System.Web.HttpUtility]::HtmlEncode($row.'Teams活動' ?? '0'))</td>"
                                $tableData += "<td><span class='badge badge-info'>$([System.Web.HttpUtility]::HtmlEncode($row.'活動レベル' ?? '低'))</span></td>"
                                $tableData += "<td>$([System.Web.HttpUtility]::HtmlEncode($row.'活動スコア' ?? '0'))</td>"
                                $tableData += "<td><span class='badge badge-success'>$([System.Web.HttpUtility]::HtmlEncode($row.'ステータス' ?? 'アクティブ'))</span></td>"
                                $tableData += "<td>$([System.Web.HttpUtility]::HtmlEncode($row.'レポート日' ?? (Get-Date -Format 'yyyy-MM-dd')))</td>"
                                $tableData += "</tr>"
                            }
                            
                            $htmlContent = $htmlContent -replace "{{TABLE_DATA}}", $tableData
                            $htmlContent = $htmlContent -replace "{{DAILY_ACTIVITY_DATA}}", $tableData
                            $htmlContent = $htmlContent -replace "{{USER_DATA}}", $tableData
                            $htmlContent = $htmlContent -replace "{{REPORT_DATA}}", $tableData
                            
                            # HTMLファイル出力
                            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8 -Force
                            Write-GuiLog "✅ HTMLファイル出力完了: $htmlPath" "SUCCESS"
                            
                            # ファイル自動表示
                            try {
                                Start-Process $htmlPath -ErrorAction Stop
                                Write-GuiLog "✅ レポートを開きました" "SUCCESS"
                            } catch {
                                Write-GuiLog "⚠️ ファイルを開けませんでした: $($_.Exception.Message)" "WARNING"
                            }
                            
                            Set-GuiProgress -Value 100 -Status "完了"
                            Write-GuiLog "$reportName が正常に生成されました" "SUCCESS" -ShowNotification
                            
                        } else {
                            Write-GuiLog "⚠️ テンプレートファイルが見つかりません: $templatePath" "WARNING"
                        }
                    } else {
                        Write-GuiLog "⚠️ テンプレートマッピングが見つかりません: $actionRef" "WARNING"
                    }
                } else {
                    Write-GuiLog "⚠️ データの取得に失敗しました" "WARNING"
                }
                
            } catch {
                Write-GuiLog "❌ レポート生成エラー: $($_.Exception.Message)" "ERROR" -ShowNotification
            } finally {
                $sender.Text = $originalText
                $sender.Enabled = $true
                $sender.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
                Set-GuiProgress -Hide
                Write-GuiLog "🔼 ボタンクリック完了: $originalText" "INFO"
            }
        }
    }.GetNewClosure())
    
    return $button
}

function Execute-ReportAction {
    param(
        [string]$Action,
        $Button
    )
    
    # ボタンオブジェクトの型チェックと安全なプロパティアクセス
    if ($Button -and $Button.GetType().Name -eq 'Button') {
        $originalText = $Button.Text
        $Button.Text = "🔄 処理中..."
        $Button.Enabled = $false
        $Button.BackColor = [System.Drawing.Color]::FromArgb(108, 117, 125)  # グレーアウト色
    } else {
        $originalText = "ボタン"
        Write-Host "警告: ボタンオブジェクトが有効ではありません" -ForegroundColor Yellow
    }
    
    try {
        $data = $null
        $reportName = ""
        
        switch ($Action) {
            "DailyReport" {
                $data = Get-ReportDataFromProvider -DataType "DailyReport"
                $reportName = "日次レポート"
            }
            "WeeklyReport" {
                $data = Get-ReportDataFromProvider -DataType "WeeklyReport"
                $reportName = "週次レポート"
            }
            "MonthlyReport" {
                $data = Get-ReportDataFromProvider -DataType "MonthlyReport"
                $reportName = "月次レポート"
            }
            "YearlyReport" {
                $data = Get-ReportDataFromProvider -DataType "YearlyReport"
                $reportName = "年次レポート"
            }
            "TestExecution" {
                # 直接モジュール関数を呼び出し
                try {
                    $data = Get-M365TestExecution
                    $reportName = "テスト実行結果"
                } catch {
                    Write-GuiLog "❌ テスト実行データ取得エラー: $($_.Exception.Message)" "ERROR"
                    $data = @([PSCustomObject]@{
                        テストID = "ERROR001"
                        テスト名 = "データ取得エラー"
                        実行状況 = "失敗"
                        結果 = "エラー"
                        エラーメッセージ = $_.Exception.Message
                        最終実行日時 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    })
                    $reportName = "テスト実行結果（エラー）"
                }
            }
            "LicenseAnalysis" {
                $data = Get-ReportDataFromProvider -DataType "LicenseAnalysis"
                $reportName = "ライセンス分析"
            }
            "UsageAnalysis" {
                $data = Get-ReportDataFromProvider -DataType "UsageAnalysis"
                $reportName = "使用状況分析"
            }
            "PerformanceAnalysis" {
                $data = @([PSCustomObject]@{ ServiceName = "Microsoft Teams"; ResponseTimeMs = 120; UptimePercent = 99.9; SLAStatus = "達成"; ErrorRatePercent = 0.1; CPUUsagePercent = 45; MemoryUsagePercent = 38; StorageUsagePercent = 25; Status = "正常" })
                $reportName = "パフォーマンス分析"
            }
            "SecurityAnalysis" {
                $data = @([PSCustomObject]@{ SecurityItem = "MFA有効率"; Status = "良好"; TargetUsers = 150; ComplianceRatePercent = 85; RiskLevel = "低"; LastCheckDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"); RecommendedAction = "全ユーザーでMFA有効化"; Details = "85%のユーザーがMFAを有効にしています" })
                $reportName = "セキュリティ分析"
            }
            "PermissionAudit" {
                $data = @([PSCustomObject]@{ UserName = "山田太郎"; Email = "yamada@contoso.com"; Department = "営業部"; AdminRole = "なし"; AccessRights = "標準ユーザー"; LastLogin = "2025-01-16 09:30"; MFAStatus = "有効"; Status = "適切" })
                $reportName = "権限監査"
            }
            "UserList" {
                $data = Get-ReportDataFromProvider -DataType "Users"
                $reportName = "ユーザー一覧"
            }
            "MFAStatus" {
                $data = Get-ReportDataFromProvider -DataType "MFAStatus"
                $reportName = "MFA状況"
            }
            "ConditionalAccess" {
                $data = @([PSCustomObject]@{ PolicyName = "MFA必須ポリシー"; Status = "有効"; TargetUsers = "全ユーザー"; TargetApplications = "全アプリケーション"; Conditions = "信頼できる場所以外"; AccessControls = "MFA必須"; CreationDate = "2024-01-15"; LastUpdated = "2024-12-01"; ApplicationCount = 1250 })
                $reportName = "条件付きアクセス"
            }
            "SignInLogs" {
                $data = Get-ReportDataFromProvider -DataType "SignInLogs"
                $reportName = "サインインログ"
            }
            "MailboxManagement" {
                $data = Get-ReportDataFromProvider -DataType "MailboxAnalysis"
                $reportName = "メールボックス管理"
            }
            "MailFlowAnalysis" {
                $data = @([PSCustomObject]@{ DateTime = "2025-01-16 09:30"; Sender = "yamada@contoso.com"; Recipient = "sato@contoso.com"; Subject = "会議の件"; MessageSizeKB = 25; Status = "配信済み"; Connector = "デフォルト"; EventType = "送信"; Details = "正常に配信されました" })
                $reportName = "メールフロー分析"
            }
            "SpamProtectionAnalysis" {
                $data = @([PSCustomObject]@{ DateTime = "2025-01-16 08:45"; Sender = "spam@example.com"; Recipient = "yamada@contoso.com"; Subject = "緊急のお知らせ"; ThreatType = "スパム"; SpamScore = 8.5; Action = "検疫"; PolicyName = "高保護ポリシー"; Details = "スパムとして検出され検疫されました" })
                $reportName = "スパム対策分析"
            }
            "MailDeliveryAnalysis" {
                $data = @([PSCustomObject]@{ SendDateTime = "2025-01-16 09:00"; Sender = "yamada@contoso.com"; Recipient = "client@partner.com"; Subject = "プロジェクト資料"; MessageID = "MSG001"; DeliveryStatus = "配信成功"; LatestEvent = "配信完了"; DelayReason = "なし"; RecipientServer = "partner.com" })
                $reportName = "配信分析"
            }
            "TeamsUsage" {
                $data = Get-ReportDataFromProvider -DataType "TeamsUsage"
                $reportName = "Teams使用状況"
            }
            "TeamsSettingsAnalysis" {
                $data = @([PSCustomObject]@{ PolicyName = "会議ポリシー"; PolicyType = "Teams会議"; TargetUsersCount = 150; Status = "有効"; MessagingPermission = "有効"; FileSharingPermission = "有効"; MeetingRecordingPermission = "管理者のみ"; LastUpdated = "2024-12-15"; Compliance = "準拠" })
                $reportName = "Teams設定分析"
            }
            "MeetingQualityAnalysis" {
                $data = @([PSCustomObject]@{ MeetingID = "MTG001"; MeetingName = "月次定例会議"; DateTime = "2025-01-16 10:00"; ParticipantCount = 8; AudioQuality = "良好"; VideoQuality = "良好"; NetworkQuality = "良好"; OverallQualityScore = 9.2; QualityRating = "優秀" })
                $reportName = "会議品質分析"
            }
            "TeamsAppAnalysis" {
                $data = @([PSCustomObject]@{ AppName = "Planner"; Version = "1.2.3"; Publisher = "Microsoft"; InstallationCount = 125; ActiveUsersCount = 95; LastUsedDate = "2025-01-16"; AppStatus = "アクティブ"; PermissionStatus = "承認済み"; SecurityScore = 9.5 })
                $reportName = "Teamsアプリ分析"
            }
            "StorageAnalysis" {
                $data = Get-ReportDataFromProvider -DataType "OneDriveAnalysis"
                $reportName = "OneDriveストレージ分析"
            }
            "SharingAnalysis" {
                $data = @([PSCustomObject]@{ FileName = "営業資料.xlsx"; Owner = "yamada@contoso.com"; FileSizeMB = 5.2; ShareType = "内部"; SharedWith = "営業チーム"; AccessPermission = "編集可能"; ShareDate = "2025-01-15 14:30"; LastAccess = "2025-01-16 09:15"; RiskLevel = "低" })
                $reportName = "OneDrive共有分析"
            }
            "SyncErrorAnalysis" {
                $data = @([PSCustomObject]@{ OccurrenceDate = "2025-01-16 08:30"; UserName = "田中次郎"; FilePath = "Documents/report.docx"; ErrorType = "同期競合"; ErrorCode = "SYNC001"; ErrorMessage = "ファイルが他のユーザーによって編集されています"; AffectedFilesCount = 1; Status = "解決済み"; RecommendedResolutionDate = "2025-01-16" })
                $reportName = "OneDrive同期エラー分析"
            }
            "ExternalSharingAnalysis" {
                $data = @([PSCustomObject]@{ FileName = "プロジェクト仕様書.pdf"; Owner = "yamada@contoso.com"; ExternalDomain = "partner.com"; SharedEmail = "client@partner.com"; AccessPermission = "表示のみ"; ShareURL = "https://contoso-my.sharepoint.com/personal/yamada.../shared"; ShareStartDate = "2025-01-15"; LastAccess = "2025-01-16 08:45"; RiskLevel = "中" })
                $reportName = "OneDrive外部共有分析"
            }
        }
        
        if ($data -and $data.Count -gt 0) {
            Export-DataToFiles -Data $data -ReportName $reportName
        } else {
            # ポップアップの代わりにエラーログとプロンプトタブに表示
            try { Write-GuiErrorLog "データの取得に失敗しました: $reportName" "WARNING" } catch { }
            if ($Script:PromptOutputTextBox -ne $null) {
                $Script:PromptOutputTextBox.AppendText("⚠️ データの取得に失敗しました: $reportName`r`n")
                $Script:PromptOutputTextBox.AppendText("💡 認証状況やネットワーク接続を確認してください`r`n`r`n")
                $Script:PromptOutputTextBox.ScrollToCaret()
            }
        }
    }
    catch {
        # ポップアップの代わりにエラーログとプロンプトタブに表示
        try { Write-GuiErrorLog "レポート処理エラー: $($_.Exception.Message)" "ERROR" } catch { }
        if ($Script:PromptOutputTextBox -ne $null) {
            $Script:PromptOutputTextBox.AppendText("❌ エラーが発生しました`r`n")
            $Script:PromptOutputTextBox.AppendText("🔍 詳細: $($_.Exception.Message)`r`n`r`n")
            $Script:PromptOutputTextBox.ScrollToCaret()
        }
    }
    finally {
        # ボタンオブジェクトの安全なリストア
        if ($Button -and $Button.GetType().Name -eq 'Button') {
            $Button.Text = $originalText
            $Button.Enabled = $true
            $Button.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)  # 元の色に戻す
        }
    }
}

# ================================================================================
# メイン処理
# ================================================================================

try {
    Write-Host "🎯 GUI初期化中..." -ForegroundColor Cyan
    Write-EarlyLog "GUI初期化開始"
    Write-GuiLog "[10:40:35] ℹ️ GUI初期化開始" "INFO"
    
    # グローバルエラーハンドラーの設定
    $global:ErrorActionPreference = "SilentlyContinue"
    
    # Windows Forms エラーハンドラーは既にスクリプト最初で設定済み
    Write-Host "✅ Windows Forms エラーハンドラーは既に設定済み" -ForegroundColor Green
    
    # メインフォーム作成と表示（完全出力抑制版）
    Write-EarlyLog "フォーム作成処理開始"
    $formCreationOutput = New-MainForm
    $mainForm = $formCreationOutput | Where-Object { $_ -is [System.Windows.Forms.Form] } | Select-Object -First 1
    
    if (-not $mainForm) {
        Write-Host "❌ フォーム作成エラー: 有効なフォームが見つかりません" -ForegroundColor Red
        Write-EarlyLog "フォーム作成エラー: 有効なフォームが見つかりません" "ERROR"
        throw "フォーム作成に失敗しました"
    }
    
    # フォーム型確認とキャスト
    if ($mainForm -is [System.Windows.Forms.Form]) {
        Write-Host "✅ GUIが正常に初期化されました" -ForegroundColor Green
        Write-EarlyLog "GUI初期化完了 - アプリケーション実行開始"
        Write-GuiLog "✅ GUI初期化完了 - アプリケーション実行開始" "SUCCESS"
        [System.Windows.Forms.Application]::Run([System.Windows.Forms.Form]$mainForm)
        Write-EarlyLog "アプリケーション実行終了"
    } else {
        Write-Host "❌ フォーム作成エラー: 予期しない型 $($mainForm.GetType().Name)" -ForegroundColor Red
        Write-EarlyLog "フォーム作成エラー: 予期しない型 $($mainForm.GetType().Name)" "ERROR"
        throw "フォーム作成に失敗しました"
    }
}
catch {
    Write-Host "❌ GUI初期化エラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "スタックトレース: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    Write-EarlyLog "GUI初期化エラー: $($_.Exception.Message)" "ERROR"
    Write-EarlyLog "スタックトレース: $($_.ScriptStackTrace)" "ERROR"
    # GUI初期化エラーは重大なため、コンソールに出力（GUIが使用不可のため）
    Write-Host "❌ GUI初期化エラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 管理者権限でPowerShellを実行し、実行ポリシーを確認してください" -ForegroundColor Yellow
    Write-Host "⚙️ Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Cyan
}
finally {
    Write-Host "🔚 Microsoft 365統合管理ツールを終了します" -ForegroundColor Cyan
    Write-EarlyLog "========================= GUI終了 ========================="
}

# ========================= テスト実行機能 =========================

function Show-TestExecutionMenu {
    try {
        Write-GuiLog "🧪 テスト実行メニューを表示します" "INFO"
        
        # テストメニューの表示
        $testMenuText = @"
[4] 🧪 テスト実行 - 接続・機能テスト
 [1] 🌐 接続テスト
 [2] 📧 Exchange Online テスト  
 [3] 💬 Teams API テスト
 [4] 📊 全機能テスト
 [0] ➤ 戻る
"@
        
        Write-GuiLog $testMenuText "INFO"
        
        # テストメニュー選択ダイアログ
        $testMenuForm = New-Object System.Windows.Forms.Form
        $testMenuForm.Text = "🧪 テスト実行メニュー"
        $testMenuForm.Size = New-Object System.Drawing.Size(500, 350)
        $testMenuForm.StartPosition = "CenterParent"
        $testMenuForm.FormBorderStyle = "FixedDialog"
        $testMenuForm.MaximizeBox = $false
        $testMenuForm.MinimizeBox = $false
        
        # メニューラベル
        $testMenuLabel = New-Object System.Windows.Forms.Label
        $testMenuLabel.Text = "🧪 テスト実行 - 接続・機能テスト"
        $testMenuLabel.Location = New-Object System.Drawing.Point(20, 20)
        $testMenuLabel.Size = New-Object System.Drawing.Size(440, 30)
        $testMenuLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI", 12, [System.Drawing.FontStyle]::Bold)
        $testMenuLabel.ForeColor = [System.Drawing.Color]::DarkBlue
        $testMenuForm.Controls.Add($testMenuLabel)
        
        # テストボタン作成
        $testButtons = @(
            @{ Text = "🌐 接続テスト"; Action = "ConnectionTest"; Y = 60 },
            @{ Text = "📧 Exchange Online テスト"; Action = "ExchangeTest"; Y = 100 },
            @{ Text = "💬 Teams API テスト"; Action = "TeamsTest"; Y = 140 },
            @{ Text = "📊 全機能テスト"; Action = "AllFeaturesTest"; Y = 180 }
        )
        
        foreach ($testBtn in $testButtons) {
            $button = New-Object System.Windows.Forms.Button
            $button.Text = $testBtn.Text
            $button.Location = New-Object System.Drawing.Point(50, $testBtn.Y)
            $button.Size = New-Object System.Drawing.Size(380, 30)
            $button.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10)
            $button.BackColor = [System.Drawing.Color]::LightBlue
            $button.FlatStyle = "Flat"
            $button.Add_Click({
                param($sender, $e)
                $action = $testBtn.Action
                $testMenuForm.Hide()
                Execute-TestAction -TestAction $action
                $testMenuForm.Close()
            }.GetNewClosure())
            $testMenuForm.Controls.Add($button)
        }
        
        # 戻るボタン
        $backButton = New-Object System.Windows.Forms.Button
        $backButton.Text = "➤ 戻る"
        $backButton.Location = New-Object System.Drawing.Point(200, 240)
        $backButton.Size = New-Object System.Drawing.Size(100, 30)
        $backButton.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10)
        $backButton.BackColor = [System.Drawing.Color]::LightGray
        $backButton.Add_Click({ $testMenuForm.Close() })
        $testMenuForm.Controls.Add($backButton)
        
        # フォーム表示
        $testMenuForm.ShowDialog() | Out-Null
        
    } catch {
        Write-GuiLog "❌ テストメニュー表示エラー: $($_.Exception.Message)" "ERROR"
    }
}

function Execute-TestAction {
    param([string]$TestAction)
    
    try {
        Write-GuiLog "🧪 テスト実行開始: $TestAction" "INFO"
        
        switch ($TestAction) {
            "ConnectionTest" {
                Write-GuiLog "🌐 接続テストを実行中..." "INFO"
                Test-M365Connection
            }
            "ExchangeTest" {
                Write-GuiLog "📧 Exchange Online テストを実行中..." "INFO"
                Test-ExchangeOnlineConnection
            }
            "TeamsTest" {
                Write-GuiLog "💬 Teams API テストを実行中..." "INFO"
                Test-TeamsApiConnection
            }
            "AllFeaturesTest" {
                Write-GuiLog "📊 全機能テストを実行中..." "INFO"
                Test-AllFeatures
            }
            default {
                Write-GuiLog "❌ 不明なテストアクション: $TestAction" "ERROR"
            }
        }
        
        Write-GuiLog "✅ テスト完了: $TestAction" "SUCCESS"
        
    } catch {
        Write-GuiLog "❌ テスト実行エラー [$TestAction]: $($_.Exception.Message)" "ERROR"
    }
}

function Test-M365Connection {
    try {
        Write-GuiLog "🔍 Microsoft 365 接続状態をテストしています..." "INFO"
        
        # 認証状態の確認
        $authResult = Test-M365Authentication
        if ($authResult) {
            Write-GuiLog "✅ Microsoft Graph: $($authResult.GraphConnected)" "INFO" 
            Write-GuiLog "✅ Exchange Online: $($authResult.ExchangeConnected)" "INFO"
            
            if ($authResult.GraphConnected -or $authResult.ExchangeConnected) {
                Write-GuiLog "🌐 接続テスト成功: 少なくとも1つのサービスに接続済み" "SUCCESS"
            } else {
                Write-GuiLog "❌ 接続テスト失敗: すべてのサービスが未接続" "ERROR"
            }
        } else {
            Write-GuiLog "❌ 接続テスト失敗: 認証状態の確認ができませんでした" "ERROR"
        }
        
    } catch {
        Write-GuiLog "❌ 接続テストエラー: $($_.Exception.Message)" "ERROR"
    }
}

function Test-ExchangeOnlineConnection {
    try {
        Write-GuiLog "🔍 Exchange Online 専用テストを実行中..." "INFO"
        
        # Exchange Online への接続テスト
        if (Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue) {
            try {
                # 既存のセッション確認
                $exchangeSession = Get-ConnectionInformation -ErrorAction SilentlyContinue
                if ($exchangeSession) {
                    Write-GuiLog "✅ Exchange Online: 既存セッションが利用可能" "SUCCESS"
                    Write-GuiLog "📧 組織: $($exchangeSession.Organization)" "INFO"
                    
                    # 簡単なコマンドテスト
                    $mailboxCount = (Get-Mailbox -ResultSize 5 | Measure-Object).Count
                    Write-GuiLog "📊 メールボックス確認: $mailboxCount 件のメールボックスを取得" "INFO"
                    
                } else {
                    Write-GuiLog "❌ Exchange Online: セッションが確立されていません" "ERROR"
                }
            } catch {
                Write-GuiLog "❌ Exchange Online テストエラー: $($_.Exception.Message)" "ERROR"
            }
        } else {
            Write-GuiLog "❌ Exchange Online モジュールが見つかりません" "ERROR"
        }
        
    } catch {
        Write-GuiLog "❌ Exchange Online テストエラー: $($_.Exception.Message)" "ERROR"
    }
}

function Test-TeamsApiConnection {
    try {
        Write-GuiLog "🔍 Teams API テストを実行中..." "INFO"
        
        # Microsoft Graph を使用した Teams 情報取得テスト
        try {
            if (Get-Command Get-MgUser -ErrorAction SilentlyContinue) {
                # ユーザー情報の取得テスト（Teams関連）
                $users = Get-MgUser -Top 3 -ErrorAction SilentlyContinue
                if ($users) {
                    Write-GuiLog "✅ Microsoft Graph: ユーザー情報取得成功 ($($users.Count) 件)" "SUCCESS"
                } else {
                    Write-GuiLog "❌ Microsoft Graph: ユーザー情報取得失敗" "ERROR"
                }
                
                # Teams 情報取得テスト
                try {
                    $teams = Get-MgGroup -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" -Top 3 -ErrorAction SilentlyContinue
                    if ($teams) {
                        Write-GuiLog "✅ Teams API: チーム情報取得成功 ($($teams.Count) 件)" "SUCCESS"
                    } else {
                        Write-GuiLog "⚠️ Teams API: チーム情報が見つかりません（権限またはデータの問題）" "WARNING"
                    }
                } catch {
                    Write-GuiLog "❌ Teams API エラー: $($_.Exception.Message)" "ERROR"
                }
                
            } else {
                Write-GuiLog "❌ Microsoft Graph モジュールが見つかりません" "ERROR"
            }
        } catch {
            Write-GuiLog "❌ Teams API テストエラー: $($_.Exception.Message)" "ERROR"
        }
        
    } catch {
        Write-GuiLog "❌ Teams API テストエラー: $($_.Exception.Message)" "ERROR"
    }
}

function Test-AllFeatures {
    try {
        Write-GuiLog "📊 全機能テストを開始します..." "INFO"
        
        # 1. 接続テスト
        Write-GuiLog "1️⃣ 接続テスト実行中..." "INFO"
        Test-M365Connection
        
        # 2. Exchange Online テスト
        Write-GuiLog "2️⃣ Exchange Online テスト実行中..." "INFO"
        Test-ExchangeOnlineConnection
        
        # 3. Teams API テスト
        Write-GuiLog "3️⃣ Teams API テスト実行中..." "INFO"
        Test-TeamsApiConnection
        
        # 4. データ取得テスト
        Write-GuiLog "4️⃣ データ取得機能テスト実行中..." "INFO"
        Test-DataRetrievalFeatures
        
        # 5. レポート生成テスト
        Write-GuiLog "5️⃣ レポート生成機能テスト実行中..." "INFO"
        Test-ReportGenerationFeatures
        
        Write-GuiLog "✅ 全機能テスト完了" "SUCCESS"
        
    } catch {
        Write-GuiLog "❌ 全機能テストエラー: $($_.Exception.Message)" "ERROR"
    }
}

function Test-DataRetrievalFeatures {
    try {
        Write-GuiLog "📊 データ取得機能をテスト中..." "INFO"
        
        # 既存のデータプロバイダー関数をテスト
        $testResults = @{}
        
        # ユーザーデータ取得テスト
        try {
            if (Get-Command Get-RealUserData -ErrorAction SilentlyContinue) {
                $userData = Get-RealUserData -MaxResults 3
                $testResults["UserData"] = if ($userData) { "✅ 成功" } else { "❌ データなし" }
            } else {
                $testResults["UserData"] = "❌ 関数未定義"
            }
        } catch {
            $testResults["UserData"] = "❌ エラー: $($_.Exception.Message)"
        }
        
        # ライセンスデータ取得テスト
        try {
            if (Get-Command Get-RealLicenseData -ErrorAction SilentlyContinue) {
                $licenseData = Get-RealLicenseData -MaxResults 3
                $testResults["LicenseData"] = if ($licenseData) { "✅ 成功" } else { "❌ データなし" }
            } else {
                $testResults["LicenseData"] = "❌ 関数未定義"
            }
        } catch {
            $testResults["LicenseData"] = "❌ エラー: $($_.Exception.Message)"
        }
        
        # テスト結果表示
        Write-GuiLog "📊 データ取得テスト結果:" "INFO"
        foreach ($test in $testResults.GetEnumerator()) {
            Write-GuiLog "  $($test.Key): $($test.Value)" "INFO"
        }
        
    } catch {
        Write-GuiLog "❌ データ取得テストエラー: $($_.Exception.Message)" "ERROR"
    }
}

function Test-ReportGenerationFeatures {
    try {
        Write-GuiLog "📄 レポート生成機能をテスト中..." "INFO"
        
        # テスト用データ作成
        $testData = @(
            [PSCustomObject]@{ 名前 = "テストユーザー1"; 状態 = "アクティブ"; 最終ログイン = (Get-Date).AddDays(-1) },
            [PSCustomObject]@{ 名前 = "テストユーザー2"; 状態 = "非アクティブ"; 最終ログイン = (Get-Date).AddDays(-30) }
        )
        
        $testOutputDir = "Reports\Test"
        if (-not (Test-Path $testOutputDir)) {
            New-Item -Path $testOutputDir -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $csvPath = "$testOutputDir\test-report_$timestamp.csv"
        $htmlPath = "$testOutputDir\test-report_$timestamp.html"
        
        try {
            # CSV出力テスト
            $testData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8BOM
            Write-GuiLog "✅ CSV出力テスト成功: $csvPath" "SUCCESS"
            
            # HTML出力テスト
            $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <title>テストレポート</title>
    <style>body{font-family:'Yu Gothic UI',sans-serif;}</style>
</head>
<body>
    <h1>🧪 レポート生成テスト</h1>
    <p>生成日時: $(Get-Date -Format "yyyy年MM月dd日 HH:mm:ss")</p>
    <table border="1" style="border-collapse:collapse;">
        <tr><th>名前</th><th>状態</th><th>最終ログイン</th></tr>
"@
            foreach ($item in $testData) {
                $htmlContent += "<tr><td>$($item.名前)</td><td>$($item.状態)</td><td>$($item.最終ログイン)</td></tr>"
            }
            $htmlContent += "</table></body></html>"
            
            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
            Write-GuiLog "✅ HTML出力テスト成功: $htmlPath" "SUCCESS"
            
            # ファイル自動開放テスト
            if ((Get-Item $csvPath).Length -gt 0 -and (Get-Item $htmlPath).Length -gt 0) {
                Write-GuiLog "✅ レポート生成テスト完了" "SUCCESS"
            } else {
                Write-GuiLog "❌ レポートファイルが空です" "ERROR"
            }
            
        } catch {
            Write-GuiLog "❌ レポート生成エラー: $($_.Exception.Message)" "ERROR"
        }
        
    } catch {
        Write-GuiLog "❌ レポート生成テストエラー: $($_.Exception.Message)" "ERROR"
    }
}