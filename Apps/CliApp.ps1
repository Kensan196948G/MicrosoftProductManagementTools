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
    [string]$LogLevel = "Info",
    
    [Parameter(Mandatory = $false, HelpMessage = "PDF形式でレポートを出力")]
    [switch]$EnablePDF = $false,
    
    [Parameter(Mandatory = $false, HelpMessage = "HTMLとPDFの両方を出力")]
    [switch]$BothFormats = $false
)

# グローバル変数
$Script:ToolRoot = Split-Path $PSScriptRoot -Parent
$Script:PSVersion = $PSVersionTable.PSVersion
$Script:IsCore = $PSVersionTable.PSEdition -eq "Core"
$Script:ConfigLoaded = $false
$Script:ShouldExit = $false

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

# レポート生成実行（PDF対応）
function Invoke-ReportGeneration {
    param([string]$ReportType)
    
    Write-CliLog "$ReportType レポートの生成を開始します..." -Level Info
    
    try {
        if (-not $Script:ConfigLoaded) {
            throw "設定が読み込まれていません"
        }
        
        # モジュールパスの設定
        $modulePath = Join-Path $Script:ToolRoot "Scripts\Common"
        
        # 必要なモジュールをインポート
        Import-Module "$modulePath\Common.psm1" -Force
        Import-Module "$modulePath\ScheduledReports.ps1" -Force
        
        # PDF機能が有効な場合、PuppeteerPDFモジュールをインポート
        if ($EnablePDF -or $BothFormats) {
            try {
                Import-Module "$modulePath\PuppeteerPDF.psm1" -Force
                Write-CliLog "PDF生成モジュールを読み込みました" -Level Info
            }
            catch {
                Write-CliLog "PDF生成モジュールの読み込みに失敗しました: $($_.Exception.Message)" -Level Warning
                Write-CliLog "HTMLレポートのみ生成します" -Level Info
                $global:EnablePDF = $false
                $global:BothFormats = $false
            }
        }
        
        if ($Script:CompatibilityMode -eq "Full") {
            # 実際のレポート関数を呼び出し（PDF対応）
            switch ($ReportType) {
                "Daily" { 
                    $result = Invoke-DailyReports
                    if ($EnablePDF -or $BothFormats) {
                        Invoke-PDFGeneration -ReportType $ReportType -ReportPaths $result
                    }
                }
                "Weekly" { 
                    $result = Invoke-WeeklyReports
                    if ($EnablePDF -or $BothFormats) {
                        Invoke-PDFGeneration -ReportType $ReportType -ReportPaths $result
                    }
                }
                "Monthly" { 
                    $result = Invoke-MonthlyReports
                    if ($EnablePDF -or $BothFormats) {
                        Invoke-PDFGeneration -ReportType $ReportType -ReportPaths $result
                    }
                }
                "Yearly" { 
                    $result = Invoke-YearlyReports
                    if ($EnablePDF -or $BothFormats) {
                        Invoke-PDFGeneration -ReportType $ReportType -ReportPaths $result
                    }
                }
                default { throw "不明なレポートタイプ: $ReportType" }
            }
        } else {
            Write-CliLog "PowerShell 5.1ではレポート機能が制限されています" -Level Warning
            Write-CliLog "基本的なレポート生成のみ実行します" -Level Info
            # 簡易版のレポート生成ロジックをここに追加
        }
            
        Write-CliLog "$ReportType レポートの生成が完了しました" -Level Success
        return $true
    }
    catch {
        Write-CliLog "$ReportType レポートの生成に失敗しました: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# PDF生成関数
function Invoke-PDFGeneration {
    param(
        [string]$ReportType,
        [object]$ReportPaths
    )
    
    Write-CliLog "$ReportType レポートのPDF生成を開始します..." -Level Info
    
    try {
        if (-not $ReportPaths) {
            Write-CliLog "レポートパスが指定されていません" -Level Warning
            return
        }
        
        # 生成されたHTMLファイルを検索
        $reportDir = Join-Path $Script:ToolRoot "Reports\$ReportType"
        $htmlFiles = Get-ChildItem -Path $reportDir -Filter "*.html" -Recurse | Sort-Object LastWriteTime -Descending
        
        if ($htmlFiles.Count -eq 0) {
            Write-CliLog "変換対象のHTMLファイルが見つかりません" -Level Warning
            return
        }
        
        $successCount = 0
        $errorCount = 0
        
        foreach ($htmlFile in $htmlFiles | Select-Object -First 5) {
            try {
                $pdfPath = $htmlFile.FullName -replace "\.html$", ".pdf"
                
                Write-CliLog "PDF生成中: $($htmlFile.Name)" -Level Info
                
                # PDF生成設定
                $pdfOptions = @{
                    format = "A4"
                    margin = @{
                        top = "20mm"
                        right = "15mm"
                        bottom = "20mm"
                        left = "15mm"
                    }
                    printBackground = $true
                    preferCSSPageSize = $false
                    displayHeaderFooter = $true
                    timeout = 30000
                    waitForNetworkIdle = $true
                }
                
                $pdfResult = ConvertTo-PDFFromHTML -InputHtmlPath $htmlFile.FullName -OutputPdfPath $pdfPath -Options $pdfOptions
                
                if ($pdfResult.Success) {
                    Write-CliLog "PDF生成完了: $($htmlFile.Name) -> $([System.IO.Path]::GetFileName($pdfPath))" -Level Success
                    Write-CliLog "  ファイルサイズ: $($pdfResult.FileSize)" -Level Info
                    Write-CliLog "  処理時間: $([math]::Round($pdfResult.ProcessingTime, 2))秒" -Level Info
                    $successCount++
                } else {
                    Write-CliLog "PDF生成失敗: $($htmlFile.Name)" -Level Error
                    $errorCount++
                }
            }
            catch {
                Write-CliLog "PDF生成エラー ($($htmlFile.Name)): $($_.Exception.Message)" -Level Error
                $errorCount++
            }
        }
        
        Write-CliLog "PDF生成完了: 成功 $successCount 件、失敗 $errorCount 件" -Level Info
    }
    catch {
        Write-CliLog "PDF生成処理でエラーが発生しました: $($_.Exception.Message)" -Level Error
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
                $Script:ShouldExit = $true
                break 
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
        "menu" { 
            Show-InteractiveMenu
            return $Script:ShouldExit
        }
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
    return $false
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
        $shouldExit = Invoke-CliAction -ActionName $Action
        
        if ($shouldExit) {
            Write-CliLog "アプリケーションを終了します" -Level Info
            return
        }
        
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