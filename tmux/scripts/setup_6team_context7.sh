#!/bin/bash

# ITSM 6人チーム開発システム v4.0 - Context7統合版
# CTO + Manager + 4Developers構成 with 階層的タスク管理・PowerShell 7専門化・Context7統合

# スクリプトのベースディレクトリ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTRUCTIONS_DIR="$BASE_DIR/instructions"
TMUXSAMPLE_DIR="$BASE_DIR/tmuxsample"
SESSION="MicrosoftProductTools-6team-Context7"

# セッション初期化
tmux kill-session -t $SESSION 2>/dev/null

echo "🔧 6人チーム構成作成（CTO + Manager + Dev4名）Context7統合版"
echo "=================================================================="
echo "仕様: 左側CTO/Manager固定、右側4Dev均等分割 + PowerShell 7専門化(Dev04) + Context7統合"
echo "階層管理: CTO → Manager → Developer自動タスク分配システム"
echo "Dev04特化: Microsoft 365 PowerShell自動化・ログ専門"

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
tmux send-keys -t $SESSION:0.0 'clear; echo "👔 Manager（ペイン0・左上）+ Context7統合"; echo "構成確認: 左上のManager（チーム管理）ペイン（Context7自動統合済み）"' C-m
tmux send-keys -t $SESSION:0.1 'clear; echo "💼 CTO（ペイン1・左下）+ Context7統合"; echo "構成確認: 左下のCTO（戦略統括）ペイン（Context7自動統合済み）"' C-m
tmux send-keys -t $SESSION:0.2 'clear; echo "💻 Dev01（ペイン2・右1番目）+ Context7統合"; echo "構成確認: 右側最上部の開発者（Context7自動統合済み）"' C-m
tmux send-keys -t $SESSION:0.3 'clear; echo "💻 Dev02（ペイン3・右2番目）+ Context7統合"; echo "構成確認: 右側上から2番目の開発者（Context7自動統合済み）"' C-m
tmux send-keys -t $SESSION:0.4 'clear; echo "💻 Dev03（ペイン4・右3番目）+ Context7統合"; echo "構成確認: 右側上から3番目の開発者（Context7自動統合済み）"' C-m
tmux send-keys -t $SESSION:0.5 'clear; echo "🔧 Dev04（ペイン5・右4番目）PowerShell7専門 + Context7統合"; echo "構成確認: PowerShell 7自動化・Microsoft 365専門ペイン（Context7自動統合済み）"' C-m

# ペイン数の検証
PANE_COUNT=$(tmux list-panes -t $SESSION | wc -l)
echo ""
echo "🔍 ペイン数検証: $PANE_COUNT/6"

