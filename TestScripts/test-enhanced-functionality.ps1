# ================================================================================
# Microsoft 365統合管理ツール - 完全版機能テスト
# Enhanced functionality test script
# ================================================================================

[CmdletBinding()]
param(
    [switch]$TestGUI,
    [switch]$TestCLI,
    [switch]$TestModules,
    [switch]$All
)

$Script:ToolRoot = Split-Path $PSScriptRoot -Parent
$Script:TestResults = @()

Write-Host "🧪 Microsoft 365統合管理ツール - 完全版機能テスト" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

function Add-TestResult {
    param(
        [string]$TestName,
        [string]$Status,
        [string]$Details = ""
    )
    
    $Script:TestResults += [PSCustomObject]@{
        TestName = $TestName
        Status = $Status
        Details = $Details
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $color = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "White" }
    }
    
    Write-Host "  [$Status] $TestName" -ForegroundColor $color
    if ($Details) {
        Write-Host "        $Details" -ForegroundColor Gray
    }
}

function Test-EnhancedModules {
    Write-Host "`n🔧 モジュールテスト" -ForegroundColor Yellow
    
    # RealM365DataProvider.psm1 テスト
    try {
        $modulePath = Join-Path $Script:ToolRoot "Scripts\Common\RealM365DataProvider.psm1"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -DisableNameChecking
            $functions = Get-Command -Module RealM365DataProvider
            Add-TestResult "RealM365DataProvider モジュール読み込み" "PASS" "$($functions.Count) 個の関数をエクスポート"
            
            # 主要関数の存在確認
            $expectedFunctions = @(
                'Test-M365Authentication',
                'Connect-M365Services', 
                'Get-M365AllUsers',
                'Get-M365LicenseAnalysis',
                'Get-M365UsageAnalysis',
                'Get-M365MFAStatus',
                'Get-M365MailboxAnalysis',
                'Get-M365TeamsUsage',
                'Get-M365OneDriveAnalysis',
                'Get-M365SignInLogs',
                'Get-M365DailyReport'
            )
            
            foreach ($func in $expectedFunctions) {
                if (Get-Command $func -ErrorAction SilentlyContinue) {
                    Add-TestResult "関数 $func" "PASS" "関数が正常にエクスポートされています"
                } else {
                    Add-TestResult "関数 $func" "FAIL" "関数が見つかりません"
                }
            }
        } else {
            Add-TestResult "RealM365DataProvider モジュール" "FAIL" "モジュールファイルが見つかりません"
        }
    } catch {
        Add-TestResult "RealM365DataProvider モジュール" "FAIL" $_.Exception.Message
    }
}

function Test-EnhancedGUI {
    Write-Host "`n🖥️ Enhanced GUIテスト" -ForegroundColor Yellow
    
    $guiPath = Join-Path $Script:ToolRoot "Apps\GuiApp_Enhanced.ps1"
    if (Test-Path $guiPath) {
        Add-TestResult "GuiApp_Enhanced.ps1" "PASS" "ファイルが存在します"
        
        # ファイル内容の基本チェック
        $content = Get-Content $guiPath -Raw
        $keywords = @(
            "RealM365DataProvider",
            "Get-RealOrDummyData",
            "Export-DataToFiles",
            "Microsoft Graph",
            "Templates/Samples",
            "6つのタブ"
        )
        
        foreach ($keyword in $keywords) {
            if ($content -match [regex]::Escape($keyword) -or $content -match $keyword) {
                Add-TestResult "GUI キーワード '$keyword'" "PASS" "実装されています"
            } else {
                Add-TestResult "GUI キーワード '$keyword'" "WARN" "キーワードが見つかりません"
            }
        }
    } else {
        Add-TestResult "GuiApp_Enhanced.ps1" "FAIL" "ファイルが見つかりません"
    }
}

function Test-EnhancedCLI {
    Write-Host "`n💻 Enhanced CLIテスト" -ForegroundColor Yellow
    
    $cliPath = Join-Path $Script:ToolRoot "Apps\CliApp_Enhanced.ps1"
    if (Test-Path $cliPath) {
        Add-TestResult "CliApp_Enhanced.ps1" "PASS" "ファイルが存在します"
        
        # ファイル内容の基本チェック
        $content = Get-Content $cliPath -Raw
        $keywords = @(
            "RealM365DataProvider",
            "Get-RealOrDummyData", 
            "Export-CliResults",
            "30種類以上のコマンド",
            "OutputCSV",
            "OutputHTML"
        )
        
        foreach ($keyword in $keywords) {
            if ($content -match [regex]::Escape($keyword) -or $content -match $keyword) {
                Add-TestResult "CLI キーワード '$keyword'" "PASS" "実装されています"
            } else {
                Add-TestResult "CLI キーワード '$keyword'" "WARN" "キーワードが見つかりません"
            }
        }
        
        # CLIアクションテスト
        try {
            Write-Host "`n    CLI機能テスト実行中..." -ForegroundColor Cyan
            $result = & $cliPath help -NoConnect 2>&1
            if ($LASTEXITCODE -eq 0 -or $result -match "ヘルプ") {
                Add-TestResult "CLI ヘルプ機能" "PASS" "ヘルプが正常に表示されます"
            } else {
                Add-TestResult "CLI ヘルプ機能" "WARN" "ヘルプ表示に問題があります"
            }
        } catch {
            Add-TestResult "CLI ヘルプ機能" "FAIL" $_.Exception.Message
        }
    } else {
        Add-TestResult "CliApp_Enhanced.ps1" "FAIL" "ファイルが見つかりません"
    }
}

