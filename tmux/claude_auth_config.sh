#!/bin/bash
# Claudeサブスクリプション設定スクリプト
# Version: 2.0
# Date: 2025-01-17

# 色定義
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Claude設定ディレクトリ
CLAUDE_CONFIG_DIR="$HOME/.config/claude"
TMUX_DIR="$(dirname "$0")"

echo -e "${BLUE}=== Claudeサブスクリプション設定 ===${NC}"

# 設定ディレクトリ作成
mkdir -p "$CLAUDE_CONFIG_DIR"

# 設定ファイルパス
SUBSCRIPTION_CONFIG_FILE="$CLAUDE_CONFIG_DIR/subscription_config.json"

# 既存の設定確認
if [ -f "$SUBSCRIPTION_CONFIG_FILE" ]; then
    echo -e "${YELLOW}既存のサブスクリプション設定が見つかりました。${NC}"
    echo -n "上書きしますか？ (y/n): "
    read -r overwrite
    if [ "$overwrite" != "y" ]; then
        echo "設定をスキップします。"
        exit 0
    fi
fi

# サブスクリプション情報の入力
echo -e "${GREEN}Claudeサブスクリプション情報を設定します${NC}"
echo "----------------------------------------"

# サブスクリプション選択
echo "利用可能なサブスクリプション:"
echo "1) Pro プラン"
echo "2) Max プラン (100)"
echo "3) Max プラン (200)"
echo -n "サブスクリプションを選択してください (1-3): "
read -r subscription_choice

case $subscription_choice in
    1) subscription_type="pro" ;;
    2) subscription_type="max-100" ;;
    3) subscription_type="max-200" ;;
    *) subscription_type="pro" ;;
esac

# プロジェクト/ワークスペース名
echo -n "プロジェクト/ワークスペース名（省略可能）: "
read -r workspace_name

# デフォルトモデル選択
echo ""
echo "デフォルトモデル:"
echo "1) Default (推奨) - Opus 4を使用制限の50%まで使用、その後Sonnet 4"
echo "2) Opus - Opus 4（複雑なタスク用・使用制限に早く到達）"
echo "3) Sonnet - Sonnet 4（日常使用）"
echo -n "モデルを選択してください (1-3) [デフォルト: 1]: "
read -r model_choice

case $model_choice in
    1|"") model_name="default" ;;
    2) model_name="opus" ;;
    3) model_name="sonnet" ;;
    *) model_name="default" ;;
esac

