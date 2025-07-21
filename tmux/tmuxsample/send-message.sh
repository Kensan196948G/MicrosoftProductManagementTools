#!/bin/bash

# 🤖 AI並列開発チーム - 拡張メッセージ送信システム

# 使用方法表示
show_usage() {
    cat << EOF
🏢 AI階層的開発チーム - 統合メッセージ送信システム

👥 開発チーム構成 (動的検出対応):
  1) 2 Developers  - 小規模開発 (Manager + CEO + Dev0-1)
  2) 4 Developers  - 中規模開発 (Manager + CEO + Dev0-3)
  3) 6 Developers  - 大規模開発 (Manager + CEO + Dev0-5) 🌟推奨

組織構造:
  CEO (1名)       - 全体統括・戦略決定
  Manager (1名)   - プロジェクト管理・チーム調整  
  Developer (2-6名) - 専門開発・実装作業

基本使用方法:
  $0 [エージェント名] [メッセージ]
  $0 --list / --detect / --status

階層的組織管理コマンド:
  $0 cto-directive "全体指示内容"        # CTOから全体への指示
  $0 manager-task "管理タスク内容"       # Manager向けタスク分配
  $0 dev-assign "開発タスク内容"         # Developer向けタスク分配
  $0 language-switch                     # 全員の日本語切替指示
  $0 collect-reports                     # Developer報告収集
  $0 manager-report                      # Manager統合報告作成

専門開発タスク分配:
  $0 frontend|ui "フロントエンド/UI作業内容"      # Dev0: フロントエンド/UI 💻
  $0 backend|api "バックエンド/API作業内容"       # Dev1: バックエンド/API ⚙️
  $0 qa|test "QA/テスト作業内容"                 # Dev2: QA/テスト 🔒 (4+ Devs)
  $0 infra|devops "インフラ/DevOps作業内容"      # Dev3: インフラ/DevOps 🧪 (4+ Devs)
  $0 database|design "データベース/設計作業内容"  # Dev4: データベース/設計 🚀 (6 Devs)
  $0 ux|quality "UI/UX/品質管理作業内容"         # Dev5: UI/UX/品質管理 📊 (6 Devs)

従来のエージェント指定:
  cto / manager / developer             # セッション単位
  dev0-5 / mgr0-2 / cto0-1             # ペイン単位
  broadcast                             # 全員同時送信

使用例:
  $0 cto-directive "新機能開発プロジェクト開始準備を開始してください"
  $0 frontend "ログイン画面のUI/UX改善を実装してください"
  $0 collect-reports
  $0 manager "進捗状況を確認してください"
EOF
}

# ペイン番号マッピング読み込み
load_pane_mapping() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local mapping_file="$script_dir/logs/pane_mapping.txt"
    
    if [[ -f "$mapping_file" ]]; then
        source "$mapping_file"
        return 0
    else
        return 1
    fi
}

# セッション名を動的に検出
detect_active_session() {
    # claude-team-で始まるセッションを検索
    local claude_sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^claude-team-")
    
    if [[ -n "$claude_sessions" ]]; then
        # 複数ある場合は最初の一つを使用
        echo "$claude_sessions" | head -n1
        return 0
    fi
    
    # 従来のteamセッションもチェック
    if tmux has-session -t team 2>/dev/null; then
        echo "team"
        return 0
    fi
    
    return 1
}

