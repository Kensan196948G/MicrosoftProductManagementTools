#!/bin/bash
# ITSM-tmux並列開発環境セットアップスクリプト (5ペイン構成)
# Version: 3.0
# Date: 2025-07-17

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# セッション名
SESSION_NAME="MicrosoftProductTools"

# プロジェクトディレクトリ
PROJECT_DIR="$HOME/projects/MicrosoftProductTools"

# tmuxスクリプトディレクトリ
TMUX_DIR="$(dirname "$(realpath "$0")")"
# ルートディレクトリ（tmuxフォルダの親）
ROOT_DIR="$(dirname "$TMUX_DIR")"

echo -e "${BLUE}=== ITSM-tmux並列開発環境セットアップ (5ペイン構成) ===${NC}"

# tmuxインストール確認
if ! command -v tmux &> /dev/null; then
    echo -e "${RED}tmuxがインストールされていません。インストールしてください。${NC}"
    echo "sudo apt-get install tmux"
    exit 1
fi

# プロジェクトディレクトリ作成
echo -e "${YELLOW}プロジェクトディレクトリ作成中...${NC}"
mkdir -p "$PROJECT_DIR"/{src,public,tests,docs,logs,scripts}
mkdir -p "$PROJECT_DIR/logs/messages"

# 必要なログファイル作成
touch "$PROJECT_DIR/logs/developer-activity.log"
touch "$PROJECT_DIR/logs/integrated-dev.log"
touch "$PROJECT_DIR/logs/manager-actions.log"
touch "$PROJECT_DIR/logs/task-assignments.log"

# 既存セッション確認・削除
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
    echo -e "${YELLOW}既存セッションを削除します...${NC}"
    tmux kill-session -t $SESSION_NAME
    sleep 1
fi

# 新規セッション作成 (1つのウィンドウ、5ペイン構成)
echo -e "${GREEN}tmuxセッション作成中 (5ペイン構成)...${NC}"
tmux new-session -d -s $SESSION_NAME -n "Team"

# Claude環境変数読み込み
if [ -f "$HOME/.config/claude/claude_env.sh" ]; then
    source "$HOME/.config/claude/claude_env.sh"
fi

# 少し待機
sleep 1

echo -e "${CYAN}ペイン構成を作成中...${NC}"

# ペイン構成: 5ペイン配置を順次作成
echo "開始時ペイン数: $(tmux list-panes -t $SESSION_NAME:0 | wc -l)"

# ステップ1: 水平分割（左右）
tmux split-window -h -t $SESSION_NAME:0
echo "水平分割後: $(tmux list-panes -t $SESSION_NAME:0 | wc -l) ペイン"

# ステップ2: 左ペインを垂直分割（上下）
tmux split-window -v -t $SESSION_NAME:0.0  
echo "左ペイン分割後: $(tmux list-panes -t $SESSION_NAME:0 | wc -l) ペイン"

# ステップ3: 右ペインを垂直分割（上下）
tmux split-window -v -t $SESSION_NAME:0.2
echo "右ペイン分割後: $(tmux list-panes -t $SESSION_NAME:0 | wc -l) ペイン"

# ステップ4: 右下ペインを垂直分割（上下）
tmux split-window -v -t $SESSION_NAME:0.3
echo "最終分割後: $(tmux list-panes -t $SESSION_NAME:0 | wc -l) ペイン"

# ペイン配置確認
tmux list-panes -t $SESSION_NAME:0 -F "ペイン#{pane_index}: #{pane_width}x#{pane_height}"

echo -e "${CYAN}各ペインに役割を配置中...${NC}"

# 実際のペイン配置に基づいて役割を正確に配置
# tmuxの分割順序では以下になる:
# ペイン0: 左上, ペイン1: 右上, ペイン2: 左下, ペイン3: 右中, ペイン4: 右下

# 各ペインでClaude起動
echo -e "${CYAN}各ペインでClaude起動中...${NC}"

# ペイン 0 (左上): Manager
tmux send-keys -t $SESSION_NAME:0.0 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.0 "cd $ROOT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.0 "claude --dangerously-skip-permissions" C-m

# ペイン 1 (右上): Dev0 - Frontend
tmux send-keys -t $SESSION_NAME:0.1 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.1 "cd $ROOT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.1 "claude --dangerously-skip-permissions" C-m

# ペイン 2 (左下): CTO
tmux send-keys -t $SESSION_NAME:0.2 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.2 "cd $ROOT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.2 "claude --dangerously-skip-permissions" C-m

# ペイン 3 (右中): Dev1 - Backend
tmux send-keys -t $SESSION_NAME:0.3 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.3 "cd $ROOT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.3 "claude --dangerously-skip-permissions" C-m

# ペイン 4 (右下): Dev2 - Test/QA
tmux send-keys -t $SESSION_NAME:0.4 "clear" C-m
tmux send-keys -t $SESSION_NAME:0.4 "cd $ROOT_DIR" C-m
tmux send-keys -t $SESSION_NAME:0.4 "claude --dangerously-skip-permissions" C-m

