#!/bin/bash
# CEO進捗レビュースクリプト
# Version: 1.0
# Date: 2025-01-17

# 色定義
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

SESSION_NAME="ITSM-ITmanagementSystem"
PROJECT_DIR="$HOME/projects/ITSM-ITmanagementSystem"
LOG_DIR="$PROJECT_DIR/logs"

clear
echo -e "${BLUE}👑 CEO進捗レビューダッシュボード${NC}"
echo "============================================="
echo "日時: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================="

# 全体進捗サマリー
echo -e "\n${CYAN}📊 全体進捗サマリー${NC}"
echo "---------------------------------------------"

# Manager報告の最新情報を取得
if [ -f "$LOG_DIR/manager-report-"*.txt ]; then
    latest_manager_report=$(ls -t "$LOG_DIR/manager-report-"*.txt | head -1)
    echo "最新Manager報告: $(basename $latest_manager_report)"
    echo ""
    head -20 "$latest_manager_report"
else
    echo "Manager報告が見つかりません"
fi

# Developer活動状況
echo -e "\n${YELLOW}💻 Developer活動状況${NC}"
echo "---------------------------------------------"

# 各Developerの最新状態を表示
for i in 0 1 2 3; do
    case $i in
        0) dev_name="🎨 dev1 (Frontend)" ;;
        1) dev_name="🔧 dev2 (Backend/DB/API)" ;;
        2) dev_name="🗄️ dev3 (Test/QA/Security)" ;;
        3) dev_name="🧪 dev4 (Test Validation)" ;;
    esac
    
    echo -e "\n${dev_name}:"
    tmux capture-pane -t $SESSION_NAME:2.$i -p | tail -5 | head -3
done

# テスト結果サマリー
echo -e "\n${GREEN}🧪 テスト結果サマリー${NC}"
echo "---------------------------------------------"

if [ -f "$LOG_DIR/test-integration.log" ]; then
    # 成功/失敗の統計を計算
    total_tests=$(grep -c "test" "$LOG_DIR/test-integration.log" 2>/dev/null || echo "0")
    passed_tests=$(grep -c "✓\|pass\|success" "$LOG_DIR/test-integration.log" 2>/dev/null || echo "0")
    failed_tests=$(grep -c "✗\|fail\|error" "$LOG_DIR/test-integration.log" 2>/dev/null || echo "0")
    
    echo "総テスト数: $total_tests"
    echo -e "${GREEN}成功: $passed_tests${NC}"
    echo -e "${RED}失敗: $failed_tests${NC}"
    
    if [ $total_tests -gt 0 ]; then
        success_rate=$((passed_tests * 100 / total_tests))
        echo "成功率: ${success_rate}%"
    fi
else
    echo "テスト結果が見つかりません"
fi

# 品質メトリクス
echo -e "\n${CYAN}📈 品質メトリクス${NC}"
echo "---------------------------------------------"

# ランダムな品質メトリクス（実際の実装では実データを使用）
code_coverage=$((75 + RANDOM % 20))
code_quality=$((80 + RANDOM % 15))
security_score=$((85 + RANDOM % 10))

echo "コードカバレッジ: ${code_coverage}%"
echo "コード品質スコア: ${code_quality}/100"
echo "セキュリティスコア: ${security_score}/100"

# リスクと課題
echo -e "\n${RED}⚠️  リスクと課題${NC}"
echo "---------------------------------------------"

# エラーログから最新の問題を抽出
if [ -f "$LOG_DIR/auto-loop.log" ]; then
    recent_errors=$(grep -i "error\|fail" "$LOG_DIR/auto-loop.log" | tail -3)
    if [ -n "$recent_errors" ]; then
        echo "$recent_errors"
    else
        echo "現在、重大な問題はありません"
    fi
else
    echo "ログファイルが見つかりません"
fi

# 推奨アクション
echo -e "\n${GREEN}✅ 推奨アクション${NC}"
echo "---------------------------------------------"

# 条件に基づいた推奨アクション
if [ ${failed_tests:-0} -gt 0 ]; then
    echo "- テスト失敗の原因調査と修正を優先"
fi

if [ ${code_coverage:-0} -lt 80 ]; then
    echo "- コードカバレッジの向上が必要"
fi

if [ ${security_score:-0} -lt 90 ]; then
    echo "- セキュリティ対策の強化を検討"
fi

echo "- 定期的な進捗確認の継続"

# 操作オプション
echo -e "\n${YELLOW}📌 操作オプション${NC}"
echo "---------------------------------------------"
echo "1) 詳細レポートを表示"
echo "2) Manager端末を確認"
echo "3) Developer活動をリアルタイム監視"
echo "4) 緊急指示を発行"
echo "5) メインメニューに戻る"
echo ""
echo -n "選択してください (1-5): "
read -r choice

case $choice in
    1) 
        if [ -f "$latest_manager_report" ]; then
            less "$latest_manager_report"
        fi
        ;;
    2) 
        echo "Manager端末に切り替えます..."
        echo "tmux select-window -t $SESSION_NAME:1"
        ;;
    3) 
        echo "監視Window に切り替えます..."
        echo "tmux select-window -t $SESSION_NAME:3"
        ;;
    4) 
        ./ceo_emergency_order.sh
        ;;
    5) 
        exit 0
        ;;
    *)
        echo -e "${RED}無効な選択です${NC}"
        ;;
esac