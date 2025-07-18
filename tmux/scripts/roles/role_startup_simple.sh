#!/bin/bash
# 役割別起動スクリプト（Claudeなし版）
# Version: 1.0
# Date: 2025-07-17

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# パス設定
TMUX_DIR="$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")"

# 役割情報を取得
get_role_info() {
    local role=$1
    local field=$2
    
    case $role in
        "CTO")
            case $field in
                "title") echo "Chief Technology Officer" ;;
                "startup_message") echo "CTO として技術戦略を統括します。\n技術的意思決定の責任者" ;;
            esac
            ;;
        "Manager")
            case $field in
                "title") echo "Project Manager" ;;
                "startup_message") echo "Project Manager として開発チームを調整します。\nタスク管理と進捗監視" ;;
            esac
            ;;
        "Developer")
            case $field in
                "title") echo "Developer" ;;
                "startup_message") echo "Developer として高品質なコードを実装します。" ;;
            esac
            ;;
    esac
}

# 役割宣言関数（シンプル版）
declare_role_simple() {
    local role=$1
    local sub_role=$2
    local title=$(get_role_info "$role" "title")
    local startup_msg=$(get_role_info "$role" "startup_message")
    
    clear
    
    # 役割別アイコンと名前設定
    local icon=""
    local display_name=""
    
    case $role in
        "CTO")
            icon="👔"
            display_name="CTO - Chief Technology Officer"
            ;;
        "Manager")
            icon="📋"
            display_name="Manager - Project Manager"
            ;;
        "Developer")
            case $sub_role in
                "Dev0")
                    icon="🎨"
                    display_name="Developer 0 - Frontend"
                    ;;
                "Dev1")
                    icon="🔧"
                    display_name="Developer 1 - Backend"
                    ;;
                "Dev2")
                    icon="🧪"
                    display_name="Developer 2 - Test/QA"
                    ;;
                *)
                    icon="💻"
                    display_name="Developer"
                    ;;
            esac
            ;;
    esac
    
    # ヘッダー表示
    echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${icon} ${YELLOW}${display_name}${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "$startup_msg"
    echo ""
    
    # 役割別のサブ情報
    if [ "$role" = "Developer" ] && [ -n "$sub_role" ]; then
        case $sub_role in
            "Dev0")
                echo -e "${GREEN}Frontend 開発担当${NC}"
                echo "• React/Vue.js UI実装"
                ;;
            "Dev1")
                echo -e "${GREEN}Backend 開発担当${NC}"
                echo "• Node.js/Express API開発"
                ;;
            "Dev2")
                echo -e "${GREEN}Test/QA 担当${NC}"
                echo "• 自動テスト・品質保証"
                ;;
        esac
        echo ""
    fi
    
    # コマンド案内
    echo -e "${YELLOW}=== 利用可能なコマンド ===${NC}"
    echo "• Claude起動: cd $TMUX_DIR && ./claude_auto.sh"
    echo "• Manager調整: $TMUX_DIR/manager_coordination.sh"
    echo ""
    
    # 作業ディレクトリ表示
    echo -e "${BLUE}作業ディレクトリ: $(pwd)${NC}"
    echo ""
}

# Claude自動起動関数
auto_start_claude() {
    local role=$1
    local sub_role=$2
    local prompt=""
    
    case $role in
        "CTO")
            prompt="日本語で解説・対応してください。CTO として Microsoft 365 API 統合方針と PowerShell 7.5.1 移行戦略を管理します。コーディング規約、セキュリティポリシーの策定、アーキテクチャとリリースの最終承認に注力してください。"
            ;;
        "Manager")
            prompt="日本語で解説・対応してください。Project Manager として Microsoft 365 統合管理ツールの開発を管理します。26機能の実装スケジュール管理、タスク配分、依存関係管理、コードレビューとテスト結果の監視に注力してください。"
            ;;
        "Developer")
            case $sub_role in
                "Dev0")
                    prompt="日本語で解説・対応してください。Dev0 - Frontend Developer として PowerShell Windows Forms GUI の実装を行います。26機能のボタン配置、リアルタイムログ表示、ポップアップ通知の実装に注力し、GuiApp_Enhanced.ps1 を担当してください。"
                    ;;
                "Dev1")
                    prompt="日本語で解説・対応してください。Dev1 - Backend Developer として Microsoft Graph API と Exchange Online PowerShell の統合を行います。RealM365DataProvider.psm1 のデータ処理と Authentication.psm1 の認証システム実装に注力してください。"
                    ;;
                "Dev2")
                    prompt="日本語で解説・対応してください。Dev2 - Test/QA Developer として Pester フレームワークによる自動テストを実装します。80%以上のテストカバレッジ達成、セキュリティスキャン、パフォーマンステスト、ISO/IEC 27001準拠確認に注力してください。"
                    ;;
            esac
            ;;
    esac
    
    if [ -n "$prompt" ]; then
        echo ""
        echo -e "${CYAN}=== Claude自動起動中... ===${NC}"
        echo ""
        echo -e "${YELLOW}日本語対応プロンプトが設定されています${NC}"
        echo "役割: $role $([ -n "$sub_role" ] && echo "- $sub_role")"
        echo ""
        echo "=========================================="
        echo ""
        
        # 作業ディレクトリをルートに変更
        cd "/mnt/e/MicrosoftProductManagementTools"
        
        # Claudeを起動
        claude --dangerously-skip-permissions
    fi
}

# コマンドライン引数処理
if [ $# -eq 0 ]; then
    echo "使用方法: $0 <role> [sub_role]"
    echo "役割: CTO, Manager, Developer"
    echo "サブ役割: Dev0, Dev1, Dev2"
    exit 1
fi

ROLE=$1
SUB_ROLE=$2

# 役割宣言実行
declare_role_simple "$ROLE" "$SUB_ROLE"

# Claude自動起動
auto_start_claude "$ROLE" "$SUB_ROLE"