#!/bin/bash

# 🚀 Microsoft 365 Python Migration Project - Team Messaging System

# Instructions directory
INSTRUCTIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/instructions"

# 使用方法表示
show_usage() {
    cat << EOF
🏢 Microsoft 365 Python Migration Project - Team Communication System

📋 プロジェクト概要:
  PowerShell 26機能システム → Python + FastAPI + React 完全移行
  エンタープライズ向けMicrosoft 365管理ツール群の最新化

👥 開発チーム構成:
  1) 5-Person Team - 標準移行チーム (CTO + Product Manager + 3 Python Developers)
  2) 8-Person Team - 大規模移行チーム (CTO + Product Manager + 6 Python Developers) 🌟推奨

組織構造:
  CTO (1名)             - 技術戦略・Python移行アーキテクチャ決定
  Product Manager (1名)  - 移行プロジェクト管理・進捗調整
  Python Developers (3-6名) - PowerShell→Python専門実装

基本使用方法:
  $0 [エージェント名] [メッセージ]
  $0 --list / --detect / --status

Python移行プロジェクト管理コマンド:
  $0 cto-directive "技術戦略指示"       # CTOから技術方針・アーキテクチャ指示
  $0 manager-task "移行管理タスク"      # Product Manager向けタスク分配
  $0 dev-assign "Python開発タスク"      # Python Developer向けタスク分配
  $0 start-claude [役職名]               # 指定役職でClaude起動（移行context付き）
  $0 context7-integration               # Context7統合機能テスト
  $0 collect-reports                     # Python Developer報告収集
  $0 manager-report                      # Product Manager統合報告作成
  $0 send-to-cto "報告内容"              # CTOへの報告送信
  $0 manager-to-all-devs "指示内容"      # Manager→全Developer一括送信
  $0 reset-all-prompts                  # 全ペイン Claude Code プロンプトリセット
  $0 reset-prompt [エージェント名]       # 個別ペイン プロンプトリセット
  $0 instant [エージェント名] "メッセージ" # 即時伝達（超高速送信）
  $0 instant-broadcast "メッセージ"      # 即時一斉伝達（全Developer同時）

Python移行専門タスク分配:
  $0 frontend|ui "PowerShell GUI→React移行"      # Dev0: PowerShell Forms→React+TypeScript 💻
  $0 backend|api "PowerShell Script→Python移行"  # Dev1: PowerShell→Python+FastAPI ⚙️
  $0 qa|test "PowerShell Test→Python移行"        # Dev2: PowerShell Test→pytest移行 🔒
  $0 infra|devops "PowerShell実行環境→Python移行" # Dev3: PowerShell環境→Python+Docker 🧪
  $0 database|design "PowerShell CSV→PostgreSQL移行" # Dev4: PowerShell Data→PostgreSQL 🚀
  $0 ux|quality "PowerShell UI→React UX移行"     # Dev5: PowerShell UI→React UX品質 📊

役職別エージェント指定:
  cto / manager / developer             # セッション単位
  dev0-5                                # Python Developer ペイン単位
  broadcast                             # 全Python移行チーム同時送信

