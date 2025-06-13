# ================================================================================
# MenuEngine.psm1
# メニューエンジン基盤モジュール - PowerShellバージョン対応統合メニューシステム
# ================================================================================

# 必要モジュールのインポート
Import-Module "$PSScriptRoot\..\Common\VersionDetection.psm1" -Force
Import-Module "$PSScriptRoot\EncodingManager.psm1" -Force

# 条件付きモジュールインポート
$Script:CLIMenuModule = $null
$Script:ConsoleGUIMenuModule = $null

# メニューエンジン設定
class MenuEngineConfig {
    [string]$PreferredMenuType
    [bool]$AutoDetectBestUI
    [bool]$FallbackToCLI
    [hashtable]$GlobalSettings
    [string]$ConfigPath
    
    MenuEngineConfig() {
        $this.PreferredMenuType = "Auto"
        $this.AutoDetectBestUI = $true
        $this.FallbackToCLI = $true
        $this.GlobalSettings = @{}
        $this.ConfigPath = "Config\appsettings.json"
    }
}

# グローバル変数
$Script:MenuEngineConfig = [MenuEngineConfig]::new()
$Script:CurrentMenuType = $null
$Script:IsInitialized = $false

# メニューエンジン初期化関数
function Initialize-MenuEngine {
    <#
    .SYNOPSIS
    メニューエンジンを初期化

    .DESCRIPTION
    PowerShell環境を分析し、最適なメニューシステムを選択・初期化

    .PARAMETER PreferredMenuType
    優先するメニュータイプ（Auto, CLI, ConsoleGUI, WPF）

    .PARAMETER ConfigPath
    設定ファイルのパス

    .OUTPUTS
    PSCustomObject - 初期化結果

    .EXAMPLE
    Initialize-MenuEngine
    Initialize-MenuEngine -PreferredMenuType "ConsoleGUI"
    #>
    
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Auto", "CLI", "ConsoleGUI", "WPF")]
        [string]$PreferredMenuType = "Auto",
        
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = "Config\appsettings.json"
    )
    
    try {
        Write-Verbose "メニューエンジンを初期化中..."
        
        # エンコーディング初期化
        Initialize-EncodingSupport
        
        # PowerShell環境情報取得
        $versionInfo = Get-PowerShellVersionInfo
        Write-Verbose "PowerShell環境: $($versionInfo.Version) ($($versionInfo.Edition))"
        
        # 設定更新
        $Script:MenuEngineConfig.PreferredMenuType = $PreferredMenuType
        $Script:MenuEngineConfig.ConfigPath = $ConfigPath
        
        # 最適なメニュータイプを決定
        $Script:CurrentMenuType = Get-OptimalMenuType -PreferredType $PreferredMenuType -VersionInfo $versionInfo
        Write-Verbose "選択されたメニュータイプ: $Script:CurrentMenuType"
        
        # 選択されたメニューシステムのモジュールを読み込み
        $loadResult = Load-MenuModules -MenuType $Script:CurrentMenuType
        
        # 初期化結果
        $result = [PSCustomObject]@{
            Success = $loadResult.Success
            MenuType = $Script:CurrentMenuType
            PowerShellInfo = $versionInfo
            LoadedModules = $loadResult.LoadedModules
            Warnings = $loadResult.Warnings
            Recommendations = $loadResult.Recommendations
            InitializedAt = Get-Date
        }
        
        $Script:IsInitialized = $result.Success
        
        # 初期化状況を報告
        if ($result.Success) {
            Write-Host "✅ メニューエンジン初期化完了" -ForegroundColor Green
            Write-Host "   メニュータイプ: $($result.MenuType)" -ForegroundColor Cyan
            Write-Host "   PowerShell: $($versionInfo.Version) ($($versionInfo.Edition))" -ForegroundColor Cyan
        } else {
            Write-Warning "⚠️ メニューエンジンの初期化に問題があります"
        }
        
        # 推奨事項の表示
        foreach ($recommendation in $result.Recommendations) {
            Write-Host "💡 推奨: $recommendation" -ForegroundColor Yellow
        }
        
        return $result
        
    } catch {
        Write-Error "メニューエンジンの初期化に失敗しました: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success = $false
            MenuType = "CLI"
            Error = $_.Exception.Message
        }
    }
}

