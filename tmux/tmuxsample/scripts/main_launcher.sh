#!/bin/bash

# tmux AI並列開発システム - メインランチャー
# エラーハンドリング強化版

set -euo pipefail  # エラー時即座に終了

# スクリプトの場所を取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTRUCTIONS_DIR="$BASE_DIR/instructions"

# ログ関数
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

# Claude認証統一設定
setup_claude_auth() {
    log_info "Claude認証統一設定を適用中..."
    
    # tmux環境変数設定（v3.0統合技術）
    tmux set-environment -g CLAUDE_CODE_CONFIG_PATH "$HOME/.local/share/claude" 2>/dev/null || true
    tmux set-environment -g CLAUDE_CODE_CACHE_PATH "$HOME/.cache/claude" 2>/dev/null || true
    tmux set-environment -g CLAUDE_CODE_AUTO_START "true" 2>/dev/null || true
    
    # bash環境変数設定
    export CLAUDE_CODE_CONFIG_PATH="$HOME/.local/share/claude"
    export CLAUDE_CODE_CACHE_PATH="$HOME/.cache/claude"
    export CLAUDE_CODE_AUTO_START="true"
    
    log_success "Claude認証統一設定完了"
}

# 前提条件チェック
check_prerequisites() {
    log_info "前提条件をチェック中..."
    
    # tmuxがインストールされているか
    if ! command -v tmux &> /dev/null; then
        log_error "tmuxがインストールされていません"
        exit 1
    fi
    
    # claudeがインストールされているか
    if ! command -v claude &> /dev/null; then
        log_error "claudeがインストールされていません"
        exit 1
    fi
    
    # Claude認証統一設定を適用
    setup_claude_auth
    
    # 指示ファイルディレクトリが存在するか
    if [ ! -d "$INSTRUCTIONS_DIR" ]; then
        log_warning "指示ファイルディレクトリが見つかりません: $INSTRUCTIONS_DIR"
        log_info "マニュアルセットアップが必要になります"
    fi
    
    # 実行可能かチェック
    for script in "$SCRIPT_DIR"/setup_*.sh; do
        if [ -f "$script" ] && [ ! -x "$script" ]; then
            log_info "実行権限を設定中: $(basename "$script")"
            chmod +x "$script"
        fi
    done
    
    log_success "前提条件チェック完了"
}

# セッション終了確認
cleanup_sessions() {
    log_info "既存のセッションをチェック中..."
    
    local sessions=$(tmux list-sessions 2>/dev/null | grep -E "claude-team-" | cut -d: -f1 || true)
    
    if [ -n "$sessions" ]; then
        log_warning "既存のClaudeセッションが見つかりました:"
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

# スクリプト実行
run_script() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    
    if [ ! -f "$script_path" ]; then
        log_error "スクリプトが見つかりません: $script_name"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        log_error "スクリプトに実行権限がありません: $script_name"
        return 1
    fi
    
    log_info "$script_name を実行中..."
    
    # スクリプト実行（エラーハンドリング付き）
    if ! "$script_path"; then
        log_error "$script_name の実行中にエラーが発生しました"
        return 1
    fi
    
    log_success "$script_name の実行が完了しました"
}

# メイン表示関数
show_menu() {
    clear
    echo "🚀 ITSM AI チーム開発システム v3.0"
    echo "================================="
    echo ""
    echo "👥 開発チーム構成:"
    echo "1) 2 Developers  - 小規模開発 (Manager + CEO + Dev0-1)"
    echo "2) 4 Developers  - 中規模開発 (Manager + CEO + Dev0-3)"  
    echo "3) 6 Developers  - 大規模開発 (Manager + CEO + Dev0-5) 🌟推奨"
    echo ""
    echo "⚡ 高速セットアップ:"
    echo "4) 現在のセッション確認・接続"
    echo "5) 最新6人構成で即座起動 (推奨設定)"
    echo "6) 🌟 Context7統合6人構成 (自動Context7連携) ✨NEW"
    echo ""
    echo "🛠️  管理・設定:"
    echo "8) 認証URL手動取得"
    echo "9) 既存セッション確認・終了"
    echo ""
    echo "📊 システム仕様:"
    echo "   • 左側: Manager(上) + CEO(下) 固定"
    echo "   • 右側: Dev0-Dev5 均等分割"
    echo "   • 各開発者の専門分野:"
    echo "     - Dev0: フロントエンド/UI 💻"
    echo "     - Dev1: バックエンド/API ⚙️" 
    echo "     - Dev2: QA/テスト 🔒"
    echo "     - Dev3: インフラ/DevOps 🧪"
    echo ""
    echo "🌟 Context7統合機能（オプション6）:"
    echo "   • 自動ライブラリドキュメント取得"
    echo "   • コマンドプロンプト指示で最新情報参照"
    echo "   • 全ペインで統一Context7サポート"
    echo "     - Dev4: データベース/設計 🚀"
    echo "     - Dev5: UI/UX/品質管理 📊"
    echo "   • Claude AI 自動起動・認証"
    echo ""
    echo "0) 終了"
    echo ""
}