使用例:
  $0 cto-directive "Microsoft 365 Python移行プロジェクト開始準備を開始してください"
  $0 frontend "PowerShell Windows Forms→React+TypeScript移行を実装してください"
  $0 start-claude manager                    # Product Manager用context付きでClaude起動
  $0 start-claude cto                        # CTO用context付きでClaude起動
  $0 start-claude dev0                       # Python Developer用context付きでClaude起動
  $0 context7-integration                    # Context7統合機能テスト
  $0 collect-reports
  $0 manager "PowerShell→Python移行進捗状況を確認してください"
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
    # Microsoft 365 Python Migration Project セッションを検索
    local sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^MicrosoftProductTools-Python")
    
    if [[ -n "$sessions" ]]; then
        # 複数ある場合は最初の一つを使用
        echo "$sessions" | head -n1
        return 0
    fi
    
    # Microsoft365-Python-Migration パターンも検索
    local sessions2=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^Microsoft365-Python-Migration")
    
    if [[ -n "$sessions2" ]]; then
        echo "$sessions2" | head -n1
        return 0
    fi
    
    # claude-team-で始まるセッションもチェック（後方互換性）
    local claude_sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^claude-team-")
    
    if [[ -n "$claude_sessions" ]]; then
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
        echo "❌ 有効なMicrosoft 365 Python Migration Projectセッションが見つかりません"
        echo "💡 利用可能セッション:"
        tmux list-sessions -F "  - #{session_name}" 2>/dev/null || echo "  (セッションが存在しません)"
        echo "ℹ️  推奨セッション名: MicrosoftProductTools-Python-5team または Microsoft365-Python-Migration"
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

# 緊急指示メッセージ判定機能
is_urgent_message() {
    local message="$1"
    
    # 緊急指示キーワードパターン
    local urgent_patterns=(
        "緊急指示"
        "緊急連絡"
        "緊急事態" 
        "緊急対応"
        "緊急停止"
        "緊急会議"
        "緊急報告"
        "緊急確認"
        "緊急実行"
        "緊急修正"
        "即座"
        "即時"
        "直ちに"
        "至急"
        "URGENT"
        "EMERGENCY"
        "CRITICAL"
        "【緊急】"
        "【URGENT】"
        "【至急】"
        "【即時】"
        "🚨"
        "⚡"
        "🔥"
    )
    
    # パターンマッチング
    for pattern in "${urgent_patterns[@]}"; do
        if [[ "$message" == *"$pattern"* ]]; then
            return 0  # 緊急指示と判定
        fi
    done
    
    return 1  # 通常メッセージ
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
    
    # 緊急指示自動判定
    local instant_mode="${INSTANT_DELIVERY:-false}"
    
    # メッセージ内容による自動即時伝達判定
    if [[ "$instant_mode" == "false" ]]; then
        if is_urgent_message "$message"; then
            instant_mode="true"
            echo "🚨 緊急指示を検出 - 自動的に即時伝達モードに切り替えます"
        fi
    fi
    
    if [[ "$instant_mode" == "true" ]]; then
        # 即時伝達モード: 最小限のクリア
        tmux send-keys -t "$target" C-c
        sleep 0.1
        tmux send-keys -t "$target" C-u
        sleep 0.1
    else
        # 通常モード: 完全クリア
        # Ctrl+C で現在の入力を中断
        tmux send-keys -t "$target" C-c
        sleep 0.5
        
        # ESC で Claude Code のモードをリセット  
        tmux send-keys -t "$target" Escape
        sleep 0.3
        
        # Ctrl+U で入力行全体をクリア
        tmux send-keys -t "$target" C-u
        sleep 0.3
        
        # Ctrl+L で画面をクリア（オプション）
        tmux send-keys -t "$target" C-l
        sleep 0.3
        
        # 追加の確実なクリア（Claude Code 対応）
        tmux send-keys -t "$target" C-c
        sleep 0.2
    fi
    
    # 3. メッセージ送信
    if [[ "$instant_mode" == "true" ]]; then
        # 即時伝達モード: 最短時間で送信
        if [[ "$message" == *$'\n'* ]]; then
            while IFS= read -r line || [[ -n "$line" ]]; do
                tmux send-keys -t "$target" "$line"
                tmux send-keys -t "$target" C-m
                sleep 0.05  # 最小待機時間
            done <<< "$message"
        else
            tmux send-keys -t "$target" "$message"
            sleep 0.1
            tmux send-keys -t "$target" C-m
        fi
        sleep 0.2  # 即時完了
        
        # 即時伝達では送信後クリアなし（高速化）
    else
        # 通常モード: 確実性重視
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
        sleep 0.5
        
        # 4. 送信後の追加クリア（メッセージ残留防止）
        tmux send-keys -t "$target" C-u
        sleep 0.2
    fi
    
    echo "✅ 送信完了: $agent_name に自動実行されました"
    return 0
}

