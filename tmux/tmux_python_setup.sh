#!/bin/bash
# Python移行プロジェクト用 tmux並列開発環境セットアップスクリプト (5ペイン構成)
# Version: 1.0
# Date: 2025-01-18

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# セッション名
SESSION_NAME="MicrosoftProductTools-Python"

# プロジェクトディレクトリ
PROJECT_DIR="/mnt/e/MicrosoftProductManagementTools"

echo -e "${BLUE}=== Python移行プロジェクト tmux環境セットアップ (5ペイン構成) ===${NC}"

# tmuxインストール確認
if ! command -v tmux &> /dev/null; then
    echo -e "${RED}tmuxがインストールされていません。インストールしてください。${NC}"
    echo "sudo apt-get install tmux"
    exit 1
fi

# 既存セッション確認・削除
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
    echo -e "${YELLOW}既存セッションを削除します...${NC}"
    tmux kill-session -t $SESSION_NAME
    sleep 1
fi

# 新規セッション作成 
echo -e "${GREEN}tmuxセッション作成中 (Python移行プロジェクト用)...${NC}"
tmux new-session -d -s $SESSION_NAME -n "PythonMigration" -c $PROJECT_DIR

# 5ペイン分割（仕様書準拠）
echo -e "${CYAN}5ペイン構成を作成中...${NC}"

# step 1: 水平分割（左右）
echo "Step 1: 水平分割"
tmux split-window -h -t $SESSION_NAME:0

# step 2: 左側を垂直分割（Manager/CTO）
echo "Step 2: 左側垂直分割"
tmux split-window -v -t $SESSION_NAME:0.0

# step 3: 右側を垂直分割（Dev0/Dev1）
echo "Step 3: 右側第1分割"
tmux split-window -v -t $SESSION_NAME:0.2

# step 4: 右下をさらに分割（Dev1/Dev2）
echo "Step 4: 右側第2分割"
tmux split-window -v -t $SESSION_NAME:0.3

# ペイン確認
echo "ペイン構成確認:"
tmux list-panes -t $SESSION_NAME:0

# 正しいペイン配置:
# ┌─────────────────┬─────────────────┐
# │  👔 Manager     │  🐍 Dev0        │
# │   (ペイン0)     │   (ペイン2)     │
# ├─────────────────┼─────────────────┤
# │  👑 CTO         │  🧪 Dev1        │
# │   (ペイン1)     │   (ペイン3)     │
# │                 ├─────────────────┤
# │                 │  🔄 Dev2        │
# │                 │   (ペイン4)     │
# └─────────────────┴─────────────────┘

# 各ペインで初期設定とClaude起動
echo -e "${CYAN}各ペインでClaude起動中...${NC}"

# Pane 0: Manager (左上)
tmux send-keys -t $SESSION_NAME:0.0 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.0 "cd $PROJECT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.0 "echo '👔 Manager - Python移行プロジェクト進捗管理'" C-m
tmux send-keys -t $SESSION_NAME:0.0 "echo '======================================='" C-m
tmux send-keys -t $SESSION_NAME:0.0 "claude --dangerously-skip-permissions" C-m

# Pane 1: CTO (左中)
tmux send-keys -t $SESSION_NAME:0.1 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.1 "cd $PROJECT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.1 "echo '👑 CTO - Python移行戦略決定'" C-m
tmux send-keys -t $SESSION_NAME:0.1 "echo '======================================='" C-m
tmux send-keys -t $SESSION_NAME:0.1 "claude --dangerously-skip-permissions" C-m

# Pane 2: Developer dev0 (右上)
tmux send-keys -t $SESSION_NAME:0.2 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.2 "cd $PROJECT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.2 "echo '🐍 Dev0 - Python GUI/API開発'" C-m
tmux send-keys -t $SESSION_NAME:0.2 "echo '======================================='" C-m
tmux send-keys -t $SESSION_NAME:0.2 "claude --dangerously-skip-permissions" C-m

# Pane 3: Developer dev1 (右中)
tmux send-keys -t $SESSION_NAME:0.3 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.3 "cd $PROJECT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.3 "echo '🧪 Dev1 - テスト/QA'" C-m
tmux send-keys -t $SESSION_NAME:0.3 "echo '======================================='" C-m
tmux send-keys -t $SESSION_NAME:0.3 "claude --dangerously-skip-permissions" C-m

# Pane 4: Developer dev2 (右下)
tmux send-keys -t $SESSION_NAME:0.4 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.4 "cd $PROJECT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.4 "echo '🔄 Dev2 - PowerShell互換性/インフラ'" C-m
tmux send-keys -t $SESSION_NAME:0.4 "echo '======================================='" C-m
tmux send-keys -t $SESSION_NAME:0.4 "claude --dangerously-skip-permissions" C-m

# Claudeが起動するまで待機（デフォルトを12秒に増加）
echo -e "${YELLOW}Claudeの起動を待機中...${NC}"
CLAUDE_STARTUP_WAIT=${CLAUDE_STARTUP_WAIT:-12}
echo "待機時間: ${CLAUDE_STARTUP_WAIT}秒"
echo -e "${CYAN}※ 環境変数 CLAUDE_STARTUP_WAIT で調整可能${NC}"
echo -e "${CYAN}※ 例: CLAUDE_STARTUP_WAIT=15 ./tmux_python_setup.sh${NC}"
sleep $CLAUDE_STARTUP_WAIT

