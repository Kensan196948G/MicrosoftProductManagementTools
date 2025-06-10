# ================================================================================
# Update-CertificateSettings.ps1  
# 新しい証明書情報でappsettings.jsonを自動更新
# ================================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$CertificateThumbprint,
    
    [Parameter(Mandatory = $false)]
    [string]$ClientId = "",
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "Config/appsettings.json"
)

Write-Host "🔧 証明書設定を更新中..." -ForegroundColor Green

try {
    # 設定ファイル読み込み
    if (-not (Test-Path $ConfigPath)) {
        throw "設定ファイルが見つかりません: $ConfigPath"
    }
    
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    
    # 証明書拇印更新
    $config.EntraID.CertificateThumbprint = $CertificateThumbprint
    $config.ExchangeOnline.CertificateThumbprint = $CertificateThumbprint
    
    # クライアントID更新（新しいアプリの場合）
    if ($ClientId -and $ClientId -ne "") {
        $config.EntraID.ClientId = $ClientId
        $config.ExchangeOnline.AppId = $ClientId
        Write-Host "📝 新しいクライアントID設定: $ClientId" -ForegroundColor Yellow
    }
    
    # 設定ファイル保存
    $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
    
    Write-Host "✅ 設定ファイル更新完了" -ForegroundColor Green
    Write-Host "証明書拇印: $CertificateThumbprint" -ForegroundColor Cyan
    
    # 接続テスト実行
    Write-Host "`n🧪 接続テストを実行中..." -ForegroundColor Yellow
    
    $testResult = & {
        Import-Module "./Scripts/Common/Authentication.psm1" -Force
        $configObj = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        Test-AuthenticationStatus -RequiredServices @("MicrosoftGraph")
    }
    
    if ($testResult.IsValid) {
        Write-Host "✅ 接続テスト成功" -ForegroundColor Green
    } else {
        Write-Host "⚠️ 接続テストで問題を検出: $($testResult.MissingServices -join ', ')" -ForegroundColor Yellow
    }
}
catch {
    Write-Error "設定更新エラー: $($_.Exception.Message)"
}