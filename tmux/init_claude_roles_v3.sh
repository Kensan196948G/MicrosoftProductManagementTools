#!/bin/bash
# Claude役割初期化スクリプト（Returnキー版）
# Version: 2.2
# Date: 2025-07-17

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SESSION_NAME="MicrosoftProductTools"

echo -e "${CYAN}=== Claude役割初期化（Returnキー版）===${NC}"
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

# 各ペインに役割別プロンプトを送信
echo -e "${CYAN}初期プロンプトを送信中...${NC}"

# プロンプト定義
declare -A prompts
prompts[0]="日本語で解説・対応してください。Project Manager として開発チームを調整し、プロジェクト管理を行います。進捗監視とタスク調整に注力してください。"
prompts[1]="日本語で解説・対応してください。Dev0 - Frontend Developer として React/Vue.js の実装を行います。UI/UX とレスポンシブデザインに注力してください。"
prompts[2]="日本語で解説・対応してください。CTO として技術戦略を管理します。アーキテクチャ最適化と技術的負債削減に注力してください。"
prompts[3]="日本語で解説・対応してください。Dev1 - Backend Developer として Node.js/Express の実装を行います。API設計とデータベース最適化に注力してください。"
prompts[4]="日本語で解説・対応してください。Dev2 - Test/QA Developer として自動テストとセキュリティ検証を行います。品質保証とテストカバレッジ向上に注力してください。"

# 役割名
declare -A roles
roles[0]="Manager"
roles[1]="Dev0"
roles[2]="CTO"
roles[3]="Dev1"
roles[4]="Dev2"

# 各ペインに送信（異なる方法）
for i in {0..4}; do
    # プロンプトをクリップボードスタイルで送信
    tmux send-keys -t $SESSION_NAME:0.$i -l "${prompts[$i]}"
    sleep 0.3
    # Returnキーを送信
    tmux send-keys -t $SESSION_NAME:0.$i Enter
    echo "✅ ${roles[$i]}"
    sleep 0.5
done

echo ""
echo -e "${GREEN}✅ 全ペインへの初期プロンプト送信が完了しました！${NC}"
echo ""
echo -e "${CYAN}トラブルシューティング:${NC}"
echo "  1. プロンプトが残っている場合 → 各ペインで手動でEnterキー"
echo "  2. 文字化けしている場合 → ./init_claude_roles.sh を試す"
echo "  3. 反応がない場合 → role_cards.md から手動コピペ"