# 最適なメニュータイプを決定する関数
function Get-OptimalMenuType {
    param(
        [string]$PreferredType,
        [PSCustomObject]$VersionInfo
    )
    
    # 自動選択の場合
    if ($PreferredType -eq "Auto") {
        $recommendedType = Get-RecommendedMenuType
        Write-Verbose "推奨メニュータイプ: $recommendedType"
        
        # ConsoleGUI が推奨されている場合、利用可能性をチェック
        if ($recommendedType -eq "ConsoleGUI") {
            if (Test-FeatureSupport -FeatureName "ConsoleGUI") {
                return "ConsoleGUI"
            } else {
                Write-Verbose "ConsoleGUI推奨だが利用できないため、CLIに切り替え"
                return "CLI"
            }
        }
        
        return $recommendedType
    }
    
    # 明示的な選択の場合、利用可能性をチェック
    switch ($PreferredType) {
        "ConsoleGUI" {
            if (Test-FeatureSupport -FeatureName "ConsoleGUI") {
                return "ConsoleGUI"
            } else {
                Write-Warning "ConsoleGUIが利用できません。CLIに切り替えます。"
                return "CLI"
            }
        }
        "WPF" {
            if (Test-FeatureSupport -FeatureName "WPF") {
                return "WPF"
            } else {
                Write-Warning "WPFが利用できません。CLIに切り替えます。"
                return "CLI"
            }
        }
        default {
            return $PreferredType
        }
    }
}

# メニューモジュールを読み込む関数
function Load-MenuModules {
    param([string]$MenuType)
    
    $result = [PSCustomObject]@{
        Success = $false
        LoadedModules = @()
        Warnings = @()
        Recommendations = @()
    }
    
    try {
        switch ($MenuType) {
            "CLI" {
                Write-Verbose "CLIメニューモジュールを読み込み中..."
                Import-Module "$PSScriptRoot\CLIMenu.psm1" -Force -Global
                $Script:CLIMenuModule = Get-Module "CLIMenu"
                $result.LoadedModules += "CLIMenu"
                $result.Success = $true
            }
            
            "ConsoleGUI" {
                Write-Verbose "ConsoleGUIメニューモジュールを読み込み中..."
                
                # Microsoft.PowerShell.ConsoleGuiToolsの存在確認
                $consoleGuiModule = Get-Module -ListAvailable -Name "Microsoft.PowerShell.ConsoleGuiTools"
                if (-not $consoleGuiModule) {
                    $result.Warnings += "Microsoft.PowerShell.ConsoleGuiToolsモジュールが見つかりません"
                    $result.Recommendations += "Install-Module Microsoft.PowerShell.ConsoleGuiTools -Force を実行してください"
                    
                    # CLIにフォールバック
                    Write-Verbose "ConsoleGUIが利用できないため、CLIにフォールバック"
                    Import-Module "$PSScriptRoot\CLIMenu.psm1" -Force -Global
                    $Script:CLIMenuModule = Get-Module "CLIMenu"
                    $Script:CurrentMenuType = "CLI"
                    $result.LoadedModules += "CLIMenu (Fallback)"
                } else {
                    Import-Module "$PSScriptRoot\ConsoleGUIMenu.psm1" -Force -Global
                    $Script:ConsoleGUIMenuModule = Get-Module "ConsoleGUIMenu"
                    $result.LoadedModules += "ConsoleGUIMenu"
                }
                
                $result.Success = $true
            }
            
            "WPF" {
                Write-Verbose "WPFメニューモジュールを読み込み中..."
                $result.Warnings += "WPFメニューはまだ実装されていません"
                
                # CLIにフォールバック
                Import-Module "$PSScriptRoot\CLIMenu.psm1" -Force -Global
                $Script:CLIMenuModule = Get-Module "CLIMenu"
                $Script:CurrentMenuType = "CLI"
                $result.LoadedModules += "CLIMenu (WPF Fallback)"
                $result.Success = $true
            }
            
            default {
                throw "サポートされていないメニュータイプ: $MenuType"
            }
        }
        
    } catch {
        $result.Success = $false
        $result.Warnings += "モジュール読み込みエラー: $($_.Exception.Message)"
        
        # 最終フォールバック: CLI
        if ($MenuType -ne "CLI") {
            try {
                Import-Module "$PSScriptRoot\CLIMenu.psm1" -Force -Global
                $Script:CLIMenuModule = Get-Module "CLIMenu"
                $Script:CurrentMenuType = "CLI"
                $result.LoadedModules += "CLIMenu (Error Fallback)"
                $result.Success = $true
            } catch {
                $result.Warnings += "CLIメニューのフォールバックも失敗しました"
            }
        }
    }
    
    return $result
}

