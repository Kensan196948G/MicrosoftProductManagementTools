#!/bin/bash
# 最適化されたtmux 6ペイン並列開発環境セットアップ（setup_6team_context7_fixed準拠）
# ClaudeCode統合・Context7対応・PowerShell専門化

# スクリプトのベースディレクトリ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR"
INSTRUCTIONS_DIR="$BASE_DIR/tmux/instructions"
SESSION_NAME="MicrosoftProductTools-6team-Context7"

# 既存セッション確認・削除
tmux kill-session -t $SESSION_NAME 2>/dev/null

echo "🔧 6ペイン並列開発環境作成（Manager + CTO + Dev4名）Context7統合版"
echo "=================================================================="
echo "仕様: 左側Manager/CTO固定、右側4Dev均等分割 + PowerShell 7専門化(Dev04) + Context7統合"

echo "ステップ1: 新しいセッションを作成"
tmux new-session -d -s $SESSION_NAME -c "$(pwd)"

echo "ステップ2: まず左右に分割（縦線）"
# 左右分割 - これで0（左）、1（右）になる
tmux split-window -h -t $SESSION_NAME:0.0

echo "ステップ3: 左側を上下に分割（横線）"
# 左側（ペイン0）を上下分割 - 0（上）、1（下）になり、元の1は2になる
tmux split-window -v -t $SESSION_NAME:0.0

echo "ステップ4: 右側を3回分割して4つのペインにする"
# 右側（現在のペイン2）を上下分割
tmux split-window -v -t $SESSION_NAME:0.2
# 右上（ペイン2）をさらに上下分割
tmux split-window -v -t $SESSION_NAME:0.2
# 右下（ペイン4）をさらに上下分割
tmux split-window -v -t $SESSION_NAME:0.4

echo "ステップ5: サイズ調整（ClaudeCode + PowerShell最適化）"
# 左右のバランス調整（左30%、右70%でプロンプト確実に1行化）
tmux resize-pane -t $SESSION_NAME:0.0 -x 30%

# PowerShell 7 + ClaudeCode表示最適化設定
tmux set-environment -t $SESSION_NAME COLUMNS 120
tmux set-environment -t $SESSION_NAME LINES 10
tmux set-environment -t $SESSION_NAME TERM xterm-256color
tmux set-environment -t $SESSION_NAME CLAUDE_FORCE_TTY 1
tmux set-environment -t $SESSION_NAME CLAUDE_PROMPT_WIDTH 120
tmux set-environment -t $SESSION_NAME POWERSHELL_VERSION 7

# ClaudeCode認証統一設定＋Context7統合を各ペインに適用
echo "🔧 ClaudeCode認証統一設定＋Context7自動統合を全ペインに適用中..."

# tmux環境変数設定（全ペインで認証統一＋Context7統合）
tmux set-environment -g CLAUDE_CODE_CONFIG_PATH "$HOME/.local/share/claude"
tmux set-environment -g CLAUDE_CODE_CACHE_PATH "$HOME/.cache/claude" 
tmux set-environment -g CLAUDE_CODE_AUTO_START "true"
tmux set-environment -g CLAUDE_CONTEXT7_ENABLED "true"
tmux set-environment -g MICROSOFT_TOOLS_PROJECT_ROOT "$BASE_DIR"

# 各ペインにタイトルと確認メッセージを設定
tmux send-keys -t $SESSION_NAME:0.0 'clear; echo "👔 Manager（ペイン0・左上）+ Context7統合"; echo "構成確認: 左上のManager（チーム管理）ペイン（Context7自動統合準備中）"' C-m
tmux send-keys -t $SESSION_NAME:0.1 'clear; echo "💼 CTO（ペイン1・左下）+ Context7統合"; echo "構成確認: 左下のCTO（戦略統括）ペイン（Context7自動統合準備中）"' C-m
tmux send-keys -t $SESSION_NAME:0.2 'clear; echo "💻 Dev01（ペイン2・右1番目）+ Context7統合"; echo "構成確認: 右側最上部の開発者（Context7自動統合準備中）"' C-m
tmux send-keys -t $SESSION_NAME:0.3 'clear; echo "💻 Dev02（ペイン3・右2番目）+ Context7統合"; echo "構成確認: 右側上から2番目の開発者（Context7自動統合準備中）"' C-m
tmux send-keys -t $SESSION_NAME:0.4 'clear; echo "💻 Dev03（ペイン4・右3番目）+ Context7統合"; echo "構成確認: 右側上から3番目の開発者（Context7自動統合準備中）"' C-m
tmux send-keys -t $SESSION_NAME:0.5 'clear; echo "🔧 Dev04（ペイン5・右4番目）PowerShell7専門 + Context7統合"; echo "構成確認: PowerShell 7自動化・Microsoft 365専門ペイン（Context7自動統合準備中）"' C-m

