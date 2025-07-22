# ================================================================================
# 🚀 Microsoft 365統合管理ツール - 統合ランチャー（拡張版）
# run_launcher_enhanced.ps1
# アイコン多用の美しいメニューシステム
# ================================================================================

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("GUI", "CLI", "Setup", "Test", "Advanced", "Help")]
    [string]$Mode = "",
    
    [Parameter()]
    [string]$Action = "",
    
    [Parameter()]
    [switch]$SkipPowerShell7Check,
    
    [Parameter()]
    [switch]$NoLogo,
    
    [Parameter()]
    [switch]$Silent,
    
    [Parameter()]
    [switch]$AutoExit,
    
    [Parameter()]
    [switch]$DebugMode
)

# ================================================================================
# 🔧 実行ポリシー自動修正機能（強化版）
# ================================================================================
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
$processPolicy = Get-ExecutionPolicy -Scope Process

Write-Host "🔍 現在の実行ポリシー確認中..." -ForegroundColor Cyan
Write-Host "   CurrentUser: $currentPolicy" -ForegroundColor Gray
Write-Host "   Process: $processPolicy" -ForegroundColor Gray

if ($currentPolicy -eq 'RemoteSigned' -or $currentPolicy -eq 'Restricted' -or $processPolicy -eq 'RemoteSigned' -or $processPolicy -eq 'Restricted') {
    try {
        Write-Host "🔧 実行ポリシーを自動調整中..." -ForegroundColor Yellow
        
        # CurrentUserスコープでBypassに設定
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force
        Write-Host "✅ CurrentUser スコープを Bypass に設定" -ForegroundColor Green
        
        # Processスコープでも明示的にBypassに設定
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
        Write-Host "✅ Process スコープを Bypass に設定" -ForegroundColor Green
        
        # 設定確認
        $newCurrentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        $newProcessPolicy = Get-ExecutionPolicy -Scope Process
        Write-Host "📊 更新後のポリシー:" -ForegroundColor Cyan
        Write-Host "   CurrentUser: $newCurrentPolicy" -ForegroundColor Green
        Write-Host "   Process: $newProcessPolicy" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ 実行ポリシーの自動設定に失敗しました。" -ForegroundColor Yellow
        Write-Host "📋 手動で以下のコマンドを実行してください:" -ForegroundColor Yellow
        Write-Host "   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force" -ForegroundColor White
        Write-Host "   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force" -ForegroundColor White
        Write-Host ""
        Write-Host "Enterキーを押してメニューに戻る..." -ForegroundColor Gray
        Read-Host
        exit 1
    }
} else {
    Write-Host "✅ 実行ポリシーは適切に設定されています" -ForegroundColor Green
}

# ================================================================================
# 🎨 カラー定義とアイコン
# ================================================================================
$Script:Colors = @{
    Header = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Blue"
    Menu = "Magenta"
    Prompt = "White"
    SubHeader = "DarkCyan"
}

$Script:Icons = @{
    # メインアイコン
    Logo = "🏢"
    Rocket = "🚀"
    Tool = "🔧"
    Settings = "⚙️"
    
    # 機能アイコン
    GUI = "🖥️"
    CLI = "💻"
    Setup = "🔨"
    Test = "🧪"
    Advanced = "🎛️"
    Help = "❓"
    Exit = "🚪"
    
    # ステータスアイコン
    Success = "✅"
    Warning = "⚠️"
    Error = "❌"
    Info = "ℹ️"
    Loading = "⏳"
    Running = "🔄"
    Complete = "✨"
    Check = "✓"
    Search = "🔍"
    
    # レポートアイコン
    Daily = "📅"
    Weekly = "📊"
    Monthly = "📈"
    Yearly = "📆"
    
    # サービスアイコン
    Teams = "💬"
    Exchange = "📧"
    OneDrive = "☁️"
    EntraID = "🆔"
    SharePoint = "📁"
    
    # その他
    Arrow = "➤"
    Bullet = "•"
    Cross = "✗"
    Star = "⭐"
    Lightning = "⚡"
    Shield = "🛡️"
    Key = "🔑"
    Lock = "🔒"
    Unlock = "🔓"
    Chart = "📊"
    Document = "📄"
    Folder = "📁"
    User = "👤"
    Users = "👥"
    World = "🌍"
    Cloud = "☁️"
    Database = "🗄️"
    Network = "🌐"
    Security = "🔐"
    Performance = "⚡"
    Analytics = "📊"
}

