# Exchange Online 証明書認証移行ガイド

**作成日**: 2025年1月17日  
**作成者**: CTO  
**対象**: 開発チーム・運用チーム  
**緊急度**: 高（即時対応必要）

## 概要

Exchange Online PowerShell V3において、`CertificateThumbprint`パラメータが非推奨となり、将来的に削除される予定です。本ガイドでは、PFXファイルベースの認証への移行手順を説明します。

## 1. 現状の問題点

### 1.1 非推奨の警告メッセージ
```
WARNING: The -CertificateThumbprint parameter is deprecated. 
Use the -CertificatePath parameter with a password or the -Certificate parameter with an X509Certificate2 object instead.
```

### 1.2 影響範囲
- Authentication.psm1の`Connect-ToExchangeOnline`関数
- すべてのExchange Online関連機能
- 自動化されたバッチ処理

## 2. 移行手順

### 2.1 証明書の準備

#### ステップ1: 既存証明書の確認
```powershell
# 現在の証明書情報
$thumbprint = "94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6"
$certPath = ".\Certificates\ExchangeOnlineCertificate.cer"
```

#### ステップ2: PFXファイルの生成
```bash
# CERとKEYファイルからPFXを作成
openssl pkcs12 -export \
  -out ExchangeOnlineCertificate.pfx \
  -in ExchangeOnlineCertificate.cer \
  -inkey ExchangeOnlineCertificate.key \
  -password pass:$EXO_CERTIFICATE_PASSWORD
```

#### ステップ3: PFXファイルの検証
```powershell
# PFXファイルの内容確認
$pfxPath = ".\Certificates\ExchangeOnlineCertificate.pfx"
$password = ConvertTo-SecureString $env:EXO_CERTIFICATE_PASSWORD -AsPlainText -Force
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($pfxPath, $password)

Write-Host "Subject: $($cert.Subject)"
Write-Host "Thumbprint: $($cert.Thumbprint)"
Write-Host "有効期限: $($cert.NotAfter)"
```

### 2.2 コードの更新

#### 現在の実装（非推奨）
```powershell
function Connect-ToExchangeOnline {
    param(
        [string]$CertificateThumbprint,
        [string]$AppId,
        [string]$Organization
    )
    
    Connect-ExchangeOnline `
        -CertificateThumbprint $CertificateThumbprint `
        -AppId $AppId `
        -Organization $Organization `
        -ShowBanner:$false
}
```

#### 新しい実装（推奨）
```powershell
function Connect-ToExchangeOnline {
    param(
        [string]$CertificatePath,
        [SecureString]$CertificatePassword,
        [string]$AppId,
        [string]$Organization
    )
    
    # エラーハンドリング付き
    try {
        # PFXファイルの存在確認
        if (-not (Test-Path $CertificatePath)) {
            throw "証明書ファイルが見つかりません: $CertificatePath"
        }
        
        # 接続実行
        Connect-ExchangeOnline `
            -CertificatePath $CertificatePath `
            -CertificatePassword $CertificatePassword `
            -AppId $AppId `
            -Organization $Organization `
            -ShowBanner:$false `
            -ErrorAction Stop
            
        Write-Log -Level "Info" -Message "Exchange Online接続成功"
        return $true
    }
    catch {
        Write-Log -Level "Error" -Message "Exchange Online接続失敗: $_"
        throw
    }
}
```

### 2.3 設定ファイルの更新

#### appsettings.json
```json
{
  "ExchangeOnline": {
    "AppId": "your-app-id",
    "Organization": "your-org.onmicrosoft.com",
    "CertificatePath": "Certificates\\ExchangeOnlineCertificate.pfx",
    "CertificatePasswordKey": "EXO_CERTIFICATE_PASSWORD"
  }
}
```

### 2.4 環境変数の設定
```powershell
# Windows
[Environment]::SetEnvironmentVariable("EXO_CERTIFICATE_PASSWORD", "your-password", "User")

# Linux/macOS
export EXO_CERTIFICATE_PASSWORD="your-password"
```

## 3. 互換性維持のための段階的移行

