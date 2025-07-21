#!/bin/bash

# UI Development Loop Automation Script
# 統合URL確認システムと連携したUI開発ループ自動化

# 色定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 設定
FRONTEND_PORT=3000
BACKEND_PORT=8081
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ログファイル
LOG_FILE="$SCRIPT_DIR/logs/ui-dev-loop.log"
mkdir -p "$SCRIPT_DIR/logs"

# ログ関数
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ヘッダー表示
show_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          UI Development Loop Controller            ║${NC}"
    echo -e "${CYAN}║        統合URL確認システム連携 - Phase 3対応        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Step 1: 環境準備・サーバー状態確認
check_environment() {
    log "${BLUE}=== Step 1: 環境準備・サーバー状態確認 ===${NC}"
    
    # Node.js確認
    if ! command -v node &> /dev/null; then
        log "${RED}✗ Node.js not installed${NC}"
        return 1
    fi
    log "${GREEN}✓ Node.js: $(node -v)${NC}"
    
    # npm確認
    if ! command -v npm &> /dev/null; then
        log "${RED}✗ npm not installed${NC}"
        return 1
    fi
    log "${GREEN}✓ npm: $(npm -v)${NC}"
    
    # tmux-url-helper.sh確認
    if [ -f "$SCRIPT_DIR/tmux-url-helper.sh" ]; then
        log "${GREEN}✓ tmux-url-helper.sh available${NC}"
        # サーバー状態確認
        "$SCRIPT_DIR/tmux-url-helper.sh" status
    else
        log "${YELLOW}⚠ tmux-url-helper.sh not found${NC}"
    fi
    
    return 0
}

# Step 2: サーバー起動
start_servers() {
    log "${BLUE}=== Step 2: サーバー起動 ===${NC}"
    
    # Backend起動確認
    if ! curl -s -o /dev/null "http://localhost:$BACKEND_PORT/health"; then
        log "${YELLOW}Starting backend server...${NC}"
        cd "$PROJECT_ROOT/itsm-backend" && npm start &
        BACKEND_PID=$!
        sleep 5
    else
        log "${GREEN}✓ Backend already running on port $BACKEND_PORT${NC}"
    fi
    
    # Frontend起動確認
    if ! curl -s -o /dev/null "http://localhost:$FRONTEND_PORT"; then
        log "${YELLOW}Starting frontend server...${NC}"
        cd "$PROJECT_ROOT/frontend" && npm run dev &
        FRONTEND_PID=$!
        sleep 5
    else
        log "${GREEN}✓ Frontend already running on port $FRONTEND_PORT${NC}"
    fi
    
    # 起動待機
    log "${YELLOW}Waiting for servers to initialize...${NC}"
    sleep 3
    
    # 最終確認
    "$SCRIPT_DIR/tmux-url-helper.sh" status
}

# Step 3: ブラウザ起動・URL確認
open_browsers() {
    log "${BLUE}=== Step 3: ブラウザ起動・URL確認 ===${NC}"
    
    # 統合起動
    if [ -f "$SCRIPT_DIR/tmux-url-helper.sh" ]; then
        "$SCRIPT_DIR/tmux-url-helper.sh" launch
    fi
    
    # Edge/Chrome確認メッセージ
    log "${CYAN}Please check in both browsers:${NC}"
    log "- Microsoft Edge"
    log "- Google Chrome"
    log "- Frontend: http://localhost:$FRONTEND_PORT"
    log "- Backend API: http://localhost:$BACKEND_PORT/api/docs"
}

# Step 4: UI品質チェック
run_ui_checks() {
    log "${BLUE}=== Step 4: UI品質チェック ===${NC}"
    
    # tmux-ui-panel.sh確認
    if [ -f "$SCRIPT_DIR/tmux-ui-panel.sh" ]; then
        log "${GREEN}✓ UI Panel available for quality checks${NC}"
        echo -e "${CYAN}Press 'p' to open UI Panel for detailed checks${NC}"
    fi
    
    # 基本チェック項目表示
    echo ""
    echo -e "${YELLOW}=== 建設業界特化UI確認項目 ===${NC}"
    echo "[ ] 現場作業者向け: 大きなボタン（44px以上）"
    echo "[ ] 屋外視認性: 高コントラスト（7:1以上）"
    echo "[ ] タッチ操作: 適切なタップ領域"
    echo "[ ] 安全性: 重要操作の二重確認"
    echo "[ ] オフライン: Service Worker動作"
    echo ""
    echo -e "${YELLOW}=== Phase 3 AI統合確認項目 ===${NC}"
    echo "[ ] AI応答時間: < 500ms"
    echo "[ ] 予測精度: > 85%"
    echo "[ ] リアルタイム更新: WebSocket接続"
    echo "[ ] 自然言語UI: 日本語入力対応"
}

