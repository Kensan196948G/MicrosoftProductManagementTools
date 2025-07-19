# 🏢 CTO相互連携キーワード完全ガイド

## 📋 概要

このドキュメントは、CTOプロンプト内で使用可能な相互連携キーワードの完全ガイドです。
Microsoft 365 Python移行プロジェクトにおける効率的なチーム連携を実現するための
具体的なコマンドとキーワードを体系的にまとめています。

---

## 📡 Manager連携指示キーワード

### 🎯 技術戦略指示系

- `./tmux/send-message.sh manager "【技術戦略決定】"`
  - システム全体の技術方針を決定・伝達
  - アーキテクチャの基本設計指示

- `./tmux/send-message.sh manager "【アーキテクチャ承認】"`
  - システム設計の最終承認
  - 技術選定の確定指示

- `./tmux/send-message.sh manager "【技術方針変更】"`
  - 進行中プロジェクトの技術方針修正
  - 新技術導入の指示

- `./tmux/send-message.sh manager "【技術要件確定】"`
  - 機能要件・非機能要件の確定
  - 性能・セキュリティ基準の設定

- `./tmux/send-message.sh manager "【技術スタック決定】"`
  - フレームワーク・ライブラリの選定指示
  - 開発環境・本番環境の技術構成決定

- `./tmux/send-message.sh manager "【システム仕様承認】"`
  - 詳細設計の承認
  - インターフェース仕様の確定

### 🚀 プロジェクト管理系

- `./tmux/send-message.sh manager "【ITプロジェクト開始指示】"`
  - 新規プロジェクトの正式開始宣言
  - チーム編成・役割分担の指示

- `./tmux/send-message.sh manager "【開発フェーズ移行指示】"`
  - 設計フェーズから実装フェーズへの移行
  - 開発ステージの切り替え指示

- `./tmux/send-message.sh manager "【マイルストーン設定】"`
  - 重要な中間目標の設定
  - 進捗管理ポイントの明確化

- `./tmux/send-message.sh manager "【品質基準設定】"`
  - コード品質・テストカバレッジ基準
  - レビュー・承認プロセスの設定

- `./tmux/send-message.sh manager "【セキュリティ要件指示】"`
  - セキュリティ実装基準の設定
  - 脆弱性対策・監査要件の指示

- `./tmux/send-message.sh manager "【パフォーマンス要件指示】"`
  - 応答時間・スループット基準
  - 負荷テスト・最適化要件の設定

### 🚨 緊急対応系

- `./tmux/send-message.sh manager "【緊急技術指示】"`
  - 重要技術課題の即座対応指示
  - 技術的緊急事態への対処指示

- `./tmux/send-message.sh manager "【緊急システム停止】"`
  - システムの緊急停止・メンテナンス指示
  - 障害対応・復旧作業の指示

- `./tmux/send-message.sh manager "【緊急セキュリティ対応】"`
  - セキュリティインシデント対応
  - 脆弱性の緊急修正指示

- `./tmux/send-message.sh manager "【緊急品質改善】"`
  - 品質問題の即座修正指示
  - 重大バグの緊急対応

- `./tmux/send-message.sh manager "【緊急アーキテクチャ変更】"`
  - システム設計の緊急変更
  - 技術的制約による設計修正

---

## 🚀 全体指示キーワード（CTO-directive系）

### 🔄 技術移行プロジェクト

- `./tmux/send-message.sh cto-directive "PowerShell → Python完全移行開始"`
  - レガシーシステムからの移行開始
  - 26機能システムの段階的Python化

- `./tmux/send-message.sh cto-directive "Microsoft 365統合システム実装"`
  - Microsoft Graph API統合実装
  - Azure Key Vault認証システム構築

- `./tmux/send-message.sh cto-directive "エンタープライズアーキテクチャ刷新"`
  - 企業全体のシステム基盤刷新
  - マイクロサービス化・コンテナ化

- `./tmux/send-message.sh cto-directive "レガシーシステム段階的廃止"`
  - 旧システムの計画的廃止
  - データ移行・運用移管

### 🏗️ 技術基盤強化

- `./tmux/send-message.sh cto-directive "CI/CD パイプライン完全自動化"`
  - GitHub Actions完全自動化
  - デプロイ・テスト自動化基盤構築

