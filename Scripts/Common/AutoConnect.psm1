# ================================================================================
# AutoConnect.psm1
# Microsoft 365 自動接続モジュール
# GUI環境での自動認証機能
# ================================================================================

Import-Module "$PSScriptRoot\Logging.psm1" -Force -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\Authentication.psm1" -Force -ErrorAction SilentlyContinue

function Connect-Microsoft365Auto {
    <#
    .SYNOPSIS
    Microsoft 365に自動接続を試行
    
    .DESCRIPTION
    設定ファイルを読み込んで、Microsoft GraphとExchange Onlineに自動接続を試行します
    #>
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force = $false,
        
        [Parameter(Mandatory = $false)]
        [string[]]$Services = @("MicrosoftGraph", "ExchangeOnline")
    )
    
    try {
        Write-Log "Microsoft 365自動接続を開始します" -Level "Info"
        
        # 設定ファイル読み込み
        $toolRoot = if ($Script:ToolRoot) { $Script:ToolRoot } else { Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent }
        $configPath = Join-Path -Path $toolRoot -ChildPath "Config\appsettings.json"
        
        if (-not (Test-Path $configPath)) {
            throw "設定ファイルが見つかりません: $configPath"
        }
        
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        
        # 既存接続確認
        if (-not $Force) {
            $graphConnected = $false
            $exoConnected = $false
            
            try {
                $context = Get-MgContext -ErrorAction SilentlyContinue
                if ($context) {
                    # 簡単な接続テスト
                    Get-MgUser -Top 1 -Property Id -ErrorAction Stop | Out-Null
                    $graphConnected = $true
                    Write-Log "Microsoft Graph既存接続確認済み" -Level "Info"
                }
            }
            catch {
                Write-Log "Microsoft Graph接続なし" -Level "Info"
            }
            
            try {
                Get-OrganizationConfig -ErrorAction Stop | Out-Null
                $exoConnected = $true
                Write-Log "Exchange Online既存接続確認済み" -Level "Info"
            }
            catch {
                Write-Log "Exchange Online接続なし" -Level "Info"
            }
            
            # 必要なサービスが接続済みかチェック
            $needConnection = $false
            if ($Services -contains "MicrosoftGraph" -and -not $graphConnected) {
                $needConnection = $true
            }
            if ($Services -contains "ExchangeOnline" -and -not $exoConnected) {
                $needConnection = $true
            }
            
            if (-not $needConnection) {
                Write-Log "必要なサービスは既に接続済みです" -Level "Info"
                return @{
                    Success = $true
                    ConnectedServices = $Services
                    Message = "既存接続を利用"
                }
            }
        }
        
        # 新規接続実行
        Write-Log "Microsoft 365に新規接続を実行します" -Level "Info"
        $connectResult = Connect-ToMicrosoft365 -Config $config -Services $Services
        
        if ($connectResult.Success) {
            Write-Log "Microsoft 365自動接続が成功しました: $($connectResult.ConnectedServices -join ', ')" -Level "Info"
            return @{
                Success = $true
                ConnectedServices = $connectResult.ConnectedServices
                Message = "自動接続成功"
            }
        }
        else {
            Write-Log "Microsoft 365自動接続が失敗しました: $($connectResult.Errors -join ', ')" -Level "Warning"
            return @{
                Success = $false
                ConnectedServices = @()
                Message = "自動接続失敗: $($connectResult.Errors -join ', ')"
            }
        }
    }
    catch {
        Write-Log "Microsoft 365自動接続エラー: $($_.Exception.Message)" -Level "Error"
        return @{
            Success = $false
            ConnectedServices = @()
            Message = "自動接続エラー: $($_.Exception.Message)"
        }
    }
}

function Test-Microsoft365Connection {
    <#
    .SYNOPSIS
    Microsoft 365の接続状態をテスト
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$Services = @("MicrosoftGraph", "ExchangeOnline")
    )
    
    $connectionStatus = @{
        MicrosoftGraph = $false
        ExchangeOnline = $false
        Details = @{}
    }
    
    # Microsoft Graph接続テスト
    if ($Services -contains "MicrosoftGraph") {
        try {
            $context = Get-MgContext -ErrorAction SilentlyContinue
            if ($context) {
                Get-MgUser -Top 1 -Property Id -ErrorAction Stop | Out-Null
                $connectionStatus.MicrosoftGraph = $true
                $connectionStatus.Details.MicrosoftGraph = "接続済み (テナント: $($context.TenantId))"
            }
            else {
                $connectionStatus.Details.MicrosoftGraph = "未接続"
            }
        }
        catch {
            $connectionStatus.Details.MicrosoftGraph = "接続エラー: $($_.Exception.Message)"
        }
    }
    
    # Exchange Online接続テスト
    if ($Services -contains "ExchangeOnline") {
        try {
            $orgConfig = Get-OrganizationConfig -ErrorAction Stop | Select-Object -First 1
            if ($orgConfig) {
                $connectionStatus.ExchangeOnline = $true
                $connectionStatus.Details.ExchangeOnline = "接続済み (組織: $($orgConfig.Name))"
            }
            else {
                $connectionStatus.Details.ExchangeOnline = "未接続"
            }
        }
        catch {
            $connectionStatus.Details.ExchangeOnline = "接続エラー: $($_.Exception.Message)"
        }
    }
    
    return $connectionStatus
}

function Invoke-AutoConnectIfNeeded {
    <#
    .SYNOPSIS
    必要に応じて自動接続を実行
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$RequiredServices = @("MicrosoftGraph")
    )
    
    try {
        $connectionStatus = Test-Microsoft365Connection -Services $RequiredServices
        $needConnection = $false
        
        foreach ($service in $RequiredServices) {
            if (-not $connectionStatus.$service) {
                $needConnection = $true
                Write-Log "$service への接続が必要です" -Level "Info"
                break
            }
        }
        
        if ($needConnection) {
            Write-Log "自動接続を実行します..." -Level "Info"
            $connectResult = Connect-Microsoft365Auto -Services $RequiredServices
            return $connectResult
        }
        else {
            Write-Log "必要なサービスは既に接続済みです" -Level "Info"
            return @{
                Success = $true
                ConnectedServices = $RequiredServices
                Message = "既存接続を利用"
            }
        }
    }
    catch {
        Write-Log "自動接続チェックエラー: $($_.Exception.Message)" -Level "Error"
        return @{
            Success = $false
            ConnectedServices = @()
            Message = "自動接続チェックエラー"
        }
    }
}

# エクスポート関数
Export-ModuleMember -Function Connect-Microsoft365Auto, Test-Microsoft365Connection, Invoke-AutoConnectIfNeeded