# Step 5: 修正対応
handle_modifications() {
    log "${BLUE}=== Step 5: 修正対応 ===${NC}"
    
    echo -e "${CYAN}修正が必要な場合:${NC}"
    echo "1. Frontend修正: $PROJECT_ROOT/frontend/src/"
    echo "2. Backend修正: $PROJECT_ROOT/itsm-backend/src/"
    echo "3. ホットリロードで自動反映"
    echo ""
    echo -e "${YELLOW}修正後は自動的に画面が更新されます${NC}"
}

# Step 6: 継続監視
continuous_monitoring() {
    log "${BLUE}=== Step 6: 継続監視 ===${NC}"
    
    echo -e "${CYAN}監視オプション:${NC}"
    echo "m - リアルタイム監視開始"
    echo "s - サーバー状態確認"
    echo "p - UIパネル起動"
    echo "r - サーバー再起動"
    echo "q - 終了"
}

# メインループ
main_loop() {
    while true; do
        echo ""
        echo -e "${MAGENTA}=== UI Development Loop Menu ===${NC}"
        echo "1. 環境確認"
        echo "2. サーバー起動"
        echo "3. ブラウザ起動"
        echo "4. UI品質チェック"
        echo "5. 修正対応"
        echo "6. 継続監視"
        echo "a. 自動実行（1-6全て）"
        echo "m. モニタリング開始"
        echo "p. UIパネル起動"
        echo "s. ステータス確認"
        echo "q. 終了"
        echo ""
        read -p "選択してください: " choice
        
        case $choice in
            1) check_environment ;;
            2) start_servers ;;
            3) open_browsers ;;
            4) run_ui_checks ;;
            5) handle_modifications ;;
            6) continuous_monitoring ;;
            a)
                check_environment && \
                start_servers && \
                open_browsers && \
                run_ui_checks && \
                handle_modifications && \
                continuous_monitoring
                ;;
            m)
                if [ -f "$SCRIPT_DIR/tmux-url-helper.sh" ]; then
                    "$SCRIPT_DIR/tmux-url-helper.sh" monitor
                fi
                ;;
            p)
                if [ -f "$SCRIPT_DIR/tmux-ui-panel.sh" ]; then
                    "$SCRIPT_DIR/tmux-ui-panel.sh" panel
                fi
                ;;
            s)
                if [ -f "$SCRIPT_DIR/tmux-url-helper.sh" ]; then
                    "$SCRIPT_DIR/tmux-url-helper.sh" status
                fi
                ;;
            q)
                log "${GREEN}UI Development Loop ended${NC}"
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# クリーンアップ
cleanup() {
    log "${YELLOW}Cleaning up...${NC}"
    
    # サーバー停止確認
    if [ ! -z "$BACKEND_PID" ]; then
        kill $BACKEND_PID 2>/dev/null
    fi
    if [ ! -z "$FRONTEND_PID" ]; then
        kill $FRONTEND_PID 2>/dev/null
    fi
}

# トラップ設定
trap cleanup EXIT

# メイン実行
main() {
    show_header
    log "${GREEN}🚀 UI Development Loop Controller Started${NC}"
    log "Frontend: http://localhost:$FRONTEND_PORT"
    log "Backend: http://localhost:$BACKEND_PORT"
    log ""
    
    # 引数処理
    case "${1:-}" in
        "auto"|"a")
            check_environment && \
            start_servers && \
            open_browsers && \
            run_ui_checks
            ;;
        "monitor"|"m")
            "$SCRIPT_DIR/tmux-url-helper.sh" monitor
            ;;
        "status"|"s")
            "$SCRIPT_DIR/tmux-url-helper.sh" status
            ;;
        "help"|"h")
            echo "Usage: $0 [auto|monitor|status|help]"
            echo "  auto    - 自動実行モード"
            echo "  monitor - 継続監視モード"
            echo "  status  - ステータス確認"
            echo "  help    - ヘルプ表示"
            echo ""
            echo "対話モードで起動する場合は引数なしで実行"
            ;;
        *)
            main_loop
            ;;
    esac
}

# スクリプト実行
main "$@"