- `./tmux/send-message.sh cto-directive "Kubernetes本番環境移行"`
  - コンテナオーケストレーション導入
  - 本番環境のクラウドネイティブ化

- `./tmux/send-message.sh cto-directive "セキュリティ監査対応完全実装"`
  - ISO27001/27002準拠実装
  - セキュリティ自動監視システム構築

- `./tmux/send-message.sh cto-directive "API統合・マイクロサービス化"`
  - RESTful API設計・実装
  - サービス間連携基盤構築

### 📊 品質・性能向上

- `./tmux/send-message.sh cto-directive "コード品質基準100%達成"`
  - 静的解析・コードレビュー自動化
  - 品質ゲート・承認プロセス強化

- `./tmux/send-message.sh cto-directive "自動テストカバレッジ90%以上"`
  - 単体テスト・統合テスト完全自動化
  - E2Eテスト・負荷テスト基盤構築

- `./tmux/send-message.sh cto-directive "パフォーマンス最適化実装"`
  - データベースクエリ最適化
  - キャッシュ・CDN活用最適化

- `./tmux/send-message.sh cto-directive "ユーザビリティ改善完全実装"`
  - UI/UX レスポンシブ対応
  - アクセシビリティWCAG 2.1準拠

---

## 🔍 報告収集・監視キーワード

### 📈 進捗確認系

- `./tmux/send-message.sh collect-reports`
  - 全開発者からの進捗報告自動収集
  - 統合進捗レポート生成

- `./tmux/send-message.sh manager "【進捗状況緊急確認】"`
  - プロジェクト進捗の緊急確認
  - 遅延・ブロッカーの特定

- `./tmux/send-message.sh manager "【実装完了状況報告要求】"`
  - 機能実装の完了状況確認
  - 成果物の品質評価

- `./tmux/send-message.sh manager "【技術課題報告収集】"`
  - 技術的問題・課題の収集
  - 解決策・リソース要求の把握

- `./tmux/send-message.sh manager "【品質監査報告要求】"`
  - コード品質・テスト結果の確認
  - セキュリティ・パフォーマンス監査

### 🔍 技術評価系

- `./tmux/send-message.sh manager "【技術実装評価実施】"`
  - 実装技術の適切性評価
  - 技術的負債・改善点の特定

- `./tmux/send-message.sh manager "【アーキテクチャレビュー実施】"`
  - システム設計の技術レビュー
  - 設計原則・パターンの妥当性確認

- `./tmux/send-message.sh manager "【セキュリティ監査実施】"`
  - セキュリティ実装の監査
  - 脆弱性診断・対策確認

- `./tmux/send-message.sh manager "【パフォーマンステスト実施】"`
  - 性能要件の達成度確認
  - ボトルネック・最適化ポイント特定

---

## ⚡ 即時伝達系キーワード

### 🚨 緊急技術対応

- `./tmux/send-message.sh instant-broadcast "【緊急】システム全停止"`
  - 重大障害発生時の緊急停止指示
  - 全チームへの即座通知（0.5秒で送信完了）

- `./tmux/send-message.sh instant-broadcast "【緊急】セキュリティ侵害対応"`
  - セキュリティインシデント発生時
  - 緊急セキュリティ対策の即座実行

- `./tmux/send-message.sh instant-broadcast "【緊急】データ整合性確認"`
  - データ破損・不整合の緊急確認
  - バックアップ・復旧準備の即座開始

- `./tmux/send-message.sh instant-broadcast "【緊急】本番環境ロールバック"`
  - 本番環境での重大問題発生時
  - 前バージョンへの緊急切り戻し

### 📢 重要発表系

- `./tmux/send-message.sh instant-broadcast "【重要】技術方針大幅変更"`
  - プロジェクト方針の重要変更
  - 全チームへの即座周知

- `./tmux/send-message.sh instant-broadcast "【重要】新技術スタック採用"`
  - 新技術・フレームワーク採用決定
  - 学習・移行計画の即座開始

- `./tmux/send-message.sh instant-broadcast "【重要】開発体制変更"`
  - チーム編成・役割変更の発表
  - 新体制での作業開始指示

---

## 🛠️ 専門分野別技術指示キーワード

### 💻 Frontend技術指示