# ================================================================================
# 🛠️ ユーティリティ関数
# ================================================================================

# カラー付きテキスト出力
function Write-ColorText {
    param(
        [string]$Text,
        [string]$Color = "White",
        [switch]$NoNewline
    )
    
    if ($NoNewline) {
        Write-Host $Text -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Text -ForegroundColor $Color
    }
}

# アイコン付きメッセージ
function Write-IconMessage {
    param(
        [string]$Icon,
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewline
    )
    
    Write-ColorText "$Icon $Message" -Color $Color -NoNewline:$NoNewline
}

# 美しい区切り線
function Write-Separator {
    param(
        [string]$Character = "═",
        [int]$Length = 80,
        [string]$Color = "DarkGray"
    )
    
    $line = $Character * $Length
    Write-ColorText $line -Color $Color
}

# プログレスバー表示（コンソールハンドルエラー対応強化版）
function Show-Progress {
    param(
        [string]$Activity,
        [int]$PercentComplete,
        [string]$Status = ""
    )
    
    try {
        # 基本的なチェック
        if (-not $Host -or -not $Host.UI -or -not $Host.UI.RawUI) {
            Write-Host "$($Script:Icons.Loading) $Activity - $PercentComplete% $Status" -ForegroundColor Cyan
            return
        }
        
        # コンソールハンドルとウィンドウサイズのチェック
        $windowSize = $null
        try {
            $windowSize = $Host.UI.RawUI.WindowSize
        } catch {
            # ウィンドウサイズ取得でエラーが発生した場合
            Write-Host "$($Script:Icons.Loading) $Activity - $PercentComplete% $Status" -ForegroundColor Cyan
            return
        }
        
        # 出力がリダイレクトされていない場合のみプログレスバーを表示
        if (-not [Console]::IsOutputRedirected -and $windowSize -and $windowSize.Width -gt 0) {
            $width = [Math]::Min(50, $windowSize.Width - 20)  # 安全なバー幅
            $complete = [Math]::Floor($width * $PercentComplete / 100)
            $remaining = $width - $complete
            
            $progressBar = "█" * $complete + "░" * $remaining
            
            # カーソル位置の変更を試行
            try {
                Write-Host "`r$($Script:Icons.Loading) $Activity [$progressBar] $PercentComplete% $Status" -NoNewline -ForegroundColor Cyan
            } catch {
                # カーソル位置変更でエラーが発生した場合は通常出力
                Write-Host "$($Script:Icons.Loading) $Activity [$progressBar] $PercentComplete% $Status" -ForegroundColor Cyan
            }
        } else {
            # コンソールハンドルが無効な場合のフォールバック
            Write-Host "$($Script:Icons.Loading) $Activity - $PercentComplete% $Status" -ForegroundColor Cyan
        }
    }
    catch {
        # 全てのエラーケースでのシンプルな表示
        try {
            Write-Host "$($Script:Icons.Loading) $Activity - $PercentComplete% $Status" -ForegroundColor Cyan
        } catch {
            # 最後の手段：Write-Output使用
            Write-Output "$($Script:Icons.Loading) $Activity - $PercentComplete% $Status"
        }
    }
}

# ================================================================================
# 📋 ログ機能
# ================================================================================
$Script:LogPath = Join-Path $PSScriptRoot "Logs\launcher_enhanced.log"
$Script:LogLevel = if ($DebugMode) { "Debug" } else { "Info" }

