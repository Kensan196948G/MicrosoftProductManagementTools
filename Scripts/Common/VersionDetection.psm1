# ================================================================================
# VersionDetection.psm1
# PowerShellバージョン検出と互換性管理モジュール
# ================================================================================

# PowerShellバージョン情報を取得する関数
function Get-PowerShellVersionInfo {
    <#
    .SYNOPSIS
    PowerShellのバージョン情報と互換性情報を取得

    .DESCRIPTION
    実行中のPowerShellバージョンを詳細に分析し、利用可能な機能を判定

    .OUTPUTS
    PSCustomObject - PowerShellバージョン詳細情報

    .EXAMPLE
    Get-PowerShellVersionInfo
    #>
    
    $versionInfo = [PSCustomObject]@{
        Version = $PSVersionTable.PSVersion
        MajorVersion = $PSVersionTable.PSVersion.Major
        MinorVersion = $PSVersionTable.PSVersion.Minor
        Edition = $PSVersionTable.PSEdition
        IsCore = $PSVersionTable.PSEdition -eq "Core"
        IsWindows = $PSVersionTable.Platform -eq "Win32NT" -or [System.Environment]::OSVersion.Platform -eq "Win32NT"
        IsLinux = $PSVersionTable.Platform -eq "Unix" -and [System.Environment]::OSVersion.Platform -eq "Unix"
        IsMacOS = $PSVersionTable.Platform -eq "Unix" -and [System.Environment]::OSVersion.Platform -eq "Unix"
        SupportsGUI = $false
        SupportsConsoleGUI = $false
        SupportsWPF = $false
        SupportedMenuType = "CLI"
        EngineVersion = $PSVersionTable.CLRVersion
        BuildVersion = $PSVersionTable.BuildVersion
        CompatibilityLevel = "Unknown"
    }
    
    # プラットフォーム固有の判定
    if ($versionInfo.IsCore) {
        # PowerShell 7系の判定
        if ($versionInfo.MajorVersion -ge 7) {
            $versionInfo.CompatibilityLevel = "Modern"
            $versionInfo.SupportsConsoleGUI = $true
            
            # Windows環境での追加機能
            if ($versionInfo.IsWindows) {
                $versionInfo.SupportsWPF = $true
                $versionInfo.SupportsGUI = $true
                $versionInfo.SupportedMenuType = "ConsoleGUI"
            } else {
                $versionInfo.SupportedMenuType = "ConsoleGUI"
            }
        } else {
            # PowerShell 6系
            $versionInfo.CompatibilityLevel = "Transitional"
            $versionInfo.SupportedMenuType = "CLI"
        }
    } else {
        # PowerShell 5.1系（Windows PowerShell）
        if ($versionInfo.MajorVersion -eq 5 -and $versionInfo.MinorVersion -ge 1) {
            $versionInfo.CompatibilityLevel = "Legacy"
            $versionInfo.SupportsWPF = $true
            $versionInfo.SupportsGUI = $true
            $versionInfo.SupportedMenuType = "CLI"
            $versionInfo.IsWindows = $true
        } else {
            $versionInfo.CompatibilityLevel = "Unsupported"
            $versionInfo.SupportedMenuType = "CLI"
        }
    }
    
    return $versionInfo
}

# 推奨メニュータイプを決定する関数
function Get-RecommendedMenuType {
    <#
    .SYNOPSIS
    PowerShell環境に基づいて推奨メニュータイプを決定

    .DESCRIPTION
    PowerShellバージョンとプラットフォームに基づいて最適なメニューインターフェースを推奨

    .OUTPUTS
    String - 推奨メニュータイプ（CLI, ConsoleGUI, WPF）

    .EXAMPLE
    Get-RecommendedMenuType
    #>
    
    $versionInfo = Get-PowerShellVersionInfo
    
    # PowerShell 7系の場合
    if ($versionInfo.IsCore -and $versionInfo.MajorVersion -ge 7) {
        if ($versionInfo.IsWindows) {
            # Windows環境 - ConsoleGUIを優先
            try {
                # Microsoft.PowerShell.ConsoleGuiToolsが利用可能かチェック
                $module = Get-Module -ListAvailable -Name "Microsoft.PowerShell.ConsoleGuiTools"
                if ($module) {
                    return "ConsoleGUI"
                } else {
                    Write-Verbose "ConsoleGuiToolsモジュールが見つかりません。CLIモードを使用します。"
                    return "CLI"
                }
            } catch {
                return "CLI"
            }
        } else {
            # Linux/macOS環境 - CLIのみ
            return "CLI"
        }
    }
    # PowerShell 5.1系の場合
    elseif ($versionInfo.Edition -eq "Desktop" -and $versionInfo.MajorVersion -eq 5) {
        return "CLI"
    }
    # その他の場合
    else {
        return "CLI"
    }
}

