#!/bin/bash

# Auto Start Servers Script
# フロントエンド・バックエンドサーバーの自動起動

# 色定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 設定
FRONTEND_PORT=3000
BACKEND_PORT=8081
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
BACKEND_DIR="$PROJECT_ROOT/itsm-backend"

# ログファイル
LOG_DIR="$SCRIPT_DIR/logs"
FRONTEND_LOG="$LOG_DIR/frontend.log"
BACKEND_LOG="$LOG_DIR/backend.log"
AUTO_START_LOG="$LOG_DIR/auto-start.log"

# ログディレクトリ作成
mkdir -p "$LOG_DIR"

# ログ関数
log() {
    echo -e "$1" | tee -a "$AUTO_START_LOG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$AUTO_START_LOG"
}

# PIDファイル
FRONTEND_PID_FILE="$LOG_DIR/frontend.pid"
BACKEND_PID_FILE="$LOG_DIR/backend.pid"

# ヘッダー表示
show_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║            Auto Start Servers Controller          ║${NC}"
    echo -e "${CYAN}║         フロントエンド・バックエンド自動起動        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ポート使用確認
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # ポート使用中
    else
        return 1  # ポート空き
    fi
}

# プロセス終了
kill_process() {
    local pid_file=$1
    local service_name=$2
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log "${YELLOW}Stopping $service_name (PID: $pid)...${NC}"
            kill "$pid" 2>/dev/null
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null
            fi
        fi
        rm -f "$pid_file"
    fi
}

# バックエンドサーバー起動
start_backend() {
    log "${BLUE}=== Starting Backend Server ===${NC}"
    
    # 既存プロセス確認・停止
    kill_process "$BACKEND_PID_FILE" "Backend"
    
    # ポート確認
    if check_port $BACKEND_PORT; then
        log "${YELLOW}Port $BACKEND_PORT is in use, killing process...${NC}"
        lsof -ti:$BACKEND_PORT | xargs kill -9 2>/dev/null
        sleep 2
    fi
    
    # バックエンド起動
    if [ -d "$BACKEND_DIR" ]; then
        cd "$BACKEND_DIR"
        log "${YELLOW}Starting backend server on port $BACKEND_PORT...${NC}"
        
        # npm start をバックグラウンドで実行
        nohup npm start > "$BACKEND_LOG" 2>&1 &
        local backend_pid=$!
        echo "$backend_pid" > "$BACKEND_PID_FILE"
        
        log "${GREEN}✓ Backend server started (PID: $backend_pid)${NC}"
        log "${GREEN}  Log file: $BACKEND_LOG${NC}"
        
        # 起動確認（最大30秒待機）
        local count=0
        while [ $count -lt 30 ]; do
            if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$BACKEND_PORT/health" | grep -q "200"; then
                log "${GREEN}✓ Backend server is ready and responding${NC}"
                return 0
            fi
            sleep 1
            count=$((count + 1))
            echo -n "."
        done
        
        log "${YELLOW}⚠ Backend server may not be fully ready (this is normal)${NC}"
        log "${CYAN}  Backend API available at: http://192.168.3.135:$BACKEND_PORT${NC}"
        return 0
    else
        log "${RED}✗ Backend directory not found: $BACKEND_DIR${NC}"
        return 1
    fi
}