# 現在のペイン構成を検出
detect_panes() {
    echo "📋 現在のtmux構成を検出中..."
    
    local session_name=$(detect_active_session)
    if [[ $? -ne 0 || -z "$session_name" ]]; then
        echo "❌ 有効なClaude AI teamセッションが見つかりません"
        echo "💡 利用可能セッション:"
        tmux list-sessions -F "  - #{session_name}" 2>/dev/null || echo "  (セッションが存在しません)"
        return 1
    fi
    
    echo "🎯 検出されたセッション: $session_name"
    
    local pane_count=$(tmux list-panes -t "$session_name" -F "#{pane_index}" | wc -l)
    echo "検出されたペイン数: $pane_count"
    
    # マッピング情報を読み込み
    if load_pane_mapping; then
        echo "📊 レイアウト種別: $LAYOUT_TYPE"
        
        if [[ "$LAYOUT_TYPE" == "hierarchical" ]]; then
            echo "🏗️  階層レイアウト (Developer数: $DEVELOPER_COUNT)"
            echo ""
            echo "📋 利用可能なエージェント:"
            echo "======================="
            echo "  ceo     → $session_name:0.$CEO_PANE (下段)          (最高経営責任者)"
            echo "  manager → $session_name:0.$MANAGER_PANE (中段)          (プロジェクトマネージャー)"
            
            IFS=',' read -ra dev_panes <<< "$DEVELOPER_PANES"
            for i in "${!dev_panes[@]}"; do
                local dev_num=$((i+1))
                echo "  dev$dev_num    → $session_name:0.${dev_panes[$i]} (上段)          (実行エージェント$dev_num)"
            done
            
            echo ""
            echo "特殊コマンド:"
            echo "  broadcast              (dev1-dev$DEVELOPER_COUNT に同時送信)"
            
        else
            echo "📋 従来レイアウト ($LAYOUT_NAME)"
            echo ""
            echo "📋 利用可能なエージェント:"
            echo "======================="
            echo "  ceo     → ceo:0        (最高経営責任者)"
            echo "  manager → $session_name:0.0     (プロジェクトマネージャー)"
            
            for ((i=1; i<pane_count; i++)); do
                echo "  dev$i    → $session_name:0.$i     (実行エージェント$i)"
            done
            
            echo ""
            echo "特殊コマンド:"
            echo "  broadcast              (dev1-dev$((pane_count-1))に同時送信)"
        fi
    else
        echo "⚠️  マッピング情報が見つかりません（従来形式で表示）"
        echo ""
        echo "📋 利用可能なエージェント:"
        echo "======================="
        echo "  manager → $session_name:0.0     (プロジェクトマネージャー)"
        echo "  ceo     → $session_name:0.1     (最高経営責任者)"
        
        local max_dev=0
        for ((i=2; i<pane_count; i++)); do
            local dev_num=$((i-2))
            echo "  dev$dev_num    → $session_name:0.$i     (実行エージェント$dev_num)"
            max_dev=$dev_num
        done
        
        echo ""
        echo "特殊コマンド:"
        echo "  broadcast              (dev0-dev$max_dev に同時送信)"
    fi
}

# エージェント一覧表示（動的）
show_agents() {
    detect_panes
}

# ログ機能
log_message() {
    local agent="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p logs
    echo "[$timestamp] → $agent: \"$message\"" >> logs/communication.log
}

# セッション存在確認
check_session() {
    local session_name="$1"
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "❌ エラー: セッション '$session_name' が見つかりません"
        echo "先に ./start-ai-team.sh を実行してください"
        return 1
    fi
    return 0
}

# 改良されたペイン存在確認
check_pane_exists() {
    local target="$1"
    local session="${target%:*}"
    local window_pane="${target##*:}"
    local pane="${window_pane##*.}"  # window.pane から pane だけを抽出
    
    # セッション存在確認
    if ! tmux has-session -t "$session" 2>/dev/null; then
        echo "❌ エラー: セッション '$session' が見つかりません"
        return 1
    fi
    
    # ペイン存在確認（より厳密に）
    if ! tmux list-panes -t "$session" 2>/dev/null | grep -q "^${pane}:"; then
        echo "❌ エラー: ペイン '$target' が見つかりません"
        echo "🔍 利用可能ペイン:"
        tmux list-panes -t "$session" -F "  #{pane_index}: #{pane_title}" 2>/dev/null || echo "  (ペイン一覧取得失敗)"
        return 1
    fi
    
    return 0
}

# 後方互換性のため旧関数も残す
check_pane() {
    check_pane_exists "$1"
}