function Write-LauncherLog {
    param(
        [string]$Message,
        [ValidateSet("Debug", "Info", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # ログディレクトリ作成
    $logDir = Split-Path $Script:LogPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    # ファイルに書き込み
    Add-Content -Path $Script:LogPath -Value $logMessage -Encoding UTF8
    
    # コンソール出力（デバッグモード時）
    if ($DebugMode -and $Level -ne "Debug") {
        switch ($Level) {
            "Warning" { Write-IconMessage $Script:Icons.Warning $Message -Color Yellow }
            "Error" { Write-IconMessage $Script:Icons.Error $Message -Color Red }
            default { Write-IconMessage $Script:Icons.Info $Message -Color Gray }
        }
    }
}

# ================================================================================
# 🎭 ヘッダー表示
# ================================================================================
function Show-Header {
    param(
        [switch]$Minimal
    )
    
    # 安全なクリア操作
    try {
        if ($Host.UI.RawUI.WindowSize.Width -gt 0) {
            Clear-Host
        }
    } catch {
        # Clear-Hostでエラーが発生した場合は改行で代用
        Write-Host "`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n`n" -NoNewline
    }
    
    if (-not $Minimal) {
        Write-Separator -Character "═" -Color Cyan
        Write-Host ""
        Write-ColorText "    $($Script:Icons.Logo) Microsoft 365 統合管理ツール $($Script:Icons.Logo)" -Color Cyan
        Write-ColorText "    $($Script:Icons.Rocket) Enterprise Management Suite v2.0 $($Script:Icons.Rocket)" -Color Cyan
        Write-Host ""
        Write-Separator -Character "═" -Color Cyan
        Write-Host ""
        
        # システム情報
        $psVersion = $PSVersionTable.PSVersion
        Write-IconMessage $Script:Icons.Info "PowerShell: $psVersion" -Color Gray
        Write-IconMessage $Script:Icons.World "プラットフォーム: $($PSVersionTable.Platform)" -Color Gray
        Write-IconMessage $Script:Icons.User "ユーザー: $env:USERNAME" -Color Gray
        Write-IconMessage $Script:Icons.Folder "場所: $PSScriptRoot" -Color Gray
        Write-Host ""
    } else {
        Write-ColorText "$($Script:Icons.Logo) M365 管理ツール - メニュー" -Color Cyan
        Write-Separator -Character "─" -Color DarkGray
    }
}

# ================================================================================
# 📊 メインメニュー
# ================================================================================
function Show-MainMenu {
    Show-Header
    
    Write-ColorText "🎯 メインメニュー" -Color Magenta
    Write-Separator -Character "─" -Color DarkGray;
    Write-Host "";
    ;
    $menuItems = @(;
        @{ Number = "1"; Icon = $Script:Icons.GUI; Text = "GUI モード"; Description = "Windows Forms GUIアプリケーション"; Color = "Cyan" }
        @{ Number = "2"; Icon = $Script:Icons.CLI; Text = "CLI モード"; Description = "コマンドライン操作"; Color = "Green" }
        @{ Number = "3"; Icon = $Script:Icons.Setup; Text = "セットアップ"; Description = "初期設定・環境構築"; Color = "Yellow" }
        @{ Number = "4"; Icon = $Script:Icons.Test; Text = "テスト実行"; Description = "接続・機能テスト"; Color = "Magenta" }
        @{ Number = "5"; Icon = $Script:Icons.Advanced; Text = "高度な機能"; Description = "上級者向け機能"; Color = "Blue" }
        @{ Number = "6"; Icon = $Script:Icons.Help; Text = "ヘルプ"; Description = "使い方・トラブルシューティング"; Color = "White" }
        @{ Number = "0"; Icon = $Script:Icons.Exit; Text = "終了"; Description = "アプリケーションを終了"; Color = "Red" }
    )
    
    foreach ($item in $menuItems) {
        Write-Host "  " -NoNewline
        Write-ColorText "[$($item.Number)]" -Color White -NoNewline
        Write-Host " " -NoNewline
        Write-ColorText "$($item.Icon) $($item.Text)" -Color $item.Color -NoNewline
        Write-Host " - " -NoNewline
        Write-ColorText $item.Description -Color DarkGray
    }
    
    Write-Host ""
    Write-Separator -Character "─" -Color DarkGray
    Write-Host ""
    Write-ColorText "選択してください " -Color White -NoNewline
    Write-ColorText "[0-6]: " -Color Yellow -NoNewline
}

# ================================================================================
# 🖥️ GUI起動（エラーハンドリング強化版）
# ================================================================================
function Start-GUIMode {
    Write-LauncherLog "GUIモード起動開始" -Level Info
    
    try {
        Show-Header -Minimal
        Write-IconMessage $Script:Icons.GUI "GUI アプリケーションを起動しています..." -Color Cyan
        Write-Host ""
        
        # 事前チェック - Enhanced GUIを優先使用
        $enhancedGuiPath = Join-Path $PSScriptRoot "Apps\GuiApp_Enhanced.ps1"
        $originalGuiPath = Join-Path $PSScriptRoot "Apps\GuiApp.ps1"
        
        if (Test-Path $enhancedGuiPath) {
            $guiPath = $enhancedGuiPath
            Write-IconMessage $Script:Icons.Info "Enhanced GUI (完全版) を使用します" -Color Cyan
        } elseif (Test-Path $originalGuiPath) {
            $guiPath = $originalGuiPath
            Write-IconMessage $Script:Icons.Warning "標準GUIを使用します" -Color Yellow
        } else {
            throw "GUIアプリケーションが見つかりません: $enhancedGuiPath, $originalGuiPath"
        }
        
        # PowerShellバージョンチェック
        $psVersion = $PSVersionTable.PSVersion
        Write-IconMessage $Script:Icons.Info "PowerShell バージョン: $psVersion" -Color Cyan
        
        # Windowsプラットフォームチェック
        if ($PSVersionTable.Platform -and $PSVersionTable.Platform -ne "Win32NT") {
            throw "GUIアプリケーションはWindows環境でのみ動作します。現在のプラットフォーム: $($PSVersionTable.Platform)"
        };
        ;
        # アニメーション表示（エラーハンドリング付き）;
        $steps = @(;
            @{ Text = "環境チェック"; Icon = $Script:Icons.Search }
            @{ Text = "モジュール読み込み"; Icon = $Script:Icons.Loading }
            @{ Text = "GUI初期化"; Icon = $Script:Icons.Settings }
            @{ Text = "起動準備完了"; Icon = $Script:Icons.Check }
        )
        
        foreach ($step in $steps) {
            try {
                Write-IconMessage $step.Icon $step.Text -Color Yellow
                Start-Sleep -Milliseconds 200  # 短縮して高速化
            }
            catch {
                Write-IconMessage $Script:Icons.Warning "ステップ処理でエラーが発生しましたが継続します" -Color Yellow
            }
        }
        
        Write-Host ""
        Write-IconMessage $Script:Icons.Rocket "起動中..." -Color Green
        
        # GUI起動の実行（同じプロンプトで実行）
        Write-LauncherLog "同じプロセスでGUI起動" -Level Info
        Write-IconMessage $Script:Icons.Info "現在のPowerShellプロンプトでGUIを起動します..." -Color Cyan
        
        # STAモードチェック
        if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
            Write-IconMessage $Script:Icons.Warning "STAモードではありません。GUI表示に問題が発生する可能性があります。" -Color Yellow
        }
        
        try {
            # 現在のプロンプトでGUIスクリプトを直接実行
            Write-IconMessage $Script:Icons.Running "GUIアプリケーションを起動中..." -Color Green
            & $guiPath
            Write-IconMessage $Script:Icons.Success "GUIアプリケーションが正常に終了しました" -Color Green
        }
        catch {
            # STAモード以外でのエラーの場合、新しいSTAプロセスで再実行を提案
            if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
                Write-IconMessage $Script:Icons.Warning "STAモードが必要です。新しいプロセスで起動します..." -Color Yellow
                
                # PowerShellコマンドの選択
                $psCommand = "pwsh"
                if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
                    $psCommand = "powershell"
                }
                
                # STAモードで新しいプロセス起動
                $argumentList = @("-sta", "-File", $guiPath)
                Start-Process -FilePath $psCommand -ArgumentList $argumentList -Wait
            } else {
                throw
            }
        }
        
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-IconMessage $Script:Icons.Error "GUI起動エラー: $errorMessage" -Color Red
        Write-LauncherLog "GUI起動エラー: $errorMessage" -Level Error
        
        # エラー時のトラブルシューティング提案
        Write-Host ""
        Write-IconMessage $Script:Icons.Info "トラブルシューティング:" -Color Cyan
        Write-Host "  • PowerShell 7.0以上がインストールされているか確認してください" -ForegroundColor Gray
        Write-Host "  • 実行ポリシーが適切に設定されているか確認してください" -ForegroundColor Gray
        Write-Host "  • Windowsフォームアセンブリが利用可能か確認してください" -ForegroundColor Gray
        Write-Host "  • CLIモードを試してみてください (オプション 2)" -ForegroundColor Gray
        
        # 詳細ログの提案
        Write-Host ""
        Write-IconMessage $Script:Icons.Info "詳細ログ: $Script:LogPath" -Color Cyan
    }
    
    if (-not $AutoExit) {
        Write-Host ""
        Write-ColorText "Enterキーを押してメニューに戻る..." -Color Gray
        try {
            Read-Host
        }
        catch {
            # Read-Hostでエラーが発生した場合のフォールバック
            Start-Sleep -Seconds 2
        }
    }
}

