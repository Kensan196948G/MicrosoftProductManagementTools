# ================================================================================
# Microsoft 365統合管理ツール - 環境変数設定スクリプト
# set-environment.ps1
# セキュアな認証情報管理
# ================================================================================

param(
    [Parameter(Mandatory = $false)]
    [switch]$Persistent = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$ShowCurrent = $false
)

function Set-SecureEnvironmentVariables {
    param(
        [bool]$MakePersistent = $false
    )
    
    Write-Host "🔐 Microsoft 365統合管理ツール - 環境変数設定" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Gray
    
    # 証明書パスワード設定
    if (-not $env:CERT_PASSWORD) {
        Write-Host "📋 証明書パスワードを設定します..." -ForegroundColor Yellow
        $certPassword = Read-Host "証明書パスワードを入力してください" -AsSecureString
        $env:CERT_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($certPassword))
        
        if ($MakePersistent) {
            [Environment]::SetEnvironmentVariable("CERT_PASSWORD", $env:CERT_PASSWORD, "User")
            Write-Host "✅ 証明書パスワードを永続的に設定しました" -ForegroundColor Green
        } else {
            Write-Host "✅ 証明書パスワードを現在のセッションに設定しました" -ForegroundColor Green
        }
    } else {
        Write-Host "✅ 証明書パスワードは既に設定されています" -ForegroundColor Green
    }
    
    # その他の環境変数
    $envVars = @{
        "M365_TENANT_ID" = "a7232f7a-a9e5-4f71-9372-dc8b1c6645ea"
        "M365_CLIENT_ID" = "22e5d6e4-805f-4516-af09-ff09c7c224c4"
        "M365_ORGANIZATION" = "miraiconst.onmicrosoft.com"
    }
    
    foreach ($var in $envVars.GetEnumerator()) {
        $env:($var.Name) = $var.Value
        if ($MakePersistent) {
            [Environment]::SetEnvironmentVariable($var.Name, $var.Value, "User")
        }
        Write-Host "✅ $($var.Name) = $($var.Value)" -ForegroundColor Green
    }
    
    Write-Host "`n🎯 環境変数設定完了!" -ForegroundColor Cyan
    
    if (-not $MakePersistent) {
        Write-Host "⚠️  現在のセッションのみ有効です。永続化する場合は -Persistent を使用してください。" -ForegroundColor Yellow
    }
}

function Show-CurrentEnvironmentVariables {
    Write-Host "🔍 現在の環境変数設定" -ForegroundColor Cyan
    Write-Host "=" * 40 -ForegroundColor Gray
    
    $vars = @("CERT_PASSWORD", "M365_TENANT_ID", "M365_CLIENT_ID", "M365_ORGANIZATION")
    
    foreach ($var in $vars) {
        $value = [Environment]::GetEnvironmentVariable($var)
        if ($value) {
            if ($var -eq "CERT_PASSWORD") {
                Write-Host "$var = ********" -ForegroundColor Green
            } else {
                Write-Host "$var = $value" -ForegroundColor Green
            }
        } else {
            Write-Host "$var = (未設定)" -ForegroundColor Red
        }
    }
}

# メイン実行
if ($ShowCurrent) {
    Show-CurrentEnvironmentVariables
} else {
    Set-SecureEnvironmentVariables -MakePersistent $Persistent
}