# 自動認証統合Claude起動
launch_auto_auth_claude() {
    log_info "3ペイン構成 + 完全自動認証システムを起動します"
    
    # 既存のclaude-dev セッション確認・終了
    if tmux has-session -t claude-dev 2>/dev/null; then
        log_warning "claude-dev セッションが既に存在します"
        echo ""
        read -p "既存セッションを終了して新しく作成しますか？ (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            tmux kill-session -t claude-dev 2>/dev/null || true
            log_info "既存セッションを終了しました"
        else
            log_info "既存セッションにアタッチします"
            tmux attach-session -t claude-dev
            return 0
        fi
    fi
    
    # claude-tmux スクリプトの実行
    local claude_tmux_script="$BASE_DIR/claude-tmux"
    if [ -f "$claude_tmux_script" ] && [ -x "$claude_tmux_script" ]; then
        log_info "claude-tmux スクリプトを実行します"
        exec "$claude_tmux_script"
    else
        log_error "claude-tmux スクリプトが見つかりません: $claude_tmux_script"
        log_info "手動で自動認証システムを設定します..."
        
        # 代替として手動で3ペイン構成作成
        setup_manual_auto_auth
    fi
}

# 完全自動認証統合型6Developer構成
launch_enhanced_6dev_auto_auth() {
    log_info "完全自動認証統合型6Developer構成を起動します"
    
    local session="claude-team-6devs-enhanced"
    local project_dir="/media/kensan/LinuxHDD/ITSM-ITmanagementSystem"
    
    # 既存セッションの確認・終了
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
    
    log_info "6Developer完全自動認証構成を作成中（元の正しいレイアウト）..."
    
    # ステップ1: 新しいセッション作成
    tmux new-session -d -s "$session" -c "$project_dir"
    
    # ステップ2: まず左右に分割（縦線）
    tmux split-window -h -t "$session:0.0" -c "$project_dir"
    # 分割後: 0（左）、1（右）
    
    # ステップ3: 左側を上下に分割（横線）
    tmux split-window -v -t "$session:0.0" -c "$project_dir"
    # 分割後: 0（左上・Manager）、1（左下・CEO）、2（右全体）
    
    # ステップ4: 右側を5回分割し6つのペインにする
    # 右側（現在のペイン2）を上下分割
    tmux split-window -v -t "$session:0.2" -c "$project_dir"
    # 分割後: 0（左上）、1（左下）、2（右上）、3（右下）
    
    # 右上（ペイン2）をさらに上下分割
    tmux split-window -v -t "$session:0.2" -c "$project_dir"
    # 分割後: 0（左上）、1（左下）、2（右上上）、3（右上下）、4（右下）
    
    # 右上下（ペイン3）をさらに上下分割
    tmux split-window -v -t "$session:0.3" -c "$project_dir"
    # 分割後: 0（左上）、1（左下）、2（右1）、3（右2）、4（右3）、5（右下）
    
    # 右下（ペイン5）をさらに上下分割
    tmux split-window -v -t "$session:0.5" -c "$project_dir"
    # 分割後: 0（左上）、1（左下）、2（右1）、3（右2）、4（右3）、5（右4）、6（右5）
    
    # 右5（ペイン6）をさらに上下分割
    tmux split-window -v -t "$session:0.6" -c "$project_dir"
    # 分割後: 0（左上）、1（左下）、2（右1）、3（右2）、4（右3）、5（右4）、6（右5）、7（右6）
    
    # ステップ5: サイズ調整（Claudeプロンプト表示に最適化）
    # 左右のバランス調整（左30%、右70% - Claudeプロンプト表示のため右側をさらに拡張）
    tmux resize-pane -t "$session:0.0" -x 30%
    
    # 右側の6つのペインを完全に均等にする
    log_info "右側Developer領域を均等化中（Claudeプロンプト表示最適化）..."
    sleep 1
    
    # 右側全体の高さを取得し6等分（Claudeプロンプト2行以上確保）
    local window_height=$(tmux display-message -t "$session" -p '#{window_height}')
    local window_width=$(tmux display-message -t "$session" -p '#{window_width}')
    local min_height=4  # Claudeプロンプト2行+余裕2行の最小高さ
    local dev_height=$(( window_height > (min_height * 6) ? window_height / 6 : min_height ))
    local dev_width=$((window_width * 70 / 100))  # 右側70%に拡張（プロンプト表示改善）
    
    log_info "ウィンドウ総高さ: $window_height, 総幅: $window_width"
    log_info "各Devペイン目標高さ: $dev_height, 目標幅: $dev_width"
    
    # 各Developerペインを絶対値で均等に設定
    tmux resize-pane -t "$session:0.2" -y $dev_height
    tmux resize-pane -t "$session:0.3" -y $dev_height
    tmux resize-pane -t "$session:0.4" -y $dev_height
    tmux resize-pane -t "$session:0.5" -y $dev_height
    tmux resize-pane -t "$session:0.6" -y $dev_height
    tmux resize-pane -t "$session:0.7" -y $dev_height
    
    # 微調整：最終均等化（絶対値で再調整）
    local final_height=$((window_height / 6))
    tmux resize-pane -t "$session:0.2" -y $final_height
    tmux resize-pane -t "$session:0.3" -y $final_height
    tmux resize-pane -t "$session:0.4" -y $final_height
    tmux resize-pane -t "$session:0.5" -y $final_height
    tmux resize-pane -t "$session:0.6" -y $final_height
    tmux resize-pane -t "$session:0.7" -y $final_height
    
    # 右側の幅を再調整（Claudeプロンプト用）
    log_info "右側Developer領域の幅を最適化中..."
    tmux resize-pane -t "$session:0.2" -x $dev_width
    
    log_success "右側Developerペインの均等化完了"
    
    # ステップ6: 各ペインの確認とタイトル設定（役職+アイコン）
    log_info "現在のペイン構成:"
    tmux list-panes -t "$session" -F "ペイン#{pane_index}: (#{pane_width}x#{pane_height})"
    
    # tmuxペインタイトル表示を有効化
    tmux set-window-option -t "$session" pane-border-status top
    tmux set-window-option -t "$session" pane-border-format '#[align=centre,bg=colour236,fg=colour255,bold] #{pane_title} #[default]'
    
    # ペインボーダーのスタイル設定
    tmux set-window-option -t "$session" pane-active-border-style 'fg=colour208,bg=default,bold'
    tmux set-window-option -t "$session" pane-border-style 'fg=colour238,bg=default'
    
    # 各ペインにタイトルと確認メッセージを設定
    tmux select-pane -t "$session:0.0" -T "👔 Manager"
    tmux send-keys -t "$session:0.0" 'clear; echo "👔 Manager（ペイン0・左上）"; echo "構成確認: 左上の管理者ペイン"' C-m
    
    tmux select-pane -t "$session:0.1" -T "👑 CEO"
    tmux send-keys -t "$session:0.1" 'clear; echo "👑 CEO（ペイン1・左下）"; echo "構成確認: 左下のCEOペイン"' C-m
    
    tmux select-pane -t "$session:0.2" -T "💻 Dev0"
    tmux send-keys -t "$session:0.2" 'clear; echo "💻 Dev0（ペイン2・右1番目）"; echo "構成確認: 右側最上部の開発者"' C-m
    
    tmux select-pane -t "$session:0.3" -T "⚙️ Dev1"
    tmux send-keys -t "$session:0.3" 'clear; echo "⚙️ Dev1（ペイン3・右2番目）"; echo "構成確認: 右側上から2番目の開発者"' C-m
    
    tmux select-pane -t "$session:0.4" -T "🔒 Dev2"
    tmux send-keys -t "$session:0.4" 'clear; echo "🔒 Dev2（ペイン4・右3番目）"; echo "構成確認: 右側上から3番目の開発者"' C-m
    
    tmux select-pane -t "$session:0.5" -T "🧪 Dev3"
    tmux send-keys -t "$session:0.5" 'clear; echo "🧪 Dev3（ペイン5・右4番目）"; echo "構成確認: 右側上から4番目の開発者"' C-m
    
    tmux select-pane -t "$session:0.6" -T "🚀 Dev4"
    tmux send-keys -t "$session:0.6" 'clear; echo "🚀 Dev4（ペイン6・右5番目）"; echo "構成確認: 右側上から5番目の開発者"' C-m
    
    tmux select-pane -t "$session:0.7" -T "📊 Dev5"
    tmux send-keys -t "$session:0.7" 'clear; echo "📊 Dev5（ペイン7・右6番目）"; echo "構成確認: 右側最下部の開発者"' C-m
    
    # 各ペインで改良された自動認証Claude起動
    log_info "各ペインで改良された自動認証Claude起動中..."
    
    # Claude認証統合設定を各ペインに適用
    tmux set-environment -g CLAUDE_CODE_CONFIG_PATH "$HOME/.local/share/claude"
    tmux set-environment -g CLAUDE_CODE_CACHE_PATH "$HOME/.cache/claude"
    tmux set-environment -g CLAUDE_CODE_AUTO_START "true"
    
    # タイトル表示の再確認と強化
    tmux set-window-option -t "$session" pane-border-status top
    tmux set-window-option -t "$session" pane-border-format '#[align=centre,bg=colour236,fg=colour255,bold] #{pane_title} #[default]'
    
    # ペインボーダーのスタイル設定を強化
    tmux set-window-option -t "$session" pane-active-border-style 'fg=colour208,bg=default,bold'
    tmux set-window-option -t "$session" pane-border-style 'fg=colour238,bg=default'
    
    # 指示ファイルパス確認
    local instructions_dir="$BASE_DIR/instructions"
    
    # 簡単で確実な認証方法を使用
    if [[ -f "$instructions_dir/manager.md" ]]; then
        # 各ペインで直接Claude起動（expectスクリプトを使わない）
        log_info "直接Claude起動モード（より安定）"
        
        # Manager（ペイン0）- Opus 4 モード
        tmux send-keys -t "$session:0.0" "clear && echo '👔 Manager - Claude起動中... (Opus 4 for complex tasks)' && echo '指示ファイル読み込み準備完了' && cd '$project_dir' && export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && claude --model opus --dangerously-skip-permissions '$instructions_dir/manager.md'" C-m
        
        # CEO（ペイン1）- Opus 4 モード - 3秒遅延
        tmux send-keys -t "$session:0.1" "sleep 3 && clear && echo '👑 CEO - Claude起動中... (Opus 4 for complex tasks)' && echo 'CEO指示ファイル読み込み準備完了' && cd '$project_dir' && export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && claude --model opus --dangerously-skip-permissions '$instructions_dir/ceo.md'" C-m
        
        # Developer0-5（各5秒間隔で起動 - シンプルコマンド）
        local dev_roles=("Dev0" "Dev1" "Dev2" "Dev3" "Dev4" "Dev5")
        local dev_icons=("💻" "⚙️" "🔒" "🧪" "🚀" "📊")
        
        for i in {0..5}; do
            local pane_idx=$((i + 2))
            local delay=$((6 + i * 5))
            local role="${dev_roles[$i]}"
            local icon="${dev_icons[$i]}"
            tmux send-keys -t "$session:0.$pane_idx" "sleep $delay && clear && echo '$icon $role - Claude起動中... (Sonnet 4 for daily use)' && echo '開発者指示ファイル読み込み準備完了' && cd '$project_dir' && export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && claude --model sonnet --dangerously-skip-permissions '$instructions_dir/developer.md'" C-m
        done
        
        log_success "8ペイン直接Claude起動コマンド送信完了"
        log_info "各ペインで段階的にClaude起動（最大36秒）"
        log_info "認証が必要な場合は、各ペインで手動で認証してください"
        log_info "ペインタイトル: Claude起動後も役職+アイコン維持"
        log_info "Claude起動: --dangerously-skip-permissions フラグ付き"
        log_info "🧠 モデル設定:"
        log_info "   • Manager・CEO: Opus 4 (complex tasks)"
        log_info "   • Dev0-Dev5: Sonnet 4 (daily use)"
        log_info "⚠️  注意: Claude内部メッセージは英語で表示されます"
        log_info "💡 Claude起動後の操作指示は日本語で記載されています"
        
        # ペインタイトル維持システムをバックグラウンドで実行
        log_info "ペインタイトル維持システムを起動中..."
        (
            # Claude起動を待ってからタイトル再設定開始
            sleep 15
            for ((count=1; count<=30; count++)); do
                # セッションが存在するか確認
                if ! tmux has-session -t "$session" 2>/dev/null; then
                    break
                fi
                
                # 各ペインのタイトルを再設定
                tmux select-pane -t "$session:0.0" -T "👔 Manager" 2>/dev/null
                tmux select-pane -t "$session:0.1" -T "👑 CEO" 2>/dev/null
                tmux select-pane -t "$session:0.2" -T "💻 Dev0" 2>/dev/null
                tmux select-pane -t "$session:0.3" -T "⚙️ Dev1" 2>/dev/null
                tmux select-pane -t "$session:0.4" -T "🔒 Dev2" 2>/dev/null
                tmux select-pane -t "$session:0.5" -T "🧪 Dev3" 2>/dev/null
                tmux select-pane -t "$session:0.6" -T "🚀 Dev4" 2>/dev/null
                tmux select-pane -t "$session:0.7" -T "📊 Dev5" 2>/dev/null
                
                sleep 3
            done
        ) &
    else
        log_warning "指示ファイルが見つかりません: $instructions_dir"
        log_info "基本的なClaude起動を実行します"
        
        # 基本的なClaude起動
        local roles=("Manager" "CEO" "Frontend" "Backend" "Security" "QA" "DevOps" "Data")
        local icons=("👔" "👑" "💻" "⚙️" "🔒" "🧪" "🚀" "📊")
        
        for pane in 0 1 2 3 4 5 6 7; do
            local delay=$((pane * 3))
            local role="${roles[$pane]}"
            local icon="${icons[$pane]}"
            tmux send-keys -t "$session:0.$pane" "sleep $delay && clear && echo '$icon $role - Claude起動中...' && cd '$project_dir' && export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && claude --dangerously-skip-permissions" C-m
        done
    fi
    
    # メインペインを選択
    tmux select-pane -t "$session:0.0"
    
    # セッション情報表示
    echo ""
    log_success "完全自動認証統合型6Developer構成が作成されました！"
    echo "📊 構成詳細:"
    echo "   - セッション名: $session"
    echo "   - 総ペイン数: 8"
    echo "   - 左側: 👔 Manager(0) + 👑 CEO(1)"
    echo "   - 右側: 💻 Dev0(2) + ⚙️ Dev1(3) + 🔒 Dev2(4) + 🧪 Dev3(5) + 🚀 Dev4(6) + 📊 Dev5(7)"
    echo "   - 認証方式: 直接Claude起動（より安定）"
    echo "   - レイアウト: 左35% + 右65%（Claudeプロンプト表示最適化）"
    echo "   - ペインタイトル: 役職+アイコン表示"
    echo "   - Claude起動メッセージ: 日本語表示"
    echo "   - 注意: Claude内部メッセージは英語（変更不可）"
    echo ""
    echo "🚀 接続コマンド: tmux attach-session -t $session"
    echo ""
    
    # セッションにアタッチ
    read -p "セッションに接続しますか？ (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tmux attach-session -t "$session"
    else
        echo "手動接続: tmux attach-session -t $session"
    fi
}

