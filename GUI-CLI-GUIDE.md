# 📖 Microsoft 365統合管理ツール GUI/CLI両対応ガイド

## 📋 概要

Microsoft 365統合管理ツールは、Windows 11 + PowerShell 7.5.1対応のGUI/CLI両対応アプリケーションです。現在**本格運用中**で、日次・週次・月次・年次の自動レポート生成システムが稼働しています。

## 🚀 クイックスタート

### 1. 基本起動方法

```powershell
# 自動モード選択（GUI/CLI選択画面表示）
.\run_launcher.ps1

# GUIモードで直接起動
.\run_launcher.ps1 -Mode gui

# CLIモードで直接起動
.\run_launcher.ps1 -Mode cli
```

### 2. ショートカット作成

```powershell
# デスクトップとスタートメニューにショートカット作成
.\Create-Shortcuts.ps1

# デスクトップのみ
.\Create-Shortcuts.ps1 -StartMenu:$false

# 全ユーザー向け（管理者権限必要）
.\Create-Shortcuts.ps1 -AllUsers
```

## 📁 新しいフォルダ構造

```
Microsoft365ProductManagementTools/
├── run_launcher.ps1              # 🎯 メインランチャー
├── Apps/
│   ├── GuiApp.ps1               # 🖼️ GUI アプリケーション
│   └── CliApp.ps1               # 💻 CLI アプリケーション
├── Config/
│   ├── appsettings.json         # ⚙️ Microsoft 365設定
│   └── launcher-config.json     # 🔧 ランチャー設定
├── Installers/
│   ├── README.md                # 📖 インストーラー配置手順
│   └── (PowerShell-7.5.1-win-x64.msi)  # 📦 PS7.5.1インストーラー
├── Scripts/                     # 📝 既存のスクリプト群
├── Create-Shortcuts.ps1         # 🔗 ショートカット作成
└── ... (既存ファイル)
```

## 🎮 GUI モード機能（本格運用中）

### メイン画面
- **🔐 認証テスト**: Microsoft 365への接続確認
- **📊 レポート生成**: 日次・週次・月次・年次レポート（自動生成システム稼働中）
- **💰 ライセンス分析**: ライセンス使用状況ダッシュボード（実運用データ活用）
- **📁 レポートフォルダ**: 生成されたレポートを開く
- **📈 専門分析**: Entra ID、Exchange Online、OneDrive、Teams、セキュリティ監査

### 特徴
- **⏱️ リアルタイム処理表示**: プログレスバーとステータス
- **📜 実行ログ表示**: 操作履歴の確認
- **🚀 PowerShell 7専用**: 最新機能フル活用
- **📊 実運用データ**: 実際の業務データで動作確認済み

## 💻 CLI モード機能（本格運用中）

### 対話メニュー
```
メインメニュー（本格運用システム）
============================================================
1. 認証テスト（証明書ベース認証）
2. 日次レポート生成（自動生成システム稼働中）
3. 週次レポート生成（権限監査・MFA分析含む）
4. 月次レポート生成（ライセンス分析・利用率分析）
5. 年次レポート生成（総合分析・コンプライアンス）
6. ライセンス分析（実運用データ活用）
7. 専門分析（Entra ID・Exchange・OneDrive・Teams）
8. セキュリティ監査（権限・脅威検知）
9. システム情報表示
0. 終了
```

### コマンドライン実行（実運用対応）
```powershell
# 基本操作（実運用データ処理）
.\Apps\CliApp.ps1 -Action auth      # 認証テスト
.\Apps\CliApp.ps1 -Action daily     # 日次レポート（運用中）
.\Apps\CliApp.ps1 -Action weekly    # 週次レポート（権限監査含む）
.\Apps\CliApp.ps1 -Action monthly   # 月次レポート（ライセンス分析含む）
.\Apps\CliApp.ps1 -Action yearly    # 年次レポート（総合分析）
.\Apps\CliApp.ps1 -Action license   # ライセンス分析

# 専門分析（実運用機能）
.\Apps\CliApp.ps1 -Action entraid   # Entra ID分析
.\Apps\CliApp.ps1 -Action exchange  # Exchange Online分析
.\Apps\CliApp.ps1 -Action onedrive  # OneDrive分析
.\Apps\CliApp.ps1 -Action teams     # Teams分析
.\Apps\CliApp.ps1 -Action security  # セキュリティ監査

# バッチモード（自動化・スケジュール実行）
.\Apps\CliApp.ps1 -Action monthly -Batch
.\Apps\CliApp.ps1 -Action daily -Batch -Quiet
```

### 互換性
- **PowerShell 7.x**: 全機能利用可能
- **PowerShell 5.1**: 基本機能のみ（制限モード）

## 🔧 PowerShell 7.5.1 自動インストール

