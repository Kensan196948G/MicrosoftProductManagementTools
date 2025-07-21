#!/bin/bash

# ITSM 6人チーム開発システム v4.1 - Claude起動問題修正版
# CTO + Manager + 4Developers構成 with 階層的タスク管理・PowerShell 7専門化・Context7統合

# スクリプトのベースディレクトリ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTRUCTIONS_DIR="$BASE_DIR/instructions"
TMUXSAMPLE_DIR="$BASE_DIR/tmuxsample"
SESSION="MicrosoftProductTools-6team-Context7"

# セッション初期化
tmux kill-session -t $SESSION 2>/dev/null

echo "🔧 6人チーム構成作成（CTO + Manager + Dev4名）Context7統合版 - 修正版"
echo "=================================================================="
echo "仕様: 左側CTO/Manager固定、右側4Dev均等分割 + PowerShell 7専門化(Dev04) + Context7統合"
echo "修正: Claude起動問題の解決、指示ファイル問題の修正"

echo "ステップ1: 新しいセッションを作成"
tmux new-session -d -s $SESSION

echo "ステップ2: まず左右に分割（縦線）"
# 左右分割 - これで0（左）、1（右）になる
tmux split-window -h -t $SESSION:0.0
echo "分割後: 0（左）、1（右）"

echo "ステップ3: 左側を上下に分割（横線）"
# 左側（ペイン0）を上下分割 - 0（上）、1（下）になり、元の1は2になる
tmux split-window -v -t $SESSION:0.0
echo "分割後: 0（左上・CTO）、1（左下・Manager）、2（右全体）"

echo "ステップ4: 右側を3回分割して4つのペインにする"
echo "現在の構成: 0（左上）、1（左下）、2（右全体）"

# 右側（現在のペイン2）を上下分割
tmux split-window -v -t $SESSION:0.2
echo "分割1: 0（左上）、1（左下）、2（右上）、3（右下）"

# 右上（ペイン2）をさらに上下分割
tmux split-window -v -t $SESSION:0.2
echo "分割2: 0（左上）、1（左下）、2（右1）、3（右2）、4（右下）"

# 右下（ペイン4）をさらに上下分割
tmux split-window -v -t $SESSION:0.4
echo "分割3: 0（左上）、1（左下）、2（右1）、3（右2）、4（右3）、5（右4）"

echo "ステップ5: サイズ調整（Claude Code + PowerShell最適化）"
# 左右のバランス調整（左30%、右70%でプロンプト確実に1行化）
tmux resize-pane -t $SESSION:0.0 -x 30%

# 右側の4つのペインを完全に均等にする
echo "右側Developer領域を均等化中（PowerShell 7最適化）..."
sleep 1

# Claude Code + PowerShell プロンプト最適化サイズ設定
echo "Claude Code + PowerShell 7表示最適化中（右側ペイン均等間隔化）..."
DEV_HEIGHT=8  # PowerShellプロンプト + Claude Codeが明確に表示される高さ

echo "各Devペイン目標高さ: $DEV_HEIGHT行（均等間隔＋PowerShell + Claude Code最適化済み）"

# 各Developerペインを均等間隔でPowerShell + Claude Code表示に最適化
for i in {2..5}; do
    tmux resize-pane -t $SESSION:0.$i -y $DEV_HEIGHT
    sleep 0.3
done

# 微調整：完全均等化
echo "右側ペイン完全均等化実行中..."
for i in {2..5}; do
    tmux resize-pane -t $SESSION:0.$i -y $DEV_HEIGHT
    sleep 0.2
done

# PowerShell 7 + Claude Code表示最適化設定
tmux set-environment -t $SESSION COLUMNS 120
tmux set-environment -t $SESSION LINES 10
tmux set-environment -t $SESSION TERM xterm-256color
tmux set-environment -t $SESSION CLAUDE_FORCE_TTY 1
tmux set-environment -t $SESSION CLAUDE_PROMPT_WIDTH 120
tmux set-environment -t $SESSION POWERSHELL_VERSION 7

echo "ステップ6: 各ペインの確認とタイトル設定"
echo "現在のペイン構成:"
tmux list-panes -t $SESSION -F "ペイン#{pane_index}: (#{pane_width}x#{pane_height})"

