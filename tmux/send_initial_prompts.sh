#!/bin/bash
# 全ペインに初期プロンプトを送信するスクリプト
# Version: 1.0
# Date: 2025-07-17

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SESSION_NAME="MicrosoftProductTools"

echo -e "${CYAN}=== 全ペインに日本語対応プロンプトを送信 ===${NC}"
echo ""

# 各ペインにプロンプトを送信
echo -e "${YELLOW}Manager (ペイン0) に送信中...${NC}"
tmux send-keys -t $SESSION_NAME:0.0 "日本語で解説・対応してください。Project Manager として開発チームを調整し、プロジェクト管理を行います。進捗監視とタスク調整に注力してください。" C-m

echo -e "${YELLOW}Dev0 (ペイン1) に送信中...${NC}"
tmux send-keys -t $SESSION_NAME:0.1 "日本語で解説・対応してください。Dev0 - Frontend Developer として React/Vue.js の実装を行います。UI/UX とレスポンシブデザインに注力してください。" C-m

echo -e "${YELLOW}CTO (ペイン2) に送信中...${NC}"
tmux send-keys -t $SESSION_NAME:0.2 "日本語で解説・対応してください。CTO として技術戦略を管理します。アーキテクチャ最適化と技術的負債削減に注力してください。" C-m

echo -e "${YELLOW}Dev1 (ペイン3) に送信中...${NC}"
tmux send-keys -t $SESSION_NAME:0.3 "日本語で解説・対応してください。Dev1 - Backend Developer として Node.js/Express の実装を行います。API設計とデータベース最適化に注力してください。" C-m

echo -e "${YELLOW}Dev2 (ペイン4) に送信中...${NC}"
tmux send-keys -t $SESSION_NAME:0.4 "日本語で解説・対応してください。Dev2 - Test/QA Developer として自動テストとセキュリティ検証を行います。品質保証とテストカバレッジ向上に注力してください。" C-m

echo ""
echo -e "${GREEN}✅ 全ペインへの初期プロンプト送信が完了しました！${NC}"
echo ""
echo -e "${CYAN}使用方法:${NC}"
echo "1. tmux attach-session -t $SESSION_NAME でセッションに接続"
echo "2. 各ペインでClaudeが起動していることを確認"
echo "3. このスクリプトを実行: ./send_initial_prompts.sh"