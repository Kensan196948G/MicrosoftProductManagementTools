#!/bin/bash
# 5ペイン相互連携テストスクリプト
# CTO、Manager、3名のDeveloperの連携をシミュレート

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# テスト用ログディレクトリ
TEST_LOG_DIR="./logs/communication_test"
mkdir -p $TEST_LOG_DIR

# タイムスタンプ付きログ関数
log_message() {
    local from=$1
    local to=$2
    local type=$3
    local message=$4
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] $from → $to [$type]: $message" >> "$TEST_LOG_DIR/test_communication.log"
    
    # 画面にも表示
    case $type in
        instruction)
            echo -e "${BLUE}[$timestamp] ${CYAN}$from${NC} → ${YELLOW}$to${NC} [指示]: $message"
            ;;
        report)
            echo -e "${GREEN}[$timestamp] ${YELLOW}$from${NC} → ${CYAN}$to${NC} [報告]: $message"
            ;;
        emergency)
            echo -e "${RED}[$timestamp] ${RED}$from${NC} → ${RED}$to${NC} [緊急]: $message"
            ;;
        consultation)
            echo -e "${PURPLE}[$timestamp] ${PURPLE}$from${NC} → ${PURPLE}$to${NC} [相談]: $message"
            ;;
    esac
}

# テスト開始
echo -e "${CYAN}=== 5ペイン相互連携テスト開始 ===${NC}"
echo "テストシナリオ: Python移行プロジェクト Phase 1 基盤構築"
echo ""

# シナリオ1: CTO → Manager への戦略指示
echo -e "${YELLOW}【シナリオ1】CTO → Manager への戦略指示${NC}"
log_message "CTO" "Manager" "instruction" "Python移行のPhase 1を開始してください。PyQt6とMSAL認証を優先"
sleep 2

# Manager → CTO への確認
log_message "Manager" "CTO" "report" "了解しました。Phase 1の開発リソースを以下のように配分します"
sleep 1

# シナリオ2: Manager → 各Developer へのタスク割り当て
echo -e "\n${YELLOW}【シナリオ2】Manager → 各Developer へのタスク割り当て${NC}"
log_message "Manager" "dev0" "instruction" "PyQt6環境構築と基本GUIフレームワーク実装を開始してください（優先度: 高）"
sleep 1
log_message "Manager" "dev1" "instruction" "pytest環境セットアップとテスト基盤構築をお願いします（優先度: 中）"
sleep 1
log_message "Manager" "dev2" "instruction" "PowerShell仕様分析とWSL環境構築を進めてください（優先度: 中）"
sleep 2

# シナリオ3: 各Developer からの初期報告
echo -e "\n${YELLOW}【シナリオ3】各Developer からの初期報告${NC}"
log_message "dev0" "Manager" "report" "PyQt6環境構築開始。予想完了時間: 4時間"
sleep 1
log_message "dev1" "Manager" "report" "pytest環境確認中。GitHub Actions設定も並行して進めます"
sleep 1
log_message "dev2" "Manager" "report" "既存PowerShellコード分析開始。26機能の詳細仕様をドキュメント化します"
sleep 2

# シナリオ4: Developer間の技術相談
echo -e "\n${YELLOW}【シナリオ4】Developer間の技術相談${NC}"
log_message "dev0" "dev2" "consultation" "既存GUIのボタン配置仕様を確認させてください"
sleep 1
log_message "dev2" "dev0" "report" "GuiApp_Enhanced.ps1の248行目から26機能のレイアウト定義があります"
sleep 2

# シナリオ5: ブロッカー発生と緊急対応
echo -e "\n${YELLOW}【シナリオ5】ブロッカー発生と緊急対応${NC}"
log_message "dev1" "Manager" "emergency" "pytest環境でPowerShell互換性テストのモジュールエラー発生"
sleep 1
log_message "Manager" "dev1" "instruction" "dev2と連携して解決してください。必要なら私も支援します"
sleep 1
log_message "Manager" "dev2" "instruction" "dev1のブロッカー解決を優先してください"
sleep 1
log_message "dev2" "dev1" "report" "PowerShell実行コンテキストの設定が必要です。解決方法を共有します"
sleep 2

# シナリオ6: 進捗報告とCTOへのエスカレーション
echo -e "\n${YELLOW}【シナリオ6】進捗報告とCTOへのエスカレーション${NC}"
log_message "Manager" "CTO" "report" "Phase 1進捗: 全体15%完了。dev1でブロッカー発生も解決見込み"
sleep 1
log_message "CTO" "Manager" "instruction" "ブロッカーの詳細を確認。必要なら追加リソースを検討します"
sleep 2

# シナリオ7: 定期同期
echo -e "\n${YELLOW}【シナリオ7】定期同期ミーティング${NC}"
log_message "Manager" "All" "instruction" "30分定期同期を開始します。各自ステータスを報告してください"
sleep 1
log_message "dev0" "All" "report" "PyQt6基本構造50%完了。メインウィンドウのプロトタイプ作成中"
sleep 1
log_message "dev1" "All" "report" "テスト環境30%完了。PowerShell互換性問題はdev2の支援で解決"
sleep 1
log_message "dev2" "All" "report" "仕様分析40%完了。互換性マッピング表を作成中"
sleep 2

# テスト結果サマリー
echo -e "\n${CYAN}=== テスト結果サマリー ===${NC}"
echo "テスト完了時刻: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "通信統計:"
echo "- 総メッセージ数: $(wc -l < $TEST_LOG_DIR/test_communication.log)"
echo "- 指示: $(grep -c "instruction" $TEST_LOG_DIR/test_communication.log)"
echo "- 報告: $(grep -c "report" $TEST_LOG_DIR/test_communication.log)" 
echo "- 緊急: $(grep -c "emergency" $TEST_LOG_DIR/test_communication.log)"
echo "- 相談: $(grep -c "consultation" $TEST_LOG_DIR/test_communication.log)"
echo ""
echo "役割別メッセージ数:"
for role in CTO Manager dev0 dev1 dev2; do
    count=$(grep -c "$role →" $TEST_LOG_DIR/test_communication.log)
    echo "- $role: $count メッセージ送信"
done
echo ""
echo "詳細ログ: $TEST_LOG_DIR/test_communication.log"