# 改良版メッセージ送信
send_enhanced_message() {
    local target="$1"
    local message="$2"
    local agent_name="$3"
    
    echo "📤 送信中: $agent_name へメッセージを送信..."
    
    # ペイン存在確認
    if ! check_pane "$target"; then
        echo "❌ エラー: ペイン '$target' が見つかりません"
        return 1
    fi
    
    # 1. プロンプトクリア（より確実に）
    tmux send-keys -t "$target" C-c
    sleep 0.4
    
    # 2. 追加のクリア（念のため）
    tmux send-keys -t "$target" C-u
    sleep 0.2
    
    # 3. メッセージ送信（改行を含む場合は複数行で送信）
    # 改行が含まれる場合は行ごとに分けて送信
    if [[ "$message" == *$'\n'* ]]; then
        # 改行で分割して各行を送信
        while IFS= read -r line || [[ -n "$line" ]]; do
            tmux send-keys -t "$target" "$line"
            tmux send-keys -t "$target" C-m
            sleep 0.2
        done <<< "$message"
    else
        # 単一行の場合は従来通り
        tmux send-keys -t "$target" "$message"
        sleep 0.3
        tmux send-keys -t "$target" C-m
    fi
    
    sleep 0.5
    
    echo "✅ 送信完了: $agent_name に自動実行されました"
    return 0
}

# ブロードキャスト送信
broadcast_message() {
    local message="$1"
    
    local session_name=$(detect_active_session)
    if [[ $? -ne 0 || -z "$session_name" ]]; then
        echo "❌ 有効なClaude AI teamセッションが見つかりません"
        return 1
    fi
    
    if ! check_session "$session_name"; then
        return 1
    fi
    
    local success_count=0
    
    echo "📡 ブロードキャスト送信中..."
    
    # マッピング情報を読み込んでブロードキャスト対象を決定
    if load_pane_mapping && [[ "$LAYOUT_TYPE" == "hierarchical" ]]; then
        echo "対象: dev1 から dev$DEVELOPER_COUNT ($DEVELOPER_COUNT エージェント)"
        echo ""
        
        IFS=',' read -ra dev_panes <<< "$DEVELOPER_PANES"
        for i in "${!dev_panes[@]}"; do
            local dev_num=$((i+1))
            local target="$session_name:0.${dev_panes[$i]}"
            local agent_name="dev$dev_num"
            
            if send_enhanced_message "$target" "$message" "$agent_name"; then
                ((success_count++))
                log_message "$agent_name" "$message"
            fi
            
            sleep 0.3  # 送信間隔
        done
        
        echo ""
        echo "🎯 ブロードキャスト完了:"
        echo "   送信成功: $success_count/$DEVELOPER_COUNT エージェント"
    else
        # 従来レイアウトの処理
        local pane_count=$(tmux list-panes -t "$session_name" -F "#{pane_index}" | wc -l)
        local dev_count=$((pane_count-2))  # Manager(0) + CEO(1) を除く
        echo "対象: dev0 から dev$((dev_count-1)) ($dev_count エージェント)"
        echo ""
        
        # manager (ペイン0) + CEO (ペイン1) を除く開発者ペインに送信
        for ((i=2; i<pane_count; i++)); do
            local target="$session_name:0.$i"
            local dev_num=$((i-2))
            local agent_name="dev$dev_num"
            
            if send_enhanced_message "$target" "$message" "$agent_name"; then
                ((success_count++))
                log_message "$agent_name" "$message"
            fi
            
            sleep 0.3  # 送信間隔
        done
        
        echo ""
        echo "🎯 ブロードキャスト完了:"
        echo "   送信成功: $success_count/$dev_count エージェント"
    fi
    
    echo "   メッセージ: \"$message\""
    echo "   ログ: logs/communication.log に記録済み"
}