# ブロードキャスト送信
broadcast_message() {
    local message="$1"
    
    local session_name=$(detect_active_session)
    if [[ $? -ne 0 || -z "$session_name" ]]; then
        echo "❌ 有効なMicrosoft Product Management Toolsセッションが見つかりません"
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
        "ceo"|"cto")
            # CTOとCEOは同じペイン（ペイン1）
            echo "$session_name:0.1"
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
    local session_name=$(detect_active_session)
    
    # Microsoft 365 Python Migration Project session structure
    echo "$session_name:1:CTO-Technical-Leadership"
}

get_manager_members() {
    local session_name=$(detect_active_session)
    
    # Microsoft 365 Python Migration Project session structure
    echo "$session_name:0:Product-Manager-Migration-Coordination"
}

get_developer_members() {
    local session_name=$(detect_active_session)
    
    # 現在のセッションのペイン数を取得して動的に決定
    local pane_count=$(tmux list-panes -t "$session_name" -F "#{pane_index}" | wc -l)
    
    # ペイン2以降がDeveloper (Manager=0, CTO=1を除く)
    for ((i=2; i<pane_count; i++)); do
        local dev_num=$((i-2))
        case $dev_num in
            0) echo "$session_name:$i:Python-Dev0-PowerShell-Forms-to-React-Migration💻" ;;
            1) echo "$session_name:$i:Python-Dev1-PowerShell-Scripts-to-Python-FastAPI-Migration⚙️" ;;
            2) echo "$session_name:$i:Python-Dev2-PowerShell-Tests-to-pytest-Migration🔒" ;;
            3) echo "$session_name:$i:Python-Dev3-PowerShell-Environment-to-Docker-Migration🧪" ;;
            4) echo "$session_name:$i:Python-Dev4-PowerShell-CSV-to-PostgreSQL-Migration🚀" ;;
            5) echo "$session_name:$i:Python-Dev5-PowerShell-UI-to-React-UX-Migration📊" ;;
            *) echo "$session_name:$i:Python-Developer-Migration-Specialist" ;;
        esac
    done
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
    
    # 緊急指示自動判定（階層的メッセージ用）
    local instant_mode="false"
    if is_urgent_message "$message"; then
        instant_mode="true"
        echo "🚨 緊急指示を検出 - 階層的メッセージも即時伝達モードで送信"
    fi
    
    # 統一された送信表示フォーマット
    echo "📤 送信中: $role へメッセージを送信..."
    
    local formatted_message="【$timestamp】$message

担当役割: $role
指示者: システム自動分配
対応要求: 即座に作業を開始し、完了後に報告してください"
    
    # プロンプトクリアしてメッセージ送信
    local target="$session:0.$pane"
    
    if [[ "$instant_mode" == "true" ]]; then
        # 即時伝達モード
        tmux send-keys -t "$target" C-c 2>/dev/null
        sleep 0.1
        tmux send-keys -t "$target" C-u 2>/dev/null
        sleep 0.1
        
        while IFS= read -r line || [[ -n "$line" ]]; do
            tmux send-keys -t "$target" "$line"
            tmux send-keys -t "$target" C-m
            sleep 0.05
        done <<< "$formatted_message"
        
        sleep 0.2
    else
        # 通常モード
        tmux send-keys -t "$target" C-c 2>/dev/null
        sleep 0.3
        tmux send-keys -t "$target" C-u 2>/dev/null
        sleep 0.2
        
        while IFS= read -r line || [[ -n "$line" ]]; do
            tmux send-keys -t "$target" "$line"
            tmux send-keys -t "$target" C-m
            sleep 0.1
        done <<< "$formatted_message"
        
        sleep 0.3
    fi
    
    # 統一された送信完了表示
    echo "✅ 送信完了: $role に自動実行されました"
    
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

