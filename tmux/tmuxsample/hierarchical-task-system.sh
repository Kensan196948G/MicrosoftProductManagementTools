#!/bin/bash

# 🏢 階層的AI開発チーム管理システム
# CTO → Manager → Developer の組織構造に基づく自動タスク分配・報告システム

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/hierarchical-tasks.log"
REPORT_FILE="$SCRIPT_DIR/logs/development-reports.log"

# 色付きログ出力
log_info() { echo -e "\033[36m[INFO]\033[0m $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $1" | tee -a "$LOG_FILE"; }

# 使用方法表示
show_usage() {
    cat << EOF
🏢 階層的AI開発チーム管理システム

組織構造:
  CTO (2ペイン)     - 全Manager・Developerの日本語言語切替統括
  Manager (3ペイン) - Developer指示・報告取りまとめ・CTO報告
  Developer (6ペイン) - Frontend/Backend/DB/API開発・修復

使用方法:
  $0 cto-directive "全体指示内容"        # CTOから全体への指示
  $0 manager-task "管理タスク内容"       # Manager向けタスク分配
  $0 dev-assign "開発タスク内容"         # Developer向けタスク分配
  $0 language-switch                     # 全員の日本語切替指示
  $0 collect-reports                     # Developer報告収集
  $0 manager-report                      # Manager統合報告作成
  $0 status                              # 現在の組織状況表示

専門的な開発タスク分配:
  $0 frontend "フロントエンド作業内容"
  $0 backend "バックエンド作業内容" 
  $0 database "データベース作業内容"
  $0 api "API開発作業内容"
  $0 repair "修復作業内容"

例:
  $0 cto-directive "新機能開発プロジェクト開始準備を開始してください"
  $0 frontend "ログイン画面のUI/UX改善を実装してください"
  $0 collect-reports
EOF
}

# 組織メンバー定義
get_cto_members() {
    echo "cto:0:CTO-Language-Coordinator"
    echo "cto:1:CTO-Team-Supervisor"
}

get_manager_members() {
    echo "manager:0:Manager-Task-Distributor"
    echo "manager:1:Manager-Report-Collector" 
    echo "manager:2:Manager-CTO-Reporter"
}

get_developer_members() {
    echo "developer:0:Developer-Frontend"
    echo "developer:1:Developer-Backend"
    echo "developer:2:Developer-Database"
    echo "developer:3:Developer-API"
    echo "developer:4:Developer-Frontend-Repair"
    echo "developer:5:Developer-Backend-Repair"
}

# 全メンバー取得
get_all_members() {
    get_cto_members
    get_manager_members
    get_developer_members
}

# メンバーにメッセージ送信
send_message_to_member() {
    local session="$1"
    local pane="$2"
    local role="$3"
    local message="$4"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # セッション存在確認
    if ! tmux has-session -t "$session" 2>/dev/null; then
        log_error "セッション '$session' が見つかりません"
        return 1
    fi
    
    log_info "送信中: $role ($session:$pane) へ"
    
    # メッセージ整形
    local formatted_message="【$timestamp】$message

担当役割: $role
指示者: システム自動分配
対応要求: 即座に作業を開始し、完了後に報告してください"
    
    # プロンプトクリアしてメッセージ送信
    tmux send-keys -t "$session:$pane" C-c 2>/dev/null
    sleep 0.3
    tmux send-keys -t "$session:$pane" C-u 2>/dev/null
    sleep 0.2
    
    # 複数行メッセージを送信
    while IFS= read -r line || [[ -n "$line" ]]; do
        tmux send-keys -t "$session:$pane" "$line"
        tmux send-keys -t "$session:$pane" C-m
        sleep 0.1
    done <<< "$formatted_message"
    
    sleep 0.3
    
    # ログ記録
    echo "[$timestamp] $role ($session:$pane) <- $message" >> "$LOG_FILE"
    
    return 0
}

# CTOから全体への指示
cto_directive() {
    local directive="$1"
    if [[ -z "$directive" ]]; then
        log_error "CTO指示内容が指定されていません"
        return 1
    fi
    
    log_info "🏢 CTO全体指示開始: $directive"
    
    local success_count=0
    local total_count=0
    
    # Manager全員に指示
    while IFS=: read -r session pane role; do
        ((total_count++))
        local manager_directive="【CTO指示】$directive

役割: あなたはManagerとして、この指示をDeveloperチームに適切に分配し、進捗を管理してください。"
        
        if send_message_to_member "$session" "$pane" "$role" "$manager_directive"; then
            ((success_count++))
        fi
        sleep 0.5
    done < <(get_manager_members)
    
    # Developer全員にも同時通知
    while IFS=: read -r session pane role; do
        ((total_count++))
        local dev_directive="【CTO指示通知】$directive

役割: この指示はManagerを通じて具体的なタスクとして分配されます。準備を整えてお待ちください。"
        
        if send_message_to_member "$session" "$pane" "$role" "$dev_directive"; then
            ((success_count++))
        fi
        sleep 0.3
    done < <(get_developer_members)
    
    log_success "CTO指示完了: $success_count/$total_count メンバーに送信完了"
}

