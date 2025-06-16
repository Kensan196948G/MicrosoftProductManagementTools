#!/bin/bash

# Microsoft製品運用管理ツール - Vim操作デモ
# 設定ファイル編集の練習用

set -e

PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}=================================================================================${NC}"
echo -e "${WHITE}      Microsoft製品運用管理ツール - Vim操作デモ${NC}"
echo -e "${CYAN}=================================================================================${NC}"
echo ""

# デモ用JSONファイル作成
DEMO_FILE="${PROJECT_ROOT}/demo-config.json"

cat > "${DEMO_FILE}" << 'EOF'
{
  "General": {
    "OrganizationName": "Demo Organization",
    "Environment": "Test",
    "TimeZone": "Tokyo Standard Time"
  },
  "Demo": {
    "EditThis": "この値を編集してください",
    "AddNewItem": "新しい項目を追加してください",
    "TestValue": 123
  }
}
EOF

echo -e "${GREEN}📝 Vim操作デモファイルを作成しました: ${DEMO_FILE}${NC}"
echo ""
echo -e "${YELLOW}【練習手順】${NC}"
echo -e "1. ${WHITE}i${NC} を押して挿入モード"
echo -e "2. ${WHITE}\"Demo Organization\"${NC} を ${WHITE}\"あなたの組織名\"${NC} に変更"
echo -e "3. ${WHITE}ESC${NC} でノーマルモードに戻る"
echo -e "4. ${WHITE}:wq${NC} で保存終了"
echo ""
echo -e "${BLUE}Enterキーを押してVimデモを開始...${NC}"
read -r

# Vimでデモファイルを開く
vim "${DEMO_FILE}"

echo ""
echo -e "${GREEN}✅ Vimデモ完了！${NC}"

# 編集結果確認
if [[ -f "${DEMO_FILE}" ]]; then
    echo ""
    echo -e "${WHITE}編集結果:${NC}"
    echo -e "${CYAN}----------------------------------------${NC}"
    cat "${DEMO_FILE}"
    echo -e "${CYAN}----------------------------------------${NC}"
    
    # JSON構文チェック
    if python3 -m json.tool "${DEMO_FILE}" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ JSON構文: 正常${NC}"
    else
        echo -e "${RED}❌ JSON構文: エラー${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}💡 実際の設定ファイル編集は以下で実行:${NC}"
echo -e "${WHITE}   ./edit-config-vim.sh${NC}"
echo ""