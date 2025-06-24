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

# システム要件確認
function Test-SystemRequirements {
    $result = @{
        IsValid = $true
        Checks = @()
        Errors = @()
    }
    
    try {
        # PowerShellバージョン確認
        $psInfo = Get-PowerShellVersionInfo
        if ($psInfo.Is751Plus) {
            $result.Checks += "PowerShell $($psInfo.Current) (要件: 7.5.1以上)"
        } else {
            $result.Errors += "PowerShell $($psInfo.Current) は要件を満たしません (要件: 7.5.1以上)"
            $result.IsValid = $false
        }
        
        # OS確認
        if ($IsWindows -or [Environment]::OSVersion.Platform -eq "Win32NT") {
            if ([Environment]::OSVersion.Version.Major -ge 10) {
                $result.Checks += "Windows $([Environment]::OSVersion.Version) (要件: Windows 10以上)"
            } else {
                $result.Errors += "Windows $([Environment]::OSVersion.Version) は要件を満たしません (要件: Windows 10以上)"
                $result.IsValid = $false
            }
        } else {
            $result.Checks += "クロスプラットフォーム環境 ($($PSVersionTable.Platform))"
        }
        
        # 実行ポリシー確認
        $policy = Get-ExecutionPolicy -Scope CurrentUser
        if ($policy -eq "RemoteSigned" -or $policy -eq "Bypass" -or $policy -eq "Unrestricted") {
            $result.Checks += "実行ポリシー: $policy (適切)"
        } else {
            $result.Errors += "実行ポリシー '$policy' は推奨されません (推奨: RemoteSigned)"
            # 実行ポリシーは警告のみで停止させない
        }
        
        # ディスク容量確認（最低1GB）
        try {
            $drive = (Get-Item $Script:ToolRoot).PSDrive
            $freeSpace = [math]::Round(($drive.Free / 1GB), 2)
            if ($freeSpace -ge 1) {
                $result.Checks += "ディスク容量: ${freeSpace}GB 利用可能"
            } else {
                $result.Errors += "ディスク容量不足: ${freeSpace}GB (最低1GB必要)"
                $result.IsValid = $false
            }
        } catch {
            $result.Checks += "ディスク容量: 確認できませんでした"
        }
        
        # .NET Framework確認（PowerShell 7では不要だが情報として）
        try {
            $dotnetVersion = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
            $result.Checks += ".NET Runtime: $dotnetVersion"
        } catch {
            $result.Checks += ".NET Runtime: 確認できませんでした"
        }
        
        return $result
    }
    catch {
        $result.Errors += "システム要件確認エラー: $($_.Exception.Message)"
        $result.IsValid = $false
        return $result
    }
}