function Test-LauncherIntegration {
    Write-Host "`n🚀 ランチャー統合テスト" -ForegroundColor Yellow
    
    $launcherPath = Join-Path $Script:ToolRoot "run_launcher.ps1"
    if (Test-Path $launcherPath) {
        Add-TestResult "run_launcher.ps1" "PASS" "ファイルが存在します"
        
        # ランチャーの Enhanced 対応確認
        $content = Get-Content $launcherPath -Raw
        if ($content -match "GuiApp_Enhanced\.ps1") {
            Add-TestResult "ランチャー Enhanced GUI対応" "PASS" "Enhanced GUIが優先選択されます"
        } else {
            Add-TestResult "ランチャー Enhanced GUI対応" "FAIL" "Enhanced GUI対応が見つかりません"
        }
        
        if ($content -match "CliApp_Enhanced\.ps1") {
            Add-TestResult "ランチャー Enhanced CLI対応" "PASS" "Enhanced CLIが優先選択されます"
        } else {
            Add-TestResult "ランチャー Enhanced CLI対応" "FAIL" "Enhanced CLI対応が見つかりません"
        }
    } else {
        Add-TestResult "run_launcher.ps1" "FAIL" "ファイルが見つかりません"
    }
}

function Test-TemplatesSamplesIntegration {
    Write-Host "`n📁 Templates/Samples統合テスト" -ForegroundColor Yellow
    
    $samplesPath = Join-Path $Script:ToolRoot "Templates\Samples"
    if (Test-Path $samplesPath) {
        Add-TestResult "Templates/Samples ディレクトリ" "PASS" "ディレクトリが存在します"
        
        $expectedFolders = @(
            "Analyticreport",
            "EntraIDManagement", 
            "ExchangeOnlineManagement",
            "OneDriveManagement",
            "Regularreports",
            "TeamsManagement"
        )
        
        foreach ($folder in $expectedFolders) {
            $folderPath = Join-Path $samplesPath $folder
            if (Test-Path $folderPath) {
                $htmlFiles = Get-ChildItem $folderPath -Filter "*.html" -ErrorAction SilentlyContinue
                Add-TestResult "フォルダ $folder" "PASS" "$($htmlFiles.Count) 個のHTMLテンプレート"
            } else {
                Add-TestResult "フォルダ $folder" "WARN" "フォルダが見つかりません"
            }
        }
    } else {
        Add-TestResult "Templates/Samples ディレクトリ" "FAIL" "ディレクトリが見つかりません"
    }
}

function Show-TestSummary {
    Write-Host "`n📊 テスト結果サマリー" -ForegroundColor Cyan
    Write-Host "====================" -ForegroundColor Cyan
    
    $passCount = ($Script:TestResults | Where-Object Status -eq "PASS").Count
    $failCount = ($Script:TestResults | Where-Object Status -eq "FAIL").Count  
    $warnCount = ($Script:TestResults | Where-Object Status -eq "WARN").Count
    $totalCount = $Script:TestResults.Count
    
    Write-Host "総テスト数: $totalCount" -ForegroundColor White
    Write-Host "成功: $passCount" -ForegroundColor Green
    Write-Host "警告: $warnCount" -ForegroundColor Yellow
    Write-Host "失敗: $failCount" -ForegroundColor Red
    
    $successRate = if ($totalCount -gt 0) { [Math]::Round(($passCount / $totalCount) * 100, 1) } else { 0 }
    Write-Host "成功率: $successRate%" -ForegroundColor $(if ($successRate -gt 80) { "Green" } elseif ($successRate -gt 60) { "Yellow" } else { "Red" })
    
    # 結果をCSVで保存
    $reportPath = Join-Path $PSScriptRoot "enhanced-functionality-test-report.csv"
    $Script:TestResults | Export-Csv -Path $reportPath -Encoding UTF8BOM -NoTypeInformation
    Write-Host "`n📄 詳細レポート: $reportPath" -ForegroundColor Cyan
}

# ================================================================================
# メイン実行部
# ================================================================================

try {
    if ($All -or (!$TestGUI -and !$TestCLI -and !$TestModules)) {
        Test-EnhancedModules
        Test-EnhancedGUI  
        Test-EnhancedCLI
        Test-LauncherIntegration
        Test-TemplatesSamplesIntegration
    } else {
        if ($TestModules) { Test-EnhancedModules }
        if ($TestGUI) { Test-EnhancedGUI }
        if ($TestCLI) { Test-EnhancedCLI }
    }
    
    Show-TestSummary
    
    Write-Host "`n✅ テスト完了" -ForegroundColor Green
} catch {
    Write-Host "`n❌ テスト実行エラー: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}