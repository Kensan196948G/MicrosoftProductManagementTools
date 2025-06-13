# Microsoft製品運用管理ツール - 展開ガイド

## 🚀 別PCへの展開手順

このツールを別のPCに移動・展開する際の手順とベストプラクティスです。

### 📋 前提条件

- Windows 10/11 または Windows Server 2019+
- PowerShell 5.1+ または PowerShell 7+
- 管理者権限
- インターネット接続

### 📦 展開パッケージ内容

```
MicrosoftProductManagementTools/
├── Config/
│   └── appsettings.json           # 設定ファイル（要設定）
├── Certificates/
│   ├── MiraiConstEXO.pfx         # 認証用証明書（重要）
│   ├── MiraiConstEXO.cer         # Azure AD用証明書
│   └── certificate-info.txt     # 証明書情報
├── Scripts/                      # PowerShellスクリプト群
├── Templates/                    # レポートテンプレート
├── Reports/                      # 生成されるレポート格納先
└── Logs/                        # ログファイル格納先
```

## 🔧 セットアップ手順

### ステップ1: ファイルのコピー

```powershell
# フォルダ全体を新しいPCにコピー
# 例: C:\Tools\MicrosoftProductManagementTools\
```

### ステップ2: PowerShellモジュールのインストール

```powershell
# 管理者権限でPowerShell実行
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 必要なモジュールをインストール
Install-Module Microsoft.Graph -Force -AllowClobber -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Force -AllowClobber -Scope CurrentUser
```

### ステップ3: 証明書の確認

```powershell
# 証明書ファイルの存在確認
Test-Path "C:\Tools\MicrosoftProductManagementTools\Certificates\MiraiConstEXO.pfx"

# 証明書情報の確認
Get-Content "C:\Tools\MicrosoftProductManagementTools\Certificates\certificate-info.txt"
```

### ステップ4: 設定の確認・調整

```powershell
# 設定ファイルの確認
Get-Content "C:\Tools\MicrosoftProductManagementTools\Config\appsettings.json" | ConvertFrom-Json
```

#### 重要な設定項目：

```json
{
  "EntraID": {
    "TenantId": "a7232f7a-a9e5-4f71-9372-dc8b1c6645ea",
    "ClientId": "22e5d6e4-805f-4516-af09-ff09c7c224c4",
    "CertificateThumbprint": "94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6",
    "CertificatePath": "Certificates/MiraiConstEXO.pfx",
    "CertificatePassword": ""
  },
  "ExchangeOnline": {
    "Organization": "miraiconst.onmicrosoft.com",
    "AppId": "22e5d6e4-805f-4516-af09-ff09c7c224c4",
    "CertificateThumbprint": "94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6",
    "CertificatePath": "Certificates/MiraiConstEXO.pfx",
    "CertificatePassword": ""
  }
}
```

### ステップ5: 認証テスト

```powershell
# ツールディレクトリに移動
cd "C:\Tools\MicrosoftProductManagementTools"

# 認証テスト実行
pwsh -File test-authentication.ps1
```

### ステップ6: 動作確認

```powershell
# レポート生成テスト
pwsh -File test-report-generation.ps1 -ReportType Daily

# システム整合性チェック
bash config-check.sh --auto
```

## ✅ 認証方式の説明

### 🔄 ハイブリッド認証（推奨）

このツールは以下の順序で認証を試行します：

1. **ファイルベース証明書認証**（ポータブル）
   - `CertificatePath` で指定されたPFXファイルを使用
   - 別PCでもファイルがあれば動作

2. **Thumbprint証明書認証**（フォールバック）
   - Windows証明書ストアのThumbprintを使用
   - 同一PC内でのみ有効

### 🔐 セキュリティ考慮事項

**証明書の取り扱い：**
- PFXファイルには秘密鍵が含まれるため厳重に管理
- 可能であればパスワード保護を推奨
- 不要なコピーは削除

**ネットワークセキュリティ：**
- Microsoft 365への接続はTLS暗号化
- オンプレミスADへの接続は組織のセキュリティポリシーに従う

## 🚨 トラブルシューティング

### 問題: 証明書認証エラー

```powershell
# 証明書ファイルの権限確認
Get-Acl "Certificates/MiraiConstEXO.pfx"

# 証明書の有効性確認
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("Certificates/MiraiConstEXO.pfx")
$cert.NotAfter  # 有効期限確認
```

### 問題: PowerShellモジュールエラー

```powershell
# モジュールの再インストール
Remove-Module Microsoft.Graph -Force -ErrorAction SilentlyContinue
Install-Module Microsoft.Graph -Force -AllowClobber
```

### 問題: 設定ファイルエラー

```powershell
# JSON構文チェック
Get-Content "Config/appsettings.json" | ConvertFrom-Json
```

## 📅 定期保守

### 証明書の更新
- 証明書有効期限の監視
- 更新時は `certificate-update-procedure.md` を参照

### ログの管理
- 自動ログローテーション設定済み
- 必要に応じて `log-management-config.sh` 実行

### スケジュール設定
- Windows: タスクスケジューラー
- Linux/WSL: cron設定

## 📞 サポート

問題が発生した場合：
1. ログファイル（`Logs/`）を確認
2. `config-check.sh` でシステム整合性確認
3. 証明書の有効期限確認
4. Azure ADアプリケーションの権限確認

---

**重要**: 本ツールはITSM/ISO27001/27002準拠のため、変更記録と承認プロセスに従って展開してください。