# 指示ファイルの存在確認とClaudeCode起動
echo "⏳ 3秒後にClaudeCode（6ペイン Context7統合版）を起動します..."
sleep 3

# 指示ファイル確認
echo "📂 指示ファイルディレクトリ: $INSTRUCTIONS_DIR"
mkdir -p "$INSTRUCTIONS_DIR"

# 必要なファイルの存在確認と作成
files_ok=true

# manager.md作成
if [[ ! -f "$INSTRUCTIONS_DIR/manager.md" ]]; then
    echo "📝 manager.md作成中..."
    cat > "$INSTRUCTIONS_DIR/manager.md" << 'EOF'
# Manager役指示書

あなたはMicrosoft365管理ツール開発プロジェクトのManagerです。

## 役割
- プロジェクト進捗管理
- チーム間調整
- 優先度決定
- リソース配分

## Context7活用
最新のプロジェクト管理手法やチーム運営ベストプラクティスを積極的に活用してください。

## 今日のタスク
- conftest.py競合解消の進捗確認
- pytest環境修復状況監視
- CI/CD復旧計画調整
EOF
    files_ok=true
fi

# cto.md作成
if [[ ! -f "$INSTRUCTIONS_DIR/cto.md" ]]; then
    echo "📝 cto.md作成中..."
    cat > "$INSTRUCTIONS_DIR/cto.md" << 'EOF'
# CTO役指示書

あなたはMicrosoft365管理ツール開発プロジェクトのCTOです。

## 役割
- 技術戦略決定
- アーキテクチャ設計
- 技術的判断
- PowerShell→Python移行戦略

## Context7活用
最新のPowerShell、Python、Microsoft365 API技術情報を積極的に活用してください。

## 今日のタスク
- PowerShell GUI + PyQt6統合戦略
- Microsoft Graph API最適化
- 技術的な意思決定
EOF
    files_ok=true
fi

# developer.md作成
if [[ ! -f "$INSTRUCTIONS_DIR/developer.md" ]]; then
    echo "📝 developer.md作成中..."
    cat > "$INSTRUCTIONS_DIR/developer.md" << 'EOF'
# Developer役指示書

あなたはMicrosoft365管理ツール開発プロジェクトの開発者です。

## 役割
- 機能実装
- バグ修正
- テスト実行
- コードレビュー

## Context7活用
最新のPython、PyQt6、Microsoft Graph SDK情報を積極的に活用してください。

## 今日のタスク
- PyQt6 GUI実装
- API統合作業
- 品質保証
EOF
    files_ok=true
fi

# powershell-specialist.md作成
if [[ ! -f "$INSTRUCTIONS_DIR/powershell-specialist.md" ]]; then
    echo "📝 powershell-specialist.md作成中..."
    cat > "$INSTRUCTIONS_DIR/powershell-specialist.md" << 'EOF'
# PowerShell専門家役指示書

あなたはMicrosoft365管理ツール開発プロジェクトのPowerShell専門家です。

## 役割
- PowerShell 7最適化
- Microsoft 365自動化
- Exchange Online統合
- スクリプト自動化

## Context7活用
最新のPowerShell 7、Microsoft Graph PowerShell、Exchange Online管理情報を積極的に活用してください。

## 今日のタスク
- PowerShell GUI安定化
- Microsoft 365認証最適化
- 自動化スクリプト改善
EOF
    files_ok=true
fi

if [[ "$files_ok" == true ]]; then
    echo "✅ 全ての指示ファイルが確認されました"
    
    echo "🌟 ClaudeCode起動コマンド準備中..."
    
    # 正しいペイン配置でClaudeCode起動（permissions skip版）
    echo "  📡 Manager起動中(ペイン0・左上)..."
    tmux send-keys -t $SESSION_NAME:0.0 C-c
    sleep 0.5
    tmux send-keys -t $SESSION_NAME:0.0 "claude --dangerously-skip-permissions '$INSTRUCTIONS_DIR/manager.md'" C-m
    sleep 3
    
    echo "  📡 CTO起動中(ペイン1・左下)..."
    tmux send-keys -t $SESSION_NAME:0.1 C-c
    sleep 0.5
    tmux send-keys -t $SESSION_NAME:0.1 "claude --dangerously-skip-permissions '$INSTRUCTIONS_DIR/cto.md'" C-m
    sleep 3
    
    echo "  📡 Dev01-03起動中..."
    tmux send-keys -t $SESSION_NAME:0.2 C-c
    sleep 0.5
    tmux send-keys -t $SESSION_NAME:0.2 "claude --dangerously-skip-permissions '$INSTRUCTIONS_DIR/developer.md'" C-m
    sleep 2
    
    tmux send-keys -t $SESSION_NAME:0.3 C-c
    sleep 0.5
    tmux send-keys -t $SESSION_NAME:0.3 "claude --dangerously-skip-permissions '$INSTRUCTIONS_DIR/developer.md'" C-m
    sleep 2
    
    tmux send-keys -t $SESSION_NAME:0.4 C-c
    sleep 0.5
    tmux send-keys -t $SESSION_NAME:0.4 "claude --dangerously-skip-permissions '$INSTRUCTIONS_DIR/developer.md'" C-m
    sleep 2
    
    echo "  🔧 Dev04（PowerShell 7専門）起動中..."
    tmux send-keys -t $SESSION_NAME:0.5 C-c
    sleep 0.5
    tmux send-keys -t $SESSION_NAME:0.5 "claude --dangerously-skip-permissions '$INSTRUCTIONS_DIR/powershell-specialist.md'" C-m
    sleep 2
    
    echo "✅ ClaudeCode起動プロセス完了"
