#!/bin/bash

# Microsoft Product Management Tools - Python Project Launcher
# Based on tmuxsample/ reference implementation
# Complete reimplementation with advanced features

set -euo pipefail

# Dynamic path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
SESSION_PREFIX="MicrosoftProductTools-Python"

# Logging functions
log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_error() {
    echo "❌ $1" >&2
}

log_warning() {
    echo "⚠️  $1"
}

# Initialize logging
init_logging() {
    mkdir -p "$LOG_DIR"
    local log_file="$LOG_DIR/launcher_$(date +%Y%m%d_%H%M%S).log"
    exec > >(tee -a "$log_file") 2>&1
    log_info "Logging initialized: $log_file"
}

# Claude authentication unified setup
setup_claude_auth() {
    log_info "Claude認証統一設定を適用中..."
    
    # tmux environment variables (v3.0 integrated technology)
    tmux set-environment -g CLAUDE_CODE_CONFIG_PATH "$HOME/.local/share/claude" 2>/dev/null || true
    tmux set-environment -g CLAUDE_CODE_CACHE_PATH "$HOME/.cache/claude" 2>/dev/null || true
    tmux set-environment -g CLAUDE_CODE_AUTO_START "true" 2>/dev/null || true
    
    # bash environment variables
    export CLAUDE_CODE_CONFIG_PATH="$HOME/.local/share/claude"
    export CLAUDE_CODE_CACHE_PATH="$HOME/.cache/claude"
    export CLAUDE_CODE_AUTO_START="true"
    
    log_success "Claude認証統一設定完了"
}

# Prerequisites check
check_prerequisites() {
    log_info "前提条件をチェック中..."
    
    # Check tmux installation
    if ! command -v tmux &> /dev/null; then
        log_error "tmuxがインストールされていません"
        exit 1
    fi
    
    # Check claude installation
    if ! command -v claude &> /dev/null; then
        log_error "claudeがインストールされていません"
        exit 1
    fi
    
    # Apply Claude authentication unified setup
    setup_claude_auth
    
    # Check project directory
    if [ ! -d "$PROJECT_DIR" ]; then
        log_error "プロジェクトディレクトリが見つかりません: $PROJECT_DIR"
        exit 1
    fi
    
    # Set execution permissions for scripts
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ] && [ ! -x "$script" ]; then
            log_info "実行権限を設定中: $(basename "$script")"
            chmod +x "$script"
        fi
    done
    
    log_success "前提条件チェック完了"
}

# Session cleanup
cleanup_sessions() {
    log_info "既存のセッションをチェック中..."
    
    local sessions=$(tmux list-sessions 2>/dev/null | grep -E "$SESSION_PREFIX" | cut -d: -f1 || true)
    
    if [ -n "$sessions" ]; then
        log_warning "既存のセッションが見つかりました:"
        echo "$sessions"
        echo ""
        read -p "既存セッションを終了しますか？ (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$sessions" | while read -r session; do
                tmux kill-session -t "$session" 2>/dev/null || true
                log_info "セッション終了: $session"
            done
        fi
    fi
}

# Main menu display
show_menu() {
    clear
    echo "🚀 Microsoft Product Management Tools - Python Project Launcher v4.0"
    echo "============================================================================"
    echo ""
    echo "👥 開発チーム構成:"
    echo "1) 5人構成 - 標準開発 (Manager + CTO + Dev0-2) 🌟推奨"
    echo "2) 8人構成 - 大規模開発 (Manager + CEO + Dev0-5)"
    echo ""
    echo "⚡ 高速セットアップ:"
    echo "3) 現在のセッション確認・接続"
    echo "4) 標準5人構成で即座起動 (推奨設定)"
    echo "5) 🌟 Context7統合5人構成 (自動Context7連携) ✨NEW"
    echo ""
    echo "🛠️  管理・設定:"
    echo "6) 認証状態確認"
    echo "7) 既存セッション確認・終了"
    echo "8) メッセージングシステムテスト"
    echo ""
    echo "📊 システム仕様:"
    echo "   • 左側: Manager(上) + CTO(下) 固定"
    echo "   • 右側: Dev0-Dev2 均等分割"
    echo "   • 各開発者の専門分野:"
    echo "     - Dev0: フロントエンド/UI 💻"
    echo "     - Dev1: バックエンド/API ⚙️"
    echo "     - Dev2: QA/テスト 🔒"
    echo ""
    echo "🌟 Context7統合機能（オプション5）:"
    echo "   • 自動ライブラリドキュメント取得"
    echo "   • コマンドプロンプト指示で最新情報参照"
    echo "   • 全ペインで統一Context7サポート"
    echo "   • Claude AI 自動起動・認証"
    echo ""
    echo "0) 終了"
    echo ""
}

