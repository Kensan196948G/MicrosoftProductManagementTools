#!/bin/bash
# Python移行プロジェクト用 tmux統合ランチャー
# セッション作成から安全な接続まで一括実行
# Version: 1.0
# Date: 2025-01-18

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# セッション名
SESSION_NAME="MicrosoftProductTools-Python"

# プロジェクトディレクトリ
PROJECT_DIR="/mnt/e/MicrosoftProductManagementTools"

echo -e "${BLUE}=== Python移行プロジェクト tmux統合ランチャー ===${NC}"
echo ""

# 既存セッション確認
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
    echo -e "${YELLOW}既存セッション '$SESSION_NAME' が見つかりました${NC}"
    echo ""
    echo "選択してください:"
    echo "  1) 既存セッションを削除して新規作成"
    echo "  2) 既存セッションに接続"
    echo "  3) キャンセル"
    echo ""
    read -p "選択 (1-3): " choice
    
    case $choice in
        1)
            echo -e "${YELLOW}既存セッションを削除中...${NC}"
            tmux kill-session -t $SESSION_NAME
            sleep 2
            ;;
        2)
            echo -e "${GREEN}既存セッションに安全接続中...${NC}"
            
            # 接続前にペインタイトルを確保
            tmux set-window-option -t $SESSION_NAME:0 automatic-rename off 2>/dev/null
            tmux set-window-option -t $SESSION_NAME:0 allow-rename off 2>/dev/null
            tmux set-window-option -t $SESSION_NAME:0 pane-border-status top 2>/dev/null
            tmux set-window-option -t $SESSION_NAME:0 pane-border-format "#[fg=cyan,bold]#{pane_title}#[default]" 2>/dev/null
            
            # ペインタイトルを設定
            tmux select-pane -t $SESSION_NAME:0.0 -T "👔 Manager: Coordination & Progress" 2>/dev/null
            tmux select-pane -t $SESSION_NAME:0.1 -T "👑 CTO: Strategy & Decision" 2>/dev/null
            tmux select-pane -t $SESSION_NAME:0.2 -T "🐍 Dev0: Python GUI & API Development" 2>/dev/null
            tmux select-pane -t $SESSION_NAME:0.3 -T "🧪 Dev1: Testing & Quality Assurance" 2>/dev/null
            tmux select-pane -t $SESSION_NAME:0.4 -T "🔄 Dev2: PowerShell Compatibility & Infrastructure" 2>/dev/null
            
            exec tmux attach-session -t $SESSION_NAME
            ;;
        3)
            echo "キャンセルしました"
            exit 0
            ;;
        *)
            echo -e "${RED}無効な選択です${NC}"
            exit 1
            ;;
    esac
fi

echo -e "${CYAN}Phase 1: セッション作成とセットアップ開始...${NC}"
echo ""

# tmuxインストール確認
if ! command -v tmux &> /dev/null; then
    echo -e "${RED}tmuxがインストールされていません。インストールしてください。${NC}"
    echo "sudo apt-get install tmux"
    exit 1
fi

# 新規セッション作成 
echo -e "${GREEN}tmuxセッション作成中 (Python移行プロジェクト用)...${NC}"
tmux new-session -d -s $SESSION_NAME -n "PythonMigration" -c $PROJECT_DIR

# 5ペイン分割（仕様書準拠）
echo -e "${CYAN}5ペイン構成を作成中...${NC}"

# step 1: 水平分割（左右）
tmux split-window -h -t $SESSION_NAME:0

# step 2: 左側を垂直分割（Manager/CTO）
tmux split-window -v -t $SESSION_NAME:0.0

# step 3: 右側を垂直分割（Dev0/Dev1）
tmux split-window -v -t $SESSION_NAME:0.2

# step 4: 右下をさらに分割（Dev1/Dev2）
tmux split-window -v -t $SESSION_NAME:0.3

echo "✅ ペイン構成完了"

# 各ペインで初期設定とClaude起動
echo -e "${CYAN}各ペインでClaude起動中...${NC}"

# Pane 0: Manager (左上)
tmux select-pane -t $SESSION_NAME:0.0 -T "👔 Manager: Coordination & Progress"
tmux send-keys -t $SESSION_NAME:0.0 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.0 "cd $PROJECT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.0 "echo '👔 Manager: Coordination & Progress'" C-m
tmux send-keys -t $SESSION_NAME:0.0 "echo '======================================='" C-m
tmux send-keys -t $SESSION_NAME:0.0 "claude --dangerously-skip-permissions" C-m