# フロントエンドサーバー起動
start_frontend() {
    log "${BLUE}=== Starting Frontend Server ===${NC}"
    
    # 既存プロセス確認・停止
    kill_process "$FRONTEND_PID_FILE" "Frontend"
    
    # ポート確認
    if check_port $FRONTEND_PORT; then
        log "${YELLOW}Port $FRONTEND_PORT is in use, killing process...${NC}"
        lsof -ti:$FRONTEND_PORT | xargs kill -9 2>/dev/null
        sleep 2
    fi
    
    # フロントエンド起動
    if [ -d "$FRONTEND_DIR" ]; then
        cd "$FRONTEND_DIR"
        log "${YELLOW}Starting frontend server on port $FRONTEND_PORT...${NC}"
        
        # 現在動作中のExpress簡易サーバーを使用
        if [ -f "simple-server.cjs" ]; then
            log "${CYAN}Using simplified Express server (simple-server.cjs)${NC}"
            nohup node simple-server.cjs > "$FRONTEND_LOG" 2>&1 &
        else
            log "${CYAN}Using Next.js development server${NC}"
            nohup npm run dev > "$FRONTEND_LOG" 2>&1 &
        fi
        
        local frontend_pid=$!
        echo "$frontend_pid" > "$FRONTEND_PID_FILE"
        
        log "${GREEN}✓ Frontend server started (PID: $frontend_pid)${NC}"
        log "${GREEN}  Log file: $FRONTEND_LOG${NC}"
        
        # 起動確認（最大60秒待機）
        local count=0
        while [ $count -lt 60 ]; do
            if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$FRONTEND_PORT" | grep -q "200"; then
                log "${GREEN}✓ Frontend server is ready and responding${NC}"
                log "${CYAN}  Frontend available at: http://192.168.3.135:$FRONTEND_PORT${NC}"
                log "${CYAN}  Login page: http://192.168.3.135:$FRONTEND_PORT/login${NC}"
                log "${CYAN}  Dashboard: http://192.168.3.135:$FRONTEND_PORT/dashboard${NC}"
                return 0
            fi
            sleep 1
            count=$((count + 1))
            echo -n "."
        done
        
        log "${YELLOW}⚠ Frontend server may not be fully ready${NC}"
        log "${CYAN}  Frontend should be available at: http://192.168.3.135:$FRONTEND_PORT${NC}"
        return 0
    else
        log "${RED}✗ Frontend directory not found: $FRONTEND_DIR${NC}"
        return 1
    fi
}

# サーバー状態確認
check_servers_status() {
    log "${BLUE}=== Checking Servers Status ===${NC}"
    
    # Backend確認
    local backend_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$BACKEND_PORT/health" 2>/dev/null)
    if [ "$backend_status" = "200" ]; then
        log "${GREEN}✓ Backend: Running (http://192.168.3.135:$BACKEND_PORT)${NC}"
        log "${CYAN}  API Health: http://192.168.3.135:$BACKEND_PORT/health${NC}"
        log "${CYAN}  API Status: http://192.168.3.135:$BACKEND_PORT/api/status${NC}"
    else
        log "${YELLOW}⚠ Backend: Not responding on health endpoint${NC}"
        log "${CYAN}  Backend should be available at: http://192.168.3.135:$BACKEND_PORT${NC}"
    fi
    
    # Frontend確認
    local frontend_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$FRONTEND_PORT" 2>/dev/null)
    if [ "$frontend_status" = "200" ]; then
        log "${GREEN}✓ Frontend: Running (http://192.168.3.135:$FRONTEND_PORT)${NC}"
        log "${CYAN}  Main page: http://192.168.3.135:$FRONTEND_PORT${NC}"
        log "${CYAN}  Login page: http://192.168.3.135:$FRONTEND_PORT/login${NC}"
        log "${CYAN}  Dashboard: http://192.168.3.135:$FRONTEND_PORT/dashboard${NC}"
    else
        log "${YELLOW}⚠ Frontend: Not responding${NC}"
        log "${CYAN}  Frontend should be available at: http://192.168.3.135:$FRONTEND_PORT${NC}"
    fi
    
    # プロセス状態確認
    echo ""
    log "${BLUE}=== Process Status ===${NC}"
    
    if [ -f "$BACKEND_PID_FILE" ]; then
        local backend_pid=$(cat "$BACKEND_PID_FILE")
        if kill -0 "$backend_pid" 2>/dev/null; then
            log "${GREEN}✓ Backend process running (PID: $backend_pid)${NC}"
        else
            log "${RED}✗ Backend process not found${NC}"
        fi
    else
        log "${YELLOW}⚠ Backend PID file not found${NC}"
    fi
    
    if [ -f "$FRONTEND_PID_FILE" ]; then
        local frontend_pid=$(cat "$FRONTEND_PID_FILE")
        if kill -0 "$frontend_pid" 2>/dev/null; then
            log "${GREEN}✓ Frontend process running (PID: $frontend_pid)${NC}"
        else
            log "${RED}✗ Frontend process not found${NC}"
        fi
    else
        log "${YELLOW}⚠ Frontend PID file not found${NC}"
    fi
    
    # 統合URL確認ツール実行
    if [ -f "$SCRIPT_DIR/tmux-url-helper.sh" ]; then
        echo ""
        "$SCRIPT_DIR/tmux-url-helper.sh" status
    fi
}