# 各ペインにタイトルと確認メッセージを設定
tmux send-keys -t $SESSION:0.0 'clear; echo "👔 Manager（ペイン0・左上）+ Context7統合"; echo "構成確認: 左上のManager（チーム管理）ペイン（Context7自動統合準備中）"' C-m
tmux send-keys -t $SESSION:0.1 'clear; echo "💼 CTO（ペイン1・左下）+ Context7統合"; echo "構成確認: 左下のCTO（戦略統括）ペイン（Context7自動統合準備中）"' C-m
tmux send-keys -t $SESSION:0.2 'clear; echo "💻 Dev01（ペイン2・右1番目）+ Context7統合"; echo "構成確認: 右側最上部の開発者（Context7自動統合準備中）"' C-m
tmux send-keys -t $SESSION:0.3 'clear; echo "💻 Dev02（ペイン3・右2番目）+ Context7統合"; echo "構成確認: 右側上から2番目の開発者（Context7自動統合準備中）"' C-m
tmux send-keys -t $SESSION:0.4 'clear; echo "💻 Dev03（ペイン4・右3番目）+ Context7統合"; echo "構成確認: 右側上から3番目の開発者（Context7自動統合準備中）"' C-m
tmux send-keys -t $SESSION:0.5 'clear; echo "🔧 Dev04（ペイン5・右4番目）PowerShell7専門 + Context7統合"; echo "構成確認: PowerShell 7自動化・Microsoft 365専門ペイン（Context7自動統合準備中）"' C-m

# ペイン数の検証
PANE_COUNT=$(tmux list-panes -t $SESSION | wc -l)
echo ""
echo "🔍 ペイン数検証: $PANE_COUNT/6"