# メインメニューを起動する関数
function Start-MainMenu {
    <#
    .SYNOPSIS
    選択されたメニューシステムでメインメニューを起動

    .DESCRIPTION
    初期化されたメニューシステムに基づいてメインメニューを表示

    .EXAMPLE
    Start-MainMenu
    #>
    
    if (-not $Script:IsInitialized) {
        Write-Warning "メニューエンジンが初期化されていません。初期化を実行します..."
        $initResult = Initialize-MenuEngine
        if (-not $initResult.Success) {
            Write-Error "メニューエンジンの初期化に失敗しました"
            return
        }
    }
    
    try {
        Write-Verbose "メニューシステムを起動中: $Script:CurrentMenuType"
        
        # 起動前メッセージ
        Clear-Host
        Write-SafeBox -Title "Microsoft 365 統合管理システム" -Width 70 -Color Blue
        Write-Host ""
        Write-Host "システム起動中..." -ForegroundColor Cyan
        Write-Host "メニュータイプ: $Script:CurrentMenuType" -ForegroundColor Gray
        Start-Sleep -Seconds 1
        
        # 選択されたメニューシステムを起動
        switch ($Script:CurrentMenuType) {
            "CLI" {
                Show-CLIMainMenu
            }
            "ConsoleGUI" {
                $consoleGUIResult = Show-ConsoleGUIMainMenu
                
                # ConsoleGUIが失敗した場合はCLIにフォールバック
                if ($consoleGUIResult -eq $false) {
                    Write-Host "ConsoleGUIメニューが利用できません。CLIメニューに切り替えます..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                    
                    # CLIモジュールが読み込まれていない場合は読み込み
                    if (-not $Script:CLIMenuModule) {
                        Import-Module "$PSScriptRoot\CLIMenu.psm1" -Force -Global
                        $Script:CLIMenuModule = Get-Module "CLIMenu"
                    }
                    
                    Show-CLIMainMenu
                }
            }
            default {
                Write-Error "サポートされていないメニュータイプ: $Script:CurrentMenuType"
                return
            }
        }
        
    } catch {
        Write-Error "メニューシステムの起動中にエラーが発生しました: $($_.Exception.Message)"
        
        # 緊急時CLIフォールバック
        try {
            Write-Host "緊急フォールバック: CLIメニューに切り替えます..." -ForegroundColor Yellow
            Import-Module "$PSScriptRoot\CLIMenu.psm1" -Force -Global
            Show-CLIMainMenu
        } catch {
            Write-Error "緊急フォールバックも失敗しました: $($_.Exception.Message)"
        }
    }
}