# Manager→全Developer一括送信
manager_to_all_devs() {
    local message="$1"
    if [[ -z "$message" ]]; then
        h_log_error "送信メッセージが指定されていません"
        return 1
    fi
    
    h_log_info "👔 Manager→全Developer一括送信開始: $message"
    
    local success_count=0
    local total_count=0
    
    echo ""
    echo "📡 Manager指示を全Developerに送信中..."
    echo ""
    
    # 全Developerに送信
    while IFS=: read -r session pane role; do
        ((total_count++))
        
        # dev0, dev1, dev2 形式の表示名を作成
        local dev_num=$((pane-2))
        local display_name="dev$dev_num"
        
        local manager_message="【Manager指示】$message

指示者: Product Manager
対象: $role
対応要求: 即座に作業を開始し、完了後にManagerに報告してください。
受信時刻: $(date '+%Y-%m-%d %H:%M:%S')"
        
        # 統一フォーマットで表示・送信
        local target="$session:0.$pane"
        if send_enhanced_message "$target" "$manager_message" "$display_name"; then
            ((success_count++))
            log_message "$display_name" "$manager_message"
        else
            echo "❌ 送信失敗: $display_name"
        fi
        
        echo ""
        sleep 0.3
    done < <(get_developer_members)
    
    echo "🎯 Manager→Developer一括送信完了:"
    echo "   送信成功: $success_count/$total_count Developer"
    echo "   メッセージ: \"$message\""
    echo "   ログ: logs/communication.log に記録済み"
    
    h_log_success "Manager→全Developer送信完了: $success_count/$total_count 送信成功"
}

# Launch Claude with context file for specific role
launch_claude_with_context() {
    local target_role="$1"
    local target_pane="$2"
    local session="$3"
    
    # Determine context file based on role
    local context_file=""
    case "$target_role" in
        *"Manager"*|*"manager"*)
            context_file="$INSTRUCTIONS_DIR/manager.md"
            ;;
        *"CEO"*|*"CTO"*|*"cto"*)
            context_file="$INSTRUCTIONS_DIR/cto.md"
            ;;
        *"Dev"*|*"dev"*|*"Developer"*|*"developer"*)
            context_file="$INSTRUCTIONS_DIR/developer.md"
            ;;
        *)
            context_file="$INSTRUCTIONS_DIR/developer.md"  # Default to developer
            ;;
    esac
    
    # Check if context file exists and start Claude with context
    if [[ ! -f "$context_file" ]]; then
        h_log_warning "Context file not found: $context_file"
        h_log_info "Starting Claude without context file"
        tmux send-keys -t "$session:$target_pane" "claude --dangerously-skip-permissions" C-m
        return 0
    fi
    
    h_log_info "Starting Claude with context: $context_file"
    tmux send-keys -t "$session:$target_pane" "claude --dangerously-skip-permissions \"\$(cat \"$context_file\")\"" C-m
    
    return 0
}

# 専門分野別タスク分配
assign_specialized_task() {
    local specialty="$1"
    local task="$2"
    
    if [[ -z "$task" ]]; then
        h_log_error "タスク内容が指定されていません"
        return 1
    fi
    
    local session_name=$(detect_active_session)
    if [[ $? -ne 0 || -z "$session_name" ]]; then
        h_log_error "有効なセッションが見つかりません"
        return 1
    fi
    
    local target_pane=""
    local target_role=""
    
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
            target_pane="4"
            target_role="Dev2-QA-Test🔒"
            ;;
        "infra"|"devops")
            target_pane="3"
            target_role="Dev1-Infrastructure-DevOps🧪"
            ;;
        "database"|"design")
            target_pane="4"
            target_role="Dev2-Database-Design🚀"
            ;;
        "ux"|"quality")
            target_pane="2"
            target_role="Dev0-UI-UX-Quality📊"
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
    
    local target="$session_name:0.$target_pane"
    
    if send_enhanced_message "$target" "$specialized_task" "$target_role"; then
        h_log_success "$specialty専門タスク分配完了: $target_role に送信"
        log_message "$target_role" "$specialized_task"
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
    
    local session_name=$(detect_active_session)
    send_hierarchical_message "$session_name" "0" "Manager-Report-Collector" "【報告収集開始】Developerからの進捗報告を収集し、統合レポートを作成してください"
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
5. 次期計画・提案

