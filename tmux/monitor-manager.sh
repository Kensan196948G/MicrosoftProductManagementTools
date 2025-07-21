#!/bin/bash
# Manager pane real-time monitoring script

SESSION="MicrosoftProductTools-Python-Context7-5team"
PANE="0.0"

echo "🔍 Managerペインのリアルタイム監視を開始します..."
echo "終了: Ctrl+C"
echo "================================================"

while true; do
    clear
    echo "📊 Manager Activity Monitor - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "================================================"
    
    # Capture last 40 lines from Manager pane
    tmux capture-pane -t "${SESSION}:${PANE}" -p -S -40 | tail -40
    
    echo ""
    echo "================================================"
    echo "🔄 更新間隔: 2秒 | 📍 監視対象: ${SESSION}:${PANE}"
    
    sleep 2
done