# メニューエンジンの状態を取得する関数
function Get-MenuEngineStatus {
    <#
    .SYNOPSIS
    メニューエンジンの現在の状態を取得

    .DESCRIPTION
    メニューエンジンの初期化状況、選択されたメニュータイプ、利用可能な機能を報告

    .OUTPUTS
    PSCustomObject - メニューエンジン状態情報

    .EXAMPLE
    Get-MenuEngineStatus
    #>
    
    $versionInfo = Get-PowerShellVersionInfo
    $compatibilityReport = Get-EnvironmentCompatibilityReport
    
    $status = [PSCustomObject]@{
        IsInitialized = $Script:IsInitialized
        CurrentMenuType = $Script:CurrentMenuType
        PreferredMenuType = $Script:MenuEngineConfig.PreferredMenuType
        PowerShellInfo = $versionInfo
        LoadedModules = @{
            CLIMenu = $null -ne $Script:CLIMenuModule
            ConsoleGUIMenu = $null -ne $Script:ConsoleGUIMenuModule
        }
        FeatureSupport = @{
            CLI = $true
            ConsoleGUI = Test-FeatureSupport -FeatureName "ConsoleGUI"
            WPF = Test-FeatureSupport -FeatureName "WPF"
            OutGridView = Test-FeatureSupport -FeatureName "OutGridView"
        }
        EncodingInfo = Test-UnicodeSupport
        CompatibilityReport = $compatibilityReport
        StatusCheckedAt = Get-Date
    }
    
    return $status
}

# メニューエンジン設定を更新する関数
function Set-MenuEngineConfig {
    <#
    .SYNOPSIS
    メニューエンジンの設定を更新

    .PARAMETER PreferredMenuType
    優先するメニュータイプ

    .PARAMETER AutoDetectBestUI
    最適なUIの自動検出を有効にするか

    .PARAMETER FallbackToCLI
    問題発生時にCLIへフォールバックするか

    .EXAMPLE
    Set-MenuEngineConfig -PreferredMenuType "ConsoleGUI" -AutoDetectBestUI $true
    #>
    
    param(
        [ValidateSet("Auto", "CLI", "ConsoleGUI", "WPF")]
        [string]$PreferredMenuType,
        
        [bool]$AutoDetectBestUI,
        [bool]$FallbackToCLI
    )
    
    if ($PSBoundParameters.ContainsKey('PreferredMenuType')) {
        $Script:MenuEngineConfig.PreferredMenuType = $PreferredMenuType
    }
    
    if ($PSBoundParameters.ContainsKey('AutoDetectBestUI')) {
        $Script:MenuEngineConfig.AutoDetectBestUI = $AutoDetectBestUI
    }
    
    if ($PSBoundParameters.ContainsKey('FallbackToCLI')) {
        $Script:MenuEngineConfig.FallbackToCLI = $FallbackToCLI
    }
    
    Write-Host "メニューエンジン設定を更新しました" -ForegroundColor Green
}

