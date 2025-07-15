# Exchange Online認証テスト
Import-Module ./Scripts/Common/Logging.psm1 -Force
Import-Module ./Scripts/Common/ErrorHandling.psm1 -Force
Import-Module ./Scripts/Common/Authentication.psm1 -Force

try {
    Write-Host "Exchange Online認証テスト開始..." -ForegroundColor Yellow
    
    # ローカル設定ファイルを優先的に読み込み
    $localConfigPath = "./Config/appsettings.local.json"
    $baseConfigPath = "./Config/appsettings.json"
    
    if (Test-Path $localConfigPath) {
        Write-Host "ローカル設定ファイルを使用: $localConfigPath" -ForegroundColor Green
        $configText = Get-Content $localConfigPath -Raw
        $config = $configText | ConvertFrom-Json
    }
    elseif (Test-Path $baseConfigPath) {
        Write-Host "ベース設定ファイルを使用: $baseConfigPath" -ForegroundColor Yellow
        $configText = Get-Content $baseConfigPath -Raw
        $config = $configText | ConvertFrom-Json
        
        # プレースホルダーチェック
        if ($config.ExchangeOnline.AppId -like "*YOUR-*-HERE*" -or $config.ExchangeOnline.CertificateThumbprint -like "*YOUR-*-HERE*") {
            Write-Host "⚠️  Exchange Online設定にプレースホルダーが含まれています" -ForegroundColor Yellow
            Write-Host "💡 実際の認証情報を Config/appsettings.local.json に設定してください" -ForegroundColor Cyan
            throw "Exchange Online認証情報が未設定です"
        }
    }
    else {
        throw "設定ファイルが見つかりません: $baseConfigPath または $localConfigPath"
    }
    
    Write-Host "AppId: $($config.ExchangeOnline.AppId)" -ForegroundColor Green
    Write-Host "Organization: $($config.ExchangeOnline.Organization)" -ForegroundColor Green
    Write-Host "CertificateThumbprint: $($config.ExchangeOnline.CertificateThumbprint)" -ForegroundColor Green
    Write-Host "CertificatePath: $($config.ExchangeOnline.CertificatePath)" -ForegroundColor Green
    
    $result = Connect-ExchangeOnlineService -Config $config
    
    if ($result) {
        Write-Host "Exchange Online認証成功!" -ForegroundColor Green
        
        # 接続確認
        Write-Host "組織情報確認中..." -ForegroundColor Yellow
        $orgConfig = Get-OrganizationConfig | Select-Object Name, Identity
        if ($orgConfig) {
            Write-Host "組織名: $($orgConfig.Name)" -ForegroundColor Green
            Write-Host "組織ID: $($orgConfig.Identity)" -ForegroundColor Green
        }
        
        # 基本API呼び出しテスト
        Write-Host "メールボックス情報取得テスト中..." -ForegroundColor Yellow
        $mailboxes = Get-Mailbox -ResultSize 3 | Select-Object DisplayName, PrimarySmtpAddress
        if ($mailboxes) {
            Write-Host "メールボックス取得成功: $($mailboxes.Count) 個" -ForegroundColor Green
            foreach ($mailbox in $mailboxes) {
                Write-Host "  - $($mailbox.DisplayName) ($($mailbox.PrimarySmtpAddress))" -ForegroundColor Gray
            }
        }
    }
    else {
        Write-Host "Exchange Online認証失敗" -ForegroundColor Red
    }
}
catch {
    Write-Host "エラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "詳細: $($_.Exception.InnerException.Message)" -ForegroundColor Red
}