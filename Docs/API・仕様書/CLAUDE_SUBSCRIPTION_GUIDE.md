# Claude サブスクリプション設定ガイド

## 概要
このガイドでは、tmux並列開発環境でClaudeを自動起動するためのサブスクリプション設定について説明します。CTO、Manager、Developer の各役割で Claude を統合し、技術的な意思決定と開発作業を支援します。

## サブスクリプションプラン

### 利用可能なプラン
1. **Pro プラン**
   - 標準的な使用に適したプラン
   - コマンド: `--subscription pro`

2. **Max プラン (100)**
   - 100メッセージ/日の制限
   - コマンド: `--subscription max --limit 100`

3. **Max プラン (200)**
   - 200メッセージ/日の制限
   - コマンド: `--subscription max --limit 200`

### モデル選択
1. **Default (推奨)**
   - Opus 4を使用制限の50%まで使用、その後Sonnet 4に自動切替
   - バランスの取れた使用に最適
   - コマンド: `--model default`

2. **Opus**
   - Opus 4を専用使用（複雑なタスク向け）
   - 使用制限に早く到達する可能性あり
   - コマンド: `--model opus`

3. **Sonnet**
   - Sonnet 4を専用使用（日常的なタスク向け）
   - 使用制限を効率的に活用
   - コマンド: `--model sonnet`

## 設定手順

### 1. 初期設定
```bash
# サブスクリプション設定スクリプトを実行
./claude_auth_config.sh
```

設定項目:
- サブスクリプションプラン選択 (1-3)
- ワークスペース名（省略可能）
- デフォルトモデル選択
  - Default（推奨）: Opus 4/Sonnet 4自動切替
  - Opus: Opus 4専用
  - Sonnet: Sonnet 4専用

### 2. 設定確認
```bash
# 設定内容を確認
cat ~/.config/claude/subscription_config.json
```

### 3. 環境変数
自動的に設定される環境変数:
- `CLAUDE_SUBSCRIPTION_TYPE`: pro/max-100/max-200
- `CLAUDE_WORKSPACE_NAME`: ワークスペース名
- `CLAUDE_DEFAULT_MODEL`: default/opus/sonnet
- `CLAUDE_NO_INTERACTION`: true（非対話モード）
- `CLAUDE_SKIP_URL_PROMPT`: true
- `CLAUDE_SKIP_KEY_PROMPT`: true

## 自動化される動作

Claude起動時に以下が自動化されます:
1. **サブスクリプション選択画面**: 事前設定されたプランを自動選択
2. **URL入力画面**: スキップ
3. **認証キー入力画面**: スキップ
4. **権限確認**: `--dangerously-skip-permissions`で自動スキップ

## tmuxでの使用

### 個別起動
```bash
# CTO Windowで起動
tmux send-keys -t ITSM-ITmanagementSystem:0 "./claude_auto.sh" C-m

# Developer Paneで起動
tmux send-keys -t ITSM-ITmanagementSystem:2.0 "./claude_auto.sh 'Frontend開発タスク'" C-m
```

### 一括起動
```bash
# tmux_claude_functions.shを読み込んで全役割で起動
source tmux_claude_functions.sh
launch_all_claude
```

### 役割別起動
```bash
# CTOとして起動
./scripts/roles/role_startup.sh CTO

# Developerとして起動（専門分野指定）
./scripts/roles/role_startup.sh Developer frontend
./scripts/roles/role_startup.sh Developer backend
./scripts/roles/role_startup.sh Developer test
./scripts/roles/role_startup.sh Developer validation
```

## トラブルシューティング

### サブスクリプションが認識されない場合
1. 環境変数を確認
   ```bash
   echo $CLAUDE_SUBSCRIPTION_TYPE
   ```

2. 設定ファイルを再作成
   ```bash
   ./claude_auth_config.sh
   ```

### Claudeが対話モードになる場合
環境変数を明示的に設定:
```bash
export CLAUDE_NO_INTERACTION=true
export CLAUDE_SKIP_URL_PROMPT=true
export CLAUDE_SKIP_KEY_PROMPT=true
```

## 設定ファイル

### ~/.config/claude/subscription_config.json
```json
{
  "subscription_type": "pro",
  "workspace_name": "ITSM-Project",
  "default_model": "default",
  "auto_auth": true,
  "skip_permissions": true,
  "default_options": [
    "--dangerously-skip-permissions"
  ],
  "preferences": {
    "auto_select_subscription": true,
    "skip_url_prompt": true,
    "skip_key_prompt": true
  }
}
```

## 相互連携システムでの使用

### Claudeを使った技術相談
```bash
# CTOからDeveloperへの技術相談
./collaboration/team_commands.sh consult CTO Developer "Claudeでアーキテクチャ設計を検討"

# Developer間の相談
./collaboration/team_commands.sh consult Frontend Backend "API設計についてClaudeで相談"
```

### ステータス更新
```bash
# Claude作業状況の共有
source ./collaboration/messaging_system.sh
update_status "CTO" "Claudeで技術戦略検討中" "マイクロサービスアーキテクチャの設計"
```

## 注意事項
- サブスクリプションの使用制限に注意してください
- Maxプランの場合、日次メッセージ数の制限があります
- 設定ファイルは安全に保管してください（パーミッション600）
- 役割間のコミュニケーションでClaudeの出力を共有することを推奨します