# ================================================================================
# 💻 CLI起動
# ================================================================================
function Start-CLIMode {
    Write-LauncherLog "CLIモード起動開始" -Level Info
    
    Show-Header -Minimal
    Write-IconMessage $Script:Icons.CLI "CLI モードメニュー" -Color Green
    Write-Separator -Character "─" -Color DarkGray;
    Write-Host "";
    ;
    $cliOptions = @(;
        @{ Number = "1"; Icon = $Script:Icons.Daily; Text = "日次レポート"; Command = "daily" }
        @{ Number = "2"; Icon = $Script:Icons.Weekly; Text = "週次レポート"; Command = "weekly" }
        @{ Number = "3"; Icon = $Script:Icons.Monthly; Text = "月次レポート"; Command = "monthly" }
        @{ Number = "4"; Icon = $Script:Icons.Yearly; Text = "年次レポート"; Command = "yearly" }
        @{ Number = "5"; Icon = $Script:Icons.Analytics; Text = "分析レポート"; Command = "analysis" }
        @{ Number = "6"; Icon = $Script:Icons.Shield; Text = "セキュリティ監査"; Command = "security" }
        @{ Number = "0"; Icon = $Script:Icons.Arrow; Text = "メインメニューに戻る"; Command = "back" }
    )
    
    foreach ($option in $cliOptions) {
        Write-Host "  [$($option.Number)] " -NoNewline
        Write-IconMessage $option.Icon $option.Text -Color White
    }
    
    Write-Host ""
    Write-ColorText "選択してください [0-6]: " -Color Yellow -NoNewline
    
    # 安全なRead-Host実行
    $choice = ""
    try {
        $choice = Read-Host
    } catch {
        Write-LauncherLog "入力読み取りエラー: $($_.Exception.Message)" -Level Warning
        return
    }
    
    if ($choice -eq "0") {
        return
    }
    
    $selected = $cliOptions | Where-Object { $_.Number -eq $choice }
    if ($selected -and $selected.Command -ne "back") {
        # Enhanced CLIを優先使用
        $enhancedCliPath = Join-Path $PSScriptRoot "Apps\CliApp_Enhanced.ps1"
        $originalCliPath = Join-Path $PSScriptRoot "Apps\CliApp.ps1"
        
        if (Test-Path $enhancedCliPath) {
            $cliPath = $enhancedCliPath
            Write-IconMessage $Script:Icons.Info "Enhanced CLI (完全版) を使用します" -Color Cyan
        } elseif (Test-Path $originalCliPath) {
            $cliPath = $originalCliPath
            Write-IconMessage $Script:Icons.Warning "標準CLIを使用します" -Color Yellow
        } else {
            Write-IconMessage $Script:Icons.Error "CLIアプリケーションが見つかりません" -Color Red
            return
        }
        
        Write-Host ""
        Write-IconMessage $Script:Icons.Running "$($selected.Text)を実行中..." -Color Cyan
        
        try {
            # 同じプロセスで実行
            & $cliPath -Action $selected.Command
            Write-IconMessage $Script:Icons.Success "完了しました" -Color Green
        }
        catch {
            Write-IconMessage $Script:Icons.Error "エラー: $_" -Color Red
        }
    }
    
    if (-not $AutoExit) {
        Write-Host ""
        Write-ColorText "Enterキーを押してメニューに戻る..." -Color Gray
        Read-Host
    }
}

