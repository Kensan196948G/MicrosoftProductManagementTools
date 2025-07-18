#!/bin/bash
# Claude自動起動スクリプト（初期プロンプト付き）
# Version: 2.0
# Date: 2025-07-17

# 環境変数読み込み
if [ -f "$HOME/.config/claude/claude_env.sh" ]; then
    source "$HOME/.config/claude/claude_env.sh"
fi

# デフォルトオプション
CLAUDE_OPTIONS="--dangerously-skip-permissions"

# 初期プロンプトメッセージ
INITIAL_PROMPT=""
if [ $# -gt 0 ]; then
    INITIAL_PROMPT="$1"
fi

# Claude起動ログ
echo "Claude起動中..."
echo "オプション: $CLAUDE_OPTIONS"

# 作業ディレクトリをルートに変更
cd "/mnt/e/MicrosoftProductManagementTools"

# Claudeを起動
echo "🚀 Claudeセッション開始..."
claude $CLAUDE_OPTIONS &

# Claudeが起動するまで少し待つ
sleep 2

# 初期プロンプトがある場合は送信
if [ -n "$INITIAL_PROMPT" ]; then
    echo "初期指示を送信中: $INITIAL_PROMPT"
    
    # 現在のペインに初期プロンプトを送信
    tmux send-keys -t $TMUX_PANE "$INITIAL_PROMPT" C-m
    
    # ログに記録
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Claude起動: $INITIAL_PROMPT" >> "/tmp/claude_startup.log"
fi

# プロセスを待機
wait