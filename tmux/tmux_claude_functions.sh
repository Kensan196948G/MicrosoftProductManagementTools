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
    local session="MicrosoftProductTools"
    
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
