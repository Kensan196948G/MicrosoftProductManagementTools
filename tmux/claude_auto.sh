#!/bin/bash
# Claude実行起動スクリプト

# 環境変数読み込み
if [ -f "$HOME/.config/claude/claude_env.sh" ]; then
    source "$HOME/.config/claude/claude_env.sh"
fi

# デフォルトオプション
CLAUDE_OPTIONS="--dangerously-skip-permissions"

# Claude起動ログ
echo "Claude起動中..."
echo "オプション: $CLAUDE_OPTIONS"

# 初期プロンプトメッセージ作成
INITIAL_PROMPT=""
if [ $# -gt 0 ]; then
    INITIAL_PROMPT="$1"
fi

# Claudeを実際に起動（対話モード）
if [ -n "$INITIAL_PROMPT" ]; then
    echo "初期指示: $INITIAL_PROMPT"
    echo "🚀 Claudeセッション開始..."
    
    # 作業ディレクトリをルートに変更
    cd "/mnt/e/MicrosoftProductManagementTools"
    
    # 初期プロンプトをファイルに保存
    echo "$INITIAL_PROMPT" > /tmp/claude_init_prompt_$$.txt
    
    # Claudeを起動して初期プロンプトを送信
    (echo "$INITIAL_PROMPT"; cat) | claude $CLAUDE_OPTIONS
    
else
    echo "⚠️ 初期プロンプトが指定されていません"
    # 作業ディレクトリをルートに変更
    cd "/mnt/e/MicrosoftProductManagementTools"
    # プロンプトなしでもClaude起動
    claude $CLAUDE_OPTIONS
fi

# 役割宣言をログに記録
if [ -n "$INITIAL_PROMPT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Claude起動: $INITIAL_PROMPT" >> "/tmp/claude_startup.log"
fi
