#!/bin/bash

# 🚀 AI自動作業分担システム - チーム開発支援ツール
# 全メンバーに平等にタスクを自動分配して並行開発を実現

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/task-distribution.log"
TASK_QUEUE_FILE="$SCRIPT_DIR/logs/task-queue.txt"

# 色付きログ出力
log_info() { echo -e "\033[36m[INFO]\033[0m $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $1" | tee -a "$LOG_FILE"; }

# 使用方法表示
show_usage() {
    cat << EOF
🚀 AI自動作業分担システム

使用方法:
  $0 distribute "タスク説明"     # 単一タスクを自動分配
  $0 batch-distribute         # 複数タスクを一括分配
  $0 status                   # 現在の分配状況確認
  $0 add-task "タスク説明"     # タスクキューに追加
  $0 clear-queue              # タスクキューをクリア

例:
  $0 distribute "フロントエンドのバグ修正を実施してください"
  $0 add-task "API連携テストの実装"
  $0 add-task "UI/UXの改善作業"
  $0 batch-distribute
EOF
}

# チームメンバー検出
detect_team_members() {
    local members=()
    
    # 各セッションのペインを検出
    for session in $(tmux list-sessions -F "#{session_name}" 2>/dev/null); do
        
        # セッション内の全ペイン情報を取得
        while IFS= read -r pane_info; do
            if [[ -n "$pane_info" ]]; then
                local pane_index=$(echo "$pane_info" | cut -d: -f1)
                local pane_title=$(echo "$pane_info" | cut -d: -f2- | sed 's/^ *//')
                
                # セッション名に基づいて役割を決定
                local role=""
                case "$session" in
                    "cto") 
                        if [[ "$pane_title" == *"Backend"* ]]; then
                            role="CTO-Backend-Lead"
                        else
                            role="CTO-Support-$pane_index"
                        fi
                        ;;
                    "developer") 
                        if [[ "$pane_title" == *"WebUI"* ]]; then
                            role="Frontend-Developer-$pane_index"
                        else
                            role="Developer-$pane_index"
                        fi
                        ;;
                    "manager") 
                        if [[ "$pane_title" == *"WebUI"* ]]; then
                            role="Frontend-Manager-$pane_index"
                        else
                            role="Manager-$pane_index"
                        fi
                        ;;
                    *) role="$session-$pane_index" ;;
                esac
                
                members+=("$session:$pane_index:$role")
            fi
        done < <(tmux list-panes -t "$session" -F "#{pane_index}:#{pane_title}" 2>/dev/null)
    done
    
    printf '%s\n' "${members[@]}"
}