# Claudeが起動するまで待機
echo -e "${YELLOW}Claudeの起動を待機中...${NC}"
CLAUDE_STARTUP_WAIT=${CLAUDE_STARTUP_WAIT:-8}
echo "待機時間: ${CLAUDE_STARTUP_WAIT}秒"
echo -e "${CYAN}※ 環境変数 CLAUDE_STARTUP_WAIT で調整可能${NC}"
sleep $CLAUDE_STARTUP_WAIT

# 日本語対応プロンプトを送信
echo -e "${CYAN}日本語対応プロンプトを送信中...${NC}"

# Manager (ペイン0)
tmux send-keys -t $SESSION_NAME:0.0 "日本語で解説・対応してください。Project Manager として Microsoft 365 統合管理ツールの開発を管理します。26機能の実装スケジュール管理、タスク配分、依存関係管理、コードレビューとテスト結果の監視に注力してください。"
sleep 0.5
tmux send-keys -t $SESSION_NAME:0.0 C-m

# Dev0 (ペイン1)
tmux send-keys -t $SESSION_NAME:0.1 "日本語で解説・対応してください。Dev0 - Frontend Developer として PowerShell Windows Forms GUI の実装を行います。26機能のボタン配置、リアルタイムログ表示、ポップアップ通知の実装に注力し、GuiApp_Enhanced.ps1 を担当してください。"
sleep 0.5
tmux send-keys -t $SESSION_NAME:0.1 C-m

# CTO (ペイン2)
tmux send-keys -t $SESSION_NAME:0.2 "日本語で解説・対応してください。CTO として Microsoft 365 API 統合方針と PowerShell 7.5.1 移行戦略を管理します。コーディング規約、セキュリティポリシーの策定、アーキテクチャとリリースの最終承認に注力してください。"
sleep 0.5
tmux send-keys -t $SESSION_NAME:0.2 C-m

# Dev1 (ペイン3)
tmux send-keys -t $SESSION_NAME:0.3 "日本語で解説・対応してください。Dev1 - Backend Developer として Microsoft Graph API と Exchange Online PowerShell の統合を行います。RealM365DataProvider.psm1 のデータ処理と Authentication.psm1 の認証システム実装に注力してください。"
sleep 0.5
tmux send-keys -t $SESSION_NAME:0.3 C-m

# Dev2 (ペイン4)
tmux send-keys -t $SESSION_NAME:0.4 "日本語で解説・対応してください。Dev2 - Test/QA Developer として Pester フレームワークによる自動テストを実装します。80%以上のテストカバレッジ達成、セキュリティスキャン、パフォーマンステスト、ISO/IEC 27001準拠確認に注力してください。"
sleep 0.5
tmux send-keys -t $SESSION_NAME:0.4 C-m

# ペイン 0 (Manager) にフォーカス
tmux select-pane -t $SESSION_NAME:0.0

# Window 0 (Team) を選択してデフォルトに
tmux select-window -t $SESSION_NAME:0

echo -e "${GREEN}✅ tmuxセッション作成完了！${NC}"
echo ""
echo -e "${CYAN}=== 5ペイン構成 ===${NC}"
echo -e "${YELLOW}実際の配置:${NC}"
echo "┌─────────────────┬─────────────────┐"
echo "│  📋 Manager     │  🎨 Dev0        │"
echo "│   (ペイン0)     │   (ペイン2)     │"
echo "├─────────────────┼─────────────────┤"
echo "│  👔 CTO         │  🔧 Dev1        │"
echo "│   (ペイン1)     │   (ペイン3)     │"
echo "│                 ├─────────────────┤"
echo "│                 │  🧪 Dev2        │"
echo "│                 │   (ペイン4)     │"
echo "└─────────────────┴─────────────────┘"
echo ""
echo -e "${YELLOW}接続方法:${NC}"
echo "  tmux attach-session -t $SESSION_NAME"
echo ""
echo -e "${YELLOW}ペイン操作:${NC}"
echo "  Ctrl+b + 矢印キー: ペイン移動"
echo "  Ctrl+b + h/j/k/l: Vim風ペイン移動"
echo "  Ctrl+b + q: ペイン番号表示"
echo ""
echo -e "${YELLOW}役割配置:${NC}"
echo "  ペイン 0 (左上): Manager - プロジェクト管理"
echo "  ペイン 1 (右上): Dev0 - Frontend開発" 
echo "  ペイン 2 (左下): CTO - 技術戦略"
echo "  ペイン 3 (右中): Dev1 - Backend開発"
echo "  ペイン 4 (右下): Dev2 - Test/QA"
echo ""
echo -e "${YELLOW}Claude統合:${NC}"
echo "  全役割でClaude自動起動済み ✅"
echo "  日本語対応プロンプト自動送信済み ✅"
echo "  各ペインで日本語での対話が可能"
echo ""
echo -e "${YELLOW}次のステップ:${NC}"
echo "  1. tmux attach-session -t $SESSION_NAME"
echo "  2. 各ペインで役割に応じた作業開始"
echo ""
echo -e "${YELLOW}関連ドキュメント:${NC}"
echo "  - ITSM-tmux並列開発環境仕様書.md"
echo "  - docs/役割定義書.md"
echo "  - collaboration/role_communication_guide.md"