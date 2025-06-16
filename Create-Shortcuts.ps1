# ================================================================================
# Microsoft 365統合管理ツール - ショートカット作成スクリプト
# Create-Shortcuts.ps1
# デスクトップ・スタートメニューショートカット自動作成
# ================================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "デスクトップにショートカットを作成")]
    [switch]$Desktop = $true,
    
    [Parameter(Mandatory = $false, HelpMessage = "スタートメニューにショートカットを作成")]
    [switch]$StartMenu = $true,
    
    [Parameter(Mandatory = $false, HelpMessage = "すべてのユーザー向けに作成（管理者権限必要）")]
    [switch]$AllUsers = $false,
    
    [Parameter(Mandatory = $false, HelpMessage = "既存のショートカットを上書き")]
    [switch]$Force = $false,
    
    [Parameter(Mandatory = $false, HelpMessage = "作成確認をスキップ")]
    [switch]$Quiet = $false
)

# グローバル変数
$Script:ToolRoot = $PSScriptRoot
$Script:ToolName = "Microsoft 365統合管理ツール"
$Script:ShortcutsCreated = @()

# ログ出力関数
function Write-ShortcutLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
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

# 管理者権限確認
function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ショートカット作成確認
function Confirm-ShortcutCreation {
    param(
        [string]$ShortcutName,
        [string]$Location
    )
    
    if ($Quiet) {
        return $true
    }
    
    Write-Host "`n📝 ショートカット作成確認" -ForegroundColor Yellow
    Write-Host "名前: $ShortcutName" -ForegroundColor White
    Write-Host "場所: $Location" -ForegroundColor White
    
    $response = Read-Host "作成しますか？ (Y/n)"
    return ($response -eq "" -or $response -match "^[Yy]")
}

# ショートカット作成
function New-ApplicationShortcut {
    param(
        [string]$Name,
        [string]$Description,
        [string]$TargetPath,
        [string]$Arguments,
        [string]$WorkingDirectory,
        [string]$IconPath,
        [string]$DestinationPath
    )
    
    try {
        # 既存ショートカット確認
        if ((Test-Path $DestinationPath) -and -not $Force) {
            Write-ShortcutLog "ショートカットが既に存在します: $DestinationPath" -Level Warning
            
            if (-not $Quiet) {
                $overwrite = Read-Host "上書きしますか？ (y/N)"
                if ($overwrite -notmatch "^[Yy]") {
                    Write-ShortcutLog "ショートカットの作成をスキップしました: $Name" -Level Info
                    return $false
                }
            } else {
                Write-ShortcutLog "既存のショートカットをスキップします: $Name" -Level Info
                return $false
            }
        }
        
        # WScript.Shell オブジェクト作成
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($DestinationPath)
        
        # ショートカット設定
        $shortcut.TargetPath = $TargetPath
        $shortcut.Arguments = $Arguments
        $shortcut.WorkingDirectory = $WorkingDirectory
        $shortcut.Description = $Description
        $shortcut.WindowStyle = 1  # Normal window
        
        # アイコン設定
        if ($IconPath -and (Test-Path $IconPath)) {
            $shortcut.IconLocation = $IconPath
        } else {
            # デフォルトアイコン（PowerShell）
            $shortcut.IconLocation = "powershell.exe,0"
        }
        
        # ショートカット保存
        $shortcut.Save()
        
        # 作成確認
        if (Test-Path $DestinationPath) {
            Write-ShortcutLog "ショートカットを作成しました: $Name" -Level Success
            $Script:ShortcutsCreated += @{
                Name = $Name
                Path = $DestinationPath
                Type = $(if ($DestinationPath -like "*Desktop*") { "Desktop" } else { "StartMenu" })
            }
            return $true
        } else {
            throw "ファイルが作成されませんでした"
        }
    }
    catch {
        Write-ShortcutLog "ショートカット作成エラー: $Name - $($_.Exception.Message)" -Level Error
        return $false
    }
    finally {
        # COMオブジェクトの解放
        if ($shortcut) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shortcut) | Out-Null }
        if ($shell) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null }
    }
}

