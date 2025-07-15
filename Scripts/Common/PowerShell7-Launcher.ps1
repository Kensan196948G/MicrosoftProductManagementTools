# PowerShell 7 Launcher
# 運用ツールのPowerShell 7 統一化ランチャー

<#
.SYNOPSIS
運用ツールをPowerShell 7で実行するためのランチャースクリプト

.DESCRIPTION
このスクリプトは以下の機能を提供します:
- 現在のPowerShellバージョンを自動検出
- PowerShell 5検出時にPowerShell 7への切り替えを提案
- PowerShell 7の自動ダウンロード・インストール
- 指定されたスクリプトをPowerShell 7で実行

.PARAMETER TargetScript
実行対象のスクリプトパス

.PARAMETER Arguments
スクリプトに渡す引数

.PARAMETER AutoInstall
PowerShell 7が見つからない場合の自動インストール

.PARAMETER Force
強制的にバージョンチェックを実行

.EXAMPLE
.\PowerShell7-Launcher.ps1 -TargetScript "Scripts\AD\UserManagement.ps1"

.EXAMPLE
.\PowerShell7-Launcher.ps1 -TargetScript "run_launcher.ps1" -AutoInstall

.NOTES
このスクリプトはPowerShell 5.1以上で動作します
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$TargetScript,
    
    [Parameter(Mandatory = $false)]
    [string[]]$Arguments = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$AutoInstall,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# エラーハンドリング設定
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# スクリプトのルートディレクトリを取得
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot

# PowerShellVersionManager モジュールを読み込み
$modulePathVersionManager = Join-Path $ScriptRoot "PowerShellVersionManager.psm1"

if (-not (Test-Path $modulePathVersionManager)) {
    Write-Error "PowerShellVersionManager.psm1 が見つかりません: $modulePathVersionManager"
    exit 1
}

try {
    Import-Module $modulePathVersionManager -Force
}
catch {
    Write-Error "PowerShellVersionManager モジュールの読み込みに失敗しました: $($_.Exception.Message)"
    exit 1
}

