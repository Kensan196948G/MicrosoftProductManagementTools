# ================================================================================
# Common.psm1
# Microsoft製品運用管理ツール - 共通機能統合モジュール
# ITSM/ISO27001/27002準拠
# ================================================================================

. $PSScriptRoot\Authentication.psm1
. $PSScriptRoot\Logging.psm1
. $PSScriptRoot\ErrorHandling.psm1

function Initialize-ManagementTools {
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = "Config\appsettings.json"
    )
    
    try {
        Initialize-Logging
        Write-Log "Microsoft製品運用管理ツールを初期化しています" -Level "Info"
        
        if (Test-Path $ConfigPath) {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            Write-Log "設定ファイルを読み込みました: $ConfigPath" -Level "Info"
            return $config
        }
        else {
            Write-Log "設定ファイルが見つかりません: $ConfigPath" -Level "Warning"
            return $null
        }
    }
    catch {
        Write-Log "初期化エラー: $($_.Exception.Message)" -Level "Error"
        throw $_
    }
}

function Get-SystemInfo {
    $info = @{
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        OSVersion = [System.Environment]::OSVersion.ToString()
        MachineName = [System.Environment]::MachineName
        UserName = [System.Environment]::UserName
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        TimeZone = (Get-TimeZone).Id
    }
    
    return $info
}

function Test-SystemRequirements {
    $requirements = @{
        PowerShellVersion = "5.1"
        RequiredModules = @("ActiveDirectory", "ExchangeOnlineManagement", "Microsoft.Graph")
        OSMinVersion = "10.0"
    }
    
    $results = @{
        PowerShellOK = $false
        ModulesOK = $false
        OSOK = $false
        Overall = $false
    }
    
    if ($PSVersionTable.PSVersion -ge [Version]$requirements.PowerShellVersion) {
        $results.PowerShellOK = $true
        Write-Log "PowerShellバージョン確認OK" -Level "Info"
    }
    else {
        Write-Log "PowerShellバージョンが要件を満たしていません" -Level "Error"
    }
    
    $moduleStatus = $true
    foreach ($module in $requirements.RequiredModules) {
        if (Get-Module -ListAvailable -Name $module) {
            Write-Log "モジュール確認OK: $module" -Level "Debug"
        }
        else {
            Write-Log "必要なモジュールが見つかりません: $module" -Level "Warning"
            $moduleStatus = $false
        }
    }
    $results.ModulesOK = $moduleStatus
    
    if ([System.Environment]::OSVersion.Version -ge [Version]$requirements.OSMinVersion) {
        $results.OSOK = $true
        Write-Log "OS要件確認OK" -Level "Info"
    }
    else {
        Write-Log "OSが要件を満たしていません" -Level "Error"
    }
    
    $results.Overall = $results.PowerShellOK -and $results.ModulesOK -and $results.OSOK
    
    return $results
}

function Export-DataToCSV {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Data,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$Encoding = "UTF8"
    )
    
    try {
        $Data | Export-Csv -Path $FilePath -NoTypeInformation -Encoding $Encoding
        Write-Log "CSVエクスポート完了: $FilePath" -Level "Info"
        return $true
    }
    catch {
        Write-Log "CSVエクスポートエラー: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function New-ReportDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportType,
        
        [Parameter(Mandatory = $false)]
        [string]$BaseDirectory = "Reports"
    )
    
    $dateString = Get-Date -Format "yyyyMMdd"
    $reportDir = Join-Path $BaseDirectory $ReportType
    
    if (-not (Test-Path $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
    }
    
    return $reportDir
}

Export-ModuleMember -Function Initialize-ManagementTools, Get-SystemInfo, Test-SystemRequirements, Export-DataToCSV, New-ReportDirectory