if [ "$PANE_COUNT" -eq 6 ]; then
    echo "✅ 全ペインが正常に作成されました"
    
    echo ""
    echo "⏳ 3秒後にClaudeエージェント（6人チーム Context7統合版）を起動します..."
    sleep 3
    
    # Claudeエージェント起動
    echo "📂 指示ファイルディレクトリ: $INSTRUCTIONS_DIR"
    echo "📄 ファイル確認:"
    ls -la "$INSTRUCTIONS_DIR"/ 2>/dev/null || echo "⚠️ ディレクトリが見つかりません: $INSTRUCTIONS_DIR"
    
    # Claude認証統一設定＋Context7統合を各ペインに適用
    echo "🔧 Claude認証統一設定＋Context7自動統合を全ペインに適用中..."
    
    # tmux環境変数設定（全ペインで認証統一＋Context7統合）
    tmux set-environment -g CLAUDE_CODE_CONFIG_PATH "$HOME/.local/share/claude"
    tmux set-environment -g CLAUDE_CODE_CACHE_PATH "$HOME/.cache/claude" 
    tmux set-environment -g CLAUDE_CODE_AUTO_START "true"
    tmux set-environment -g CLAUDE_CONTEXT7_ENABLED "true"
    tmux set-environment -g MICROSOFT_TOOLS_PROJECT_ROOT "/mnt/e/MicrosoftProductManagementTools"
    
    if [ -f "$INSTRUCTIONS_DIR/cto.md" ]; then
        # Context7統合版コマンド（MCP Context7サーバーを明示的に指定）
        echo "🌟 Context7統合起動コマンド準備中..."
        
        # CTO（Opus + Context7統合）
        echo "  📡 CTO起動中..."
        tmux send-keys -t $SESSION:0.0 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🌟 CTO + Context7統合起動中...' && claude --model opus --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/cto.md'" C-m
        sleep 2
        
        # Manager（Opus + Context7統合）
        echo "  📡 Manager起動中..."
        tmux send-keys -t $SESSION:0.1 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🌟 Manager + Context7統合起動中...' && claude --model opus --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/manager.md'" C-m
        sleep 2
        
        # Developer01-03（Sonnet + Context7統合）
        echo "  📡 Dev01-03起動中..."
        tmux send-keys -t $SESSION:0.2 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🌟 Dev01 + Context7統合起動中...' && claude --model sonnet --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/developer.md'" C-m
        sleep 1
        tmux send-keys -t $SESSION:0.3 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🌟 Dev02 + Context7統合起動中...' && claude --model sonnet --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/developer.md'" C-m
        sleep 1
        tmux send-keys -t $SESSION:0.4 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🌟 Dev03 + Context7統合起動中...' && claude --model sonnet --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/developer.md'" C-m
        sleep 1
        
        # Developer04（PowerShell 7専門 + Sonnet + Context7統合）
        echo "  🔧 Dev04（PowerShell 7専門）起動中..."
        if [ -f "$INSTRUCTIONS_DIR/powershell-specialist.md" ]; then
            tmux send-keys -t $SESSION:0.5 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🔧 Dev04 PowerShell7専門 + Context7統合起動中...' && claude --model sonnet --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/powershell-specialist.md'" C-m
        else
            # PowerShell専門指示ファイルがない場合は通常のdeveloper.mdを使用
            tmux send-keys -t $SESSION:0.5 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🔧 Dev04 PowerShell7専門 + Context7統合起動中...' && claude --model sonnet --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/developer.md'" C-m
        fi
        
        echo "🚀 Claudeエージェント起動中（認証統一適用済み + Context7統合）..."
        
        # 自動テーマ選択（デフォルトテーマを自動選択）
        echo "⏳ テーマ選択を自動スキップ中..."
        sleep 8
        
        # 各ペインでEnterキーを送信（デフォルトテーマ選択）
        for i in {0..5}; do
            tmux send-keys -t $SESSION:0.$i C-m
        done
        
        echo "✅ テーマ選択自動スキップ完了"
        
        # 日本語設定メッセージを全ペインに自動送信（Enterキー自動押下）
        echo "🌍 日本語設定メッセージ送信中（自動Enterキー押下）..."
        sleep 8
        echo "  📨 CTO..."
        tmux send-keys -t $SESSION:0.0 C-c
        sleep 0.5
        echo "  📨 Context7統合メッセージ送信をスキップしています..."
        # 日本語メッセージは削除されました
        
        # Dev04に特別なPowerShell専門メッセージ
        echo "  🔧 Dev04にPowerShell専門設定..."
        echo "  🔧 Dev04に技術専門設定をスキップしています..."
        # PowerShell専門メッセージは削除されました
        
        echo "✅ 全6ペインに言語・専門設定完了（Enterキー自動押下済み）"
        
        # Context7統合確認メッセージ
        sleep 3
        echo ""
        echo "🌟 Context7統合機能について:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✨ 各Claude AIエージェントにContext7が統合されました"
        echo "🔧 コマンドプロンプト指示時に自動的にContext7経由で実行されます"
        echo "📚 使用可能なContext7機能:"
        echo "   - mcp__context7__resolve-library-id: ライブラリ名からライブラリIDを解決"
        echo "   - mcp__context7__get-library-docs: ライブラリのドキュメントを取得"
        echo "💡 使用例: 'PowerShell Microsoft Graph 最新実装例' と入力すると"
        echo "   自動的にContext7経由で最新ドキュメントを取得して回答します"
        echo "🔧 Dev04特化: PowerShell 7・Microsoft 365自動化・ログ管理専門"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
    else
        echo "⚠️ Claudeエージェント指示ファイルが見つかりません"
        echo "各ペインでmanual setupが必要です"
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
    tmux select-pane -t $SESSION:0.0 -T "👔 Manager+Context7"
    tmux select-pane -t $SESSION:0.1 -T "💼 CTO+Context7"
    tmux select-pane -t $SESSION:0.2 -T "💻 Dev01+Context7"
    tmux select-pane -t $SESSION:0.3 -T "💻 Dev02+Context7"
    tmux select-pane -t $SESSION:0.4 -T "💻 Dev03+Context7"
    tmux select-pane -t $SESSION:0.5 -T "🔧 Dev04-PS7+Context7"
    
    echo ""
    echo "✅ 6人チーム構成起動完了（CTO + Manager + Dev4名 Context7統合版）！"
    
    # 階層的タスク管理システム統合
    echo ""
    echo "🏢 階層的タスク管理システム統合中..."
    if [ -f "$TMUXSAMPLE_DIR/hierarchical-task-system.sh" ]; then
        # 階層的タスク管理システムをバックグラウンドで起動
        echo "✅ 階層的タスク管理システムが利用可能です"
        echo "📋 使用方法:"
        echo "   $BASE_DIR/send-message-enhanced-hierarchical.sh cto-directive \"指示内容\""
        echo "   $BASE_DIR/send-message-enhanced-hierarchical.sh auto-distribute \"タスク内容\""
        echo "   $BASE_DIR/send-message-enhanced-hierarchical.sh collect-reports"
    else
        echo "⚠️ 階層的タスク管理システムが見つかりません"
    fi
    