# メイン処理
function Main {
    try {
        Write-Host ""
        Write-Host "🚀 " -ForegroundColor Blue -NoNewline
        Write-Host "Microsoft Product Management Tools - PowerShell 7 Launcher" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        
        # 現在のバージョン情報取得
        $currentVersion = Get-PowerShellVersionInfo
        
        Write-Host "📋 実行環境情報:" -ForegroundColor White
        Write-Host "   PowerShell: " -NoNewline
        Write-Host "$($currentVersion.FullVersion) " -ForegroundColor White -NoNewline
        Write-Host "($($currentVersion.Edition))" -ForegroundColor Gray
        Write-Host "   実行パス: " -NoNewline
        Write-Host "$($currentVersion.ExecutablePath)" -ForegroundColor Gray
        Write-Host "   プラットフォーム: " -NoNewline
        Write-Host "$($currentVersion.Platform)" -ForegroundColor Gray
        
        # ターゲットスクリプトの解決
        if ($TargetScript) {
            if (-not [System.IO.Path]::IsPathRooted($TargetScript)) {
                $TargetScript = Join-Path $ProjectRoot $TargetScript
            }
            
            if (-not (Test-Path $TargetScript)) {
                throw "指定されたスクリプトが見つかりません: $TargetScript"
            }
            
            Write-Host "   対象スクリプト: " -NoNewline
            Write-Host "$TargetScript" -ForegroundColor Cyan
        }
        
        Write-Host ""
        
        # PowerShell 7 環境確認
        if ($currentVersion.IsPowerShell7Plus) {
            Write-Host "✅ " -ForegroundColor Green -NoNewline
            Write-Host "PowerShell 7 シリーズで実行中です" -ForegroundColor Green
            
            if ($TargetScript) {
                Write-Host "🔄 対象スクリプトを実行します..." -ForegroundColor Cyan
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                
                # スクリプト実行
                & $TargetScript @Arguments
            }
            else {
                Write-Host "💡 対象スクリプトが指定されていません。PowerShell 7 環境が利用可能です。" -ForegroundColor White
            }
            
            return
        }
        
        # PowerShell 5 または その他のバージョン
        Write-Host "⚠️  " -ForegroundColor Yellow -NoNewline
        Write-Host "PowerShell $($currentVersion.MajorVersion) で実行中です" -ForegroundColor Yellow
        Write-Host "📋 " -ForegroundColor Blue -NoNewline
        Write-Host "このツールはPowerShell 7 での実行を強く推奨します" -ForegroundColor White
        
        # 利点の説明
        Write-Host ""
        Write-Host "🌟 PowerShell 7 の利点:" -ForegroundColor Cyan
        Write-Host "   • より高速で安定した実行" -ForegroundColor Gray
        Write-Host "   • 改良されたエラーハンドリング" -ForegroundColor Gray
        Write-Host "   • Microsoft Graph API との完全互換性" -ForegroundColor Gray
        Write-Host "   • 最新のセキュリティ機能" -ForegroundColor Gray
        Write-Host "   • クロスプラットフォーム対応" -ForegroundColor Gray
        Write-Host ""
        
        # PowerShell 7 環境確認・切り替え
        $continueWithPs7 = Confirm-PowerShell7Environment -AutoInstall:$AutoInstall -Force:$Force -ScriptPath $TargetScript
        
        if (-not $continueWithPs7) {
            Write-Host "🔄 PowerShell 7 での実行に切り替えました" -ForegroundColor Green
            Write-Host "   現在のセッションを終了します..." -ForegroundColor Gray
            return
        }
        
        # PowerShell 5 で続行する場合
        if ($TargetScript) {
            Write-Host ""
            Write-Host "⚠️  PowerShell $($currentVersion.MajorVersion) で続行します" -ForegroundColor Yellow
            Write-Host "📋 一部機能が制限される場合があります" -ForegroundColor White
            
            $continueChoice = Read-Host "続行しますか? (y/N)"
            if ($continueChoice -match "^[yY]") {
                Write-Host "🔄 対象スクリプトを実行します..." -ForegroundColor Cyan
                Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                
                # スクリプト実行
                & $TargetScript @Arguments
            }
            else {
                Write-Host "❌ 実行を中止しました" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host ""
        Write-Host "❌ " -ForegroundColor Red -NoNewline
        Write-Host "エラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "🔍 詳細: $($_.ScriptStackTrace)" -ForegroundColor Gray
        exit 1
    }
}

# 使用方法の表示
function Show-Usage {
    Write-Host ""
    Write-Host "📖 " -ForegroundColor Blue -NoNewline
    Write-Host "PowerShell 7 Launcher - 使用方法" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "基本的な使用方法:" -ForegroundColor White
    Write-Host "  .\PowerShell7-Launcher.ps1 -TargetScript 'Scripts\AD\UserManagement.ps1'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "オプション:" -ForegroundColor White
    Write-Host "  -TargetScript   : 実行するスクリプトのパス" -ForegroundColor Gray
    Write-Host "  -Arguments      : スクリプトに渡す引数" -ForegroundColor Gray
    Write-Host "  -AutoInstall    : PowerShell 7の自動インストール" -ForegroundColor Gray
    Write-Host "  -Force          : 強制的にバージョンチェックを実行" -ForegroundColor Gray
    Write-Host ""
    Write-Host "例:" -ForegroundColor White
    Write-Host "  # メインランチャーをPowerShell 7で実行" -ForegroundColor Gray
    Write-Host "  .\PowerShell7-Launcher.ps1 -TargetScript 'run_launcher.ps1'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # 自動インストールを有効にして実行" -ForegroundColor Gray
    Write-Host "  .\PowerShell7-Launcher.ps1 -TargetScript 'Scripts\Common\ScheduledReports.ps1' -AutoInstall" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # 引数を渡して実行" -ForegroundColor Gray
    Write-Host "  .\PowerShell7-Launcher.ps1 -TargetScript 'Scripts\Common\ScheduledReports.ps1' -Arguments @('-ReportType', 'Daily')" -ForegroundColor Gray
    Write-Host ""
}

# ヘルプ表示チェック
if ($args -contains "-?" -or $args -contains "-Help" -or $args -contains "--help") {
    Show-Usage
    return
}

# メイン処理実行
try {
    Main
}
catch {
    Write-Host ""
    Write-Host "💥 " -ForegroundColor Red -NoNewline
    Write-Host "予期しないエラーが発生しました" -ForegroundColor Red
    Write-Host "🔍 エラー詳細: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host "📞 サポートが必要な場合は、ログファイルと併せてお問い合わせください" -ForegroundColor White
    exit 1
}