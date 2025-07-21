#!/bin/bash

# Team Session Attachment Script
# Claude認証保持対応の安全な接続スクリプト

# 動的パス解決と統一記法
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
ATTACH_LOG="$LOG_DIR/attach.log"

# ログ関数
log_attach() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    mkdir -p "$LOG_DIR"
    echo "[$timestamp] [ATTACH-$level] $message" >> "$ATTACH_LOG"
    echo "[ATTACH-$level] $message"
}

# セッション状態確認
check_session_status() {
    if ! tmux has-session -t team 2>/dev/null; then
        echo "❌ team セッションが見つかりません"
        echo "💡 先にシステムを起動してください: $SCRIPT_DIR/start-ai-team.sh"
        log_attach "ERROR" "Team session not found"
        return 1
    fi
    
    # ペイン数確認
    local pane_count=$(tmux list-panes -t team | wc -l)
    if [[ $pane_count -lt 4 ]]; then
        echo "⚠️ ペイン数が不十分です ($pane_count ペイン)"
        log_attach "WARNING" "Insufficient panes: $pane_count"
    else
        echo "✅ セッション確認: $pane_count ペインで構成"
        log_attach "SUCCESS" "Session verified: $pane_count panes"
    fi
    
    return 0
}

# セッション状態確認実行
if ! check_session_status; then
    exit 1
fi

# Claude認証状態確認
echo "🔐 Claude認証状態確認中..."
log_attach "INFO" "Checking Claude authentication status"

if [[ -f "$SCRIPT_DIR/claude-session-manager.sh" ]]; then
    "$SCRIPT_DIR/claude-session-manager.sh" check > /dev/null 2>&1
    log_attach "SUCCESS" "Claude session manager check completed"
else
    echo "⚠️ claude-session-manager.sh が見つかりません"
    log_attach "WARNING" "claude-session-manager.sh not found"
fi

# 認証状態の復元試行
if [[ -f "$SCRIPT_DIR/claude-session-manager.sh" ]]; then
    echo "🔄 認証状態復元中..."
    "$SCRIPT_DIR/claude-session-manager.sh" restore > /dev/null 2>&1
    log_attach "INFO" "Authentication restore attempted"
fi

echo "🔗 team セッションに接続中..."
log_attach "INFO" "Attaching to team session"

# 接続後のフック設定
trap 'log_attach "INFO" "Session detached"' EXIT

tmux attach-session -t team