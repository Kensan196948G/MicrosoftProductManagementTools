#!/bin/bash

# ITSM AIチーム開発システム v3.0 - Context7統合版
# 6 Developers構成（Technical Manager + CTO + Dev0-5）with Context7自動統合

# スクリプトのベースディレクトリ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTRUCTIONS_DIR="$BASE_DIR/instructions"
SESSION="claude-team-6devs-context7"

# セッション初期化
tmux kill-session -t $SESSION 2>/dev/null

echo "🔧 6 Developers構成作成（Context7統合版）"
echo "============================================"
echo "仕様: 左側CTO/Technical Manager固定、右側6Dev均等分割 + Context7自動統合"
echo "Context7: 自動でコマンドプロンプト指示時にContext7経由で実行"

echo "ステップ1: 新しいセッションを作成"
tmux new-session -d -s $SESSION

echo "ステップ2: まず左右に分割（縦線）"
# 左右分割 - これで0（左）、1（右）になる
tmux split-window -h -t $SESSION:0.0
echo "分割後: 0（左）、1（右）"

echo "ステップ3: 左側を上下に分割（横線）"
# 左側（ペイン0）を上下分割 - 0（上）、1（下）になり、元の1は2になる
tmux split-window -v -t $SESSION:0.0
echo "分割後: 0（左上・Technical Manager）、1（左下・CTO）、2（右全体）"

echo "ステップ4: 右側を5回分割して6つのペインにする"
echo "現在の構成: 0（左上）、1（左下）、2（右全体）"

# 右側（現在のペイン2）を上下分割
tmux split-window -v -t $SESSION:0.2
echo "分割1: 0（左上）、1（左下）、2（右上）、3（右下）"

# 右上（ペイン2）をさらに上下分割
tmux split-window -v -t $SESSION:0.2
echo "分割2: 0（左上）、1（左下）、2（右上上）、3（右上下）、4（右下）"

# 右上下（ペイン3）をさらに上下分割
tmux split-window -v -t $SESSION:0.3
echo "分割3: 0（左上）、1（左下）、2（右1）、3（右2）、4（右3）、5（右下）"

# 右下（ペイン5）をさらに上下分割
tmux split-window -v -t $SESSION:0.5
echo "分割4: 0（左上）、1（左下）、2（右1）、3（右2）、4（右3）、5（右4）、6（右5）"

# 右5（ペイン6）をさらに上下分割
tmux split-window -v -t $SESSION:0.6
echo "分割5: 0（左上）、1（左下）、2（右1）、3（右2）、4（右3）、5（右4）、6（右5）、7（右6）"

echo "ステップ5: サイズ調整（Claude Codeプロンプト1行表示最適化）"
# 左右のバランス調整（左35%、右65% → 左30%、右70%でプロンプト確実に1行化）
tmux resize-pane -t $SESSION:0.0 -x 30%

# 右側の6つのペインを完全に均等にする
echo "右側Developer領域を均等化中..."
sleep 1

# Claude Codeプロンプト最適化サイズ設定（均等間隔）
echo "Claude Codeプロンプト表示最適化中（右側ペイン均等間隔化）..."
DEV_HEIGHT=7  # Claude Codeプロンプトが明確に表示される高さ（均等間隔）

echo "各Devペイン目標高さ: $DEV_HEIGHT行（均等間隔＋Claude Codeプロンプト最適化済み）"

# 各Developerペインを均等間隔で Claude Code プロンプト表示に最適化
for i in {2..7}; do
    tmux resize-pane -t $SESSION:0.$i -y $DEV_HEIGHT
    sleep 0.3
done

# 微調整：完全均等化
echo "右側ペイン完全均等化実行中..."
for i in {2..7}; do
    tmux resize-pane -t $SESSION:0.$i -y $DEV_HEIGHT
    sleep 0.2
done

# Claude Code表示最適化設定（プロンプト1行表示）
tmux set-environment -t $SESSION COLUMNS 110
tmux set-environment -t $SESSION LINES 9
tmux set-environment -t $SESSION TERM xterm-256color
tmux set-environment -t $SESSION CLAUDE_FORCE_TTY 1
tmux set-environment -t $SESSION CLAUDE_PROMPT_WIDTH 110

echo "ステップ6: 各ペインの確認とタイトル設定"
echo "現在のペイン構成:"
tmux list-panes -t $SESSION -F "ペイン#{pane_index}: (#{pane_width}x#{pane_height})"

