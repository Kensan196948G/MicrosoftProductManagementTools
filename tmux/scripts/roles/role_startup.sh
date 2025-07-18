#!/bin/bash
# 役割別起動スクリプト
# Version: 2.0
# Date: 2025-01-17

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
ROLE_DEF_FILE="$TMUX_DIR/roles/role_definitions.json"
MESSAGE_SYSTEM="$TMUX_DIR/collaboration/messaging_system.sh"

# メッセージングシステムを読み込み
if [ -f "$MESSAGE_SYSTEM" ]; then
    source "$MESSAGE_SYSTEM"
fi

# 役割情報を取得（jqが無い場合の簡易実装）
get_role_info() {
    local role=$1
    local field=$2
    
    # 簡易的なJSON解析
    case $role in
        "CTO")
            case $field in
                "title") echo "Chief Technology Officer" ;;
                "startup_message") echo "CTO として技術戦略を統括します。本日の技術目標:\n1. アーキテクチャの最適化\n2. コード品質の向上\n3. 技術的負債の削減\n4. チームの技術力向上" ;;
            esac
            ;;
        "Manager")
            case $field in
                "title") echo "Project Manager" ;;
                "startup_message") echo "Project Manager として開発チームを調整します。本日の管理目標:\n1. スプリント進捗の確認\n2. ブロッカーの解消\n3. チーム生産性の最適化\n4. ステークホルダー報告の準備" ;;
            esac
            ;;
        "Developer")
            case $field in
                "title") echo "Full Stack Developer" ;;
                "startup_message") echo "Developer として高品質なコードを実装します。本日の開発目標:\n1. 機能実装の完了\n2. コードレビューの実施\n3. テストカバレッジの向上\n4. ドキュメントの更新" ;;
            esac
            ;;
    esac
}

# 役割宣言関数
declare_role() {
    local role=$1
    local sub_role=$2
    local title=$(get_role_info "$role" "title")
    local startup_msg=$(get_role_info "$role" "startup_message")
    
    # ヘッダー表示
    echo -e "${CYAN}================================================${NC}"
    echo -e "${YELLOW}🎯 役割宣言${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
    
    # 役割情報表示
    echo -e "${GREEN}役割: ${title}${NC}"
    if [ -n "$sub_role" ]; then
        echo -e "${GREEN}専門分野: ${sub_role}${NC}"
    fi
    echo -e "${BLUE}開始時刻: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""
    
    # スタートアップメッセージ
    echo -e "${YELLOW}=== 本日の目標 ===${NC}"
    echo -e "$startup_msg"
    echo ""
    
    # 初期ステータス送信
    update_status "$role" "起動完了" "$title として業務を開始します"
    
    # 役割別の追加処理
    case $role in
        "CTO")
            echo -e "${CYAN}=== 技術リーダーシップ ===${NC}"
            echo "• 技術的意思決定の責任者"
            echo "• アーキテクチャの最終承認権限"
            echo "• チーム技術力向上の推進者"
            echo ""
            # CTOコマンドメニューへの案内
            echo -e "${YELLOW}技術戦略コマンド: ./cto_strategic_command.sh${NC}"
            ;;
        "Manager")
            echo -e "${CYAN}=== プロジェクト管理 ===${NC}"
            echo "• チーム調整とタスク管理"
            echo "• 進捗モニタリングと報告"
            echo "• リソース最適化"
            echo ""
            # Managerコマンドメニューへの案内
            echo -e "${YELLOW}調整コマンド: ./manager_coordination.sh${NC}"
            ;;
        "Developer")
            echo -e "${CYAN}=== 開発責任 ===${NC}"
            echo "• 高品質なコード実装"
            echo "• テスト駆動開発"
            echo "• 継続的改善"
            echo ""
            if [ -n "$sub_role" ]; then
                case $sub_role in
                    "Dev0")
                        echo -e "${GREEN}Dev0 - Frontend専門:${NC}"
                        echo "• React/Vue.js でのUI実装"
                        echo "• レスポンシブデザイン"
                        echo "• ユーザビリティ最適化"
                        ;;
                    "Dev1")
                        echo -e "${GREEN}Dev1 - Backend専門:${NC}"
                        echo "• Node.js/Express API開発"
                        echo "• データベース設計"
                        echo "• パフォーマンス最適化"
                        ;;
                    "Dev2")
                        echo -e "${GREEN}Dev2 - Test/QA専門:${NC}"
                        echo "• 自動テスト実装"
                        echo "• セキュリティ検証"
                        echo "• 品質保証プロセス"
                        echo "• 手動テスト実施"
                        echo "• ユーザビリティ検証"
                        ;;
                    "frontend")
                        echo -e "${GREEN}Frontend 専門:${NC}"
                        echo "• React/Vue.js でのUI実装"
                        echo "• レスポンシブデザイン"
                        echo "• ユーザビリティ最適化"
                        ;;
                    "backend")
                        echo -e "${GREEN}Backend 専門:${NC}"
                        echo "• Node.js/Express API開発"
                        echo "• データベース設計"
                        echo "• パフォーマンス最適化"
                        ;;
                    "test")
                        echo -e "${GREEN}Test/QA 専門:${NC}"
                        echo "• 自動テスト実装"
                        echo "• セキュリティ検証"
                        echo "• 品質保証プロセス"
                        ;;
                    "validation")
                        echo -e "${GREEN}Validation 専門:${NC}"
                        echo "• 手動テスト実施"
                        echo "• ユーザビリティ検証"
                        echo "• ドキュメント作成"
                        ;;
                esac
            fi
            ;;
    esac
    
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${GREEN}✅ 役割宣言完了 - 業務開始${NC}"
    echo -e "${CYAN}================================================${NC}"
}

