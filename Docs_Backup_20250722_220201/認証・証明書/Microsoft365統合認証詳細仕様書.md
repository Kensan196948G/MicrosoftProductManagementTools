# Microsoft 365統合認証詳細仕様書

**文書バージョン**: v2.1  
**作成日**: 2025年7月17日  
**対象システム**: Microsoft 365統合管理ツール  
**認証対象**: Microsoft Graph API、Microsoft Teams、Exchange Online  

## 📋 文書概要

本仕様書は、Microsoft 365統合管理ツールにおける非対話型認証の実装詳細、設定方法、トラブルシューティングについて包括的に説明します。

## 🏢 システム構成概要

### 認証アーキテクチャ
```
Microsoft 365統合管理ツール
├── Microsoft Graph API（非対話型認証）
│   ├── Application Registration
│   ├── Client Credentials Flow
│   └── API Permissions
├── Microsoft Teams認証
│   ├── Teams API via Graph
│   ├── Teams Admin Center API
│   └── Teams PowerShell Module
└── Exchange Online認証
    ├── Certificate-based Authentication
    ├── App-only Authentication
    └── Exchange Online PowerShell
```

## 🔐 Microsoft Graph API 非対話型認証

### 1. Azure AD アプリケーション登録

#### 1.1 アプリケーション基本設定
- **アプリケーション名**: `M365-Management-Tool-Production`
- **サポートされるアカウントの種類**: この組織ディレクトリのみのアカウント
- **リダイレクトURI**: 不要（非対話型のため）

#### 1.2 必要なAPI権限（Application権限）
```
Microsoft Graph:
├── Application.Read.All
├── Directory.Read.All
├── Group.Read.All
├── GroupMember.Read.All
├── Mail.Read
├── Reports.Read.All
├── Sites.Read.All
├── User.Read.All
├── UserAuthenticationMethod.Read.All
├── AuditLog.Read.All
├── SecurityEvents.Read.All
├── MailboxSettings.Read
├── Calendars.Read
└── Files.Read.All
```

#### 1.3 クライアント資格情報の設定
```json
{
  "TenantId": "your-tenant-id-here",
  "ClientId": "your-client-id-here",
  "ClientSecret": "your-client-secret-here"
}
```

### 2. PowerShell実装

#### 2.1 認証関数の実装
```powershell
function Connect-M365GraphAPI {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret
    )
    
    try {
        # Microsoft Graph PowerShell SDK接続
        $SecureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential($ClientId, $SecureSecret)
        
        Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $Credential -NoWelcome
        
        # 接続確認
        $context = Get-MgContext
        if ($context) {
            Write-Host "✅ Microsoft Graph接続成功" -ForegroundColor Green
            Write-Host "   TenantId: $($context.TenantId)" -ForegroundColor Gray
            Write-Host "   Account: $($context.Account)" -ForegroundColor Gray
            return $true
        }
    }
    catch {
        Write-Host "❌ Microsoft Graph接続失敗: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}
```

#### 2.2 主要データ取得関数
```powershell
# ユーザー情報取得
function Get-M365AllUsers {
    try {
        $users = Get-MgUser -All -Property DisplayName,Mail,UserPrincipalName,AccountEnabled,CreatedDateTime,LastSignInDateTime
        return $users
    }
    catch {
        Write-Error "ユーザー情報取得エラー: $($_.Exception.Message)"
        return @()
    }
}

# ライセンス情報取得
function Get-M365LicenseInfo {
    try {
        $subscribedSkus = Get-MgSubscribedSku
        $licenses = foreach ($sku in $subscribedSkus) {
            [PSCustomObject]@{
                SkuPartNumber = $sku.SkuPartNumber
                ConsumedUnits = $sku.ConsumedUnits
                PrepaidUnits = $sku.PrepaidUnits.Enabled
                SkuId = $sku.SkuId
            }
        }
        return $licenses
    }
    catch {
        Write-Error "ライセンス情報取得エラー: $($_.Exception.Message)"
        return @()
    }
}

# MFA状況取得
function Get-M365MFAStatus {
    try {
        $users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName
        $mfaStatus = foreach ($user in $users) {
            $authMethods = Get-MgUserAuthenticationMethod -UserId $user.Id
            [PSCustomObject]@{
                DisplayName = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                MFAEnabled = $authMethods.Count -gt 1
                AuthMethodCount = $authMethods.Count
            }
        }
        return $mfaStatus
    }
    catch {
        Write-Error "MFA状況取得エラー: $($_.Exception.Message)"
        return @()
    }
}
```

