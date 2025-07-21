#!/bin/bash

# 🤖 自動キーワード検出・相互連携システム v1.0
# CTO/Manager/Developer キーワード自動検出・メッセージ転送システム

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/auto-keyword.log"
KEYWORD_LOG="$SCRIPT_DIR/logs/keyword-detection.log"
SESSION="MicrosoftProductTools-6team-Context7"

# ログディレクトリ作成
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$KEYWORD_LOG")"

# 色付きログ出力
log_info() { echo -e "\\033[36m[AUTO-KEYWORD]\\033[0m $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "\\033[32m[DETECTED]\\033[0m $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "\\033[31m[ERROR]\\033[0m $1" | tee -a "$LOG_FILE"; }
log_keyword() { echo -e "\\033[35m[KEYWORD]\\033[0m $1" | tee -a "$KEYWORD_LOG"; }

# キーワード検出パターン定義
declare -A KEYWORD_PATTERNS=(
    # CTO関連キーワード
    ["cto-directive"]="CTO|最高技術責任者|技術戦略|アーキテクチャ決定|技術承認"
    ["cto-review"]="技術レビュー|アーキテクチャレビュー|技術評価|品質承認"
    
    # Manager関連キーワード
    ["manager-task"]="Manager|マネージャー|チーム管理|進捗管理|タスク分配"
    ["manager-report"]="管理報告|進捗報告|チーム状況|プロジェクト状況"
    
    # Developer関連キーワード（一般）
    ["dev-assign"]="Developer|開発者|開発チーム|Dev|開発担当"
    ["frontend"]="フロントエンド|React|TypeScript|UI|UX|コンポーネント"
    ["backend"]="バックエンド|API|サーバー|データベース|Python|FastAPI"
    ["qa"]="QA|テスト|品質保証|テストケース|バグ|品質確認"
    ["powershell"]="PowerShell|Microsoft365|Exchange|Graph|EntraID|自動化"
    
    # 緊急・重要キーワード
    ["emergency"]="緊急|URGENT|CRITICAL|障害|エラー|問題|修正"
    ["priority"]="優先|重要|至急|即時|HIGH|すぐに"
)

# メッセージ解析・キーワード検出
detect_keywords() {
    local input_message="$1"
    local detected_categories=()
    
    log_info "メッセージ解析開始: ${input_message:0:50}..."
    
    for category in "${!KEYWORD_PATTERNS[@]}"; do
        local patterns="${KEYWORD_PATTERNS[$category]}"
        
        # 各パターンをチェック
        IFS='|' read -ra PATTERN_ARRAY <<< "$patterns"
        for pattern in "${PATTERN_ARRAY[@]}"; do
            if [[ "$input_message" =~ $pattern ]]; then
                detected_categories+=("$category")
                log_keyword "検出: $category <- '$pattern'"
                break
            fi
        done
    done
    
    echo "${detected_categories[@]}"
}

# 自動メッセージ送信
auto_send_message() {
    local category="$1"
    local original_message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_success "自動送信実行: $category"
    
    case "$category" in
        "cto-directive")
            if [[ -x "$SCRIPT_DIR/hierarchical-task-system-6team.sh" ]]; then
                "$SCRIPT_DIR/hierarchical-task-system-6team.sh" cto-directive "$original_message"
                log_success "CTO指示自動送信完了"
            fi
            ;;
            
        "manager-task")
            if [[ -x "$SCRIPT_DIR/hierarchical-task-system-6team.sh" ]]; then
                "$SCRIPT_DIR/hierarchical-task-system-6team.sh" manager-task "$original_message"
                log_success "Manager指示自動送信完了"
            fi
            ;;
            
        "dev-assign")
            if [[ -x "$SCRIPT_DIR/hierarchical-task-system-6team.sh" ]]; then
                "$SCRIPT_DIR/hierarchical-task-system-6team.sh" dev-assign "$original_message"
                log_success "Developer指示自動送信完了"
            fi
            ;;
            
        "frontend"|"backend"|"qa"|"powershell")
            if [[ -x "$SCRIPT_DIR/hierarchical-task-system-6team.sh" ]]; then
                "$SCRIPT_DIR/hierarchical-task-system-6team.sh" "$category" "$original_message"
                log_success "$category専門タスク自動送信完了"
            fi
            ;;
            
        "emergency")
            # 緊急時は全員に送信
            emergency_broadcast "$original_message"
            ;;
            
        "priority")
            # 優先タスクは自動分散
            if [[ -x "$SCRIPT_DIR/hierarchical-task-system-6team.sh" ]]; then
                "$SCRIPT_DIR/hierarchical-task-system-6team.sh" auto-distribute "$original_message"
                log_success "優先タスク自動分散完了"
            fi
            ;;
    esac
}