# ラウンドロビン方式でタスク分配
distribute_single_task() {
    local task="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ -z "$task" ]]; then
        log_error "タスクが指定されていません"
        return 1
    fi
    
    log_info "タスク分配開始: $task"
    
    # メンバー一覧取得
    local members=($(detect_team_members))
    
    if [[ ${#members[@]} -eq 0 ]]; then
        log_error "利用可能なチームメンバーが見つかりません"
        return 1
    fi
    
    log_info "検出されたメンバー数: ${#members[@]}"
    
    # 前回の分配インデックスを読み込み（ラウンドロビン継続）
    local last_index_file="$SCRIPT_DIR/logs/last_distribution_index.txt"
    local current_index=0
    
    if [[ -f "$last_index_file" ]]; then
        current_index=$(cat "$last_index_file")
        current_index=$(( (current_index + 1) % ${#members[@]} ))
    fi
    
    # 選択されたメンバー
    local selected_member="${members[$current_index]}"
    local session=$(echo "$selected_member" | cut -d: -f1)
    local pane=$(echo "$selected_member" | cut -d: -f2)
    local role=$(echo "$selected_member" | cut -d: -f3)
    
    log_info "選択されたメンバー: $session:$pane ($role)"
    
    # タスク送信
    local formatted_task="【自動分配タスク】$task

担当: $role
時刻: $timestamp
指示: 上記タスクを担当領域に応じて実装してください"
    
    if send_task_to_member "$session" "$pane" "$formatted_task"; then
        log_success "タスク分配完了: $session:$pane に「$task」を送信"
        
        # 次回用のインデックス保存
        echo "$current_index" > "$last_index_file"
        
        # 分配履歴記録
        echo "[$timestamp] $session:$pane ($role) -> $task" >> "$LOG_FILE"
        
        return 0
    else
        log_error "タスク送信失敗: $session:$pane"
        return 1
    fi
}

# メンバーにタスクを送信
send_task_to_member() {
    local session="$1"
    local pane="$2"
    local task="$3"
    
    # セッション存在確認
    if ! tmux has-session -t "$session" 2>/dev/null; then
        log_error "セッション '$session' が見つかりません"
        return 1
    fi
    
    # プロンプトクリアしてタスク送信
    tmux send-keys -t "$session:$pane" C-c 2>/dev/null
    sleep 0.3
    tmux send-keys -t "$session:$pane" C-u 2>/dev/null
    sleep 0.2
    
    # 複数行メッセージを送信
    while IFS= read -r line || [[ -n "$line" ]]; do
        tmux send-keys -t "$session:$pane" "$line"
        tmux send-keys -t "$session:$pane" C-m
        sleep 0.1
    done <<< "$task"
    
    sleep 0.3
    return 0
}

# 複数タスクの一括分配
batch_distribute() {
    if [[ ! -f "$TASK_QUEUE_FILE" ]]; then
        log_warn "タスクキューファイルが存在しません"
        return 1
    fi
    
    local task_count=$(wc -l < "$TASK_QUEUE_FILE")
    if [[ $task_count -eq 0 ]]; then
        log_warn "タスクキューは空です"
        return 1
    fi
    
    log_info "一括分配開始: $task_count 個のタスク"
    
    local success_count=0
    local line_num=1
    
    while IFS= read -r task; do
        if [[ -n "$task" && ! "$task" =~ ^[[:space:]]*# ]]; then
            log_info "分配中 ($line_num/$task_count): $task"
            
            if distribute_single_task "$task"; then
                ((success_count++))
                sleep 1  # 分配間隔
            fi
        fi
        ((line_num++))
    done < "$TASK_QUEUE_FILE"
    
    log_success "一括分配完了: $success_count/$task_count タスクが正常に分配されました"
    
    # 分配完了したタスクキューをバックアップして削除
    local backup_file="$TASK_QUEUE_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    mv "$TASK_QUEUE_FILE" "$backup_file"
    log_info "完了したタスクキューを $backup_file にバックアップしました"
}

# タスクキューに追加
add_task_to_queue() {
    local task="$1"
    if [[ -z "$task" ]]; then
        log_error "タスクが指定されていません"
        return 1
    fi
    
    mkdir -p "$(dirname "$TASK_QUEUE_FILE")"
    echo "$task" >> "$TASK_QUEUE_FILE"
    log_success "タスクをキューに追加: $task"
}

# 現在の状況表示
show_status() {
    echo "🎯 AI自動作業分担システム - 現在の状況"
    echo "=================================="
    
    # チームメンバー表示
    echo ""
    echo "👥 検出されたチームメンバー:"
    local members=($(detect_team_members))
    
    if [[ ${#members[@]} -eq 0 ]]; then
        echo "  ❌ 利用可能なメンバーが見つかりません"
    else
        for i in "${!members[@]}"; do
            local member="${members[$i]}"
            local session=$(echo "$member" | cut -d: -f1)
            local pane=$(echo "$member" | cut -d: -f2)
            local role=$(echo "$member" | cut -d: -f3)
            echo "  $((i+1)). $session:$pane - $role"
        done
    fi
    
    # 次回分配予定
    local last_index_file="$SCRIPT_DIR/logs/last_distribution_index.txt"
    if [[ -f "$last_index_file" && ${#members[@]} -gt 0 ]]; then
        local current_index=$(cat "$last_index_file")
        local next_index=$(( (current_index + 1) % ${#members[@]} ))
        local next_member="${members[$next_index]}"
        echo ""
        echo "🎯 次回分配予定: $(echo "$next_member" | cut -d: -f1,2) ($(echo "$next_member" | cut -d: -f3))"
    fi
    
    # タスクキューの状況
    echo ""
    echo "📋 タスクキュー:"
    if [[ -f "$TASK_QUEUE_FILE" ]]; then
        local queue_count=$(wc -l < "$TASK_QUEUE_FILE")
        echo "  待機中のタスク: $queue_count 個"
        if [[ $queue_count -gt 0 ]]; then
            echo "  --- 待機中タスク一覧 ---"
            cat -n "$TASK_QUEUE_FILE" | head -10
            if [[ $queue_count -gt 10 ]]; then
                echo "  ... 他 $((queue_count - 10)) 個"
            fi
        fi
    else
        echo "  待機中のタスク: 0 個"
    fi
    
    # 最近の分配履歴
    echo ""
    echo "📊 最近の分配履歴 (直近5件):"
    if [[ -f "$LOG_FILE" ]]; then
        grep "タスク分配完了" "$LOG_FILE" | tail -5 | while read -r line; do
            echo "  $line"
        done
    else
        echo "  履歴なし"
    fi
}

# タスクキューのクリア
clear_queue() {
    if [[ -f "$TASK_QUEUE_FILE" ]]; then
        local backup_file="$TASK_QUEUE_FILE.cleared.$(date +%Y%m%d_%H%M%S)"
        mv "$TASK_QUEUE_FILE" "$backup_file"
        log_success "タスクキューをクリアしました (バックアップ: $backup_file)"
    else
        log_info "タスクキューは既に空です"
    fi
}

# ログディレクトリ作成
mkdir -p "$(dirname "$LOG_FILE")"

# メイン処理
main() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] 自動作業分担システム実行: $*" >> "$LOG_FILE"
    
    case "${1:-}" in
        "distribute")
            if [[ -n "$2" ]]; then
                distribute_single_task "$2"
            else
                log_error "タスクを指定してください"
                show_usage
                exit 1
            fi
            ;;
        "batch-distribute")
            batch_distribute
            ;;
        "add-task")
            if [[ -n "$2" ]]; then
                add_task_to_queue "$2"
            else
                log_error "タスクを指定してください"
                show_usage
                exit 1
            fi
            ;;
        "status")
            show_status
            ;;
        "clear-queue")
            clear_queue
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