# エージェント名からターゲットを解決
resolve_target() {
    local agent="$1"
    local session_name=$(detect_active_session)
    
    if [[ $? -ne 0 || -z "$session_name" ]]; then
        return 1
    fi
    
    case $agent in
        "ceo")
            # マッピング情報を読み込んでCEOの場所を確認
            if load_pane_mapping && [[ "$LAYOUT_TYPE" == "hierarchical" ]]; then
                echo "$session_name:0.$CEO_PANE"  # 階層レイアウトでは検出されたセッション内
            else
                echo "$session_name:0.1"  # 現在の構成ではCEOはペイン1
            fi
            return 0
            ;;
        "manager")
            # マッピング情報を読み込んで適切なペインを返す
            if load_pane_mapping && [[ "$LAYOUT_TYPE" == "hierarchical" ]]; then
                echo "$session_name:0.$MANAGER_PANE"
            else
                echo "$session_name:0.0"  # 従来レイアウトではmanagerは常に0
            fi
            return 0
            ;;
        "broadcast")
            echo "broadcast"
            return 0
            ;;
        dev[0-9]|dev1[0-2])  # dev0-dev12 まで対応
            local dev_num="${agent#dev}"
            
            # 階層レイアウトでは動的にペイン番号を解決
            if load_pane_mapping && [[ "$LAYOUT_TYPE" == "hierarchical" ]]; then
                IFS=',' read -ra dev_panes <<< "$DEVELOPER_PANES"
                local dev_index=$dev_num
                
                if [[ $dev_index -ge 0 && $dev_index -lt ${#dev_panes[@]} ]]; then
                    echo "$session_name:0.${dev_panes[$dev_index]}"
                    return 0
                else
                    return 1  # 指定されたDeveloper番号が範囲外
                fi
            else
                # 従来レイアウトではdev0=ペイン2, dev1=ペイン3, ... 
                local pane_num=$((dev_num + 2))
                echo "$session_name:0.$pane_num"
                return 0
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# メイン処理
main() {
    # 引数チェック
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi
    
    # --listオプション
    if [[ "$1" == "--list" ]]; then
        show_agents
        exit 0
    fi
    
    # --detectオプション
    if [[ "$1" == "--detect" ]]; then
        detect_panes
        exit 0
    fi
    
    if [[ $# -lt 2 ]]; then
        show_usage
        exit 1
    fi
    
    local agent="$1"
    local message="$2"
    
    # ブロードキャスト処理
    if [[ "$agent" == "broadcast" ]]; then
        broadcast_message "$message"
        return $?
    fi
    
    # 送信先の決定
    local target
    target=$(resolve_target "$agent")
    
    if [[ $? -ne 0 ]]; then
        echo "❌ エラー: 無効なエージェント名 '$agent'"
        echo "利用可能エージェント: $0 --list"
        exit 1
    fi
    
    # セッション存在確認
    local session
    if [[ "$agent" == "ceo" ]]; then
        # CEOの場所を確認
        if load_pane_mapping && [[ "$LAYOUT_TYPE" == "hierarchical" ]]; then
            session=$(detect_active_session)  # 階層レイアウトでは検出されたセッション
        else
            session=$(detect_active_session)   # 現在の構成では同じセッション内
        fi
    else
        session=$(detect_active_session)
    fi
    
    if ! check_session "$session"; then
        exit 1
    fi
    
    # メッセージ送信
    if send_enhanced_message "$target" "$message" "$agent"; then
        # ログ記録
        log_message "$agent" "$message"
        
        echo ""
        echo "🎯 メッセージ詳細:"
        echo "   宛先: $agent ($target)"
        echo "   内容: \"$message\""
        echo "   ログ: logs/communication.log に記録済み"
        
        return 0
    else
        echo "❌ メッセージ送信に失敗しました"
        return 1
    fi
}

# ========================================
# 🏢 階層的組織管理システム - 統合機能
# ========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HIERARCHICAL_LOG_FILE="$SCRIPT_DIR/logs/hierarchical-tasks.log"
REPORT_FILE="$SCRIPT_DIR/logs/development-reports.log"

# 階層的ログ出力
h_log_info() { echo -e "\033[36m[INFO]\033[0m $1" | tee -a "$HIERARCHICAL_LOG_FILE"; }
h_log_success() { echo -e "\033[32m[SUCCESS]\033[0m $1" | tee -a "$HIERARCHICAL_LOG_FILE"; }
h_log_error() { echo -e "\033[31m[ERROR]\033[0m $1" | tee -a "$HIERARCHICAL_LOG_FILE"; }

# 動的チーム構成検出機能
detect_team_configuration() {
    local active_sessions=($(tmux list-sessions -F "#{session_name}" 2>/dev/null))
    
    for session in "${active_sessions[@]}"; do
        case "$session" in
            "claude-team-2devs")
                echo "2devs"
                return 0
                ;;
            "claude-team-4devs")
                echo "4devs"
                return 0
                ;;
            "claude-team-6devs")
                echo "6devs"
                return 0
                ;;
        esac
    done
    
    # フォールバック: 最も大きいセッションを検出
    if [[ " ${active_sessions[@]} " =~ " claude-team-6devs " ]]; then
        echo "6devs"
    elif [[ " ${active_sessions[@]} " =~ " claude-team-4devs " ]]; then
        echo "4devs"
    elif [[ " ${active_sessions[@]} " =~ " claude-team-2devs " ]]; then
        echo "2devs"
    else
        echo "unknown"
    fi
}

# 組織メンバー定義 (動的構成対応)
get_cto_members() {
    local config=$(detect_team_configuration)
    
    case "$config" in
        "2devs")
            echo "claude-team-2devs:1:CEO-Executive-Director"
            ;;
        "4devs")
            echo "claude-team-4devs:1:CEO-Executive-Director"
            ;;
        "6devs")
            echo "claude-team-6devs:1:CEO-Executive-Director"
            ;;
        *)
            echo "unknown:1:CEO-Executive-Director"
            ;;
    esac
}