# コマンドライン引数処理
if [ $# -eq 0 ]; then
    echo "使用方法: $0 <role> [sub_role]"
    echo "役割: CTO, Manager, Developer"
    echo "サブ役割 (Developer用): Dev0, Dev1, Dev2, frontend, backend, test, validation"
    exit 1
fi

ROLE=$1
SUB_ROLE=$2

# 役割宣言実行
declare_role "$ROLE" "$SUB_ROLE"

# 役割別の初期化処理（Claude実起動）
case $ROLE in
    "CTO")
        # CTO用Claude起動
        if [ -f "$TMUX_DIR/claude_auto.sh" ]; then
            echo ""
            echo -e "${YELLOW}CTO用Claude を起動しています...${NC}"
            echo -e "${BLUE}tmuxウィンドウでClaude起動中...${NC}"
            # 現在のペインで直接Claude起動
            echo -e "${CYAN}現在のペインでClaude起動中...${NC}"
            cd "$TMUX_DIR"
            ./claude_auto.sh 'CTO として技術戦略を管理します。アーキテクチャ最適化と技術的負債削減に注力してください。'
            echo -e "${GREEN}✅ CTO用Claude起動完了${NC}"
            else
                echo -e "${YELLOW}tmuxセッションが見つかりません。手動でClaude起動してください:${NC}"
                echo "./claude_auto.sh 'CTO として技術戦略を管理します。'"
            fi
        fi
        ;;
    "Manager")
        # Manager用Claude起動
        if [ -f "$TMUX_DIR/claude_auto.sh" ]; then
            echo ""
            echo -e "${YELLOW}Manager用Claude を起動しています...${NC}"
            echo -e "${BLUE}tmuxウィンドウでClaude起動中...${NC}"
            # 現在のペインで直接Claude起動
            echo -e "${CYAN}現在のペインでClaude起動中...${NC}"
            cd "$TMUX_DIR"
            ./claude_auto.sh 'Project Manager として開発チームを調整し、プロジェクト管理を行います。進捗監視とタスク調整に注力してください。'
            echo -e "${GREEN}✅ Manager用Claude起動完了${NC}"
            else
                echo -e "${YELLOW}tmuxセッションが見つかりません。手動でClaude起動してください:${NC}"
                echo "./claude_auto.sh 'Project Manager として開発チームを調整し、プロジェクト管理を行います。'"
            fi
        fi
        ;;
    "Developer")
        # Developer用Claude起動
        if [ -f "$TMUX_DIR/claude_auto.sh" ] && [ -n "$SUB_ROLE" ]; then
            echo ""
            echo -e "${YELLOW}${SUB_ROLE} Developer用Claude を起動しています...${NC}"
            echo -e "${BLUE}tmuxウィンドウでClaude起動中...${NC}"
            case $SUB_ROLE in
                "Dev0") prompt="Dev0 - Frontend Developer として React/Vue.js の実装を行います。UI/UX とレスポンシブデザインに注力してください。" ;;
                "Dev1") prompt="Dev1 - Backend Developer として Node.js/Express の実装を行います。API設計とデータベース最適化に注力してください。" ;;
                "Dev2") prompt="Dev2 - Test/QA Developer として自動テストとセキュリティ検証を行います。品質保証とテストカバレッジ向上に注力してください。" ;;
                "frontend") prompt="Frontend Developer として React/Vue.js の実装を行います。UI/UX とレスポンシブデザインに注力してください。" ;;
                "backend") prompt="Backend Developer として Node.js/Express の実装を行います。API設計とデータベース最適化に注力してください。" ;;
                "test") prompt="Test/QA Developer として自動テストとセキュリティ検証を行います。品質保証とテストカバレッジ向上に注力してください。" ;;
                "validation") prompt="Validation Developer として手動テストと品質保証を行います。ユーザビリティと受け入れテストに注力してください。" ;;
            esac
            # 現在のペインで直接Claude起動
            echo -e "${CYAN}現在のペインでClaude起動中...${NC}"
            cd "$TMUX_DIR"
            ./claude_auto.sh "$prompt"
            echo -e "${GREEN}✅ ${SUB_ROLE} Developer用Claude起動完了${NC}"
            else
                echo -e "${YELLOW}tmuxセッションが見つかりません。手動でClaude起動してください:${NC}"
                echo "./claude_auto.sh '$prompt'"
            fi
        fi
        ;;
esac