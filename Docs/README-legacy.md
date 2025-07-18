# 🚀 Microsoft 365統合管理ツール (GUI/CLI両対応版)

**Windows 11 + PowerShell 7.5.1対応・26機能搭載GUI・エンタープライズ向け統合管理システム**

[![PowerShell](https://img.shields.io/badge/PowerShell-7.5.1%2B-blue)](https://github.com/PowerShell/PowerShell)
[![GUI](https://img.shields.io/badge/GUI-26%20Functions-green)](https://docs.microsoft.com/dotnet/desktop/winforms/)
[![CLI](https://img.shields.io/badge/CLI-Cross%20Compatible-orange)](https://docs.microsoft.com/powershell/)
[![License](https://img.shields.io/badge/License-Enterprise-green)](LICENSE)
[![ITSM](https://img.shields.io/badge/ITSM-ISO%2020000-orange)](https://www.iso.org/iso-20000-it-service-management.html)
[![Security](https://img.shields.io/badge/Security-ISO%2027001%2F27002-red)](https://www.iso.org/isoiec-27001-information-security.html)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)](https://github.com)

## 📋 概要

ITSM（ISO/IEC 20000）、ISO/IEC 27001、ISO/IEC 27002標準に準拠したエンタープライズ向けMicrosoft 365管理ツール群です。**26機能を搭載した直感的なGUI**と強力なCLIにより、Active Directory、Entra ID、Exchange Online、OneDrive、Microsoft Teamsの自動監視、レポート生成、コンプライアンス追跡を効率的に実行できます。

**本プロジェクトは現在本格運用中で、日次・週次・月次・年次の自動レポート生成システムが稼働しています。**

## ✨ 主な特徴

### 🎮 26機能搭載のリッチGUI
- **📊 定期レポート (5機能)**: 日次・週次・月次・年次・テスト実行
- **🔍 分析レポート (5機能)**: ライセンス・使用状況・パフォーマンス・セキュリティ・権限監査
- **👥 Entra ID管理 (4機能)**: ユーザー一覧・MFA状況・条件付きアクセス・サインインログ
- **📧 Exchange Online管理 (4機能)**: メールボックス・メールフロー・スパム対策・配信分析
- **💬 Teams管理 (4機能)**: 使用状況・設定・会議品質・アプリ分析
- **💾 OneDrive管理 (4機能)**: ストレージ・共有・同期エラー・外部共有分析

### 🎯 最新のユーザーエクスペリエンス（2025/7/17大幅更新）
- **🖼️ 直感的なセクション分け**: 機能別カテゴリで分かりやすい操作
- **📋 リアルタイムログ表示**: GUI内でコンソール風ログをリアルタイム表示
- **🪟 完全なウィンドウ操作**: 移動・リサイズ・最大化・最小化対応
- **🔄 同一プロンプト実行**: 新しいPowerShellプロセスを作成せず継続実行
- **⚡ UIスレッドセーフ**: Invoke()による安全なログ更新機能
- **📱 リアルタイム表示**: 処理進行状況・ステータス・ログの即座更新
- **🎨 視覚的フィードバック**: セクション別絵文字・色分けログ・プログレスバー
- **📂 自動ファイル表示**: CSV/HTML両形式での結果出力と自動オープン
- **💬 ポップアップ通知**: 処理完了時の詳細な結果表示

### 🌐 PowerShell 7.5.1完全対応
- **🚀 最新機能**: PowerShell 7.5.1の型キャスト改善に対応
- **🤖 自動環境判別**: 実行環境に応じた最適処理
- **🛡️ 安全なフォールバック**: バージョン非対応時の代替機能
- **⚙️ 自動セットアップ**: PowerShell 7未インストール時の自動導入

### 📊 包括的監視・分析機能
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
- **📄 CSV出力**: データ分析・外部システム連携用
- **📁 自動整理**: Reports配下に機能別ディレクトリで出力

## 🚀 クイックスタート

### 1. 起動方法

```powershell
# 管理者権限でPowerShellを開いて実行
pwsh -File run_launcher.ps1
```

ランチャーが自動で以下を実行します：
- PowerShell 7.5.1の有無確認と自動インストール
- 実行環境の判定（Windows/Linux/macOS）
- GUI/CLIモードの選択メニュー表示

### 2. GUI操作

1. ランチャーで「1. GUI モード (推奨)」を選択
2. GUIが起動し、26個の機能ボタンが表示されます
3. 使用したい機能のボタンをクリック
4. CSV/HTMLファイルが自動生成・表示されます
5. ポップアップで処理結果を確認

### 3. CLI操作

```powershell
# CLIモードで特定レポート実行
pwsh -File Apps/CliApp.ps1 -Action daily

# バッチモードで自動実行
pwsh -File Apps/CliApp.ps1 -Action weekly -Batch
```

## 📁 プロジェクト構造

```
MicrosoftProductManagementTools/
├── 📱 Apps/                    # メインアプリケーション
│   ├── GuiApp.ps1             # GUI版（26機能搭載）
│   └── CliApp.ps1             # CLI版（クロスプラットフォーム）
├── 📜 Scripts/                # 機能別スクリプト群
│   ├── Common/                # 共通モジュール
│   ├── AD/                    # Active Directory管理
│   ├── EntraID/              # Entra ID管理
│   ├── EXO/                  # Exchange Online管理
│   └── UI/                   # ユーザーインターフェース
├── 📊 Reports/               # レポート出力先
│   ├── Daily/                # 日次レポート
│   ├── Weekly/               # 週次レポート
│   ├── Monthly/              # 月次レポート
│   ├── Yearly/               # 年次レポート
│   ├── Analysis/             # 分析レポート
│   ├── EntraID/              # Entra ID関連
│   ├── Exchange/             # Exchange関連
│   ├── Teams/                # Teams関連
│   └── OneDrive/             # OneDrive関連
├── ⚙️ Config/                # 設定ファイル
├── 📚 Docs/                  # ドキュメント
├── 🔧 TestScripts/          # テスト・検証用
├── 📋 Logs/                 # システムログ
└── 📦 Archive/              # アーカイブ
```

## 🎯 GUI機能一覧

### 📊 定期レポート
| 機能 | 説明 | 出力先 |
|------|------|--------|
| 日次レポート | ログイン状況・容量監視 | Reports/Daily/ |
| 週次レポート | MFA状況・セキュリティ | Reports/Weekly/ |
| 月次レポート | 利用率・コスト分析 | Reports/Monthly/ |
| 年次レポート | 総合統計・コンプライアンス | Reports/Yearly/ |
| テスト実行 | 動作確認・サンプルデータ | Reports/ |

### 🔍 分析レポート
| 機能 | 説明 | 出力先 |
|------|------|--------|
| ライセンス分析 | 使用状況・コスト最適化 | Analysis/License/ |
| 使用状況分析 | サービス別利用統計 | Analysis/Usage/ |
| パフォーマンス監視 | システム性能・レスポンス | Analysis/Performance/ |
| セキュリティ分析 | 脅威検出・リスク評価 | General/ |
| 権限監査 | アクセス権限・コンプライアンス | General/ |

### 👥 Entra ID管理
| 機能 | 説明 | 出力先 |
|------|------|--------|
| ユーザー一覧 | 全ユーザー情報・ステータス | Reports/EntraID/Users/ |
| MFA状況 | 多要素認証設定・普及率 | Reports/EntraID/Users/ |
| 条件付きアクセス | アクセス制御・セキュリティ | General/ |
| サインインログ | ログイン分析・異常検出 | General/ |

### 📧 Exchange Online管理
| 機能 | 説明 | 出力先 |
|------|------|--------|
| メールボックス分析 | 容量・使用状況・設定 | Reports/Exchange/Mailbox/ |
| メールフロー分析 | 配信状況・ルール・遅延 | Reports/Exchange/Mailbox/ |
| スパム対策分析 | フィルタリング・検出状況 | General/ |
| メール配信分析 | 成功率・エラー・配信時間 | Reports/Exchange/Mailbox/ |

### 💬 Teams管理
| 機能 | 説明 | 出力先 |
|------|------|--------|
| Teams使用状況 | 利用統計・アクティビティ | Reports/Teams/Usage/ |
| Teams設定分析 | ポリシー・制限・設定状況 | Reports/Teams/Usage/ |
| 会議品質分析 | 音声・映像品質・接続状況 | Analysis/Performance/ |
| Teamsアプリ分析 | アプリ使用状況・普及率 | Analysis/Usage/ |

### 💾 OneDrive管理
| 機能 | 説明 | 出力先 |
|------|------|--------|
| ストレージ分析 | 容量・使用率・トレンド | Reports/OneDrive/Storage/ |
| 共有分析 | 内部共有・権限・アクセス | General/ |
| 同期エラー分析 | 同期問題・解決状況 | Reports/OneDrive/Storage/ |
| 外部共有分析 | 外部共有・セキュリティリスク | General/ |

## ⚙️ 設定・カスタマイズ

### 認証設定
```json
{
  "Authentication": {
    "TenantId": "your-tenant-id",
    "ClientId": "your-client-id",
    "CertificateThumbprint": "certificate-thumbprint"
  }
}
```

### レポート設定
```json
{
  "Reports": {
    "AutoOpenFiles": true,
    "ShowPopupNotifications": true,
    "OutputFormats": ["CSV", "HTML"],
    "RetentionDays": 90
  }
}
```

## 🛠️ システム要件

- **OS**: Windows 10/11 (GUI), Linux/macOS (CLI)
- **PowerShell**: 7.5.1推奨（自動インストール対応）
- **メモリ**: 4GB以上推奨
- **ディスク**: 2GB以上の空き容量
- **ネットワーク**: Microsoft 365への接続

## 📚 ドキュメント

- [📖 操作手順書](Docs/Microsoft365統合管理ツール操作手順書.md)
- [🔧 インストールガイド](Docs/インストールガイド.md)
- [⚙️ 設定リファレンス](Docs/設定リファレンス.md)
- [🚨 トラブルシューティング](Docs/トラブルシューティング.md)
- [🏢 企業展開ガイド](Docs/企業展開ガイド.md)
- [🔄 PowerShell 7移行ガイド](Docs/PowerShell7-Migration-Guide.md)

## 🚀 最新アップデート

### v2.0 (2025年7月版) - 🆕 2025/7/17 大幅アップデート
- ✅ **26機能搭載GUI**: セクション別整理による使いやすさ向上
- ✅ **PowerShell 7.5.1完全対応**: 型キャスト問題解決
- ✅ **完全なダミーデータ除去**: 全ての機能で実際のMicrosoft 365データを取得
- ✅ **改良されたHTML出力**: レスポンシブデザイン・列幅最適化
- ✅ **自動ファイル管理**: 機能別ディレクトリでの整理保存
- ✅ **ポップアップ通知強化**: 詳細な処理結果表示

#### 🆕 2025/7/17 新機能
- ✅ **リアルタイムログ表示**: GUIウィンドウ内にコンソール風ログパネル
- ✅ **Write-GuiLog関数**: INFO/SUCCESS/WARNING/ERROR/DEBUGレベル対応
- ✅ **同一プロンプト実行**: 新しいPowerShellプロセスを作成せず継続実行
- ✅ **ウィンドウ操作拡張**: 移動・リサイズ・最大化・最小化対応
- ✅ **UIスレッドセーフ機能**: Invoke()による安全なログ更新
- ✅ **ドキュメント日本語化**: README.md → README日本語.md等

### v1.x からの主な改善点
- GUIボタン数: 9個 → 26個
- セクション分け: なし → 6カテゴリ
- HTML表示: 基本テーブル → レスポンシブデザイン
- ファイル管理: 単一フォルダ → 機能別ディレクトリ
- エラーハンドリング: 基本 → 詳細なデバッグ情報

## 🤝 サポート・貢献

- **Issue報告**: [GitHub Issues](https://github.com/your-org/microsoft365-tools/issues)
- **機能要求**: [Feature Requests](https://github.com/your-org/microsoft365-tools/discussions)
- **コミュニティ**: [Discussions](https://github.com/your-org/microsoft365-tools/discussions)

## 📄 ライセンス

このプロジェクトはエンタープライズライセンスの下で公開されています。詳細は[LICENSE](LICENSE)ファイルをご覧ください。

## 🏷️ タグ

`microsoft365` `powershell` `gui` `cli` `enterprise` `itsm` `iso27001` `automation` `reporting` `azure` `exchange` `teams` `onedrive` `entra-id`

---

**🚀 Microsoft 365統合管理ツール - エンタープライズ向け統合管理システム**