get_manager_members() {
    local config=$(detect_team_configuration)
    
    case "$config" in
        "2devs")
            echo "claude-team-2devs:0:Manager-Small-Team"
            ;;
        "4devs")
            echo "claude-team-4devs:0:Manager-Medium-Team"
            ;;
        "6devs")
            echo "claude-team-6devs:0:Manager-Large-Team"
            ;;
        *)
            echo "unknown:0:Manager-Unknown-Team"
            ;;
    esac
}

get_developer_members() {
    local config=$(detect_team_configuration)
    
    case "$config" in
        "2devs")
            echo "claude-team-2devs:2:Dev0-Frontend-UI💻"
            echo "claude-team-2devs:3:Dev1-Backend-API⚙️"
            ;;
        "4devs")
            echo "claude-team-4devs:2:Dev0-Frontend-UI💻"
            echo "claude-team-4devs:3:Dev1-Backend-API⚙️"
            echo "claude-team-4devs:4:Dev2-QA-Test🔒"
            echo "claude-team-4devs:5:Dev3-Infrastructure-DevOps🧪"
            ;;
        "6devs")
            echo "claude-team-6devs:2:Dev0-Frontend-UI💻"
            echo "claude-team-6devs:3:Dev1-Backend-API⚙️"
            echo "claude-team-6devs:4:Dev2-QA-Test🔒"
            echo "claude-team-6devs:5:Dev3-Infrastructure-DevOps🧪"
            echo "claude-team-6devs:6:Dev4-Database-Design🚀"
            echo "claude-team-6devs:7:Dev5-UI-UX-Quality📊"
            ;;
        *)
            echo "unknown:2:Developer-Unknown"
            ;;
    esac
}

get_all_members() {
    get_cto_members
    get_manager_members
    get_developer_members
}

# 階層的メッセージ送信
send_hierarchical_message() {
    local session="$1"
    local pane="$2"
    local role="$3"
    local message="$4"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if ! tmux has-session -t "$session" 2>/dev/null; then
        h_log_error "セッション '$session' が見つかりません"
        return 1
    fi
    
    h_log_info "送信中: $role ($session:$pane) へ"
    
    local formatted_message="【$timestamp】$message

担当役割: $role
指示者: システム自動分配
対応要求: 即座に作業を開始し、完了後に報告してください"
    
    # プロンプトクリアしてメッセージ送信
    tmux send-keys -t "$session:$pane" C-c 2>/dev/null
    sleep 0.3
    tmux send-keys -t "$session:$pane" C-u 2>/dev/null
    sleep 0.2
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        tmux send-keys -t "$session:$pane" "$line"
        tmux send-keys -t "$session:$pane" C-m
        sleep 0.1
    done <<< "$formatted_message"
    
    sleep 0.3
    echo "[$timestamp] $role ($session:$pane) <- $message" >> "$HIERARCHICAL_LOG_FILE"
    return 0
}

