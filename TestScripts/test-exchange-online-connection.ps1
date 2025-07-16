# Exchange Online接続テストスクリプト
# 証明書ベース認証でExchange Onlineに接続

$configPath = "E:\MicrosoftProductManagementTools\Config\appsettings.json"
$envPath = "E:\MicrosoftProductManagementTools\.env"

Write-Host "🔑 Exchange Online接続テスト開始..." -ForegroundColor Cyan

try {
    # 環境変数読み込み
    $envVars = @{}
    if (Test-Path $envPath) {
        $content = Get-Content $envPath -ErrorAction SilentlyContinue
        foreach ($line in $content) {
            if ($line -match '^([^#][^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim().Trim('"', "'")
                $envVars[$key] = $value
            }
        }
    }
    
    # 設定ファイルから認証情報を読み込み
    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $organization = $config.ExchangeOnline.Organization
        $appId = $envVars["REACT_APP_MS_CLIENT_ID"]
        $certificateThumbprint = $config.ExchangeOnline.CertificateThumbprint
        $certificatePassword = $envVars["EXO_CERTIFICATE_PASSWORD"]
        
        Write-Host "📋 接続パラメータ:" -ForegroundColor Yellow
        Write-Host "  Organization: $organization" -ForegroundColor Gray
        Write-Host "  AppId: $appId" -ForegroundColor Gray
        Write-Host "  CertificateThumbprint: $certificateThumbprint" -ForegroundColor Gray
        Write-Host "  CertificatePassword: $($certificatePassword.Substring(0, 3))..." -ForegroundColor Gray
        
        # 証明書がWindows証明書ストアに存在するか確認
        $installedCert = Get-ChildItem "Cert:\CurrentUser\My" | Where-Object { $_.Thumbprint -eq $certificateThumbprint }
        if ($installedCert) {
            Write-Host "✅ 証明書が証明書ストアで見つかりました" -ForegroundColor Green
            Write-Host "  Subject: $($installedCert.Subject)" -ForegroundColor Gray
            Write-Host "  NotAfter: $($installedCert.NotAfter)" -ForegroundColor Gray
            
            # ExchangeOnlineManagementモジュールのインポート
            Write-Host "`n📦 ExchangeOnlineManagementモジュールを確認中..." -ForegroundColor Yellow
            if (Get-Module -Name ExchangeOnlineManagement -ListAvailable) {
                Import-Module ExchangeOnlineManagement -Force
                Write-Host "✅ ExchangeOnlineManagementモジュールが読み込まれました" -ForegroundColor Green
                
                # Exchange Onlineに接続
                Write-Host "`n🔗 Exchange Onlineに接続中..." -ForegroundColor Yellow
                $connectParams = @{
                    Organization = $organization
                    AppId = $appId
                    CertificateThumbprint = $certificateThumbprint
                    ShowProgress = $false
                    ShowBanner = $false
                }
                
                Connect-ExchangeOnline @connectParams
                
                # 接続テスト
                Write-Host "🧪 接続テスト実行中..." -ForegroundColor Yellow
                $orgConfig = Get-OrganizationConfig
                
                if ($orgConfig) {
                    Write-Host "✅ Exchange Online接続成功!" -ForegroundColor Green
                    Write-Host "  組織名: $($orgConfig.DisplayName)" -ForegroundColor Gray
                    Write-Host "  組織ID: $($orgConfig.Identity)" -ForegroundColor Gray
                    
                    # 簡単なメールボックス情報を取得
                    Write-Host "`n📧 メールボックス情報テスト..." -ForegroundColor Yellow
                    $mailboxes = Get-Mailbox -ResultSize 5
                    if ($mailboxes) {
                        Write-Host "✅ メールボックス情報の取得に成功しました ($($mailboxes.Count) 件)" -ForegroundColor Green
                        foreach ($mailbox in $mailboxes) {
                            Write-Host "  - $($mailbox.DisplayName) ($($mailbox.PrimarySmtpAddress))" -ForegroundColor Gray
                        }
                    }
                    
                    # 接続を切断
                    Write-Host "`n🔌 接続を切断中..." -ForegroundColor Yellow
                    Disconnect-ExchangeOnline -Confirm:$false
                    Write-Host "✅ 接続が切断されました" -ForegroundColor Green
                    
                } else {
                    Write-Host "❌ 組織設定の取得に失敗しました" -ForegroundColor Red
                }
            } else {
                Write-Host "❌ ExchangeOnlineManagementモジュールが見つかりません" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ 証明書が証明書ストアで見つかりません" -ForegroundColor Red
            Write-Host "  Thumbprint: $certificateThumbprint" -ForegroundColor Gray
        }
    } else {
        Write-Host "❌ 設定ファイルが見つかりません: $configPath" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Exchange Online接続エラー: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🏁 Exchange Online接続テスト完了" -ForegroundColor Cyan