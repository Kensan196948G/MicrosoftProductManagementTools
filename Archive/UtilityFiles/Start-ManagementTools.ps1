# ================================================================================
# Microsoft 365統合管理ツール - 新しいメインランチャー
# Start-ManagementTools.ps1
# PowerShellバージョン対応・改良メニューシステム対応版
# ================================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Menu", "CLI", "ConsoleGUI", "WPF", "Info", "Test")]
    [string]$Mode = "Menu",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Auto", "CLI", "ConsoleGUI", "WPF")]
    [string]$MenuType = "Auto",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$ShowInfo = $false
)

# グローバル変数
$Script:ToolRoot = $PSScriptRoot
$Script:LogDir = Join-Path $Script:ToolRoot "Logs"
$Script:ConfigFile = Join-Path $Script:ToolRoot "Config\appsettings.json"

# ログディレクトリ作成
if (-not (Test-Path $Script:LogDir)) {
    New-Item -Path $Script:LogDir -ItemType Directory -Force | Out-Null
}

# 基本ログ関数
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # コンソール出力
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "Cyan" }
    }
    
    Write-Host $logEntry -ForegroundColor $color
    
    # ファイルログ出力
    try {
        $logFile = Join-Path $Script:LogDir "Management_$(Get-Date -Format 'yyyyMMdd').log"
        Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
    } catch {
        # ログファイル書き込みエラーは無視
    }
}

# 前提条件チェック関数
function Test-Prerequisites {
    Write-Log "前提条件をチェック中..." "Info"
    
    $results = @{
        PowerShell = $false
        Modules = @()
        Config = $false
        Overall = $false
    }
    
    # PowerShellバージョン確認
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion -ge [Version]"5.1") {
        Write-Log "PowerShell $psVersion - OK" "Success"
        $results.PowerShell = $true
    } else {
        Write-Log "PowerShell $psVersion - バージョンが古すぎます（5.1以上が必要）" "Error"
        return $results
    }
    
    # 重要モジュール確認
    $importantModules = @("Microsoft.Graph", "ExchangeOnlineManagement")
    foreach ($module in $importantModules) {
        $moduleInfo = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending | Select-Object -First 1
        if ($moduleInfo) {
            Write-Log "$module v$($moduleInfo.Version) - 利用可能" "Success"
            $results.Modules += $module
        } else {
            Write-Log "$module - 見つかりません（一部機能が制限されます）" "Warning"
        }
    }
    
    # 設定ファイル確認
    if (Test-Path $Script:ConfigFile) {
        try {
            $config = Get-Content $Script:ConfigFile | ConvertFrom-Json
            Write-Log "設定ファイル - OK" "Success"
            $results.Config = $true
        } catch {
            Write-Log "設定ファイル - 読み込みエラー: $($_.Exception.Message)" "Warning"
        }
    } else {
        Write-Log "設定ファイルが見つかりません: $Script:ConfigFile" "Warning"
    }
    
    $results.Overall = $results.PowerShell
    return $results
}

# メニューシステム初期化と起動
function Start-MenuSystem {
    param(
        [string]$PreferredMenuType = "Auto"
    )
    
    try {
        Write-Log "メニューシステムを初期化中..." "Info"
        
        # 共通モジュールの初期化（自動認証含む）
        $commonModulePath = Join-Path $Script:ToolRoot "Scripts\Common\Common.psm1"
        if (Test-Path $commonModulePath) {
            Import-Module $commonModulePath -Force -Global
            try {
                Write-Log "Microsoft 365サービスへの自動認証を実行中..." "Info"
                $config = Initialize-ManagementTools -ConfigPath $Script:ConfigFile
                Write-Log "共通モジュール初期化完了（自動認証含む）" "Success"
            }
            catch {
                Write-Log "自動認証エラー: $($_.Exception.Message)" "Warning"
                Write-Log "手動認証が必要な場合があります" "Info"
            }
        }
        
        # UI関連モジュールのパス確認
        $menuEngineModulePath = Join-Path $Script:ToolRoot "Scripts\UI\MenuEngine.psm1"
        
        if (-not (Test-Path $menuEngineModulePath)) {
            Write-Log "MenuEngineモジュールが見つかりません: $menuEngineModulePath" "Error"
            Write-Log "レガシーメニューシステムに切り替えます..." "Warning"
            Start-LegacyMenu
            return
        }
        
        # MenuEngineモジュールのインポートと初期化
        Import-Module $menuEngineModulePath -Force -Global
        
        # メニューエンジン初期化
        $initResult = Initialize-MenuEngine -PreferredMenuType $PreferredMenuType
        
        if ($initResult.Success) {
            Write-Log "メニューエンジン初期化完了: $($initResult.MenuType)" "Success"
            
            # メインメニュー起動
            Start-MainMenu
        } else {
            Write-Log "メニューエンジン初期化失敗: $($initResult.Error)" "Error"
            Write-Log "レガシーメニューシステムに切り替えます..." "Warning"
            Start-LegacyMenu
        }
        
    } catch {
        Write-Log "メニューシステム起動エラー: $($_.Exception.Message)" "Error"
        Write-Log "レガシーメニューシステムに切り替えます..." "Warning"
        Start-LegacyMenu
    }
}