# メニューエンジンの詳細情報を表示する関数
function Show-MenuEngineInfo {
    <#
    .SYNOPSIS
    メニューエンジンの詳細情報を表示

    .DESCRIPTION
    メニューエンジンの状態、機能サポート状況、推奨事項を詳細に表示

    .EXAMPLE
    Show-MenuEngineInfo
    #>
    
    $status = Get-MenuEngineStatus
    
    Clear-Host
    Write-SafeBox -Title "メニューエンジン情報" -Width 70 -Color Cyan
    
    Write-Host ""
    Write-Host "🔧 基本情報" -ForegroundColor Cyan
    Write-Host "  初期化状況: " -NoNewline
    Write-Host $(if($status.IsInitialized) {"✅ 初期化済み"} else {"❌ 未初期化"}) -ForegroundColor $(if($status.IsInitialized) {"Green"} else {"Red"})
    Write-Host "  現在のメニュータイプ: $($status.CurrentMenuType)" -ForegroundColor White
    Write-Host "  優先メニュータイプ: $($status.PreferredMenuType)" -ForegroundColor White
    
    Write-Host ""
    Write-Host "💻 PowerShell環境" -ForegroundColor Cyan
    Write-Host "  バージョン: $($status.PowerShellInfo.Version)" -ForegroundColor White
    Write-Host "  エディション: $($status.PowerShellInfo.Edition)" -ForegroundColor White
    Write-Host "  プラットフォーム: " -NoNewline
    if ($status.PowerShellInfo.IsWindows) { Write-Host "Windows" -ForegroundColor Green }
    elseif ($status.PowerShellInfo.IsLinux) { Write-Host "Linux" -ForegroundColor Yellow }
    else { Write-Host "その他" -ForegroundColor Gray }
    
    Write-Host ""
    Write-Host "📦 モジュール読み込み状況" -ForegroundColor Cyan
    Write-Host "  CLIMenu: " -NoNewline
    Write-Host $(if($status.LoadedModules.CLIMenu) {"✅ 読み込み済み"} else {"❌ 未読み込み"}) -ForegroundColor $(if($status.LoadedModules.CLIMenu) {"Green"} else {"Red"})
    Write-Host "  ConsoleGUIMenu: " -NoNewline  
    Write-Host $(if($status.LoadedModules.ConsoleGUIMenu) {"✅ 読み込み済み"} else {"❌ 未読み込み"}) -ForegroundColor $(if($status.LoadedModules.ConsoleGUIMenu) {"Green"} else {"Red"})
    
    Write-Host ""
    Write-Host "⚡ 機能サポート状況" -ForegroundColor Cyan
    Write-Host "  CLI: " -NoNewline
    Write-Host $(if($status.FeatureSupport.CLI) {"✅ サポート"} else {"❌ 非サポート"}) -ForegroundColor $(if($status.FeatureSupport.CLI) {"Green"} else {"Red"})
    Write-Host "  ConsoleGUI: " -NoNewline
    Write-Host $(if($status.FeatureSupport.ConsoleGUI) {"✅ サポート"} else {"❌ 非サポート"}) -ForegroundColor $(if($status.FeatureSupport.ConsoleGUI) {"Green"} else {"Red"})
    Write-Host "  WPF: " -NoNewline
    Write-Host $(if($status.FeatureSupport.WPF) {"✅ サポート"} else {"❌ 非サポート"}) -ForegroundColor $(if($status.FeatureSupport.WPF) {"Green"} else {"Red"})
    Write-Host "  Out-GridView: " -NoNewline
    Write-Host $(if($status.FeatureSupport.OutGridView) {"✅ サポート"} else {"❌ 非サポート"}) -ForegroundColor $(if($status.FeatureSupport.OutGridView) {"Green"} else {"Red"})
    
    Write-Host ""
    Write-Host "🔤 文字エンコーディング" -ForegroundColor Cyan
    Write-Host "  Unicode文字サポート: $($status.EncodingInfo.OverallSupport)" -ForegroundColor White
    Write-Host "  出力エンコーディング: $($status.EncodingInfo.Environment.OutputEncoding)" -ForegroundColor White
    
    # 推奨事項の表示
    if ($status.CompatibilityReport.Recommendations.Count -gt 0) {
        Write-Host ""
        Write-Host "💡 推奨事項" -ForegroundColor Yellow
        foreach ($rec in $status.CompatibilityReport.Recommendations) {
            Write-Host "  • $rec" -ForegroundColor Yellow
        }
    }
    
    # 警告の表示
    if ($status.CompatibilityReport.Warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "⚠️ 警告" -ForegroundColor Red
        foreach ($warn in $status.CompatibilityReport.Warnings) {
            Write-Host "  • $warn" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "📊 状態確認日時: $($status.StatusCheckedAt)" -ForegroundColor Gray
    Write-Host ""
}

# エクスポートする関数
Export-ModuleMember -Function @(
    'Initialize-MenuEngine',
    'Start-MainMenu',
    'Get-MenuEngineStatus',
    'Set-MenuEngineConfig',
    'Show-MenuEngineInfo'
)