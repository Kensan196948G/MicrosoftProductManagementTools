#!/bin/bash

# 🏢 階層的チーム管理統合メッセージシステム
# CTO/Manager/Developer階層管理 + tmuxsample機能統合版

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/hierarchical-messages.log"
TASK_QUEUE_FILE="$SCRIPT_DIR/logs/task-queue.txt"
ACTIVITY_LOG="$SCRIPT_DIR/logs/team-activity.log"

# ログディレクトリ作成
mkdir -p "$SCRIPT_DIR/logs"

# 色付きログ出力
log_info() { echo -e "\033[36m[INFO]\033[0m $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $1" | tee -a "$LOG_FILE"; }

# セッション検出（既存の機能を維持）
detect_active_session() {
    local session_patterns=(
        "MicrosoftProductTools-Python-Context7-5team"
        "claude-team-*"
        "dev-team-*"
        "python-dev-*"
    )
    
    for pattern in "${session_patterns[@]}"; do
        if tmux list-sessions 2>/dev/null | grep -q "$pattern"; then
            tmux list-sessions | grep "$pattern" | head -1 | cut -d: -f1
            return 0
        fi
    done
    
    return 1
}

# 緊急メッセージ自動検出（既存機能を維持）
is_urgent_message() {
    local message="$1"
    local urgent_patterns=(
        "緊急指示" "緊急連絡" "緊急事態" "緊急対応" "緊急停止"
        "即座" "即時" "直ちに" "至急" "URGENT" "EMERGENCY" "CRITICAL"
        "【緊急】" "【URGENT】" "【至急】" "【即時】" "🚨" "⚡" "🔥"
    )
    
    for pattern in "${urgent_patterns[@]}"; do
        if [[ "$message" == *"$pattern"* ]]; then
            return 0
        fi
    done
    return 1
}

# チームメンバー定義（tmuxsample統合）
get_team_members() {
    local role="$1"
    case "$role" in
        "cto")
            echo "cto manager"
            ;;
        "manager")
            echo "manager dev0 dev1 dev2"
            ;;
        "all-devs")
            echo "dev0 dev1 dev2"
            ;;
        "frontend")
            echo "dev0"  # フロントエンド専門
            ;;
        "backend")
            echo "dev1"  # バックエンド専門
            ;;
        "qa")
            echo "dev2"  # QA・テスト専門
            ;;
        *)
            echo "$role"
            ;;
    esac
}

# 階層的メッセージ送信（新機能）
send_hierarchical_message() {
    local action="$1"
    local message="$2"
    local session=$(detect_active_session)
    
    if [[ -z "$session" ]]; then
        log_error "アクティブなtmuxセッションが見つかりません"
        return 1
    fi
    
    log_info "階層的メッセージ送信開始: $action"
    
    case "$action" in
        "cto-directive")
            # CTO → 全体指示（アイコン付き）
            local cto_icon="👑"
            log_info "$cto_icon CTO全体指示: $message"
            for member in $(get_team_members "cto") $(get_team_members "all-devs"); do
                send_enhanced_message "$session:0.$member" "【$cto_icon CTO指示】$message" "$member"
            done
            ;;
            
        "manager-task")
            # Manager → Developer配布（アイコン付き）
            local manager_icon="👔"
            log_info "$manager_icon Manager指示: $message"
            for member in $(get_team_members "all-devs"); do
                send_enhanced_message "$session:0.$member" "【$manager_icon Manager指示】$message" "$member"
            done
            ;;
            
        "frontend")
            # フロントエンド専門タスク（アイコン付き）
            local frontend_icon="💻"
            log_info "$frontend_icon フロントエンド専門タスク: $message"
            for member in $(get_team_members "frontend"); do
                send_enhanced_message "$session:0.$member" "【$frontend_icon Frontend専門】$message" "$member"
            done
            ;;
            
        "backend")
            # バックエンド専門タスク（アイコン付き）
            local backend_icon="⚙️"
            log_info "$backend_icon バックエンド専門タスク: $message"
            for member in $(get_team_members "backend"); do
                send_enhanced_message "$session:0.$member" "【$backend_icon Backend専門】$message" "$member"
            done
            ;;
            
        "qa")
            # QA・テスト専門タスク（アイコン付き）
            local qa_icon="🧪"
            log_info "$qa_icon QA・テスト専門タスク: $message"
            for member in $(get_team_members "qa"); do
                send_enhanced_message "$session:0.$member" "【$qa_icon QA専門】$message" "$member"
            done
            ;;
            
        "collect-reports")
            # 進捗報告収集（アイコン付き）
            log_info "📊 進捗報告収集開始"
            collect_team_reports "$session"
            ;;
            
        "auto-distribute")
            # 自動タスク分散（アイコン付き）
            log_info "🚀 自動タスク分散: $message"
            auto_distribute_task "$session" "$message"
            ;;
            
        *)
            # デフォルト（既存機能）
            "$SCRIPT_DIR/send-message.sh" "$action" "$message"
            ;;
    esac
}