# CTO全体指示
cto_directive() {
    local directive="$1"
    if [[ -z "$directive" ]]; then
        h_log_error "CTO指示内容が指定されていません"
        return 1
    fi
    
    h_log_info "🏢 CTO全体指示開始: $directive"
    
    local success_count=0
    local total_count=0
    
    # Manager全員に指示
    while IFS=: read -r session pane role; do
        ((total_count++))
        local manager_directive="【CTO指示】$directive

役割: あなたはManagerとして、この指示をDeveloperチームに適切に分配し、進捗を管理してください。"
        
        if send_hierarchical_message "$session" "$pane" "$role" "$manager_directive"; then
            ((success_count++))
        fi
        sleep 0.5
    done < <(get_manager_members)
    
    # Developer全員にも同時通知
    while IFS=: read -r session pane role; do
        ((total_count++))
        local dev_directive="【CTO指示通知】$directive

役割: この指示はManagerを通じて具体的なタスクとして分配されます。準備を整えてお待ちください。"
        
        if send_hierarchical_message "$session" "$pane" "$role" "$dev_directive"; then
            ((success_count++))
        fi
        sleep 0.3
    done < <(get_developer_members)
    
    h_log_success "CTO指示完了: $success_count/$total_count メンバーに送信完了"
}

# Manager向けタスク分配
manager_task() {
    local task="$1"
    if [[ -z "$task" ]]; then
        h_log_error "Managerタスクが指定されていません"
        return 1
    fi
    
    h_log_info "📋 Manager向けタスク分配: $task"
    
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
    
    local manager_task_msg="【Manager専用タスク】$task

管理責任: このタスクを適切にDeveloperに分配し、進捗を監視してください。完了後はCTOに報告してください。"
    
    if send_hierarchical_message "$session" "$pane" "$role" "$manager_task_msg"; then
        echo "$current_index" > "$last_index_file"
        h_log_success "Managerタスク分配完了: $role に送信"
    fi
}

# Developer向けタスク分配
dev_assign() {
    local task="$1"
    if [[ -z "$task" ]]; then
        h_log_error "Developerタスクが指定されていません"
        return 1
    fi
    
    h_log_info "💻 Developer向けタスク分配: $task"
    
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
    
    local dev_task_msg="【開発タスク】$task

専門領域: あなたの専門性を活かして実装してください。完了後はManagerに詳細な実装報告をしてください。"
    
    if send_hierarchical_message "$session" "$pane" "$role" "$dev_task_msg"; then
        echo "$current_index" > "$last_index_file"
        h_log_success "Developerタスク分配完了: $role に送信"
    fi
}

# 専門分野別タスク分配
assign_specialized_task() {
    local specialty="$1"
    local task="$2"
    
    if [[ -z "$task" ]]; then
        h_log_error "タスク内容が指定されていません"
        return 1
    fi
    
    local config=$(detect_team_configuration)
    local target_pane=""
    local target_role=""
    local session_name="claude-team-$config"
    
    case "$specialty" in
        "frontend"|"ui")
            target_pane="2"
            target_role="Dev0-Frontend-UI💻"
            ;;
        "backend"|"api") 
            target_pane="3"
            target_role="Dev1-Backend-API⚙️"
            ;;
        "qa"|"test")
            if [[ "$config" == "2devs" ]]; then
                h_log_error "QA/Test専門担当は4 Developers以上の構成でのみ利用可能です"
                return 1
            fi
            target_pane="4"
            target_role="Dev2-QA-Test🔒"
            ;;
        "infra"|"devops")
            if [[ "$config" == "2devs" ]]; then
                h_log_error "Infrastructure/DevOps専門担当は4 Developers以上の構成でのみ利用可能です"
                return 1
            fi
            target_pane="5"
            target_role="Dev3-Infrastructure-DevOps🧪"
            ;;
        "database"|"design")
            if [[ "$config" != "6devs" ]]; then
                h_log_error "Database/Design専門担当は6 Developers構成でのみ利用可能です"
                return 1
            fi
            target_pane="6"
            target_role="Dev4-Database-Design🚀"
            ;;
        "ux"|"quality")
            if [[ "$config" != "6devs" ]]; then
                h_log_error "UI/UX/Quality専門担当は6 Developers構成でのみ利用可能です"
                return 1
            fi
            target_pane="7"
            target_role="Dev5-UI-UX-Quality📊"
            ;;
        *)
            h_log_error "不明な専門分野: $specialty"
            h_log_info "利用可能な専門分野: frontend|ui, backend|api, qa|test, infra|devops, database|design, ux|quality"
            return 1
            ;;
    esac
    
    local specialized_task="【$specialty専門タスク】$task

