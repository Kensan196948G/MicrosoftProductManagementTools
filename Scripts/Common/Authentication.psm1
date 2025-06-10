# ================================================================================
# Authentication.psm1
# Microsoft製品運用管理ツール - 認証共通モジュール
# ITSM/ISO27001/27002準拠
# ================================================================================

function Connect-EntraID {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        
        [Parameter(Mandatory = $false)]
        [string]$CertificateThumbprint,
        
        [Parameter(Mandatory = $false)]
        [string]$ClientSecret
    )
    
    try {
        Write-Log "Entra ID接続を開始します" -Level "Info"
        
        if ($CertificateThumbprint) {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint
            Write-Log "Entra ID接続成功（証明書認証）" -Level "Info"
        }
        elseif ($ClientSecret) {
            $SecureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential($ClientId, $SecureSecret)
            Connect-MgGraph -TenantId $TenantId -ClientCredential $Credential
            Write-Log "Entra ID接続成功（クライアントシークレット認証）" -Level "Info"
        }
        else {
            throw "認証方法が指定されていません（証明書またはクライアントシークレットが必要）"
        }
        
        return $true
    }
    catch {
        Write-Log "Entra ID接続エラー: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Connect-ExchangeOnlineService {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Organization,
        
        [Parameter(Mandatory = $true)]
        [string]$AppId,
        
        [Parameter(Mandatory = $true)]
        [string]$CertificateThumbprint
    )
    
    try {
        Write-Log "Exchange Online接続を開始します" -Level "Info"
        
        Connect-ExchangeOnline -AppId $AppId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowProgress $false
        
        Write-Log "Exchange Online接続成功" -Level "Info"
        return $true
    }
    catch {
        Write-Log "Exchange Online接続エラー: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Connect-ActiveDirectory {
    try {
        Write-Log "Active Directory接続を開始します" -Level "Info"
        
        Import-Module ActiveDirectory -ErrorAction Stop
        
        Write-Log "Active Directory接続成功" -Level "Info"
        return $true
    }
    catch {
        Write-Log "Active Directory接続エラー: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Disconnect-AllServices {
    try {
        Write-Log "全サービスからの切断を開始します" -Level "Info"
        
        try { Disconnect-MgGraph -ErrorAction SilentlyContinue } catch { }
        try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue } catch { }
        
        Write-Log "全サービスからの切断完了" -Level "Info"
        return $true
    }
    catch {
        Write-Log "切断エラー: $($_.Exception.Message)" -Level "Warning"
        return $false
    }
}

Export-ModuleMember -Function Connect-EntraID, Connect-ExchangeOnlineService, Connect-ActiveDirectory, Disconnect-AllServices