# 必要モジュールインストール
function Install-RequiredModules {
    $result = @{
        Success = $true
        InstalledModules = @()
        Errors = @()
    }
    
    $requiredModules = @(
        @{
            Name = "Microsoft.Graph"
            MinVersion = "1.0.0"
            Description = "Microsoft Graph PowerShell SDK"
        },
        @{
            Name = "ExchangeOnlineManagement"
            MinVersion = "3.0.0"
            Description = "Exchange Online Management"
        }
    )
    
    try {
        foreach ($module in $requiredModules) {
            Write-Host "  モジュール確認中: $($module.Name)..." -ForegroundColor Cyan
            
            # 既存モジュール確認
            $installedModule = Get-Module -ListAvailable -Name $module.Name | Sort-Object Version -Descending | Select-Object -First 1
            
            if ($installedModule) {
                if ($installedModule.Version -ge [Version]$module.MinVersion) {
                    $result.InstalledModules += "$($module.Name) v$($installedModule.Version) (既存)"
                    Write-Host "    ✓ 既にインストール済み: v$($installedModule.Version)" -ForegroundColor Green
                } else {
                    Write-Host "    ⚠ バージョンが古いため更新中..." -ForegroundColor Yellow
                    try {
                        # プログレス表示抑制
                        $ProgressPreference = 'SilentlyContinue'
                        
                        Install-Module $module.Name -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
                        $newModule = Get-Module -ListAvailable -Name $module.Name | Sort-Object Version -Descending | Select-Object -First 1
                        $result.InstalledModules += "$($module.Name) v$($newModule.Version) (更新)"
                        Write-Host "    ✓ 更新完了: v$($newModule.Version)" -ForegroundColor Green
                        
                        # プログレス表示復元
                        $ProgressPreference = 'Continue'
                    } catch {
                        $result.Errors += "$($module.Name) の更新に失敗: $($_.Exception.Message)"
                        $result.Success = $false
                        $ProgressPreference = 'Continue'
                    }
                }
            } else {
                Write-Host "    新規インストール中..." -ForegroundColor Yellow
                try {
                    # プログレス表示抑制
                    $ProgressPreference = 'SilentlyContinue'
                    
                    Install-Module $module.Name -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
                    $newModule = Get-Module -ListAvailable -Name $module.Name | Sort-Object Version -Descending | Select-Object -First 1
                    $result.InstalledModules += "$($module.Name) v$($newModule.Version) (新規)"
                    Write-Host "    ✓ インストール完了: v$($newModule.Version)" -ForegroundColor Green
                    
                    # プログレス表示復元
                    $ProgressPreference = 'Continue'
                } catch {
                    $result.Errors += "$($module.Name) のインストールに失敗: $($_.Exception.Message)"
                    $result.Success = $false
                    $ProgressPreference = 'Continue'
                }
            }
        }
        
        return $result
    }
    catch {
        $result.Errors += "モジュールインストールエラー: $($_.Exception.Message)"
        $result.Success = $false
        return $result
    }
}

# 実行ポリシー設定
function Set-ExecutionPolicyIfNeeded {
    $result = @{
        Success = $true
        Policy = ""
        Error = ""
    }
    
    try {
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        $result.Policy = $currentPolicy
        
        if ($currentPolicy -eq "Restricted") {
            Write-Host "  実行ポリシーをRemoteSignedに変更中..." -ForegroundColor Yellow
            try {
                Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
                $result.Policy = "RemoteSigned"
                Write-Host "    ✓ 実行ポリシーをRemoteSignedに変更しました" -ForegroundColor Green
            } catch {
                $result.Error = $_.Exception.Message
                $result.Success = $false
            }
        } else {
            Write-Host "    ✓ 実行ポリシーは適切に設定されています: $currentPolicy" -ForegroundColor Green
        }
        
        return $result
    }
    catch {
        $result.Error = $_.Exception.Message
        $result.Success = $false
        return $result
    }
}

