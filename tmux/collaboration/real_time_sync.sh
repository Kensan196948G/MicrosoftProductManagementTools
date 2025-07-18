#!/bin/bash
# リアルタイム同期と連携強化スクリプト
# 5ペイン体制での効率的な情報共有を実現

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ステータスファイル
STATUS_DIR="./logs/realtime_status"
mkdir -p $STATUS_DIR

# リアルタイムステータス更新
update_realtime_status() {
    local role=$1
    local status=$2
    local details=$3
    local priority=${4:-normal}
    
    # ステータスファイル更新
    cat > "$STATUS_DIR/${role}.status" << EOF
{
    "role": "$role",
    "status": "$status",
    "details": "$details",
    "priority": "$priority",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "unix_time": $(date +%s)
}
EOF
    
    # 全ペインに通知（優先度に応じた色分け）
    case $priority in
        high)
            color=$RED
            prefix="🚨"
            ;;
        medium)
            color=$YELLOW
            prefix="⚠️"
            ;;
        *)
            color=$GREEN
            prefix="✓"
            ;;
    esac
    
    # tmux全ペインに送信
    for pane in 0 1 2 3 4; do
        tmux send-keys -t MicrosoftProductTools-Python:0.$pane \
            "echo -e '${color}${prefix} [$role] $status${NC}'" C-m
    done
}

# ブロッカー検出と自動エスカレーション
detect_blockers() {
    local role=$1
    local issue=$2
    local severity=$3
    
    echo -e "${RED}🚫 ブロッカー検出: [$role]${NC}"
    echo "問題: $issue"
    echo "深刻度: $severity"
    
    # ブロッカーログ記録
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $role | $issue | $severity" >> "$STATUS_DIR/blockers.log"
    
    # 自動エスカレーション
    case $severity in
        critical)
            # CTOとManagerに即座に通知
            update_realtime_status "SYSTEM" "重大ブロッカー: $issue (from $role)" "" "high"
            tmux send-keys -t MicrosoftProductTools-Python:0.0 \
                "echo -e '${RED}🚨 重大問題: $issue - 即座の対応が必要です${NC}'" C-m
            tmux send-keys -t MicrosoftProductTools-Python:0.1 \
                "echo -e '${RED}🚨 [$role] ブロッカー: $issue - リソース再配分を検討${NC}'" C-m
            ;;
        high)
            # Managerに通知
            tmux send-keys -t MicrosoftProductTools-Python:0.1 \
                "echo -e '${YELLOW}⚠️ [$role] ブロッカー: $issue${NC}'" C-m
            ;;
        *)
            # ログのみ
            echo "ブロッカーをログに記録しました"
            ;;
    esac
}

# 依存関係の自動通知
notify_dependency_resolved() {
    local from_role=$1
    local to_role=$2
    local task=$3
    
    # 依存先に通知
    case $to_role in
        dev0) target_pane=2 ;;
        dev1) target_pane=3 ;;
        dev2) target_pane=4 ;;
        Manager) target_pane=1 ;;
        CTO) target_pane=0 ;;
        *) target_pane=1 ;; # デフォルトはManager
    esac
    
    tmux send-keys -t MicrosoftProductTools-Python:0.$target_pane \
        "echo -e '${GREEN}✅ [$from_role] 完了: $task - 作業を開始できます${NC}'" C-m
}

# 進捗ダッシュボード表示
show_progress_dashboard() {
    clear
    echo -e "${CYAN}=== 5ペイン開発進捗ダッシュボード ===${NC}"
    echo -e "更新時刻: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # 各ロールの最新ステータス表示
    for role in CTO Manager dev0 dev1 dev2; do
        if [ -f "$STATUS_DIR/${role}.status" ]; then
            status_data=$(cat "$STATUS_DIR/${role}.status")
            status=$(echo $status_data | jq -r '.status')
            details=$(echo $status_data | jq -r '.details')
            timestamp=$(echo $status_data | jq -r '.timestamp')
            priority=$(echo $status_data | jq -r '.priority')
            
            # 優先度に応じた色
            case $priority in
                high) color=$RED ;;
                medium) color=$YELLOW ;;
                *) color=$GREEN ;;
            esac
            
            printf "${color}%-10s${NC}: %s\n" "[$role]" "$status"
            if [ ! -z "$details" ] && [ "$details" != "null" ]; then
                printf "           詳細: %s\n" "$details"
            fi
            printf "           更新: %s\n\n" "$timestamp"
        else
            printf "${PURPLE}%-10s${NC}: ステータス未設定\n\n" "[$role]"
        fi
    done
    
    # アクティブなブロッカー表示
    if [ -f "$STATUS_DIR/blockers.log" ]; then
        echo -e "${RED}=== アクティブなブロッカー ===${NC}"
        tail -5 "$STATUS_DIR/blockers.log"
        echo ""
    fi
}

# 定期同期ミーティングの自動リマインダー
schedule_sync_reminder() {
    local interval=${1:-30}  # デフォルト30分
    
    while true; do
        sleep $((interval * 60))
        
        # 全ペインにリマインダー送信
        for pane in 0 1 2 3 4; do
            tmux send-keys -t MicrosoftProductTools-Python:0.$pane \
                "echo -e '${BLUE}📅 定期同期時刻です - team sync を実行してください${NC}'" C-m
        done
    done
}

# メインコマンド処理
case "$1" in
    status)
        update_realtime_status "$2" "$3" "$4" "$5"
        ;;
    blocker)
        detect_blockers "$2" "$3" "$4"
        ;;
    resolved)
        notify_dependency_resolved "$2" "$3" "$4"
        ;;
    dashboard)
        show_progress_dashboard
        ;;
    sync-reminder)
        schedule_sync_reminder "$2"
        ;;
    watch)
        # ダッシュボードを継続的に更新
        while true; do
            show_progress_dashboard
            sleep 5
        done
        ;;
    *)
        echo "使用方法:"
        echo "  $0 status <role> <status> [details] [priority]"
        echo "  $0 blocker <role> <issue> <severity>"
        echo "  $0 resolved <from_role> <to_role> <task>"
        echo "  $0 dashboard"
        echo "  $0 watch"
        echo "  $0 sync-reminder [interval_minutes]"
        echo ""
        echo "優先度: high, medium, normal"
        echo "深刻度: critical, high, medium, low"
        ;;
esac