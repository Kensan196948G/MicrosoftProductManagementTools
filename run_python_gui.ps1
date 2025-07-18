#!/usr/bin/env pwsh
# ================================================================================
# Microsoft 365 統合管理ツール - Python GUI 起動スクリプト
# 完全版 Python Edition v2.0 - PowerShell GUI完全互換
# ================================================================================

[CmdletBinding()]
param(
    [switch]$CLI,
    [switch]$InstallDependencies,
    [switch]$TestMode,
    [switch]$Debug
)

# スクリプトのパスを取得
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonMainScript = Join-Path $ScriptRoot "src\main.py"

# バナー表示
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "🚀 Microsoft 365 統合管理ツール - 完全版 Python Edition v2.0" -ForegroundColor Yellow
Write-Host "   PowerShell GUI完全互換 - 26機能搭載" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan

# Python バージョンチェック
function Test-PythonVersion {
    try {
        $pythonVersion = python --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $pythonVersion -match "Python (\d+)\.(\d+)") {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            
            if ($major -ge 3 -and $minor -ge 9) {
                Write-Host "✅ Python バージョン確認: $pythonVersion" -ForegroundColor Green
                return $true
            } else {
                Write-Host "❌ Python 3.9以上が必要です。現在: $pythonVersion" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "❌ Python が見つかりません。" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Python バージョン確認エラー: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 必要なパッケージのインストール
function Install-PythonDependencies {
    Write-Host "📦 Python パッケージのインストール中..." -ForegroundColor Yellow
    
    $packages = @(
        "PyQt6",
        "msal",
        "pandas",
        "jinja2",
        "requests",
        "python-dateutil",
        "pytz"
    )
    
    foreach ($package in $packages) {
        Write-Host "  インストール中: $package" -ForegroundColor Cyan
        try {
            $result = python -m pip install $package --upgrade 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ $package インストール完了" -ForegroundColor Green
            } else {
                Write-Host "  ❌ $package インストール失敗: $result" -ForegroundColor Red
            }
        } catch {
            Write-Host "  ❌ $package インストールエラー: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# 仮想環境の確認
function Test-VirtualEnvironment {
    if ($env:VIRTUAL_ENV) {
        Write-Host "✅ 仮想環境が有効です: $env:VIRTUAL_ENV" -ForegroundColor Green
        return $true
    } else {
        Write-Host "⚠️  仮想環境が検出されません。グローバル環境を使用します。" -ForegroundColor Yellow
        return $false
    }
}

# メイン処理
function Main {
    # 作業ディレクトリを変更
    Set-Location $ScriptRoot
    
    # Python バージョンチェック
    if (-not (Test-PythonVersion)) {
        Write-Host "Python 3.9以上をインストールしてください。" -ForegroundColor Red
        Write-Host "ダウンロード: https://www.python.org/downloads/" -ForegroundColor Yellow
        exit 1
    }
    
    # 仮想環境チェック
    Test-VirtualEnvironment
    
    # 依存関係のインストール
    if ($InstallDependencies) {
        Install-PythonDependencies
    }
    
    # メインスクリプトの存在確認
    if (-not (Test-Path $PythonMainScript)) {
        Write-Host "❌ メインスクリプトが見つかりません: $PythonMainScript" -ForegroundColor Red
        exit 1
    }
    
    # 起動モード決定
    $arguments = @()
    
    if ($CLI) {
        $arguments += "cli"
        Write-Host "📋 CLI モードで起動中..." -ForegroundColor Cyan
    } else {
        Write-Host "🖥️  GUI モードで起動中..." -ForegroundColor Cyan
    }
    
    if ($Debug) {
        $arguments += "--debug"
        Write-Host "🐛 デバッグモードが有効です" -ForegroundColor Yellow
    }
    
    # Python アプリケーション起動
    try {
        Write-Host "🚀 アプリケーション起動中..." -ForegroundColor Green
        
        if ($TestMode) {
            Write-Host "テストモード: python `"$PythonMainScript`" $($arguments -join ' ')" -ForegroundColor Magenta
        } else {
            $process = Start-Process -FilePath "python" -ArgumentList @("`"$PythonMainScript`"") + $arguments -NoNewWindow -Wait -PassThru
            
            if ($process.ExitCode -eq 0) {
                Write-Host "✅ アプリケーション正常終了" -ForegroundColor Green
            } else {
                Write-Host "❌ アプリケーション異常終了 (終了コード: $($process.ExitCode))" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "❌ アプリケーション起動エラー: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# ヘルプ表示
function Show-Help {
    Write-Host @"
使用方法:
  .\run_python_gui.ps1 [オプション]

オプション:
  -CLI                   CLI モードで起動
  -InstallDependencies  Python パッケージを自動インストール
  -TestMode             テストモード（実際には起動しない）
  -Debug                デバッグモード
  -Help                 このヘルプを表示

例:
  .\run_python_gui.ps1                        # GUI モードで起動
  .\run_python_gui.ps1 -CLI                   # CLI モードで起動
  .\run_python_gui.ps1 -InstallDependencies   # 依存関係をインストールしてGUI起動
  .\run_python_gui.ps1 -CLI -Debug            # CLI デバッグモードで起動
"@ -ForegroundColor White
}

# パラメータチェック
if ($Help) {
    Show-Help
    exit 0
}

# メイン実行
Main