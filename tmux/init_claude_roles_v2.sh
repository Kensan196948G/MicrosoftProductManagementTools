#!/bin/bash
# Claude役割初期化スクリプト（ダブルEnter版）
# Version: 2.1
# Date: 2025-07-17

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SESSION_NAME="MicrosoftProductTools"

echo -e "${CYAN}=== Claude役割初期化（ダブルEnter版）===${NC}"
echo ""
echo -e "${YELLOW}⚠️ 注意: 全てのペインでClaudeが完全に起動していることを確認してください${NC}"
echo ""
read -p "Claudeが全ペインで起動完了していますか？ (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}中止しました${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}5秒後に初期プロンプトを送信します...${NC}"
sleep 5

# 各ペインに役割別プロンプトを送信（ダブルEnter方式）
echo -e "${CYAN}初期プロンプトを送信中...${NC}"

send_prompt_to_pane() {
    local pane=$1
    local prompt=$2
    local role_name=$3
    
    # プロンプトを送信
    tmux send-keys -t $SESSION_NAME:0.$pane "$prompt"
    sleep 0.2
    # 1回目のEnter
    tmux send-keys -t $SESSION_NAME:0.$pane C-m
    sleep 0.5
    # 2回目のEnter（念のため）
    tmux send-keys -t $SESSION_NAME:0.$pane C-m
    
    echo "✅ $role_name"
}

# 各ペインに送信
send_prompt_to_pane 0 "日本語で解説・対応してください。Project Manager として開発チームを調整し、プロジェクト管理を行います。進捗監視とタスク調整に注力してください。" "Manager"
sleep 1

send_prompt_to_pane 1 "日本語で解説・対応してください。Dev0 - Frontend Developer として React/Vue.js の実装を行います。UI/UX とレスポンシブデザインに注力してください。" "Dev0"
sleep 1

send_prompt_to_pane 2 "日本語で解説・対応してください。CTO として技術戦略を管理します。アーキテクチャ最適化と技術的負債削減に注力してください。" "CTO"
sleep 1

send_prompt_to_pane 3 "日本語で解説・対応してください。Dev1 - Backend Developer として Node.js/Express の実装を行います。API設計とデータベース最適化に注力してください。" "Dev1"
sleep 1

send_prompt_to_pane 4 "日本語で解説・対応してください。Dev2 - Test/QA Developer として自動テストとセキュリティ検証を行います。品質保証とテストカバレッジ向上に注力してください。" "Dev2"

echo ""
echo -e "${GREEN}✅ 全ペインへの初期プロンプト送信が完了しました！${NC}"
echo ""
echo -e "${CYAN}確認方法:${NC}"
echo "  tmux attach-session -t $SESSION_NAME"
echo "  各ペインでClaudeが日本語で応答しているか確認"
echo ""
echo -e "${YELLOW}もしプロンプトが残っている場合:${NC}"
echo "  各ペインで手動でEnterキーを押してください"