# Manager向けタスク分配
manager_task() {
    local task="$1"
    if [[ -z "$task" ]]; then
        log_error "Managerタスクが指定されていません"
        return 1
    fi
    
    log_info "📋 Manager向けタスク分配: $task"
    
    # Manager全員に分配（ラウンドロビン）
    local managers=($(get_manager_members))
    local last_index_file="$SCRIPT_DIR/logs/last_manager_index.txt"
    local current_index=0
    
    if [[ -f "$last_index_file" ]]; then
        current_index=$(cat "$last_index_file")
        current_index=$(( (current_index + 1) % ${#managers[@]} ))
    fi
    
    local selected_manager="${managers[$current_index]}"
    local session=$(echo "$selected_manager" | cut -d: -f1)
    local pane=$(echo "$selected_manager" | cut -d: -f2)
    local role=$(echo "$selected_manager" | cut -d: -f3)
    
    local manager_task="【Manager専用タスク】$task

管理責任: このタスクを適切にDeveloperに分配し、進捗を監視してください。完了後はCTOに報告してください。"
    
    if send_message_to_member "$session" "$pane" "$role" "$manager_task"; then
        echo "$current_index" > "$last_index_file"
        log_success "Managerタスク分配完了: $role に送信"
    fi
}

# Developer向けタスク分配
dev_assign() {
    local task="$1"
    if [[ -z "$task" ]]; then
        log_error "Developerタスクが指定されていません"
        return 1
    fi
    
    log_info "💻 Developer向けタスク分配: $task"
    
    # Developer全員に分配（ラウンドロビン）
    local developers=($(get_developer_members))
    local last_index_file="$SCRIPT_DIR/logs/last_developer_index.txt"
    local current_index=0
    
    if [[ -f "$last_index_file" ]]; then
        current_index=$(cat "$last_index_file")
        current_index=$(( (current_index + 1) % ${#developers[@]} ))
    fi
    
    local selected_dev="${developers[$current_index]}"
    local session=$(echo "$selected_dev" | cut -d: -f1)
    local pane=$(echo "$selected_dev" | cut -d: -f2)
    local role=$(echo "$selected_dev" | cut -d: -f3)
    
    local dev_task="【開発タスク】$task

専門領域: あなたの専門性を活かして実装してください。完了後はManagerに詳細な実装報告をしてください。"
    
    if send_message_to_member "$session" "$pane" "$role" "$dev_task"; then
        echo "$current_index" > "$last_index_file"
        log_success "Developerタスク分配完了: $role に送信"
    fi
}

# 専門分野別タスク分配
assign_specialized_task() {
    local specialty="$1"
    local task="$2"
    
    if [[ -z "$task" ]]; then
        log_error "タスク内容が指定されていません"
        return 1
    fi
    
    local target_role=""
    case "$specialty" in
        "frontend")
            target_role="Developer-Frontend"
            ;;
        "backend") 
            target_role="Developer-Backend"
            ;;
        "database")
            target_role="Developer-Database"
            ;;
        "api")
            target_role="Developer-API"
            ;;
        "repair")
            # 修復タスクは両方のRepair担当に分配
            log_info "🔧 修復タスク開始: $task"
            
            # Frontend Repair
            if send_message_to_member "developer" "4" "Developer-Frontend-Repair" "【修復タスク】$task (フロントエンド領域)"; then
                log_success "Frontend修復担当に送信完了"
            fi
            
            # Backend Repair  
            if send_message_to_member "developer" "5" "Developer-Backend-Repair" "【修復タスク】$task (バックエンド領域)"; then
                log_success "Backend修復担当に送信完了"
            fi
            return 0
            ;;
        *)
            log_error "不明な専門分野: $specialty"
            return 1
            ;;
    esac
    
    # 特定の専門分野に送信
    while IFS=: read -r session pane role; do
        if [[ "$role" == "$target_role" ]]; then
            local specialized_task="【$specialty専門タスク】$task

専門領域: あなたの$specialty専門性を最大限活用して実装してください。"
            
            if send_message_to_member "$session" "$pane" "$role" "$specialized_task"; then
                log_success "$specialty専門タスク分配完了: $role に送信"
                return 0
            fi
        fi
    done < <(get_developer_members)
    
    log_error "$target_role が見つかりませんでした"
    return 1
}