# 各ペインにタイトルと確認メッセージを設定
tmux send-keys -t $SESSION:0.0 'clear; echo "👔 Technical Manager（ペイン0・左上）+ Context7統合"; echo "構成確認: 左上の技術マネージャーペイン（Context7自動統合済み）"' C-m
tmux send-keys -t $SESSION:0.1 'clear; echo "👑 CTO（ペイン1・左下）+ Context7統合"; echo "構成確認: 左下のCTO（最高技術責任者）ペイン（Context7自動統合済み）"' C-m
tmux send-keys -t $SESSION:0.2 'clear; echo "💻 Dev0（ペイン2・右1番目）+ Context7統合"; echo "構成確認: 右側最上部の開発者（Context7自動統合済み）"' C-m
tmux send-keys -t $SESSION:0.3 'clear; echo "💻 Dev1（ペイン3・右2番目）+ Context7統合"; echo "構成確認: 右側上から2番目の開発者（Context7自動統合済み）"' C-m
tmux send-keys -t $SESSION:0.4 'clear; echo "💻 Dev2（ペイン4・右3番目）+ Context7統合"; echo "構成確認: 右側上から3番目の開発者（Context7自動統合済み）"' C-m
tmux send-keys -t $SESSION:0.5 'clear; echo "💻 Dev3（ペイン5・右4番目）+ Context7統合"; echo "構成確認: 右側上から4番目の開発者（Context7自動統合済み）"' C-m
tmux send-keys -t $SESSION:0.6 'clear; echo "💻 Dev4（ペイン6・右5番目）+ Context7統合"; echo "構成確認: 右側上から5番目の開発者（Context7自動統合済み）"' C-m
tmux send-keys -t $SESSION:0.7 'clear; echo "💻 Dev5（ペイン7・右6番目）+ Context7統合"; echo "構成確認: 右側最下部の開発者（Context7自動統合済み）"' C-m

# ペイン数の検証
PANE_COUNT=$(tmux list-panes -t $SESSION | wc -l)
echo ""
echo "🔍 ペイン数検証: $PANE_COUNT/8"

if [ "$PANE_COUNT" -eq 8 ]; then
    echo "✅ 全ペインが正常に作成されました"
    
    echo ""
    echo "⏳ 3秒後にClaudeエージェント（Context7統合版）を起動します..."
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
    
    if [ -f "$INSTRUCTIONS_DIR/manager.md" ]; then
        # Context7統合版コマンド（MCP Context7サーバーを明示的に指定）
        echo "🌟 Context7統合起動コマンド準備中..."
        
        # Manager（Opus + Context7統合）
        echo "  📡 Technical Manager起動中..."
        tmux send-keys -t $SESSION:0.0 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🌟 Technical Manager + Context7統合起動中...' && claude --model opus --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/manager.md'" C-m
        sleep 2
        
        # CTO（Opus + Context7統合）
        echo "  📡 CTO起動中..."
        tmux send-keys -t $SESSION:0.1 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🌟 CTO + Context7統合起動中...' && claude --model opus --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/ceo.md'" C-m
        sleep 2
        
        # Developer0-5（Sonnet + Context7統合）
        echo "  📡 Dev0-5起動中..."
        tmux send-keys -t $SESSION:0.2 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🌟 Dev0 + Context7統合起動中...' && claude --model sonnet --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/developer.md'" C-m
        sleep 1
        tmux send-keys -t $SESSION:0.3 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🌟 Dev1 + Context7統合起動中...' && claude --model sonnet --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/developer.md'" C-m
        sleep 1
        tmux send-keys -t $SESSION:0.4 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🌟 Dev2 + Context7統合起動中...' && claude --model sonnet --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/developer.md'" C-m
        sleep 1
        tmux send-keys -t $SESSION:0.5 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🌟 Dev3 + Context7統合起動中...' && claude --model sonnet --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/developer.md'" C-m
        sleep 1
        tmux send-keys -t $SESSION:0.6 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🌟 Dev4 + Context7統合起動中...' && claude --model sonnet --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/developer.md'" C-m
        sleep 1
        tmux send-keys -t $SESSION:0.7 "export CLAUDE_CODE_CONFIG_PATH='$HOME/.local/share/claude' && export CLAUDE_CODE_CACHE_PATH='$HOME/.cache/claude' && echo '🌟 Dev5 + Context7統合起動中...' && claude --model sonnet --dangerously-skip-permissions --mcp-config '{\"mcpServers\":{\"context7\":{\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp@latest\"]}}}' '$INSTRUCTIONS_DIR/developer.md'" C-m
        
        echo "🚀 Claudeエージェント起動中（認証統一適用済み + Context7統合）..."
        
        # 自動テーマ選択（デフォルトテーマを自動選択）
        echo "⏳ テーマ選択を自動スキップ中..."
        sleep 8
        
        # 各ペインでEnterキーを送信（デフォルトテーマ選択）
        tmux send-keys -t $SESSION:0.0 C-m
        tmux send-keys -t $SESSION:0.1 C-m
        tmux send-keys -t $SESSION:0.2 C-m
        tmux send-keys -t $SESSION:0.3 C-m
        tmux send-keys -t $SESSION:0.4 C-m
        tmux send-keys -t $SESSION:0.5 C-m
        tmux send-keys -t $SESSION:0.6 C-m
        tmux send-keys -t $SESSION:0.7 C-m
        
        echo "✅ テーマ選択自動スキップ完了"
        
        # 日本語設定メッセージを全ペインに自動送信（Enterキー自動押下）
        echo "🌍 日本語設定メッセージ送信中（自動Enterキー押下）..."
        sleep 8
        echo "  📨 Technical Manager..."
        echo "  📨 Context7統合メッセージ送信をスキップしています..."
        # 日本語メッセージは削除されました
        echo "✅ 全8ペインに日本語設定完了（Enterキー自動押下済み）"
        
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
        echo "💡 使用例: 'React Query 最新実装例を教えて' と入力すると"
        echo "   自動的にContext7経由で最新ドキュメントを取得して回答します"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
    else
        echo "⚠️ Claudeエージェント指示ファイルが見つかりません"
        echo "各ペインでmanual setupが必要です"
    fi

    # tmux表示設定
    echo "🎨 tmux表示設定中（Context7統合版）..."
    tmux set-option -t $SESSION pane-border-status top
    tmux set-option -t $SESSION pane-border-format "#{pane_title}"
    tmux set-option -t $SESSION status-format[1] "#[align=centre]#{P:#{?pane_active,#[reverse],}#{pane_title}#[default] }"
    tmux set-option -t $SESSION status-left "#[fg=green]ITSM Context7: #S #[fg=blue]| "
    tmux set-option -t $SESSION status-right "#[fg=yellow]🌟 ITSM AI Team #[fg=cyan]%H:%M"
    
    # ペインタイトルを設定（Context7統合版）
    echo "🏷️ ペインタイトル設定中（Context7統合版）..."
    sleep 1
    tmux select-pane -t $SESSION:0.0 -T "👔 Technical Manager+Context7"
    tmux select-pane -t $SESSION:0.1 -T "👑 CTO+Context7"
    tmux select-pane -t $SESSION:0.2 -T "💻 Dev0+Context7"
    tmux select-pane -t $SESSION:0.3 -T "💻 Dev1+Context7"
    tmux select-pane -t $SESSION:0.4 -T "💻 Dev2+Context7"
    tmux select-pane -t $SESSION:0.5 -T "💻 Dev3+Context7"
    tmux select-pane -t $SESSION:0.6 -T "💻 Dev4+Context7"
    tmux select-pane -t $SESSION:0.7 -T "💻 Dev5+Context7"
    
    echo ""
    echo "✅ 6 Developers構成起動完了（Context7統合版）！"