## 💬 Microsoft Teams認証

### 1. Teams API経由のアクセス

#### 1.1 必要なGraph API権限
```
Microsoft Graph - Teams関連:
├── Team.ReadBasic.All
├── TeamMember.Read.All
├── TeamsActivity.Read.All
├── CallRecords.Read.All
├── Chat.Read.All
├── Channel.ReadBasic.All
└── TeamsAppInstallation.Read.All
```

#### 1.2 Teams使用状況データ取得
```powershell
function Get-M365TeamsUsage {
    param(
        [int]$Period = 30  # 過去30日間
    )
    
    try {
        # Teams使用状況レポート取得
        $teamsUsage = Get-MgReportTeamsUserActivityUserDetail -Period "D$Period"
        
        if ($teamsUsage) {
            $parsedData = $teamsUsage | ConvertFrom-Csv
            $formattedData = foreach ($record in $parsedData) {
                [PSCustomObject]@{
                    UserPrincipalName = $record.'User Principal Name'
                    LastActivityDate = $record.'Last Activity Date'
                    TeamChatMessageCount = $record.'Team Chat Message Count'
                    PrivateChatMessageCount = $record.'Private Chat Message Count'
                    CallCount = $record.'Call Count'
                    MeetingCount = $record.'Meeting Count'
                    HasOtherAction = $record.'Has Other Action'
                    ReportPeriod = $Period
                }
            }
            return $formattedData
        }
    }
    catch {
        Write-Error "Teams使用状況取得エラー: $($_.Exception.Message)"
        return @()
    }
}

# Teamsの通話品質データ取得
function Get-M365TeamsCallQuality {
    try {
        # 過去7日間の通話レコード取得
        $startDate = (Get-Date).AddDays(-7)
        $endDate = Get-Date
        
        $callRecords = Get-MgCommunicationCallRecord -Filter "startDateTime ge $($startDate.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')) and startDateTime le $($endDate.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'))"
        
        return $callRecords
    }
    catch {
        Write-Error "Teams通話品質データ取得エラー: $($_.Exception.Message)"
        return @()
    }
}
```

### 2. Teams PowerShellモジュール（補完用）

#### 2.1 Teams PowerShell接続
```powershell
function Connect-TeamsService {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret
    )
    
    try {
        # Teams PowerShellモジュール接続
        Import-Module MicrosoftTeams -Force
        
        $SecureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential($ClientId, $SecureSecret)
        
        Connect-MicrosoftTeams -TenantId $TenantId -ApplicationId $ClientId -CertificateThumbprint $CertificateThumbprint
        
        return $true
    }
    catch {
        Write-Error "Teams PowerShell接続エラー: $($_.Exception.Message)"
        return $false
    }
}
```

## 📧 Exchange Online認証

### 1. 証明書ベース認証

#### 1.1 証明書要件
- **証明書タイプ**: X.509証明書
- **キー長**: 2048ビット以上
- **有効期間**: 1年間（推奨）
- **フォーマット**: .pfx（秘密キー含む）

#### 1.2 証明書作成手順
```powershell
# 自己署名証明書作成
$cert = New-SelfSignedCertificate -Subject "CN=M365ManagementTool" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256

# PFXファイルとしてエクスポート
$certPassword = ConvertTo-SecureString "YourSecurePassword" -AsPlainText -Force
Export-PfxCertificate -Cert $cert -FilePath "C:\Certificates\mycert.pfx" -Password $certPassword

# 公開キー（.cer）をエクスポート
Export-Certificate -Cert $cert -FilePath "C:\Certificates\mycert.cer"
```

