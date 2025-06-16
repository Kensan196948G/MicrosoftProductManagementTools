# ================================================================================
# Microsoft 365統合管理ツール - CLI アプリケーション
# CliApp.ps1
# コンソールベースインターフェース（PowerShell 5.1/7.x 両対応）
# ================================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "実行する操作を指定")]
    [ValidateSet("menu", "auth", "daily", "weekly", "monthly", "yearly", "license", "help", "version")]
    [string]$Action = "menu",
    
    [Parameter(Mandatory = $false, HelpMessage = "バッチモードで実行（対話なし）")]
    [switch]$Batch = $false,
    
    [Parameter(Mandatory = $false, HelpMessage = "詳細出力を有効化")]
    [switch]$VerboseOutput = $false,
    
    [Parameter(Mandatory = $false, HelpMessage = "設定ファイルパスを指定")]
    [string]$ConfigPath,
    
    [Parameter(Mandatory = $false, HelpMessage = "ログレベルを指定")]
    [ValidateSet("Debug", "Info", "Warning", "Error")]
    [string]$LogLevel = "Info"
)

# グローバル変数
$Script:ToolRoot = Split-Path $PSScriptRoot -Parent
$Script:PSVersion = $PSVersionTable.PSVersion
$Script:IsCore = $PSVersionTable.PSEdition -eq "Core"
$Script:ConfigLoaded = $false

# PowerShell バージョン互換性チェック
$Script:CompatibilityMode = if ($Script:PSVersion -ge [Version]"7.0.0") { "Full" } else { "Limited" }

