# ================================================================================
# test-launcher-gui.ps1
# ランチャーからGUI起動のテストスクリプト
# ================================================================================

param(
    [Parameter(Mandatory = $false)]
    [switch]$TestPDFGeneration = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose = $false
)

# スクリプトルートパス
$Script:ToolRoot = Split-Path $PSScriptRoot -Parent

# ログ出力関数
function Write-TestLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "Cyan" }
    }
    
    $prefix = switch ($Level) {
        "Success" { "✓" }
        "Warning" { "⚠" }
        "Error" { "✗" }
        default { "ℹ" }
    }
    
    Write-Host "[$timestamp] $prefix $Message" -ForegroundColor $color
}

# テストバナー表示
function Show-TestBanner {
    Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                    ランチャーGUI起動テストスクリプト                            ║
║                  run_launcher.ps1 → GUIモードの動作確認                       ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Blue
    Write-Host ""
}

# ランチャーファイルのチェック
function Test-LauncherFile {
    Write-TestLog "ランチャーファイルの存在チェック..." -Level Info
    
    $launcherPath = Join-Path $Script:ToolRoot "run_launcher.ps1"
    if (-not (Test-Path $launcherPath)) {
        Write-TestLog "ランチャーファイルが見つかりません: $launcherPath" -Level Error
        return $false
    }
    
    Write-TestLog "ランチャーファイルが見つかりました: $launcherPath" -Level Success
    return $true
}

# GUI アプリケーションファイルのチェック
function Test-GUIFile {
    Write-TestLog "GUIアプリケーションファイルの存在チェック..." -Level Info
    
    $guiPath = Join-Path $Script:ToolRoot "Apps\GuiApp.ps1"
    if (-not (Test-Path $guiPath)) {
        Write-TestLog "GUIアプリケーションファイルが見つかりません: $guiPath" -Level Error
        return $false
    }
    
    Write-TestLog "GUIアプリケーションファイルが見つかりました: $guiPath" -Level Success
    return $true
}

# PowerShell環境のチェック
function Test-PowerShellEnvironment {
    Write-TestLog "PowerShell環境をチェック..." -Level Info
    
    $psVersion = $PSVersionTable.PSVersion
    $psEdition = $PSVersionTable.PSEdition
    
    Write-TestLog "PowerShell バージョン: $psVersion" -Level Info
    Write-TestLog "PowerShell エディション: $psEdition" -Level Info
    
    if ($psVersion -lt [Version]"5.1") {
        Write-TestLog "PowerShell 5.1以上が必要です" -Level Error
        return $false
    }
    
    # Windows プラットフォームチェック
    if ($PSVersionTable.Platform -and $PSVersionTable.Platform -ne "Win32NT") {
        Write-TestLog "GUIアプリケーションはWindows環境でのみ動作します" -Level Error
        return $false
    }
    
    Write-TestLog "PowerShell環境は正常です" -Level Success
    return $true
}

# 実行ポリシーのチェック
function Test-ExecutionPolicy {
    Write-TestLog "実行ポリシーをチェック..." -Level Info
    
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    Write-TestLog "現在の実行ポリシー (CurrentUser): $currentPolicy" -Level Info
    
    $systemPolicy = Get-ExecutionPolicy -Scope LocalMachine
    Write-TestLog "現在の実行ポリシー (LocalMachine): $systemPolicy" -Level Info
    
    if ($currentPolicy -eq "Restricted") {
        Write-TestLog "実行ポリシーがRestrictedです。スクリプト実行に問題がある可能性があります" -Level Warning
        return $false
    }
    
    Write-TestLog "実行ポリシーは正常です" -Level Success
    return $true
}

# 依存モジュールのチェック
function Test-Dependencies {
    Write-TestLog "依存モジュールをチェック..." -Level Info
    
    $requiredModules = @(
        "Scripts\Common\GuiReportFunctions.psm1",
        "Scripts\Common\PuppeteerPDF.psm1",
        "Scripts\Common\Common.psm1"
    )
    
    $allFound = $true
    foreach ($module in $requiredModules) {
        $modulePath = Join-Path $Script:ToolRoot $module
        if (Test-Path $modulePath) {
            Write-TestLog "モジュール見つかりました: $module" -Level Success
        } else {
            Write-TestLog "モジュールが見つかりません: $module" -Level Warning
            $allFound = $false
        }
    }
    
    return $allFound
}

