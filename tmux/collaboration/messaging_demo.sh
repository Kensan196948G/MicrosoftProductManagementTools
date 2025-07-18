#!/bin/bash
# メッセージングシステムデモスクリプト（5ペイン構成版）
# Version: 1.0
# Date: 2025-07-17

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 設定
SESSION_NAME="MicrosoftProductTools"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# メッセージングシステムを読み込み
source "$SCRIPT_DIR/messaging_system.sh"

echo -e "${CYAN}=== 相互連携メッセージングシステム デモ（5ペイン構成） ===${NC}"
echo ""
echo -e "${YELLOW}このデモでは、CTO、Manager、Developer間の連携を実演します。${NC}"
echo ""

# セッション確認
if ! tmux has-session -t $SESSION_NAME 2>/dev/null; then
    echo -e "${RED}エラー: tmuxセッション '$SESSION_NAME' が見つかりません。${NC}"
    echo "先に tmux_itsm_setup.sh を実行してください。"
    exit 1
fi

echo -e "${GREEN}tmuxセッションが確認されました。${NC}"
echo ""

# デモシナリオ
echo -e "${CYAN}=== シナリオ1: CTOからManagerへの技術方針通達 ===${NC}"
read -p "Enterキーで実行..."
send_message "CTO" "Manager" "coordination" "新しいマイクロサービス化プロジェクトを開始します。チーム編成を検討してください。"
sleep 2

echo ""
echo -e "${CYAN}=== シナリオ2: ManagerからDeveloper全員へのタスク割り当て ===${NC}"
read -p "Enterキーで実行..."
send_message "Manager" "Developer" "coordination" "マイクロサービス化プロジェクトのタスクを以下のように割り当てます：Dev0-UI設計、Dev1-API実装、Dev2-テスト戦略"
sleep 2

echo ""
echo -e "${CYAN}=== シナリオ3: Dev0からManagerへの進捗報告 ===${NC}"
read -p "Enterキーで実行..."
send_message "Dev0" "Manager" "status" "UI設計のモックアップが完成しました。レビューをお願いします。"
sleep 2

echo ""
echo -e "${CYAN}=== シナリオ4: Dev1からCTOへの技術相談 ===${NC}"
read -p "Enterキーで実行..."
technical_consultation "Dev1" "CTO" "GraphQLとREST APIのどちらを採用すべきか、技術的な観点からアドバイスをお願いします。"
sleep 2

echo ""
echo -e "${CYAN}=== シナリオ5: Dev2から全員への緊急連絡 ===${NC}"
read -p "Enterキーで実行..."
emergency_notification "Dev2" "本番環境でメモリリークを検出しました。至急対応が必要です。"
sleep 2

echo ""
echo -e "${CYAN}=== シナリオ6: CTOから全員へのステータス更新 ===${NC}"
read -p "Enterキーで実行..."
update_status "CTO" "対応中" "メモリリーク問題を最優先で対応します。Dev1は原因調査、Dev0はユーザー通知準備を。"
sleep 2

echo ""
echo -e "${GREEN}✅ デモが完了しました！${NC}"
echo ""
echo -e "${YELLOW}実際の使用例：${NC}"
echo "  source $SCRIPT_DIR/messaging_system.sh"
echo "  send_message \"Manager\" \"Dev0\" \"coordination\" \"フロントエンドのレビューをお願いします\""
echo "  request_task \"CTO\" \"Manager\" \"セキュリティ監査の計画策定\" \"高\""
echo ""
echo -e "${YELLOW}tmuxセッションで確認：${NC}"
echo "  tmux attach-session -t $SESSION_NAME"