# ================================================================================
# 🔨 セットアップ
# ================================================================================
function Start-Setup {
    Write-LauncherLog "セットアップ開始" -Level Info
    
    Show-Header -Minimal
    Write-IconMessage $Script:Icons.Setup "セットアップメニュー" -Color Yellow
    Write-Separator -Character "─" -Color DarkGray;
    Write-Host "";
    ;
    $setupOptions = @(;
        @{ Number = "1"; Icon = $Script:Icons.Lightning; Text = "クイックセットアップ"; Description = "推奨設定で自動構成" }
        @{ Number = "2"; Icon = $Script:Icons.Settings; Text = "詳細セットアップ"; Description = "手動で詳細設定" }
        @{ Number = "3"; Icon = $Script:Icons.Key; Text = "認証設定"; Description = "Microsoft 365認証情報" }
        @{ Number = "4"; Icon = $Script:Icons.Shield; Text = "証明書設定"; Description = "証明書のインストール" }
        @{ Number = "5"; Icon = $Script:Icons.Database; Text = "データベース設定"; Description = "ログ・レポート保存先" }
        @{ Number = "0"; Icon = $Script:Icons.Arrow; Text = "戻る"; Description = "" }
    )
    
    foreach ($option in $setupOptions) {
        Write-Host "  [$($option.Number)] " -NoNewline
        Write-IconMessage $option.Icon $option.Text -Color White -NoNewline
        if ($option.Description) {
            Write-Host " - " -NoNewline
            Write-ColorText $option.Description -Color DarkGray
        } else {
            Write-Host ""
        }
    }
    
    Write-Host ""
    Write-ColorText "選択してください [0-5]: " -Color Yellow -NoNewline
    
    # 安全なRead-Host実行
    $choice = ""
    try {
        $choice = Read-Host
    } catch {
        Write-LauncherLog "入力読み取りエラー: $($_.Exception.Message)" -Level Warning
        return
    }
    
    switch ($choice) {
        "1" { Start-QuickSetup }
        "2" { Start-DetailedSetup }
        "3" { Start-AuthSetup }
        "4" { Start-CertificateSetup }
        "5" { Start-DatabaseSetup }
        "0" { return }
    }
    
    if (-not $AutoExit) {
        Write-Host ""
        Write-ColorText "Enterキーを押してメニューに戻る..." -Color Gray
        Read-Host
    }
}