# 自動タスク分散（tmuxsample統合）
auto_distribute_task() {
    local session="$1"
    local task="$2"
    local members=($(get_team_members "all-devs"))
    local index_file="$SCRIPT_DIR/logs/last_distribution_index.txt"
    
    # 前回の分配インデックスを読み取り
    local last_index=0
    if [[ -f "$index_file" ]]; then
        last_index=$(cat "$index_file" 2>/dev/null || echo "0")
    fi
    
    # ラウンドロビン方式で次のメンバーを選択
    local current_index=$(( (last_index + 1) % ${#members[@]} ))
    local assigned_member="${members[$current_index]}"
    
    # タスク分配実行（アイコン付き）
    local assigned_icon=$(get_role_icon "$assigned_member")
    log_info "🎯 自動分配: $task → $assigned_icon $assigned_member"
    send_enhanced_message "$session:0.$assigned_member" "【🚀 自動分配タスク】$task" "$assigned_member"
    
    # インデックス更新
    echo "$current_index" > "$index_file"
    
    # 分配記録
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $task → $assigned_member" >> "$TASK_QUEUE_FILE"
}

# 進捗報告収集（tmuxsample統合）
collect_team_reports() {
    local session="$1"
    log_info "📊 チーム進捗報告収集開始"
    
    for member in $(get_team_members "all-devs"); do
        local member_icon=$(get_role_icon "$member")
        local report_request="【📊 進捗報告要求】現在の作業状況・完了項目・次の予定を簡潔に報告してください。"
        send_enhanced_message "$session:0.$member" "$report_request" "$member"
        sleep 2  # 送信間隔調整
    done
    
    # Manager宛に収集完了通知（アイコン付き）
    local cto_icon="👑"
    local manager_icon="👔"
    send_enhanced_message "$session:0.manager" "【$cto_icon CTO】全開発者への進捗報告収集を完了しました。統合レポート作成をお願いします。" "manager"
}

# チーム活動監視（tmuxsample統合）
monitor_team_activity() {
    log_info "👀 チーム活動監視開始"
    
    local current_time=$(date +%s)
    local members=($(get_team_members "all-devs"))
    local inactive_members=()
    
    for member in "${members[@]}"; do
        # 最後のアクティビティ時間をチェック
        local last_activity=$(grep "$member" "$ACTIVITY_LOG" | tail -1 | grep -o '\[.*\]' | tr -d '[]' 2>/dev/null)
        
        if [[ -n "$last_activity" ]]; then
            local last_time=$(date -d "$last_activity" +%s 2>/dev/null || echo "0")
            local time_diff=$((current_time - last_time))
            local minutes_ago=$((time_diff / 60))
            
            if [[ $minutes_ago -gt 30 ]]; then
                log_warn "⚠️ $member: 最後のアクティビティから${minutes_ago}分経過"
                inactive_members+=("$member")
            else
                log_info "✅ $member: 最後のアクティビティから${minutes_ago}分"
            fi
        else
            log_warn "⚠️ $member: アクティビティ記録なし"
            inactive_members+=("$member")
        fi
    done
    
    # 非アクティブメンバーに緊急ping（アイコン付き）
    if [[ ${#inactive_members[@]} -gt 0 ]]; then
        local session=$(detect_active_session)
        for member in "${inactive_members[@]}"; do
            local member_icon=$(get_role_icon "$member")
            send_enhanced_message "$session:0.$member" "【🚨 緊急ping】$member_icon 応答確認: 現在の状況を教えてください" "$member"
        done
    fi
}

# 役職別アイコン定義
get_role_icon() {
    local role="$1"
    case "$role" in
        "cto")
            echo "👑"
            ;;
        "manager")
            echo "👔"
            ;;
        "dev0"|"frontend")
            echo "💻"
            ;;
        "dev1"|"backend")
            echo "⚙️"
            ;;
        "dev2"|"qa")
            echo "🧪"
            ;;
        *)
            echo "📢"
            ;;
    esac
}

