#!/bin/bash

# Simple Auto Start Script
# シンプルなサーバー自動起動スクリプト

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Starting ITSM Servers..."

# Backend起動
echo "Starting Backend Server (port 8081)..."
cd "$PROJECT_ROOT/itsm-backend"
npm start &
BACKEND_PID=$!

# Frontend起動
echo "Starting Frontend Server (port 3000)..."
cd "$PROJECT_ROOT/frontend"
npm run dev &
FRONTEND_PID=$!

# 起動待機
echo "Waiting for servers to initialize..."
sleep 10

# 状態確認
echo "Checking server status..."
if [ -f "$SCRIPT_DIR/tmux-url-helper.sh" ]; then
    "$SCRIPT_DIR/tmux-url-helper.sh" status
else
    echo "Frontend: http://localhost:3000"
    echo "Backend: http://localhost:8081"
fi

echo ""
echo "✅ Servers are starting up!"
echo "   Frontend: http://localhost:3000"
echo "   Backend: http://localhost:8081"
echo "   API Docs: http://localhost:8081/api/docs"
echo ""
echo "Press Ctrl+C to stop servers"

# 終了時処理
cleanup() {
    echo ""
    echo "Stopping servers..."
    kill $BACKEND_PID 2>/dev/null
    kill $FRONTEND_PID 2>/dev/null
    echo "Servers stopped"
}

trap cleanup EXIT

# 待機
wait