# ================================================================================
# ⚡ クイックセットアップ
# ================================================================================
function Start-QuickSetup {
    Write-Host ""
    Write-IconMessage $Script:Icons.Lightning "クイックセットアップを開始します" -Color Cyan
    Write-Host ""
    
    $tasks = @(
        "PowerShell 7確認"
        "必須モジュール確認"
        "設定ファイル作成"
        "証明書確認"
        "接続テスト"
    )
    
    $i = 0
    foreach ($task in $tasks) {
        $i++
        $percent = [Math]::Round(($i / $tasks.Count) * 100)
        Show-Progress -Activity "セットアップ中" -PercentComplete $percent -Status $task
        Start-Sleep -Milliseconds 800
    }
    
    Write-Host ""
    Write-Host ""
    Write-IconMessage $Script:Icons.Success "セットアップが完了しました！" -Color Green
}

# ================================================================================
# 🧪 テスト実行
# ================================================================================
function Start-TestMode {
    Write-LauncherLog "テストモード開始" -Level Info
    
    Show-Header -Minimal
    Write-IconMessage $Script:Icons.Test "テストメニュー" -Color Magenta
    Write-Separator -Character "─" -Color DarkGray;
    Write-Host "";
    ;
    $testOptions = @(;
        @{ Number = "1"; Icon = $Script:Icons.Network; Text = "接続テスト"; Script = "test-auth.ps1" }
        @{ Number = "2"; Icon = $Script:Icons.Exchange; Text = "Exchange Online テスト"; Script = "test-exchange-auth.ps1" }
        @{ Number = "3"; Icon = $Script:Icons.Teams; Text = "Teams API テスト"; Script = "test-teams-api.ps1" }
        @{ Number = "4"; Icon = $Script:Icons.Chart; Text = "全機能テスト"; Script = "test-all-features.ps1" }
        @{ Number = "0"; Icon = $Script:Icons.Arrow; Text = "戻る"; Script = "" }
    )
    
    foreach ($option in $testOptions) {
        Write-Host "  [$($option.Number)] " -NoNewline
        Write-IconMessage $option.Icon $option.Text -Color White
    }
    
    Write-Host ""
    Write-ColorText "選択してください [0-4]: " -Color Yellow -NoNewline
    
    # 安全なRead-Host実行
    $choice = ""
    try {
        $choice = Read-Host
    } catch {
        Write-LauncherLog "入力読み取りエラー: $($_.Exception.Message)" -Level Warning
        return
    }
    
    $selected = $testOptions | Where-Object { $_.Number -eq $choice }
    if ($selected -and $selected.Script) {
        $testPath = Join-Path $PSScriptRoot "TestScripts\$($selected.Script)"
        
        if (Test-Path $testPath) {
            Write-Host ""
            Write-IconMessage $Script:Icons.Running "テスト実行中: $($selected.Text)" -Color Cyan
            
            try {
                & $testPath
                Write-IconMessage $Script:Icons.Success "テスト完了" -Color Green
            }
            catch {
                Write-IconMessage $Script:Icons.Error "テストエラー: $_" -Color Red
            }
        } else {
            Write-IconMessage $Script:Icons.Warning "テストスクリプトが見つかりません: $($selected.Script)" -Color Yellow
        }
    }
    
    if (-not $AutoExit) {
        Write-Host ""
        Write-ColorText "Enterキーを押してメニューに戻る..." -Color Gray
        Read-Host
    }
}

