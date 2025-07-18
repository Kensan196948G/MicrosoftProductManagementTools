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
    echo "1) 3人構成 - 標準開発 (CTO + Manager + Developer) 🌟推奨"
    echo "2) 5人構成 - 大規模開発 (Architect + Backend + Frontend + Tester + DevOps)"
    echo ""
    echo "⚡ 高速セットアップ:"
    echo "3) 現在のセッション確認・接続"
    echo "4) 標準3人構成で即座起動 (推奨設定)"
    echo "5) 🌟 Context7統合3人構成 (自動Context7連携) ✨NEW"
    echo "6) 🌟 Context7統合5人構成 (自動Context7連携) ✨NEW"
    echo ""
    echo "🛠️  管理・設定:"
    echo "7) 認証状態確認"
    echo "8) 既存セッション確認・終了"
    echo "9) メッセージングシステムテスト"
    echo ""
    echo "📊 システム仕様:"
    echo "   • 左側: CTO(上) + Manager(下) 固定"
    echo "   • 右側: Developer 全幅"
    echo "   • 各役割の専門分野:"
    echo "     - CTO: 技術戦略・アーキテクチャ決定 💼"
    echo "     - Manager: プロジェクト管理・進捗調整 👔"
    echo "     - Developer: 実装・開発作業 👨‍💻"
    echo ""
    echo "🌟 Context7統合機能（オプション5・6）:"
    echo "   • 自動ライブラリドキュメント取得"
    echo "   • コマンドプロンプト指示で最新情報参照"
    echo "   • 全ペインで統一Context7サポート"
    echo "   • Claude AI 自動起動・認証"
    echo "   • tmux_shared_context.md 連携強化"
    echo "   • オプション5: CTO→Manager→Developer 自動連携"
    echo "   • オプション6: CTO→Manager→Dev0/Dev1/Dev2 自動連携"
    echo ""
    echo "0) 終了"
    echo ""
}