完了後: ./tmux/send-message.sh cto \"【Manager統合報告】\" で報告を送信してください"
    
    local session_name=$(detect_active_session)
    send_hierarchical_message "$session_name" "0" "Manager-CTO-Reporter" "$report_task"
    h_log_success "Manager統合報告作成指示完了"
}

# 全ペイン Claude Code プロンプトリセット機能
reset_all_prompts() {
    echo "🔄 全ペイン Claude Code プロンプトリセット開始..."
    
    local session_name=$(detect_active_session)
    if [[ $? -ne 0 || -z "$session_name" ]]; then
        echo "❌ 有効なセッションが見つかりません"
        return 1
    fi
    
    local success_count=0
    local total_count=0
    
    # Manager, CTO, 全Developer をリセット
    local all_panes=(0 1 2 3 4)  # ペイン0-4
    
    for pane in "${all_panes[@]}"; do
        ((total_count++))
        local target="$session_name:0.$pane"
        local role=""
        
        case $pane in
            0) role="Manager" ;;
            1) role="CTO" ;;
            2) role="Dev0" ;;
            3) role="Dev1" ;;
            4) role="Dev2" ;;
            *) role="Unknown" ;;
        esac
        
        echo "🔄 リセット中: $role (ペイン$pane)"
        
        if reset_single_prompt "$target" "$role"; then
            ((success_count++))
            echo "✅ リセット完了: $role"
        else
            echo "❌ リセット失敗: $role"
        fi
        
        sleep 0.5
    done
    
    echo ""
    echo "🎯 プロンプトリセット完了:"
    echo "   成功: $success_count/$total_count ペイン"
    echo "   セッション: $session_name"
    
    return 0
}

# 単一ペインのプロンプトリセット
reset_single_prompt() {
    local target="$1"
    local role="$2"
    
    # 1. 強制中断
    tmux send-keys -t "$target" C-c 2>/dev/null
    sleep 0.3
    
    # 2. ESC でモードリセット
    tmux send-keys -t "$target" Escape 2>/dev/null
    sleep 0.2
    
    # 3. 入力行クリア
    tmux send-keys -t "$target" C-u 2>/dev/null
    sleep 0.2
    
    # 4. 画面クリア
    tmux send-keys -t "$target" C-l 2>/dev/null
    sleep 0.2
    
    # 5. 追加の確実なクリア
    tmux send-keys -t "$target" C-c 2>/dev/null
    sleep 0.2
    tmux send-keys -t "$target" C-u 2>/dev/null
    sleep 0.2
    
    # 6. 空のエンター（プロンプト再表示）
    tmux send-keys -t "$target" C-m 2>/dev/null
    sleep 0.3
    
    return 0
}