# レガシーメニューシステム（フォールバック用）
function Start-LegacyMenu {
    Write-Log "レガシーメニューシステムを起動中..." "Warning"
    
    do {
        Clear-Host
        Write-Host @"
╔══════════════════════════════════════════════════════════════════════╗
║                Microsoft 365 統合管理システム                       ║
║             ITSM/ISO27001/27002準拠 エンタープライズ管理             ║
╚══════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Blue

        Write-Host ""
        Write-Host "=== 基本機能 ===" -ForegroundColor Cyan
        Write-Host "1. AD連携とユーザー同期状況確認"
        Write-Host "2. Exchangeメールボックス容量監視"
        Write-Host "3. OneDrive容量・Teams利用状況確認"
        Write-Host "4. 日次/週次/月次レポート生成"
        
        Write-Host ""
        Write-Host "=== 管理機能 ===" -ForegroundColor Cyan
        Write-Host "5. セキュリティとコンプライアンス監査"
        Write-Host "6. 年間消費傾向のアラート出力"
        Write-Host "7. ユーザー・グループ管理"
        Write-Host "8. システム設定とメンテナンス"
        
        Write-Host ""
        Write-Host "0. 終了" -ForegroundColor Yellow
        Write-Host ""
        
        $selection = Read-Host "選択してください (0-8)"
        
        switch ($selection) {
            "1" { 
                Write-Log "AD連携確認を実行中..." "Info"
                $scriptPath = Join-Path $Script:ToolRoot "Scripts\AD\Test-ADSync.ps1"
                if (Test-Path $scriptPath) { & $scriptPath } 
                else { Write-Log "スクリプトが見つかりません: $scriptPath" "Warning" }
                Read-Host "続行するには Enter キーを押してください"
            }
            "2" { 
                Write-Log "メールボックス容量監視を実行中..." "Info"
                $scriptPath = Join-Path $Script:ToolRoot "Scripts\EXO\Get-MailboxUsage.ps1"
                if (Test-Path $scriptPath) { & $scriptPath } 
                else { Write-Log "スクリプトが見つかりません: $scriptPath" "Warning" }
                Read-Host "続行するには Enter キーを押してください"
            }
            "3" { 
                Write-Log "OneDrive・Teams使用状況確認を実行中..." "Info"
                $scriptPath = Join-Path $Script:ToolRoot "Scripts\EntraID\Get-ODTeamsUsage.ps1"
                if (Test-Path $scriptPath) { & $scriptPath } 
                else { Write-Log "スクリプトが見つかりません: $scriptPath" "Warning" }
                Read-Host "続行するには Enter キーを押してください"
            }
            "4" { 
                Show-LegacyReportMenu
            }
            "5" { 
                Write-Log "セキュリティ監査を実行中..." "Info"
                $scriptPath = Join-Path $Script:ToolRoot "Scripts\Common\SecurityAudit.ps1"
                if (Test-Path $scriptPath) { & $scriptPath } 
                else { Write-Log "スクリプトが見つかりません: $scriptPath" "Warning" }
                Read-Host "続行するには Enter キーを押してください"
            }
            "6" { 
                Show-LegacyYearlyConsumptionMenu
            }
            "7" { 
                Write-Log "ユーザー・グループ管理メニューは実装中です" "Warning"
                Read-Host "続行するには Enter キーを押してください"
            }
            "8" { 
                Write-Log "システム設定メニューは実装中です" "Warning"
                Read-Host "続行するには Enter キーを押してください"
            }
            "0" { 
                Write-Log "Microsoft 365 管理ツールを終了します" "Info"
                return 
            }
            default {
                Write-Log "無効な選択です: $selection" "Warning"
                Start-Sleep -Seconds 2
            }
        }
    } while ($true)
}