#### 1.3 Azure ADアプリケーションへの証明書登録
1. Azure PortalでAzure AD → アプリの登録 → 対象アプリ選択
2. 「証明書とシークレット」→「証明書」→「証明書のアップロード」
3. .cerファイルをアップロード
4. 拇印（Thumbprint）を記録

### 2. Exchange Online PowerShell接続

#### 2.1 接続関数の実装
```powershell
function Connect-ExchangeOnlineService {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$CertificateThumbprint,
        [string]$CertificateFilePath,
        [string]$CertificatePassword
    )
    
    try {
        # Exchange Online PowerShellモジュールインポート
        Import-Module ExchangeOnlineManagement -Force
        
        if ($CertificateThumbprint) {
            # 証明書ストアから接続
            Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $TenantId -ShowProgress:$false
        }
        elseif ($CertificateFilePath) {
            # PFXファイルから接続
            $SecurePassword = ConvertTo-SecureString $CertificatePassword -AsPlainText -Force
            Connect-ExchangeOnline -AppId $ClientId -CertificateFilePath $CertificateFilePath -CertificatePassword $SecurePassword -Organization $TenantId -ShowProgress:$false
        }
        
        # 接続確認
        $session = Get-PSSession | Where-Object {$_.Name -like "*ExchangeOnline*"}
        if ($session) {
            Write-Host "✅ Exchange Online接続成功" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Error "Exchange Online接続エラー: $($_.Exception.Message)"
        return $false
    }
}
```

#### 2.2 主要データ取得関数
```powershell
# メールボックス情報取得
function Get-M365MailboxInfo {
    try {
        $mailboxes = Get-Mailbox -ResultSize Unlimited | Select-Object DisplayName,PrimarySmtpAddress,RecipientType,WhenCreated
        return $mailboxes
    }
    catch {
        Write-Error "メールボックス情報取得エラー: $($_.Exception.Message)"
        return @()
    }
}

# メールフロー統計取得
function Get-M365MailFlowStats {
    param(
        [int]$Days = 7
    )
    
    try {
        $endDate = Get-Date
        $startDate = $endDate.AddDays(-$Days)
        
        $messageTrace = Get-MessageTrace -StartDate $startDate -EndDate $endDate
        return $messageTrace
    }
    catch {
        Write-Error "メールフロー統計取得エラー: $($_.Exception.Message)"
        return @()
    }
}
```

## ⚙️ 設定ファイル構成

### appsettings.json構成例
```json
{
  "Authentication": {
    "Microsoft365": {
      "TenantId": "your-tenant-id",
      "ClientId": "your-client-id",
      "ClientSecret": "your-client-secret"
    },
    "ExchangeOnline": {
      "AppId": "your-app-id",
      "CertificateThumbprint": "94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6",
      "CertificateFilePath": "Certificates/mycert.pfx",
      "CertificatePassword": "your-certificate-password",
      "Organization": "your-tenant-domain.onmicrosoft.com"
    }
  },
  "Security": {
    "EncryptionKey": "your-encryption-key",
    "UseKeyVault": false,
    "KeyVaultName": ""
  }
}
```

## 🛡️ セキュリティ考慮事項

### 1. 権限の最小化
- **必要最小限の権限のみ付与**
- **定期的な権限レビュー**（推奨：3ヶ月毎）
- **使用しない権限の削除**

### 2. シークレット管理
- **Azure Key Vault使用推奨**
- **appsettings.jsonの暗号化**
- **定期的なシークレットローテーション**（推奨：6ヶ月毎）

### 3. 証明書管理
- **証明書の有効期限監視**
- **自動更新スクリプトの実装**
- **バックアップ証明書の準備**