# 5-person team configuration (Manager + CTO + 3 Developers)
launch_5person_team() {
    log_info "5人構成チーム開発環境を起動します"
    
    local session="$SESSION_PREFIX-5team"
    
    # Check existing session
    if tmux has-session -t "$session" 2>/dev/null; then
        log_warning "$session セッションが既に存在します"
        echo ""
        read -p "既存セッションを終了して新しく作成しますか？ (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            tmux kill-session -t "$session" 2>/dev/null || true
            log_info "既存セッションを終了しました"
        else
            log_info "既存セッションにアタッチします"
            tmux attach-session -t "$session"
            return 0
        fi
    fi
    
    log_info "5人構成を作成中..."
    
    # Step 1: Create new session
    tmux new-session -d -s "$session" -c "$PROJECT_DIR"
    
    # Step 2: Split left and right (vertical line)
    tmux split-window -h -t "$session:0.0" -c "$PROJECT_DIR"
    # After split: 0(left), 1(right)
    
    # Step 3: Split left side horizontally
    tmux split-window -v -t "$session:0.0" -c "$PROJECT_DIR"
    # After split: 0(left-top・Manager), 1(left-bottom・CTO), 2(right-all)
    
    # Step 4: Split right side into 3 panes
    # Split right pane vertically
    tmux split-window -v -t "$session:0.2" -c "$PROJECT_DIR"
    # After split: 0(left-top), 1(left-bottom), 2(right-top), 3(right-bottom)
    
    # Split right-top pane vertically
    tmux split-window -v -t "$session:0.2" -c "$PROJECT_DIR"
    # After split: 0(left-top), 1(left-bottom), 2(right-1), 3(right-2), 4(right-3)
    
    # Step 5: Size adjustment
    # Left-right balance (left 30%, right 70%)
    tmux resize-pane -t "$session:0.0" -x 30%
    
    # Right side equal distribution
    log_info "右側Developer領域を均等化中..."
    sleep 1
    
    local window_height=$(tmux display-message -t "$session" -p '#{window_height}')
    local window_width=$(tmux display-message -t "$session" -p '#{window_width}')
    local min_height=6  # Minimum height for Claude prompt
    local dev_height=$(( window_height > (min_height * 3) ? window_height / 3 : min_height ))
    
    log_info "ウィンドウ総高さ: $window_height, 各Devペイン目標高さ: $dev_height"
    
    # Equal height for Developer panes
    tmux resize-pane -t "$session:0.2" -y $dev_height
    tmux resize-pane -t "$session:0.3" -y $dev_height
    tmux resize-pane -t "$session:0.4" -y $dev_height
    
    # Step 6: Enable pane titles
    tmux set-window-option -t "$session" pane-border-status top
    tmux set-window-option -t "$session" pane-border-format '#[align=centre,bg=colour236,fg=colour255,bold] #{pane_title} #[default]'
    tmux set-window-option -t "$session" automatic-rename off
    
    # Pane border style
    tmux set-window-option -t "$session" pane-active-border-style 'fg=colour208,bg=default,bold'
    tmux set-window-option -t "$session" pane-border-style 'fg=colour238,bg=default'
    
    # Step 7: Set titles and roles
    tmux select-pane -t "$session:0.0" -T "👔 Manager: Coordination & Progress"
    tmux select-pane -t "$session:0.1" -T "💼 CTO: Technical Leadership"
    tmux select-pane -t "$session:0.2" -T "💻 Dev0: Frontend/UI"
    tmux select-pane -t "$session:0.3" -T "⚙️ Dev1: Backend/API"
    tmux select-pane -t "$session:0.4" -T "🔒 Dev2: QA/Test"
    
    # Step 8: Initialize panes with clear messages
    tmux send-keys -t "$session:0.0" 'clear; echo "👔 Manager（ペイン0・左上）"; echo "役割: プロジェクト管理・進捗調整"; echo "準備完了"; cd "'"$PROJECT_DIR"'"' C-m
    tmux send-keys -t "$session:0.1" 'clear; echo "💼 CTO（ペイン1・左下）"; echo "役割: 技術的意思決定・アーキテクチャ"; echo "準備完了"; cd "'"$PROJECT_DIR"'"' C-m
    tmux send-keys -t "$session:0.2" 'clear; echo "💻 Dev0（ペイン2・右上）"; echo "役割: フロントエンド・UI開発"; echo "準備完了"; cd "'"$PROJECT_DIR"'"' C-m
    tmux send-keys -t "$session:0.3" 'clear; echo "⚙️ Dev1（ペイン3・右中）"; echo "役割: バックエンド・API開発"; echo "準備完了"; cd "'"$PROJECT_DIR"'"' C-m
    tmux send-keys -t "$session:0.4" 'clear; echo "🔒 Dev2（ペイン4・右下）"; echo "役割: QA・テスト・品質管理"; echo "準備完了"; cd "'"$PROJECT_DIR"'"' C-m
    
    # Step 9: Start Claude in each pane with delay
    log_info "各ペインでClaude起動中..."
    
    # Manager (pane 0) - immediate start with context
    tmux send-keys -t "$session:0.0" "clear && echo '👔 Manager - Claude起動中...' && claude --dangerously-skip-permissions \"\$(cat \"$PROJECT_DIR/tmux/instructions/manager.md\")\"" C-m
    
    # CTO (pane 1) - 3 second delay with context
    tmux send-keys -t "$session:0.1" "sleep 3 && clear && echo '💼 CTO - Claude起動中...' && claude --dangerously-skip-permissions \"\$(cat \"$PROJECT_DIR/tmux/instructions/cto.md\")\"" C-m
    
    # Developers (panes 2-4) - 5 second intervals with context
    local dev_roles=("Dev0" "Dev1" "Dev2")
    local dev_icons=("💻" "⚙️" "🔒")
    
    for i in {0..2}; do
        local pane_idx=$((i + 2))
        local delay=$((6 + i * 5))
        local role="${dev_roles[$i]}"
        local icon="${dev_icons[$i]}"
        tmux send-keys -t "$session:0.$pane_idx" "sleep $delay && clear && echo '$icon $role - Claude起動中...' && claude --dangerously-skip-permissions \"\$(cat \"$PROJECT_DIR/tmux/instructions/developer.md\")\"" C-m
    done
    
    # Step 10: Pane title maintenance system
    log_info "ペインタイトル維持システムを起動中..."
    (
        sleep 15
        for ((count=1; count<=30; count++)); do
            if ! tmux has-session -t "$session" 2>/dev/null; then
                break
            fi
            
            tmux select-pane -t "$session:0.0" -T "👔 Manager: Coordination & Progress" 2>/dev/null
            tmux select-pane -t "$session:0.1" -T "💼 CTO: Technical Leadership" 2>/dev/null
            tmux select-pane -t "$session:0.2" -T "💻 Dev0: Frontend/UI" 2>/dev/null
            tmux select-pane -t "$session:0.3" -T "⚙️ Dev1: Backend/API" 2>/dev/null
            tmux select-pane -t "$session:0.4" -T "🔒 Dev2: QA/Test" 2>/dev/null
            
            sleep 3
        done
    ) &
    
    # Select main pane
    tmux select-pane -t "$session:0.0"
    
    # Session information
    echo ""
    log_success "5人構成チーム開発環境が作成されました！"
    echo "📊 構成詳細:"
    echo "   - セッション名: $session"
    echo "   - 総ペイン数: 5"
    echo "   - 左側: 👔 Manager(0) + 💼 CTO(1)"
    echo "   - 右側: 💻 Dev0(2) + ⚙️ Dev1(3) + 🔒 Dev2(4)"
    echo "   - レイアウト: 左30% + 右70%"
    echo "   - ペインタイトル: 役職+アイコン+役割表示"
    echo ""
    echo "🚀 接続コマンド: tmux attach-session -t $session"
    echo ""
    
    # Attach to session
    read -p "セッションに接続しますか？ (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tmux attach-session -t "$session"
    else
        echo "手動接続: tmux attach-session -t $session"
    fi
}

