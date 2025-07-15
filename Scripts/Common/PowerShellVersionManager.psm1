# PowerShell Version Manager Module
# PowerShell 7 自動検出・ダウンロード・起動管理

<#
.SYNOPSIS
PowerShell 7 シリーズへの統一化を支援するモジュール

.DESCRIPTION
このモジュールは以下の機能を提供します：
- PowerShell バージョンの自動検出
- PowerShell 7 の自動ダウンロード・インストール
- PowerShell 5 から PowerShell 7 への自動切り替え
- 統一されたPowerShell環境の確保

.NOTES
File Name  : PowerShellVersionManager.psm1
Author     : Microsoft Product Management Tools Team
Requires   : PowerShell 5.1 以上
#>

# グローバル変数
$global:PowerShellVersionManager = @{
    RequiredMajorVersion = 7
    MinimumVersion = [Version]"7.0.0"
    PreferredVersion = [Version]"7.4.0"
    LatestVersion = $null
    DownloadUrl = "https://github.com/PowerShell/PowerShell/releases/latest"
    InstallPath = "$env:ProgramFiles\PowerShell\7"
    PortableInstallPath = "$env:LOCALAPPDATA\Microsoft\PowerShell\7"
    LogPath = "Logs\PowerShellVersionManager.log"
    SupportedPlatforms = @("Windows", "Linux", "macOS")
}

# ログ機能
function Write-PSVMLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # コンソール出力
    switch ($Level) {
        "Info" { Write-Host $logEntry -ForegroundColor White }
        "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
        "Error" { Write-Host $logEntry -ForegroundColor Red }
        "Success" { Write-Host $logEntry -ForegroundColor Green }
    }
    
    # ファイル出力
    try {
        $logDir = Split-Path $global:PowerShellVersionManager.LogPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $global:PowerShellVersionManager.LogPath -Value $logEntry -Encoding UTF8
    }
    catch {
        # ログ出力失敗は無視
    }
}

