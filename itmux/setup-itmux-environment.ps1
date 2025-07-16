# setup-itmux-environment.ps1
# ITSM開発環境のitmux統合セットアップスクリプト

param(
    [string]$WorkspaceBase = "C:\workspace\itsm-project",
    [string]$ItselfPath = "C:\tools\itmux",
    [switch]$Force
)

Write-Host "🎯 ITSM開発環境のitmux統合セットアップを開始します" -ForegroundColor Green
Write-Host "📁 作業ディレクトリ: $WorkspaceBase" -ForegroundColor Yellow
Write-Host "🔧 itmux インストール: $ItselfPath" -ForegroundColor Yellow

# 必要なディレクトリ構造を作成
$directories = @(
    "$WorkspaceBase\frontend",
    "$WorkspaceBase\backend", 
    "$WorkspaceBase\tests",
    "$WorkspaceBase\integration",
    "$WorkspaceBase\scripts",
    "$WorkspaceBase\logs",
    "$WorkspaceBase\docs",
    "$WorkspaceBase\config",
    "$WorkspaceBase\itmux-scripts"
)

Write-Host "📂 ディレクトリ構造を作成中..." -ForegroundColor Yellow
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "✅ 作成: $dir" -ForegroundColor Green
    } else {
        Write-Host "📁 既存: $dir" -ForegroundColor Cyan
    }
}

# itmux環境の検証
Write-Host "🔍 itmux環境を検証中..." -ForegroundColor Yellow
$itmuxExecutable = "$ItselfPath\itmux.cmd"
$tmuxExecutable = "$ItselfPath\bin\tmux.exe"
$minttyExecutable = "$ItselfPath\bin\mintty.exe"

if (Test-Path $itmuxExecutable) {
    Write-Host "✅ itmux.cmd: OK" -ForegroundColor Green
} else {
    Write-Host "❌ itmux.cmd: Not Found" -ForegroundColor Red
    throw "itmux.cmd が見つかりません: $itmuxExecutable"
}

if (Test-Path $tmuxExecutable) {
    Write-Host "✅ tmux.exe: OK" -ForegroundColor Green
} else {
    Write-Host "❌ tmux.exe: Not Found" -ForegroundColor Red
    throw "tmux.exe が見つかりません: $tmuxExecutable"
}

if (Test-Path $minttyExecutable) {
    Write-Host "✅ mintty.exe: OK" -ForegroundColor Green
} else {
    Write-Host "❌ mintty.exe: Not Found" -ForegroundColor Red
    throw "mintty.exe が見つかりません: $minttyExecutable"
}

# 環境変数の設定
Write-Host "🔧 環境変数を設定中..." -ForegroundColor Yellow
$currentPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
$itmuxBinPath = "$ItselfPath\bin"

if (-not $currentPath.Contains($itmuxBinPath)) {
    $newPath = "$currentPath;$itmuxBinPath"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::User)
    Write-Host "✅ PATH環境変数にitmux binディレクトリを追加しました" -ForegroundColor Green
} else {
    Write-Host "📁 PATH環境変数は既に設定されています" -ForegroundColor Cyan
}

# ITSM開発環境用の環境変数を設定
[Environment]::SetEnvironmentVariable("ITSM_WORKSPACE", $WorkspaceBase, [EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("ITMUX_PATH", $ItselfPath, [EnvironmentVariableTarget]::User)
Write-Host "✅ ITSM開発環境変数を設定しました" -ForegroundColor Green

# PowerShellスクリプトの実行ポリシーを確認・設定
Write-Host "🔒 PowerShell実行ポリシーを確認中..." -ForegroundColor Yellow
$executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($executionPolicy -eq "Restricted") {
    Write-Host "⚠️ PowerShell実行ポリシーが制限されています。RemoteSignedに変更します..." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "✅ PowerShell実行ポリシーをRemoteSignedに変更しました" -ForegroundColor Green
} else {
    Write-Host "✅ PowerShell実行ポリシー: $executionPolicy" -ForegroundColor Green
}

Write-Host "🎉 itmux環境のセットアップが完了しました!" -ForegroundColor Green
Write-Host "📋 次のステップ:" -ForegroundColor Yellow
Write-Host "  1. PowerShellを再起動してください" -ForegroundColor White
Write-Host "  2. itmux.cmdを実行してください: C:\tools\itmux\itmux.cmd" -ForegroundColor White
Write-Host "  3. tmux新規セッションを作成してください" -ForegroundColor White
Write-Host "  4. ITSM開発スクリプトを実行してください" -ForegroundColor White