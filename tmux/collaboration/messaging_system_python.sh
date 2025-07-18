#!/bin/bash
# Python移行プロジェクト専用メッセージングシステム（5ペイン構成対応版）
# Version: 1.0
# Date: 2025-01-18

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Python移行プロジェクト専用設定
SESSION_NAME="MicrosoftProductTools-Python"
MESSAGE_LOG_DIR="/mnt/e/MicrosoftProductManagementTools/logs/messages"
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

# ペイン番号マッピング（Python移行プロジェクト用）
get_pane_number() {
    local role=$1
    case $role in
        "Manager"|"manager") echo "0" ;;
        "CTO"|"cto") echo "1" ;;
        "Dev0"|"dev0"|"Python") echo "2" ;;
        "Dev1"|"dev1"|"Test") echo "3" ;;
        "Dev2"|"dev2"|"Compat") echo "4" ;;
        "Developer"|"developer") echo "2,3,4" ;;  # 全Developer
        "All"|"all") echo "0,1,2,3,4" ;;  # 全員
        *) echo "$role" ;;  # 数字の場合はそのまま返す
    esac
}

# ロール名の正規化
normalize_role() {
    local role=$1
    case $role in
        "Manager"|"manager"|"0") echo "Manager" ;;
        "CTO"|"cto"|"1") echo "CTO" ;;
        "Dev0"|"dev0"|"Python"|"2") echo "Dev0" ;;
        "Dev1"|"dev1"|"Test"|"3") echo "Dev1" ;;
        "Dev2"|"dev2"|"Compat"|"4") echo "Dev2" ;;
        *) echo "$role" ;;
    esac
}

# メッセージ送信関数
send_message() {
    local from=$1
    local to=$2
    local msg_type=$3
    local message=$4
    
    if [ $# -lt 4 ]; then
        echo "使用方法: send_message <送信元> <送信先> <タイプ> <メッセージ>"
        echo "タイプ: emergency, technical, coordination, general, status"
        return 1
    fi
    
    local color=$(get_message_color "$msg_type")
    local timestamp=$(date '+%H:%M:%S')
    local from_normalized=$(normalize_role "$from")
    local pane_numbers=$(get_pane_number "$to")
    
    # メッセージフォーマット
    local formatted_message="${color}[$timestamp] 📨 ${from_normalized} → ${to}: ${message}${NC}"
    
    # ペイン番号を分割して各ペインに送信
    IFS=',' read -ra PANES <<< "$pane_numbers"
    for pane in "${PANES[@]}"; do
        if tmux list-panes -t "$SESSION_NAME:0" | grep -q "^$pane:"; then
            tmux send-keys -t "$SESSION_NAME:0.$pane" "echo '$formatted_message'" C-m
        fi
    done
    
    # ログ記録
    echo "[$timestamp] $from_normalized → $to ($msg_type): $message" >> "$MESSAGE_LOG_DIR/all_messages.log"
    echo "[$timestamp] → $to ($msg_type): $message" >> "$MESSAGE_LOG_DIR/${from_normalized}_sent.log"
}

# ステータス更新関数
update_status() {
    local role=$1
    local status=$2
    local details=$3
    
    if [ $# -lt 2 ]; then
        echo "使用方法: update_status <役割> <ステータス> [詳細]"
        return 1
    fi
    
    local message="🔄 ステータス: $status"
    if [ -n "$details" ]; then
        message="$message - $details"
    fi
    
    send_message "$role" "All" "status" "$message"
}

# 緊急通知関数
emergency_notification() {
    local from=$1
    local message=$2
    
    if [ $# -lt 2 ]; then
        echo "使用方法: emergency_notification <送信元> <メッセージ>"
        return 1
    fi
    
    send_message "$from" "All" "emergency" "🚨 緊急: $message"
}

# 技術相談関数
technical_consultation() {
    local from=$1
    local to=$2
    local topic=$3
    
    if [ $# -lt 3 ]; then
        echo "使用方法: technical_consultation <送信元> <送信先> <相談内容>"
        return 1
    fi
    
    send_message "$from" "$to" "technical" "🔧 技術相談: $topic"
}

# 簡単なエイリアス（Pythonプロジェクト用）
python_status() {
    update_status "Dev0" "$1" "$2"
}

test_status() {
    update_status "Dev1" "$1" "$2"
}

compat_status() {
    update_status "Dev2" "$1" "$2"
}

# チーム同期関数
team_sync() {
    local timestamp=$(date '+%H:%M:%S')
    echo -e "${CYAN}=== チーム同期 ($timestamp) ===${NC}"
    send_message "Manager" "All" "coordination" "チーム同期を実施します。各自の現在状況を報告してください"
    
    # 5秒待機して状況確認を促す
    sleep 2
    echo -e "${YELLOW}各ペインでの状況報告をお待ちしています...${NC}"
}

# 使用方法表示
show_usage() {
    echo -e "${CYAN}=== Python移行プロジェクト メッセージングシステム ===${NC}"
    echo ""
    echo "基本コマンド:"
    echo "  send_message <送信元> <送信先> <タイプ> <メッセージ>"
    echo "  update_status <役割> <ステータス> [詳細]"
    echo "  emergency_notification <送信元> <メッセージ>"
    echo "  technical_consultation <送信元> <送信先> <相談内容>"
    echo ""
    echo "役割名:"
    echo "  Manager (Pane 0) - 進捗管理・タスク調整"
    echo "  CTO (Pane 1) - 戦略決定・技術承認"
    echo "  Dev0 (Pane 2) - Python GUI/API開発"
    echo "  Dev1 (Pane 3) - テスト/品質保証"
    echo "  Dev2 (Pane 4) - PowerShell互換性"
    echo ""
    echo "簡単エイリアス:"
    echo "  python_status <状況> [詳細] - Dev0のステータス更新"
    echo "  test_status <状況> [詳細] - Dev1のステータス更新"
    echo "  compat_status <状況> [詳細] - Dev2のステータス更新"
    echo "  team_sync - チーム全体同期"
    echo ""
    echo "例:"
    echo '  send_message "CTO" "Manager" "coordination" "Phase 1を開始してください"'
    echo '  send_message "Manager" "Dev0" "coordination" "PyQt6環境構築を開始"'
    echo '  python_status "PyQt6環境構築中" "MainWindow実装完了"'
    echo '  technical_consultation "Dev0" "CTO" "PyQt6でのスレッド処理について"'
}

# 初期化メッセージ
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_usage
else
    echo -e "${GREEN}Python移行プロジェクト メッセージングシステム初期化完了${NC}"
    echo -e "${YELLOW}セッション: $SESSION_NAME${NC}"
    echo -e "${YELLOW}使用方法: show_usage または --help${NC}"
fi