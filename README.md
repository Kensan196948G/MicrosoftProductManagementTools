# 🚀 Microsoft 365統合管理ツール (GUI/CLI両対応版)

**Windows 11 + PowerShell 7.5.1対応・GUI/CLI両対応・エンタープライズ向け統合管理システム**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207.5.1%2B-blue)](https://github.com/PowerShell/PowerShell)
[![GUI](https://img.shields.io/badge/GUI-Windows%20Forms-green)](https://docs.microsoft.com/dotnet/desktop/winforms/)
[![CLI](https://img.shields.io/badge/CLI-Cross%20Compatible-orange)](https://docs.microsoft.com/powershell/)
[![License](https://img.shields.io/badge/License-Enterprise-green)](LICENSE)
[![ITSM](https://img.shields.io/badge/ITSM-ISO%2020000-orange)](https://www.iso.org/iso-20000-it-service-management.html)
[![Security](https://img.shields.io/badge/Security-ISO%2027001%2F27002-red)](https://www.iso.org/isoiec-27001-information-security.html)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)](https://github.com)

## 📋 概要

ITSM（ISO/IEC 20000）、ISO/IEC 27001、ISO/IEC 27002標準に準拠したエンタープライズ向けMicrosoft 365管理ツール群です。最新のGUI/CLI両対応アーキテクチャにより、Active Directory、Entra ID、Exchange Online、OneDrive、Microsoft Teamsの自動監視、レポート生成、コンプライアンス追跡機能を直感的なGUIまたは強力なCLIで利用できます。

**本プロジェクトは現在本格運用中で、日次・週次・月次・年次の自動レポート生成システムが稼働しています。**

## ✨ 主な特徴

### 🎮 GUI/CLI両対応アーキテクチャ
- **🖼️ GUIモード**: System.Windows.Formsによる直感的な操作画面
- **💻 CLIモード**: PowerShell 5.1/7.x クロスバージョン対応コマンドライン
- **🔄 統一ランチャー**: `run_launcher.ps1`による自動モード選択
- **⚙️ PowerShell 7.5.1自動管理**: 未インストール時の自動セットアップ

### 🎯 ユーザーエクスペリエンス
- **📱 リアルタイム表示**: 処理進行状況・ステータス・ログの即座更新
- **🎨 視覚的フィードバック**: プログレスバー・色分けログ・アイコン表示
- **⌨️ バッチ処理対応**: 自動化スクリプト・スケジュール実行に最適
- **🔗 ショートカット自動作成**: デスクトップ・スタートメニュー統合

### 🌐 クロスバージョン互換性
- **🔧 PowerShell 5.1**: 基本機能・レガシー環境対応
- **🚀 PowerShell 7.5.1**: 全機能・最新API・高性能処理
- **🤖 自動判別**: 環境に応じた最適機能の提供
- **🛡️ 安全なフォールバック**: バージョン非対応時の代替処理

### 📊 包括的監視機能
- **👥 Active Directory**: ユーザー・グループ・同期状況管理
- **📧 Exchange Online**: メールボックス容量・スパム分析・添付ファイル監視・メールフロー分析
- **☁️ OneDrive**: ストレージ利用状況・外部共有・同期エラー監視
- **💬 Microsoft Teams**: 利用状況・会議品質・外部アクセス管理
- **🛡️ Entra ID**: ユーザー管理・条件付きアクセス・MFA・サインインログ分析
- **💰 ライセンス管理**: 使用状況・コスト分析・最適化提案

### 📈 高度な分析・レポート
- **📅 定期レポート**: 日次/週次/月次/年次の自動生成（実運用中）
- **🚨 リアルタイムアラート**: 閾値ベースの即座通知
- **📊 HTMLダッシュボード**: 視覚的で分かりやすい分析結果
- **📄 CSV出力**: 監査証跡・データ分析用の詳細データ
- **🔐 セキュリティ監査**: 権限レビュー・異常検知・コンプライアンス追跡

## 🚀 クイックスタート

### 📋 前提条件
- ✅ Windows 11 (推奨) または Windows 10
- ✅ PowerShell 5.1+ (PowerShell 7.5.1は自動インストール可能)
- ✅ 管理者権限 (PowerShell自動インストール時)
- ✅ Microsoft 365 管理者アカウント

### ⚡ 即座実行

#### 🖼️ GUIモードで開始
```powershell
# 管理者権限でPowerShellを起動
Start-Process PowerShell -Verb RunAs

# GUIアプリケーション起動
.\run_launcher.ps1 -Mode gui
```

#### 💻 CLIモードで開始
```powershell
# CLIアプリケーション起動
.\run_launcher.ps1 -Mode cli

# または直接コマンド実行
.\Apps\CliApp.ps1 -Action auth  # 認証テスト
.\Apps\CliApp.ps1 -Action daily # 日次レポート
```

#### 🔄 自動モード選択
```powershell
# GUI/CLI選択画面を表示
.\run_launcher.ps1
```

### 🔧 初回セットアップ

#### 1. PowerShell 7.5.1準備
```powershell
# 自動ダウンロード（推奨）
.\Download-PowerShell751.ps1

# 手動配置の場合
# PowerShell-7.5.1-win-x64.msi を Installers/ フォルダに配置
```

#### 2. ショートカット作成
```powershell
# 現在のユーザー向けショートカット作成
.\Create-Shortcuts.ps1

# 全ユーザー向け（管理者権限必要）
.\Create-Shortcuts.ps1 -AllUsers
```

#### 3. 設定確認
```powershell
# 認証設定テスト
.\TestScripts\test-auth-simple.ps1

# 統合機能テスト
.\TestScripts\test-all-features.ps1

# システムチェック
.\Check-System.ps1
```

## 📁 プロジェクト構造

```
Microsoft365ProductManagementTools/
├── 🚀 run_launcher.ps1              # メインランチャー
├── ✅ Check-System.ps1               # システムチェック
├── 📦 Download-PowerShell751.ps1     # PowerShell自動ダウンロード
├── 🔗 Create-Shortcuts.ps1          # ショートカット作成
├── 📱 Apps/                         # GUI/CLIアプリケーション
│   ├── GuiApp.ps1                   # GUI版 (PowerShell 7専用)
│   └── CliApp.ps1                   # CLI版 (クロスバージョン)
├── 🧪 TestScripts/                  # テストスクリプト群
│   ├── test-auth.ps1                # 基本認証テスト
│   ├── test-all-features.ps1        # 全機能統合テスト
│   ├── test-graph-features.ps1      # Microsoft Graph機能テスト
│   └── test-onedrive-gui.ps1        # OneDrive GUI機能テスト
├── ⚙️ Config/                       # 設定ファイル
│   ├── appsettings.json             # Microsoft 365設定
│   └── launcher-config.json         # ランチャー設定
├── 📦 Installers/                   # PowerShell 7.5.1インストーラー
├── 🔐 Certificates/                 # 証明書ファイル
├── 📚 Docs/                         # ドキュメント（日本語）
├── 📝 Scripts/                      # 管理スクリプト群
│   ├── Common/                      # 共通機能モジュール
│   ├── AD/                          # Active Directory管理
│   ├── EXO/                         # Exchange Online管理
│   ├── EntraID/                     # Entra ID・Teams・OneDrive管理
│   └── UI/                          # ユーザーインターフェース
├── 📊 Reports/                      # 生成レポート
│   ├── Daily/                       # 日次レポート
│   ├── Weekly/                      # 週次レポート
│   ├── Monthly/                     # 月次レポート
│   └── Yearly/                      # 年次レポート
├── 📋 Templates/                    # レポートテンプレート
├── 📄 Logs/                         # ログファイル
└── 🗃️ Archive/                      # アーカイブファイル
    ├── LegacyScripts/               # レガシースクリプト
    ├── OldTools/                    # 旧管理ツール
    ├── TestFiles/                   # テストファイル
    ├── BatchFiles/                  # バッチファイル
    ├── PythonScripts/               # Pythonスクリプト
    ├── SystemScripts/               # システムスクリプト
    └── UtilityFiles/                # ユーティリティファイル
```

## 🎮 GUI機能

### 📱 メイン画面
- **🔐 認証テスト**: Microsoft 365への接続確認
- **📊 レポート生成**: 日次・週次・月次・年次レポート
- **💰 ライセンス分析**: 使用状況ダッシュボード
- **📁 レポートフォルダ**: 生成結果へのアクセス

### 🎨 特徴
- **⏱️ リアルタイム処理表示**: プログレスバーとステータス更新
- **📜 実行ログ表示**: 操作履歴の即座確認
- **🎯 エラーハンドリング**: 分かりやすいエラーメッセージ
- **🖱️ ワンクリック操作**: 複雑な処理も簡単実行

## 💻 CLI機能

### 📋 対話メニュー
```
メインメニュー
============================================================
1. 認証テスト
2. 日次レポート生成
3. 週次レポート生成
4. 月次レポート生成
5. 年次レポート生成
6. ライセンス分析
7. システム情報表示
8. ヘルプ表示
0. 終了
============================================================
```

### ⌨️ コマンドライン実行
```powershell
# 認証テスト
.\Apps\CliApp.ps1 -Action auth

# レポート生成
.\Apps\CliApp.ps1 -Action daily
.\Apps\CliApp.ps1 -Action weekly
.\Apps\CliApp.ps1 -Action monthly

# バッチモード（非対話）
.\Apps\CliApp.ps1 -Action monthly -Batch

# ライセンス分析
.\Apps\CliApp.ps1 -Action license
```

## 🔧 設定管理

### 📄 Microsoft 365設定 (`Config/appsettings.json`)
```json
{
  "EntraID": {
    "TenantId": "your-tenant-id",
    "ClientId": "your-client-id",
    "CertificateThumbprint": "your-cert-thumbprint"
  },
  "ExchangeOnline": {
    "Organization": "your-org.onmicrosoft.com"
  }
}
```

### ⚙️ ランチャー設定 (`Config/launcher-config.json`)
```json
{
  "LauncherSettings": {
    "DefaultMode": "auto",
    "RequiredPowerShellVersion": "7.5.1",
    "EnableAutoInstall": true
  }
}
```

## 📈 レポート機能

### 📅 定期レポート（本格運用中）
- **🌅 日次**: ログイン失敗、容量監視、添付ファイル分析、認証状況
- **📆 週次**: MFA状況、外部共有、グループレビュー、権限監査
- **📊 月次**: 利用率、権限レビュー、スパム分析、ライセンス分析
- **📈 年次**: ライセンス消費、インシデント統計、コンプライアンス、総合分析

### 🔍 専門分析レポート
- **👤 Entra ID**: ユーザー監視、条件付きアクセス、MFA状況、サインインログ
- **📧 Exchange Online**: メールフロー、スパム対策、配信レポート、メールボックス監視
- **☁️ OneDrive**: ストレージ利用状況、外部共有、同期エラー
- **💬 Teams**: 利用状況分析、アプリケーション管理、外部アクセス
- **🛡️ セキュリティ**: 権限監査、脅威検知、コンプライアンス状況

### 📋 出力形式
- **🌐 HTML**: 視覚的ダッシュボード（タイムスタンプ付き）
- **📄 CSV**: データ分析・監査証跡用（UTF-8エンコーディング）
- **📊 JSON**: API連携・自動処理用（将来実装予定）

### 🏗️ 実装済み機能ステータス
✅ **完全実装・運用中（実データ対応）**:
- GUI/CLIアプリケーション（PowerShell 5.1/7.x両対応）
- 認証システム（証明書ベース・ClientSecret対応）
- 全種類レポート生成（日次/週次/月次/年次）
- Entra ID監視（ユーザー、MFA、条件付きアクセス、サインインログ）
- Exchange Online監視（メールボックス、スパム対策、メール配信、メールフロー）
- OneDrive監視（ストレージ、外部共有、同期エラー）
- ライセンス分析（実データ取得・使用状況・コスト分析）
- セキュリティ監査・権限監査（実データベース）
- コンプライアンス追跡（ISO27001/27002準拠）

🔶 **部分実装（ダミーデータ使用）**:
- Teams監視（利用状況、構成分析、外部アクセス）
  - Microsoft Teams API制限によりサンプルデータを使用
  - 基本構成情報は実データ取得可能

## 🏢 企業展開

### 📦 配布パッケージ
- **📁 ZIP形式**: 単一パッケージでの簡単展開
- **🔧 MSIインストーラー**: PowerShell 7.5.1自動セットアップ
- **📋 サイレントインストール**: 無人環境での自動配置

### 🔗 統合ツール対応
- **📱 Microsoft Intune**: MDM展開対応
- **🖥️ SCCM**: 企業内自動配布
- **🔧 Group Policy**: グループポリシー統合

## 🔍 トラブルシューティング

### 📋 一般的な問題と解決策

#### PowerShell 7.5.1が見つからない
```powershell
# 手動確認
Get-Command pwsh -ErrorAction SilentlyContinue

# 自動ダウンロード
.\Download-PowerShell751.ps1
```

#### 認証エラー
```powershell
# 認証テスト実行
.\test-auth-simple.ps1

# 設定ファイル確認
Test-Path "Config\appsettings.json"
```

#### GUI起動エラー
```powershell
# PowerShell 7確認
$PSVersionTable.PSVersion -ge [Version]"7.0.0"

# .NET Framework確認
[System.Windows.Forms.Application]::EnableVisualStyles()
```

### 📞 ログファイル確認
```powershell
# アプリケーションログ
Get-Content "Logs\cli_app.log" -Tail 20

# システムログ
Get-Content "Logs\system.log" -Tail 20

# 管理ツールログ
Get-Content "Logs\Management_$(Get-Date -Format yyyyMMdd).log" -Tail 20
```

## 📚 詳細ドキュメント

- 📖 **[GUI/CLI使用ガイド](GUI-CLI-GUIDE.md)**: 詳細な操作方法
- 🔧 **[インストールガイド](Docs/インストールガイド.md)**: セットアップ手順
- ⚙️ **[設定リファレンス](Docs/設定リファレンス.md)**: 全設定項目説明
- 🏢 **[企業展開ガイド](Docs/企業展開ガイド.md)**: 大規模展開手順
- 🔍 **[トラブルシューティング](Docs/トラブルシューティング.md)**: 問題解決集

## 🎉 新機能ハイライト

### ✨ バージョン 2.0.0（本格運用版）
- **🖼️ GUI対応**: Windows Forms ベースの直感的インターフェース
- **💻 CLI強化**: PowerShell 5.1/7.x クロスバージョン対応
- **🔄 統一ランチャー**: GUI/CLI自動選択機能
- **⚙️ PowerShell自動管理**: 7.5.1の自動インストール
- **🔗 ショートカット統合**: デスクトップ・スタートメニュー対応
- **📊 リアルタイム表示**: 処理状況の即座可視化
- **🏭 本格運用開始**: 企業環境での実稼働開始（2025年6月）
- **📈 実績データ蓄積**: 継続的なレポート生成と分析データ収集

## 📄 ライセンス

Enterprise License - 企業向け統合管理システム

## 🤝 サポート

技術サポート・機能要望については、システム管理者またはプロジェクト担当者までお問い合わせください。

---

**🚀 今すぐ開始**: `.\run_launcher.ps1` を実行してMicrosoft 365統合管理の新しい体験をお楽しみください！