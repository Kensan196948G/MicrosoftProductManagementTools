#!/bin/bash

# tmux環境健全性チェック・監視スクリプト
# 開発環境の5ペイン構成を監視し、問題発生時に自動復旧を試行

set -euo pipefail

PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
LOGS_DIR="$PROJECT_ROOT/logs"
REPORTS_DIR="$PROJECT_ROOT/reports/progress"
TMUX_SESSION="MicrosoftProductTools-Python"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/tmux_monitor.log"
}

# tmux環境の健全性チェック
check_tmux_health() {
    local health_status="unknown"
    local issues=()
    
    # tmuxインストール確認
    if ! command -v tmux &>/dev/null; then
        health_status="tmux_not_installed"
        issues+=("tmux is not installed")
        log "ERROR: tmux is not installed"
        return
    fi
    
    # セッション存在確認
    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        health_status="session_not_found"
        issues+=("Python migration session not found")
        log "INFO: tmux session '$TMUX_SESSION' not found"
        
        # 自動復旧の提案
        log "INFO: Session can be restored using: ./tmux_python_setup.sh"
        
        echo "$health_status"
        return
    fi
    
    # ペイン数確認
    local active_panes=$(tmux list-panes -t "$TMUX_SESSION" 2>/dev/null | wc -l)
    local expected_panes=5
    
    if [ "$active_panes" -eq "$expected_panes" ]; then
        health_status="healthy"
        log "INFO: tmux session is healthy ($active_panes/$expected_panes panes)"
    else
        health_status="degraded"
        issues+=("Pane count mismatch: $active_panes/$expected_panes panes active")
        log "WARNING: tmux session degraded - $active_panes/$expected_panes panes active"
        
        # 詳細ペイン情報取得
        get_pane_details
    fi
    
    # ペインの応答性確認
    check_pane_responsiveness
    
    # 各ペインの役割確認
    verify_pane_roles
    
    echo "$health_status"
}

# 詳細ペイン情報取得
get_pane_details() {
    log "Getting detailed pane information..."
    
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        local pane_info=$(tmux list-panes -t "$TMUX_SESSION" -F "#{pane_index}:#{pane_active}:#{pane_dead}:#{pane_title}" 2>/dev/null)
        
        log "Pane details:"
        echo "$pane_info" | while IFS=':' read -r index active dead title; do
            local status="active"
            [ "$dead" = "1" ] && status="dead"
            [ "$active" = "0" ] && status="inactive"
            
            log "  Pane $index: $status ($title)"
        done
    fi
}

# ペイン応答性確認
check_pane_responsiveness() {
    log "Checking pane responsiveness..."
    
    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        return
    fi
    
    # 各ペインにテストコマンドを送信
    for pane in {0..4}; do
        if tmux list-panes -t "$TMUX_SESSION" | grep -q "^$pane:"; then
            # echoコマンドを送信して応答を確認
            tmux send-keys -t "$TMUX_SESSION:$pane" "echo 'tmux_health_check_$(date +%s)'" C-m
            log "  Pane $pane: Test command sent"
        else
            log "  Pane $pane: Not found"
        fi
    done
}

# ペインの役割確認
verify_pane_roles() {
    log "Verifying pane roles..."
    
    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        return
    fi
    
    # 期待される役割配置
    local expected_roles=(
        "architect"      # Pane 0
        "backend"        # Pane 1
        "frontend"       # Pane 2
        "tester"         # Pane 3
        "devops"         # Pane 4
    )
    
    for i in "${!expected_roles[@]}"; do
        local role="${expected_roles[$i]}"
        local pane_index=$i
        
        if tmux list-panes -t "$TMUX_SESSION" | grep -q "^$pane_index:"; then
            log "  Pane $pane_index ($role): Present"
        else
            log "  Pane $pane_index ($role): Missing"
        fi
    done
}

# セッション自動復旧
auto_recover_session() {
    log "Attempting automatic session recovery..."
    
    local setup_script="$PROJECT_ROOT/tmux_python_setup.sh"
    
    if [ -f "$setup_script" ]; then
        log "Found setup script: $setup_script"
        
        # セットアップスクリプトを実行
        if bash "$setup_script"; then
            log "SUCCESS: Session recovery completed"
            return 0
        else
            log "ERROR: Session recovery failed"
            return 1
        fi
    else
        log "ERROR: Setup script not found: $setup_script"
        return 1
    fi
}