- `./tmux/send-message.sh frontend "React + TypeScript 最新移行"`
  - PowerShell GUIからReact移行
  - TypeScript型安全性の完全実装

- `./tmux/send-message.sh frontend "UI/UX レスポンシブ完全対応"`
  - マルチデバイス対応実装
  - レスポンシブデザイン最適化

- `./tmux/send-message.sh frontend "Progressive Web App実装"`
  - PWA機能の実装
  - オフライン対応・プッシュ通知

- `./tmux/send-message.sh frontend "Accessibility WCAG 2.1準拠"`
  - アクセシビリティ完全対応
  - 障害者支援技術への対応

### ⚙️ Backend技術指示

- `./tmux/send-message.sh backend "FastAPI + PostgreSQL統合"`
  - PowerShellスクリプトからFastAPI移行
  - データベース統合・最適化

- `./tmux/send-message.sh backend "RESTful API設計・実装"`
  - API設計原則の適用
  - OpenAPI仕様書の完全実装

- `./tmux/send-message.sh backend "認証・認可システム構築"`
  - JWT・OAuth 2.0実装
  - ロールベースアクセス制御

- `./tmux/send-message.sh backend "データベース最適化実装"`
  - クエリパフォーマンス最適化
  - インデックス・パーティション設計

### 🔒 QA・テスト技術指示

- `./tmux/send-message.sh qa "pytest自動テスト完全構築"`
  - PowerShellテストからpytest移行
  - 自動テスト基盤の完全構築

- `./tmux/send-message.sh qa "E2Eテスト・負荷テスト実装"`
  - エンドツーエンドテスト自動化
  - 性能・負荷テストの実装

- `./tmux/send-message.sh qa "セキュリティテスト自動化"`
  - 脆弱性診断の自動化
  - セキュリティCI/CDパイプライン

- `./tmux/send-message.sh qa "品質監視ダッシュボード構築"`
  - リアルタイム品質監視
  - 品質メトリクス可視化

### 🧪 インフラ・DevOps技術指示

- `./tmux/send-message.sh infra "Docker + Kubernetes完全移行"`
  - コンテナ化・オーケストレーション
  - 本番環境のクラウドネイティブ化

- `./tmux/send-message.sh infra "CI/CD GitHub Actions自動化"`
  - 完全自動化パイプライン構築
  - デプロイ・テスト自動化

- `./tmux/send-message.sh infra "監視・ログ集約システム構築"`
  - システム監視の完全自動化
  - ログ分析・アラート基盤

- `./tmux/send-message.sh infra "バックアップ・災害復旧システム"`
  - データ保護・復旧戦略実装
  - 事業継続性の確保

---

## 📊 Context7統合技術情報取得キーワード

### 🔍 最新技術情報取得

- `"FastAPI SQLAlchemy 最新実装パターン"`
  - 最新のORM実装パターン取得
  - パフォーマンス最適化手法

- `"React TypeScript 最新構成"`
  - React 18 + TypeScript最新構成
  - モダンフロントエンド開発手法

- `"PostgreSQL パフォーマンス最適化"`
  - データベースチューニング手法
  - クエリ最適化ベストプラクティス

- `"Kubernetes本番運用ベストプラクティス"`
  - 本番環境運用のベストプラクティス
  - セキュリティ・監視・スケーリング

- `"Docker セキュリティ強化設定"`
  - コンテナセキュリティ最新手法
  - 脆弱性対策・最小権限原則

- `"GitHub Actions CI/CD最新パターン"`
  - CI/CDパイプライン最新パターン
  - 自動化・最適化手法

### 🔄 Python移行専門情報

- `"PowerShell Python移行戦略"`
  - PowerShellからPythonへの移行戦略
  - 段階的移行・互換性確保手法

- `"Microsoft Graph API Python統合"`
  - Microsoft 365 API統合手法
  - 認証・データ取得最適化

- `"Windows Forms PyQt6移行"`
  - GUIアプリケーション移行手法
  - UI/UXの移行戦略

- `"PowerShell CSV Python pandas移行"`
  - データ処理ロジックの移行
  - pandas活用・最適化手法

---

## 🔄 システム制御キーワード

### 🛠️ 環境制御系

- `./tmux/send-message.sh reset-all-prompts`
  - 全ペイン（Manager/CTO/Dev0-2）のプロンプトリセット
  - Claude Codeの完全初期化

