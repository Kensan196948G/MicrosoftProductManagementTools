#!/bin/bash

# Developer Activity Monitoring Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/developer-activity.log"
COMMUNICATION_LOG="$SCRIPT_DIR/logs/communication.log"

# Create logs directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/logs"

# Function to log activity
log_activity() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

# Function to check developer last activity
check_developer_activity() {
    local dev_name="$1"
    local current_time=$(date +%s)
    
    # Check last message from developer in communication log
    local last_message_time=$(grep "→ manager.*$dev_name" "$COMMUNICATION_LOG" | tail -1 | grep -o '\[.*\]' | tr -d '[]' | head -1)
    
    if [[ -n "$last_message_time" ]]; then
        local last_time=$(date -d "$last_message_time" +%s 2>/dev/null || echo "0")
        local time_diff=$((current_time - last_time))
        local minutes_ago=$((time_diff / 60))
        
        if [[ $minutes_ago -gt 30 ]]; then
            log_activity "WARNING: $dev_name last activity was $minutes_ago minutes ago"
            return 1
        else
            log_activity "OK: $dev_name last activity was $minutes_ago minutes ago"
            return 0
        fi
    else
        log_activity "ERROR: No activity found for $dev_name"
        return 1
    fi
}

# Function to send emergency ping to inactive developers
send_emergency_ping() {
    local dev_name="$1"
    log_activity "Sending emergency ping to $dev_name"
    
    ./send-message.sh "$dev_name" "【緊急応答要請】
システム監視により、あなたの活動が30分以上検出されていません。

至急以下を実行してください：
1. 現在の状況を報告: 【緊急応答】[状況]
2. 作業中の場合: 進捗状況を詳細報告
3. 問題がある場合: 具体的な課題を報告

5分以内に応答がない場合、セッション復旧手順を実行します。"
}

# Function to check tmux session health
check_tmux_health() {
    local session_name="claude-team-6devs"
    
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        log_activity "CRITICAL: tmux session $session_name not found"
        return 1
    fi
    
    local pane_count=$(tmux list-panes -t "$session_name" -F "#{pane_index}" | wc -l)
    if [[ $pane_count -lt 8 ]]; then
        log_activity "WARNING: Expected 8 panes, found $pane_count"
        return 1
    fi
    
    log_activity "OK: tmux session healthy with $pane_count panes"
    return 0
}

# Function to monitor server processes
check_server_processes() {
    # Check for backend process
    if pgrep -f "nodemon src/app.ts" > /dev/null; then
        log_activity "OK: Backend server process running"
    else
        log_activity "ERROR: Backend server process not found"
    fi
    
    # Check for frontend process
    if pgrep -f "npm.*dev.*frontend" > /dev/null; then
        log_activity "OK: Frontend server process running"
    else
        log_activity "WARNING: Frontend server process not found"
    fi
}

# Main monitoring function
main_monitor() {
    log_activity "=== Developer Activity Monitor Started ==="
    
    # Check tmux session health
    check_tmux_health
    
    # Check server processes
    check_server_processes
    
    # Check each developer
    local inactive_devs=()
    for dev in dev1 dev2 dev3 dev4 dev5 dev6; do
        if ! check_developer_activity "$dev"; then
            inactive_devs+=("$dev")
        fi
    done
    
    # Send emergency pings to inactive developers
    if [[ ${#inactive_devs[@]} -gt 0 ]]; then
        log_activity "Found ${#inactive_devs[@]} inactive developers: ${inactive_devs[*]}"
        for dev in "${inactive_devs[@]}"; do
            send_emergency_ping "$dev"
        done
    else
        log_activity "All developers are active"
    fi
    
    log_activity "=== Monitoring cycle completed ==="
}

# Auto-recovery function
auto_recovery() {
    log_activity "=== Auto-recovery initiated ==="
    
    # Try to restart tmux session if needed
    if ! check_tmux_health; then
        log_activity "Attempting tmux session recovery..."
        # Add recovery commands here
    fi
    
    # Generate activity report
    generate_activity_report
}

# Generate activity report
generate_activity_report() {
    local report_file="$SCRIPT_DIR/logs/activity-report-$(date +%Y%m%d-%H%M%S).log"
    
    {
        echo "Developer Activity Report - $(date)"
        echo "========================================"
        echo ""
        echo "Developer Status:"
        for dev in dev1 dev2 dev3 dev4 dev5 dev6; do
            check_developer_activity "$dev" 2>&1
        done
        echo ""
        echo "System Status:"
        check_tmux_health 2>&1
        check_server_processes 2>&1
        echo ""
        echo "Recent Communication (last 10 entries):"
        tail -10 "$COMMUNICATION_LOG"
    } > "$report_file"
    
    log_activity "Activity report generated: $report_file"
}

# Command line interface
case "${1:-monitor}" in
    "monitor")
        main_monitor
        ;;
    "report")
        generate_activity_report
        ;;
    "recovery")
        auto_recovery
        ;;
    "ping")
        if [[ -n "$2" ]]; then
            send_emergency_ping "$2"
        else
            echo "Usage: $0 ping <dev_name>"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {monitor|report|recovery|ping <dev_name>}"
        echo ""
        echo "Commands:"
        echo "  monitor  - Run full activity monitoring cycle"
        echo "  report   - Generate activity report"
        echo "  recovery - Attempt auto-recovery"
        echo "  ping     - Send emergency ping to specific developer"
        exit 1
        ;;
esac