# 8-person team configuration (Manager + CEO + 6 Developers)
launch_8person_team() {
    log_info "8人構成チーム開発環境を起動します"
    
    local session="$SESSION_PREFIX-8team"
    
    # Check existing session
    if tmux has-session -t "$session" 2>/dev/null; then
        log_warning "$session セッションが既に存在します"
        echo ""
        read -p "既存セッションを終了して新しく作成しますか？ (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            tmux kill-session -t "$session" 2>/dev/null || true
            log_info "既存セッションを終了しました"
        else
            log_info "既存セッションにアタッチします"
            tmux attach-session -t "$session"
            return 0
        fi
    fi
    
    log_info "8人構成を作成中..."
    
    # Step 1: Create new session
    tmux new-session -d -s "$session" -c "$PROJECT_DIR"
    
    # Step 2: Split left and right (vertical line)
    tmux split-window -h -t "$session:0.0" -c "$PROJECT_DIR"
    
    # Step 3: Split left side horizontally
    tmux split-window -v -t "$session:0.0" -c "$PROJECT_DIR"
    
    # Step 4: Split right side into 6 panes
    for i in {1..5}; do
        if [ $i -eq 1 ]; then
            tmux split-window -v -t "$session:0.2" -c "$PROJECT_DIR"
        else
            local target_pane=$((i + 1))
            tmux split-window -v -t "$session:0.$target_pane" -c "$PROJECT_DIR"
        fi
    done
    
    # Step 5: Size adjustment
    tmux resize-pane -t "$session:0.0" -x 30%
    
    # Step 6: Enable pane titles
    tmux set-window-option -t "$session" pane-border-status top
    tmux set-window-option -t "$session" pane-border-format '#[align=centre,bg=colour236,fg=colour255,bold] #{pane_title} #[default]'
    tmux set-window-option -t "$session" automatic-rename off
    
    # Step 7: Set titles and roles
    tmux select-pane -t "$session:0.0" -T "👔 Manager: Coordination & Progress"
    tmux select-pane -t "$session:0.1" -T "👑 CEO: Strategic Leadership"
    tmux select-pane -t "$session:0.2" -T "💻 Dev0: Frontend/UI"
    tmux select-pane -t "$session:0.3" -T "⚙️ Dev1: Backend/API"
    tmux select-pane -t "$session:0.4" -T "🔒 Dev2: QA/Test"
    tmux select-pane -t "$session:0.5" -T "🧪 Dev3: DevOps/Infrastructure"
    tmux select-pane -t "$session:0.6" -T "🚀 Dev4: Database/Architecture"
    tmux select-pane -t "$session:0.7" -T "📊 Dev5: Data/Analytics"
    
    # Step 8: Initialize and start Claude
    local roles=("Manager" "CEO" "Dev0" "Dev1" "Dev2" "Dev3" "Dev4" "Dev5")
    local icons=("👔" "👑" "💻" "⚙️" "🔒" "🧪" "🚀" "📊")
    
    for pane in {0..7}; do
        local delay=$((pane * 3))
        local role="${roles[$pane]}"
        local icon="${icons[$pane]}"
        
        # Determine context file based on role and start Claude with context
        local context_file=""
        if [[ "$role" == "Manager" ]]; then
            context_file="$PROJECT_DIR/tmux/instructions/manager.md"
        elif [[ "$role" == "CEO" ]]; then
            context_file="$PROJECT_DIR/tmux/instructions/cto.md"
        else
            context_file="$PROJECT_DIR/tmux/instructions/developer.md"
        fi
        
        tmux send-keys -t "$session:0.$pane" "sleep $delay && clear && echo '$icon $role - Claude起動中...' && cd '$PROJECT_DIR' && claude --dangerously-skip-permissions \"\$(cat \"$context_file\")\"" C-m
    done
    
    # Pane title maintenance
    (
        sleep 15
        for ((count=1; count<=30; count++)); do
            if ! tmux has-session -t "$session" 2>/dev/null; then
                break
            fi
            
            tmux select-pane -t "$session:0.0" -T "👔 Manager: Coordination & Progress" 2>/dev/null
            tmux select-pane -t "$session:0.1" -T "👑 CEO: Strategic Leadership" 2>/dev/null
            tmux select-pane -t "$session:0.2" -T "💻 Dev0: Frontend/UI" 2>/dev/null
            tmux select-pane -t "$session:0.3" -T "⚙️ Dev1: Backend/API" 2>/dev/null
            tmux select-pane -t "$session:0.4" -T "🔒 Dev2: QA/Test" 2>/dev/null
            tmux select-pane -t "$session:0.5" -T "🧪 Dev3: DevOps/Infrastructure" 2>/dev/null
            tmux select-pane -t "$session:0.6" -T "🚀 Dev4: Database/Architecture" 2>/dev/null
            tmux select-pane -t "$session:0.7" -T "📊 Dev5: Data/Analytics" 2>/dev/null
            
            sleep 3
        done
    ) &
    
    tmux select-pane -t "$session:0.0"
    
    echo ""
    log_success "8人構成チーム開発環境が作成されました！"
    echo "📊 構成詳細:"
    echo "   - セッション名: $session"
    echo "   - 総ペイン数: 8"
    echo "   - 左側: 👔 Manager(0) + 👑 CEO(1)"
    echo "   - 右側: 💻 Dev0(2) + ⚙️ Dev1(3) + 🔒 Dev2(4) + 🧪 Dev3(5) + 🚀 Dev4(6) + 📊 Dev5(7)"
    echo ""
    echo "🚀 接続コマンド: tmux attach-session -t $session"
    echo ""
    
    read -p "セッションに接続しますか？ (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tmux attach-session -t "$session"
    else
        echo "手動接続: tmux attach-session -t $session"
    fi
}