### インストーラー配置
1. `Installers/README.md` の手順に従いPowerShell 7.5.1をダウンロード
2. `Installers/PowerShell-7.5.1-win-x64.msi` として配置

### 自動インストール動作
```powershell
# PowerShell 7.5.1未検出時の動作
1. 既存PowerShell 7バージョンを検索
2. 見つからない場合は自動インストール提案
3. 管理者権限でサイレントインストール実行
4. インストール完了後にアプリケーション起動
```

## ⚙️ 設定ファイル

### Microsoft 365設定 (`Config/appsettings.json`)
```json
{
  "EntraID": {
    "TenantId": "your-tenant-id",
    "ClientId": "your-client-id",
    "CertificateThumbprint": "your-cert-thumbprint"
  }
}
```

### ランチャー設定 (`Config/launcher-config.json`)
```json
{
  "LauncherSettings": {
    "DefaultMode": "auto",
    "RequiredPowerShellVersion": "7.5.1",
    "EnableAutoInstall": true
  }
}
```

## 🎯 使用例

### シナリオ1: 初回セットアップ
```powershell
# 1. PowerShell 7.5.1インストーラー配置
# 2. ランチャー実行
.\run_launcher.ps1

# 3. 自動でPowerShell 7.5.1インストール（必要な場合）
# 4. ショートカット作成
.\Create-Shortcuts.ps1

# 5. GUI/CLIモード選択して利用開始
```

### シナリオ2: 日常運用
```powershell
# GUIモードで視覚的操作
.\run_launcher.ps1 -Mode gui

# CLIモードで自動化スクリプト
.\run_launcher.ps1 -Mode cli
.\Apps\CliApp.ps1 -Action daily -Batch
```

### シナリオ3: 企業展開
```powershell
# 1. ZIPパッケージ展開
# 2. PowerShell 7.5.1インストーラー配置
# 3. 全ユーザー向けショートカット作成
.\Create-Shortcuts.ps1 -AllUsers -Quiet

# 4. バッチファイルでの起動（例）
pwsh.exe -File "run_launcher.ps1" -Mode gui
```

## 🔍 トラブルシューティング

### PowerShell 7.5.1が見つからない
```powershell
# 手動インストール確認
Get-Command pwsh -ErrorAction SilentlyContinue

# バージョン確認
pwsh -Command '$PSVersionTable.PSVersion'

# インストーラー配置確認
Test-Path "Installers\PowerShell-7.5.1-win-x64.msi"
```

### 認証エラー
```powershell
# 認証テスト実行
.\test-auth-simple.ps1

# 設定ファイル確認
Test-Path "Config\appsettings.json"

# 証明書確認
Get-ChildItem Cert:\CurrentUser\My | Where-Object Thumbprint -eq "your-thumbprint"
```

### GUI起動エラー
```powershell
# PowerShell 7確認
$PSVersionTable.PSVersion -ge [Version]"7.0.0"

# .NET Framework確認
[System.Windows.Forms.Application]::EnableVisualStyles()
```

## 📞 サポート

### ログファイル確認
```powershell
# ランチャーログ
Get-Content "Logs\cli_app.log" -Tail 20

# システムログ
Get-Content "Logs\system.log" -Tail 20

# 管理ツールログ
Get-Content "Logs\Management_$(Get-Date -Format yyyyMMdd).log" -Tail 20
```

### バージョン情報
```powershell
# ランチャーバージョン
.\run_launcher.ps1 -Mode cli
.\Apps\CliApp.ps1 -Action version

# PowerShellバージョン
$PSVersionTable
```

---

## 🎉 本格運用中！

Microsoft 365統合管理ツールは最新のGUI/CLI両対応アプリケーションとして**本格運用中**です！

**🏭 本格運用実績:**
- ✅ 日次・週次・月次・年次レポート自動生成システム稼働
- ✅ 証明書ベース認証による安全な接続
- ✅ 全Microsoft 365サービスの包括的監視
- ✅ HTMLダッシュボード・CSV監査証跡の継続生成
- ✅ ライセンス分析・セキュリティ監査の実運用

**🚀 主要機能:**
- ✅ Windows 11 + PowerShell 7.5.1 最適化
- ✅ 直感的なGUIインターフェース
- ✅ 強化されたCLI機能
- ✅ PowerShell 5.1互換性維持
- ✅ 自動インストール機能
- ✅ エンタープライズ展開対応
- ✅ 実運用データによる継続的分析

🚀 **今すぐ利用**: `.\run_launcher.ps1` を実行して本格運用システムをご体験ください！

---

**📊 運用実績**: 2025年6月より継続稼働中 | **🎯 対象**: Microsoft 365 E3環境 | **🔐 認証**: 証明書ベース安全認証