# 緊急ブロードキャスト
emergency_broadcast() {
    local emergency_message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_error "🚨 緊急ブロードキャスト実行"
    
    # 全ペインに緊急メッセージ送信
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        local formatted_message="🚨【緊急通知・$timestamp】$emergency_message

⚡ 緊急対応要求: 即座に確認し、必要な対応を開始してください
📞 連絡: 対応状況を速やかに報告してください"

        for pane_id in {0..5}; do
            tmux send-keys -t "$SESSION:0.$pane_id" C-c 2>/dev/null
            sleep 0.2
            tmux send-keys -t "$SESSION:0.$pane_id" C-u 2>/dev/null
            sleep 0.2
            
            # 複数行メッセージ送信
            while IFS= read -r line || [[ -n "$line" ]]; do
                tmux send-keys -t "$SESSION:0.$pane_id" "$line"
                tmux send-keys -t "$SESSION:0.$pane_id" C-m
                sleep 0.1
            done <<< "$formatted_message"
            
            sleep 0.3
        done
        
        log_error "緊急ブロードキャスト完了: 全6ペインに送信"
    else
        log_error "tmuxセッションが見つかりません"
    fi
}

# 使用方法表示
show_usage() {
    cat << EOF
🤖 自動キーワード検出・相互連携システム v1.0

【基本使用法】
  $0 analyze "メッセージ内容"          # メッセージ解析・自動送信
  $0 test "テストメッセージ"           # テスト実行（送信なし）
  $0 monitor                          # リアルタイム監視開始
  $0 stop-monitor                     # 監視停止

【キーワード検出カテゴリ】
  🎯 CTO関連:
     - CTO, 最高技術責任者, 技術戦略, アーキテクチャ決定, 技術承認
     - 技術レビュー, アーキテクチャレビュー, 技術評価, 品質承認
  
  👔 Manager関連:
     - Manager, マネージャー, チーム管理, 進捗管理, タスク分配
     - 管理報告, 進捗報告, チーム状況, プロジェクト状況
  
  💻 Developer関連:
     - 一般: Developer, 開発者, 開発チーム, Dev, 開発担当
     - フロントエンド: React, TypeScript, UI, UX, コンポーネント
     - バックエンド: API, サーバー, データベース, Python, FastAPI
     - QA: テスト, 品質保証, テストケース, バグ, 品質確認
     - PowerShell: Microsoft365, Exchange, Graph, EntraID, 自動化
  
  🚨 緊急・優先:
     - 緊急, URGENT, CRITICAL, 障害, エラー, 問題, 修正
     - 優先, 重要, 至急, 即時, HIGH, すぐに

【自動実行例】
  $0 analyze "CTOからの技術戦略について検討してください"
  → CTO指示として自動送信
  
  $0 analyze "フロントエンドのReactコンポーネント修正が必要"
  → Frontend専門タスクとして自動送信
  
  $0 analyze "緊急でサーバーエラーが発生しています"
  → 全員への緊急ブロードキャスト実行

【監視モード】
  リアルタイム監視: tmuxペイン内の会話を自動監視し、
  キーワード検出時に自動的に相互連携メッセージを送信
EOF
}