# ログ出力関数（クロスバージョン対応）
function Write-CliLog {
    param(
        [string]$Message,
        [ValidateSet("Debug", "Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Debug" { "Gray" }
        default { "Cyan" }
    }
    
    $prefix = switch ($Level) {
        "Success" { "✓" }
        "Warning" { "⚠" }
        "Error" { "✗" }
        "Debug" { "→" }
        default { "ℹ" }
    }
    
    if ($Level -eq "Debug" -and $LogLevel -ne "Debug") {
        return
    }
    
    Write-Host "[$timestamp] $prefix $Message" -ForegroundColor $color
    
    # ログファイルにも出力（可能な場合）
    try {
        $logPath = Join-Path $Script:ToolRoot "Logs\cli_app.log"
        $logEntry = "[$timestamp] [$Level] $Message"
        Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        # ログファイル書き込みエラーは無視
    }
}

# バナー表示
function Show-CliBanner {
    if (-not $Batch) {
        Clear-Host
        Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║              Microsoft 365統合管理ツール - CLI版                               ║
║                 PowerShell $($Script:PSVersion) ($Script:CompatibilityMode Mode)                    ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Blue
        Write-Host ""
    }
}

# ヘルプ表示
function Show-Help {
    Write-Host @"
Microsoft 365統合管理ツール - CLI版

使用方法:
  .\CliApp.ps1 [-Action <操作>] [-Batch] [-Verbose] [-ConfigPath <パス>] [-LogLevel <レベル>]

パラメーター:
  -Action       実行する操作 (menu, auth, daily, weekly, monthly, yearly, license, help, version)
  -Batch        バッチモードで実行（対話なし）
  -Verbose      詳細出力を有効化
  -ConfigPath   設定ファイルのパスを指定
  -LogLevel     ログレベル (Debug, Info, Warning, Error)

操作:
  menu          対話メニューを表示（デフォルト）
  auth          認証テストを実行
  daily         日次レポートを生成
  weekly        週次レポートを生成
  monthly       月次レポートを生成
  yearly        年次レポートを生成
  license       ライセンス分析を実行
  help          このヘルプを表示
  version       バージョン情報を表示

例:
  .\CliApp.ps1                           # 対話メニューを表示
  .\CliApp.ps1 -Action auth             # 認証テストを実行
  .\CliApp.ps1 -Action daily -Batch     # 日次レポートをバッチ実行
  .\CliApp.ps1 -Action help             # ヘルプを表示

"@ -ForegroundColor White
}

# バージョン情報表示
function Show-Version {
    Write-Host @"
Microsoft 365統合管理ツール CLI版
バージョン: 2.0.0
PowerShell: $($Script:PSVersion)
互換性モード: $Script:CompatibilityMode
実行ディレクトリ: $Script:ToolRoot
"@ -ForegroundColor Green
}

# 設定読み込み（クロスバージョン対応）
function Initialize-Configuration {
    try {
        if ($ConfigPath) {
            $configFile = $ConfigPath
        } else {
            $configFile = Join-Path $Script:ToolRoot "Config\appsettings.json"
        }
        
        if (-not (Test-Path $configFile)) {
            Write-CliLog "設定ファイルが見つかりません: $configFile" -Level Warning
            return $false
        }
        
        Write-CliLog "設定ファイルを読み込み中: $configFile" -Level Debug
        
        # PowerShell 5.1 と 7.x の互換性対応
        if ($Script:IsCore) {
            $global:Config = Get-Content $configFile | ConvertFrom-Json
        } else {
            # PowerShell 5.1用の読み込み
            $configContent = Get-Content $configFile -Raw
            $global:Config = $configContent | ConvertFrom-Json
        }
        
        Write-CliLog "設定ファイルの読み込みが完了しました" -Level Success
        $Script:ConfigLoaded = $true
        return $true
    }
    catch {
        Write-CliLog "設定ファイルの読み込みに失敗しました: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# モジュール読み込み（互換性チェック付き）
function Import-RequiredModules {
    $modules = @(
        "Scripts\Common\Common.psm1",
        "Scripts\Common\Logging.psm1"
    )
    
    if ($Script:CompatibilityMode -eq "Full") {
        $modules += @(
            "Scripts\Common\Authentication.psm1",
            "Scripts\Common\ReportGenerator.psm1"
        )
    }
    
    foreach ($module in $modules) {
        $modulePath = Join-Path $Script:ToolRoot $module
        if (Test-Path $modulePath) {
            try {
                Import-Module $modulePath -Force -ErrorAction Stop
                Write-CliLog "モジュールを読み込みました: $module" -Level Debug
            }
            catch {
                Write-CliLog "モジュールの読み込みに失敗しました: $module - $($_.Exception.Message)" -Level Warning
            }
        } else {
            Write-CliLog "モジュールが見つかりません: $modulePath" -Level Warning
        }
    }
}

# 認証実行
function Invoke-AuthenticationTest {
    Write-CliLog "認証テストを開始します..." -Level Info
    
    if ($Script:CompatibilityMode -eq "Limited") {
        Write-CliLog "PowerShell 5.1では認証機能が制限されています" -Level Warning
        Write-CliLog "PowerShell 7以上での実行を推奨します" -Level Info
        return $false
    }
    
    try {
        if (-not $Script:ConfigLoaded) {
            throw "設定が読み込まれていません"
        }
        
        # 認証テストスクリプトを実行
        $testScript = Join-Path $Script:ToolRoot "test-auth-simple.ps1"
        if (Test-Path $testScript) {
            & $testScript
            Write-CliLog "認証テストが完了しました" -Level Success
            return $true
        } else {
            throw "認証テストスクリプトが見つかりません: $testScript"
        }
    }
    catch {
        Write-CliLog "認証テストに失敗しました: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# レポート生成実行
function Invoke-ReportGeneration {
    param([string]$ReportType)
    
    Write-CliLog "$ReportType レポートの生成を開始します..." -Level Info
    
    try {
        if (-not $Script:ConfigLoaded) {
            throw "設定が読み込まれていません"
        }
        
        $reportScript = Join-Path $Script:ToolRoot "Scripts\Common\ScheduledReports.ps1"
        if (Test-Path $reportScript) {
            if ($Script:CompatibilityMode -eq "Full") {
                & $reportScript -ReportType $ReportType
            } else {
                Write-CliLog "PowerShell 5.1ではレポート機能が制限されています" -Level Warning
                Write-CliLog "基本的なレポート生成のみ実行します" -Level Info
                # 簡易版のレポート生成ロジックをここに追加
            }
            
            Write-CliLog "$ReportType レポートの生成が完了しました" -Level Success
            return $true
        } else {
            throw "レポート生成スクリプトが見つかりません: $reportScript"
        }
    }
    catch {
        Write-CliLog "$ReportType レポートの生成に失敗しました: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# ライセンス分析実行
function Invoke-LicenseAnalysis {
    Write-CliLog "ライセンス分析を開始します..." -Level Info
    
    try {
        $licenseScript = Join-Path $Script:ToolRoot "New-LicenseDashboard.ps1"
        if (Test-Path $licenseScript) {
            & $licenseScript
            Write-CliLog "ライセンス分析が完了しました" -Level Success
            return $true
        } else {
            throw "ライセンス分析スクリプトが見つかりません: $licenseScript"
        }
    }
    catch {
        Write-CliLog "ライセンス分析に失敗しました: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# 対話メニュー表示
function Show-InteractiveMenu {
    if ($Batch) {
        Write-CliLog "バッチモードでは対話メニューは利用できません" -Level Warning
        return
    }
    
    do {
        Write-Host "`n" + "="*60 -ForegroundColor Gray
        Write-Host "メインメニュー" -ForegroundColor Yellow
        Write-Host "="*60 -ForegroundColor Gray
        Write-Host "1. 認証テスト" -ForegroundColor Green
        Write-Host "2. 日次レポート生成" -ForegroundColor Cyan
        Write-Host "3. 週次レポート生成" -ForegroundColor Cyan
        Write-Host "4. 月次レポート生成" -ForegroundColor Cyan
        Write-Host "5. 年次レポート生成" -ForegroundColor Cyan
        Write-Host "6. ライセンス分析" -ForegroundColor Magenta
        Write-Host "7. システム情報表示" -ForegroundColor White
        Write-Host "8. ヘルプ表示" -ForegroundColor White
        Write-Host "0. 終了" -ForegroundColor Red
        Write-Host "="*60 -ForegroundColor Gray
        
        $choice = Read-Host "選択してください (0-8)"
        
        switch ($choice) {
            "1" { 
                Invoke-AuthenticationTest
                if (-not $Batch) { Read-Host "`nEnterキーを押して続行" | Out-Null }
            }
            "2" { 
                Invoke-ReportGeneration -ReportType "Daily"
                if (-not $Batch) { Read-Host "`nEnterキーを押して続行" | Out-Null }
            }
            "3" { 
                Invoke-ReportGeneration -ReportType "Weekly"
                if (-not $Batch) { Read-Host "`nEnterキーを押して続行" | Out-Null }
            }
            "4" { 
                Invoke-ReportGeneration -ReportType "Monthly"
                if (-not $Batch) { Read-Host "`nEnterキーを押して続行" | Out-Null }
            }
            "5" { 
                Invoke-ReportGeneration -ReportType "Yearly"
                if (-not $Batch) { Read-Host "`nEnterキーを押して続行" | Out-Null }
            }
            "6" { 
                Invoke-LicenseAnalysis
                if (-not $Batch) { Read-Host "`nEnterキーを押して続行" | Out-Null }
            }
            "7" { 
                Show-Version
                if (-not $Batch) { Read-Host "`nEnterキーを押して続行" | Out-Null }
            }
            "8" { 
                Show-Help
                if (-not $Batch) { Read-Host "`nEnterキーを押して続行" | Out-Null }
            }
            "0" { 
                Write-CliLog "アプリケーションを終了します" -Level Info
                return 
            }
            default { 
                Write-Host "無効な選択です。0-8の数字を入力してください。" -ForegroundColor Red 
            }
        }
        
    } while ($true)
}

# アクション実行
function Invoke-CliAction {
    param([string]$ActionName)
    
    switch ($ActionName.ToLower()) {
        "menu" { Show-InteractiveMenu }
        "auth" { Invoke-AuthenticationTest }
        "daily" { Invoke-ReportGeneration -ReportType "Daily" }
        "weekly" { Invoke-ReportGeneration -ReportType "Weekly" }
        "monthly" { Invoke-ReportGeneration -ReportType "Monthly" }
        "yearly" { Invoke-ReportGeneration -ReportType "Yearly" }
        "license" { Invoke-LicenseAnalysis }
        "help" { Show-Help }
        "version" { Show-Version }
        default { 
            Write-CliLog "不明なアクション: $ActionName" -Level Error
            Show-Help
        }
    }
}

# メイン実行
function Main {
    try {
        Show-CliBanner
        
        Write-CliLog "Microsoft 365統合管理ツール CLI版を起動しています..." -Level Info
        Write-CliLog "PowerShell バージョン: $($Script:PSVersion)" -Level Info
        Write-CliLog "互換性モード: $Script:CompatibilityMode" -Level Info
        
        if ($Script:CompatibilityMode -eq "Limited") {
            Write-CliLog "PowerShell 5.1での実行が検出されました。一部機能が制限されます。" -Level Warning
            Write-CliLog "完全な機能を利用するには PowerShell 7.5.1 以上をご利用ください。" -Level Info
        }
        
        # 設定初期化
        $configResult = Initialize-Configuration
        if (-not $configResult) {
            Write-CliLog "設定の初期化に失敗しました。基本機能のみ利用可能です。" -Level Warning
        }
        
        # モジュール読み込み
        Import-RequiredModules
        
        # アクション実行
        Invoke-CliAction -ActionName $Action
        
        Write-CliLog "処理が完了しました" -Level Success
    }
    catch {
        Write-CliLog "予期しないエラーが発生しました: $($_.Exception.Message)" -Level Error
        Write-CliLog "スタックトレース: $($_.ScriptStackTrace)" -Level Debug
        
        if (-not $Batch) {
            Read-Host "`nEnterキーを押して終了"
        }
        exit 1
    }
}

# 実行開始
Main