# Python移行プロジェクト用の日本語プロンプトを送信
echo -e "${CYAN}Python移行プロジェクト用プロンプトを送信中...${NC}"

# Manager (Pane 0)
echo -e "${YELLOW}Manager (Pane 0) にプロンプトを送信...${NC}"
tmux send-keys -t $SESSION_NAME:0.0 "日本語で解説・対応してください。Project Manager として PowerShell版からPython版への移行プロジェクトを管理します。26機能の仕様分析とタスク調整を行います"
sleep 2  # 各プロンプト間の待機時間を増加
tmux send-keys -t $SESSION_NAME:0.0 C-m
echo "✅ Manager"

# CTO (Pane 1)
sleep 1
echo -e "${YELLOW}CTO (Pane 1) にプロンプトを送信...${NC}"
tmux send-keys -t $SESSION_NAME:0.1 "日本語で解説・対応してください。CTO として Python移行の技術戦略を決定します。既存資産を保護しつつ段階的移行を実現します"
sleep 2
tmux send-keys -t $SESSION_NAME:0.1 C-m
echo "✅ CTO"

# Dev0 (Pane 2)
sleep 1
echo -e "${YELLOW}Dev0 (Pane 2) にプロンプトを送信...${NC}"
tmux send-keys -t $SESSION_NAME:0.2 "日本語で解説・対応してください。Dev0 - Python GUI/API Developer として PyQt6による26機能のGUI実装とMicrosoft Graph API統合を担当します"
sleep 2
tmux send-keys -t $SESSION_NAME:0.2 C-m
echo "✅ Dev0"

# Dev1 (Pane 3)
sleep 1
echo -e "${YELLOW}Dev1 (Pane 3) にプロンプトを送信...${NC}"
tmux send-keys -t $SESSION_NAME:0.3 "日本語で解説・対応してください。Dev1 - Test/QA Developer として pytest基盤構築とPowerShell版との互換性テストを実装します"
sleep 2
tmux send-keys -t $SESSION_NAME:0.3 C-m
echo "✅ Dev1"

# Dev2 (Pane 4)
sleep 1
echo -e "${YELLOW}Dev2 (Pane 4) にプロンプトを送信...${NC}"
tmux send-keys -t $SESSION_NAME:0.4 "日本語で解説・対応してください。Dev2 - PowerShell Compatibility Developer として 既存仕様の分析と移行ツール開発を担当します"
sleep 2
tmux send-keys -t $SESSION_NAME:0.4 C-m
echo "✅ Dev2"

# Manager (Pane 0) にフォーカス
tmux select-pane -t $SESSION_NAME:0.0

echo ""
echo -e "${GREEN}✅ Python移行プロジェクト tmuxセッション作成完了！${NC}"
echo ""
echo -e "${CYAN}=== 5ペイン構成（仕様書準拠） ===${NC}"
echo -e "${YELLOW}配置:${NC}"
echo "┌─────────────────┬─────────────────┐"
echo "│  👔 Manager     │  🐍 Dev0        │"
echo "│   (ペイン0)     │   (ペイン2)     │"
echo "├─────────────────┼─────────────────┤"
echo "│  👑 CTO         │  🧪 Dev1        │"
echo "│   (ペイン1)     │   (ペイン3)     │"
echo "│                 ├─────────────────┤"
echo "│                 │  🔄 Dev2        │"
echo "│                 │   (ペイン4)     │"
echo "└─────────────────┴─────────────────┘"
echo ""
echo -e "${YELLOW}接続方法:${NC}"
echo "  tmux attach-session -t $SESSION_NAME"
echo ""
echo -e "${YELLOW}ペイン操作:${NC}"
echo "  Ctrl+b + 矢印キー: ペイン移動"
echo "  Ctrl+b + q: ペイン番号表示"
echo ""
echo -e "${YELLOW}役割配置:${NC}"
echo "  ペイン 0 (左上): Manager - 進捗管理・タスク調整"
echo "  ペイン 1 (左中): CTO - 戦略決定・技術承認"
echo "  ペイン 2 (右上): Dev0 - Python GUI/API開発"
echo "  ペイン 3 (右中): Dev1 - テスト/品質保証"
echo "  ペイン 4 (右下): Dev2 - PowerShell互換性"
echo ""
echo -e "${YELLOW}Claude統合:${NC}"
echo "  全役割でClaude自動起動済み ✅"
echo "  Python移行プロジェクト用プロンプト送信済み ✅"
echo "  各ペインで日本語での対話が可能"
echo ""
echo -e "${YELLOW}プロンプト送信の問題が発生した場合:${NC}"
echo "  ./init_claude_roles.sh を実行してください"
echo ""
echo -e "${YELLOW}関連ドキュメント:${NC}"
echo "  - ITSM-tmux並列開発環境仕様書.md"
echo "  - Microsoft365管理ツール変更仕様書.md"
echo "  - tmux/collaboration/5pane_integration_guide.md"