# メッセージ解析・自動送信メイン処理
analyze_and_send() {
    local message="$1"
    local test_mode="${2:-false}"
    
    if [[ -z "$message" ]]; then
        log_error "メッセージが指定されていません"
        return 1
    fi
    
    log_info "自動キーワード検出開始"
    
    # キーワード検出
    local detected_categories=($(detect_keywords "$message"))
    
    if [[ ${#detected_categories[@]} -eq 0 ]]; then
        log_info "検出されたキーワードなし"
        return 0
    fi
    
    log_success "検出されたカテゴリ: ${detected_categories[*]}"
    echo "検出結果: ${detected_categories[*]}"
    
    # テストモードの場合は送信しない
    if [[ "$test_mode" == "true" ]]; then
        log_info "テストモード: 送信をスキップ"
        return 0
    fi
    
    # 自動送信実行
    for category in "${detected_categories[@]}"; do
        auto_send_message "$category" "$message"
        sleep 1
    done
    
    log_success "自動相互連携完了"
}

# リアルタイム監視（実験的機能）
start_monitoring() {
    log_info "リアルタイム監視開始（実験的機能）"
    
    local monitor_pid_file="$SCRIPT_DIR/logs/keyword-monitor.pid"
    
    # 既存監視プロセス確認
    if [[ -f "$monitor_pid_file" ]]; then
        local existing_pid=$(cat "$monitor_pid_file")
        if kill -0 "$existing_pid" 2>/dev/null; then
            log_error "監視プロセスは既に実行中です (PID: $existing_pid)"
            return 1
        fi
    fi
    
    # 監視プロセス開始（簡易版）
    nohup bash -c '
        while true; do
            # 簡易的な監視（ログファイルベース）
            if [[ -f "'"$SCRIPT_DIR"'/logs/tmux-chat.log" ]]; then
                tail -n 1 "'"$SCRIPT_DIR"'/logs/tmux-chat.log" | while read -r line; do
                    if [[ -n "$line" ]]; then
                        echo "[$(date \"+%Y-%m-%d %H:%M:%S\")] 監視検出: $line" >> "'"$LOG_FILE"'"
                        "'"$0"'" analyze "$line" >/dev/null 2>&1
                    fi
                done
            fi
            sleep 5
        done
    ' > /dev/null 2>&1 &
    
    echo $! > "$monitor_pid_file"
    log_success "リアルタイム監視開始完了 (PID: $!)"
    
    echo ""
    echo "📋 監視設定:"
    echo "- 監視対象: tmuxチャットログ"
    echo "- 監視間隔: 5秒"
    echo "- 自動送信: 有効"
    echo "- 停止方法: $0 stop-monitor"
}

# 監視停止
stop_monitoring() {
    local monitor_pid_file="$SCRIPT_DIR/logs/keyword-monitor.pid"
    
    if [[ -f "$monitor_pid_file" ]]; then
        local monitor_pid=$(cat "$monitor_pid_file")
        if kill -0 "$monitor_pid" 2>/dev/null; then
            kill "$monitor_pid"
            rm -f "$monitor_pid_file"
            log_success "リアルタイム監視停止完了 (PID: $monitor_pid)"
        else
            log_error "監視プロセスが見つかりません"
            rm -f "$monitor_pid_file"
        fi
    else
        log_error "監視PIDファイルが見つかりません"
    fi
}

# メイン処理
main() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] 自動キーワード検出システム実行: $*" >> "$LOG_FILE"
    
    case "${1:-}" in
        "analyze")
            analyze_and_send "$2" false
            ;;
        "test")
            analyze_and_send "$2" true
            ;;
        "monitor")
            start_monitoring
            ;;
        "stop-monitor")
            stop_monitoring
            ;;
        "--help"|"-h"|"help"|"")
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