# デスクトップショートカット作成
function New-DesktopShortcuts {
    Write-ShortcutLog "デスクトップショートカットを作成中..." -Level Info
    
    # デスクトップパス取得
    if ($AllUsers) {
        $desktopPath = [Environment]::GetFolderPath("CommonDesktopDirectory")
        $userType = "全ユーザー"
    } else {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $userType = "現在のユーザー"
    }
    
    Write-ShortcutLog "デスクトップパス ($userType): $desktopPath" -Level Info
    
    # ランチャーパス
    $launcherPath = Join-Path $Script:ToolRoot "run_launcher.ps1"
    $pwshPath = "pwsh.exe"  # PowerShell 7
    $powershellPath = "powershell.exe"  # PowerShell 5.1
    
    # ショートカット定義
    $shortcuts = @(
        @{
            Name = "$Script:ToolName (GUI)"
            Description = "$Script:ToolName をGUIモードで起動"
            TargetPath = $pwshPath
            Arguments = "-File `"$launcherPath`" -Mode gui"
            FileName = "M365管理ツール-GUI.lnk"
        },
        @{
            Name = "$Script:ToolName (CLI)"
            Description = "$Script:ToolName をCLIモードで起動"
            TargetPath = $pwshPath
            Arguments = "-File `"$launcherPath`" -Mode cli"
            FileName = "M365管理ツール-CLI.lnk"
        },
        @{
            Name = "$Script:ToolName (自動選択)"
            Description = "$Script:ToolName を自動モード選択で起動"
            TargetPath = $pwshPath
            Arguments = "-File `"$launcherPath`""
            FileName = "M365管理ツール.lnk"
        }
    )
    
    # PowerShell 5.1用ショートカット（互換性）
    $shortcuts += @{
        Name = "$Script:ToolName (PS5.1 CLI)"
        Description = "$Script:ToolName をPowerShell 5.1 CLIモードで起動"
        TargetPath = $powershellPath
        Arguments = "-File `"$launcherPath`" -Mode cli"
        FileName = "M365管理ツール-PS51.lnk"
    }
    
    $successCount = 0
    foreach ($shortcut in $shortcuts) {
        $destinationPath = Join-Path $desktopPath $shortcut.FileName
        
        if (Confirm-ShortcutCreation -ShortcutName $shortcut.Name -Location $desktopPath) {
            $result = New-ApplicationShortcut -Name $shortcut.Name -Description $shortcut.Description -TargetPath $shortcut.TargetPath -Arguments $shortcut.Arguments -WorkingDirectory $Script:ToolRoot -DestinationPath $destinationPath
            if ($result) { $successCount++ }
        }
    }
    
    Write-ShortcutLog "デスクトップショートカット作成完了: $successCount/$($shortcuts.Count)" -Level Success
}

# スタートメニューショートカット作成
function New-StartMenuShortcuts {
    Write-ShortcutLog "スタートメニューショートカットを作成中..." -Level Info
    
    # スタートメニューパス取得
    if ($AllUsers) {
        $startMenuPath = [Environment]::GetFolderPath("CommonPrograms")
        $userType = "全ユーザー"
    } else {
        $startMenuPath = [Environment]::GetFolderPath("Programs")
        $userType = "現在のユーザー"
    }
    
    # アプリケーション専用フォルダ作成
    $appFolderPath = Join-Path $startMenuPath $Script:ToolName
    if (-not (Test-Path $appFolderPath)) {
        New-Item -Path $appFolderPath -ItemType Directory -Force | Out-Null
        Write-ShortcutLog "アプリケーションフォルダを作成: $appFolderPath" -Level Info
    }
    
    Write-ShortcutLog "スタートメニューパス ($userType): $appFolderPath" -Level Info
    
    # ランチャーパス
    $launcherPath = Join-Path $Script:ToolRoot "run_launcher.ps1"
    $pwshPath = "pwsh.exe"
    $powershellPath = "powershell.exe"
    
    # ショートカット定義
    $shortcuts = @(
        @{
            Name = "GUI モード"
            Description = "$Script:ToolName をGUIモードで起動"
            TargetPath = $pwshPath
            Arguments = "-File `"$launcherPath`" -Mode gui"
            FileName = "GUI モード.lnk"
        },
        @{
            Name = "CLI モード"
            Description = "$Script:ToolName をCLIモードで起動"
            TargetPath = $pwshPath
            Arguments = "-File `"$launcherPath`" -Mode cli"
            FileName = "CLI モード.lnk"
        },
        @{
            Name = "起動"
            Description = "$Script:ToolName を起動（自動モード選択）"
            TargetPath = $pwshPath
            Arguments = "-File `"$launcherPath`""
            FileName = "起動.lnk"
        },
        @{
            Name = "設定ファイル編集"
            Description = "設定ファイルを編集"
            TargetPath = "notepad.exe"
            Arguments = "`"$(Join-Path $Script:ToolRoot 'Config\appsettings.json')`""
            FileName = "設定ファイル編集.lnk"
        },
        @{
            Name = "レポートフォルダを開く"
            Description = "生成されたレポートフォルダを開く"
            TargetPath = "explorer.exe"
            Arguments = "`"$(Join-Path $Script:ToolRoot 'Reports')`""
            FileName = "レポートフォルダを開く.lnk"
        },
        @{
            Name = "ヘルプ・ドキュメント"
            Description = "ヘルプとドキュメントフォルダを開く"
            TargetPath = "explorer.exe"
            Arguments = "`"$(Join-Path $Script:ToolRoot 'Docs')`""
            FileName = "ヘルプ・ドキュメント.lnk"
        }
    )
    
    $successCount = 0
    foreach ($shortcut in $shortcuts) {
        $destinationPath = Join-Path $appFolderPath $shortcut.FileName
        
        if (Confirm-ShortcutCreation -ShortcutName $shortcut.Name -Location $appFolderPath) {
            $result = New-ApplicationShortcut -Name $shortcut.Name -Description $shortcut.Description -TargetPath $shortcut.TargetPath -Arguments $shortcut.Arguments -WorkingDirectory $Script:ToolRoot -DestinationPath $destinationPath
            if ($result) { $successCount++ }
        }
    }
    
    Write-ShortcutLog "スタートメニューショートカット作成完了: $successCount/$($shortcuts.Count)" -Level Success
}

# 作成結果表示
function Show-CreationSummary {
    Write-Host "`n" + "="*60 -ForegroundColor Gray
    Write-Host "ショートカット作成結果" -ForegroundColor Yellow
    Write-Host "="*60 -ForegroundColor Gray
    
    if ($Script:ShortcutsCreated.Count -eq 0) {
        Write-Host "ショートカットは作成されませんでした。" -ForegroundColor Yellow
        return
    }
    
    $desktopShortcuts = $Script:ShortcutsCreated | Where-Object { $_.Type -eq "Desktop" }
    $startMenuShortcuts = $Script:ShortcutsCreated | Where-Object { $_.Type -eq "StartMenu" }
    
    if ($desktopShortcuts) {
        Write-Host "`n📋 デスクトップショートカット ($($desktopShortcuts.Count)個):" -ForegroundColor Green
        foreach ($shortcut in $desktopShortcuts) {
            Write-Host "  ✓ $($shortcut.Name)" -ForegroundColor White
        }
    }
    
    if ($startMenuShortcuts) {
        Write-Host "`n📁 スタートメニューショートカット ($($startMenuShortcuts.Count)個):" -ForegroundColor Green
        foreach ($shortcut in $startMenuShortcuts) {
            Write-Host "  ✓ $($shortcut.Name)" -ForegroundColor White
        }
    }
    
    Write-Host "`n🎉 合計 $($Script:ShortcutsCreated.Count) 個のショートカットが作成されました！" -ForegroundColor Green
    Write-Host "="*60 -ForegroundColor Gray
}

# メイン実行
function Main {
    Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                     ショートカット作成ツール                                     ║
║                Microsoft 365統合管理ツール 用                                  ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Blue
    
    Write-ShortcutLog "ショートカット作成を開始します..." -Level Info
    Write-ShortcutLog "ツールルート: $Script:ToolRoot" -Level Info
    
    # 管理者権限確認
    $isAdmin = Test-AdminRights
    Write-ShortcutLog "管理者権限: $(if ($isAdmin) { '有効' } else { '無効' })" -Level Info
    
    if ($AllUsers -and -not $isAdmin) {
        Write-ShortcutLog "全ユーザー向けショートカット作成には管理者権限が必要です" -Level Error
        Write-ShortcutLog "管理者として実行するか、-AllUsers パラメーターを外してください" -Level Info
        return
    }
    
    # ランチャーファイル確認
    $launcherPath = Join-Path $Script:ToolRoot "run_launcher.ps1"
    if (-not (Test-Path $launcherPath)) {
        Write-ShortcutLog "ランチャーファイルが見つかりません: $launcherPath" -Level Error
        Write-ShortcutLog "スクリプトを正しいディレクトリから実行してください" -Level Info
        return
    }
    
    # ショートカット作成実行
    try {
        if ($Desktop) {
            New-DesktopShortcuts
        }
        
        if ($StartMenu) {
            New-StartMenuShortcuts
        }
        
        # 結果表示
        Show-CreationSummary
        
        Write-ShortcutLog "ショートカット作成処理が完了しました" -Level Success
    }
    catch {
        Write-ShortcutLog "予期しないエラーが発生しました: $($_.Exception.Message)" -Level Error
    }
}

# 実行開始
Main