# 手動自動認証セットアップ
setup_manual_auto_auth() {
    local session="claude-dev"
    local project_dir="/media/kensan/LinuxHDD/ITSM-ITmanagementSystem"
    
    log_info "手動で3ペイン + 自動認証構成を作成します"
    
    # 新しいセッションを作成
    tmux new-session -d -s "$session" -c "$project_dir"
    
    # 2つ目のペインを水平分割で作成
    tmux split-window -h -t "$session" -c "$project_dir"
    
    # 3つ目のペインを垂直分割で作成（右側を上下に分割）
    tmux split-window -v -t "$session:0.1" -c "$project_dir"
    
    # 各ペインでのコマンド実行
    log_info "各ペインで自動認証Claudeを起動します..."
    
    # ペイン0: メインのClaude（自動認証）
    tmux send-keys -t "$session:0.0" 'clear && echo "=== Claude Code Main Session (Auto-Auth) ===" && cd tmux && ./auto-claude-auth.sh --quick' C-m
    
    # ペイン1: サブのClaude（自動認証）
    tmux send-keys -t "$session:0.1" 'clear && echo "=== Claude Code Work Session (Auto-Auth) ===" && sleep 5 && cd tmux && ./auto-claude-auth.sh --quick' C-m
    
    # ペイン2: システムコマンド用
    tmux send-keys -t "$session:0.2" 'clear && echo "=== System Commands ===" && echo "プロジェクトディレクトリ: $PWD" && echo "自動認証スクリプト: tmux/auto-claude-auth.sh"' C-m
    
    # ペインのレイアウト調整
    tmux select-layout -t "$session" main-vertical
    
    # メインペインを選択
    tmux select-pane -t "$session:0.0"
    
    # セッションにアタッチ
    log_success "3ペイン + 自動認証構成でセッションを作成しました"
    tmux attach-session -t "$session"
}