# 問題のあるペインの復旧
recover_missing_panes() {
    log "Attempting to recover missing panes..."
    
    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        log "ERROR: Session not found, cannot recover panes"
        return 1
    fi
    
    local current_panes=$(tmux list-panes -t "$TMUX_SESSION" 2>/dev/null | wc -l)
    local expected_panes=5
    
    if [ "$current_panes" -lt "$expected_panes" ]; then
        log "Recovering missing panes..."
        
        # 不足しているペインを作成
        for ((i=current_panes; i<expected_panes; i++)); do
            tmux split-window -t "$TMUX_SESSION" -h
            log "Created pane $i"
        done
        
        # ペインレイアウトを再調整
        tmux select-layout -t "$TMUX_SESSION" tiled
        log "Adjusted pane layout"
        
        return 0
    else
        log "INFO: All expected panes are present"
        return 0
    fi
}

# アラート送信
send_tmux_alert() {
    local alert_level="$1"
    local message="$2"
    
    log "Sending tmux alert: $alert_level - $message"
    
    # アーキテクトペインへの通知（可能な場合）
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        tmux send-keys -t "$TMUX_SESSION:0" "echo '🚨 tmux Alert [$alert_level]: $message'" C-m
    fi
    
    # アラートファイルに記録
    local alert_file="$REPORTS_DIR/tmux_alerts_$(date +%Y%m%d).json"
    local timestamp=$(date -Iseconds)
    
    # アラートJSONデータ作成
    local alert_data=$(cat << EOF
{
    "timestamp": "$timestamp",
    "alert_level": "$alert_level",
    "message": "$message",
    "session": "$TMUX_SESSION",
    "reported_by": "tmux_health_monitor"
}
EOF
)
    
    # アラートファイルに追記
    if [ -f "$alert_file" ]; then
        # 既存ファイルに追記
        local temp_file=$(mktemp)
        jq ". += [$alert_data]" "$alert_file" > "$temp_file" && mv "$temp_file" "$alert_file"
    else
        # 新規ファイル作成
        echo "[$alert_data]" > "$alert_file"
    fi
    
    log "Alert recorded in: $alert_file"
}

# メトリクス収集
collect_tmux_metrics() {
    local timestamp=$(date -Iseconds)
    local health_status=$(check_tmux_health)
    
    # メトリクス情報収集
    local metrics=$(cat << EOF
{
    "timestamp": "$timestamp",
    "monitor_type": "tmux_health",
    "session_name": "$TMUX_SESSION",
    "health_status": "$health_status",
    "metrics": {
        "session_exists": $(tmux has-session -t "$TMUX_SESSION" 2>/dev/null && echo "true" || echo "false"),
        "active_panes": $(tmux list-panes -t "$TMUX_SESSION" 2>/dev/null | wc -l || echo "0"),
        "expected_panes": 5,
        "session_uptime": "$(tmux display-message -t "$TMUX_SESSION" -p "#{session_created}" 2>/dev/null || echo "0")",
        "tmux_version": "$(tmux -V | cut -d' ' -f2)"
    }
}
EOF
)
    
    # メトリクスファイルに保存
    local metrics_file="$REPORTS_DIR/tmux_metrics_$(date +%Y%m%d_%H%M%S).json"
    echo "$metrics" > "$metrics_file"
    
    log "tmux metrics saved: $metrics_file"
    
    # 問題があればアラート送信
    if [ "$health_status" != "healthy" ]; then
        send_tmux_alert "WARNING" "tmux session health: $health_status"
    fi
}

# メイン実行
main() {
    local action="${1:-monitor}"
    
    log "=== tmux Health Monitor Started (action: $action) ==="
    
    case "$action" in
        "monitor")
            # 標準監視
            collect_tmux_metrics
            ;;
        "recover")
            # 自動復旧
            if [ "$(check_tmux_health)" = "session_not_found" ]; then
                auto_recover_session
            else
                recover_missing_panes
            fi
            ;;
        "alert")
            # 手動アラート
            send_tmux_alert "MANUAL" "${2:-Manual alert triggered}"
            ;;
        "status")
            # ステータス表示
            local status=$(check_tmux_health)
            echo "tmux Health Status: $status"
            ;;
        *)
            echo "Usage: $0 {monitor|recover|alert|status}"
            exit 1
            ;;
    esac
    
    log "=== tmux Health Monitor Completed ==="
}

# メイン実行
main "$@"