# 設定を作成
cat > "$SUBSCRIPTION_CONFIG_FILE" << EOF
{
  "subscription_type": "${subscription_type}",
  "workspace_name": "${workspace_name}",
  "default_model": "${model_name}",
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
EOF

# パーミッション設定（読み取り専用）
chmod 600 "$SUBSCRIPTION_CONFIG_FILE"

# 環境変数設定スクリプト作成
cat > "$CLAUDE_CONFIG_DIR/claude_env.sh" << 'EOF'
#!/bin/bash
# Claude環境変数設定

# 設定ファイル読み込み
CONFIG_FILE="$HOME/.config/claude/subscription_config.json"

if [ -f "$CONFIG_FILE" ]; then
    # JSONから値を抽出（jqがない場合の簡易パース）
    export CLAUDE_SUBSCRIPTION_TYPE=$(grep '"subscription_type"' "$CONFIG_FILE" | cut -d'"' -f4)
    export CLAUDE_WORKSPACE_NAME=$(grep '"workspace_name"' "$CONFIG_FILE" | cut -d'"' -f4)
    export CLAUDE_DEFAULT_MODEL=$(grep '"default_model"' "$CONFIG_FILE" | cut -d'"' -f4)
    export CLAUDE_SKIP_PERMISSIONS=true
    export CLAUDE_AUTO_SELECT_SUBSCRIPTION=true
fi

# Claude CLIのデフォルト設定
export CLAUDE_NO_INTERACTION=true
export CLAUDE_SKIP_URL_PROMPT=true
export CLAUDE_SKIP_KEY_PROMPT=true
EOF

chmod +x "$CLAUDE_CONFIG_DIR/claude_env.sh"

# Claude起動ラッパースクリプト作成
cat > "$TMUX_DIR/claude_auto.sh" << 'EOF'
#!/bin/bash
# Claude自動起動ラッパー

# 環境変数読み込み
if [ -f "$HOME/.config/claude/claude_env.sh" ]; then
    source "$HOME/.config/claude/claude_env.sh"
fi

# デフォルトオプション
CLAUDE_OPTIONS="--dangerously-skip-permissions"

# Claude起動
echo "Claude起動中..."
echo "オプション: $CLAUDE_OPTIONS"

# Claudeコマンドを実行
if [ $# -eq 0 ]; then
    # 引数なしの場合
    claude $CLAUDE_OPTIONS
else
    # 引数ありの場合
    claude $CLAUDE_OPTIONS "$@"
fi
EOF

chmod +x "$TMUX_DIR/claude_auto.sh"

# tmux用Claude起動関数を更新
cat > "$TMUX_DIR/tmux_claude_functions.sh" << 'EOF'
#!/bin/bash
# tmux用Claude起動関数（サブスクリプション対応）

# Claude起動関数（CTO用）
launch_claude_cto() {
    local session=$1
    local window=$2
    local prompt=$3
    
    # 環境変数読み込み
    source "$HOME/.config/claude/claude_env.sh"
    
    # Claudeコマンド構築
    local claude_cmd="claude --dangerously-skip-permissions"
    
    # サブスクリプション設定
    if [ -n "$CLAUDE_SUBSCRIPTION_TYPE" ]; then
        claude_cmd="$claude_cmd --subscription $CLAUDE_SUBSCRIPTION_TYPE"
    fi
    
    if [ -n "$CLAUDE_WORKSPACE_NAME" ]; then
        claude_cmd="$claude_cmd --workspace $CLAUDE_WORKSPACE_NAME"
    fi
    
    if [ -n "$prompt" ]; then
        claude_cmd="$claude_cmd \"$prompt\""
    fi
    
    # 環境変数設定してtmuxペインでClaude起動
    tmux send-keys -t "$session:$window" "export CLAUDE_NO_INTERACTION=true" C-m
    tmux send-keys -t "$session:$window" "$claude_cmd" C-m
}

# Claude起動関数（Developer用）
launch_claude_dev() {
    local session=$1
    local pane=$2
    local role=$3
    local prompt=$4
    
    # 環境変数読み込み
    source "$HOME/.config/claude/claude_env.sh"
    
    # 役割別プロンプト
    local role_prompt=""
    case $role in
        "frontend")
            role_prompt="Frontend Developer として React/Vue.js の実装を行います。"
            ;;
        "backend")
            role_prompt="Backend Developer として Node.js/Express/API の実装を行います。"
            ;;
        "test")
            role_prompt="Test/QA Developer として自動テストとセキュリティチェックを行います。"
            ;;
        "validation")
            role_prompt="Validation Developer として手動テストと検証を行います。"
            ;;
    esac
    
    # Claudeコマンド構築
    local claude_cmd="claude --dangerously-skip-permissions"
    
    # サブスクリプション設定
    if [ -n "$CLAUDE_SUBSCRIPTION_TYPE" ]; then
        claude_cmd="$claude_cmd --subscription $CLAUDE_SUBSCRIPTION_TYPE"
    fi
    
    if [ -n "$CLAUDE_WORKSPACE_NAME" ]; then
        claude_cmd="$claude_cmd --workspace $CLAUDE_WORKSPACE_NAME"
    fi
    
    claude_cmd="$claude_cmd \"$role_prompt $prompt\""
    
    # 環境変数設定してtmuxペインでClaude起動
    tmux send-keys -t "$session:$pane" "export CLAUDE_NO_INTERACTION=true" C-m
    tmux send-keys -t "$session:$pane" "$claude_cmd" C-m
}

# 一括Claude起動関数
launch_all_claude() {
    local session="ITSM-ITmanagementSystem"
    
    echo "全役割でClaude起動中..."
    
    # CTO
    launch_claude_cto "$session" "0" "CTOとしてプロジェクト全体の技術戦略を管理します。"
    
    # Manager
    tmux send-keys -t "$session:1" "echo 'Manager調整ターミナル準備完了'" C-m
    
    # Developers
    launch_claude_dev "$session" "2.0" "frontend" ""
    launch_claude_dev "$session" "2.1" "backend" ""
    launch_claude_dev "$session" "2.2" "test" ""
    launch_claude_dev "$session" "2.3" "validation" ""
    
    echo "全Claude起動完了"
}
EOF

chmod +x "$TMUX_DIR/tmux_claude_functions.sh"

# .bashrcに環境変数読み込みを追加
if ! grep -q "claude_env.sh" "$HOME/.bashrc"; then
    echo "" >> "$HOME/.bashrc"
    echo "# Claudeサブスクリプション設定" >> "$HOME/.bashrc"
    echo "[ -f \"\$HOME/.config/claude/claude_env.sh\" ] && source \"\$HOME/.config/claude/claude_env.sh\"" >> "$HOME/.bashrc"
fi

echo -e "${GREEN}✅ Claudeサブスクリプション設定完了！${NC}"
echo ""
echo -e "${YELLOW}設定内容:${NC}"
echo "- サブスクリプション: $subscription_type"
echo "- ワークスペース: ${workspace_name:-未設定}"
echo "- デフォルトモデル: $model_name"
echo ""
echo -e "${YELLOW}使用方法:${NC}"
echo "1. 単独起動: ./claude_auto.sh"
echo "2. tmux統合: source tmux_claude_functions.sh && launch_all_claude"
echo ""
echo -e "${BLUE}設定ファイル:${NC}"
echo "- サブスクリプション設定: $SUBSCRIPTION_CONFIG_FILE"
echo "- 環境変数: $CLAUDE_CONFIG_DIR/claude_env.sh"
echo ""
echo -e "${GREEN}Claude起動時の動作:${NC}"
echo "- サブスクリプション自動選択"
echo "- URL入力スキップ"
echo "- 認証キー入力スキップ"
echo "- --dangerously-skip-permissions 自動付与"