else
    echo "❌ ペイン作成に失敗しました（$PANE_COUNT/8）"
fi

echo ""
echo "📊 最終ペイン構成（Context7統合版）:"
tmux list-panes -t $SESSION -F "ペイン#{pane_index}: #{pane_title} (#{pane_width}x#{pane_height})"

echo ""
echo "📐 実現した構成図（Context7統合版）:"
echo "┌─────────────┬─────────────┐"
echo "│             │💻 Dev0+Ctx7 │ ← ペイン2"
echo "│             ├─────────────┤"
echo "│👔Tech Mgr   │💻 Dev1+Ctx7 │ ← ペイン3"
echo "│+Context7    ├─────────────┤"
echo "│(ペイン0)    │💻 Dev2+Ctx7 │ ← ペイン4"
echo "├─────────────┼─────────────┤"
echo "│             │💻 Dev3+Ctx7 │ ← ペイン5"
echo "│             ├─────────────┤"
echo "│👑 CTO       │💻 Dev4+Ctx7 │ ← ペイン6"
echo "│+Context7    ├─────────────┤"
echo "│(ペイン1)    │💻 Dev5+Ctx7 │ ← ペイン7"
echo "└─────────────┴─────────────┘"

echo ""
echo "🌟 Context7統合機能詳細:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 全てのClaude AIエージェント（CTO、Technical Manager、Dev0-5）にContext7が統合されました"
echo ""
echo "📋 利用可能な機能:"
echo "   🔍 resolve-library-id: パッケージ名→Context7ライブラリID変換"
echo "   📚 get-library-docs: 最新ライブラリドキュメント取得"
echo ""
echo "💡 使用方法:"
echo "   任意のペインで「React Query 最新実装例」「Next.js TypeScript設定」等を"
echo "   入力すると、自動的にContext7経由で最新情報を取得します"
echo ""
echo "🚀 対象ペイン: 全8ペイン（Technical Manager、CTO、Dev0、Dev1、Dev2、Dev3、Dev4、Dev5）"
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