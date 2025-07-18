#!/bin/bash
# 相互連携メッセージングシステム（5ペイン構成対応版）
# Version: 3.0
# Date: 2025-07-17

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 設定
SESSION_NAME="MicrosoftProductTools"
MESSAGE_LOG_DIR="$HOME/projects/MicrosoftProductTools/logs/messages"
mkdir -p "$MESSAGE_LOG_DIR"

# メッセージタイプごとの色
get_message_color() {
    local msg_type=$1
    case $msg_type in
        "emergency") echo "$RED" ;;
        "technical") echo "$CYAN" ;;
        "coordination") echo "$YELLOW" ;;
        "general") echo "$GREEN" ;;
        "status") echo "$BLUE" ;;
        *) echo "$NC" ;;
    esac
}

# メッセージ送信関数
send_message() {
    local from=$1
    local to=$2
    local msg_type=$3
    local message=$4
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=$(get_message_color "$msg_type")
    
    # メッセージフォーマット
    local formatted_msg="${color}[${timestamp}] [${msg_type^^}] ${from} → ${to}: ${message}${NC}"
    
    # ログに記録
    echo "[${timestamp}] [${msg_type}] ${from} → ${to}: ${message}" >> "$MESSAGE_LOG_DIR/all_messages.log"
    echo "[${timestamp}] [${msg_type}] ${from} → ${to}: ${message}" >> "$MESSAGE_LOG_DIR/${from,,}_sent.log"
    echo "[${timestamp}] [${msg_type}] ${from} → ${to}: ${message}" >> "$MESSAGE_LOG_DIR/${to,,}_received.log"
    
    # 送信先を特定して送信（5ペイン構成対応）
    # ペイン配置: 0=Manager, 1=Dev0, 2=CTO, 3=Dev1, 4=Dev2
    case $to in
        "CTO")
            tmux send-keys -t $SESSION_NAME:0.2 "echo -e '$formatted_msg'" C-m
            ;;
        "Manager")
            tmux send-keys -t $SESSION_NAME:0.0 "echo -e '$formatted_msg'" C-m
            ;;
        "Developer"|"Dev0"|"Dev1"|"Dev2"|"Frontend"|"Backend"|"Test")
            # 全Developer または特定のDeveloperに送信
            if [ "$to" = "Developer" ]; then
                # Dev0, Dev1, Dev2に送信
                tmux send-keys -t $SESSION_NAME:0.1 "echo -e '$formatted_msg'" C-m
                tmux send-keys -t $SESSION_NAME:0.3 "echo -e '$formatted_msg'" C-m
                tmux send-keys -t $SESSION_NAME:0.4 "echo -e '$formatted_msg'" C-m
            else
                case $to in
                    "Dev0"|"Frontend") pane=1 ;;
                    "Dev1"|"Backend") pane=3 ;;
                    "Dev2"|"Test") pane=4 ;;
                esac
                tmux send-keys -t $SESSION_NAME:0.$pane "echo -e '$formatted_msg'" C-m
            fi
            ;;
        "All")
            # 全員に送信（5ペイン全て）
            for pane in 0 1 2 3 4; do
                tmux send-keys -t $SESSION_NAME:0.$pane "echo -e '$formatted_msg'" C-m
            done
            ;;
    esac
}

# ステータス更新関数
update_status() {
    local role=$1
    local status=$2
    local details=$3
    
    send_message "$role" "All" "status" "ステータス更新: $status - $details"
}

# タスク依頼関数
request_task() {
    local from=$1
    local to=$2
    local task=$3
    local priority=$4
    
    send_message "$from" "$to" "coordination" "タスク依頼 [優先度: $priority]: $task"
}

# 技術相談関数
technical_consultation() {
    local from=$1
    local to=$2
    local topic=$3
    
    send_message "$from" "$to" "technical" "技術相談: $topic"
}

# 緊急連絡関数
emergency_notification() {
    local from=$1
    local message=$2
    
    send_message "$from" "All" "emergency" "🚨 緊急: $message"
}

# エクスポート関数
export -f send_message
export -f update_status
export -f request_task
export -f technical_consultation
export -f emergency_notification
export -f get_message_color

# スタンドアロン実行時の処理
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo -e "${CYAN}=== 相互連携メッセージングシステム ===${NC}"
    echo "使用方法:"
    echo "  source messaging_system.sh"
    echo ""
    echo "関数:"
    echo "  send_message <from> <to> <type> <message>"
    echo "  update_status <role> <status> <details>"
    echo "  request_task <from> <to> <task> <priority>"
    echo "  technical_consultation <from> <to> <topic>"
    echo "  emergency_notification <from> <message>"
    echo ""
    echo "メッセージタイプ: emergency, technical, coordination, general, status"
    echo "送信先: CTO, Manager, Developer, Dev0, Dev1, Dev2, Frontend, Backend, Test, All"
fi