fi

# 共有コンテキストファイル初期化
SHARED_CONTEXT="$BASE_DIR/tmux_shared_context.md"
echo "# 6ペイン並列開発環境 - Context7統合共有コンテキスト
## 📅 $(date '+%Y-%m-%d %H:%M:%S') - セッション開始

### 🎯 本日の目標
- [ ] conftest.py競合解消
- [ ] pytest環境修復  
- [ ] CI/CD状況確認
- [ ] PowerShell GUI安定化
- [ ] PyQt6基盤構築

### 👥 役割分担（6ペイン構成）
- 👔 Manager (ペイン0): 進捗監視・優先度調整・チーム調整
- 💼 CTO (ペイン1): 技術判断・アーキテクチャ・戦略決定
- 💻 Dev01 (ペイン2): PyQt6実装・Frontend開発
- 💻 Dev02 (ペイン3): Backend開発・API統合
- 💻 Dev03 (ペイン4): テスト・品質保証
- 🔧 Dev04 (ペイン5): PowerShell専門・Microsoft365自動化

### 📝 通信ログ
" > "$SHARED_CONTEXT"

# 自動同期機能設定（12秒間隔）
tmux send-keys -t $SESSION_NAME:0.5 'watch -n 12 "echo \"🔄 $(date) - 自動同期実行\" >> tmux_shared_context.md"' C-m

# tmux表示設定
echo "🎨 tmux表示設定中（6ペイン Context7統合版）..."
tmux set-option -t $SESSION_NAME pane-border-status top
tmux set-option -t $SESSION_NAME pane-border-format "#{pane_title}"
tmux set-option -t $SESSION_NAME status-left "#[fg=green]MS365-6Team: #S #[fg=blue]| "
tmux set-option -t $SESSION_NAME status-right "#[fg=yellow]🌟 Mgr+CTO+Dev4 #[fg=cyan]%H:%M"

# ペインタイトルを設定（6ペイン Context7統合版）
echo "🏷️ ペインタイトル設定中（6ペイン Context7統合版）..."
sleep 1
tmux select-pane -t $SESSION_NAME:0.0 -T "👔 Manager: 進捗管理・調整"
tmux select-pane -t $SESSION_NAME:0.1 -T "💼 CTO: 技術戦略・判断"
tmux select-pane -t $SESSION_NAME:0.2 -T "💻 Dev01: Frontend・PyQt6"
tmux select-pane -t $SESSION_NAME:0.3 -T "💻 Dev02: Backend・API"
tmux select-pane -t $SESSION_NAME:0.4 -T "💻 Dev03: QA・テスト"
tmux select-pane -t $SESSION_NAME:0.5 -T "🔧 Dev04: PowerShell専門"

echo "✅ 6ペイン並列開発環境（Manager + CTO + Dev4名）Context7統合版起動完了！"
echo "🔗 セッション接続: tmux attach-session -t $SESSION_NAME"
echo "📋 共有コンテキスト: tmux_shared_context.md"
echo "🔧 自動同期: 12秒間隔で進捗更新"
echo ""
echo "📱 各ペイン移動:"
echo "  Ctrl+b 0: Manager"
echo "  Ctrl+b 1: CTO" 
echo "  Ctrl+b 2: Dev01 (Frontend)"
echo "  Ctrl+b 3: Dev02 (Backend)"
echo "  Ctrl+b 4: Dev03 (QA)"
echo "  Ctrl+b 5: Dev04 (PowerShell)"
echo ""
echo "📐 実現した構成図（6ペイン Context7統合版）:"
echo "┌─────────────┬─────────────┐"
echo "│👔 Manager   │💻 Dev01     │ ← ペイン2"
echo "│進捗管理     ├─────────────┤"
echo "│(ペイン0)    │💻 Dev02     │ ← ペイン3"
echo "├─────────────┼─────────────┤"
echo "│💼 CTO       │💻 Dev03     │ ← ペイン4"
echo "│技術戦略     ├─────────────┤"
echo "│(ペイン1)    │🔧 Dev04     │ ← ペイン5"
echo "│             │PowerShell専門│"
echo "└─────────────┴─────────────┘"

# セッション接続
tmux attach-session -t $SESSION_NAME