#!/bin/bash
# チーム相互連携コマンドシステム
# Version: 1.0
# Date: 2025-01-17

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 設定
SESSION_NAME="ITSM-ITmanagementSystem"
TMUX_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
MESSAGE_SYSTEM="$TMUX_DIR/collaboration/messaging_system.sh"

# メッセージングシステムを読み込み
source "$MESSAGE_SYSTEM"

# 使用方法表示
show_usage() {
    echo -e "${CYAN}=== チーム相互連携コマンド ===${NC}"
    echo ""
    echo "使用方法: team <command> [options]"
    echo ""
    echo "コマンド:"
    echo "  status <role>                    - ステータス更新"
    echo "  request <from> <to> <task>       - タスク依頼"
    echo "  consult <from> <to> <topic>      - 技術相談"
    echo "  emergency <from> <message>       - 緊急連絡"
    echo "  report                           - チーム状況レポート"
    echo "  sync                             - チーム同期会議"
    echo ""
    echo "役割: CTO, Manager, Developer, Frontend, Backend, Test, Validation, All"
}

# ステータス更新
cmd_status() {
    local role=$1
    echo -e "${YELLOW}ステータスを入力してください:${NC}"
    read -r status
    echo -e "${YELLOW}詳細を入力してください:${NC}"
    read -r details
    
    update_status "$role" "$status" "$details"
    echo -e "${GREEN}✅ ステータスを更新しました${NC}"
}

# タスク依頼
cmd_request() {
    local from=$1
    local to=$2
    local task=$3
    
    if [ -z "$task" ]; then
        echo -e "${YELLOW}タスク内容を入力してください:${NC}"
        read -r task
    fi
    
    echo -e "${YELLOW}優先度を選択 (1:最高, 2:高, 3:中, 4:低):${NC}"
    read -r priority_num
    
    case $priority_num in
        1) priority="最高" ;;
        2) priority="高" ;;
        3) priority="中" ;;
        4) priority="低" ;;
        *) priority="中" ;;
    esac
    
    request_task "$from" "$to" "$task" "$priority"
    echo -e "${GREEN}✅ タスクを依頼しました${NC}"
}

# 技術相談
cmd_consult() {
    local from=$1
    local to=$2
    local topic=$3
    
    if [ -z "$topic" ]; then
        echo -e "${YELLOW}相談内容を入力してください:${NC}"
        read -r topic
    fi
    
    technical_consultation "$from" "$to" "$topic"
    echo -e "${GREEN}✅ 技術相談を送信しました${NC}"
}

# 緊急連絡
cmd_emergency() {
    local from=$1
    local message=$2
    
    if [ -z "$message" ]; then
        echo -e "${RED}緊急メッセージを入力してください:${NC}"
        read -r message
    fi
    
    emergency_notification "$from" "$message"
    echo -e "${GREEN}✅ 緊急連絡を送信しました${NC}"
}

# チーム状況レポート
cmd_report() {
    echo -e "${CYAN}=== チーム状況レポート ===${NC}"
    echo -e "${BLUE}生成時刻: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""
    
    # 各役割の最新ステータスを表示
    echo -e "${YELLOW}=== 最新ステータス ===${NC}"
    
    # CTOステータス
    echo -e "${GREEN}CTO:${NC}"
    if [ -f "$HOME/projects/ITSM-ITmanagementSystem/logs/messages/cto_received.log" ]; then
        grep "status" "$HOME/projects/ITSM-ITmanagementSystem/logs/messages/cto_received.log" | tail -1
    fi
    
    # Managerステータス
    echo -e "${GREEN}Manager:${NC}"
    if [ -f "$HOME/projects/ITSM-ITmanagementSystem/logs/messages/manager_received.log" ]; then
        grep "status" "$HOME/projects/ITSM-ITmanagementSystem/logs/messages/manager_received.log" | tail -1
    fi
    
    # Developer ステータス
    echo -e "${GREEN}Developers:${NC}"
    for dev in frontend backend test validation; do
        if [ -f "$HOME/projects/ITSM-ITmanagementSystem/logs/messages/${dev}_received.log" ]; then
            echo "  $dev:"
            grep "status" "$HOME/projects/ITSM-ITmanagementSystem/logs/messages/${dev}_received.log" | tail -1
        fi
    done
    
    echo ""
    echo -e "${YELLOW}=== 最近のメッセージ ===${NC}"
    if [ -f "$HOME/projects/ITSM-ITmanagementSystem/logs/messages/all_messages.log" ]; then
        tail -10 "$HOME/projects/ITSM-ITmanagementSystem/logs/messages/all_messages.log"
    fi
}

# チーム同期会議
cmd_sync() {
    echo -e "${CYAN}=== チーム同期会議開始 ===${NC}"
    
    # 全員に同期会議開始を通知
    send_message "System" "All" "coordination" "📅 チーム同期会議を開始します"
    
    echo -e "${YELLOW}議題を入力してください (終了は 'done'):${NC}"
    
    while true; do
        echo -n "> "
        read -r agenda_item
        
        if [ "$agenda_item" = "done" ]; then
            break
        fi
        
        if [ -n "$agenda_item" ]; then
            send_message "System" "All" "coordination" "議題: $agenda_item"
        fi
    done
    
    send_message "System" "All" "coordination" "📅 チーム同期会議を終了します"
    echo -e "${GREEN}✅ 同期会議を終了しました${NC}"
}

# メイン処理
case "${1:-help}" in
    status)
        shift
        cmd_status "$@"
        ;;
    request)
        shift
        cmd_request "$@"
        ;;
    consult)
        shift
        cmd_consult "$@"
        ;;
    emergency)
        shift
        cmd_emergency "$@"
        ;;
    report)
        cmd_report
        ;;
    sync)
        cmd_sync
        ;;
    help|*)
        show_usage
        ;;
esac