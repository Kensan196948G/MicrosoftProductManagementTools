# ================================================================================
# Microsoft 365統合管理ツール - GUI/CLI 両対応ランチャー
# run_launcher.ps1
# Windows 11 + PowerShell 7.5.1 専用／CLI対応
# ================================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "アプリケーションモードを指定")]
    [ValidateSet("gui", "cli", "auto")]
    [string]$Mode = "auto",
    
    [Parameter(Mandatory = $false, HelpMessage = "PowerShell 7のインストールをスキップ")]
    [switch]$SkipPowerShell7Install = $false,
    
    [Parameter(Mandatory = $false, HelpMessage = "管理者権限での実行を強制")]
    [switch]$ForceAdmin = $false,
    
    [Parameter(Mandatory = $false, HelpMessage = "詳細出力を有効化")]
    [switch]$VerboseOutput = $false
)

# グローバル変数
$Script:ToolRoot = $PSScriptRoot
$Script:RequiredPSVersion = [Version]"7.5.1"
$Script:PowerShell7Path = ""
$Script:IsAdmin = $false

# ログ関数
function Write-LauncherLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "Cyan" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# バナー表示
function Show-LauncherBanner {
    Clear-Host
    Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║              Microsoft 365統合管理ツール GUI/CLI ランチャー                          ║
║                    Windows 11 + PowerShell 7.5.1 対応                       ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Blue
    Write-Host ""
}