# Pane 1: CTO (左中)
tmux select-pane -t $SESSION_NAME:0.1 -T "👑 CTO: Strategy & Decision"
tmux send-keys -t $SESSION_NAME:0.1 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.1 "cd $PROJECT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.1 "echo '👑 CTO: Strategy & Decision'" C-m
tmux send-keys -t $SESSION_NAME:0.1 "echo '======================================='" C-m
tmux send-keys -t $SESSION_NAME:0.1 "claude --dangerously-skip-permissions" C-m

# Pane 2: Developer dev0 (右上)
tmux select-pane -t $SESSION_NAME:0.2 -T "🐍 Dev0: Python GUI & API Development"
tmux send-keys -t $SESSION_NAME:0.2 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.2 "cd $PROJECT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.2 "echo '🐍 Dev0: Python GUI & API Development'" C-m
tmux send-keys -t $SESSION_NAME:0.2 "echo '======================================='" C-m
tmux send-keys -t $SESSION_NAME:0.2 "claude --dangerously-skip-permissions" C-m

# Pane 3: Developer dev1 (右中)
tmux select-pane -t $SESSION_NAME:0.3 -T "🧪 Dev1: Testing & Quality Assurance"
tmux send-keys -t $SESSION_NAME:0.3 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.3 "cd $PROJECT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.3 "echo '🧪 Dev1: Testing & Quality Assurance'" C-m
tmux send-keys -t $SESSION_NAME:0.3 "echo '======================================='" C-m
tmux send-keys -t $SESSION_NAME:0.3 "claude --dangerously-skip-permissions" C-m

# Pane 4: Developer dev2 (右下)
tmux select-pane -t $SESSION_NAME:0.4 -T "🔄 Dev2: PowerShell Compatibility & Infrastructure"
tmux send-keys -t $SESSION_NAME:0.4 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.4 "cd $PROJECT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.4 "echo '🔄 Dev2: PowerShell Compatibility & Infrastructure'" C-m
tmux send-keys -t $SESSION_NAME:0.4 "echo '======================================='" C-m
tmux send-keys -t $SESSION_NAME:0.4 "claude --dangerously-skip-permissions" C-m

# Claudeが起動するまで待機
echo -e "${YELLOW}Claude起動待機中...${NC}"
CLAUDE_STARTUP_WAIT=${CLAUDE_STARTUP_WAIT:-15}
echo "待機時間: ${CLAUDE_STARTUP_WAIT}秒"

# プログレスバー風表示
for i in $(seq 1 $CLAUDE_STARTUP_WAIT); do
    printf "\rClaude起動中... [%3d%%] " $((i * 100 / CLAUDE_STARTUP_WAIT))
    for j in $(seq 1 $((i * 30 / CLAUDE_STARTUP_WAIT))); do
        printf "█"
    done
    sleep 1
done
echo ""

# Python移行プロジェクト用の日本語プロンプトを送信
echo -e "${CYAN}Python移行プロジェクト用プロンプトを送信中...${NC}"

# Manager (Pane 0)
tmux send-keys -t $SESSION_NAME:0.0 "日本語で解説・対応してください。Project Manager として PowerShell版からPython版への移行プロジェクトを管理します。26機能の仕様分析とタスク調整を行います"
sleep 2
tmux send-keys -t $SESSION_NAME:0.0 C-m

# CTO (Pane 1)
sleep 1
tmux send-keys -t $SESSION_NAME:0.1 "日本語で解説・対応してください。CTO として Python移行の技術戦略を決定します。既存資産を保護しつつ段階的移行を実現します"
sleep 2
tmux send-keys -t $SESSION_NAME:0.1 C-m

# Dev0 (Pane 2)
sleep 1
tmux send-keys -t $SESSION_NAME:0.2 "日本語で解説・対応してください。Dev0 - Python GUI/API Developer として PyQt6による26機能のGUI実装とMicrosoft Graph API統合を担当します"
sleep 2
tmux send-keys -t $SESSION_NAME:0.2 C-m

# Dev1 (Pane 3)
sleep 1
tmux send-keys -t $SESSION_NAME:0.3 "日本語で解説・対応してください。Dev1 - Test/QA Developer として pytest基盤構築とPowerShell版との互換性テストを実装します"
sleep 2
tmux send-keys -t $SESSION_NAME:0.3 C-m

