# CLAUDE.md

このファイルは、Claude Code (claude.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。

## プロジェクト概要

ITSM（ISO/IEC 20000）、ISO/IEC 27001、ISO/IEC 27002標準に準拠したエンタープライズ向けMicrosoft 365管理ツール群です。**26機能を搭載したリッチGUI**とクロスプラットフォーム対応CLIにより、Active Directory、Entra ID、Exchange Online、OneDrive、Microsoft Teamsの自動監視、レポート生成、コンプライアンス追跡機能を提供します。

## アーキテクチャ

### GUI/CLI両対応システム

- **Apps/GuiApp.ps1**: 26機能搭載のWindows Forms GUI（PowerShell 7.5.1対応）
  - 📊 定期レポート (5機能): 日次・週次・月次・年次・テスト実行
  - 🔍 分析レポート (5機能): ライセンス・使用状況・パフォーマンス・セキュリティ・権限監査
  - 👥 Entra ID管理 (4機能): ユーザー一覧・MFA状況・条件付きアクセス・サインインログ
  - 📧 Exchange Online管理 (4機能): メールボックス・メールフロー・スパム対策・配信分析
  - 💬 Teams管理 (4機能): 使用状況・設定・会議品質・アプリ分析
  - 💾 OneDrive管理 (4機能): ストレージ・共有・同期エラー・外部共有分析

- **Apps/CliApp.ps1**: クロスプラットフォーム対応CLIアプリケーション
  - PowerShell 5.1/7.x両対応
  - バッチモード・対話モード切替
  - 全GUI機能をコマンドラインで実行可能

- **run_launcher.ps1**: 統一ランチャー
  - PowerShell 7.5.1自動検出・インストール
  - プラットフォーム自動判定（Windows/Linux/macOS）
  - GUI/CLI/セットアップモード選択

### コアモジュール構成

- **Scripts/Common/**: 共通機能を提供するコアモジュール
  - `Common.psm1`: メイン初期化と設定読み込み
  - `Authentication.psm1`: 全Microsoftサービス統一認証
  - `Logging.psm1`: 監査証跡対応の集中ログ機能
  - `ErrorHandling.psm1`: 標準化されたエラーハンドリングと再試行ロジック
  - `ReportGenerator.psm1`: HTMLおよびCSVレポート生成
  - `ScheduledReports.ps1`: 日次/週次/月次/年次レポートのオーケストレーション
  - `PowerShellVersionManager.psm1`: PowerShell 7.5.1バージョン管理

- **Scripts/AD/**: Active Directory管理スクリプト
- **Scripts/EXO/**: Exchange Online監視・分析
- **Scripts/EntraID/**: Entra ID、Teams、OneDrive管理

- **TestScripts/**: 開発・テスト用スクリプト群
  - `test-auth.ps1`: 基本認証テスト
  - `test-all-features.ps1`: 全機能統合テスト
  - `test-graph-features.ps1`: Microsoft Graph機能テスト

## 設定

全設定は`Config/appsettings.json`で一元管理されています。主要セクション：
- 認証資格情報と証明書
- レポート閾値とスケジューリング
- コンプライアンスとセキュリティ設定
- パフォーマンスと再試行設定
- GUI表示オプション（ポップアップ・自動ファイル表示）

## 主要コマンド

### 統一ランチャー実行
```powershell
# 管理者権限でPowerShellを開いて実行
pwsh -File run_launcher.ps1

# 選択メニューが表示されます:
# 1. GUI モード (推奨) - 26機能搭載のWindows Forms GUI
# 2. CLI モード - コマンドライン操作
# 3. 初期セットアップ（初回のみ）
# 4. 認証テスト
# 5. 終了
```

### GUI操作（推奨）
```powershell
# GUIモードで起動
pwsh -File run_launcher.ps1
# → 1を選択

# または直接GUI起動
pwsh -File Apps/GuiApp.ps1
```

### CLI操作
```powershell
# CLIモードで特定レポート実行
pwsh -File Apps/CliApp.ps1 -Action daily

# バッチモードで自動実行
pwsh -File Apps/CliApp.ps1 -Action weekly -Batch

# 対話メニューモード
pwsh -File Apps/CliApp.ps1 -Action menu
```

### 認証設定
認証は非対話型実行のために証明書ベースまたはクライアントシークレット方式を使用します。スクリプト実行前に`Config/appsettings.json`で資格情報を設定してください。

### テスト実行
```powershell
# 基本認証テスト
TestScripts\test-auth.ps1

# 全機能統合テスト
TestScripts\test-all-features.ps1

# Microsoft Graph機能テスト
TestScripts\test-graph-features.ps1
```

## レポート構造

生成されるレポートは`Reports/`ディレクトリに機能別・頻度別に保存されます：

### 定期レポート
- `Reports/Daily/`: 日次ログイン状況・容量監視・アクティビティ
- `Reports/Weekly/`: 週次MFA状況・外部共有・グループレビュー
- `Reports/Monthly/`: 月次利用率・権限レビュー・コスト分析
- `Reports/Yearly/`: 年次ライセンス消費・インシデント統計・コンプライアンス

### 機能別レポート
- `Analysis/License/`: ライセンス分析・コスト最適化
- `Analysis/Usage/`: サービス別使用状況・普及率分析
- `Analysis/Performance/`: パフォーマンス監視・会議品質
- `Reports/EntraID/`: Entra IDユーザー・MFA・アクセス制御
- `Reports/Exchange/`: Exchange メールボックス・フロー・配信
- `Reports/Teams/`: Teams利用状況・設定・アプリ分析
- `Reports/OneDrive/`: OneDriveストレージ・共有・同期

全レポートはコンプライアンス要件のためにHTML（ダッシュボード）とCSV（監査証跡）の両形式で生成され、自動的にファイルが開かれます。

## GUI機能詳細

### セクション構成
1. **📊 定期レポート**: 日次・週次・月次・年次・テスト実行
2. **🔍 分析レポート**: ライセンス・使用状況・パフォーマンス・セキュリティ・権限監査
3. **👥 Entra ID管理**: ユーザー一覧・MFA状況・条件付きアクセス・サインインログ
4. **📧 Exchange Online管理**: メールボックス・メールフロー・スパム対策・配信分析
5. **💬 Teams管理**: 使用状況・設定・会議品質・アプリ分析
6. **💾 OneDrive管理**: ストレージ・共有・同期エラー・外部共有分析

### ユーザーエクスペリエンス
- ボタンクリック → ダミーデータ生成 → CSV/HTML出力 → 自動ファイル表示 → ポップアップ通知
- セクション別色分け・絵文字による直感的な操作
- スクロール対応で大量機能でも使いやすいUI
- リアルタイムステータス表示

## エラーハンドリング

システムは以下を実装しています：
- PowerShell 7.5.1型キャスト問題の解決
- 自動再試行ロジック（最大7回）
- `Logs/`ディレクトリへの包括的ログ記録
- 一時的障害の自己修復機能
- 1年間保持の監査証跡維持
- プラットフォーム別フォールバック処理

## 開発時の注意事項

### PowerShell要件
- **推奨**: PowerShell 7.5.1以上（完全機能）
- **最小**: PowerShell 5.1（基本機能・制限あり）
- 必須モジュール: ExchangeOnlineManagement、Microsoft.Graph
- 実行ポリシー: RemoteSignedまたはBypass

### GUI開発時の注意
- Windows環境専用（Windows Forms使用）
- `[System.Windows.Forms.Application]::Run([System.Windows.Forms.Form]$form)` の型キャスト必須
- エラーハンドリングは try-catch とメッセージボックス併用
- ダミーデータはNew-DummyData関数で一元管理

### CLI開発時の注意
- クロスプラットフォーム対応（Windows/Linux/macOS）
- PowerShell 5.1/7.x両対応
- バッチモード・対話モード切替対応
- ログ出力は Write-CliLog 関数使用

### ファイル出力
- CSV: UTF8BOM エンコーディング
- HTML: レスポンシブデザイン・日本語フォント対応
- 機能別ディレクトリ自動作成
- タイムスタンプ付きファイル名

## 主要技術仕様

- **PowerShell**: 7.5.1推奨・5.1最小サポート
- **GUI**: System.Windows.Forms（Windows専用）
- **認証**: Microsoft Graph・証明書ベース
- **出力**: CSV（UTF8BOM）・HTML（レスポンシブ）
- **ログ**: 構造化ログ・監査証跡対応
- **テスト**: 自動化テスト・統合テスト完備

スクリプトはタスクスケジューラーでの非対話型実行向けに設計されており、エンタープライズ環境での24/7運用に対応しています。