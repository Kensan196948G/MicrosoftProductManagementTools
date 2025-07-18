#!/bin/bash
# 緊急ペインタイトル修正スクリプト
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

echo -e "${CYAN}=== 緊急ペインタイトル修正システム ===${NC}"
echo ""

# セッション存在確認
if ! tmux has-session -t $SESSION_NAME 2>/dev/null; then
    echo -e "${RED}エラー: セッション '$SESSION_NAME' が見つかりません${NC}"
    echo "先に tmux_python_setup.sh を実行してください"
    exit 1
fi

echo -e "${YELLOW}現在のペインタイトル:${NC}"
tmux list-panes -t $SESSION_NAME:0 -F "  Pane #{pane_index}: #{pane_title}"
echo ""

# tmux自動リネーム機能を強制無効化
echo -e "${CYAN}Step 1: tmux自動リネーム機能を無効化...${NC}"
tmux set-window-option -t $SESSION_NAME:0 automatic-rename off
tmux set-window-option -t $SESSION_NAME:0 allow-rename off
echo "✅ 完了"

# ペインタイトルを強制設定（5回反復で確実に）
echo -e "${CYAN}Step 2: ペインタイトルを強制設定中...${NC}"
for i in {1..5}; do
    echo -e "${YELLOW}  設定試行 $i/5...${NC}"
    
    tmux select-pane -t $SESSION_NAME:0.0 -T "👔 Manager: Coordination & Progress"
    tmux select-pane -t $SESSION_NAME:0.1 -T "👑 CTO: Strategy & Decision"
    tmux select-pane -t $SESSION_NAME:0.2 -T "🐍 Dev0: Python GUI & API Development"
    tmux select-pane -t $SESSION_NAME:0.3 -T "🧪 Dev1: Testing & Quality Assurance"
    tmux select-pane -t $SESSION_NAME:0.4 -T "🔄 Dev2: PowerShell Compatibility & Infrastructure"
    
    sleep 1
done
echo "✅ 完了"

# 設定確認
echo -e "${CYAN}Step 3: 設定結果確認...${NC}"
sleep 2
echo -e "${YELLOW}修正後のペインタイトル:${NC}"
tmux list-panes -t $SESSION_NAME:0 -F "  Pane #{pane_index}: #{pane_title}"
echo ""

# 継続監視システム開始
echo -e "${CYAN}Step 4: 継続監視システム開始...${NC}"

# 既存の監視プロセスを停止
pkill -f "tmux.*pane.*title.*monitor" 2>/dev/null

# 新しい監視プロセスを開始
nohup bash -c "
while tmux has-session -t $SESSION_NAME 2>/dev/null; do
    sleep 5
    # tmux設定を維持
    tmux set-window-option -t $SESSION_NAME:0 automatic-rename off 2>/dev/null
    tmux set-window-option -t $SESSION_NAME:0 allow-rename off 2>/dev/null
    
    # ペインタイトルを維持
    tmux select-pane -t $SESSION_NAME:0.0 -T '👔 Manager: Coordination & Progress' 2>/dev/null
    tmux select-pane -t $SESSION_NAME:0.1 -T '👑 CTO: Strategy & Decision' 2>/dev/null
    tmux select-pane -t $SESSION_NAME:0.2 -T '🐍 Dev0: Python GUI & API Development' 2>/dev/null
    tmux select-pane -t $SESSION_NAME:0.3 -T '🧪 Dev1: Testing & Quality Assurance' 2>/dev/null
    tmux select-pane -t $SESSION_NAME:0.4 -T '🔄 Dev2: PowerShell Compatibility & Infrastructure' 2>/dev/null
done
" > /tmp/pane_title_monitor.log 2>&1 &

MONITOR_PID=$!
echo "監視プロセス開始: PID $MONITOR_PID"
echo "ログファイル: /tmp/pane_title_monitor.log"
echo ""

echo -e "${GREEN}✅ ペインタイトル修正完了！${NC}"
echo ""
echo -e "${YELLOW}📋 確認方法:${NC}"
echo "  tmux list-panes -t $SESSION_NAME:0 -F \"Pane #{pane_index}: #{pane_title}\""
echo ""
echo -e "${YELLOW}🔄 問題が再発した場合:${NC}"
echo "  ./tmux/fix_pane_titles.sh を再実行してください"
echo ""
echo -e "${YELLOW}🛑 監視停止方法:${NC}"
echo "  pkill -f \"tmux.*pane.*title.*monitor\""