# 管理者権限確認
function Test-AdminRights {
    try {
        if ($IsLinux -or $IsMacOS) {
            # Linux/macOS での簡易チェック
            return (id -u) -eq 0
        } else {
            # Windows での標準チェック
            $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
    }
    catch {
        Write-LauncherLog "管理者権限の確認に失敗しました: $($_.Exception.Message)" -Level Warning
        return $false
    }
}

# 管理者権限で再実行
function Start-AsAdmin {
    if (-not (Test-AdminRights)) {
        Write-LauncherLog "管理者権限で再実行します..." -Level Warning
        
        $arguments = "-File `"$($MyInvocation.MyCommand.Path)`""
        if ($Mode -ne "auto") { $arguments += " -Mode $Mode" }
        if ($SkipPowerShell7Install) { $arguments += " -SkipPowerShell7Install" }
        if ($VerboseOutput) { $arguments += " -VerboseOutput" }
        
        Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
        exit
    }
}

# PowerShell バージョン確認
function Get-PowerShellVersionInfo {
    $psVersions = @{
        Current = $PSVersionTable.PSVersion
        IsCore = $PSVersionTable.PSEdition -eq "Core"
        Is7Plus = $PSVersionTable.PSVersion -ge [Version]"7.0.0"
        Is751Plus = $PSVersionTable.PSVersion -ge $Script:RequiredPSVersion
    }
    
    return $psVersions
}

# PowerShell 7.5.1 のパス検索
function Find-PowerShell7Path {
    $possiblePaths = @(
        "${env:ProgramFiles}\PowerShell\7\pwsh.exe",
        "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
        "${env:LocalAppData}\Microsoft\powershell\pwsh.exe",
        "C:\Program Files\PowerShell\7\pwsh.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            try {
                $version = & $path -Command '$PSVersionTable.PSVersion.ToString()'
                if ([Version]$version -ge $Script:RequiredPSVersion) {
                    Write-LauncherLog "PowerShell 7.5.1+ が見つかりました: $path (v$version)" -Level Success
                    return $path
                }
            }
            catch {
                Write-LauncherLog "PowerShell実行エラー: $path" -Level Warning
            }
        }
    }
    
    return $null
}

# PowerShell 7.5.1 インストール
function Install-PowerShell751 {
    if ($SkipPowerShell7Install) {
        Write-LauncherLog "PowerShell 7.5.1のインストールがスキップされました" -Level Warning
        return $false
    }
    
    $installerPath = Join-Path $Script:ToolRoot "Installers\PowerShell-7.5.1-win-x64.msi"
    
    if (-not (Test-Path $installerPath)) {
        Write-LauncherLog "PowerShell 7.5.1インストーラーが見つかりません: $installerPath" -Level Error
        Write-LauncherLog "手動でPowerShell 7.5.1をインストールしてください" -Level Info
        Write-LauncherLog "ダウンロードURL: https://github.com/PowerShell/PowerShell/releases" -Level Info
        return $false
    }
    
    Write-LauncherLog "PowerShell 7.5.1をサイレントインストールしています..." -Level Info
    
    try {
        $process = Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /qn /l*v `"$env:TEMP\PowerShell751Install.log`"" -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-LauncherLog "PowerShell 7.5.1のインストールが完了しました" -Level Success
            Write-LauncherLog "システムを再起動後にご利用ください" -Level Info
            return $true
        } else {
            Write-LauncherLog "PowerShell 7.5.1のインストールに失敗しました (ExitCode: $($process.ExitCode))" -Level Error
            Write-LauncherLog "ログファイル: $env:TEMP\PowerShell751Install.log" -Level Info
            return $false
        }
    }
    catch {
        Write-LauncherLog "インストールエラー: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# アプリケーションモード決定
function Get-ApplicationMode {
    if ($Mode -ne "auto") {
        return $Mode
    }
    
    # プラットフォームとGUIサポート確認
    if ($IsLinux -or $IsMacOS) {
        Write-LauncherLog "Linux/macOS環境が検出されました。CLIモードで起動します。" -Level Info
        return "cli"
    }
    
    # Windows環境でのGUIサポート確認
    if ([Environment]::OSVersion.Version.Major -ge 10 -and $env:USERDOMAIN) {
        Write-Host "アプリケーションモードを選択してください:" -ForegroundColor Yellow
        Write-Host "1. GUI モード (推奨)" -ForegroundColor Green
        Write-Host "2. CLI モード" -ForegroundColor Cyan
        Write-Host "3. 終了" -ForegroundColor Red
        
        do {
            $choice = Read-Host "選択 (1-3)"
            switch ($choice) {
                "1" { return "gui" }
                "2" { return "cli" }
                "3" { 
                    Write-LauncherLog "ランチャーを終了します" -Level Info
                    exit 0 
                }
                default { 
                    Write-Host "無効な選択です。1-3を入力してください。" -ForegroundColor Red 
                }
            }
        } while ($true)
    } else {
        Write-LauncherLog "GUI環境が検出されません。CLIモードで起動します" -Level Info
        return "cli"
    }
}

# GUI アプリケーション起動
function Start-GuiApplication {
    # プラットフォーム確認
    if ($IsLinux -or $IsMacOS) {
        Write-LauncherLog "エラー: GUIモードはWindows環境でのみサポートされています" -Level Error
        Write-LauncherLog "現在の環境: $($PSVersionTable.Platform)" -Level Info
        Write-LauncherLog "CLIモードをご利用ください" -Level Info
        return $false
    }
    
    $guiAppPath = Join-Path $Script:ToolRoot "Apps\GuiApp.ps1"
    
    if (-not (Test-Path $guiAppPath)) {
        Write-LauncherLog "GUIアプリケーションが見つかりません: $guiAppPath" -Level Error
        return $false
    }
    
    Write-LauncherLog "GUIアプリケーションを起動しています..." -Level Info
    
    if ($Script:PowerShell7Path) {
        & $Script:PowerShell7Path -File $guiAppPath
    } else {
        & $guiAppPath
    }
    
    return $true
}

# CLI アプリケーション起動
function Start-CliApplication {
    $cliAppPath = Join-Path $Script:ToolRoot "Apps\CliApp.ps1"
    
    if (-not (Test-Path $cliAppPath)) {
        Write-LauncherLog "CLIアプリケーションが見つかりません: $cliAppPath" -Level Error
        return $false
    }
    
    Write-LauncherLog "CLIアプリケーションを起動しています..." -Level Info
    
    if ($Script:PowerShell7Path) {
        & $Script:PowerShell7Path -File $cliAppPath
    } else {
        & $cliAppPath
    }
    
    return $true
}

# メイン実行
function Main {
    Show-LauncherBanner
    
    $Script:IsAdmin = Test-AdminRights
    Write-LauncherLog "管理者権限: $(if ($Script:IsAdmin) { '有効' } else { '無効' })" -Level Info
    
    # PowerShell バージョン確認
    $psInfo = Get-PowerShellVersionInfo
    Write-LauncherLog "現在のPowerShell: v$($psInfo.Current) ($($psInfo.Current.ToString()))" -Level Info
    
    if (-not $psInfo.Is751Plus) {
        Write-LauncherLog "PowerShell 7.5.1以上が必要です" -Level Warning
        
        # PowerShell 7の検索
        $Script:PowerShell7Path = Find-PowerShell7Path
        
        if (-not $Script:PowerShell7Path) {
            Write-LauncherLog "PowerShell 7.5.1が見つかりません" -Level Warning
            
            if (-not $Script:IsAdmin -and $ForceAdmin) {
                Start-AsAdmin
                return
            }
            
            if ($Script:IsAdmin) {
                $installResult = Install-PowerShell751
                if ($installResult) {
                    Write-LauncherLog "インストール完了後、ランチャーを再実行してください" -Level Success
                    Read-Host "Enterキーを押して終了"
                    return
                }
            } else {
                Write-LauncherLog "PowerShell 7.5.1のインストールには管理者権限が必要です" -Level Error
                Write-LauncherLog "管理者として実行するか、手動でインストールしてください" -Level Info
                Read-Host "Enterキーを押して終了"
                return
            }
        } else {
            Write-LauncherLog "PowerShell 7を使用してアプリケーションを再起動します" -Level Info
            $arguments = "-File `"$($MyInvocation.MyCommand.Path)`""
            if ($Mode -ne "auto") { $arguments += " -Mode $Mode" }
            if ($SkipPowerShell7Install) { $arguments += " -SkipPowerShell7Install" }
            if ($VerboseOutput) { $arguments += " -VerboseOutput" }
            
            & $Script:PowerShell7Path $arguments
            return
        }
    }
    
    # アプリケーションモード決定
    $appMode = Get-ApplicationMode
    Write-LauncherLog "アプリケーションモード: $appMode" -Level Info
    
    # アプリケーション起動
    $success = switch ($appMode) {
        "gui" { Start-GuiApplication }
        "cli" { Start-CliApplication }
        default { 
            Write-LauncherLog "無効なアプリケーションモード: $appMode" -Level Error
            $false
        }
    }
    
    if (-not $success) {
        Write-LauncherLog "アプリケーションの起動に失敗しました" -Level Error
        Read-Host "Enterキーを押して終了"
    }
}

# エラーハンドリング
trap {
    Write-LauncherLog "予期しないエラーが発生しました: $($_.Exception.Message)" -Level Error
    Write-LauncherLog "スタックトレース: $($_.ScriptStackTrace)" -Level Error
    Read-Host "Enterキーを押して終了"
    exit 1
}

# 実行開始
Main