# 機能サポート状況をチェックする関数
function Test-FeatureSupport {
    <#
    .SYNOPSIS
    特定の機能がサポートされているかチェック

    .PARAMETER FeatureName
    チェック対象の機能名

    .OUTPUTS
    Boolean - サポート状況

    .EXAMPLE
    Test-FeatureSupport -FeatureName "WPF"
    Test-FeatureSupport -FeatureName "ConsoleGUI"
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("WPF", "ConsoleGUI", "OutGridView", "WindowsForms", "Threading")]
        [string]$FeatureName
    )
    
    $versionInfo = Get-PowerShellVersionInfo
    
    switch ($FeatureName) {
        "WPF" {
            return $versionInfo.SupportsWPF
        }
        "ConsoleGUI" {
            if ($versionInfo.SupportsConsoleGUI) {
                try {
                    $module = Get-Module -ListAvailable -Name "Microsoft.PowerShell.ConsoleGuiTools"
                    return $module -ne $null
                } catch {
                    return $false
                }
            }
            return $false
        }
        "OutGridView" {
            try {
                $command = Get-Command "Out-GridView" -ErrorAction SilentlyContinue
                return $command -ne $null
            } catch {
                return $false
            }
        }
        "WindowsForms" {
            return $versionInfo.IsWindows -and ($versionInfo.SupportsGUI -or $versionInfo.SupportsWPF)
        }
        "Threading" {
            return $versionInfo.MajorVersion -ge 5
        }
        default {
            return $false
        }
    }
}

# 環境互換性レポートを生成する関数
function Get-EnvironmentCompatibilityReport {
    <#
    .SYNOPSIS
    現在の環境の互換性レポートを生成

    .DESCRIPTION
    PowerShell環境の詳細情報と利用可能な機能の一覧を生成

    .OUTPUTS
    PSCustomObject - 環境互換性レポート

    .EXAMPLE
    Get-EnvironmentCompatibilityReport
    #>
    
    $versionInfo = Get-PowerShellVersionInfo
    $recommendedMenu = Get-RecommendedMenuType
    
    $featureSupport = [PSCustomObject]@{
        WPF = Test-FeatureSupport -FeatureName "WPF"
        ConsoleGUI = Test-FeatureSupport -FeatureName "ConsoleGUI"
        OutGridView = Test-FeatureSupport -FeatureName "OutGridView"
        WindowsForms = Test-FeatureSupport -FeatureName "WindowsForms"
        Threading = Test-FeatureSupport -FeatureName "Threading"
    }
    
    $report = [PSCustomObject]@{
        PowerShellVersion = $versionInfo
        RecommendedMenuType = $recommendedMenu
        FeatureSupport = $featureSupport
        Recommendations = @()
        Warnings = @()
        GeneratedAt = Get-Date
    }
    
    # 推奨事項とワーニングの生成
    if ($versionInfo.CompatibilityLevel -eq "Unsupported") {
        $report.Warnings += "PowerShell バージョンが古すぎます。PowerShell 5.1以上にアップグレードしてください。"
    }
    
    if ($versionInfo.IsCore -and $versionInfo.MajorVersion -ge 7 -and -not $featureSupport.ConsoleGUI) {
        $report.Recommendations += "PowerShell 7系でのGUI機能を有効にするため、'Install-Module Microsoft.PowerShell.ConsoleGuiTools' を実行してください。"
    }
    
    if ($versionInfo.IsWindows -and $versionInfo.SupportsWPF) {
        $report.Recommendations += "Windows環境では高機能なWPF GUIメニューが利用可能です。"
    }
    
    return $report
}

# エクスポートする関数
Export-ModuleMember -Function @(
    'Get-PowerShellVersionInfo',
    'Get-RecommendedMenuType', 
    'Test-FeatureSupport',
    'Get-EnvironmentCompatibilityReport'
)