# ランチャーをテストモードで起動
function Test-LauncherExecution {
    Write-TestLog "ランチャーをテストモードで起動..." -Level Info
    
    try {
        $launcherPath = Join-Path $Script:ToolRoot "run_launcher.ps1"
        
        # ランチャーを読み込んで構文チェック
        $syntaxErrors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($launcherPath, [ref]$tokens, [ref]$syntaxErrors)
        
        if ($syntaxErrors) {
            Write-TestLog "ランチャーに構文エラーがあります:" -Level Error
            foreach ($error in $syntaxErrors) {
                Write-TestLog "  行 $($error.Extent.StartLineNumber): $($error.Message)" -Level Error
            }
            return $false
        }
        
        Write-TestLog "ランチャーの構文チェックが完了しました" -Level Success
        return $true
    }
    catch {
        Write-TestLog "ランチャー構文チェックでエラーが発生しました: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# PDF生成機能のテスト
function Test-PDFFeature {
    Write-TestLog "PDF生成機能をテスト..." -Level Info
    
    try {
        # PuppeteerPDFモジュールのインポート
        $pdfModulePath = Join-Path $Script:ToolRoot "Scripts\Common\PuppeteerPDF.psm1"
        if (Test-Path $pdfModulePath) {
            Import-Module $pdfModulePath -Force
            
            # Puppeteerセットアップ状態の確認
            $setupResult = Test-PuppeteerSetup
            if ($setupResult) {
                Write-TestLog "Puppeteer環境は正常にセットアップされています" -Level Success
            } else {
                Write-TestLog "Puppeteer環境のセットアップが必要です" -Level Warning
                Write-TestLog "以下のコマンドでセットアップしてください:" -Level Info
                Write-TestLog "  pwsh -File TestScripts\test-pdf-generation.ps1 -InstallPuppeteer" -Level Info
            }
            
            return $setupResult
        } else {
            Write-TestLog "PuppeteerPDFモジュールが見つかりません" -Level Error
            return $false
        }
    }
    catch {
        Write-TestLog "PDF機能テストでエラーが発生しました: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# 使用方法の表示
function Show-Usage {
    Write-Host ""
    Write-Host "📋 使用方法:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. 基本的な起動:" -ForegroundColor White
    Write-Host "   .\run_launcher.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. 直接GUIモードで起動:" -ForegroundColor White
    Write-Host "   .\run_launcher.ps1 -Mode GUI" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. サイレントモードで起動:" -ForegroundColor White
    Write-Host "   .\run_launcher.ps1 -Mode GUI -Silent" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. デバッグモードで起動:" -ForegroundColor White
    Write-Host "   .\run_launcher.ps1 -Mode GUI -DebugMode" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📄 PDF生成機能について:" -ForegroundColor Cyan
    Write-Host "• GUIのレポート生成ボタンを押すと、CSV・HTML・PDFが自動生成されます" -ForegroundColor Gray
    Write-Host "• 初回使用時は Node.js と Puppeteer の自動インストールが行われます" -ForegroundColor Gray
    Write-Host "• PDF生成に失敗した場合でも、CSVとHTMLは正常に生成されます" -ForegroundColor Gray
    Write-Host ""
}

# メイン実行
function Main {
    Show-TestBanner
    
    Write-TestLog "ランチャーGUI起動テストを開始します..." -Level Info
    Write-TestLog "PowerShell バージョン: $($PSVersionTable.PSVersion)" -Level Info
    Write-TestLog "PowerShell エディション: $($PSVersionTable.PSEdition)" -Level Info
    
    $testResults = @()
    
    # 1. ランチャーファイルのチェック
    $launcherResult = Test-LauncherFile
    $testResults += @{
        Test = "ランチャーファイルの存在チェック"
        Result = $launcherResult
    }
    
    # 2. GUIアプリケーションファイルのチェック
    $guiResult = Test-GUIFile
    $testResults += @{
        Test = "GUIアプリケーションファイルの存在チェック"
        Result = $guiResult
    }
    
    # 3. PowerShell環境のチェック
    $psResult = Test-PowerShellEnvironment
    $testResults += @{
        Test = "PowerShell環境のチェック"
        Result = $psResult
    }
    
    # 4. 実行ポリシーのチェック
    $policyResult = Test-ExecutionPolicy
    $testResults += @{
        Test = "実行ポリシーのチェック"
        Result = $policyResult
    }
    
    # 5. 依存モジュールのチェック
    $depResult = Test-Dependencies
    $testResults += @{
        Test = "依存モジュールのチェック"
        Result = $depResult
    }
    
    # 6. ランチャー構文チェック
    $execResult = Test-LauncherExecution
    $testResults += @{
        Test = "ランチャー構文チェック"
        Result = $execResult
    }
    
    # 7. PDF生成機能のテスト（オプション）
    if ($TestPDFGeneration) {
        $pdfResult = Test-PDFFeature
        $testResults += @{
            Test = "PDF生成機能のテスト"
            Result = $pdfResult
        }
    }
    
    # テスト結果まとめ
    Write-Host ""
    Write-TestLog "テスト結果まとめ:" -Level Info
    foreach ($test in $testResults) {
        $status = if ($test.Result) { "成功" } else { "失敗" }
        $level = if ($test.Result) { "Success" } else { "Error" }
        Write-TestLog "  $($test.Test): $status" -Level $level
    }
    
    $successCount = ($testResults | Where-Object { $_.Result }).Count
    $totalCount = $testResults.Count
    
    Write-TestLog "全体結果: $successCount/$totalCount テストが成功しました" -Level Info
    
    if ($successCount -eq $totalCount) {
        Write-TestLog "全てのテストが成功しました! ランチャーからGUI起動できます。" -Level Success
    } elseif ($successCount -ge ($totalCount - 1)) {
        Write-TestLog "ほとんどのテストが成功しました。GUI起動に問題がある可能性は低いです。" -Level Success
    } else {
        Write-TestLog "複数のテストが失敗しました。GUI起動に問題がある可能性があります。" -Level Warning
    }
    
    Show-Usage
}

# スクリプト実行
Main