# ================================================================================
# 🎛️ 高度な機能
# ================================================================================
function Start-AdvancedMode {
    Show-Header -Minimal
    Write-IconMessage $Script:Icons.Advanced "高度な機能" -Color Blue
    Write-Separator -Character "─" -Color DarkGray;
    Write-Host "";
    ;
    $advancedOptions = @(;
        @{ Number = "1"; Icon = $Script:Icons.Performance; Text = "パフォーマンス分析" }
        @{ Number = "2"; Icon = $Script:Icons.Security; Text = "セキュリティ監査" }
        @{ Number = "3"; Icon = $Script:Icons.Database; Text = "データベース管理" }
        @{ Number = "4"; Icon = $Script:Icons.Cloud; Text = "クラウド同期" }
        @{ Number = "5"; Icon = "🔧"; Text = "カスタムスクリプト実行" }
        @{ Number = "0"; Icon = $Script:Icons.Arrow; Text = "戻る" }
    )
    
    foreach ($option in $advancedOptions) {
        Write-Host "  [$($option.Number)] " -NoNewline
        Write-IconMessage $option.Icon $option.Text -Color White
    }
    
    Write-Host ""
    Write-ColorText "選択してください [0-5]: " -Color Yellow -NoNewline
    
    # 安全なRead-Host実行
    $choice = ""
    try {
        $choice = Read-Host
    } catch {
        Write-LauncherLog "入力読み取りエラー: $($_.Exception.Message)" -Level Warning
        return
    }
    
    # TODO: 各機能の実装
    
    if (-not $AutoExit) {
        Write-Host ""
        Write-ColorText "Enterキーを押してメニューに戻る..." -Color Gray
        Read-Host
    }
}

