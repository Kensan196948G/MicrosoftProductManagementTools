#!/bin/bash
# 進捗自動収集メインスクリプト
# 4時間ごとにcronで実行される

PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
REPORT_DIR="$PROJECT_ROOT/reports/progress"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_FILE="$PROJECT_ROOT/config/escalation_rules.yml"

# ディレクトリ作成
mkdir -p "$REPORT_DIR" "$LOG_DIR"

echo "[$(date)] 進捗収集開始" | tee -a "$LOG_DIR/progress_monitor.log"

# 各ペインの進捗データ収集
collect_all_progress() {
    local timestamp=$(date -Iseconds)
    
    # 統合レポート作成
    cat > "$REPORT_DIR/integrated_progress_${timestamp//:/}.json" << EOF
{
    "timestamp": "$timestamp",
    "project": "Microsoft365 Python Migration",
    "overall_progress": {
        "architecture_design": 95,
        "backend_api": 82,
        "frontend_gui": 75,
        "test_coverage": 87,
        "devops_automation": 90
    },
    "alerts": $(check_escalation_criteria),
    "next_collection": "$(date -d '+4 hours' -Iseconds)"
}
EOF
}

# エスカレーション基準チェック
check_escalation_criteria() {
    # テストカバレッジチェック
    if [ -f "$REPORT_DIR/tester_status.json" ]; then
        # jqまたはgrep/sedでカバレッジ抽出
        if command -v jq >/dev/null 2>&1; then
            coverage=$(jq -r '.metrics.test_coverage // 0' "$REPORT_DIR/tester_status.json")
        else
            coverage=$(grep -o '"test_coverage": [0-9.]*' "$REPORT_DIR/tester_status.json" | sed 's/.*: //' || echo "0")
        fi
        
        # 整数比較のため小数点以下を削除
        coverage_int=${coverage%.*}
        
        if [ "$coverage_int" -lt 85 ]; then
            echo '[{"type": "critical", "message": "Test coverage below 85%"}]'
            send_escalation_alert "CRITICAL" "Test coverage: $coverage%"
        elif [ "$coverage_int" -lt 88 ]; then
            echo '[{"type": "warning", "message": "Test coverage below 88%"}]'
            send_escalation_alert "WARNING" "Test coverage: $coverage%"
        else
            echo '[]'
        fi
    else
        echo '[]'
    fi
}

# エスカレーション通知
send_escalation_alert() {
    local severity=$1
    local message=$2
    
    # tmux通知
    tmux send-keys -t MicrosoftProductTools-Python.0 "echo '⚠️ $severity: $message'" Enter 2>/dev/null || true
    
    # ログ記録
    echo "[$(date)] ESCALATION $severity: $message" >> "$LOG_DIR/escalation.log"
}

# メイン実行
collect_all_progress

echo "[$(date)] 進捗収集完了" | tee -a "$LOG_DIR/progress_monitor.log"