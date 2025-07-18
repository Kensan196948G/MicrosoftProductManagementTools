#!/bin/bash

# Microsoft Product Management Tools - Quick Connect
# Fast session connection and status check

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_PREFIX="MicrosoftProductTools-Python"

# Color codes for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions with colors
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Show session status
show_session_status() {
    log_info "Microsoft Product Management Tools セッション状況"
    echo "=================================================="
    echo ""
    
    local sessions=$(tmux list-sessions 2>/dev/null | grep -E "$SESSION_PREFIX" || true)
    
    if [ -z "$sessions" ]; then
        log_warning "アクティブなセッションが見つかりません"
        echo ""
        echo "📋 利用可能なオプション:"
        echo "1. 新しいセッションを作成: ./python_project_launcher.sh"
        echo "2. 5人構成で即座起動: ./python_project_launcher.sh (メニューで4を選択)"
        echo ""
        return 1
    fi
    
    log_success "アクティブなセッションが見つかりました:"
    echo ""
    
    echo "$sessions" | while read -r session_line; do
        local session_name=$(echo "$session_line" | cut -d: -f1)
        local session_info=$(echo "$session_line" | cut -d: -f2-)
        
        # Get pane count and titles
        local pane_count=$(tmux list-panes -t "$session_name" 2>/dev/null | wc -l)
        
        echo "🚀 セッション: $session_name"
        echo "   📊 ペイン数: $pane_count"
        echo "   📋 状態: $session_info"
        
        # Show pane titles if available
        if tmux list-panes -t "$session_name" -F "#{pane_title}" 2>/dev/null | grep -q -v "^$"; then
            echo "   👥 役職構成:"
            tmux list-panes -t "$session_name" -F "      #{pane_index}: #{pane_title}" 2>/dev/null
        fi
        
        echo ""
    done
    
    return 0
}

# Quick connect to session
quick_connect() {
    local sessions=$(tmux list-sessions 2>/dev/null | grep -E "$SESSION_PREFIX" | cut -d: -f1 || true)
    
    if [ -z "$sessions" ]; then
        log_error "接続可能なセッションが見つかりません"
        echo ""
        echo "💡 新しいセッションを作成してください:"
        echo "   ./python_project_launcher.sh"
        return 1
    fi
    
    local session_count=$(echo "$sessions" | wc -l)
    
    if [ "$session_count" -eq 1 ]; then
        local session_name=$(echo "$sessions" | head -n1)
        log_info "セッション '$session_name' に接続中..."
        tmux attach-session -t "$session_name"
    else
        log_info "複数のセッションが見つかりました:"
        echo ""
        
        local i=1
        echo "$sessions" | while read -r session_name; do
            local pane_count=$(tmux list-panes -t "$session_name" 2>/dev/null | wc -l)
            echo "$i) $session_name (ペイン数: $pane_count)"
            ((i++))
        done
        echo ""
        
        read -p "接続するセッション番号を選択してください (1-$session_count): " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$session_count" ]; then
            local selected_session=$(echo "$sessions" | sed -n "${choice}p")
            log_info "セッション '$selected_session' に接続中..."
            tmux attach-session -t "$selected_session"
        else
            log_error "無効な選択です: $choice"
            return 1
        fi
    fi
}

# Kill all sessions
kill_all_sessions() {
    local sessions=$(tmux list-sessions 2>/dev/null | grep -E "$SESSION_PREFIX" | cut -d: -f1 || true)
    
    if [ -z "$sessions" ]; then
        log_warning "終了するセッションが見つかりません"
        return 0
    fi
    
    log_warning "以下のセッションを終了します:"
    echo "$sessions"
    echo ""
    
    read -p "本当に全セッションを終了しますか？ (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$sessions" | while read -r session_name; do
            tmux kill-session -t "$session_name" 2>/dev/null || true
            log_info "セッション終了: $session_name"
        done
        log_success "全セッションを終了しました"
    else
        log_info "キャンセルしました"
    fi
}

# Send test message
send_test_message() {
    if [ -f "$SCRIPT_DIR/team_messaging.sh" ]; then
        log_info "メッセージングシステムテストを実行中..."
        "$SCRIPT_DIR/team_messaging.sh" --test
    else
        log_error "メッセージングシステムが見つかりません: $SCRIPT_DIR/team_messaging.sh"
        return 1
    fi
}

# Show usage
show_usage() {
    echo "🚀 Microsoft Product Management Tools - Quick Connect"
    echo "====================================================="
    echo ""
    echo "📋 使用方法:"
    echo ""
    echo "  $0 [オプション]"
    echo ""
    echo "🔧 オプション:"
    echo ""
    echo "  (なし)          セッション状況表示"
    echo "  -c, --connect   セッションに即座接続"
    echo "  -k, --kill      全セッション終了"
    echo "  -t, --test      メッセージングテスト"
    echo "  -h, --help      このヘルプを表示"
    echo ""
    echo "📋 例:"
    echo ""
    echo "  $0              # セッション状況確認"
    echo "  $0 -c           # 即座接続"
    echo "  $0 -k           # 全セッション終了"
    echo "  $0 -t           # メッセージングテスト"
    echo ""
    echo "💡 ヒント:"
    echo ""
    echo "  • セッションがない場合は ./python_project_launcher.sh で作成"
    echo "  • メッセージング: ./team_messaging.sh"
    echo "  • ペインタイトル: 役職+アイコンで表示"
}

# Main execution
main() {
    case "${1:-}" in
        "-c"|"--connect")
            quick_connect
            ;;
        "-k"|"--kill")
            kill_all_sessions
            ;;
        "-t"|"--test")
            send_test_message
            ;;
        "-h"|"--help")
            show_usage
            ;;
        "")
            if show_session_status; then
                echo "🚀 クイック接続オプション:"
                echo "   即座接続: $0 -c"
                echo "   終了: $0 -k"
                echo "   メッセージテスト: $0 -t"
                echo ""
                read -p "セッションに接続しますか？ (y/n): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    quick_connect
                fi
            fi
            ;;
        *)
            log_error "不明なオプション: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"