# 言語切替指示
language_switch() {
    log_info "🌐 全員日本語切替指示開始"
    
    local switch_message="【言語切替指示】日本語モードに切り替えてください

指示: 以下のコマンドを実行してください
1. 現在の作業を安全に保存
2. 日本語言語設定に変更
3. 準備完了後に「日本語切替完了」と報告"
    
    local success_count=0
    local total_count=0
    
    # 全メンバーに送信
    while IFS=: read -r session pane role; do
        ((total_count++))
        if send_message_to_member "$session" "$pane" "$role" "$switch_message"; then
            ((success_count++))
        fi
        sleep 0.2
    done < <(get_all_members)
    
    log_success "言語切替指示完了: $success_count/$total_count メンバーに送信"
}

# Developer報告収集
collect_reports() {
    log_info "📊 Developer報告収集開始"
    
    local report_request="【進捗報告要求】現在の作業状況を詳細に報告してください

報告項目:
1. 現在実施中のタスク
2. 完了した作業内容
3. 発生した問題・課題
4. 次の予定作業
5. サポート必要事項

フォーマット: 「【進捗報告】[役割名] [報告内容]」"
    
    local success_count=0
    
    while IFS=: read -r session pane role; do
        if send_message_to_member "$session" "$pane" "$role" "$report_request"; then
            ((success_count++))
        fi
        sleep 0.3
    done < <(get_developer_members)
    
    log_success "報告収集要求完了: $success_count 名のDeveloperに送信"
    
    # Manager報告収集担当に通知
    send_message_to_member "manager" "1" "Manager-Report-Collector" "【報告収集開始】Developerからの進捗報告を収集し、統合レポートを作成してください"
}

# Manager統合報告作成
manager_report() {
    log_info "📈 Manager統合報告作成開始"
    
    local report_task="【統合報告作成】収集した全Developer報告を統合し、CTOに包括的な状況報告を作成してください

統合報告内容:
1. 全体プロジェクト進捗状況
2. 各専門分野の状況
3. 発生している課題・リスク
4. 必要なリソース・サポート
5. 次期計画・提案"
    
    send_message_to_member "manager" "2" "Manager-CTO-Reporter" "$report_task"
    log_success "Manager統合報告作成指示完了"
}

# 組織状況表示
show_status() {
    echo "🏢 階層的AI開発チーム - 組織状況"
    echo "================================="
    
    echo ""
    echo "👑 CTO (2ペイン) - 全体統括・言語切替管理"
    while IFS=: read -r session pane role; do
        echo "  • $session:$pane - $role"
    done < <(get_cto_members)
    
    echo ""
    echo "👔 Manager (3ペイン) - 指示分配・報告統合・CTO報告"
    while IFS=: read -r session pane role; do
        echo "  • $session:$pane - $role"
    done < <(get_manager_members)
    
    echo ""
    echo "💻 Developer (6ペイン) - 専門開発・修復作業"
    while IFS=: read -r session pane role; do
        echo "  • $session:$pane - $role"
    done < <(get_developer_members)
    
    echo ""
    echo "📊 最近の活動 (直近5件):"
    if [[ -f "$LOG_FILE" ]]; then
        tail -5 "$LOG_FILE" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  活動履歴なし"
    fi
}

# ログディレクトリ作成
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$REPORT_FILE")"

# メイン処理
main() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] 階層的タスクシステム実行: $*" >> "$LOG_FILE"
    
    case "${1:-}" in
        "cto-directive")
            cto_directive "$2"
            ;;
        "manager-task")
            manager_task "$2"
            ;;
        "dev-assign")
            dev_assign "$2"
            ;;
        "frontend")
            assign_specialized_task "frontend" "$2"
            ;;
        "backend")
            assign_specialized_task "backend" "$2"
            ;;
        "database")
            assign_specialized_task "database" "$2"
            ;;
        "api")
            assign_specialized_task "api" "$2"
            ;;
        "repair")
            assign_specialized_task "repair" "$2"
            ;;
        "language-switch")
            language_switch
            ;;
        "collect-reports")
            collect_reports
            ;;
        "manager-report")
            manager_report
            ;;
        "status")
            show_status
            ;;
        "--help"|"-h"|"")
            show_usage
            ;;
        *)
            log_error "不明なコマンド: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"