# 即時ブロードキャスト機能
instant_broadcast_message() {
    local message="$1"
    
    local session_name=$(detect_active_session)
    if [[ $? -ne 0 || -z "$session_name" ]]; then
        echo "❌ 有効なセッションが見つかりません"
        return 1
    fi
    
    local success_count=0
    local total_count=0
    
    echo "⚡ 即時一斉伝達開始..."
    echo ""
    
    # 全Developer（ペイン2-4）に即時送信
    local all_panes=(2 3 4)
    
    for pane in "${all_panes[@]}"; do
        ((total_count++))
        local target="$session_name:0.$pane"
        local dev_num=$((pane-2))
        local display_name="dev$dev_num"
        
        # 即時送信（並列実行）
        echo "⚡ 即時送信: $display_name"
        
        if send_enhanced_message "$target" "$message" "$display_name"; then
            ((success_count++))
            log_message "$display_name" "$message"
        fi
        
        # 即時送信のため待機時間なし
    done
    
    echo ""
    echo "⚡ 即時一斉伝達完了:"
    echo "   送信成功: $success_count/$total_count Developer"
    echo "   送信時間: 約0.5秒"
    echo "   メッセージ: \"$message\""
    
    return 0
}

# 個別ペインリセット機能
reset_prompt() {
    local agent="$1"
    if [[ -z "$agent" ]]; then
        echo "❌ エラー: リセット対象を指定してください"
        echo "使用方法: $0 reset-prompt [manager|cto|dev0|dev1|dev2]"
        return 1
    fi
    
    echo "🔄 個別プロンプトリセット: $agent"
    
    local target
    target=$(resolve_target "$agent")
    
    if [[ $? -ne 0 ]]; then
        echo "❌ エラー: 無効なエージェント名 '$agent'"
        return 1
    fi
    
    if reset_single_prompt "$target" "$agent"; then
        echo "✅ プロンプトリセット完了: $agent ($target)"
        return 0
    else
        echo "❌ プロンプトリセット失敗: $agent"
        return 1
    fi
}

# CTOへの報告送信機能
send_to_cto() {
    local report="$1"
    if [[ -z "$report" ]]; then
        h_log_error "CTO報告内容が指定されていません"
        return 1
    fi
    
    h_log_info "📤 CTO への報告送信開始"
    
    local session_name=$(detect_active_session)
    local cto_target="$session_name:0.1"
    
    local cto_report="【進捗報告受信】$report

受信時刻: $(date '+%Y-%m-%d %H:%M:%S')
送信者: プロジェクト管理システム
対応要求: 内容を確認し、必要に応じて指示を発出してください"
    
    if send_enhanced_message "$cto_target" "$cto_report" "CTO-Technical-Leadership"; then
        h_log_success "CTO報告送信完了"
        log_message "CTO-Technical-Leadership" "$cto_report"
        return 0
    else
        h_log_error "CTO報告送信に失敗しました"
        return 1
    fi
}

