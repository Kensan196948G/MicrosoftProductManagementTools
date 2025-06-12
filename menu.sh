#!/bin/bash

# Microsoft製品運用管理ツール - メインメニュー
# ITSM/ISO27001/27002準拠 - 統合運用コンソール

set -e

PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
LOG_DIR="${PROJECT_ROOT}/Logs"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# メニュー表示関数
show_main_menu() {
    clear
    echo -e "${CYAN}=================================================================================${NC}"
    echo -e "${WHITE}      Microsoft製品運用管理ツール - 統合運用コンソール${NC}"
    echo -e "${WHITE}      ITSM/ISO27001/27002準拠 - 完全自動運用システム${NC}"
    echo -e "${CYAN}=================================================================================${NC}"
    echo ""
    echo -e "${GREEN}現在時刻: $(date '+%Y年%m月%d日 %H:%M:%S')${NC}"
    echo -e "${GREEN}PowerShell: $(pwsh --version 2>/dev/null || echo '未検出')${NC}"
    echo -e "${GREEN}システム状態: $(check_system_status)${NC}"
    echo ""
    echo -e "${YELLOW}【システム制御】${NC}"
    echo -e "  ${WHITE}1.${NC} システム開始 (start-all.sh)"
    echo -e "  ${WHITE}2.${NC} システム停止 (stop-all.sh)"
    echo -e "  ${WHITE}3.${NC} 自動修復ループ開始 (auto-repair.sh --daemon)"
    echo -e "  ${WHITE}4.${NC} システム再起動 (stop → start)"
    echo ""
    echo -e "${YELLOW}【診断・テスト】${NC}"
    echo -e "  ${WHITE}5.${NC} 構成整合性チェック (config-check.sh --auto)"
    echo -e "  ${WHITE}6.${NC} 包括的自動テスト (auto-test.sh --comprehensive)"
    echo -e "  ${WHITE}7.${NC} クイックテスト (quick-test.sh)"
    echo -e "  ${WHITE}8.${NC} PowerShell統合テスト (simple-test.ps1)"
    echo ""
    echo -e "${YELLOW}【レポート生成】${NC}"
    echo -e "  ${WHITE}9.${NC} 日次レポート生成"
    echo -e "  ${WHITE}10.${NC} 週次レポート生成"
    echo -e "  ${WHITE}11.${NC} 月次レポート生成"
    echo -e "  ${WHITE}12.${NC} 年次レポート生成"
    echo ""
    echo -e "${YELLOW}【Exchange Online監査】${NC}"
    echo -e "  ${WHITE}21.${NC} 自動転送・返信設定確認レポート"
    echo -e "  ${WHITE}22.${NC} 会議室リソース利用状況監査"
    echo ""
    echo -e "${YELLOW}【ログ・監査】${NC}"
    echo -e "  ${WHITE}13.${NC} ログファイル一覧表示"
    echo -e "  ${WHITE}14.${NC} 最新ログ表示 (tail -f)"
    echo -e "  ${WHITE}15.${NC} システム情報表示"
    echo -e "  ${WHITE}16.${NC} プロセス状況確認"
    echo ""
    echo -e "${YELLOW}【設定・管理】${NC}"
    echo -e "  ${WHITE}17.${NC} 設定ファイル編集 (appsettings.json)"
    echo -e "  ${WHITE}18.${NC} ディレクトリ構造表示"
    echo -e "  ${WHITE}19.${NC} システム要件確認"
    echo -e "  ${WHITE}20.${NC} 導入完了報告表示"
    echo ""
    echo -e "  ${RED}0.${NC} 終了"
    echo ""
    echo -e "${CYAN}=================================================================================${NC}"
}

# システム状態チェック
check_system_status() {
    if pgrep -f "auto-repair.sh --daemon" >/dev/null 2>&1; then
        echo -e "${GREEN}自動修復ループ稼働中${NC}"
    elif [[ -f "${LOG_DIR}/SYSTEM_STARTED_"* ]]; then
        echo -e "${YELLOW}手動開始済み${NC}"
    elif [[ -f "${LOG_DIR}/SYSTEM_STOPPED_"* ]]; then
        echo -e "${RED}停止中${NC}"
    else
        echo -e "${CYAN}初期状態${NC}"
    fi
}

