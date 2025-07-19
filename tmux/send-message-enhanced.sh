#!/bin/bash

# 🚀 Enhanced Message Sending with Reliability Improvements

# メッセージ送信前のペイン状態確認
check_pane_responsiveness() {
    local target="$1"
    local timeout=5
    
    echo "🔍 ペイン応答性確認中: $target"
    
    # ペイン情報取得
    local pane_info=$(tmux display-message -t "$target" -p "#{pane_pid}:#{pane_current_command}" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        echo "❌ ペイン情報取得失敗"
        return 1
    fi
    
    local pid=$(echo "$pane_info" | cut -d: -f1)
    local command=$(echo "$pane_info" | cut -d: -f2)
    
    echo "📊 ペイン状態: PID=$pid, Command=$command"
    
    # Claudeまたはbashプロンプトの場合は送信可能
    if [[ "$command" =~ ^(bash|claude|zsh|sh)$ ]]; then
        echo "✅ ペイン送信可能状態"
        return 0
    else
        echo "⚠️ ペイン使用中: $command"
        return 1
    fi
}

# 再試行機能付きメッセージ送信
send_message_with_retry() {
    local target="$1"
    local message="$2"
    local agent_name="$3"
    local max_retries=3
    local retry_delay=2
    
    for ((i=1; i<=max_retries; i++)); do
        echo "📤 送信試行 $i/$max_retries: $agent_name"
        
        # ペイン応答性確認
        if ! check_pane_responsiveness "$target"; then
            if [[ $i -lt $max_retries ]]; then
                echo "⏳ $retry_delay 秒後に再試行..."
                sleep $retry_delay
                continue
            else
                echo "❌ 最大試行回数到達: ペイン応答なし"
                return 1
            fi
        fi
        
        # 実際の送信実行
        if send_enhanced_message_core "$target" "$message" "$agent_name"; then
            echo "✅ 送信成功: 試行 $i/$max_retries"
            return 0
        else
            if [[ $i -lt $max_retries ]]; then
                echo "⏳ $retry_delay 秒後に再試行..."
                sleep $retry_delay
            else
                echo "❌ 送信失敗: 最大試行回数到達"
                return 1
            fi
        fi
    done
}

# コア送信ロジック（元のsend_enhanced_message）
send_enhanced_message_core() {
    local target="$1"
    local message="$2" 
    local agent_name="$3"
    
    # プロンプトクリア（より確実に）
    tmux send-keys -t "$target" C-c 2>/dev/null
    sleep 0.5  # 増加: より確実なクリア
    
    tmux send-keys -t "$target" C-u 2>/dev/null
    sleep 0.3  # 増加: 入力行クリア確実化
    
    # メッセージ送信
    if [[ "$message" == *$'\n'* ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            tmux send-keys -t "$target" "$line"
            tmux send-keys -t "$target" C-m
            sleep 0.3  # 増加: 行間隔確保
        done <<< "$message"
    else
        tmux send-keys -t "$target" "$message"
        sleep 0.4  # 増加: 入力完了待ち
        tmux send-keys -t "$target" C-m
    fi
    
    sleep 0.8  # 増加: 実行完了待ち
    
    return 0
}

# 使用例
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "🧪 Enhanced Message Sending Test"
    
    if [[ $# -lt 2 ]]; then
        echo "使用方法: $0 <target> <message> [agent_name]"
        echo "例: $0 'session:0.2' 'テストメッセージ' 'dev0'"
        exit 1
    fi
    
    target="$1"
    message="$2"
    agent_name="${3:-Unknown}"
    
    send_message_with_retry "$target" "$message" "$agent_name"
fi