if [ "$PANE_COUNT" -eq 6 ]; then
    echo "✅ 全ペインが正常に作成されました"
    
    echo ""
    echo "⏳ 3秒後にClaudeエージェント（6人チーム Context7統合版）を起動します..."
    sleep 3
    
    # 指示ファイル確認
    echo "📂 指示ファイルディレクトリ: $INSTRUCTIONS_DIR"
    echo "📄 ファイル確認:"
    ls -la "$INSTRUCTIONS_DIR"/ 2>/dev/null || echo "⚠️ ディレクトリが見つかりません: $INSTRUCTIONS_DIR"
    
    # 必要なファイルの存在確認
    files_ok=true
    if [[ ! -f "$INSTRUCTIONS_DIR/cto.md" ]]; then
        echo "❌ cto.md が見つかりません"
        files_ok=false
    fi
    if [[ ! -f "$INSTRUCTIONS_DIR/manager.md" ]]; then
        echo "❌ manager.md が見つかりません" 
        files_ok=false
    fi
    if [[ ! -f "$INSTRUCTIONS_DIR/developer.md" ]]; then
        echo "❌ developer.md が見つかりません"
        files_ok=false
    fi
    if [[ ! -f "$INSTRUCTIONS_DIR/powershell-specialist.md" ]]; then
        echo "❌ powershell-specialist.md が見つかりません"
        files_ok=false
    fi
    
    if [[ "$files_ok" == true ]]; then
        echo "✅ 全ての指示ファイルが確認されました"
        
        # Claude認証統一設定＋Context7統合を各ペインに適用
        echo "🔧 Claude認証統一設定＋Context7自動統合を全ペインに適用中..."
        
        # tmux環境変数設定（全ペインで認証統一＋Context7統合）
        tmux set-environment -g CLAUDE_CODE_CONFIG_PATH "$HOME/.local/share/claude"
        tmux set-environment -g CLAUDE_CODE_CACHE_PATH "$HOME/.cache/claude" 
        tmux set-environment -g CLAUDE_CODE_AUTO_START "true"
        tmux set-environment -g CLAUDE_CONTEXT7_ENABLED "true"
        tmux set-environment -g MICROSOFT_TOOLS_PROJECT_ROOT "/mnt/e/MicrosoftProductManagementTools"
        
        echo "🌟 Claude起動コマンド準備中..."
        
        # 正しいペイン配置でClaude起動（permissions skip版）
        echo "  📡 Manager起動中(ペイン0・左上)..."
        tmux send-keys -t $SESSION:0.0 C-c
        sleep 0.5
        tmux send-keys -t $SESSION:0.0 "claude --dangerously-skip-permissions '$INSTRUCTIONS_DIR/manager.md'" C-m
        sleep 3
        
        echo "  📡 CTO起動中(ペイン1・左下)..."
        tmux send-keys -t $SESSION:0.1 C-c
        sleep 0.5
        tmux send-keys -t $SESSION:0.1 "claude --dangerously-skip-permissions '$INSTRUCTIONS_DIR/cto.md'" C-m
        sleep 3
        
        echo "  📡 Dev01-03起動中..."
        tmux send-keys -t $SESSION:0.2 C-c
        sleep 0.5
        tmux send-keys -t $SESSION:0.2 "claude --dangerously-skip-permissions '$INSTRUCTIONS_DIR/developer.md'" C-m
        sleep 2
        
        tmux send-keys -t $SESSION:0.3 C-c
        sleep 0.5
        tmux send-keys -t $SESSION:0.3 "claude --dangerously-skip-permissions '$INSTRUCTIONS_DIR/developer.md'" C-m
        sleep 2
        
        tmux send-keys -t $SESSION:0.4 C-c
        sleep 0.5
        tmux send-keys -t $SESSION:0.4 "claude --dangerously-skip-permissions '$INSTRUCTIONS_DIR/developer.md'" C-m
        sleep 2
        
        echo "  🔧 Dev04（PowerShell 7専門）起動中..."
        tmux send-keys -t $SESSION:0.5 C-c
        sleep 0.5
        tmux send-keys -t $SESSION:0.5 "claude --dangerously-skip-permissions '$INSTRUCTIONS_DIR/powershell-specialist.md'" C-m
        sleep 2
        
        echo "🚀 Claudeエージェント起動中（Context7統合準備）..."
        
        # テーマ選択の自動スキップを試行
        echo "⏳ Claude初期化待機中..."
        sleep 10
        
        echo "🎨 デフォルトテーマ選択試行中..."
        # 各ペインでEnterキーを送信（デフォルトテーマ選択試行）
        for i in {0..5}; do
            tmux send-keys -t $SESSION:0.$i C-m 2>/dev/null
            sleep 0.5
        done
        
        echo "✅ Claude起動プロセス完了"
        
        # 日本語設定メッセージを全ペインに送信
        echo "🌍 日本語設定メッセージ送信中..."
        sleep 5
        
        echo "  📨 全ペインにContext7統合日本語設定中..."
        
        # Claudeが完全に起動するまで待機
        echo "  ⏳ Claude起動完了を待機中..."
        sleep 5
        
        echo "  👔 Managerにメッセージ送信..."
        tmux send-keys -t $SESSION:0.0 C-c  # 現在の入力をキャンセル
        sleep 0.5
        tmux send-keys -t $SESSION:0.0 "Context7が統合されたマネージャーとして日本語で対応してください。プロジェクト管理とチーム調整を担当します。" C-m
        sleep 2
        
        echo "  💼 CTOにメッセージ送信..."
        tmux send-keys -t $SESSION:0.1 C-c  # 現在の入力をキャンセル
        sleep 0.5
        tmux send-keys -t $SESSION:0.1 "Context7が統合されたCTOとして日本語で対応してください。技術戦略とアーキテクチャ決定を担当します。" C-m
        sleep 2
        
        echo "  💻 Dev01-03にメッセージ送信（一括送信）..."
        for i in {2..4}; do
            echo "    Dev0$((i-1))に送信中..."
            tmux send-keys -t $SESSION:0.$i C-c  # 現在の入力をキャンセル
            sleep 0.5
            tmux send-keys -t $SESSION:0.$i "Context7が統合された開発者として日本語で対応してください。最新技術情報を活用して開発作業を行ってください。" C-m
            sleep 1
        done
        
        echo "  🔧 Dev04 (PowerShell専門)にメッセージ送信..."
        tmux send-keys -t $SESSION:0.5 C-c  # 現在の入力をキャンセル
        sleep 0.5
        tmux send-keys -t $SESSION:0.5 "Context7が統合されたPowerShell専門家として日本語で対応してください。PowerShell 7、Microsoft 365自動化、ログ管理の専門家として活動してください。" C-m
        sleep 2
        
        echo "✅ 全6ペインに言語・専門設定完了"
        
        # プロンプトクリア処理（残存メッセージの自動送信）
        echo "🔄 全ペインプロンプトクリア処理実行中..."
        sleep 2
        
        for pane in {0..5}; do
            echo "  ペイン$pane プロンプトクリア中..."
            tmux send-keys -t $SESSION:0.$pane C-c 2>/dev/null || true
            sleep 0.3
            tmux send-keys -t $SESSION:0.$pane "" C-m 2>/dev/null || true
            sleep 0.2
        done
        
        echo "✅ 全ペインプロンプトクリア処理完了"
        
        # Context7統合説明
        sleep 3
        echo ""
        echo "🌟 Context7統合について:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📋 Context7統合は手動で設定してください："
        echo "   1. 各ペインでClaude起動後、Context7 MCPサーバーを手動設定"
        echo "   2. 設定方法: Claudeに「Context7を有効にしてください」と指示"
        echo "   3. または claude --mcp-config オプションで起動時に設定"
        echo ""
        echo "💡 使用例:"
        echo "   各ペインで「React Query 最新実装例」「PowerShell Microsoft Graph設定」等を"
        echo "   入力すると、Context7経由で最新情報を取得できます"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
    else
        echo "⚠️ 一部指示ファイルが見つかりません。手動でClaude設定が必要です"
        echo "各ペインでmanual setupを行ってください"
        
        # 基本的なClaude起動のみ実行
        echo "🔧 基本Claude起動を試行中..."
        for i in {0..5}; do
            tmux send-keys -t $SESSION:0.$i "claude --dangerously-skip-permissions" C-m
            sleep 1
        done
    fi

    # tmux表示設定
    echo "🎨 tmux表示設定中（6人チーム Context7統合版）..."
    tmux set-option -t $SESSION pane-border-status top
    tmux set-option -t $SESSION pane-border-format "#{pane_title}"
    tmux set-option -t $SESSION status-format[1] "#[align=centre]#{P:#{?pane_active,#[reverse],}#{pane_title}#[default] }"
    tmux set-option -t $SESSION status-left "#[fg=green]ITSM 6Team: #S #[fg=blue]| "
    tmux set-option -t $SESSION status-right "#[fg=yellow]🌟 CTO+Mgr+Dev4 #[fg=cyan]%H:%M"
    
    # ペインタイトルを設定（6人チーム Context7統合版）
    echo "🏷️ ペインタイトル設定中（6人チーム Context7統合版）..."
    sleep 1
    tmux select-pane -t $SESSION:0.0 -T "👔 Manager: 進捗管理 | 待機中"
    tmux select-pane -t $SESSION:0.1 -T "💼 CTO: 技術戦略 | 待機中"
    tmux select-pane -t $SESSION:0.2 -T "💻 Dev01: 開発作業 | 待機中"
    tmux select-pane -t $SESSION:0.3 -T "💻 Dev02: 開発作業 | 待機中"
    tmux select-pane -t $SESSION:0.4 -T "💻 Dev03: 開発作業 | 待機中"
    tmux select-pane -t $SESSION:0.5 -T "🔧 Dev04: PowerShell専門 | 待機中"
    
    echo ""
    echo "✅ 6人チーム構成起動完了（CTO + Manager + Dev4名 Context7統合版）！"
    
    # 階層的タスク管理システム統合
    echo ""
    echo "🏢 階層的タスク管理システム統合中..."
    if [ -f "$BASE_DIR/hierarchical-task-system-6team.sh" ]; then
        echo "✅ 階層的タスク管理システムが利用可能です"
        echo "📋 使用方法:"
        echo "   $BASE_DIR/hierarchical-task-system-6team.sh cto-directive \"指示内容\""
        echo "   $BASE_DIR/hierarchical-task-system-6team.sh auto-distribute \"タスク内容\""
        echo "   $BASE_DIR/hierarchical-task-system-6team.sh collect-reports"
    else
        echo "⚠️ 階層的タスク管理システムが見つかりません"
    fi
    
    # 相互連携設定の初期化
    echo "🔗 相互連携システム設定中..."
    
    # 共有コンテキストファイルの作成
    SHARED_CONTEXT="/mnt/e/MicrosoftProductManagementTools/tmux_shared_context.md"
    echo "# 6人構成並列開発環境 - Context7統合共有コンテキスト" > "$SHARED_CONTEXT"
    echo "## 更新時刻: $(date)" >> "$SHARED_CONTEXT"
    echo "## 進捗状況:" >> "$SHARED_CONTEXT"
    echo "- Manager: Context7統合待機中" >> "$SHARED_CONTEXT"
    echo "- CTO: Context7統合待機中" >> "$SHARED_CONTEXT"
    echo "- Dev01: 待機中" >> "$SHARED_CONTEXT"
    echo "- Dev02: 待機中" >> "$SHARED_CONTEXT"
    echo "- Dev03: 待機中" >> "$SHARED_CONTEXT"
    echo "- Dev04: PowerShell専門待機中" >> "$SHARED_CONTEXT"
    echo "" >> "$SHARED_CONTEXT"
    echo "## 連携フロー:" >> "$SHARED_CONTEXT"
    echo "Manager → CTO → Dev01/Dev02/Dev03/Dev04 → CTO → Manager" >> "$SHARED_CONTEXT"
    echo "" >> "$SHARED_CONTEXT"
    echo "## メッセージ送信方法:" >> "$SHARED_CONTEXT"
    echo "./tmux/send-message.sh [role] [メッセージ]" >> "$SHARED_CONTEXT"
    echo "./tmux/send-message.sh manager \"【報告】タスク完了\"" >> "$SHARED_CONTEXT"
    
    # send-message.shの実行権限設定
    chmod +x "/mnt/e/MicrosoftProductManagementTools/tmux/send-message.sh" 2>/dev/null || true
    
