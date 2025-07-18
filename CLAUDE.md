# CLAUDE.md

このファイルは、Claude Code (claude.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。

## プロジェクト概要

ITSM（ISO/IEC 20000）、ISO/IEC 27001、ISO/IEC 27002標準に準拠したエンタープライズ向けMicrosoft 365管理ツール群です。**26機能を搭載したリッチGUI**とクロスプラットフォーム対応CLIにより、Active Directory、Entra ID、Exchange Online、OneDrive、Microsoft Teamsの自動監視、レポート生成、コンプライアンス追跡機能を提供します。

## 🆕 最新アップデート（2025年1月18日）

### Python移行開始
- 🐍 **PowerShell → Python段階的移行**: 既存26機能を維持しながらPythonで再実装
- 🎯 **完全互換性維持**: 既存UI/UX、ファイル形式、ディレクトリ構造を完全継承
- 📦 **新プロジェクト構造**: `src/`ディレクトリにPythonコード集約
- 🔄 **PowerShellブリッジ**: 移行期間中の互換性確保
- 📚 **ドキュメント整理**: 全ドキュメントをDocsフォルダに集約
- 🖥️ **tmux並列開発環境**: 5ペインによる効率的な開発環境構築

## 🆕 最新アップデート（2025年7月17日）

### GUI機能強化
- ✅ **リアルタイムログ表示**: GUIウィンドウ内にコンソール風ログパネルを追加
- ✅ **Write-GuiLog関数**: INFO/SUCCESS/WARNING/ERROR/DEBUGレベル対応
- ✅ **PowerShellプロンプト統合**: 別プロンプトを開かず同一プロンプトで継続実行
- ✅ **ウィンドウ操作**: 移動・リサイズ・最大化・最小化対応
- ✅ **UIスレッドセーフ**: Invoke()によるスレッドセーフログ更新
- ✅ **完全なダミーデータ除去**: 全ての仮想データを実データ取得に置換

### ランチャー改善
- ✅ **同一プロンプト実行**: GUI起動時に新しいPowerShellプロセスを作成しない
- ✅ **STAモード自動検出**: GUI要件の自動チェックとフォールバック
- ✅ **エラーハンドリング強化**: 包括的なエラー処理とユーザーフレンドリーなメッセージ

### ドキュメント整備
- ✅ **英語ファイル名の日本語化**: README.md → README日本語.md等
- ✅ **CLAUDE.md更新**: 最新機能と技術仕様を反映

## アーキテクチャ

### Python版アーキテクチャ（移行中）

- **src/**: Pythonソースコードディレクトリ
  - `main.py`: エントリーポイント（GUI/CLI自動判定）
  - `gui/`: PyQt6ベースのGUIアプリケーション
    - `main_window.py`: メインウィンドウ（26機能ボタン配置）
    - `components/`: GUIコンポーネント（ログビューア等）
  - `api/`: Microsoft 365 API統合
    - `graph/`: Microsoft Graph APIクライアント
    - `exchange/`: Exchange Online API（PowerShellブリッジ含む）
  - `core/`: コア機能
    - `config.py`: 設定管理（appsettings.json互換）
    - `logging_config.py`: ログ設定
  - `cli/`: CLIアプリケーション
  - `reports/`: レポート生成エンジン
  - `tests/`: テストスイート

### GUI/CLI両対応システム（PowerShell版 - 現行）

- **Apps/GuiApp_Enhanced.ps1**: 26機能搭載のWindows Forms GUI完全版（PowerShell 7.5.1対応）
  - 📊 定期レポート (5機能): 日次・週次・月次・年次・テスト実行
  - 🔍 分析レポート (5機能): ライセンス・使用状況・パフォーマンス・セキュリティ・権限監査  
  - 👥 Entra ID管理 (4機能): ユーザー一覧・MFA状況・条件付きアクセス・サインインログ
  - 📧 Exchange Online管理 (4機能): メールボックス・メールフロー・スパム対策・配信分析
  - 💬 Teams管理 (4機能): 使用状況・設定・会議品質・アプリ分析
  - 💾 OneDrive管理 (4機能): ストレージ・共有・同期エラー・外部共有分析
  - **2025/7/17更新**: リアルタイムログ表示機能（📋 Write-GuiLog）
  - **2025/7/17更新**: 移動可能・リサイズ対応GUI（FormBorderStyle = "Sizable"）
  - **2025/7/17更新**: 同一プロンプト実行（新プロセス作成なし）
  - **新機能**: リアルタイムMicrosoft 365データ取得対応
  - **新機能**: Templates/Samplesの全6フォルダ構造に完全対応
  - **新機能**: Microsoft Graph API統合・Exchange Online PowerShell統合

- **Apps/CliApp_Enhanced.ps1**: 完全版CLIアプリケーション
  - PowerShell 5.1/7.x両対応・クロスプラットフォーム対応
  - バッチモード・対話モード切替
  - 全GUI機能をコマンドラインで実行可能
  - **新機能**: 30種類以上のコマンド対応
  - **新機能**: CSV・HTML出力オプション
  - **新機能**: リアルタイムデータ取得対応

- **Apps/GuiApp.ps1**: 従来版GUI（後方互換性維持）
- **Apps/CliApp.ps1**: 従来版CLI（後方互換性維持）

- **run_launcher.ps1**: 統一ランチャー
  - PowerShell 7.5.1自動検出・インストール
  - プラットフォーム自動判定（Windows/Linux/macOS）
  - GUI/CLI/セットアップモード選択
  - **2025/7/17更新**: 同一プロンプト実行（GUI起動時の別プロセス作成を廃止）
  - **2025/7/17更新**: STAモード自動検出とフォールバック処理

### コアモジュール構成

- **Scripts/Common/**: 共通機能を提供するコアモジュール
  - `Common.psm1`: メイン初期化と設定読み込み
  - `Authentication.psm1`: 全Microsoftサービス統一認証
  - `RealM365DataProvider.psm1`: **新機能** Microsoft 365リアルデータ取得エンジン
    - Microsoft Graph API統合
    - Exchange Online PowerShell統合
    - 全ユーザー・ライセンス・使用状況・MFA状況等の実データ取得
    - Teams使用状況（ダミーデータ対応）・OneDrive・サインインログ対応
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
# GUIモードで起動（完全版が自動選択）
pwsh -File run_launcher.ps1
# → 1を選択

# または直接完全版GUI起動
pwsh -File Apps/GuiApp_Enhanced.ps1

# 従来版GUI起動（後方互換性）
pwsh -File Apps/GuiApp.ps1
```

### CLI操作
```powershell
# CLIモードで特定レポート実行（完全版が自動選択）
pwsh -File run_launcher.ps1
# → 2を選択

# または直接完全版CLI実行
pwsh -File Apps/CliApp_Enhanced.ps1 daily -OutputHTML
pwsh -File Apps/CliApp_Enhanced.ps1 users -Batch -OutputCSV -MaxResults 500
pwsh -File Apps/CliApp_Enhanced.ps1 license -OutputPath 'C:\Reports'

# 完全版CLI対話メニューモード
pwsh -File Apps/CliApp_Enhanced.ps1 menu

# 従来版CLI操作（後方互換性）
pwsh -File Apps/CliApp.ps1 -Action daily
pwsh -File Apps/CliApp.ps1 -Action weekly -Batch
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

## tmux並列開発環境

### 概要
Python移行プロジェクトでは、tmuxを使用した5ペイン並列開発環境を採用しています。これにより、複数の役割を同時に実行し、効率的な開発を実現します。

### tmux環境セットアップ
```bash
# Python移行専用tmux環境の起動
./tmux_python_setup.sh

# 既存のPowerShell開発用tmux環境
./tmux_dev_env.sh
```

### 5ペイン構成（Python移行用）
1. **Pane 0 (左上)**: アーキテクト役 - システム設計・API設計
2. **Pane 1 (左下)**: バックエンド開発者役 - API実装・データ処理
3. **Pane 2 (右上)**: フロントエンド開発者役 - GUI実装（PyQt6）
4. **Pane 3 (右中)**: テスター役 - テスト実装・品質保証
5. **Pane 4 (右下)**: DevOps役 - 環境構築・CI/CD・監視

### 相互連携システム
- **共有ファイル**: `tmux_shared_context.md` - ペイン間の情報共有
- **通信プロトコル**: 定型化されたメッセージフォーマット
- **自動同期**: 12秒間隔でのClaude同期

### 開発ワークフロー
1. アーキテクトが設計を作成
2. バックエンド/フロントエンドが並行実装
3. テスターがリアルタイムでテスト作成
4. DevOpsが環境を最適化
5. 全ペインが`tmux_shared_context.md`で進捗共有

詳細は`Docs/tmux・並列開発/`ディレクトリのドキュメントを参照してください。

## 開発時の注意事項

### Python要件（新規）
- **推奨**: Python 3.11以上
- **最小**: Python 3.9
- 必須パッケージ: PyQt6、msal、pandas、jinja2
- 仮想環境: venv推奨
- 開発環境: tmux（並列開発環境用）

### PowerShell要件（現行）
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

### Python版（移行中）
- **Python**: 3.11推奨・3.9最小サポート
- **GUI**: PyQt6（クロスプラットフォーム対応）
- **認証**: MSAL Python・証明書ベース
- **API**: Microsoft Graph SDK for Python
- **出力**: CSV（UTF8BOM）・HTML（Jinja2テンプレート）
- **テスト**: pytest・pytest-qt

### PowerShell版（現行）
- **PowerShell**: 7.5.1推奨・5.1最小サポート
- **GUI**: System.Windows.Forms（Windows専用）
- **認証**: Microsoft Graph・証明書ベース
- **出力**: CSV（UTF8BOM）・HTML（レスポンシブ）
- **ログ**: 構造化ログ・監査証跡対応
- **テスト**: 自動化テスト・統合テスト完備

両バージョンともタスクスケジューラーでの非対話型実行向けに設計されており、エンタープライズ環境での24/7運用に対応しています。