else
    echo "❌ ペイン作成に失敗しました（$PANE_COUNT/6）"
fi

echo ""
echo "📊 最終ペイン構成（6人チーム Context7統合版）:"
tmux list-panes -t $SESSION -F "ペイン#{pane_index}: #{pane_title} (#{pane_width}x#{pane_height})"

echo ""
echo "📐 実現した構成図（6人チーム Context7統合版）:"
echo "┌─────────────┬─────────────┐"
echo "│             │💻 Dev01+Ctx7│ ← ペイン2"
echo "│             ├─────────────┤"
echo "│👑 CTO       │💻 Dev02+Ctx7│ ← ペイン3"
echo "│+Context7    ├─────────────┤"
echo "│(ペイン0)    │💻 Dev03+Ctx7│ ← ペイン4"
echo "├─────────────┼─────────────┤"
echo "│             │🔧 Dev04-PS7 │ ← ペイン5"
echo "│👔 Manager   │+Context7    │  (PowerShell専門)"
echo "│+Context7    │             │"
echo "│(ペイン1)    │             │"
echo "└─────────────┴─────────────┘"

echo ""
echo "🌟 6人チーム Context7統合機能詳細:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 全てのClaude AIエージェント（CTO、Manager、Dev01-04）にContext7が統合されました"
echo ""
echo "👥 組織構造:"
echo "   👑 CTO (ペイン0): 戦略決定・全体統括"
echo "   👔 Manager (ペイン1): チーム管理・タスク分配・報告統合"
echo "   💻 Dev01 (ペイン2): 一般開発業務"
echo "   💻 Dev02 (ペイン3): 一般開発業務"
echo "   💻 Dev03 (ペイン4): 一般開発業務"
echo "   🔧 Dev04 (ペイン5): PowerShell 7・Microsoft 365自動化・ログ管理専門"
echo ""
echo "📋 利用可能な機能:"
echo "   🔍 resolve-library-id: パッケージ名→Context7ライブラリID変換"
echo "   📚 get-library-docs: 最新ライブラリドキュメント取得"
echo "   🏢 階層的タスク管理: CTO→Manager→Developer自動分配"
echo ""
echo "💡 使用方法:"
echo "   任意のペインで「React Query 最新実装例」「PowerShell Microsoft Graph設定」等を"
echo "   入力すると、自動的にContext7経由で最新情報を取得します"
echo ""
echo "🚀 対象ペイン: 全6ペイン（CTO、Manager、Dev01、Dev02、Dev03、Dev04-PowerShell専門）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "🔧 PowerShell 7専門化詳細（Dev04）:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Dev04はPowerShell 7・Microsoft 365自動化・ログ管理の専門担当です"
echo ""
echo "📋 専門領域:"
echo "   🔧 PowerShell 7スクリプト開発・最適化"
echo "   📊 Microsoft Graph API統合"
echo "   📧 Exchange Online PowerShell管理"
echo "   💾 OneDrive・SharePoint自動化"
echo "   👥 Entra ID・Teams管理"
echo "   📝 ログ管理・監査証跡"
echo "   🔄 自動化スクリプト・スケジューリング"
echo ""
echo "💡 Context7統合:"
echo "   Dev04でPowerShell関連質問をすると、最新のMicrosoft 365"
echo "   PowerShellモジュール情報を自動取得して回答します"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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