# 階層的組織状況表示
show_hierarchical_status() {
    local session_name=$(detect_active_session)
    local team_size=""
    local dev_count=0
    
    # Microsoft 365 Python Migration Project session structure
    case "$session_name" in
        "MicrosoftProductTools-Python-5team")
            team_size="標準Python移行チーム (5人構成: CTO + Product Manager + 3 Python Developers)"
            dev_count=3
            ;;
        "MicrosoftProductTools-Python-8team")
            team_size="大規模Python移行チーム (8人構成: CTO + Product Manager + 6 Python Developers) 🌟推奨"
            dev_count=6
            ;;
        "Microsoft365-Python-Migration")
            team_size="Microsoft 365 Python移行専用チーム (8人構成) 🌟推奨"
            dev_count=6
            ;;
        *)
            team_size="Microsoft 365 Python移行チーム (構成検出中)"
            dev_count=3
            ;;
    esac
    
    echo "🚀 Microsoft 365 Python Migration Project - チーム状況"
    echo "================================================================="
    echo "📊 現在の構成: $team_size"
    echo "🎯 アクティブセッション: $session_name"
    echo "📋 プロジェクト: PowerShell 26機能システム → Python + FastAPI + React 完全移行"
    echo ""
    
    echo "💼 CTO (1名) - 技術戦略・Python移行アーキテクチャ決定"
    while IFS=: read -r session pane role; do
        echo "  • $session:$pane - $role"
    done < <(get_cto_members)
    
    echo ""
    echo "👔 Product Manager (1名) - 移行プロジェクト管理・進捗調整"
    while IFS=: read -r session pane role; do
        echo "  • $session:$pane - $role"
    done < <(get_manager_members)
    
    echo ""
    echo "💻 Python Developers ($dev_count名) - PowerShell→Python専門実装"
    while IFS=: read -r session pane role; do
        echo "  • $session:$pane - $role"
    done < <(get_developer_members)
    
    echo ""
    echo "📋 Python移行専門分野:"
    echo "  🔹 Dev0: PowerShell Windows Forms → React + TypeScript 移行💻"
    echo "  🔹 Dev1: PowerShell Scripts → Python + FastAPI 移行⚙️"
    echo "  🔹 Dev2: PowerShell Tests → pytest 移行🔒"
    if [[ $dev_count -ge 4 ]]; then
        echo "  🔹 Dev3: PowerShell実行環境 → Python + Docker 移行🧪"
    fi
    if [[ $dev_count -ge 5 ]]; then
        echo "  🔹 Dev4: PowerShell CSV/JSON → PostgreSQL 移行🚀"
    fi
    if [[ $dev_count -ge 6 ]]; then
        echo "  🔹 Dev5: PowerShell GUI → React UX品質管理 移行📊"
    fi
    
    echo ""
    echo "🌟 Context7統合機能:"
    echo "  • 最新Python技術情報自動取得"
    echo "  • FastAPI実装パターン参照"
    echo "  • React移行ベストプラクティス"
    echo "  • PowerShell→Python移行トラブルシューティング"
    
    echo ""
    echo "📊 実際のペイン構成:"
    echo "  • ペイン0: 👔 Product Manager (左上)"
    echo "  • ペイン1: 💼 CTO (左下)"  
    echo "  • ペイン2-7: 💻 Python Dev0-Dev5 (右側6段)"
    echo "  • Claude AI 自動起動・認証完了 (Python移行context付き)"
    
    echo ""
    echo "📊 最近のPython移行活動 (直近5件):"
    if [[ -f "$HIERARCHICAL_LOG_FILE" ]]; then
        tail -5 "$HIERARCHICAL_LOG_FILE" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  移行活動履歴なし"
    fi
}

# Get pane by role for Claude startup
get_pane_by_role() {
    local role="$1"
    local session_name=$(detect_active_session)
    
    case "$role" in
        "manager")
            echo "$session_name:0:Product-Manager-Migration-Coordination"
            ;;
        "cto")
            echo "$session_name:1:CTO-Technical-Leadership"
            ;;
        "dev0")
            echo "$session_name:2:Python-Dev0-PowerShell-Forms-to-React-Migration"
            ;;
        "dev1")
            echo "$session_name:3:Python-Dev1-PowerShell-Scripts-to-Python-FastAPI-Migration"
            ;;
        "dev2")
            echo "$session_name:4:Python-Dev2-PowerShell-Tests-to-pytest-Migration"
            ;;
        "dev3")
            echo "$session_name:5:Python-Dev3-PowerShell-Environment-to-Docker-Migration"
            ;;
        "dev4")
            echo "$session_name:6:Python-Dev4-PowerShell-CSV-to-PostgreSQL-Migration"
            ;;
        "dev5")
            echo "$session_name:7:Python-Dev5-PowerShell-UI-to-React-UX-Migration"
            ;;
        *)
            return 1
            ;;
    esac
}