# 3-person team configuration (CTO + Manager + Developer)
launch_3person_team() {
    log_info "3人構成チーム開発環境を起動します"
    
    local session="$SESSION_PREFIX-3team"
    
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
    
    log_info "3人構成を作成中..."
    
    # Step 1: Create new session
    tmux new-session -d -s "$session" -c "$PROJECT_DIR"
    
    # Step 2: Split left and right (vertical line)
    tmux split-window -h -t "$session:0.0" -c "$PROJECT_DIR"
    # After split: 0(left), 1(right)
    
    # Step 3: Split left side horizontally
    tmux split-window -v -t "$session:0.0" -c "$PROJECT_DIR"
    # After split: 0(left-top・CTO), 1(left-bottom・Manager), 2(right-all・Developer)
    
    # Step 4: Size adjustment
    # Left-right balance (left 40%, right 60%)
    tmux resize-pane -t "$session:0.0" -x 40%
    
    # Step 5: Enable pane titles
    tmux set-window-option -t "$session" pane-border-status top
    tmux set-window-option -t "$session" pane-border-format '#[align=centre,bg=colour236,fg=colour255,bold] #{pane_title} #[default]'
    tmux set-window-option -t "$session" automatic-rename off
    
    # Pane border style
    tmux set-window-option -t "$session" pane-active-border-style 'fg=colour208,bg=default,bold'
    tmux set-window-option -t "$session" pane-border-style 'fg=colour238,bg=default'
    
    # Step 6: Set titles and roles (3-person team)
    tmux select-pane -t "$session:0.0" -T "💼 CTO: Technical Leadership"
    tmux select-pane -t "$session:0.1" -T "👔 Manager: Project Management"
    tmux select-pane -t "$session:0.2" -T "👨‍💻 Developer: Implementation"
    
    # Step 7: Initialize panes with clear messages (3-person team)
    tmux send-keys -t "$session:0.0" 'clear; echo "💼 CTO（ペイン0・左上）"; echo "役割: 技術戦略・アーキテクチャ決定"; echo "連携: tmux_shared_context.md + send-message.sh"; echo "準備完了"; cd "'"$PROJECT_DIR"'"' C-m
    tmux send-keys -t "$session:0.1" 'clear; echo "👔 Manager（ペイン1・左下）"; echo "役割: プロジェクト管理・進捗調整"; echo "連携: tmux_shared_context.md + send-message.sh"; echo "準備完了"; cd "'"$PROJECT_DIR"'"' C-m
    tmux send-keys -t "$session:0.2" 'clear; echo "👨‍💻 Developer（ペイン2・右全体）"; echo "役割: 実装・開発作業"; echo "連携: tmux_shared_context.md + send-message.sh"; echo "準備完了"; cd "'"$PROJECT_DIR"'"' C-m
    
    # Step 8: Create shared context file
    local shared_context="$PROJECT_DIR/tmux_shared_context.md"
    if [ ! -f "$shared_context" ]; then
        echo "# 3人構成並列開発環境 - 共有コンテキスト" > "$shared_context"
        echo "## 更新時刻: $(date)" >> "$shared_context"
        echo "## 進捗状況:" >> "$shared_context"
        echo "- CTO: 待機中" >> "$shared_context"
        echo "- Manager: 待機中" >> "$shared_context"
        echo "- Developer: 待機中" >> "$shared_context"
        echo "" >> "$shared_context"
        echo "## 連携フロー:" >> "$shared_context"
        echo "CTO → Manager → Developer → Manager → CTO" >> "$shared_context"
    fi
    
    # Step 9: Start Claude in each pane with context files
    log_info "各ペインでClaude起動中（専用コンテキスト付き）..."
    
    # CTO (pane 0) - immediate start with CTO context
    tmux send-keys -t "$session:0.0" "clear && echo '💼 CTO - Claude起動中...' && claude --dangerously-skip-permissions \"\$(cat \"$PROJECT_DIR/tmux/instructions/cto.md\")\"" C-m
    
    # Manager (pane 1) - 3 second delay with Manager context
    tmux send-keys -t "$session:0.1" "sleep 3 && clear && echo '👔 Manager - Claude起動中...' && claude --dangerously-skip-permissions \"\$(cat \"$PROJECT_DIR/tmux/instructions/manager.md\")\"" C-m
    
    # Developer (pane 2) - 6 second delay with Developer context
    tmux send-keys -t "$session:0.2" "sleep 6 && clear && echo '👨‍💻 Developer - Claude起動中...' && claude --dangerously-skip-permissions \"\$(cat \"$PROJECT_DIR/tmux/instructions/developer.md\")\"" C-m
    
    # Step 10: Setup automatic connectivity monitoring and collaboration system
    log_info "自動連携監視システムを起動中..."
    
    # Initialize collaboration system
    chmod +x "$PROJECT_DIR/tmux/auto_collaboration.sh" 2>/dev/null || true
    "$PROJECT_DIR/tmux/auto_collaboration.sh" init
    
    # Start monitoring in background
    (
        sleep 15
        # Start collaboration monitoring
        "$PROJECT_DIR/tmux/auto_collaboration.sh" monitor &
        
        # Create automatic connectivity monitoring
        for ((count=1; count<=60; count++)); do
            if ! tmux has-session -t "$session" 2>/dev/null; then
                break
            fi
            
            # Update pane titles
            tmux select-pane -t "$session:0.0" -T "💼 CTO: Technical Leadership" 2>/dev/null
            tmux select-pane -t "$session:0.1" -T "👔 Manager: Project Management" 2>/dev/null
            tmux select-pane -t "$session:0.2" -T "👨‍💻 Developer: Implementation" 2>/dev/null
            
            # Update shared context timestamp
            if [ -f "$shared_context" ]; then
                sed -i "s/## 更新時刻: .*/## 更新時刻: $(date)/" "$shared_context" 2>/dev/null
            fi
            
            sleep 12
        done
    ) &
    
    # Setup send-message.sh permissions
    chmod +x "$PROJECT_DIR/tmux/send-message.sh" 2>/dev/null || true
    
    # Select main pane
    tmux select-pane -t "$session:0.0"
    
    # Session information
    echo ""
    log_success "3人構成チーム開発環境が作成されました！"
    echo "📊 構成詳細:"
    echo "   - セッション名: $session"
    echo "   - 総ペイン数: 3"
    echo "   - 左側: 💼 CTO(0) + 👔 Manager(1)"
    echo "   - 右側: 👨‍💻 Developer(2)"
    echo "   - レイアウト: 左40% + 右60%"
    echo "   - コンテキストファイル: cto.md, manager.md, developer.md"
    echo "   - 自動連携: tmux_shared_context.md + send-message.sh"
    echo "   - 完全自動化: 12秒間隔監視"
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

# 5-person team configuration (Architect + Backend + Frontend + Tester + DevOps)
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
    
    # Step 7: Set titles and roles (5-pane independent architecture)
    tmux select-pane -t "$session:0.0" -T "🏗️ Architect: System Design"
    tmux select-pane -t "$session:0.1" -T "⚙️ Backend: API Development"
    tmux select-pane -t "$session:0.2" -T "💻 Frontend: UI Development"
    tmux select-pane -t "$session:0.3" -T "🔬 Tester: QA & Testing"
    tmux select-pane -t "$session:0.4" -T "🔧 DevOps: Infrastructure"
    
    # Step 8: Initialize panes with clear messages (5-pane independent architecture)
    tmux send-keys -t "$session:0.0" 'clear; echo "🏗️ Architect（ペイン0・左上）"; echo "役割: システム設計・アーキテクチャ"; echo "共有ファイル: tmux_shared_context.md"; echo "準備完了"; cd "'"$PROJECT_DIR"'"' C-m
    tmux send-keys -t "$session:0.1" 'clear; echo "⚙️ Backend（ペイン1・左下）"; echo "役割: API開発・データ処理"; echo "共有ファイル: tmux_shared_context.md"; echo "準備完了"; cd "'"$PROJECT_DIR"'"' C-m
    tmux send-keys -t "$session:0.2" 'clear; echo "💻 Frontend（ペイン2・右上）"; echo "役割: UI開発・PyQt6"; echo "共有ファイル: tmux_shared_context.md"; echo "準備完了"; cd "'"$PROJECT_DIR"'"' C-m
    tmux send-keys -t "$session:0.3" 'clear; echo "🔬 Tester（ペイン3・右中）"; echo "役割: QA・テスト実装"; echo "共有ファイル: tmux_shared_context.md"; echo "準備完了"; cd "'"$PROJECT_DIR"'"' C-m
    tmux send-keys -t "$session:0.4" 'clear; echo "🔧 DevOps（ペイン4・右下）"; echo "役割: 環境構築・CI/CD"; echo "共有ファイル: tmux_shared_context.md"; echo "準備完了"; cd "'"$PROJECT_DIR"'"' C-m
    
    # Step 9: Start Claude in each pane with delay (5-pane independent architecture)
    log_info "各ペインでClaude起動中（5つの独立役割）..."
    
    # Create shared context file
    local shared_context="$PROJECT_DIR/tmux_shared_context.md"
    if [ ! -f "$shared_context" ]; then
        echo "# 5ペイン並列開発環境 - 共有コンテキスト" > "$shared_context"
        echo "## 更新時刻: $(date)" >> "$shared_context"
        echo "## 進捗状況:" >> "$shared_context"
        echo "- Architect: 待機中" >> "$shared_context"
        echo "- Backend: 待機中" >> "$shared_context"
        echo "- Frontend: 待機中" >> "$shared_context"
        echo "- Tester: 待機中" >> "$shared_context"
        echo "- DevOps: 待機中" >> "$shared_context"
    fi
    
    # Architect (pane 0) - immediate start with system design role
    tmux send-keys -t "$session:0.0" "clear && echo '🏗️ Architect - Claude起動中...' && claude --dangerously-skip-permissions \"あなたはPython移行プロジェクトのアーキテクトです。システム設計とAPI設計を担当します。tmux_shared_context.mdで他の役割と連携してください。\"" C-m
    
    # Backend (pane 1) - 3 second delay with backend role
    tmux send-keys -t "$session:0.1" "sleep 3 && clear && echo '⚙️ Backend - Claude起動中...' && claude --dangerously-skip-permissions \"あなたはバックエンド開発者です。API実装とデータ処理を担当します。tmux_shared_context.mdで他の役割と連携してください。\"" C-m
    
    # Frontend (pane 2) - 6 second delay with frontend role
    tmux send-keys -t "$session:0.2" "sleep 6 && clear && echo '💻 Frontend - Claude起動中...' && claude --dangerously-skip-permissions \"あなたはフロントエンド開発者です。PyQt6を使用したGUI実装を担当します。tmux_shared_context.mdで他の役割と連携してください。\"" C-m
    
    # Tester (pane 3) - 9 second delay with tester role
    tmux send-keys -t "$session:0.3" "sleep 9 && clear && echo '🔬 Tester - Claude起動中...' && claude --dangerously-skip-permissions \"あなたはテスターです。テスト実装と品質保証を担当します。tmux_shared_context.mdで他の役割と連携してください。\"" C-m
    
    # DevOps (pane 4) - 12 second delay with devops role
    tmux send-keys -t "$session:0.4" "sleep 12 && clear && echo '🔧 DevOps - Claude起動中...' && claude --dangerously-skip-permissions \"あなたはDevOpsエンジニアです。環境構築とCI/CDを担当します。tmux_shared_context.mdで他の役割と連携してください。\"" C-m
    
    # Step 10: Pane title maintenance system (5-pane independent architecture)
    log_info "ペインタイトル維持システムを起動中..."
    (
        sleep 15
        for ((count=1; count<=30; count++)); do
            if ! tmux has-session -t "$session" 2>/dev/null; then
                break
            fi
            
            tmux select-pane -t "$session:0.0" -T "🏗️ Architect: System Design" 2>/dev/null
            tmux select-pane -t "$session:0.1" -T "⚙️ Backend: API Development" 2>/dev/null
            tmux select-pane -t "$session:0.2" -T "💻 Frontend: UI Development" 2>/dev/null
            tmux select-pane -t "$session:0.3" -T "🔬 Tester: QA & Testing" 2>/dev/null
            tmux select-pane -t "$session:0.4" -T "🔧 DevOps: Infrastructure" 2>/dev/null
            
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
    echo "   - 左側: 🏗️ Architect(0) + ⚙️ Backend(1)"
    echo "   - 右側: 💻 Frontend(2) + 🔬 Tester(3) + 🔧 DevOps(4)"
    echo "   - レイアウト: 左30% + 右70%"
    echo "   - 共有ファイル: tmux_shared_context.md"
    echo "   - 5つの独立役割が並列で動作"
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

# Context7 integrated team configuration (3-person with Context7 enhancements)
launch_context7_integrated_team() {
    log_info "Context7統合3人構成チーム開発環境を起動します"
    
    local session="$SESSION_PREFIX-Context7-3team"
    
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
    
    log_info "Context7統合3人構成を作成中..."
    
    # Use the same layout as 3-person team
    tmux new-session -d -s "$session" -c "$PROJECT_DIR"
    tmux split-window -h -t "$session:0.0" -c "$PROJECT_DIR"
    tmux split-window -v -t "$session:0.0" -c "$PROJECT_DIR"
    
    # Size adjustment
    tmux resize-pane -t "$session:0.0" -x 40%
    
    # Enable pane titles
    tmux set-window-option -t "$session" pane-border-status top
    tmux set-window-option -t "$session" pane-border-format '#[align=centre,bg=colour208,fg=colour255,bold] #{pane_title} #[default]'
    tmux set-window-option -t "$session" automatic-rename off
    
    # Set Context7 enhanced titles (3-person architecture)
    tmux select-pane -t "$session:0.0" -T "💼 CTO: Context7 + Technical Leadership"
    tmux select-pane -t "$session:0.1" -T "👔 Manager: Context7 + Project Management"
    tmux select-pane -t "$session:0.2" -T "👨‍💻 Developer: Context7 + Implementation"
    
    # Initialize with Context7 integration messages (3-person architecture)
    tmux send-keys -t "$session:0.0" 'clear; echo "💼 CTO（Context7統合）"; echo "役割: Context7活用技術戦略"; echo "機能: 最新アーキテクチャ参照"; echo "共有: tmux_shared_context.md"; echo "準備完了"; cd "'$PROJECT_DIR'"' C-m
    tmux send-keys -t "$session:0.1" 'clear; echo "👔 Manager（Context7統合）"; echo "役割: Context7活用プロジェクト管理"; echo "機能: 最新管理手法参照"; echo "共有: tmux_shared_context.md"; echo "準備完了"; cd "'$PROJECT_DIR'"' C-m
    tmux send-keys -t "$session:0.2" 'clear; echo "👨‍💻 Developer（Context7統合）"; echo "役割: Context7活用実装"; echo "機能: 最新技術実装参照"; echo "共有: tmux_shared_context.md"; echo "準備完了"; cd "'$PROJECT_DIR'"' C-m
    
    # Start Claude with Context7 integration in each pane (3-person architecture)
    log_info "Context7統合Claude起動中（3つの連携役割）..."
    
    # Create shared context file for Context7 integration
    local shared_context="$PROJECT_DIR/tmux_shared_context.md"
    if [ ! -f "$shared_context" ]; then
        echo "# 3人構成並列開発環境 - Context7統合共有コンテキスト" > "$shared_context"
        echo "## 更新時刻: $(date)" >> "$shared_context"
        echo "## 進捗状況:" >> "$shared_context"
        echo "- CTO: Context7統合待機中" >> "$shared_context"
        echo "- Manager: Context7統合待機中" >> "$shared_context"
        echo "- Developer: Context7統合待機中" >> "$shared_context"
        echo "" >> "$shared_context"
        echo "## 連携フロー:" >> "$shared_context"
        echo "CTO → Manager → Developer → Manager → CTO" >> "$shared_context"
    fi
    
    # Enhanced context messages with Context7 integration
    local context7_prompt="あなたは3人構成並列開発環境の専門役割です。Context7統合機能を活用して最新技術情報を自動取得し、Microsoft 365 Python移行プロジェクトを効率化してください。tmux_shared_context.mdで他の役割と連携してください。"
    
    # CTO with Context7
    tmux send-keys -t "$session:0.0" "claude --dangerously-skip-permissions \"$context7_prompt \$(cat \"$PROJECT_DIR/tmux/instructions/cto.md\")\"" C-m
    
    # Manager with Context7
    tmux send-keys -t "$session:0.1" "sleep 3 && claude --dangerously-skip-permissions \"$context7_prompt \$(cat \"$PROJECT_DIR/tmux/instructions/manager.md\")\"" C-m
    
    # Developer with Context7
    tmux send-keys -t "$session:0.2" "sleep 6 && claude --dangerously-skip-permissions \"$context7_prompt \$(cat \"$PROJECT_DIR/tmux/instructions/developer.md\")\"" C-m
    
    # Context7 integration test (removed automatic message sending)
    log_info "Context7統合テスト機能を準備中..."
    # Context7テストメッセージの自動送信を無効化
    # ユーザーが手動でContext7機能をテストできるように待機状態を維持
    
    # Pane title maintenance for Context7 session
    (
        sleep 20
        for ((count=1; count<=30; count++)); do
            if ! tmux has-session -t "$session" 2>/dev/null; then
                break
            fi
            
            tmux select-pane -t "$session:0.0" -T "💼 CTO: Context7 + Technical Leadership" 2>/dev/null
            tmux select-pane -t "$session:0.1" -T "👔 Manager: Context7 + Project Management" 2>/dev/null
            tmux select-pane -t "$session:0.2" -T "👨‍💻 Developer: Context7 + Implementation" 2>/dev/null
            
            sleep 3
        done
    ) &
    
    tmux select-pane -t "$session:0.0"
    
    echo ""
    log_success "Context7統合3人構成チーム開発環境が作成されました！"
    echo "🌟 Context7統合機能:"
    echo "   - 最新技術情報自動取得"
    echo "   - ライブラリドキュメント参照"
    echo "   - 実装パターン検索"
    echo "   - トラブルシューティング支援"
    echo "   - CTO→Manager→Developer 自動連携"
    echo ""
    echo "📊 構成詳細:"
    echo "   - セッション名: $session"
    echo "   - 総ペイン数: 3"
    echo "   - Context7統合: 全ペイン対応"
    echo "   - 手動テスト: 各ペインで自由にテスト可能"
    echo "   - 完全自動化: 12秒間隔監視"
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

# Context7 integrated 5-person team configuration (CTO + Manager + Dev0/Dev1/Dev2)
launch_context7_integrated_5person_team() {
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
    
    # Step 1: Create new session
    tmux new-session -d -s "$session" -c "$PROJECT_DIR"
    
    # Step 2: Split left and right (vertical line)
    tmux split-window -h -t "$session:0.0" -c "$PROJECT_DIR"
    # After split: 0(left), 1(right)
    
    # Step 3: Split left side horizontally
    tmux split-window -v -t "$session:0.0" -c "$PROJECT_DIR"
    # After split: 0(left-top・Manager), 1(left-bottom・CTO), 2(right-all)
    
    # Step 4: Split right side into 3 panes
    tmux split-window -v -t "$session:0.2" -c "$PROJECT_DIR"
    # After split: 0(left-top), 1(left-bottom), 2(right-top), 3(right-bottom)
    
    tmux split-window -v -t "$session:0.2" -c "$PROJECT_DIR"
    # After split: 0(left-top), 1(left-bottom), 2(right-1), 3(right-2), 4(right-3)
    
    # Step 5: Size adjustment
    # Left-right balance (left 30%, right 70%)
    tmux resize-pane -t "$session:0.0" -x 30%
    
    # Right side equal distribution
    local window_height=$(tmux display-message -t "$session" -p '#{window_height}')
    local min_height=6
    local dev_height=$(( window_height > (min_height * 3) ? window_height / 3 : min_height ))
    
    tmux resize-pane -t "$session:0.2" -y $dev_height
    tmux resize-pane -t "$session:0.3" -y $dev_height
    tmux resize-pane -t "$session:0.4" -y $dev_height
    
    # Step 6: Enable pane titles
    tmux set-window-option -t "$session" pane-border-status top
    tmux set-window-option -t "$session" pane-border-format '#[align=centre,bg=colour208,fg=colour255,bold] #{pane_title} #[default]'
    tmux set-window-option -t "$session" automatic-rename off
    
    # Pane border style
    tmux set-window-option -t "$session" pane-active-border-style 'fg=colour208,bg=default,bold'
    tmux set-window-option -t "$session" pane-border-style 'fg=colour238,bg=default'
    
    # Step 7: Set Context7 enhanced titles (5-person architecture)
    tmux select-pane -t "$session:0.0" -T "👔 Manager: Context7 + Project Management"
    tmux select-pane -t "$session:0.1" -T "💼 CTO: Context7 + Technical Leadership"
    tmux select-pane -t "$session:0.2" -T "💻 Dev0: Context7 + Frontend Development"
    tmux select-pane -t "$session:0.3" -T "⚙️ Dev1: Context7 + Backend Development"
    tmux select-pane -t "$session:0.4" -T "🔒 Dev2: Context7 + QA & Testing"
    
    # Step 8: Initialize with Context7 integration messages (5-person architecture)
    tmux send-keys -t "$session:0.0" 'clear; echo "👔 Manager（Context7統合）"; echo "役割: Context7活用プロジェクト管理"; echo "機能: 最新管理手法参照"; echo "共有: tmux_shared_context.md"; echo "準備完了"; cd "'$PROJECT_DIR'"' C-m
    tmux send-keys -t "$session:0.1" 'clear; echo "💼 CTO（Context7統合）"; echo "役割: Context7活用技術戦略"; echo "機能: 最新アーキテクチャ参照"; echo "共有: tmux_shared_context.md"; echo "準備完了"; cd "'$PROJECT_DIR'"' C-m
    tmux send-keys -t "$session:0.2" 'clear; echo "💻 Dev0（Context7統合）"; echo "役割: Context7活用フロントエンド開発"; echo "機能: React最新パターン取得"; echo "共有: tmux_shared_context.md"; echo "準備完了"; cd "'$PROJECT_DIR'"' C-m
    tmux send-keys -t "$session:0.3" 'clear; echo "⚙️ Dev1（Context7統合）"; echo "役割: Context7活用バックエンド開発"; echo "機能: FastAPI最新実装参照"; echo "共有: tmux_shared_context.md"; echo "準備完了"; cd "'$PROJECT_DIR'"' C-m
    tmux send-keys -t "$session:0.4" 'clear; echo "🔒 Dev2（Context7統合）"; echo "役割: Context7活用QA・テスト"; echo "機能: pytest最新テスト手法"; echo "共有: tmux_shared_context.md"; echo "準備完了"; cd "'$PROJECT_DIR'"' C-m
    
    # Step 9: Start Claude with Context7 integration in each pane (5-person architecture)
    log_info "Context7統合Claude起動中（5つの連携役割）..."
    
    # Create shared context file for Context7 integration
    local shared_context="$PROJECT_DIR/tmux_shared_context.md"
    if [ ! -f "$shared_context" ]; then
        echo "# 5人構成並列開発環境 - Context7統合共有コンテキスト" > "$shared_context"
        echo "## 更新時刻: $(date)" >> "$shared_context"
        echo "## 進捗状況:" >> "$shared_context"
        echo "- Manager: Context7統合待機中" >> "$shared_context"
        echo "- CTO: Context7統合待機中" >> "$shared_context"
        echo "- Dev0: Context7統合待機中" >> "$shared_context"
        echo "- Dev1: Context7統合待機中" >> "$shared_context"
        echo "- Dev2: Context7統合待機中" >> "$shared_context"
        echo "" >> "$shared_context"
        echo "## 連携フロー:" >> "$shared_context"
        echo "Manager → CTO → Dev0/Dev1/Dev2 → Manager → CTO" >> "$shared_context"
    fi
    
    # Enhanced context messages with Context7 integration
    local context7_prompt="あなたは5人構成並列開発環境の専門役割です。Context7統合機能を活用して最新技術情報を自動取得し、Microsoft 365 Python移行プロジェクトを効率化してください。tmux_shared_context.mdで他の役割と連携してください。"
    
    # Manager with Context7
    tmux send-keys -t "$session:0.0" "claude --dangerously-skip-permissions \"$context7_prompt \$(cat \"$PROJECT_DIR/tmux/instructions/manager.md\")\"" C-m
    
    # CTO with Context7
    tmux send-keys -t "$session:0.1" "sleep 3 && claude --dangerously-skip-permissions \"$context7_prompt \$(cat \"$PROJECT_DIR/tmux/instructions/cto.md\")\"" C-m
    
    # Dev0, Dev1, Dev2 with Context7
    tmux send-keys -t "$session:0.2" "sleep 6 && claude --dangerously-skip-permissions \"$context7_prompt \$(cat \"$PROJECT_DIR/tmux/instructions/developer.md\")\"" C-m
    tmux send-keys -t "$session:0.3" "sleep 9 && claude --dangerously-skip-permissions \"$context7_prompt \$(cat \"$PROJECT_DIR/tmux/instructions/developer.md\")\"" C-m
    tmux send-keys -t "$session:0.4" "sleep 12 && claude --dangerously-skip-permissions \"$context7_prompt \$(cat \"$PROJECT_DIR/tmux/instructions/developer.md\")\"" C-m
    
    # Step 10: Context7 integration test (removed automatic message sending)
    log_info "Context7統合テスト機能を準備中..."
    # Context7テストメッセージの自動送信を無効化
    # ユーザーが手動でContext7機能をテストできるように待機状態を維持
    
    # Step 11: Pane title maintenance for Context7 session
    (
        sleep 20
        for ((count=1; count<=30; count++)); do
            if ! tmux has-session -t "$session" 2>/dev/null; then
                break
            fi
            
            tmux select-pane -t "$session:0.0" -T "👔 Manager: Context7 + Project Management" 2>/dev/null
            tmux select-pane -t "$session:0.1" -T "💼 CTO: Context7 + Technical Leadership" 2>/dev/null
            tmux select-pane -t "$session:0.2" -T "💻 Dev0: Context7 + Frontend Development" 2>/dev/null
            tmux select-pane -t "$session:0.3" -T "⚙️ Dev1: Context7 + Backend Development" 2>/dev/null
            tmux select-pane -t "$session:0.4" -T "🔒 Dev2: Context7 + QA & Testing" 2>/dev/null
            
            sleep 3
        done
    ) &
    
    # Step 12: Setup automatic connectivity monitoring and collaboration system
    log_info "自動連携監視システムを起動中..."
    
    # Initialize collaboration system
    chmod +x "$PROJECT_DIR/tmux/auto_collaboration.sh" 2>/dev/null || true
    "$PROJECT_DIR/tmux/auto_collaboration.sh" init
    
    # Start monitoring in background
    (
        sleep 15
        # Start collaboration monitoring for 5-person team
        "$PROJECT_DIR/tmux/auto_collaboration.sh" monitor &
        
        # Update shared context timestamp
        if [ -f "$shared_context" ]; then
            sed -i "s/## 更新時刻: .*/## 更新時刻: $(date)/" "$shared_context" 2>/dev/null
        fi
    ) &
    
    # Setup send-message.sh permissions
    chmod +x "$PROJECT_DIR/tmux/send-message.sh" 2>/dev/null || true
    
    # Select main pane (Manager starts first)
    tmux select-pane -t "$session:0.0"
    
    # Session information
    echo ""
    log_success "Context7統合5人構成チーム開発環境が作成されました！"
    echo "🌟 Context7統合機能:"
    echo "   - 最新技術情報自動取得"
    echo "   - ライブラリドキュメント参照"
    echo "   - 実装パターン検索"
    echo "   - トラブルシューティング支援"
    echo "   - Manager→CTO→Dev0/Dev1/Dev2 自動連携"
    echo ""
    echo "📊 構成詳細:"
    echo "   - セッション名: $session"
    echo "   - 総ペイン数: 5"
    echo "   - 左側: 👔 Manager(0) + 💼 CTO(1)"
    echo "   - 右側: 💻 Dev0(2) + ⚙️ Dev1(3) + 🔒 Dev2(4)"
    echo "   - レイアウト: 左30% + 右70%"
    echo "   - Context7統合: 全ペイン対応"
    echo "   - 手動テスト: 各ペインで自由にテスト可能"
    echo "   - 完全自動化: 12秒間隔監視"
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
        read -p "選択してください (0-9): " choice
        echo ""
        
        case $choice in
            1)
                log_info "3人構成を起動します"
                cleanup_sessions
                launch_3person_team
                ;;
            2)
                log_info "5人構成を起動します"
                cleanup_sessions
                launch_5person_team
                ;;
            3)
                log_info "現在のセッション確認・接続"
                show_current_sessions
                ;;
            4)
                log_info "標準3人構成で即座起動"
                cleanup_sessions
                launch_3person_team
                ;;
            5)
                log_info "Context7統合3人構成を起動します"
                cleanup_sessions
                launch_context7_integrated_team
                ;;
            6)
                log_info "Context7統合5人構成を起動します"
                cleanup_sessions
                launch_context7_integrated_5person_team
                ;;
            7)
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
            8)
                cleanup_sessions
                echo ""
                read -p "メニューに戻りますか？ (y/n): " -n 1 -r
                echo ""
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    break
                fi
                ;;
            9)
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
        
        if [ "$choice" != "7" ] && [ "$choice" != "8" ] && [ "$choice" != "9" ] && [ "$choice" != "0" ] && [ "$choice" != "3" ]; then
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