# Context7 integrated team configuration (5-person with Context7 enhancements)
launch_context7_integrated_team() {
    log_info "Context7統合5人構成チーム開発環境を起動します"
    
    local session="$SESSION_PREFIX-Context7-5team"
    
    # Check existing session
    if tmux has-session -t "$session" 2>/dev/null; then
        log_warning "$session セッションが既に存在します"
        echo ""
        read -p "既存セッションを終了して新しく作成しますか？ (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            tmux kill-session -t "$session" 2>/dev/null || true
            log_info "既存セッションを終了しました"
        else
            log_info "既存セッションにアタッチします"
            tmux attach-session -t "$session"
            return 0
        fi
    fi
    
    log_info "Context7統合5人構成を作成中..."
    
    # Use the same layout as 5-person team
    tmux new-session -d -s "$session" -c "$PROJECT_DIR"
    tmux split-window -h -t "$session:0.0" -c "$PROJECT_DIR"
    tmux split-window -v -t "$session:0.0" -c "$PROJECT_DIR"
    tmux split-window -v -t "$session:0.2" -c "$PROJECT_DIR"
    tmux split-window -v -t "$session:0.2" -c "$PROJECT_DIR"
    
    # Size adjustment
    tmux resize-pane -t "$session:0.0" -x 30%
    
    local window_height=$(tmux display-message -t "$session" -p '#{window_height}')
    local min_height=6
    local dev_height=$(( window_height > (min_height * 3) ? window_height / 3 : min_height ))
    
    tmux resize-pane -t "$session:0.2" -y $dev_height
    tmux resize-pane -t "$session:0.3" -y $dev_height
    tmux resize-pane -t "$session:0.4" -y $dev_height
    
    # Enable pane titles
    tmux set-window-option -t "$session" pane-border-status top
    tmux set-window-option -t "$session" pane-border-format '#[align=centre,bg=colour208,fg=colour255,bold] #{pane_title} #[default]'
    tmux set-window-option -t "$session" automatic-rename off
    
    # Set Context7 enhanced titles
    tmux select-pane -t "$session:0.0" -T "👔 Manager: Context7 + Coordination"
    tmux select-pane -t "$session:0.1" -T "💼 CTO: Context7 + Technical Leadership"
    tmux select-pane -t "$session:0.2" -T "💻 Dev0: Context7 + Frontend/UI"
    tmux select-pane -t "$session:0.3" -T "⚙️ Dev1: Context7 + Backend/API"
    tmux select-pane -t "$session:0.4" -T "🔒 Dev2: Context7 + QA/Test"
    
    # Initialize with Context7 integration messages
    tmux send-keys -t "$session:0.0" 'clear; echo "👔 Manager（Context7統合）"; echo "役割: Context7活用プロジェクト管理"; echo "機能: 最新技術情報自動取得"; echo "準備完了"; cd "'$PROJECT_DIR'"' C-m
    tmux send-keys -t "$session:0.1" 'clear; echo "💼 CTO（Context7統合）"; echo "役割: Context7活用技術戦略"; echo "機能: 最新アーキテクチャ参照"; echo "準備完了"; cd "'$PROJECT_DIR'"' C-m
    tmux send-keys -t "$session:0.2" 'clear; echo "💻 Dev0（Context7統合）"; echo "役割: Context7活用フロントエンド"; echo "機能: React最新パターン取得"; echo "準備完了"; cd "'$PROJECT_DIR'"' C-m
    tmux send-keys -t "$session:0.3" 'clear; echo "⚙️ Dev1（Context7統合）"; echo "役割: Context7活用バックエンド"; echo "機能: FastAPI最新実装参照"; echo "準備完了"; cd "'$PROJECT_DIR'"' C-m
    tmux send-keys -t "$session:0.4" 'clear; echo "🔒 Dev2（Context7統合）"; echo "役割: Context7活用QA"; echo "機能: pytest最新テスト手法"; echo "準備完了"; cd "'$PROJECT_DIR'"' C-m
    
    # Start Claude with Context7 integration in each pane
    log_info "Context7統合Claude起動中..."
    
    # Enhanced context messages with Context7 integration
    local context7_prompt="このファイルの内容を理解し、Context7統合機能を活用して役割を設定してください。Context7を使って最新技術情報を自動取得し、Microsoft 365 Python移行プロジェクトを効率化してください。"
    
    # Manager with Context7
    tmux send-keys -t "$session:0.0" "claude --dangerously-skip-permissions \"$context7_prompt \$(cat \"$PROJECT_DIR/tmux/instructions/manager.md\")\"" C-m
    
    # CTO with Context7
    tmux send-keys -t "$session:0.1" "sleep 3 && claude --dangerously-skip-permissions \"$context7_prompt \$(cat \"$PROJECT_DIR/tmux/instructions/cto.md\")\"" C-m
    
    # Developers with Context7
    local dev_roles=("Dev0" "Dev1" "Dev2")
    for i in {0..2}; do
        local pane_idx=$((i + 2))
        local delay=$((6 + i * 5))
        local role="${dev_roles[$i]}"
        tmux send-keys -t "$session:0.$pane_idx" "sleep $delay && claude --dangerously-skip-permissions \"$context7_prompt \$(cat \"$PROJECT_DIR/tmux/instructions/developer.md\")\"" C-m
    done
    
    # Context7 integration test
    log_info "Context7統合テストを実行中..."
    (
        sleep 15
        # Send Context7 test message to all panes
        for pane in {0..4}; do
            tmux send-keys -t "$session:0.$pane" "Context7統合テスト: 「FastAPI SQLAlchemy 最新実装パターン」で最新技術情報を取得してください" C-m
            sleep 2
        done
    ) &
    
    # Pane title maintenance for Context7 session
    (
        sleep 20
        for ((count=1; count<=30; count++)); do
            if ! tmux has-session -t "$session" 2>/dev/null; then
                break
            fi
            
            tmux select-pane -t "$session:0.0" -T "👔 Manager: Context7 + Coordination" 2>/dev/null
            tmux select-pane -t "$session:0.1" -T "💼 CTO: Context7 + Technical Leadership" 2>/dev/null
            tmux select-pane -t "$session:0.2" -T "💻 Dev0: Context7 + Frontend/UI" 2>/dev/null
            tmux select-pane -t "$session:0.3" -T "⚙️ Dev1: Context7 + Backend/API" 2>/dev/null
            tmux select-pane -t "$session:0.4" -T "🔒 Dev2: Context7 + QA/Test" 2>/dev/null
            
            sleep 3
        done
    ) &
    
    tmux select-pane -t "$session:0.0"
    
    echo ""
    log_success "Context7統合5人構成チーム開発環境が作成されました！"
    echo "🌟 Context7統合機能:"
    echo "   - 最新技術情報自動取得"
    echo "   - ライブラリドキュメント参照"
    echo "   - 実装パターン検索"
    echo "   - トラブルシューティング支援"
    echo ""
    echo "📊 構成詳細:"
    echo "   - セッション名: $session"
    echo "   - 総ペイン数: 5"
    echo "   - Context7統合: 全ペイン対応"
    echo "   - 自動テスト: 15秒後に実行"
    echo ""
    echo "🚀 接続コマンド: tmux attach-session -t $session"
    echo ""
    
    read -p "セッションに接続しますか？ (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tmux attach-session -t "$session"
    else
        echo "手動接続: tmux attach-session -t $session"
    fi
}

# Test messaging system
test_messaging_system() {
    log_info "メッセージングシステムテストを実行中..."
    
    # Check if send-message.sh exists
    if [ ! -f "$SCRIPT_DIR/send-message.sh" ]; then
        log_error "send-message.shが見つかりません"
        return 1
    fi
    
    # Make send-message.sh executable
    chmod +x "$SCRIPT_DIR/send-message.sh"
    
    # Test 1: Check help/usage
    echo "🔧 テスト1: ヘルプ表示"
    "$SCRIPT_DIR/send-message.sh" --help
    echo ""
    
    # Test 2: Detect sessions
    echo "🔧 テスト2: セッション検出"
    "$SCRIPT_DIR/send-message.sh" --detect
    echo ""
    
    # Test 3: Context7 integration test
    echo "🔧 テスト3: Context7統合テスト"
    "$SCRIPT_DIR/send-message.sh" context7-integration
    echo ""
    
    # Test 4: Check status
    echo "🔧 テスト4: システム状況確認"
    "$SCRIPT_DIR/send-message.sh" --status
    echo ""
    
    # Test 5: Interactive test
    echo "🔧 テスト5: インタラクティブテスト"
    local active_session=$(tmux list-sessions 2>/dev/null | grep -E "$SESSION_PREFIX" | head -n1 | cut -d: -f1 || true)
    
    if [ -n "$active_session" ]; then
        echo "✅ アクティブセッション発見: $active_session"
        echo "📤 テストメッセージ送信中..."
        
        # Send test message to manager
        "$SCRIPT_DIR/send-message.sh" manager "【テスト】メッセージングシステムテスト実行中 - Python移行プロジェクト動作確認"
        echo ""
        
        # Send test message to cto
        "$SCRIPT_DIR/send-message.sh" cto "【テスト】技術システムテスト実行中 - Context7統合機能動作確認"
        echo ""
        
        # Send test message to developers
        "$SCRIPT_DIR/send-message.sh" broadcast "【テスト】全開発者へのブロードキャストテスト - Python移行開発環境確認"
        echo ""
        
        log_success "メッセージングシステムテスト完了"
        echo "📊 テスト結果:"
        echo "   ✅ send-message.sh 実行可能"
        echo "   ✅ セッション検出機能"
        echo "   ✅ Context7統合機能"
        echo "   ✅ メッセージ送信機能"
        echo "   ✅ ブロードキャスト機能"
        
    else
        log_warning "アクティブなセッションが見つかりません"
        echo "💡 テストを完了するには、先にセッションを作成してください:"
        echo "   1) 5人構成を起動"
        echo "   2) 8人構成を起動"
        echo "   5) Context7統合5人構成を起動"
        echo ""
        log_info "基本機能テストは完了しました"
    fi
}

# Show current sessions
show_current_sessions() {
    log_info "現在のtmuxセッションを確認中..."
    
    local sessions=$(tmux list-sessions 2>/dev/null | grep -E "$SESSION_PREFIX" | cut -d: -f1 || true)
    
    if [ -n "$sessions" ]; then
        log_success "アクティブなセッションが見つかりました:"
        echo "$sessions" | while read -r session; do
            local pane_count=$(tmux list-panes -t "$session" 2>/dev/null | wc -l)
            echo "  📊 $session (ペイン数: $pane_count)"
        done
        echo ""
        
        local first_session=$(echo "$sessions" | head -n1)
        read -p "セッション '$first_session' に接続しますか？ (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "セッション '$first_session' に接続中..."
            tmux attach-session -t "$first_session"
        fi
    else
        log_warning "アクティブなセッションが見つかりません"
        log_info "新しいセッションを作成するには、メニューから選択してください"
    fi
}

# Main execution
main() {
    # Initialize logging
    init_logging
    
    # Check prerequisites
    check_prerequisites
    
    while true; do
        show_menu
        read -p "選択してください (0-8): " choice
        echo ""
        
        case $choice in
            1)
                log_info "5人構成を起動します"
                cleanup_sessions
                launch_5person_team
                ;;
            2)
                log_info "8人構成を起動します"
                cleanup_sessions
                launch_8person_team
                ;;
            3)
                log_info "現在のセッション確認・接続"
                show_current_sessions
                ;;
            4)
                log_info "標準5人構成で即座起動"
                cleanup_sessions
                launch_5person_team
                ;;
            5)
                log_info "Context7統合5人構成を起動します"
                cleanup_sessions
                launch_context7_integrated_team
                ;;
            6)
                log_info "認証状態確認"
                if command -v claude &> /dev/null; then
                    echo "✅ Claude Code: インストール済み"
                    claude --version 2>/dev/null || echo "❌ Claude Code: バージョン確認に失敗"
                else
                    echo "❌ Claude Code: 未インストール"
                fi
                echo ""
                read -p "メニューに戻りますか？ (y/n): " -n 1 -r
                echo ""
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    break
                fi
                ;;
            7)
                cleanup_sessions
                echo ""
                read -p "メニューに戻りますか？ (y/n): " -n 1 -r
                echo ""
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    break
                fi
                ;;
            8)
                log_info "メッセージングシステムテスト"
                test_messaging_system
                echo ""
                read -p "メニューに戻りますか？ (y/n): " -n 1 -r
                echo ""
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    break
                fi
                ;;
            0)
                log_info "システムを終了します"
                exit 0
                ;;
            *)
                log_error "無効な選択です: $choice"
                sleep 2
                ;;
        esac
        
        if [ "$choice" != "6" ] && [ "$choice" != "7" ] && [ "$choice" != "8" ] && [ "$choice" != "0" ] && [ "$choice" != "3" ]; then
            echo ""
            read -p "メニューに戻りますか？ (y/n): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                break
            fi
        fi
    done
}

# Error trap
trap 'log_error "予期しないエラーが発生しました (行: $LINENO)"' ERR

# Execute main function
main "$@"