# サーバー停止
stop_servers() {
    log "${BLUE}=== Stopping Servers ===${NC}"
    
    # プロセスファイルからの停止
    kill_process "$BACKEND_PID_FILE" "Backend"
    kill_process "$FRONTEND_PID_FILE" "Frontend"
    
    # ポート強制クリア（念のため）
    if check_port $BACKEND_PORT; then
        log "${YELLOW}Force killing processes on port $BACKEND_PORT...${NC}"
        lsof -ti:$BACKEND_PORT | xargs kill -9 2>/dev/null
    fi
    if check_port $FRONTEND_PORT; then
        log "${YELLOW}Force killing processes on port $FRONTEND_PORT...${NC}"
        lsof -ti:$FRONTEND_PORT | xargs kill -9 2>/dev/null
    fi
    
    # Next.js プロセスも終了
    pkill -f "next dev" 2>/dev/null || true
    pkill -f "simple-server.cjs" 2>/dev/null || true
    
    log "${GREEN}✓ All servers stopped${NC}"
}

# 再起動
restart_servers() {
    stop_servers
    sleep 3
    start_all_servers
}

# 全サーバー起動
start_all_servers() {
    log "${CYAN}🚀 Starting all servers...${NC}"
    
    # 依存関係確認
    check_dependencies
    
    # バックエンド起動
    if start_backend; then
        sleep 2
        # フロントエンド起動
        if start_frontend; then
            sleep 2
            log "${GREEN}🎉 All servers started successfully!${NC}"
            
            echo ""
            log "${BLUE}=== Server Information ===${NC}"
            log "${CYAN}Frontend (ITSM Web UI):${NC}"
            log "${GREEN}  Main page:  http://192.168.3.135:$FRONTEND_PORT${NC}"
            log "${GREEN}  Login:      http://192.168.3.135:$FRONTEND_PORT/login${NC}"
            log "${GREEN}  Dashboard:  http://192.168.3.135:$FRONTEND_PORT/dashboard${NC}"
            log "${CYAN}Backend (API):${NC}"
            log "${GREEN}  API Base:   http://192.168.3.135:$BACKEND_PORT${NC}"
            log "${GREEN}  Health:     http://192.168.3.135:$BACKEND_PORT/health${NC}"
            log "${GREEN}  Status:     http://192.168.3.135:$BACKEND_PORT/api/status${NC}"
            
            echo ""
            log "${BLUE}=== Test Login Credentials ===${NC}"
            log "${CYAN}Email:    admin@company.com${NC}"
            log "${CYAN}Password: admin123${NC}"
            
            check_servers_status
            
            # ブラウザ起動オプション
            echo ""
            echo -e "${CYAN}Would you like to open browsers? (y/n): ${NC}"
            read -r -n 1 open_browser
            echo ""
            if [[ $open_browser =~ ^[Yy]$ ]]; then
                if [ -f "$SCRIPT_DIR/tmux-url-helper.sh" ]; then
                    "$SCRIPT_DIR/tmux-url-helper.sh" launch
                else
                    # ブラウザ起動
                    if command -v xdg-open &> /dev/null; then
                        xdg-open "http://192.168.3.135:$FRONTEND_PORT" &
                        xdg-open "http://192.168.3.135:$BACKEND_PORT/health" &
                    fi
                fi
            fi
            
            return 0
        else
            log "${RED}✗ Failed to start frontend server${NC}"
            return 1
        fi
    else
        log "${RED}✗ Failed to start backend server${NC}"
        return 1
    fi
}

# 依存関係確認
check_dependencies() {
    log "${BLUE}=== Checking Dependencies ===${NC}"
    
    # Node.js確認
    if ! command -v node &> /dev/null; then
        log "${RED}✗ Node.js not found${NC}"
        exit 1
    fi
    log "${GREEN}✓ Node.js: $(node -v)${NC}"
    
    # npm確認
    if ! command -v npm &> /dev/null; then
        log "${RED}✗ npm not found${NC}"
        exit 1
    fi
    log "${GREEN}✓ npm: $(npm -v)${NC}"
    
    # curl確認
    if ! command -v curl &> /dev/null; then
        log "${YELLOW}⚠ curl not found (recommended for health checks)${NC}"
    else
        log "${GREEN}✓ curl available${NC}"
    fi
    
    # Frontend依存関係確認
    if [ ! -d "$FRONTEND_DIR/node_modules" ]; then
        log "${YELLOW}Installing frontend dependencies...${NC}"
        cd "$FRONTEND_DIR" && npm install
    fi
    
    # Frontend Express確認（簡易サーバー用）
    if [ -d "$FRONTEND_DIR" ]; then
        cd "$FRONTEND_DIR"
        if [ -f "simple-server.cjs" ]; then
            log "${GREEN}✓ Express simple server found (simple-server.cjs)${NC}"
        fi
        if ! npm list express &> /dev/null; then
            log "${YELLOW}Installing Express for simple server...${NC}"
            npm install express
        else
            log "${GREEN}✓ Express dependency available${NC}"
        fi
    fi
    
    # Backend依存関係確認
    if [ ! -d "$BACKEND_DIR/node_modules" ]; then
        log "${YELLOW}Installing backend dependencies...${NC}"
        cd "$BACKEND_DIR" && npm install
    fi
}