# 拡張メッセージ送信（アイコン表示機能追加）
send_enhanced_message() {
    local target="$1"
    local message="$2"
    local agent_name="$3"
    
    # 送信者と受信者のアイコンを取得
    local sender_icon=$(get_role_icon "$(whoami)")
    local receiver_icon=$(get_role_icon "$agent_name")
    
    # 緊急メッセージの場合は即時配信
    if is_urgent_message "$message"; then
        log_warn "🚨 緊急メッセージ検出 - 即時配信モード"
        instant_broadcast_message "$target" "$message" "$agent_name"
        return $?
    fi
    
    # 通常配信（アイコン付き表示）
    echo "📤 $sender_icon → $receiver_icon 送信中: $agent_name へメッセージを送信..."
    
    # プロンプトクリア
    tmux send-keys -t "$target" C-c 2>/dev/null
    sleep 0.3
    tmux send-keys -t "$target" C-u 2>/dev/null
    sleep 0.3
    
    # メッセージ送信
    if [[ "$message" == *$'\n'* ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            tmux send-keys -t "$target" "$line"
            tmux send-keys -t "$target" C-m
            sleep 0.2
        done <<< "$message"
    else
        tmux send-keys -t "$target" "$message"
        sleep 0.3
        tmux send-keys -t "$target" C-m
    fi
    
    echo "✅ $sender_icon → $receiver_icon 送信完了: $agent_name に自動実行されました"
    
    # アクティビティ記録（アイコン付き）
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $sender_icon → $receiver_icon Message sent to $agent_name: ${message:0:50}..." >> "$ACTIVITY_LOG"
    
    return 0
}

# 即時配信（アイコン表示機能追加）
instant_broadcast_message() {
    local target="$1"
    local message="$2"
    local agent_name="$3"
    
    # 送信者と受信者のアイコンを取得
    local sender_icon=$(get_role_icon "$(whoami)")
    local receiver_icon=$(get_role_icon "$agent_name")
    
    log_warn "⚡ $sender_icon → $receiver_icon 即時配信実行: $agent_name"
    
    tmux send-keys -t "$target" C-c 2>/dev/null
    sleep 0.1
    tmux send-keys -t "$target" C-u 2>/dev/null
    sleep 0.1
    tmux send-keys -t "$target" "$message"
    sleep 0.1
    tmux send-keys -t "$target" C-m
    
    log_success "⚡ $sender_icon → $receiver_icon 即時配信完了: $agent_name"
    return 0
}

# 使用方法表示
show_usage() {
    cat << EOF
🏢 階層的チーム管理統合メッセージシステム

【階層的組織管理】
  $0 cto-directive "全体指示内容"        # CTO → 全体指示
  $0 manager-task "管理タスク内容"       # Manager → Developer配布
  
【専門分野別タスク配布】
  $0 frontend "フロントエンド作業内容"   # React/TypeScript専門
  $0 backend "バックエンド作業内容"      # FastAPI/Python専門  
  $0 qa "QA・テスト作業内容"             # pytest/品質保証専門
  
【自動化機能】
  $0 auto-distribute "タスク内容"        # 自動ラウンドロビン分配
  $0 collect-reports                     # 進捗報告自動収集
  $0 monitor-activity                    # チーム活動監視
  
【従来機能（互換性維持）】
  $0 manager "メッセージ"                # Manager宛送信
  $0 frontend "メッセージ"               # Frontend宛送信（既存）
  
【システム制御】
  $0 reset-all-prompts                   # 全プロンプトリセット
  $0 --status                            # システム状況確認

例:
  $0 cto-directive "Microsoft 365 Python移行プロジェクト開始"
  $0 frontend "React UIコンポーネントの改善作業"
  $0 auto-distribute "Microsoft Graph API統合テスト実装"
  $0 collect-reports
EOF
}

# メイン処理
main() {
    case "${1:-help}" in
        "cto-directive"|"manager-task"|"frontend"|"backend"|"qa"|"auto-distribute"|"collect-reports")
            send_hierarchical_message "$1" "$2"
            ;;
        "monitor-activity")
            monitor_team_activity
            ;;
        "reset-all-prompts")
            reset_all_prompts
            ;;
        "--status")
            show_system_status
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            # 既存機能への互換性保持
            if [[ -f "$SCRIPT_DIR/send-message.sh" ]]; then
                "$SCRIPT_DIR/send-message.sh" "$@"
            else
                log_error "不明なコマンド: $1"
                show_usage
                exit 1
            fi
            ;;
    esac
}

# システム状況表示
show_system_status() {
    echo "🏢 階層的チーム管理システム状況"
    echo "================================"
    
    local session=$(detect_active_session)
    if [[ -n "$session" ]]; then
        echo "✅ アクティブセッション: $session"
    else
        echo "❌ アクティブセッションなし"
    fi
    
    echo ""
    echo "📊 最近のタスク分配:"
    if [[ -f "$TASK_QUEUE_FILE" ]]; then
        tail -5 "$TASK_QUEUE_FILE" 2>/dev/null || echo "  (記録なし)"
    else
        echo "  (記録なし)"
    fi
    
    echo ""
    echo "👥 チーム構成:"
    echo "  CTO: 戦略決定・全体統括"
    echo "  Manager: チーム管理・報告統合"
    echo "  Frontend(dev0): React/TypeScript専門"
    echo "  Backend(dev1): FastAPI/Python専門"
    echo "  QA(dev2): pytest/品質保証専門"
}

# 全プロンプトリセット
reset_all_prompts() {
    local session=$(detect_active_session)
    if [[ -z "$session" ]]; then
        log_error "アクティブセッションが見つかりません"
        return 1
    fi
    
    log_info "🔄 全プロンプトリセット開始"
    
    local all_members=(cto manager dev0 dev1 dev2)
    for member in "${all_members[@]}"; do
        log_info "リセット中: $member"
        tmux send-keys -t "$session:0.$member" C-c 2>/dev/null
        sleep 0.5
        tmux send-keys -t "$session:0.$member" C-u 2>/dev/null
        sleep 0.5
        tmux send-keys -t "$session:0.$member" "clear" C-m 2>/dev/null
        sleep 0.3
    done
    
    log_success "✅ 全プロンプトリセット完了"
}

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi