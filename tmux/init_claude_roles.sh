#!/bin/bash
# Claude役割初期化スクリプト（遅延送信版）
# Version: 2.0
# Date: 2025-07-17

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SESSION_NAME="MicrosoftProductTools-Python"

echo -e "${CYAN}=== Claude役割初期化（Python移行プロジェクト版）===${NC}"
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
echo -e "${YELLOW}※ tmux_itsm_setup.sh 実行直後の場合は、この処理は不要です${NC}"
sleep 5

# 各ペインに役割別プロンプトを送信（Python移行プロジェクト用）
echo -e "${CYAN}初期プロンプトを送信中...${NC}"

# Manager (ペイン0) - 左上
echo -e "${YELLOW}Manager (Pane 0) にプロンプトを送信...${NC}"
tmux send-keys -t $SESSION_NAME:0.0 "日本語で解説・対応してください。Project Manager として PowerShell版からPython版への移行プロジェクトを管理します。26機能の仕様分析とタスク調整を行います"
sleep 1.5  # 待機時間を増加
tmux send-keys -t $SESSION_NAME:0.0 C-m
echo "✅ Manager"
sleep 1

# CTO (ペイン1) - 左中
echo -e "${YELLOW}CTO (Pane 1) にプロンプトを送信...${NC}"
tmux send-keys -t $SESSION_NAME:0.1 "日本語で解説・対応してください。CTO として Python移行の技術戦略を決定します。既存資産を保護しつつ段階的移行を実現します"
sleep 1.5  # 待機時間を増加
tmux send-keys -t $SESSION_NAME:0.1 C-m
echo "✅ CTO"
sleep 1

# Dev0 (ペイン2) - 右上
echo -e "${YELLOW}Dev0 (Pane 2) にプロンプトを送信...${NC}"
tmux send-keys -t $SESSION_NAME:0.2 "日本語で解説・対応してください。Dev0 - Python GUI/API Developer として PyQt6による26機能のGUI実装とMicrosoft Graph API統合を担当します"
sleep 1.5  # 待機時間を増加
tmux send-keys -t $SESSION_NAME:0.2 C-m
echo "✅ Dev0"
sleep 1

# Dev1 (ペイン3) - 右中
echo -e "${YELLOW}Dev1 (Pane 3) にプロンプトを送信...${NC}"
tmux send-keys -t $SESSION_NAME:0.3 "日本語で解説・対応してください。Dev1 - Test/QA Developer として pytest基盤構築とPowerShell版との互換性テストを実装します"
sleep 1.5  # 待機時間を増加
tmux send-keys -t $SESSION_NAME:0.3 C-m
echo "✅ Dev1"
sleep 1

# Dev2 (ペイン4) - 右下
echo -e "${YELLOW}Dev2 (Pane 4) にプロンプトを送信...${NC}"
tmux send-keys -t $SESSION_NAME:0.4 "日本語で解説・対応してください。Dev2 - PowerShell Compatibility Developer として 既存仕様の分析と移行ツール開発を担当します"
sleep 1.5  # 待機時間を増加
tmux send-keys -t $SESSION_NAME:0.4 C-m
echo "✅ Dev2"

echo ""
echo -e "${GREEN}✅ 全ペインへの初期プロンプト送信が完了しました！${NC}"
echo ""
echo -e "${CYAN}確認方法:${NC}"
echo "  tmux attach-session -t $SESSION_NAME"
echo "  各ペインでClaudeが日本語で応答しているか確認"