else
    echo "❌ ペイン作成に失敗しました（$PANE_COUNT/6）"
fi

echo ""
echo "📊 最終ペイン構成（6人チーム Context7統合版）:"
tmux list-panes -t $SESSION -F "ペイン#{pane_index}: #{pane_title} (#{pane_width}x#{pane_height})"

echo ""
echo "📐 実現した構成図（6人チーム Context7統合版）:"
echo "┌─────────────┬─────────────┐"
echo "│             │💻 Dev01     │ ← ペイン2"
echo "│             ├─────────────┤"
echo "│👔 Manager   │💻 Dev02     │ ← ペイン3"
echo "│進捗管理     ├─────────────┤"
echo "│(ペイン0)    │💻 Dev03     │ ← ペイン4"
echo "├─────────────┼─────────────┤"
echo "│             │🔧 Dev04     │ ← ペイン5"
echo "│💼 CTO       │PowerShell専門│"
echo "│技術戦略     │             │"
echo "│(ペイン1)    │             │"
echo "└─────────────┴─────────────┘"

echo ""
echo "🔧 Claude起動状況確認:"
echo "────────────────────────────────────────────────────────────────"
echo "各ペインでClaudeプロセス起動状況を確認してください:"
tmux list-panes -t $SESSION -F "ペイン#{pane_index}: #{pane_current_command}"

echo ""
echo "📋 Claude手動設定が必要な場合:"
echo "1. 各ペインでClaude起動が失敗している場合は手動で 'claude' コマンドを実行"
echo "2. Context7統合が必要な場合は、Claudeに「Context7を有効にしてください」と指示"
echo "3. 指示ファイルを再読み込みする場合は 'claude [ファイルパス]' で再実行"

echo ""
echo "🚀 接続コマンド: tmux attach-session -t $SESSION"
echo ""
echo "💡 操作のヒント:"
echo "- ペイン切り替え: Ctrl+b → 矢印キー"
echo "- ペインサイズ調整: Ctrl+b → Ctrl+矢印キー"
echo "- セッション切断: Ctrl+b → d"
echo "- セッション終了: exit（各ペインで）またはtmux kill-session -t $SESSION"

# セッションにアタッチ
echo ""
read -p "セッションに接続しますか？ (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    tmux attach-session -t $SESSION
else
    echo ""
    echo "手動接続: tmux attach-session -t $SESSION"
fi