# PowerShell バージョン検出
function Get-PowerShellVersionInfo {
    <#
    .SYNOPSIS
    現在のPowerShellバージョン情報を取得
    
    .DESCRIPTION
    実行中のPowerShellのバージョン情報を詳細に取得します
    
    .EXAMPLE
    Get-PowerShellVersionInfo
    #>
    
    try {
        $versionInfo = @{
            Version = $PSVersionTable.PSVersion
            MajorVersion = $PSVersionTable.PSVersion.Major
            FullVersion = $PSVersionTable.PSVersion.ToString()
            Edition = $PSVersionTable.PSEdition
            Platform = $PSVersionTable.Platform
            OS = $PSVersionTable.OS
            ExecutablePath = $null
            IsCore = $PSVersionTable.PSEdition -eq "Core"
            IsDesktop = $PSVersionTable.PSEdition -eq "Desktop"
            IsPowerShell7Plus = $PSVersionTable.PSVersion.Major -ge 7
            IsPowerShell5 = $PSVersionTable.PSVersion.Major -eq 5
            IsSupported = $PSVersionTable.PSVersion.Major -ge 7
        }
        
        # 実行ファイルパスの取得
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $versionInfo.ExecutablePath = (Get-Process -Id $PID).Path
        }
        else {
            $versionInfo.ExecutablePath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
        }
        
        Write-PSVMLog "PowerShell バージョン情報を取得しました: $($versionInfo.FullVersion) ($($versionInfo.Edition))" -Level "Info"
        return $versionInfo
    }
    catch {
        Write-PSVMLog "PowerShell バージョン情報の取得に失敗しました: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# PowerShell 7 インストール状況確認
function Test-PowerShell7Installation {
    <#
    .SYNOPSIS
    PowerShell 7 のインストール状況を確認
    
    .DESCRIPTION
    システムにPowerShell 7がインストールされているかを確認します
    
    .EXAMPLE
    Test-PowerShell7Installation
    #>
    
    try {
        $installations = @()
        
        # 標準インストールパス
        $standardPaths = @(
            "$env:ProgramFiles\PowerShell\7\pwsh.exe",
            "$env:ProgramFiles\PowerShell\pwsh.exe",
            "$env:ProgramFiles(x86)\PowerShell\7\pwsh.exe"
        )
        
        # ポータブルインストールパス
        $portablePaths = @(
            "$env:LOCALAPPDATA\Microsoft\PowerShell\7\pwsh.exe",
            "$env:USERPROFILE\PowerShell\pwsh.exe"
        )
        
        # PATH環境変数から検索
        $pathCommands = @("pwsh", "pwsh.exe")
        
        foreach ($path in ($standardPaths + $portablePaths)) {
            if (Test-Path $path) {
                try {
                    $versionOutput = & $path --version 2>$null
                    if ($versionOutput -match "PowerShell (\d+\.\d+\.\d+)") {
                        $installations += @{
                            Path = $path
                            Version = [Version]$matches[1]
                            Type = if ($standardPaths -contains $path) { "Standard" } else { "Portable" }
                            IsAccessible = $true
                        }
                    }
                }
                catch {
                    Write-PSVMLog "PowerShell 7 バージョン確認に失敗: $path" -Level "Warning"
                }
            }
        }
        
        # PATH環境変数から検索
        foreach ($cmd in $pathCommands) {
            try {
                $cmdPath = (Get-Command $cmd -ErrorAction SilentlyContinue).Source
                if ($cmdPath -and -not ($installations | Where-Object { $_.Path -eq $cmdPath })) {
                    $versionOutput = & $cmd --version 2>$null
                    if ($versionOutput -match "PowerShell (\d+\.\d+\.\d+)") {
                        $installations += @{
                            Path = $cmdPath
                            Version = [Version]$matches[1]
                            Type = "PATH"
                            IsAccessible = $true
                        }
                    }
                }
            }
            catch {
                # PATH検索失敗は無視
            }
        }
        
        if ($installations.Count -gt 0) {
            Write-PSVMLog "PowerShell 7 インストールが見つかりました: $($installations.Count) 個" -Level "Success"
            return $installations | Sort-Object Version -Descending
        }
        else {
            Write-PSVMLog "PowerShell 7 インストールが見つかりませんでした" -Level "Warning"
            return $null
        }
    }
    catch {
        Write-PSVMLog "PowerShell 7 インストール確認中にエラーが発生しました: $($_.Exception.Message)" -Level "Error"
        return $null
    }
}

# PowerShell 7 最新版情報取得
function Get-LatestPowerShell7Version {
    <#
    .SYNOPSIS
    PowerShell 7 の最新バージョン情報を取得
    
    .DESCRIPTION
    GitHubから最新のPowerShell 7リリース情報を取得します
    
    .EXAMPLE
    Get-LatestPowerShell7Version
    #>
    
    try {
        Write-PSVMLog "最新のPowerShell 7 バージョン情報を取得中..." -Level "Info"
        
        # GitHub API を使用して最新バージョン情報を取得
        $apiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $response = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
        
        $latestVersion = $response.tag_name -replace '^v', ''
        $releaseInfo = @{
            Version = [Version]$latestVersion
            TagName = $response.tag_name
            Name = $response.name
            PublishedAt = [DateTime]$response.published_at
            Assets = $response.assets
            DownloadUrl = $response.html_url
            Body = $response.body
        }
        
        # Windows用インストーラーのダウンロードURL
        $windowsAssets = $response.assets | Where-Object { 
            $_.name -match "PowerShell-.*-win-x64\.(msi|zip)$" 
        }
        
        if ($windowsAssets) {
            $releaseInfo.WindowsInstallerUrl = ($windowsAssets | Where-Object { $_.name -match "\.msi$" } | Select-Object -First 1).browser_download_url
            $releaseInfo.WindowsPortableUrl = ($windowsAssets | Where-Object { $_.name -match "\.zip$" } | Select-Object -First 1).browser_download_url
        }
        
        Write-PSVMLog "最新版: PowerShell $latestVersion が見つかりました" -Level "Success"
        return $releaseInfo
    }
    catch {
        Write-PSVMLog "最新バージョン情報の取得に失敗しました: $($_.Exception.Message)" -Level "Error"
        # フォールバック: 既知の安定版を返す
        return @{
            Version = [Version]"7.4.0"
            TagName = "v7.4.0"
            Name = "PowerShell 7.4.0"
            DownloadUrl = "https://github.com/PowerShell/PowerShell/releases/tag/v7.4.0"
            WindowsInstallerUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-win-x64.msi"
            WindowsPortableUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/PowerShell-7.4.0-win-x64.zip"
        }
    }
}

# PowerShell 7 ダウンロード・インストール
function Install-PowerShell7 {
    <#
    .SYNOPSIS
    PowerShell 7 を自動ダウンロード・インストール
    
    .PARAMETER InstallType
    インストール方法を指定 (Standard, Portable, Download)
    
    .PARAMETER Force
    強制インストール
    
    .EXAMPLE
    Install-PowerShell7 -InstallType Standard
    
    .EXAMPLE
    Install-PowerShell7 -InstallType Portable
    #>
    
    param(
        [ValidateSet("Standard", "Portable", "Download")]
        [string]$InstallType = "Standard",
        [switch]$Force
    )
    
    try {
        Write-PSVMLog "PowerShell 7 インストールを開始します (タイプ: $InstallType)" -Level "Info"
        
        # 最新バージョン情報取得
        $latestInfo = Get-LatestPowerShell7Version
        if (-not $latestInfo) {
            throw "最新バージョン情報の取得に失敗しました"
        }
        
        # インストール済みチェック
        if (-not $Force) {
            $existing = Test-PowerShell7Installation
            if ($existing) {
                $newestExisting = $existing | Sort-Object Version -Descending | Select-Object -First 1
                if ($newestExisting.Version -ge $latestInfo.Version) {
                    Write-PSVMLog "PowerShell 7 は既に最新版がインストールされています: $($newestExisting.Version)" -Level "Success"
                    return $newestExisting
                }
            }
        }
        
        # ダウンロード準備
        $downloadUrl = switch ($InstallType) {
            "Standard" { $latestInfo.WindowsInstallerUrl }
            "Portable" { $latestInfo.WindowsPortableUrl }
            "Download" { $latestInfo.WindowsInstallerUrl }
        }
        
        if (-not $downloadUrl) {
            throw "ダウンロードURLが見つかりません"
        }
        
        # ダウンロード
        $fileName = Split-Path $downloadUrl -Leaf
        $downloadPath = Join-Path $env:TEMP $fileName
        
        Write-PSVMLog "PowerShell 7 をダウンロード中: $downloadUrl" -Level "Info"
        
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing
            Write-PSVMLog "ダウンロード完了: $downloadPath" -Level "Success"
        }
        catch {
            throw "ダウンロードに失敗しました: $($_.Exception.Message)"
        }
        
        # インストール実行
        switch ($InstallType) {
            "Standard" {
                Write-PSVMLog "PowerShell 7 をインストール中..." -Level "Info"
                
                # 管理者権限チェック
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
                
                if (-not $isAdmin) {
                    Write-PSVMLog "管理者権限が必要です。管理者として実行してください。" -Level "Warning"
                    
                    # 管理者権限で再実行を提案
                    $choice = Read-Host "管理者権限で実行しますか? (y/N)"
                    if ($choice -match "^[yY]") {
                        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -Command `"& { Import-Module '$PSScriptRoot\PowerShellVersionManager.psm1'; Install-PowerShell7 -InstallType Standard -Force }`"" -Verb RunAs
                        return
                    }
                    else {
                        throw "管理者権限が必要なため、インストールを中止しました"
                    }
                }
                
                # MSIインストール実行
                $installArgs = @(
                    "/i", $downloadPath,
                    "/quiet",
                    "/norestart",
                    "ENABLE_PSREMOTING=1",
                    "REGISTER_MANIFEST=1"
                )
                
                $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru
                
                if ($process.ExitCode -eq 0) {
                    Write-PSVMLog "PowerShell 7 のインストールが完了しました" -Level "Success"
                    
                    # インストール後の確認
                    Start-Sleep -Seconds 3
                    $newInstallation = Test-PowerShell7Installation
                    if ($newInstallation) {
                        return $newInstallation | Sort-Object Version -Descending | Select-Object -First 1
                    }
                }
                else {
                    throw "インストールに失敗しました (終了コード: $($process.ExitCode))"
                }
            }
            
            "Portable" {
                Write-PSVMLog "PowerShell 7 をポータブルインストール中..." -Level "Info"
                
                # 展開先ディレクトリ作成
                $extractPath = $global:PowerShellVersionManager.PortableInstallPath
                if (-not (Test-Path $extractPath)) {
                    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
                }
                
                # ZIP展開
                try {
                    Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
                    Write-PSVMLog "ポータブルインストール完了: $extractPath" -Level "Success"
                    
                    # PATH環境変数への追加を提案
                    $choice = Read-Host "PATH環境変数に追加しますか? (y/N)"
                    if ($choice -match "^[yY]") {
                        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
                        if ($currentPath -notlike "*$extractPath*") {
                            [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$extractPath", "User")
                            Write-PSVMLog "PATH環境変数に追加しました: $extractPath" -Level "Success"
                        }
                    }
                    
                    return @{
                        Path = Join-Path $extractPath "pwsh.exe"
                        Version = $latestInfo.Version
                        Type = "Portable"
                        IsAccessible = $true
                    }
                }
                catch {
                    throw "ZIP展開に失敗しました: $($_.Exception.Message)"
                }
            }
            
            "Download" {
                Write-PSVMLog "PowerShell 7 をダウンロードしました: $downloadPath" -Level "Success"
                Write-PSVMLog "手動でインストールしてください: $downloadPath" -Level "Info"
                
                # ダウンロードしたファイルを開く
                $choice = Read-Host "ダウンロードしたファイルを開きますか? (y/N)"
                if ($choice -match "^[yY]") {
                    Start-Process -FilePath $downloadPath
                }
                
                return @{
                    Path = $downloadPath
                    Version = $latestInfo.Version
                    Type = "Download"
                    IsAccessible = $false
                }
            }
        }
    }
    catch {
        Write-PSVMLog "PowerShell 7 インストール中にエラーが発生しました: $($_.Exception.Message)" -Level "Error"
        throw
    }
    finally {
        # 一時ファイルクリーンアップ
        if ($downloadPath -and (Test-Path $downloadPath)) {
            try {
                Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
            }
            catch {
                # クリーンアップ失敗は無視
            }
        }
    }
}

# PowerShell 7 への切り替え
function Switch-ToPowerShell7 {
    <#
    .SYNOPSIS
    PowerShell 7 に切り替えて現在のスクリプトを再実行
    
    .PARAMETER ScriptPath
    再実行するスクリプトのパス
    
    .PARAMETER Arguments
    スクリプトに渡す引数
    
    .EXAMPLE
    Switch-ToPowerShell7 -ScriptPath "C:\Scripts\MyScript.ps1" -Arguments @("-Param1", "Value1")
    #>
    
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )
    
    try {
        Write-PSVMLog "PowerShell 7 への切り替えを開始します" -Level "Info"
        
        # PowerShell 7 インストール確認
        $installations = Test-PowerShell7Installation
        if (-not $installations) {
            throw "PowerShell 7 がインストールされていません"
        }
        
        # 最新版を選択
        $bestInstallation = $installations | Sort-Object Version -Descending | Select-Object -First 1
        $pwsh7Path = $bestInstallation.Path
        
        Write-PSVMLog "PowerShell 7 が見つかりました: $pwsh7Path (Version: $($bestInstallation.Version))" -Level "Success"
        
        # スクリプト再実行
        if ($ScriptPath) {
            Write-PSVMLog "PowerShell 7 でスクリプトを再実行します: $ScriptPath" -Level "Info"
            
            # 引数を準備
            $argumentList = @("-ExecutionPolicy", "Bypass", "-File", $ScriptPath) + $Arguments
            
            # PowerShell 7 で実行
            Start-Process -FilePath $pwsh7Path -ArgumentList $argumentList -Wait
        }
        else {
            Write-PSVMLog "PowerShell 7 を起動します" -Level "Info"
            Start-Process -FilePath $pwsh7Path
        }
    }
    catch {
        Write-PSVMLog "PowerShell 7 への切り替えに失敗しました: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# PowerShell バージョン確認・切り替えメイン関数
function Confirm-PowerShell7Environment {
    <#
    .SYNOPSIS
    PowerShell 7 環境を確認し、必要に応じて切り替えを実行
    
    .PARAMETER AutoInstall
    自動インストールを有効にする
    
    .PARAMETER Force
    強制的に確認を実行
    
    .PARAMETER ScriptPath
    現在のスクリプトパス（自動再実行用）
    
    .EXAMPLE
    Confirm-PowerShell7Environment -AutoInstall
    
    .EXAMPLE
    Confirm-PowerShell7Environment -Force -ScriptPath $MyInvocation.MyCommand.Path
    #>
    
    param(
        [switch]$AutoInstall,
        [switch]$Force,
        [string]$ScriptPath
    )
    
    try {
        Write-PSVMLog "PowerShell 7 環境確認を開始します" -Level "Info"
        
        # 現在のバージョン確認
        $currentVersion = Get-PowerShellVersionInfo
        
        Write-Host "`n" -NoNewline
        Write-Host "🔍 " -ForegroundColor Blue -NoNewline
        Write-Host "PowerShell環境チェック" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "現在のPowerShell: " -NoNewline
        Write-Host "$($currentVersion.FullVersion) " -ForegroundColor White -NoNewline
        Write-Host "($($currentVersion.Edition))" -ForegroundColor Gray
        Write-Host "実行パス: " -NoNewline
        Write-Host "$($currentVersion.ExecutablePath)" -ForegroundColor Gray
        Write-Host "プラットフォーム: " -NoNewline
        Write-Host "$($currentVersion.Platform)" -ForegroundColor Gray
        
        # PowerShell 7 確認
        if ($currentVersion.IsPowerShell7Plus) {
            Write-Host "✅ " -ForegroundColor Green -NoNewline
            Write-Host "PowerShell 7 シリーズで実行中です" -ForegroundColor Green
            Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
            return $true
        }
        
        # PowerShell 5 の場合
        if ($currentVersion.IsPowerShell5) {
            Write-Host "⚠️  " -ForegroundColor Yellow -NoNewline
            Write-Host "PowerShell 5 で実行中です" -ForegroundColor Yellow
            Write-Host "📋 " -ForegroundColor Blue -NoNewline
            Write-Host "このツールはPowerShell 7 での実行を推奨します" -ForegroundColor White
            Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
            
            # PowerShell 7 インストール確認
            Write-Host "🔍 PowerShell 7 のインストール状況を確認中..." -ForegroundColor Cyan
            $installations = Test-PowerShell7Installation
            
            if ($installations) {
                Write-Host "✅ " -ForegroundColor Green -NoNewline
                Write-Host "PowerShell 7 がインストールされています" -ForegroundColor Green
                
                foreach ($installation in $installations) {
                    Write-Host "   📁 " -ForegroundColor Blue -NoNewline
                    Write-Host "$($installation.Path) " -ForegroundColor White -NoNewline
                    Write-Host "(Version: $($installation.Version), Type: $($installation.Type))" -ForegroundColor Gray
                }
                
                # 切り替え提案
                Write-Host "`n🚀 " -ForegroundColor Blue -NoNewline
                Write-Host "PowerShell 7 に切り替えて実行しますか?" -ForegroundColor White
                Write-Host "   [Y] はい (推奨)   [N] いいえ   [?] ヘルプ" -ForegroundColor Yellow
                
                do {
                    $choice = Read-Host "選択してください"
                    switch ($choice.ToLower()) {
                        "y" { 
                            try {
                                Switch-ToPowerShell7 -ScriptPath $ScriptPath
                                return $false # 現在のセッションは終了
                            }
                            catch {
                                Write-PSVMLog "PowerShell 7 への切り替えに失敗しました: $($_.Exception.Message)" -Level "Error"
                                return $false
                            }
                        }
                        "n" { 
                            Write-Host "⚠️  " -ForegroundColor Yellow -NoNewline
                            Write-Host "PowerShell 5 で続行します。一部機能が制限される場合があります。" -ForegroundColor Yellow
                            return $true
                        }
                        "?" {
                            Write-Host "`n📖 " -ForegroundColor Blue -NoNewline
                            Write-Host "PowerShell 7 の利点:" -ForegroundColor White
                            Write-Host "   • より高速な実行" -ForegroundColor Gray
                            Write-Host "   • 改良されたエラーハンドリング" -ForegroundColor Gray
                            Write-Host "   • クロスプラットフォーム対応" -ForegroundColor Gray
                            Write-Host "   • 最新の機能とセキュリティ" -ForegroundColor Gray
                            Write-Host "   • Microsoft Graph との互換性向上" -ForegroundColor Gray
                            Write-Host ""
                        }
                        default {
                            Write-Host "❌ 無効な選択です。Y、N、または ? を入力してください。" -ForegroundColor Red
                        }
                    }
                } while ($choice -notmatch "^[ynYN]$")
            }
            else {
                Write-Host "❌ " -ForegroundColor Red -NoNewline
                Write-Host "PowerShell 7 がインストールされていません" -ForegroundColor Red
                
                # インストール提案
                Write-Host "`n📥 " -ForegroundColor Blue -NoNewline
                Write-Host "PowerShell 7 をダウンロード・インストールしますか?" -ForegroundColor White
                Write-Host "   [Y] はい (推奨)   [N] いいえ   [D] ダウンロードのみ   [?] ヘルプ" -ForegroundColor Yellow
                
                do {
                    $choice = Read-Host "選択してください"
                    switch ($choice.ToLower()) {
                        "y" { 
                            try {
                                if ($AutoInstall) {
                                    Install-PowerShell7 -InstallType "Standard"
                                }
                                else {
                                    Install-PowerShell7 -InstallType "Portable"
                                }
                                
                                # インストール後に切り替え
                                Write-Host "🔄 PowerShell 7 に切り替えます..." -ForegroundColor Cyan
                                Switch-ToPowerShell7 -ScriptPath $ScriptPath
                                return $false # 現在のセッションは終了
                            }
                            catch {
                                Write-PSVMLog "PowerShell 7 のインストールに失敗しました: $($_.Exception.Message)" -Level "Error"
                                Write-Host "❌ インストールに失敗しました。PowerShell 5 で続行します。" -ForegroundColor Red
                                return $true
                            }
                        }
                        "n" { 
                            Write-Host "⚠️  " -ForegroundColor Yellow -NoNewline
                            Write-Host "PowerShell 5 で続行します。一部機能が制限される場合があります。" -ForegroundColor Yellow
                            return $true
                        }
                        "d" {
                            try {
                                Install-PowerShell7 -InstallType "Download"
                                Write-Host "📥 " -ForegroundColor Blue -NoNewline
                                Write-Host "ダウンロードが完了しました。手動でインストールしてください。" -ForegroundColor White
                                return $false # インストール後に再実行を促す
                            }
                            catch {
                                Write-PSVMLog "PowerShell 7 のダウンロードに失敗しました: $($_.Exception.Message)" -Level "Error"
                                Write-Host "❌ ダウンロードに失敗しました。PowerShell 5 で続行します。" -ForegroundColor Red
                                return $true
                            }
                        }
                        "?" {
                            Write-Host "`n📖 " -ForegroundColor Blue -NoNewline
                            Write-Host "インストール方法:" -ForegroundColor White
                            Write-Host "   [Y] はい: ポータブルインストール（推奨）" -ForegroundColor Gray
                            Write-Host "       ユーザーフォルダにインストール、管理者権限不要" -ForegroundColor Gray
                            Write-Host "   [D] ダウンロードのみ: インストーラーをダウンロード" -ForegroundColor Gray
                            Write-Host "       手動でインストール、管理者権限でのシステム全体インストール" -ForegroundColor Gray
                            Write-Host ""
                        }
                        default {
                            Write-Host "❌ 無効な選択です。Y、N、D、または ? を入力してください。" -ForegroundColor Red
                        }
                    }
                } while ($choice -notmatch "^[yndYND]$")
            }
        }
        else {
            Write-Host "❌ " -ForegroundColor Red -NoNewline
            Write-Host "サポートされていないPowerShellバージョンです" -ForegroundColor Red
            Write-Host "📋 " -ForegroundColor Blue -NoNewline
            Write-Host "PowerShell 7 をインストールしてください" -ForegroundColor White
            return $false
        }
    }
    catch {
        Write-PSVMLog "PowerShell 7 環境確認中にエラーが発生しました: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# モジュール初期化時の自動チェック（オプション）
function Initialize-PowerShell7Check {
    <#
    .SYNOPSIS
    モジュール読み込み時の自動チェック
    
    .PARAMETER EnableAutoCheck
    自動チェックを有効にする
    
    .EXAMPLE
    Initialize-PowerShell7Check -EnableAutoCheck
    #>
    
    param(
        [switch]$EnableAutoCheck
    )
    
    if ($EnableAutoCheck) {
        $currentVersion = Get-PowerShellVersionInfo
        if (-not $currentVersion.IsPowerShell7Plus) {
            Write-Host "💡 " -ForegroundColor Blue -NoNewline
            Write-Host "PowerShell 7 での実行を推奨します。" -ForegroundColor White -NoNewline
            Write-Host "Confirm-PowerShell7Environment" -ForegroundColor Cyan -NoNewline
            Write-Host " を実行してください。" -ForegroundColor White
        }
    }
}

# エクスポート関数
Export-ModuleMember -Function @(
    'Get-PowerShellVersionInfo',
    'Test-PowerShell7Installation',
    'Get-LatestPowerShell7Version',
    'Install-PowerShell7',
    'Switch-ToPowerShell7',
    'Confirm-PowerShell7Environment',
    'Initialize-PowerShell7Check'
)