# レガシーレポートメニュー
function Show-LegacyReportMenu {
    do {
        Clear-Host
        Write-Host "=== レポート生成メニュー ===" -ForegroundColor Green
        Write-Host ""
        Write-Host "1. 日次レポート生成"
        Write-Host "2. 週次レポート生成"
        Write-Host "3. 月次レポート生成" 
        Write-Host "4. 年次レポート生成"
        Write-Host ""
        Write-Host "B. 戻る"
        Write-Host ""
        
        $selection = Read-Host "選択してください"
        
        switch ($selection.ToUpper()) {
            "1" { 
                $scriptPath = Join-Path $Script:ToolRoot "Scripts\Common\ScheduledReports.ps1"
                if (Test-Path $scriptPath) { & $scriptPath -ReportType "Daily" }
                Read-Host "続行するには Enter キーを押してください"
            }
            "2" { 
                $scriptPath = Join-Path $Script:ToolRoot "Scripts\Common\ScheduledReports.ps1"
                if (Test-Path $scriptPath) { & $scriptPath -ReportType "Weekly" }
                Read-Host "続行するには Enter キーを押してください"
            }
            "3" { 
                $scriptPath = Join-Path $Script:ToolRoot "Scripts\Common\ScheduledReports.ps1"
                if (Test-Path $scriptPath) { & $scriptPath -ReportType "Monthly" }
                Read-Host "続行するには Enter キーを押してください"
            }
            "4" { 
                $scriptPath = Join-Path $Script:ToolRoot "Scripts\Common\ScheduledReports.ps1"
                if (Test-Path $scriptPath) { & $scriptPath -ReportType "Yearly" }
                Read-Host "続行するには Enter キーを押してください"
            }
            "B" { return }
            default {
                Write-Log "無効な選択です" "Warning"
                Start-Sleep -Seconds 2
            }
        }
    } while ($true)
}

# レガシー年間消費傾向メニュー
function Show-LegacyYearlyConsumptionMenu {
    Clear-Host
    Write-Host "=== 年間消費傾向アラート ===" -ForegroundColor Red
    Write-Host ""
    
    $budgetLimit = Read-Host "年間予算上限を入力してください (例: 5000000)"
    if (-not $budgetLimit -or $budgetLimit -notmatch "^\d+$") {
        $budgetLimit = 5000000
        Write-Log "デフォルト値を使用: ¥5,000,000" "Warning"
    }
    
    $alertThreshold = Read-Host "アラート閾値(%)を入力してください (例: 80)"
    if (-not $alertThreshold -or $alertThreshold -notmatch "^\d+$") {
        $alertThreshold = 80
        Write-Log "デフォルト値を使用: 80%" "Warning"
    }
    
    Write-Log "年間消費傾向アラート分析を実行中..." "Info"
    
    try {
        $scriptPath = Join-Path $Script:ToolRoot "Scripts\EntraID\YearlyConsumptionAlert.ps1"
        
        if (Test-Path $scriptPath) {
            . $scriptPath
            $result = Get-YearlyConsumptionAlert -BudgetLimit ([long]$budgetLimit) -AlertThreshold ([int]$alertThreshold) -ExportHTML -ExportCSV
            
            if ($result.Success) {
                Write-Log "年間消費傾向アラート分析が完了しました" "Success"
                Write-Host ""
                Write-Host "結果サマリー:" -ForegroundColor Cyan
                Write-Host "  現在ライセンス数: $($result.TotalLicenses)"
                Write-Host "  年間予測消費: $($result.PredictedYearlyConsumption)"
                Write-Host "  予算使用率: $($result.BudgetUtilization)%"
                Write-Host "  緊急アラート: $($result.CriticalAlerts)件"
                Write-Host "  警告アラート: $($result.WarningAlerts)件"
                
                if ($result.HTMLPath) {
                    Write-Host "  HTMLダッシュボード: $($result.HTMLPath)" -ForegroundColor Green
                }
            } else {
                Write-Log "分析中にエラーが発生しました: $($result.Error)" "Error"
            }
        } else {
            Write-Log "年間消費傾向アラートスクリプトが見つかりません" "Error"
        }
    } catch {
        Write-Log "実行エラー: $($_.Exception.Message)" "Error"
    }
    
    Read-Host "続行するには Enter キーを押してください"
}