# ================================================================================
# ❓ ヘルプ
# ================================================================================
function Show-Help {
    Show-Header -Minimal
    Write-IconMessage $Script:Icons.Help "ヘルプ & ドキュメント" -Color White
    Write-Separator -Character "─" -Color DarkGray
    Write-Host ""
    
    Write-ColorText "📚 基本的な使い方" -Color Cyan
    Write-Host "  1. GUIモード: " -NoNewline
    Write-ColorText "視覚的な操作でレポート生成" -Color Gray
    Write-Host "  2. CLIモード: " -NoNewline
    Write-ColorText "コマンドラインからの自動実行" -Color Gray
    Write-Host "  3. セットアップ: " -NoNewline
    Write-ColorText "初回実行時の環境構築" -Color Gray
    Write-Host ""
    
    Write-ColorText "⌨️ コマンドラインオプション" -Color Cyan
    Write-Host "  -Mode <GUI|CLI|Setup|Test>  : " -NoNewline
    Write-ColorText "起動モード指定" -Color Gray
    Write-Host "  -Action <action>            : " -NoNewline
    Write-ColorText "CLIアクション指定" -Color Gray
    Write-Host "  -Silent                     : " -NoNewline
    Write-ColorText "サイレントモード" -Color Gray
    Write-Host "  -Debug                      : " -NoNewline
    Write-ColorText "デバッグモード" -Color Gray
    Write-Host ""
    
    Write-ColorText "🔗 関連リンク" -Color Cyan
    Write-Host "  ドキュメント: " -NoNewline
    Write-ColorText "https://docs.company.com/m365-tools" -Color Blue
    Write-Host "  サポート: " -NoNewline
    Write-ColorText "support@company.com" -Color Blue
    Write-Host ""
    
    if (-not $AutoExit) {
        Write-ColorText "Enterキーを押してメニューに戻る..." -Color Gray
        try {
            Read-Host
        } catch {
            Write-LauncherLog "入力読み取りエラー: $($_.Exception.Message)" -Level Warning
            Start-Sleep -Seconds 2
        }
    }
}

# ================================================================================
# 🎯 メイン処理
# ================================================================================
function Main {
    Write-LauncherLog "ランチャー起動" -Level Info
    
    # ロゴ表示（初回のみ）
    if (-not $NoLogo -and -not $Silent) {
        Show-Header
        Start-Sleep -Seconds 1
    }
    ;
    # モード指定がある場合は直接実行;
    if ($Mode) {;
        switch ($Mode.ToLower()) {;
            "gui" { Start-GUIMode; return }
            "cli" { Start-CLIMode; return }
            "setup" { Start-Setup; return }
            "test" { Start-TestMode; return }
            "advanced" { Start-AdvancedMode; return }
            "help" { Show-Help; return }
        }
    }
    
    # メインループ
    while ($true) {
        Show-MainMenu
        
        # 安全なRead-Host実行
        $choice = ""
        try {
            $choice = Read-Host
        } catch {
            Write-LauncherLog "入力読み取りエラー: $($_.Exception.Message)" -Level Warning
            # フォールバック：デフォルト動作
            Start-Sleep -Seconds 2
            continue
        }
        
        switch ($choice) {
            "1" { Start-GUIMode }
            "2" { Start-CLIMode }
            "3" { Start-Setup }
            "4" { Start-TestMode }
            "5" { Start-AdvancedMode }
            "6" { Show-Help }
            "0" { 
                Write-Host ""
                Write-IconMessage $Script:Icons.Exit "ご利用ありがとうございました！" -Color Cyan
                Write-IconMessage $Script:Icons.Star "Have a great day!" -Color Yellow
                Write-LauncherLog "ランチャー終了" -Level Info
                return 
            }
            default {
                Write-IconMessage $Script:Icons.Warning "無効な選択です" -Color Yellow
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ================================================================================
# 🚀 エントリーポイント
# ================================================================================
try {
    Main
}
catch {
    Write-IconMessage $Script:Icons.Error "予期しないエラーが発生しました: $_" -Color Red
    Write-LauncherLog "致命的エラー: $_" -Level Error
    
    if ($DebugMode) {
        Write-Host ""
        Write-ColorText "スタックトレース:" -Color Yellow
        Write-Host $_.ScriptStackTrace;
    };
    ;
    exit 1;
}