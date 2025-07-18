#!/bin/bash
# tmuxペインタイトル表示を強制有効化するスクリプト
# Version: 1.0
# Date: 2025-01-18

SESSION_NAME="MicrosoftProductTools-Python"

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== tmuxペインタイトル表示強制有効化システム ===${NC}"
echo ""

# セッション存在確認
if ! tmux has-session -t $SESSION_NAME 2>/dev/null; then
    echo -e "${RED}エラー: セッション '$SESSION_NAME' が見つかりません${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: 現在のペインボーダー設定確認...${NC}"
tmux show-window-options -t $SESSION_NAME:0 2>/dev/null | grep -E "(pane-border|status)" || echo "設定なし"
echo ""

echo -e "${YELLOW}Step 2: ペインタイトル表示を強制有効化...${NC}"

# ペインボーダーでタイトルを表示
tmux set-window-option -t $SESSION_NAME:0 pane-border-status top
tmux set-window-option -t $SESSION_NAME:0 pane-border-format "#[fg=cyan,bold]#{pane_title}#[default]"

# さらに強力な設定
tmux set-window-option -t $SESSION_NAME:0 pane-border-lines heavy
tmux set-window-option -t $SESSION_NAME:0 pane-active-border-style fg=yellow,bold

echo "✅ ペインボーダー表示設定完了"

echo -e "${YELLOW}Step 3: ペインタイトルを再設定...${NC}"

# タイトルを再設定
tmux select-pane -t $SESSION_NAME:0.0 -T "👔 Manager: Coordination & Progress"
tmux select-pane -t $SESSION_NAME:0.1 -T "👑 CTO: Strategy & Decision"
tmux select-pane -t $SESSION_NAME:0.2 -T "🐍 Dev0: Python GUI & API Development"
tmux select-pane -t $SESSION_NAME:0.3 -T "🧪 Dev1: Testing & Quality Assurance"
tmux select-pane -t $SESSION_NAME:0.4 -T "🔄 Dev2: PowerShell Compatibility & Infrastructure"

echo "✅ ペインタイトル再設定完了"

echo -e "${YELLOW}Step 4: 自動リネーム無効化...${NC}"
tmux set-window-option -t $SESSION_NAME:0 automatic-rename off
tmux set-window-option -t $SESSION_NAME:0 allow-rename off
echo "✅ 自動リネーム無効化完了"

echo -e "${YELLOW}Step 5: 設定確認...${NC}"
echo ""
echo -e "${CYAN}現在のペインタイトル:${NC}"
tmux list-panes -t $SESSION_NAME:0 -F "  Pane #{pane_index}: #{pane_title}"
echo ""

echo -e "${CYAN}ペインボーダー設定:${NC}"
tmux show-window-options -t $SESSION_NAME:0 | grep -E "(pane-border|status)" | sed 's/^/  /'
echo ""

echo -e "${GREEN}✅ ペインタイトル表示強制有効化完了！${NC}"
echo ""
echo -e "${YELLOW}📋 確認方法:${NC}"
echo "  tmux attach-session -t $SESSION_NAME"
echo "  → ペイン境界線の上部にタイトルが表示されるはずです"
echo ""
echo -e "${YELLOW}🔧 追加設定オプション:${NC}"
echo "  ペインボーダー位置: tmux set-window-option -t $SESSION_NAME:0 pane-border-status top|bottom|off"
echo "  ボーダー色: tmux set-window-option -t $SESSION_NAME:0 pane-active-border-style fg=color"
echo ""
echo -e "${YELLOW}💡 ヒント:${NC}"
echo "  もしタイトルが表示されない場合は、tmuxのバージョンを確認してください:"
echo "  tmux -V"