# 現在のセッション確認・接続
show_current_sessions() {
    log_info "現在のtmuxセッションを確認中..."
    
    local sessions=$(tmux list-sessions 2>/dev/null | grep -E "claude-team-" | cut -d: -f1 || true)
    
    if [ -n "$sessions" ]; then
        log_success "アクティブなClaudeセッションが見つかりました:"
        echo "$sessions" | while read -r session; do
            local pane_count=$(tmux list-panes -t "$session" 2>/dev/null | wc -l)
            echo "  📊 $session (ペイン数: $pane_count)"
        done
        echo ""
        
        # 最初のセッションに接続するか確認
        local first_session=$(echo "$sessions" | head -n1)
        read -p "セッション '$first_session' に接続しますか？ (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "セッション '$first_session' に接続中..."
            tmux attach-session -t "$first_session"
        fi
    else
        log_warning "アクティブなClaudeセッションが見つかりません"
        log_info "新しいセッションを作成するには、メニューから選択してください"
    fi
}

# 認証URL手動取得
manual_auth_url_setup() {
    log_info "認証URL手動取得を実行します"
    
    local auth_script="$BASE_DIR/get-auth-url-manual.sh"
    if [ -f "$auth_script" ] && [ -x "$auth_script" ]; then
        "$auth_script"
    else
        log_error "認証URL取得スクリプトが見つかりません: $auth_script"
        log_info "tmux/get-auth-url-manual.sh を確認してください"
    fi
}