# 選択実行関数
execute_selection() {
    local choice="$1"
    
    case $choice in
        1)
            echo -e "${GREEN}システムを開始しています...${NC}"
            ./start-all.sh
            ;;
        2)
            echo -e "${RED}システムを停止しています...${NC}"
            ./stop-all.sh
            ;;
        3)
            echo -e "${PURPLE}自動修復ループをバックグラウンドで開始します...${NC}"
            ./auto-repair.sh --daemon &
            echo -e "${GREEN}自動修復ループを開始しました (PID: $!)${NC}"
            ;;
        4)
            echo -e "${YELLOW}システムを再起動しています...${NC}"
            ./stop-all.sh
            sleep 3
            ./start-all.sh
            ;;
        5)
            echo -e "${BLUE}構成整合性チェックを実行します...${NC}"
            ./config-check.sh --auto --force
            ;;
        6)
            echo -e "${BLUE}包括的自動テストを実行します...${NC}"
            ./auto-test.sh --comprehensive --fix-errors --force
            ;;
        7)
            echo -e "${BLUE}クイックテストを実行します...${NC}"
            ./quick-test.sh
            ;;
        8)
            echo -e "${BLUE}PowerShell統合テストを実行します...${NC}"
            pwsh -File simple-test.ps1 -TestType Production
            ;;
        9)
            echo -e "${CYAN}日次レポートを生成します...${NC}"
            ./generate-daily-report.sh
            ;;
        10)
            echo -e "${CYAN}週次レポートを生成します...${NC}"
            ./generate-weekly-report.sh
            ;;
        11)
            echo -e "${CYAN}月次レポートを生成します...${NC}"
            ./generate-monthly-report.sh
            ;;
        12)
            echo -e "${CYAN}年次レポートを生成します...${NC}"
            ./generate-yearly-report.sh
            ;;
        13)
            echo -e "${WHITE}ログファイル一覧:${NC}"
            ls -la Logs/ 2>/dev/null || echo "ログディレクトリが見つかりません"
            ;;
        14)
            echo -e "${WHITE}最新ログをリアルタイム表示します (Ctrl+C で終了):${NC}"
            latest_log=$(ls -t Logs/*.log 2>/dev/null | head -1)
            if [[ -n "$latest_log" ]]; then
                tail -f "$latest_log"
            else
                echo "ログファイルが見つかりません"
            fi
            ;;
        15)
            echo -e "${WHITE}システム情報:${NC}"
            pwsh -Command "Import-Module './Scripts/Common/Common.psm1' -Force; Get-SystemInfo | Format-Table -AutoSize"
            ;;
        16)
            echo -e "${WHITE}プロセス状況:${NC}"
            echo "PowerShellプロセス:"
            pgrep -f "pwsh\|powershell" | wc -l | xargs echo "  実行中: "
            echo "自動修復ループ:"
            if pgrep -f "auto-repair.sh --daemon" >/dev/null; then
                echo "  ✅ 稼働中"
            else
                echo "  ❌ 停止中"
            fi
            ;;
        17)
            echo -e "${YELLOW}設定ファイルを編集します...${NC}"
            echo -e "${WHITE}編集方法を選択してください:${NC}"
            echo -e "  ${GREEN}1.${NC} Vim/Viスタイル編集（推奨・解説付き）"
            echo -e "  ${GREEN}2.${NC} 標準エディター（nano等）"
            echo -e "${WHITE}選択 (1-2): ${NC}"
            read -r editor_choice
            case $editor_choice in
                1) ./edit-config-vim.sh ;;
                2) ${EDITOR:-nano} Config/appsettings.json ;;
                *) echo -e "${RED}無効な選択です${NC}" ;;
            esac
            ;;
        18)
            echo -e "${WHITE}ディレクトリ構造:${NC}"
            tree . -L 3 2>/dev/null || find . -type d -maxdepth 3 | sort
            ;;
        19)
            echo -e "${WHITE}システム要件確認:${NC}"
            echo "PowerShell: $(pwsh --version 2>/dev/null || echo '❌ 未インストール')"
            echo "OS: $(uname -s) $(uname -r)"
            echo "Python: $(python3 --version 2>/dev/null || echo '❌ 未インストール')"
            echo "空き容量: $(df -h . | tail -1 | awk '{print $4}')"
            ;;
        20)
            echo -e "${CYAN}導入完了報告を表示します...${NC}"
            if [[ -f "deployment-summary.md" ]]; then
                cat deployment-summary.md
            else
                echo "導入完了報告ファイルが見つかりません"
            fi
            ;;
        21)
            echo -e "${YELLOW}🔄 Exchange Online自動転送・返信設定確認レポートを生成します...${NC}"
            echo -e "${WHITE}このレポートは以下を確認します:${NC}"
            echo -e "  • メールボックスの自動転送設定"
            echo -e "  • 自動応答（不在通知）設定"
            echo -e "  • インボックスルールによる転送"
            echo -e "  • 外部ドメインへの転送（セキュリティリスク）"
            echo ""
            echo -e "${CYAN}実行中... しばらくお待ちください${NC}"
            ./generate-exchange-forwarding-report.sh
            ;;
        22)
            echo -e "${YELLOW}🏢 Exchange Online会議室リソース利用状況監査を実行します...${NC}"
            echo -e "${WHITE}この監査では以下を分析します:${NC}"
            echo -e "  • 各会議室の利用率計算（過去7日間）"
            echo -e "  • 高負荷・低稼働・未使用会議室の特定"
            echo -e "  • ピーク時間帯の分析"
            echo -e "  • 会議室予約ポリシーの確認"
            echo -e "  • 利用改善の推奨アクション"
            echo ""
            echo -e "${CYAN}実行中... しばらくお待ちください${NC}"
            pwsh -Command "Import-Module Scripts/Common/Common.psm1; Import-Module Scripts/EXO/SecurityAnalysis.ps1; Get-EXORoomResourceAudit"
            ;;
        0)
            echo -e "${GREEN}Microsoft製品運用管理ツールを終了します。${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}無効な選択です。1-22または0を入力してください。${NC}"
            ;;
    esac
}

# メインループ
main_loop() {
    while true; do
        show_main_menu
        echo -e "${WHITE}選択してください (1-22, 0=終了): ${NC}"
        read -r choice
        
        echo ""
        execute_selection "$choice"
        
        echo ""
        echo -e "${YELLOW}Enterキーを押して続行...${NC}"
        read -r
    done
}

# スクリプト開始
cd "$PROJECT_ROOT"
echo -e "${GREEN}Microsoft製品運用管理ツール メニューシステムを起動中...${NC}"
sleep 1

main_loop