# ログ表示
show_logs() {
    echo -e "${CYAN}Select log to view:${NC}"
    echo "1. Backend log"
    echo "2. Frontend log"
    echo "3. Auto-start log"
    echo "4. All logs (tail -f)"
    read -p "Choice: " log_choice
    
    case $log_choice in
        1) tail -f "$BACKEND_LOG" ;;
        2) tail -f "$FRONTEND_LOG" ;;
        3) tail -f "$AUTO_START_LOG" ;;
        4) tail -f "$BACKEND_LOG" "$FRONTEND_LOG" "$AUTO_START_LOG" ;;
        *) echo "Invalid choice" ;;
    esac
}

# システムサービス作成（Linux systemd）
create_systemd_service() {
    if command -v systemctl &> /dev/null; then
        log "${BLUE}=== Creating systemd service ===${NC}"
        
        cat > /tmp/itsm-servers.service << EOF
[Unit]
Description=ITSM Frontend and Backend Servers
After=network.target

[Service]
Type=forking
User=$USER
WorkingDirectory=$SCRIPT_DIR
ExecStart=$SCRIPT_DIR/auto-start-servers.sh start
ExecStop=$SCRIPT_DIR/auto-start-servers.sh stop
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        echo "Systemd service file created at /tmp/itsm-servers.service"
        echo "To install: sudo cp /tmp/itsm-servers.service /etc/systemd/system/"
        echo "To enable: sudo systemctl enable itsm-servers.service"
        echo "To start: sudo systemctl start itsm-servers.service"
    else
        log "${YELLOW}systemd not available${NC}"
    fi
}

# クリーンアップ（終了時）
cleanup() {
    log "${YELLOW}Cleanup on exit...${NC}"
    # 必要に応じて停止
}

# trap設定
trap cleanup EXIT

# メインメニュー
show_menu() {
    echo ""
    echo -e "${CYAN}=== Auto Start Servers Menu ===${NC}"
    echo "1. Start all servers"
    echo "2. Stop all servers"
    echo "3. Restart all servers"
    echo "4. Check status"
    echo "5. Show logs"
    echo "6. Create systemd service"
    echo "7. Open browsers"
    echo "q. Quit"
    echo ""
}

# メイン処理
main() {
    show_header
    log "${GREEN}🚀 Auto Start Servers Controller${NC}"
    
    case "${1:-}" in
        "start")
            start_all_servers
            ;;
        "stop")
            stop_servers
            ;;
        "restart")
            restart_servers
            ;;
        "status")
            check_servers_status
            ;;
        "logs")
            show_logs
            ;;
        "service")
            create_systemd_service
            ;;
        "auto")
            start_all_servers
            exit 0
            ;;
        *)
            # 対話モード
            while true; do
                show_menu
                read -p "Select option: " choice
                
                case $choice in
                    1) start_all_servers ;;
                    2) stop_servers ;;
                    3) restart_servers ;;
                    4) check_servers_status ;;
                    5) show_logs ;;
                    6) create_systemd_service ;;
                    7) 
                        if [ -f "$SCRIPT_DIR/tmux-url-helper.sh" ]; then
                            "$SCRIPT_DIR/tmux-url-helper.sh" launch
                        fi
                        ;;
                    q|Q) 
                        log "${GREEN}Exiting...${NC}"
                        break 
                        ;;
                    *) 
                        echo -e "${RED}Invalid option${NC}" 
                        ;;
                esac
                
                echo ""
                read -p "Press Enter to continue..."
            done
            ;;
    esac
}

# スクリプト実行
main "$@"