# Dev2 (Pane 4)
sleep 1
tmux send-keys -t $SESSION_NAME:0.4 "日本語で解説・対応してください。Dev2 - PowerShell Compatibility Developer として 既存仕様の分析と移行ツール開発を担当します"
sleep 2
tmux send-keys -t $SESSION_NAME:0.4 C-m

# Manager (Pane 0) にフォーカス
tmux select-pane -t $SESSION_NAME:0.0

echo "✅ プロンプト送信完了"
echo ""

echo -e "${CYAN}Phase 2: ペインタイトル保護システム起動...${NC}"

# tmux設定でペインタイトルの自動更新を無効化
tmux set-window-option -t $SESSION_NAME:0 automatic-rename off
tmux set-window-option -t $SESSION_NAME:0 allow-rename off
tmux set-window-option -t $SESSION_NAME:0 pane-border-status top
tmux set-window-option -t $SESSION_NAME:0 pane-border-format "#[fg=cyan,bold]#{pane_title}#[default]"

# 最終ペインタイトル設定
echo -e "${YELLOW}最終ペインタイトル設定中...${NC}"
for i in {1..3}; do
    tmux select-pane -t $SESSION_NAME:0.0 -T "👔 Manager: Coordination & Progress"
    tmux select-pane -t $SESSION_NAME:0.1 -T "👑 CTO: Strategy & Decision"
    tmux select-pane -t $SESSION_NAME:0.2 -T "🐍 Dev0: Python GUI & API Development"
    tmux select-pane -t $SESSION_NAME:0.3 -T "🧪 Dev1: Testing & Quality Assurance"
    tmux select-pane -t $SESSION_NAME:0.4 -T "🔄 Dev2: PowerShell Compatibility & Infrastructure"
    sleep 1
done

# 強化監視システム開始
echo -e "${CYAN}強化監視システム開始...${NC}"
nohup bash -c "
while tmux has-session -t $SESSION_NAME 2>/dev/null; do
    sleep 3
    tmux set-window-option -t $SESSION_NAME:0 automatic-rename off 2>/dev/null
    tmux set-window-option -t $SESSION_NAME:0 allow-rename off 2>/dev/null
    tmux set-window-option -t $SESSION_NAME:0 pane-border-status top 2>/dev/null
    tmux select-pane -t $SESSION_NAME:0.0 -T '👔 Manager: Coordination & Progress' 2>/dev/null
    tmux select-pane -t $SESSION_NAME:0.1 -T '👑 CTO: Strategy & Decision' 2>/dev/null
    tmux select-pane -t $SESSION_NAME:0.2 -T '🐍 Dev0: Python GUI & API Development' 2>/dev/null
    tmux select-pane -t $SESSION_NAME:0.3 -T '🧪 Dev1: Testing & Quality Assurance' 2>/dev/null
    tmux select-pane -t $SESSION_NAME:0.4 -T '🔄 Dev2: PowerShell Compatibility & Infrastructure' 2>/dev/null
done
" > /tmp/pane_title_monitor.log 2>&1 &

MONITOR_PID=$!
echo "監視プロセス開始: PID $MONITOR_PID"

echo ""
echo -e "${GREEN}✅ セットアップ完了！${NC}"
echo ""

echo -e "${CYAN}Phase 3: 安全な接続準備中...${NC}"
echo -e "${YELLOW}追加待機（Claude完全起動確保）: 5秒...${NC}"
sleep 5

echo -e "${GREEN}🚀 セッションに安全接続中...${NC}"
echo ""
echo -e "${CYAN}=== 5ペイン構成（絵文字付き役職：役割表示） ===${NC}"
echo "┌─────────────────────────────────┬─────────────────────────────────┐"
echo "│  👔 Manager: Coordination       │  🐍 Dev0: Python GUI &         │"
echo "│     & Progress                  │     API Development             │"
echo "├─────────────────────────────────┼─────────────────────────────────┤"
echo "│  👑 CTO: Strategy &             │  🧪 Dev1: Testing &            │"
echo "│     Decision                    │     Quality Assurance           │"
echo "│                                 ├─────────────────────────────────┤"
echo "│                                 │  🔄 Dev2: PowerShell           │"
echo "│                                 │     Compatibility &             │"
echo "│                                 │     Infrastructure              │"
echo "└─────────────────────────────────┴─────────────────────────────────┘"
echo ""

# セッションに安全接続
exec tmux attach-session -t $SESSION_NAME