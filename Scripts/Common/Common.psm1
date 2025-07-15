# ================================================================================
# Common.psm1
# Microsoft製品運用管理ツール - 共通機能統合モジュール
# ITSM/ISO27001/27002準拠
# PowerShell 7 シリーズ推奨
# ================================================================================

# PowerShell 7 環境チェック
Import-Module "$PSScriptRoot\PowerShellVersionManager.psm1" -Force

# PowerShell 7 環境確認（自動）
$ps7Check = Confirm-PowerShell7Environment -ScriptPath $MyInvocation.MyCommand.Path
if (-not $ps7Check) {
    Write-Warning "PowerShell 7 での実行が推奨されます。一部機能が制限される場合があります。"
}

Import-Module "$PSScriptRoot\Authentication.psm1" -Force
Import-Module "$PSScriptRoot\Logging.psm1" -Force
Import-Module "$PSScriptRoot\ErrorHandling.psm1" -Force
Import-Module "$PSScriptRoot\ReportGenerator.psm1" -Force

# 設定ファイルマージ機能
function Merge-Configuration {
    param(
        [PSCustomObject]$BaseConfig,
        [PSCustomObject]$LocalConfig
    )
    
    try {
        # PowerShell オブジェクトのディープマージ
        $mergedConfig = $BaseConfig.PSObject.Copy()
        
        # ローカル設定の各プロパティをマージ
        foreach ($property in $LocalConfig.PSObject.Properties) {
            $propertyName = $property.Name
            $localValue = $property.Value
            
            if ($mergedConfig.PSObject.Properties[$propertyName]) {
                # プロパティが存在する場合、オブジェクトなら再帰的にマージ、値なら上書き
                if ($localValue -is [PSCustomObject] -and $mergedConfig.$propertyName -is [PSCustomObject]) {
                    $mergedConfig.$propertyName = Merge-Configuration -BaseConfig $mergedConfig.$propertyName -LocalConfig $localValue
                }
                else {
                    $mergedConfig.$propertyName = $localValue
                }
            }
            else {
                # プロパティが存在しない場合、追加
                $mergedConfig | Add-Member -MemberType NoteProperty -Name $propertyName -Value $localValue -Force
            }
        }
        
        return $mergedConfig
    }
    catch {
        Write-Log "設定ファイルのマージに失敗しました: $($_.Exception.Message)" -Level "Warning"
        return $LocalConfig
    }
}

function Initialize-ManagementTools {
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = "Config\appsettings.json",
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipAuthentication
    )
    
    try {
        Write-Log "Microsoft製品運用管理ツールを初期化しています" -Level "Info"
        
        # 設定ファイルの読み込み（優先順位: local.json > appsettings.json）
        $localConfigPath = $ConfigPath -replace "appsettings\.json", "appsettings.local.json"
        $actualConfigPath = $ConfigPath
        
        if (Test-Path $localConfigPath) {
            # ローカル設定ファイルが存在する場合、ベース設定とマージ
            Write-Log "ローカル設定ファイルを検出しました: $localConfigPath" -Level "Info"
            
            if (Test-Path $ConfigPath) {
                $baseConfig = Get-Content $ConfigPath | ConvertFrom-Json
                $localConfig = Get-Content $localConfigPath | ConvertFrom-Json
                
                # ローカル設定でベース設定を上書き
                $config = Merge-Configuration -BaseConfig $baseConfig -LocalConfig $localConfig
                Write-Log "設定ファイルをマージしました: $ConfigPath + $localConfigPath" -Level "Info"
            }
            else {
                $config = Get-Content $localConfigPath | ConvertFrom-Json
                Write-Log "ローカル設定ファイルのみを読み込みました: $localConfigPath" -Level "Info"
            }
            $actualConfigPath = $localConfigPath
        }
        elseif (Test-Path $ConfigPath) {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            Write-Log "設定ファイルを読み込みました: $ConfigPath" -Level "Info"
        }
        else {
            throw "設定ファイルが見つかりません: $ConfigPath"
        }
        
        # 自動認証の実行（スキップしない場合）
        if (-not $SkipAuthentication) {
            try {
                Write-Log "Microsoft 365サービスへの自動認証を開始します" -Level "Info"
                $authResult = Connect-ToMicrosoft365 -Config $config -Services @("MicrosoftGraph", "ExchangeOnline")
                
                if ($authResult.Success) {
                    Write-Log "認証成功: 接続済みサービス - $($authResult.ConnectedServices -join ', ')" -Level "Info"
                    if ($authResult.FailedServices.Count -gt 0) {
                        Write-Log "認証失敗サービス: $($authResult.FailedServices -join ', ')" -Level "Warning"
                    }
                }
                else {
                    Write-Log "認証が部分的に失敗しました。一部機能が制限される可能性があります" -Level "Warning"
                }
            }
            catch {
                Write-Log "自動認証エラー: $($_.Exception.Message)" -Level "Warning"
                Write-Log "一部機能は手動認証が必要になる場合があります" -Level "Info"
            }
        }
        
        return $config
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
        if ($Encoding -eq "UTF8" -and ($IsWindows -or $env:OS -eq "Windows_NT")) {
            # Windows環境でのCSV文字化け対策：BOM付きUTF-8で出力
            $csvContent = $Data | ConvertTo-Csv -NoTypeInformation
            $utf8WithBom = New-Object System.Text.UTF8Encoding $true
            [System.IO.File]::WriteAllLines($FilePath, $csvContent, $utf8WithBom)
            Write-Log "CSVエクスポート完了 (BOM付きUTF-8): $FilePath" -Level "Info"
        }
        else {
            # Linux環境または他のエンコーディング
            $Data | Export-Csv -Path $FilePath -NoTypeInformation -Encoding $Encoding
            Write-Log "CSVエクスポート完了: $FilePath" -Level "Info"
        }
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