# 認証設定確認
function Test-AuthenticationConfiguration {
    $result = @{
        IsValid = $true
        ValidServices = @()
        Issues = @()
    }
    
    try {
        $configPath = Join-Path $Script:ToolRoot "Config\appsettings.json"
        
        if (-not (Test-Path $configPath)) {
            $result.Issues += "設定ファイルが見つかりません: $configPath"
            $result.IsValid = $false
            return $result
        }
        
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        
        # Microsoft Graph設定確認
        if ($config.EntraID) {
            $graphConfig = $config.EntraID
            $hasValidAuth = $false
            
            # 証明書認証確認
            if ($graphConfig.CertificatePath -and (Test-Path (Join-Path $Script:ToolRoot $graphConfig.CertificatePath))) {
                $hasValidAuth = $true
                $result.ValidServices += "Microsoft Graph (証明書認証)"
            }
            elseif ($graphConfig.CertificateThumbprint -and $graphConfig.CertificateThumbprint -ne "YOUR-CERTIFICATE-THUMBPRINT-HERE") {
                $hasValidAuth = $true
                $result.ValidServices += "Microsoft Graph (Thumbprint認証)"
            }
            elseif ($graphConfig.ClientSecret -and $graphConfig.ClientSecret -ne "" -and $graphConfig.ClientSecret -ne "YOUR-CLIENT-SECRET-HERE") {
                $hasValidAuth = $true
                $result.ValidServices += "Microsoft Graph (クライアントシークレット)"
            }
            
            if (-not $hasValidAuth) {
                $result.Issues += "Microsoft Graph の認証設定が不完全です"
            }
            
            # 基本設定確認
            if (-not $graphConfig.TenantId -or $graphConfig.TenantId -eq "YOUR-TENANT-ID-HERE") {
                $result.Issues += "Microsoft Graph の TenantId が設定されていません"
            }
            if (-not $graphConfig.ClientId -or $graphConfig.ClientId -eq "YOUR-CLIENT-ID-HERE") {
                $result.Issues += "Microsoft Graph の ClientId が設定されていません"
            }
        } else {
            $result.Issues += "Microsoft Graph の設定が見つかりません"
        }
        
        # Exchange Online設定確認
        if ($config.ExchangeOnline) {
            $exoConfig = $config.ExchangeOnline
            $hasValidAuth = $false
            
            # 証明書認証確認
            if ($exoConfig.CertificatePath -and (Test-Path (Join-Path $Script:ToolRoot $exoConfig.CertificatePath))) {
                $hasValidAuth = $true
                $result.ValidServices += "Exchange Online (証明書認証)"
            }
            elseif ($exoConfig.CertificateThumbprint -and $exoConfig.CertificateThumbprint -ne "YOUR-EXO-CERTIFICATE-THUMBPRINT-HERE") {
                $hasValidAuth = $true
                $result.ValidServices += "Exchange Online (Thumbprint認証)"
            }
            
            if (-not $hasValidAuth) {
                $result.Issues += "Exchange Online の認証設定が不完全です"
            }
            
            # 基本設定確認
            if (-not $exoConfig.Organization -or $exoConfig.Organization -eq "your-tenant.onmicrosoft.com") {
                $result.Issues += "Exchange Online の Organization が設定されていません"
            }
            if (-not $exoConfig.AppId -or $exoConfig.AppId -eq "YOUR-EXO-APP-ID-HERE") {
                $result.Issues += "Exchange Online の AppId が設定されていません"
            }
        } else {
            $result.Issues += "Exchange Online の設定が見つかりません"
        }
        
        if ($result.Issues.Count -gt 0) {
            $result.IsValid = $false
        }
        
        return $result
    }
    catch {
        $result.Issues += "設定確認エラー: $($_.Exception.Message)"
        $result.IsValid = $false
        return $result
    }
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
        "pwsh.exe"
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
        Write-Host "3. 初期セットアップ（初回のみ）" -ForegroundColor Yellow
        Write-Host "4. 認証テスト" -ForegroundColor Magenta
        Write-Host "5. 終了" -ForegroundColor Red
        
        do {
            $choice = Read-Host "選択 (1-5)"
            switch ($choice) {
                "1" { return "gui" }
                "2" { return "cli" }
                "3" { return "setup" }
                "4" { return "authtest" }
                "5" { 
                    Write-LauncherLog "ランチャーを終了します" -Level Info
                    exit 0 
                }
                default { 
                    Write-Host "無効な選択です。1-5を入力してください。" -ForegroundColor Red 
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

# 初期セットアップ実行
function Start-InitialSetup {
    Write-LauncherLog "初期セットアップを開始します..." -Level Info
    
    # バナー表示
    Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                          初期セットアップ                                      ║
║                    Microsoft 365管理ツール                                  ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green
    
    Write-Host ""
    Write-Host "このセットアップでは以下の項目を確認・設定します:" -ForegroundColor Yellow
    Write-Host "1. システム要件の確認" -ForegroundColor Cyan
    Write-Host "2. 必要なPowerShellモジュールのインストール" -ForegroundColor Cyan
    Write-Host "3. 認証設定の確認" -ForegroundColor Cyan
    Write-Host "4. 実行ポリシーの設定" -ForegroundColor Cyan
    Write-Host ""
    
    $setupResult = @{
        SystemRequirements = $false
        ModuleInstallation = $false
        AuthenticationCheck = $false
        ExecutionPolicy = $false
        OverallSuccess = $false
    }
    
    try {
        # 1. システム要件確認
        Write-Host "=== 1. システム要件確認 ===" -ForegroundColor Yellow
        $systemCheckResult = Test-SystemRequirements
        $setupResult.SystemRequirements = $systemCheckResult.IsValid
        
        if (-not $systemCheckResult.IsValid) {
            Write-Host "システム要件を満たしていません。" -ForegroundColor Red
            foreach ($error in $systemCheckResult.Errors) {
                Write-Host "  ✗ $error" -ForegroundColor Red
            }
            Write-Host ""
            Write-Host "セットアップを中止します。要件を満たしてから再実行してください。" -ForegroundColor Red
            Read-Host "Enterキーを押して終了"
            return $false
        }
        
        foreach ($check in $systemCheckResult.Checks) {
            Write-Host "  ✓ $check" -ForegroundColor Green
        }
        Write-Host ""
        
        # 2. モジュールインストール
        Write-Host "=== 2. PowerShellモジュールインストール ===" -ForegroundColor Yellow
        
        # 管理者権限確認
        if (-not $Script:IsAdmin) {
            Write-Host "  ⚠ モジュールインストールには管理者権限が推奨されます" -ForegroundColor Yellow
            Write-Host "  現在のユーザースコープでインストールを試行します" -ForegroundColor Cyan
        }
        
        $moduleResult = Install-RequiredModules
        $setupResult.ModuleInstallation = $moduleResult.Success
        
        if (-not $moduleResult.Success) {
            Write-Host "必要なモジュールのインストールに失敗しました。" -ForegroundColor Red
            foreach ($error in $moduleResult.Errors) {
                Write-Host "  ✗ $error" -ForegroundColor Red
            }
            Write-Host ""
            Write-Host "手動でモジュールをインストールしてください:" -ForegroundColor Yellow
            Write-Host "  Install-Module Microsoft.Graph -Force -AllowClobber" -ForegroundColor White
            Write-Host "  Install-Module ExchangeOnlineManagement -Force -AllowClobber" -ForegroundColor White
            Write-Host ""
            
            $continueChoice = Read-Host "続行しますか？ (y/N)"
            if ($continueChoice -ne "y" -and $continueChoice -ne "Y") {
                Write-Host "セットアップを中止します。" -ForegroundColor Red
                Read-Host "Enterキーを押して終了"
                return $false
            }
        } else {
            foreach ($module in $moduleResult.InstalledModules) {
                Write-Host "  ✓ $module" -ForegroundColor Green
            }
        }
        Write-Host ""
        
        # 3. 実行ポリシー設定
        Write-Host "=== 3. 実行ポリシー設定 ===" -ForegroundColor Yellow
        $policyResult = Set-ExecutionPolicyIfNeeded
        $setupResult.ExecutionPolicy = $policyResult.Success
        
        if ($policyResult.Success) {
            Write-Host "  ✓ 実行ポリシー: $($policyResult.Policy)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ 実行ポリシーの設定に失敗: $($policyResult.Error)" -ForegroundColor Red
        }
        Write-Host ""
        
        # 4. 認証設定確認
        Write-Host "=== 4. 認証設定確認 ===" -ForegroundColor Yellow
        $authResult = Test-AuthenticationConfiguration
        $setupResult.AuthenticationCheck = $authResult.IsValid
        
        if ($authResult.IsValid) {
            Write-Host "  ✓ 認証設定が正常に構成されています" -ForegroundColor Green
            foreach ($service in $authResult.ValidServices) {
                Write-Host "    - $service" -ForegroundColor Cyan
            }
        } else {
            Write-Host "  ⚠ 認証設定に問題があります:" -ForegroundColor Yellow
            foreach ($issue in $authResult.Issues) {
                Write-Host "    - $issue" -ForegroundColor Yellow
            }
            Write-Host ""
            Write-Host "設定ファイルを確認してください: Config/appsettings.json" -ForegroundColor Cyan
        }
        Write-Host ""
        
        # 結果サマリー
        Write-Host "=== セットアップ完了 ===" -ForegroundColor Green
        $successCount = ($setupResult.Values | Where-Object { $_ -eq $true }).Count
        $totalCount = $setupResult.Count - 1  # OverallSuccessを除く
        
        Write-Host "完了項目: $successCount/$totalCount" -ForegroundColor Cyan
        
        if ($setupResult.SystemRequirements -and $setupResult.ModuleInstallation -and $setupResult.ExecutionPolicy) {
            $setupResult.OverallSuccess = $true
            Write-Host ""
            Write-Host "✅ 初期セットアップが正常に完了しました！" -ForegroundColor Green
            Write-Host ""
            Write-Host "次のステップ:" -ForegroundColor Yellow
            Write-Host "1. 認証設定を確認してください (Config/appsettings.json)" -ForegroundColor Cyan
            Write-Host "2. 認証テストを実行してください" -ForegroundColor Cyan
            Write-Host "3. 管理ツールを使用開始してください" -ForegroundColor Cyan
        } else {
            Write-Host ""
            Write-Host "⚠ セットアップが完全に完了していません" -ForegroundColor Yellow
            Write-Host "上記のエラーを修正してから再度実行してください。" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Read-Host "Enterキーを押してメインメニューに戻る"
        return $setupResult.OverallSuccess
    }
    catch {
        Write-LauncherLog "初期セットアップエラー: $($_.Exception.Message)" -Level Error
        Write-Host "初期セットアップ中にエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Enterキーを押してメインメニューに戻る"
        return $false
    }
}

# 認証テスト実行
function Start-AuthenticationTest {
    Write-LauncherLog "認証テストを開始します..." -Level Info
    
    # バナー表示
    Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                            認証テスト                                         ║
║                    Microsoft 365管理ツール                                  ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta
    
    Write-Host ""
    Write-Host "Microsoft 365サービスへの認証テストを実行します" -ForegroundColor Yellow
    Write-Host ""
    
    $testResult = @{
        ConfigurationCheck = $false
        ModuleCheck = $false
        MicrosoftGraphTest = $false
        ExchangeOnlineTest = $false
        OverallSuccess = $false
        Details = @()
    }
    
    try {
        # 1. 設定ファイル確認
        Write-Host "=== 1. 設定ファイル確認 ===" -ForegroundColor Yellow
        $configPath = Join-Path $Script:ToolRoot "Config\appsettings.json"
        
        if (-not (Test-Path $configPath)) {
            Write-Host "  ✗ 設定ファイルが見つかりません: $configPath" -ForegroundColor Red
            $testResult.Details += "設定ファイルが存在しません"
            Write-Host ""
            Read-Host "Enterキーを押してメインメニューに戻る"
            return $false
        }
        
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            Write-Host "  ✓ 設定ファイル読み込み成功" -ForegroundColor Green
            $testResult.ConfigurationCheck = $true
        }
        catch {
            Write-Host "  ✗ 設定ファイルの読み込みに失敗: $($_.Exception.Message)" -ForegroundColor Red
            $testResult.Details += "設定ファイル読み込みエラー"
            Write-Host ""
            Read-Host "Enterキーを押してメインメニューに戻る"
            return $false
        }
        Write-Host ""
        
        # 2. 必要モジュール確認
        Write-Host "=== 2. 必要モジュール確認 ===" -ForegroundColor Yellow
        $requiredModules = @("Microsoft.Graph", "ExchangeOnlineManagement")
        $missingModules = @()
        
        foreach ($module in $requiredModules) {
            $installedModule = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending | Select-Object -First 1
            if ($installedModule) {
                Write-Host "  ✓ $module v$($installedModule.Version)" -ForegroundColor Green
            } else {
                Write-Host "  ✗ $module が見つかりません" -ForegroundColor Red
                $missingModules += $module
            }
        }
        
        if ($missingModules.Count -gt 0) {
            Write-Host ""
            Write-Host "  不足しているモジュール: $($missingModules -join ', ')" -ForegroundColor Red
            Write-Host "  初期セットアップを実行してモジュールをインストールしてください" -ForegroundColor Yellow
            $testResult.Details += "必要モジュールが不足"
            Write-Host ""
            Read-Host "Enterキーを押してメインメニューに戻る"
            return $false
        }
        
        $testResult.ModuleCheck = $true
        Write-Host ""
        
        # 3. Microsoft Graph 認証テスト
        Write-Host "=== 3. Microsoft Graph 認証テスト ===" -ForegroundColor Yellow
        try {
            Import-Module Microsoft.Graph -Force -ErrorAction Stop
            
            # 既存接続の切断
            try {
                Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            } catch { }
            
            $graphConfig = $config.EntraID
            $connectionSuccessful = $false
            
            # 証明書認証テスト
            if ($graphConfig.CertificatePath -and (Test-Path (Join-Path $Script:ToolRoot $graphConfig.CertificatePath))) {
                Write-Host "  証明書認証でテスト中..." -ForegroundColor Cyan
                try {
                    $certPath = Join-Path $Script:ToolRoot $graphConfig.CertificatePath
                    
                    # パスワード候補で証明書読み込み
                    $cert = $null
                    $passwordCandidates = @($graphConfig.CertificatePassword, "", $null)
                    
                    foreach ($password in $passwordCandidates) {
                        try {
                            if ([string]::IsNullOrEmpty($password)) {
                                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)
                            } else {
                                $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
                                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $securePassword)
                            }
                            break
                        } catch { continue }
                    }
                    
                    if ($cert) {
                        Connect-MgGraph -TenantId $graphConfig.TenantId -ClientId $graphConfig.ClientId -Certificate $cert -NoWelcome
                        
                        # 接続テスト
                        $testUser = Get-MgUser -Top 1 -Property Id,DisplayName -ErrorAction Stop
                        Write-Host "  ✓ Microsoft Graph 証明書認証成功" -ForegroundColor Green
                        Write-Host "    テナント: $((Get-MgContext).TenantId)" -ForegroundColor Cyan
                        $connectionSuccessful = $true
                        $testResult.MicrosoftGraphTest = $true
                    }
                }
                catch {
                    Write-Host "  ✗ Microsoft Graph 証明書認証失敗: $($_.Exception.Message)" -ForegroundColor Red
                    $testResult.Details += "Microsoft Graph 証明書認証失敗"
                }
            }
            # クライアントシークレット認証テスト
            elseif ($graphConfig.ClientSecret -and $graphConfig.ClientSecret -ne "" -and $graphConfig.ClientSecret -ne "YOUR-CLIENT-SECRET-HERE") {
                Write-Host "  クライアントシークレット認証でテスト中..." -ForegroundColor Cyan
                try {
                    $secureSecret = ConvertTo-SecureString $graphConfig.ClientSecret -AsPlainText -Force
                    $credential = New-Object System.Management.Automation.PSCredential ($graphConfig.ClientId, $secureSecret)
                    
                    Connect-MgGraph -TenantId $graphConfig.TenantId -ClientSecretCredential $credential -NoWelcome
                    
                    # 接続テスト
                    $testUser = Get-MgUser -Top 1 -Property Id,DisplayName -ErrorAction Stop
                    Write-Host "  ✓ Microsoft Graph クライアントシークレット認証成功" -ForegroundColor Green
                    Write-Host "    テナント: $((Get-MgContext).TenantId)" -ForegroundColor Cyan
                    $connectionSuccessful = $true
                    $testResult.MicrosoftGraphTest = $true
                }
                catch {
                    Write-Host "  ✗ Microsoft Graph クライアントシークレット認証失敗: $($_.Exception.Message)" -ForegroundColor Red
                    $testResult.Details += "Microsoft Graph クライアントシークレット認証失敗"
                }
            }
            else {
                Write-Host "  ✗ Microsoft Graph の認証情報が設定されていません" -ForegroundColor Red
                $testResult.Details += "Microsoft Graph 認証情報未設定"
            }
            
            # 接続切断
            if ($connectionSuccessful) {
                try {
                    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
                } catch { }
            }
        }
        catch {
            Write-Host "  ✗ Microsoft Graph テストエラー: $($_.Exception.Message)" -ForegroundColor Red
            $testResult.Details += "Microsoft Graph テストエラー"
        }
        Write-Host ""
        
        # 4. Exchange Online 認証テスト
        Write-Host "=== 4. Exchange Online 認証テスト ===" -ForegroundColor Yellow
        try {
            Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop
            
            # 既存接続の切断
            try {
                Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            } catch { }
            
            $exoConfig = $config.ExchangeOnline
            $connectionSuccessful = $false
            
            # 証明書認証テスト
            if ($exoConfig.CertificatePath -and (Test-Path (Join-Path $Script:ToolRoot $exoConfig.CertificatePath))) {
                Write-Host "  証明書認証でテスト中..." -ForegroundColor Cyan
                try {
                    $certPath = Join-Path $Script:ToolRoot $exoConfig.CertificatePath
                    
                    # パスワード候補で証明書読み込み
                    $cert = $null
                    $passwordCandidates = @($exoConfig.CertificatePassword, "", $null)
                    
                    foreach ($password in $passwordCandidates) {
                        try {
                            if ([string]::IsNullOrEmpty($password)) {
                                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)
                            } else {
                                $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
                                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $securePassword)
                            }
                            break
                        } catch { continue }
                    }
                    
                    if ($cert) {
                        Connect-ExchangeOnline -Organization $exoConfig.Organization -AppId $exoConfig.AppId -Certificate $cert -ShowBanner:$false -ShowProgress:$false
                        
                        # 接続テスト
                        $testOrg = Get-OrganizationConfig -ErrorAction Stop | Select-Object -First 1
                        Write-Host "  ✓ Exchange Online 証明書認証成功" -ForegroundColor Green
                        Write-Host "    組織: $($testOrg.Name)" -ForegroundColor Cyan
                        $connectionSuccessful = $true
                        $testResult.ExchangeOnlineTest = $true
                    }
                }
                catch {
                    Write-Host "  ✗ Exchange Online 証明書認証失敗: $($_.Exception.Message)" -ForegroundColor Red
                    $testResult.Details += "Exchange Online 証明書認証失敗"
                }
            }
            else {
                Write-Host "  ✗ Exchange Online の認証情報が設定されていません" -ForegroundColor Red
                $testResult.Details += "Exchange Online 認証情報未設定"
            }
            
            # 接続切断
            if ($connectionSuccessful) {
                try {
                    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                } catch { }
            }
        }
        catch {
            Write-Host "  ✗ Exchange Online テストエラー: $($_.Exception.Message)" -ForegroundColor Red
            $testResult.Details += "Exchange Online テストエラー"
        }
        Write-Host ""
        
        # 結果サマリー
        Write-Host "=== 認証テスト完了 ===" -ForegroundColor Green
        $successCount = ($testResult.Values | Where-Object { $_ -eq $true -and $_ -is [bool] }).Count
        $totalTests = 4  # ConfigurationCheck, ModuleCheck, MicrosoftGraphTest, ExchangeOnlineTest
        
        Write-Host "成功テスト: $successCount/$totalTests" -ForegroundColor Cyan
        
        if ($testResult.ConfigurationCheck -and $testResult.ModuleCheck -and 
            ($testResult.MicrosoftGraphTest -or $testResult.ExchangeOnlineTest)) {
            $testResult.OverallSuccess = $true
            Write-Host ""
            Write-Host "✅ 認証テストが正常に完了しました！" -ForegroundColor Green
            Write-Host ""
            Write-Host "Microsoft 365管理ツールを使用開始できます" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "⚠ 認証テストが完全に成功していません" -ForegroundColor Yellow
            if ($testResult.Details.Count -gt 0) {
                Write-Host ""
                Write-Host "問題点:" -ForegroundColor Yellow
                foreach ($detail in $testResult.Details) {
                    Write-Host "  - $detail" -ForegroundColor Yellow
                }
            }
            Write-Host ""
            Write-Host "設定を確認してください: Config/appsettings.json" -ForegroundColor Cyan
        }
        
        Write-Host ""
        Read-Host "Enterキーを押してメインメニューに戻る"
        return $testResult.OverallSuccess
    }
    catch {
        Write-LauncherLog "認証テストエラー: $($_.Exception.Message)" -Level Error
        Write-Host "認証テスト中にエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Enterキーを押してメインメニューに戻る"
        return $false
    }
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
        "setup" { Start-InitialSetup }
        "authtest" { Start-AuthenticationTest }
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