### 4. 監査ログ
- **全認証イベントのログ記録**
- **失敗した認証の監視**
- **異常なアクセスパターンの検出**

## 🔧 トラブルシューティング

### よくある問題と解決策

#### 1. Microsoft Graph接続エラー
```
エラー: "AADSTS70011: The provided value for the input parameter 'scope' is not valid."
解決策: APIアクセス許可で管理者の同意が必要
```

#### 2. Exchange Online証明書エラー
```
エラー: "Certificate with thumbprint [XXX] not found"
解決策: 証明書が正しいストアにインストールされているか確認
```

#### 3. Teams API制限エラー
```
エラー: "Request was throttled"
解決策: リクエスト間隔を調整（推奨：1秒間隔）
```

### 診断コマンド
```powershell
# Microsoft Graph接続状態確認
Get-MgContext

# Exchange Online接続状態確認
Get-PSSession | Where-Object {$_.Name -like "*ExchangeOnline*"}

# 証明書確認
Get-ChildItem Cert:\CurrentUser\My | Where-Object {$_.Thumbprint -eq "YourThumbprint"}
```

## 📊 パフォーマンス最適化

### 1. バッチ処理
- **大量データ取得時のページング実装**
- **並列処理の活用**
- **適切なフィルタリング**

### 2. キャッシュ戦略
- **静的データの30分キャッシュ**
- **ユーザーデータの15分キャッシュ**
- **レポートデータの5分キャッシュ**

### 3. レート制限対応
- **指数バックオフ実装**
- **429エラーの適切な処理**
- **リクエスト間隔の自動調整**

## 📋 監査とコンプライアンス

### 1. ISO/IEC 27001準拠
- **アクセス制御（A.9）**
- **暗号化（A.10）**
- **事業継続性（A.17）**

### 2. ログ要件
- **認証ログの1年間保存**
- **エラーログの6ヶ月保存**
- **操作ログの90日保存**

### 3. 定期監査項目
- **月次：権限レビュー**
- **四半期：セキュリティ評価**
- **年次：包括的監査**

## 🚀 今後の拡張計画

### Phase 1（2025年Q3）
- **Azure Key Vault統合**
- **Managed Identity対応**
- **条件付きアクセス統合**

### Phase 2（2025年Q4）
- **Multi-tenant対応**
- **API Gateway実装**
- **リアルタイム監視**

### Phase 3（2026年Q1）
- **Machine Learning統合**
- **異常検知システム**
- **予測分析機能**

---

## 📝 変更履歴

| バージョン | 日付 | 変更者 | 変更内容 |
|-----------|------|--------|----------|
| v1.0 | 2024年12月15日 | 開発チーム | 初版作成 |
| v1.1 | 2025年1月20日 | セキュリティチーム | セキュリティ要件追加 |
| v1.2 | 2025年3月10日 | 開発チーム | Teams API統合 |
| v1.3 | 2025年5月15日 | 運用チーム | 監査要件追加 |
| v1.4 | 2025年6月20日 | 開発チーム | Exchange Online証明書認証対応 |
| v1.5 | 2025年7月5日 | 開発チーム | PowerShell 7.5.1対応 |
| v2.0 | 2025年7月16日 | 開発チーム | 完全ダミーデータ除去、実データ統合 |
| v2.1 | 2025年7月17日 | 開発チーム | リアルタイムログ機能、GUI強化、認証エラー解決 |

### v2.1での主な変更点
- **実行ポリシー問題の解決**: Unblock-File、強化されたエラーハンドリング
- **GUI機能強化**: リアルタイムログ表示、Write-GuiLog関数
- **認証安定性向上**: フォールバック認証、詳細エラー情報
- **PowerShellプロンプト統合**: 新プロセス作成廃止
- **モジュール読み込み最適化**: 段階的読み込み、包括的エラー対応

---

**© 2025 Microsoft 365統合管理ツール開発チーム**  
**機密文書 - 社内利用限定**