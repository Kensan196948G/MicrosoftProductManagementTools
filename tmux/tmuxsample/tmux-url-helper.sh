#!/bin/bash

# ITSM URL Helper Script
# 統合URL確認システム - Phase 3対応版

# 設定
FRONTEND_URL="http://192.168.3.135:3000"
BACKEND_URL="http://192.168.3.135:8081"
API_HEALTH_CHECK="${BACKEND_URL}/health"
API_DOCS="${BACKEND_URL}/api/docs"

# 色定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# tmuxペイン設定
STATUS_PANE_NAME="url-status"

# 関数: サーバー状態確認
check_server_status() {
    local url=$1
    local name=$2
    
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "$url" | grep -q "^[23]"; then
        echo -e "${GREEN}✓ ${name}: Running${NC}"
        return 0
    else
        echo -e "${RED}✗ ${name}: Not Running${NC}"
        return 1
    fi
}

# 関数: APIヘルスチェック
check_api_health() {
    local response=$(curl -s "$API_HEALTH_CHECK" 2>/dev/null)
    
    if [[ $response == *"healthy"* ]] || [[ $response == *"success"*"true"* ]]; then
        echo -e "${GREEN}✓ API Health: OK${NC}"
        # セキュリティ機能の状態も表示
        if [[ $response == *"owaspCompliance"*"active"* ]]; then
            echo -e "  ${BLUE}├─ OWASP Compliance: Active${NC}"
        fi
        if [[ $response == *"rateLimiting"*"active"* ]]; then
            echo -e "  ${BLUE}├─ Rate Limiting: Active${NC}"
        fi
        if [[ $response == *"csrfProtection"*"active"* ]]; then
            echo -e "  ${BLUE}└─ CSRF Protection: Active${NC}"
        fi
        return 0
    else
        echo -e "${RED}✗ API Health: Failed${NC}"
        return 1
    fi
}

# 関数: URLリスト表示
show_urls() {
    echo -e "\n${BLUE}=== ITSM System URLs ===${NC}"
    echo -e "${YELLOW}Frontend:${NC} $FRONTEND_URL"
    echo -e "${YELLOW}Backend API:${NC} $BACKEND_URL"
    echo -e "${YELLOW}API Docs:${NC} $API_DOCS"
    echo -e "${YELLOW}Health Check:${NC} $API_HEALTH_CHECK"
    echo ""
}

# 関数: SSH環境検出
is_ssh_session() {
    [[ -n "$SSH_CONNECTION" ]] || [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]]
}

# 関数: ブラウザ起動
open_browser() {
    local url=$1
    
    # SSH環境の場合は、ブラウザ起動をスキップしてURLを表示
    if is_ssh_session; then
        echo -e "${YELLOW}SSH接続を検出しました。${NC}"
        echo -e "${BLUE}Windowsのブラウザで以下のURLを開いてください：${NC}"
        echo -e "${GREEN}$url${NC}"
        echo ""
        echo -e "${YELLOW}ヒント: WindowsでCtrl+Cでコピーして、ブラウザのアドレスバーに貼り付けてください${NC}"
        return 0
    fi
    
    # OS検出
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        open "$url"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v xdg-open &> /dev/null; then
            xdg-open "$url"
        elif command -v firefox &> /dev/null; then
            firefox "$url"
        elif command -v google-chrome &> /dev/null; then
            google-chrome "$url"
        else
            echo -e "${RED}No browser found. Please open manually: $url${NC}"
            return 1
        fi
    else
        echo -e "${RED}Unsupported OS. Please open manually: $url${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Browser opened: $url${NC}"
}

# 関数: tmuxステータス更新
update_tmux_status() {
    local frontend_status=$(check_server_status "$FRONTEND_URL" "Frontend" &> /dev/null && echo "✓" || echo "✗")
    local backend_status=$(check_server_status "$API_HEALTH_CHECK" "Backend" &> /dev/null && echo "✓" || echo "✗")
    
    # tmuxステータスラインに表示
    tmux set -g status-right "#[fg=green]Frontend:$frontend_status #[fg=blue]Backend:$backend_status #[fg=yellow]%H:%M"
}

# 関数: リアルタイム監視
monitor_servers() {
    echo -e "${BLUE}Starting real-time monitoring... (Press Ctrl+C to stop)${NC}\n"
    
    while true; do
        clear
        echo -e "${BLUE}=== ITSM System Status ===${NC}"
        echo -e "$(date '+%Y-%m-%d %H:%M:%S')\n"
        
        check_server_status "$FRONTEND_URL" "Frontend"
        check_server_status "$API_HEALTH_CHECK" "Backend API"
        echo ""
        check_api_health
        
        update_tmux_status
        
        echo -e "\n${YELLOW}Refreshing in 10 seconds...${NC}"
        sleep 10
    done
}

# 関数: 統合起動
integrated_launch() {
    echo -e "${BLUE}=== ITSM Integrated Launch ===${NC}\n"
    
    # サーバー状態確認
    echo "Checking server status..."
    local frontend_ok=$(check_server_status "$FRONTEND_URL" "Frontend" > /dev/null 2>&1 && echo "true" || echo "false")
    local backend_ok=$(check_server_status "$API_HEALTH_CHECK" "Backend API" > /dev/null 2>&1 && echo "true" || echo "false")
    
    
    # 両方のサーバーが起動していれば、ブラウザを開く
    if [[ "$frontend_ok" == "true" && "$backend_ok" == "true" ]]; then
        echo -e "\n${GREEN}All systems operational!${NC}"
        echo "Opening browser..."
        open_browser "$FRONTEND_URL"
    else
        echo -e "\n${RED}Some services are not running.${NC}"
        echo "Please start the services first:"
        [[ "$frontend_ok" == "false" ]] && echo "  - Frontend: cd frontend && npm run dev"
        [[ "$backend_ok" == "false" ]] && echo "  - Backend: cd itsm-backend && npm start"
    fi
}

# メイン処理
main() {
    case "${1:-}" in
        "status"|"s")
            check_server_status "$FRONTEND_URL" "Frontend"
            check_server_status "$API_HEALTH_CHECK" "Backend API"
            echo ""
            check_api_health
            ;;
        "urls"|"u")
            show_urls
            ;;
        "open"|"o")
            if [ -z "$2" ]; then
                integrated_launch
            else
                case "$2" in
                    "frontend"|"f")
                        open_browser "$FRONTEND_URL"
                        ;;
                    "backend"|"b"|"api")
                        open_browser "$API_DOCS"
                        ;;
                    "health"|"h")
                        open_browser "$API_HEALTH_CHECK"
                        ;;
                    *)
                        echo "Unknown target: $2"
                        echo "Usage: $0 open [frontend|backend|health]"
                        ;;
                esac
            fi
            ;;
        "monitor"|"m")
            monitor_servers
            ;;
        "launch"|"l")
            integrated_launch
            ;;
        "help"|"h"|*)
            echo "ITSM URL Helper - Usage:"
            echo "  $0 status   - Check server status"
            echo "  $0 urls     - Show all URLs"
            echo "  $0 open     - Open frontend in browser (with status check)"
            echo "  $0 open [frontend|backend|health] - Open specific URL"
            echo "  $0 monitor  - Start real-time monitoring"
            echo "  $0 launch   - Integrated launch with status check"
            echo ""
            echo "Shortcuts:"
            echo "  s - status"
            echo "  u - urls"
            echo "  o - open"
            echo "  m - monitor"
            echo "  l - launch"
            ;;
    esac
}

# スクリプト実行
main "$@"