# 環境情報表示
function Show-EnvironmentInfo {
    Clear-Host
    Write-Host @"
╔══════════════════════════════════════════════════════════════════════╗
║                    環境情報・システム状況                           ║
╚══════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

    Write-Host ""
    Write-Host "📊 PowerShell環境" -ForegroundColor Cyan
    Write-Host "  バージョン: $($PSVersionTable.PSVersion)"
    Write-Host "  エディション: $($PSVersionTable.PSEdition)"
    Write-Host "  プラットフォーム: $($PSVersionTable.Platform)"
    Write-Host "  CLR バージョン: $($PSVersionTable.CLRVersion)"
    
    Write-Host ""
    Write-Host "🔧 システム情報" -ForegroundColor Cyan
    Write-Host "  OS: $([System.Environment]::OSVersion)"
    Write-Host "  .NET バージョン: $([System.Environment]::Version)"
    Write-Host "  作業ディレクトリ: $Script:ToolRoot"
    
    # メニューエンジンの状態確認
    try {
        $menuEngineModulePath = Join-Path $Script:ToolRoot "Scripts\UI\MenuEngine.psm1"
        if (Test-Path $menuEngineModulePath) {
            Import-Module $menuEngineModulePath -Force
            $status = Get-MenuEngineStatus
            
            Write-Host ""
            Write-Host "🎯 メニューシステム状況" -ForegroundColor Cyan
            Write-Host "  推奨メニュータイプ: $($status.PowerShellInfo.SupportedMenuType)"
            Write-Host "  ConsoleGUI対応: $(if($status.FeatureSupport.ConsoleGUI){'○'}else{'×'})"
            Write-Host "  WPF対応: $(if($status.FeatureSupport.WPF){'○'}else{'×'})"
            Write-Host "  Unicode文字サポート: $($status.EncodingInfo.OverallSupport)"
        }
    } catch {
        Write-Host ""
        Write-Host "⚠️ メニューシステム状況確認エラー: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "📦 重要モジュール確認" -ForegroundColor Cyan
    $modules = @("Microsoft.Graph", "ExchangeOnlineManagement", "Microsoft.PowerShell.ConsoleGuiTools")
    foreach ($module in $modules) {
        $moduleInfo = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending | Select-Object -First 1
        if ($moduleInfo) {
            Write-Host "  $module v$($moduleInfo.Version) - 利用可能" -ForegroundColor Green
        } else {
            Write-Host "  $module - 未インストール" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Read-Host "続行するには Enter キーを押してください"
}

# メイン処理
function Main {
    # パラメータ処理
    switch ($Mode) {
        "Info" {
            Show-EnvironmentInfo
            return
        }
        "Test" {
            Write-Log "システムテストを実行中..." "Info"
            $testResult = Test-Prerequisites
            if ($testResult.Overall) {
                Write-Log "システムテスト完了 - 正常" "Success"
            } else {
                Write-Log "システムテスト完了 - 問題あり" "Warning"
            }
            Read-Host "続行するには Enter キーを押してください"
            return
        }
        "CLI" {
            $MenuType = "CLI"
        }
        "ConsoleGUI" {
            $MenuType = "ConsoleGUI"
        }
        "WPF" {
            $MenuType = "WPF"
        }
    }
    
    # 環境情報表示（オプション）
    if ($ShowInfo) {
        Show-EnvironmentInfo
    }
    
    # 前提条件チェック
    Write-Log "Microsoft 365 統合管理システムを起動中..." "Info"
    $prerequisites = Test-Prerequisites
    
    if (-not $prerequisites.Overall) {
        Write-Log "前提条件チェックに失敗しました。一部機能が制限される可能性があります。" "Warning"
        if (-not $Force) {
            $continue = Read-Host "続行しますか？ (Y/N)"
            if ($continue -notmatch "^[Yy]") {
                Write-Log "処理を中止しました" "Info"
                return
            }
        }
    }
    
    # メニューシステム起動
    Start-MenuSystem -PreferredMenuType $MenuType
    
    Write-Log "Microsoft 365 統合管理システムを終了しました" "Info"
}

# スクリプト直接実行時のメイン処理実行
if ($MyInvocation.InvocationName -eq $PSCommandPath -or $MyInvocation.Line -match $MyInvocation.MyCommand.Name) {
    try {
        Main
    } catch {
        Write-Log "予期しないエラーが発生しました: $($_.Exception.Message)" "Error"
        Write-Log "レガシーメニューに切り替えます..." "Warning"
        Start-LegacyMenu
    }
}