専門領域: あなたの$specialty専門性を最大限活用して実装してください。
担当者: $target_role"
    
    if send_hierarchical_message "$session_name" "$target_pane" "$target_role" "$specialized_task"; then
        h_log_success "$specialty専門タスク分配完了: $target_role に送信"
        return 0
    else
        h_log_error "タスク送信に失敗しました: $target_role"
        return 1
    fi
}

# 言語切替指示
language_switch() {
    h_log_info "🌐 全員日本語切替指示開始"
    
    local switch_message="【言語切替指示】日本語モードに切り替えてください

指示: 以下のコマンドを実行してください
1. 現在の作業を安全に保存
2. 日本語言語設定に変更
3. 準備完了後に「日本語切替完了」と報告"
    
    local success_count=0
    local total_count=0
    
    while IFS=: read -r session pane role; do
        ((total_count++))
        if send_hierarchical_message "$session" "$pane" "$role" "$switch_message"; then
            ((success_count++))
        fi
        sleep 0.2
    done < <(get_all_members)
    
    h_log_success "言語切替指示完了: $success_count/$total_count メンバーに送信"
}

# Developer報告収集
collect_reports() {
    h_log_info "📊 Developer報告収集開始"
    
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
        if send_hierarchical_message "$session" "$pane" "$role" "$report_request"; then
            ((success_count++))
        fi
        sleep 0.3
    done < <(get_developer_members)
    
    h_log_success "報告収集要求完了: $success_count 名のDeveloperに送信"
    
    send_hierarchical_message "manager" "1" "Manager-Report-Collector" "【報告収集開始】Developerからの進捗報告を収集し、統合レポートを作成してください"
}

# Manager統合報告作成
manager_report() {
    h_log_info "📈 Manager統合報告作成開始"
    
    local report_task="【統合報告作成】収集した全Developer報告を統合し、CTOに包括的な状況報告を作成してください

統合報告内容:
1. 全体プロジェクト進捗状況
2. 各専門分野の状況
3. 発生している課題・リスク
4. 必要なリソース・サポート
5. 次期計画・提案"
    
    send_hierarchical_message "manager" "2" "Manager-CTO-Reporter" "$report_task"
    h_log_success "Manager統合報告作成指示完了"
}

# 階層的組織状況表示
show_hierarchical_status() {
    local config=$(detect_team_configuration)
    local team_size=""
    local dev_count=0
    
    case "$config" in
        "2devs")
            team_size="小規模開発チーム (2 Developers)"
            dev_count=2
            ;;
        "4devs")
            team_size="中規模開発チーム (4 Developers)"
            dev_count=4
            ;;
        "6devs")
            team_size="大規模開発チーム (6 Developers) 🌟推奨"
            dev_count=6
            ;;
        *)
            team_size="不明な構成"
            dev_count=0
            ;;
    esac
    
    echo "🏢 階層的AI開発チーム - 組織状況"
    echo "================================="
    echo "📊 現在の構成: $team_size"
    echo "🎯 アクティブセッション: claude-team-$config"
    echo ""
    
    echo "👑 CEO (1名) - 全体統括・戦略決定"
    while IFS=: read -r session pane role; do
        echo "  • $session:$pane - $role"
    done < <(get_cto_members)
    
    echo ""
    echo "👔 Manager (1名) - プロジェクト管理・チーム調整"
    while IFS=: read -r session pane role; do
        echo "  • $session:$pane - $role"
    done < <(get_manager_members)
    
    echo ""
    echo "💻 Developer ($dev_count名) - 専門開発・実装作業"
    while IFS=: read -r session pane role; do
        echo "  • $session:$pane - $role"
    done < <(get_developer_members)
    
    echo ""
    echo "📋 構成パターン情報:"
    echo "  🔹 2 Developers: Dev0(Frontend/UI💻) + Dev1(Backend/API⚙️)"
    echo "  🔹 4 Developers: + Dev2(QA/Test🔒) + Dev3(Infra/DevOps🧪)"  
    echo "  🔹 6 Developers: + Dev4(DB/Design🚀) + Dev5(UX/Quality📊) 🌟推奨"
    
    echo ""
    echo "📊 実際のペイン構成:"
    echo "  • ペイン0: 👔 Manager (左上)"
    echo "  • ペイン1: 👑 CEO (左下)"  
    echo "  • ペイン2-7: 💻 Dev0-Dev5 (右側6段)"
    echo "  • Claude AI 自動起動・認証完了"
    
    echo ""
    echo "📊 最近の階層的活動 (直近5件):"
    if [[ -f "$HIERARCHICAL_LOG_FILE" ]]; then
        tail -5 "$HIERARCHICAL_LOG_FILE" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  活動履歴なし"
    fi
}