# Context7 Integration Test Function
context7_integration_test() {
    h_log_info "🌟 Context7統合機能テスト開始"
    
    local test_message="【Context7統合テスト】Microsoft 365 Python移行プロジェクトでのContext7統合機能をテストしています

Context7機能:
- 最新のPython技術情報を自動取得
- FastAPI実装パターンの参照
- React移行のベストプラクティス
- PowerShell→Python移行のトラブルシューティング

テスト内容:
1. Context7 API接続確認
2. 最新技術ドキュメント取得
3. 移行パターン情報収集
4. 自動化コード生成支援

このテストが完了したら、Context7機能を使用して最新情報を取得してください。
例: 「FastAPI SQLAlchemy 設定方法」や「React TypeScript 移行パターン」など"
    
    local success_count=0
    local total_count=0
    
    # 全メンバーに Context7 テストメッセージを送信
    while IFS=: read -r session pane role; do
        ((total_count++))
        if send_hierarchical_message "$session" "$pane" "$role" "$test_message"; then
            ((success_count++))
        fi
        sleep 0.3
    done < <(get_all_members)
    
    h_log_success "Context7統合テスト完了: $success_count/$total_count メンバーにテストメッセージ送信"
    
    # Context7テスト結果の収集指示
    local report_message="【Context7テスト結果報告】Context7統合機能のテスト結果を以下の形式で報告してください

報告フォーマット:
1. Context7接続状況: [成功/失敗]
2. 技術情報取得テスト: [実行した問い合わせ例]
3. 取得した情報の品質: [有用性・正確性評価]
4. 移行作業での活用可能性: [具体的な活用方法]
5. 課題・改善点: [発見した問題・要望]

例: 「FastAPI 最新実装パターン」で問い合わせた結果を具体的に報告してください"
    
    # Product Managerに結果収集を依頼
    while IFS=: read -r session pane role; do
        send_hierarchical_message "$session" "$pane" "$role" "$report_message"
        break  # 最初の1つのProduct Managerのみ
    done < <(get_manager_members)
    
    h_log_info "Context7テスト結果収集指示を Product Manager に送信完了"
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
        "context7-integration")
            context7_integration_test
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
        "start-claude")
            # Start Claude with context for specified role
            if [[ -n "$2" ]]; then
                local role="$2"
                local session=$(detect_active_session)
                local pane_info=$(get_pane_by_role "$role")
                if [[ -n "$pane_info" ]]; then
                    local pane=$(echo "$pane_info" | cut -d: -f2)
                    launch_claude_with_context "$role" "$pane" "$session"
                    echo "🚀 Claude起動完了: $role"
                else
                    echo "❌ 役職が見つかりません: $role"
                fi
            else
                echo "❌ 役職を指定してください: $0 start-claude [manager|cto|dev0|dev1|...]"
            fi
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
        "send-to-cto")
            send_to_cto "$2"
            exit $?
            ;;
        "manager-to-all-devs")
            manager_to_all_devs "$2"
            exit $?
            ;;
        "reset-all-prompts")
            reset_all_prompts
            exit $?
            ;;
        "reset-prompt")
            reset_prompt "$2"
            exit $?
            ;;
        "instant")
            # 即時伝達モード送信
            if [[ $# -lt 3 ]]; then
                echo "使用方法: $0 instant [agent] [message]"
                echo "例: $0 instant manager \"緊急メッセージ\""
                exit 1
            fi
            export INSTANT_DELIVERY=true
            agent="$2"
            message="$3"
            
            target=$(resolve_target "$agent")
            if [[ $? -ne 0 ]]; then
                echo "❌ エラー: 無効なエージェント名 '$agent'"
                exit 1
            fi
            
            # 即時送信実行
            if send_enhanced_message "$target" "$message" "$agent"; then
                log_message "$agent" "$message"
                echo "⚡ 即時伝達完了: $agent"
                exit 0
            else
                echo "❌ 即時伝達失敗: $agent"
                exit 1
            fi
            ;;
        "instant-broadcast")
            # 即時伝達ブロードキャスト
            if [[ $# -lt 2 ]]; then
                echo "使用方法: $0 instant-broadcast [message]"
                echo "例: $0 instant-broadcast \"緊急一斉連絡\""
                exit 1
            fi
            export INSTANT_DELIVERY=true
            instant_broadcast_message "$2"
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