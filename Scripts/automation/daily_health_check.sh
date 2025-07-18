#!/bin/bash

# 日次システムヘルスチェック
# 毎朝6時に実行され、システム全体の健全性を確認

set -euo pipefail

PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
REPORTS_DIR="$PROJECT_ROOT/reports/progress"
LOGS_DIR="$PROJECT_ROOT/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/health_check.log"
}

log "Starting daily health check..."

# ヘルスチェック結果を格納する配列
declare -a health_issues=()

# 1. ディスク使用量チェック
check_disk_usage() {
    log "Checking disk usage..."
    
    local usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$usage" -gt 80 ]; then
        health_issues+=("Disk usage critical: ${usage}%")
        log "WARNING: Disk usage is ${usage}%"
    elif [ "$usage" -gt 70 ]; then
        health_issues+=("Disk usage high: ${usage}%")
        log "INFO: Disk usage is ${usage}%"
    else
        log "INFO: Disk usage is healthy: ${usage}%"
    fi
}

# 2. メモリ使用量チェック
check_memory_usage() {
    log "Checking memory usage..."
    
    local mem_usage=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    local mem_usage_int=$(echo "$mem_usage" | cut -d. -f1)
    
    if [ "$mem_usage_int" -gt 85 ]; then
        health_issues+=("Memory usage critical: ${mem_usage}%")
        log "WARNING: Memory usage is ${mem_usage}%"
    elif [ "$mem_usage_int" -gt 75 ]; then
        health_issues+=("Memory usage high: ${mem_usage}%")
        log "INFO: Memory usage is ${mem_usage}%"
    else
        log "INFO: Memory usage is healthy: ${mem_usage}%"
    fi
}

# 3. ログファイルサイズチェック
check_log_files() {
    log "Checking log file sizes..."
    
    local large_logs=$(find "$LOGS_DIR" -name "*.log" -size +100M 2>/dev/null || true)
    
    if [ -n "$large_logs" ]; then
        health_issues+=("Large log files found")
        log "WARNING: Large log files detected:"
        echo "$large_logs" | while read -r logfile; do
            local size=$(du -h "$logfile" | cut -f1)
            log "  - $logfile: $size"
        done
    else
        log "INFO: Log file sizes are healthy"
    fi
}

# 4. Python環境チェック
check_python_environment() {
    log "Checking Python environment..."
    
    if ! python3 --version &>/dev/null; then
        health_issues+=("Python3 not available")
        log "ERROR: Python3 is not available"
        return
    fi
    
    local python_version=$(python3 --version 2>&1 | awk '{print $2}')
    log "INFO: Python version: $python_version"
    
    # 必要なパッケージのチェック
    local required_packages=("PyQt6" "msal" "pandas" "jinja2")
    local missing_packages=()
    
    for package in "${required_packages[@]}"; do
        if ! python3 -c "import $package" &>/dev/null; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        health_issues+=("Missing Python packages: ${missing_packages[*]}")
        log "WARNING: Missing packages: ${missing_packages[*]}"
    else
        log "INFO: All required Python packages are available"
    fi
}

# 5. tmux環境チェック
check_tmux_environment() {
    log "Checking tmux environment..."
    
    if ! command -v tmux &>/dev/null; then
        health_issues+=("tmux not available")
        log "ERROR: tmux is not available"
        return
    fi
    
    local tmux_sessions=$(tmux list-sessions 2>/dev/null | wc -l)
    log "INFO: Active tmux sessions: $tmux_sessions"
    
    # MicrosoftProductTools-Python セッションの確認
    if tmux has-session -t "MicrosoftProductTools-Python" 2>/dev/null; then
        local pane_count=$(tmux list-panes -t "MicrosoftProductTools-Python" | wc -l)
        if [ "$pane_count" -eq 5 ]; then
            log "INFO: Python migration tmux session is healthy (5/5 panes)"
        else
            health_issues+=("Python migration tmux session degraded: $pane_count/5 panes")
            log "WARNING: Python migration tmux session has $pane_count/5 panes"
        fi
    else
        log "INFO: Python migration tmux session not found (this is normal if not actively developing)"
    fi
}

# 6. 進捗レポートファイルチェック
check_progress_reports() {
    log "Checking progress reports..."
    
    # 過去24時間以内のレポートがあるかチェック
    local recent_reports=$(find "$REPORTS_DIR" -name "*.json" -mtime -1 2>/dev/null | wc -l)
    
    if [ "$recent_reports" -eq 0 ]; then
        health_issues+=("No recent progress reports generated")
        log "WARNING: No progress reports generated in the last 24 hours"
    else
        log "INFO: Found $recent_reports recent progress reports"
    fi
}

# 7. cron ジョブチェック
check_cron_jobs() {
    log "Checking cron jobs..."
    
    local active_cron_jobs=$(crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$' | wc -l)
    
    if [ "$active_cron_jobs" -eq 0 ]; then
        health_issues+=("No active cron jobs configured")
        log "WARNING: No active cron jobs found"
    else
        log "INFO: Found $active_cron_jobs active cron jobs"
    fi
}

# ヘルスチェック実行
main() {
    log "=== Daily Health Check Started ==="
    
    check_disk_usage
    check_memory_usage
    check_log_files
    check_python_environment
    check_tmux_environment
    check_progress_reports
    check_cron_jobs
    
    # 結果のサマリー
    local health_status="HEALTHY"
    
    if [ ${#health_issues[@]} -gt 0 ]; then
        health_status="ISSUES_FOUND"
        log "=== Health Issues Found ==="
        for issue in "${health_issues[@]}"; do
            log "  - $issue"
        done
    fi
    
    # JSON形式でレポート保存
    local timestamp=$(date -Iseconds)
    local report_file="$REPORTS_DIR/health_check_$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$report_file" << EOF
{
    "timestamp": "$timestamp",
    "health_status": "$health_status",
    "issues_count": ${#health_issues[@]},
    "issues": $(printf '%s\n' "${health_issues[@]}" | jq -R . | jq -s .),
    "system_info": {
        "disk_usage": "$(df -h / | awk 'NR==2 {print $5}')",
        "memory_usage": "$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')",
        "load_average": "$(uptime | awk -F'load average:' '{print $2}' | xargs)",
        "python_version": "$(python3 --version 2>&1 | awk '{print $2}')",
        "tmux_sessions": $(tmux list-sessions 2>/dev/null | wc -l)
    }
}
EOF
    
    log "Health check report saved: $report_file"
    
    # 重要な問題があればアラート送信
    if [ ${#health_issues[@]} -gt 0 ]; then
        send_health_alert "$health_status" "${health_issues[@]}"
    fi
    
    log "=== Daily Health Check Completed ==="
}

# ヘルスアラート送信
send_health_alert() {
    local status="$1"
    shift
    local issues=("$@")
    
    log "Sending health alert..."
    
    # tmux経由でアーキテクトに通知
    if tmux has-session -t "MicrosoftProductTools-Python" 2>/dev/null; then
        local message="🚨 Daily Health Check: $status (${#issues[@]} issues)"
        tmux send-keys -t "MicrosoftProductTools-Python:0" "echo '$message'" C-m
        
        for issue in "${issues[@]}"; do
            tmux send-keys -t "MicrosoftProductTools-Python:0" "echo '  - $issue'" C-m
        done
    fi
}

# メイン実行
main "$@"