- `./tmux/send-message.sh reset-prompt manager`
  - 特定ペインのプロンプトリセット
  - 個別問題解決・環境初期化

- `./tmux/send-message.sh --status`
  - 現在のチーム状況・プロジェクト状況確認
  - 全体の稼働状況把握

- `./tmux/send-message.sh --detect`
  - tmux環境・ペイン構成の自動検出
  - 通信システムの健全性確認

### 🔗 統合管理系

- `./tmux/send-message.sh context7-integration`
  - Context7統合機能のテスト
  - 最新技術情報取得システムの確認

- `./tmux/send-message.sh manager-report`
  - Manager統合報告作成指示
  - プロジェクト全体レポート生成

- `./tmux/send-message.sh send-to-cto "技術実装完了報告"`
  - CTOへの直接報告送信
  - 重要な技術的完了・課題報告

---

## 💡 実践的使用例テンプレート

### 🚀 新プロジェクト開始時

```bash
./tmux/send-message.sh manager "【ITプロジェクト開始指示】
プロジェクト名：Microsoft 365 Python統合システム
システム種別：エンタープライズWebアプリ + API

技術要件：
- 対象ユーザー：1000名以上の企業ユーザー
- パフォーマンス要求：レスポンス時間2秒以内
- セキュリティレベル：ISO27001準拠・証明書ベース認証
- スケーラビリティ：同時接続500ユーザー対応

推奨技術スタック：
- フロントエンド：React 18 + TypeScript + Tailwind CSS
- バックエンド：Python 3.12 + FastAPI + PostgreSQL 15
- 認証：Azure Key Vault + Microsoft Graph API
- インフラ：Docker + Kubernetes + Azure Cloud
- CI/CD：GitHub Actions + 自動テスト + 自動デプロイ

開発手法：アジャイル開発 + DevOps + 継続的品質改善
期限：3ヶ月以内完全実装・本番運用開始"
```

### 🚨 緊急対応時

```bash
./tmux/send-message.sh instant-broadcast "【緊急】重大なセキュリティ脆弱性が発見されました。
- 全システムの緊急点検を開始してください
- 外部アクセスを一時制限してください  
- セキュリティパッチの緊急適用準備をしてください
- 30分以内に初期対応報告をしてください"
```

### 📊 進捗確認時

```bash
./tmux/send-message.sh collect-reports

./tmux/send-message.sh manager "【週次進捗確認】
以下の項目について詳細な進捗報告を収集してください：
- Frontend: React移行進捗率・完成機能一覧
- Backend: FastAPI実装進捗・API完成状況  
- QA: テスト実装進捗・発見済み課題一覧
- 全体: 技術的課題・リソース要求・次週計画"
```

---

## 📝 重要な注意事項

### ⚠️ 自動即時伝達について

以下のキーワードが含まれるメッセージは自動的に即時伝達モード（73%高速化）で送信されます：

- `緊急指示`, `緊急連絡`, `緊急事態`, `緊急対応`
- `緊急停止`, `緊急会議`, `緊急報告`, `緊急確認`
- `即座`, `即時`, `直ちに`, `至急`
- `URGENT`, `EMERGENCY`, `CRITICAL`
- `【緊急】`, `【URGENT】`, `【至急】`, `【即時】`
- `🚨`, `⚡`, `🔥`

### 🎯 効果的な使用のポイント

1. **明確な指示**: 具体的な技術要件・期限を含める
2. **適切な緊急度**: 真に緊急な場合のみ緊急キーワードを使用
3. **完結性**: 一つのメッセージで必要な情報を完全に伝達
4. **追跡可能性**: 重要な指示は報告・確認を要求する
5. **技術精度**: 正確な技術用語・フレームワーク名を使用

---

## 📚 関連ドキュメント

- `/tmux/Docs/collaboration/5pane_integration_guide.md` - 5ペイン統合開発ガイド
- `/tmux/Docs/collaboration/communication_flow_diagram.md` - 通信フロー図解
- `/tmux/Docs/collaboration/tmux_config_summary.md` - tmux設定サマリー

---

**このガイドを活用することで、CTOとしてチーム全体を効率的に指揮し、
高品質なMicrosoft 365 Python移行プロジェクトを成功に導くことができます。**