# ========================================
# メイン処理の拡張
# ========================================

# メイン処理
main() {
    # 引数チェック
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi
    
    # 階層的システムコマンド処理
    case "${1:-}" in
        "cto-directive")
            cto_directive "$2"
            exit $?
            ;;
        "manager-task")
            manager_task "$2"
            exit $?
            ;;
        "dev-assign")
            dev_assign "$2"
            exit $?
            ;;
        "frontend"|"ui")
            assign_specialized_task "frontend" "$2"
            exit $?
            ;;
        "backend"|"api")
            assign_specialized_task "backend" "$2"
            exit $?
            ;;
        "qa"|"test")
            assign_specialized_task "qa" "$2"
            exit $?
            ;;
        "infra"|"devops")
            assign_specialized_task "infra" "$2"
            exit $?
            ;;
        "database"|"design")
            assign_specialized_task "database" "$2"
            exit $?
            ;;
        "ux"|"quality")
            assign_specialized_task "ux" "$2"
            exit $?
            ;;
        "language-switch")
            language_switch
            exit $?
            ;;
        "collect-reports")
            collect_reports
            exit $?
            ;;
        "manager-report")
            manager_report
            exit $?
            ;;
        "--status")
            show_hierarchical_status
            exit 0
            ;;
        "--list")
            show_agents
            exit 0
            ;;
        "--detect")
            detect_panes
            exit 0
            ;;
        "--help"|"-h")
            show_usage
            exit 0
            ;;
    esac
    
    # 従来の処理を継続
    if [[ $# -lt 2 ]]; then
        show_usage
        exit 1
    fi
    
    local agent="$1"
    local message="$2"
    
    # ブロードキャスト処理
    if [[ "$agent" == "broadcast" ]]; then
        broadcast_message "$message"
        return $?
    fi
    
    # 送信先の決定
    local target
    target=$(resolve_target "$agent")
    
    if [[ $? -ne 0 ]]; then
        echo "❌ エラー: 無効なエージェント名 '$agent'"
        echo "利用可能エージェント: $0 --list"
        exit 1
    fi
    
    # セッション存在確認
    local session
    if [[ "$agent" == "ceo" ]]; then
        if load_pane_mapping && [[ "$LAYOUT_TYPE" == "hierarchical" ]]; then
            session=$(detect_active_session)
        else
            session=$(detect_active_session)
        fi
    else
        session=$(detect_active_session)
    fi
    
    if ! check_session "$session"; then
        exit 1
    fi
    
    # メッセージ送信
    if send_enhanced_message "$target" "$message" "$agent"; then
        log_message "$agent" "$message"
        
        echo ""
        echo "🎯 メッセージ詳細:"
        echo "   宛先: $agent ($target)"
        echo "   内容: \"$message\""
        echo "   ログ: logs/communication.log に記録済み"
        
        return 0
    else
        echo "❌ メッセージ送信に失敗しました"
        return 1
    fi
}

main "$@"