# メイン処理
main() {
    # 前提条件チェック
    check_prerequisites
    
    while true; do
        show_menu
        read -p "選択してください (0-6, 8-9): " choice
        echo ""
        
        case $choice in
            1)
                log_info "2 Developers構成を起動します"
                cleanup_sessions
                run_script "$SCRIPT_DIR/setup_2devs_new.sh"
                ;;
            2)
                log_info "4 Developers構成を起動します"
                cleanup_sessions
                run_script "$SCRIPT_DIR/setup_4devs_new.sh"
                ;;
            3)
                log_info "6 Developers構成を起動します"
                cleanup_sessions
                run_script "$SCRIPT_DIR/setup_6devs_new.sh"
                ;;
            4)
                log_info "現在のセッション確認・接続"
                show_current_sessions
                ;;
            5)
                log_info "最新6人構成で即座起動"
                cleanup_sessions
                launch_enhanced_6dev_auto_auth
                ;;
            6)
                log_info "Context7統合6人構成を起動します"
                cleanup_sessions
                run_script "$SCRIPT_DIR/setup_6devs_context7.sh"
                ;;
            8)
                manual_auth_url_setup
                echo ""
                read -p "メニューに戻りますか？ (y/n): " -n 1 -r
                echo ""
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    break
                fi
                ;;
            9)
                cleanup_sessions
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
        
        if [ "$choice" != "8" ] && [ "$choice" != "9" ] && [ "$choice" != "0" ] && [ "$choice" != "4" ] && [ "$choice" != "5" ]; then
            echo ""
            read -p "メニューに戻りますか？ (y/n): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                break
            fi
        fi
    done
}

# エラートラップ
trap 'log_error "予期しないエラーが発生しました (行: $LINENO)"' ERR

# メイン実行
main "$@"