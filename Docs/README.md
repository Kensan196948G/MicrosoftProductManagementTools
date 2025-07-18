# ITSM-tmux並列開発環境

## 概要
このディレクトリには、ITSM準拠IT運用システムの並列開発環境を構築するためのtmuxスクリプトと設定ファイルが含まれています。CTO、Manager、4名のDeveloperによる組織的な開発体制をtmuxで実現します。

### 特徴
- **相互連携システム**: 役割間のメッセージング、タスク依頼、技術相談機能
- **役割宣言システム**: 起動時に各役割の責任と目標を明確化
- **Claude統合**: 各役割でClaudeを`--dangerously-skip-permissions`オプションで自動起動
- **サブスクリプション自動選択**: Pro/Max(100)/Max(200)プランを事前設定
- **認証自動化**: サブスクリプション選択、URL入力、キー入力をスキップ
- **CTO主導**: 技術戦略、アーキテクチャ決定、技術統括

## ファイル構成

### ディレクトリ構造
```
tmux/
├── collaboration/          # 相互連携システム
│   ├── messaging_system.sh # メッセージングシステム
│   └── team_commands.sh    # チームコマンドシステム
├── roles/                 # 役割定義
│   └── role_definitions.json
├── scripts/
│   ├── core/             # コアスクリプト
│   │   ├── cto_strategic_command.sh
│   │   ├── cto_progress_review.sh
│   │   └── manager_coordination.sh
│   ├── roles/            # 役割別スクリプト
│   │   └── role_startup.sh
│   └── utils/            # ユーティリティ
│       ├── auto_development_loop.sh
│       ├── monitor_system.sh
│       └── generate_report.sh
├── docs/                 # ドキュメント
│   └── 相互連携システム仕様書.md
└── logs/
    └── messages/         # メッセージログ
```

### メインスクリプト
- **tmux_itsm_setup.sh** - tmuxセッション初期設定（役割宣言システム統合）
- **claude_auth_config.sh** - Claude認証自動化設定
- **claude_auto.sh** - Claude自動起動ラッパー

### 設定ファイル
- **.tmux.conf** - tmux設定ファイル
- **role_definitions.json** - 役割定義と権限設定

## クイックスタート

### 1. Claude認証設定
```bash
# Claude認証情報を設定
./claude_auth_config.sh
```

### 2. 環境セットアップ
```bash
# tmux設定ファイルをホームディレクトリにコピー
cp .tmux.conf ~/.tmux.conf

# セットアップスクリプト実行（Claude自動起動オプション付き）
./tmux_itsm_setup.sh
```

### 3. セッション接続
```bash
tmux attach-session -t MicrosoftProductTools
```

### 4. 自動開発ループ起動
```bash
# 別ターミナルまたはWindow 4で実行
./scripts/utils/auto_development_loop.sh &
```

## tmuxセッション構成

### Window構成
- **Window 0**: CTO Strategy Terminal（技術戦略決定）
  - 起動時に役割宣言と目標表示
- **Window 1**: Manager Coordination Terminal（チーム調整）
  - 起動時に役割宣言と目標表示
- **Window 2**: Developer Workspace（4分割開発環境）
  - Pane 0: Frontend Developer - 役割宣言とReact/Vue.js専門
  - Pane 1: Backend Developer - 役割宣言とNode.js/Express専門
  - Pane 2: Test/QA Developer - 役割宣言と自動テスト専門
  - Pane 3: Validation Developer - 役割宣言と手動テスト専門
- **Window 3**: System Monitoring（2分割監視）
  - Pane 0: Developer Activity Status
  - Pane 1: Integrated Development Logs
- **Window 4**: Automation Terminal（自動化実行）

## 基本操作

### Window切り替え
- `Ctrl+b` + `0-4`: 各Windowに移動

### Pane操作（Window 2）
- `Ctrl+b` + 矢印キー: Pane間移動
- `Ctrl+b` + `z`: Paneズーム切り替え

### その他の操作
- `Ctrl+b` + `d`: セッションからデタッチ
- `Ctrl+b` + `s`: セッション一覧表示
- `Ctrl+b` + `:`: コマンドモード

## 相互連携機能

### メッセージングシステム
```bash
# メッセージ送信
source ./collaboration/messaging_system.sh
send_message "CTO" "Developer" "technical" "アーキテクチャ変更について"

# ステータス更新
update_status "Frontend" "実装中" "ログイン画面のコンポーネント作成"

# タスク依頼
request_task "Manager" "Backend" "APIエンドポイントの実装" "高"
```

### チームコマンド
```bash
# チーム状況レポート
./collaboration/team_commands.sh report

# チーム同期会議
./collaboration/team_commands.sh sync

# 緊急連絡
./collaboration/team_commands.sh emergency CTO "システム障害発生"
```

## 役割別機能

### CTO機能
- 技術戦略策定と意思決定
- アーキテクチャ設計の最終承認
- 技術スタックの選定と標準化
- コード品質基準の設定
- 技術的リスク管理
- Claude統合管理

### Manager機能
- プロジェクト進捗管理
- タスクの割り振りと優先順位付け
- チーム間の調整とコミュニケーション
- リソース管理と最適化
- ステークホルダーへの報告

### Developer共通機能
- 高品質なコードの実装
- コードレビューへの参加
- 技術的課題の解決
- ドキュメント作成
- 継続的な学習と改善

## トラブルシューティング

### セッションが見つからない場合
```bash
./tmux_itsm_setup.sh
```

### 自動ループが停止した場合
```bash
ps aux | grep auto_development_loop
./scripts/utils/auto_development_loop.sh &
```

### 完全リセット
```bash
tmux kill-session -t ITSM-ITmanagementSystem
./tmux_itsm_setup.sh
```

## ログファイル
すべてのログは `~/projects/ITSM-ITmanagementSystem/logs/` に保存されます：
- `auto-loop.log` - 自動ループログ
- `integrated-dev.log` - 統合開発ログ
- `manager-actions.log` - Manager活動ログ
- `cto-decisions.log` - CTO技術決定ログ
- `cto-emergency.log` - CTO緊急技術指示ログ

## Claude設定
### 認証設定ファイル
- `~/.config/claude/subscription_config.json` - サブスクリプション情報
- `~/.config/claude/claude_env.sh` - 環境変数設定

### Claudeコマンド
すべてのClaude呼び出しは`--dangerously-skip-permissions`オプション付きで実行されます。

### 関連ドキュメント
- [Claudeサブスクリプション設定ガイド](CLAUDE_SUBSCRIPTION_GUIDE.md)
- [相互連携システム仕槕書](docs/相互連携システム仕槕書.md)
- [ITSM-tmux並列開発環境仕槕書](ITSM-tmux並列開発環境仕槕書.md)

## カスタマイズ
`.tmux.conf` を編集して、キーバインドや表示設定をカスタマイズできます。
変更後は以下のコマンドで反映：
```bash
tmux source-file ~/.tmux.conf
```