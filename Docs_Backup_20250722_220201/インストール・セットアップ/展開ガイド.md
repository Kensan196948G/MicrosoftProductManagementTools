# 📦 Microsoft 365統合管理ツール - 企業展開ガイド

## 🚀 本格運用システムの企業展開手順

**本格運用中のシステム**を別のPCや企業環境に展開する際の手順とベストプラクティスです。

### 📋 前提条件

- **OS**: Windows 10/11 または Windows Server 2019+
- **PowerShell**: 5.1+ または PowerShell 7.5.1（推奨・自動インストール可能）
- **権限**: 管理者権限（PowerShell自動インストール時）
- **ネットワーク**: インターネット接続（Microsoft 365 API接続）
- **認証**: Microsoft 365管理者権限（証明書ベース認証設定済み）

### 📦 本格運用システム展開パッケージ

```
Microsoft365ProductManagementTools/
├── 🚀 run_launcher.ps1             # メインランチャー
├── 📱 Apps/                        # GUI/CLIアプリケーション
│   ├── GuiApp.ps1                  # GUI版（PowerShell 7専用）
│   └── CliApp.ps1                  # CLI版（クロスバージョン）
├── ⚙️ Config/                       # 設定ファイル群
│   ├── appsettings.json            # Microsoft 365設定（要設定）
│   └── launcher-config.json        # ランチャー設定
├── 🔐 Certificates/                # 認証証明書（重要）
│   ├── mycert.pfx                  # 証明書ファイル（実運用）
│   ├── MiraiConstEXO.*            # Exchange証明書群
│   └── certificate-info.txt       # 証明書情報
├── 📦 Installers/                  # PowerShell 7.5.1インストーラー
├── 📝 Scripts/                     # PowerShellスクリプト群
│   ├── Common/                     # 共通機能モジュール
│   ├── EntraID/                    # Entra ID管理
│   ├── EXO/                        # Exchange Online管理
│   └── UI/                         # ユーザーインターフェース
├── 📊 Reports/                     # 生成レポート（運用データ有）
│   ├── Daily/                      # 日次レポート
│   ├── Weekly/                     # 週次レポート
│   ├── Monthly/                    # 月次レポート
│   └── Yearly/                     # 年次レポート
├── 📋 Templates/                   # レポートテンプレート
├── 📄 Logs/                        # ログファイル
├── 📚 Docs/                        # ドキュメント群
├── 🔗 Create-Shortcuts.ps1         # ショートカット作成
└── ✅ Check-System.ps1              # システムチェック
```

## 🔧 本格運用システム展開手順

### ステップ1: システムパッケージ展開

```powershell
# 1. フォルダ全体を展開先にコピー
# 推奨展開先: C:\Tools\Microsoft365ProductManagementTools\

# 2. 基本ディレクトリ構造確認
Test-Path "Microsoft365ProductManagementTools\run_launcher.ps1"
Test-Path "Microsoft365ProductManagementTools\Apps\"
Test-Path "Microsoft365ProductManagementTools\Config\"
```

### ステップ2: PowerShell環境セットアップ

```powershell
# 実行ポリシー設定
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# PowerShell 7.5.1自動インストール（推奨）
.\Download-PowerShell751.ps1

# 必要モジュールの自動インストール（初回実行時に自動実行）
# または手動インストール:
Install-Module Microsoft.Graph -Force -AllowClobber -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Force -AllowClobber -Scope CurrentUser
```

### ステップ3: 認証・証明書設定

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