### 3.1 フォールバック実装
```powershell
function Connect-ToExchangeOnlineWithFallback {
    param(
        [PSCustomObject]$Config
    )
    
    # 新方式を試行
    if ($Config.CertificatePath -and (Test-Path $Config.CertificatePath)) {
        try {
            $password = Get-SecurePassword -Key $Config.CertificatePasswordKey
            Connect-ExchangeOnline `
                -CertificatePath $Config.CertificatePath `
                -CertificatePassword $password `
                -AppId $Config.AppId `
                -Organization $Config.Organization `
                -ShowBanner:$false
            
            Write-Log -Level "Info" -Message "PFXベース認証成功"
            return $true
        }
        catch {
            Write-Log -Level "Warning" -Message "PFXベース認証失敗、フォールバック実行"
        }
    }
    
    # 旧方式へフォールバック（一時的）
    if ($Config.CertificateThumbprint) {
        Write-Log -Level "Warning" -Message "非推奨: Thumbprintベース認証を使用"
        Connect-ExchangeOnline `
            -CertificateThumbprint $Config.CertificateThumbprint `
            -AppId $Config.AppId `
            -Organization $Config.Organization `
            -ShowBanner:$false
    }
}
```

## 4. テスト計画

### 4.1 単体テスト
```powershell
Describe "Exchange Online PFX認証テスト" {
    BeforeAll {
        $testConfig = @{
            CertificatePath = ".\TestCertificates\test.pfx"
            AppId = "test-app-id"
            Organization = "test.onmicrosoft.com"
        }
    }
    
    It "PFXファイルで正常に接続できる" {
        { Connect-ToExchangeOnline @testConfig } | Should -Not -Throw
    }
    
    It "無効なPFXファイルでエラーが発生する" {
        $testConfig.CertificatePath = ".\invalid.pfx"
        { Connect-ToExchangeOnline @testConfig } | Should -Throw
    }
}
```

### 4.2 統合テスト
1. 開発環境での全機能テスト
2. ステージング環境での負荷テスト
3. 本番環境での段階的展開

## 5. 移行スケジュール

| フェーズ | 期間 | タスク | 担当 |
|---------|------|--------|------|
| 準備 | 1/17-1/19 | PFX証明書生成・検証 | 運用チーム |
| 開発 | 1/20-1/24 | コード更新・単体テスト | 開発チーム |
| テスト | 1/25-1/31 | 統合テスト・性能テスト | QAチーム |
| 展開 | 2/1-2/7 | 段階的本番展開 | 全チーム |
| 完了 | 2/8 | 旧方式の削除 | 開発チーム |

## 6. トラブルシューティング

### 6.1 よくある問題

#### 証明書パスワードエラー
```
エラー: The certificate password is incorrect
解決策: 環境変数 EXO_CERTIFICATE_PASSWORD を確認
```

#### 証明書の権限エラー
```
エラー: Access to the certificate file is denied
解決策: 
icacls "Certificates\ExchangeOnlineCertificate.pfx" /grant:r "$env:USERNAME:(R)"
```

#### 証明書の有効期限
```powershell
# 有効期限チェックスクリプト
$cert = Get-PfxCertificate -FilePath ".\Certificates\ExchangeOnlineCertificate.pfx"
$daysRemaining = ($cert.NotAfter - (Get-Date)).Days
if ($daysRemaining -lt 30) {
    Write-Warning "証明書の有効期限が近づいています: $daysRemaining 日"
}
```

### 6.2 ログ確認
```powershell
# Exchange Online接続ログの確認
Get-ConnectionInformation | Format-List *
```

## 7. ロールバック手順

緊急時のロールバック:
```powershell
# 1. 設定を旧方式に戻す
$config = Get-Content ".\Config\appsettings.backup.json" | ConvertFrom-Json

# 2. 旧バージョンのAuthentication.psm1を復元
Copy-Item ".\Backup\Authentication.psm1.backup" ".\Scripts\Common\Authentication.psm1" -Force

# 3. サービス再起動
Restart-Service "M365ManagementTool"
```

## 8. 完了チェックリスト

- [ ] PFX証明書の生成完了
- [ ] 証明書パスワードの環境変数設定
- [ ] Authentication.psm1の更新
- [ ] appsettings.jsonの更新
- [ ] 単体テストの成功
- [ ] 統合テストの成功
- [ ] 本番環境での動作確認
- [ ] ドキュメントの更新
- [ ] 運用チームへの引き継ぎ
- [ ] 監視アラートの設定

## 9. 参考資料

- [Microsoft Docs: Connect to Exchange Online PowerShell](https://docs.microsoft.com/powershell/exchange/connect-to-exchange-online-powershell)
- [証明書ベース認証のベストプラクティス](https://docs.microsoft.com/azure/active-directory/develop/certificate-credentials)
- 内部Wiki: Exchange Online運用ガイド

---

**承認**: CTO  
**最終更新**: 2025年1月17日