#!/bin/bash
# システムモニタリングスクリプト
# Version: 1.0
# Date: 2025-01-17

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SESSION_NAME="ITSM-ITmanagementSystem"
PROJECT_DIR="$HOME/projects/ITSM-ITmanagementSystem"
LOG_DIR="$PROJECT_DIR/logs"

# 無限ループでモニタリング
while true; do
    clear
    echo -e "${CYAN}📊 ITSM並列開発環境 - システムモニター${NC}"
    echo "============================================="
    echo "更新時刻: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================="
    
    # システムリソース状況
    echo -e "\n${YELLOW}💻 システムリソース${NC}"
    echo "---------------------------------------------"
    
    # CPU使用率
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo "CPU使用率: ${cpu_usage}%"
    
    # メモリ使用率
    mem_info=$(free -m | grep Mem)
    mem_total=$(echo $mem_info | awk '{print $2}')
    mem_used=$(echo $mem_info | awk '{print $3}')
    mem_percent=$((mem_used * 100 / mem_total))
    echo "メモリ使用率: ${mem_percent}% (${mem_used}MB / ${mem_total}MB)"
    
    # ディスク使用量
    disk_usage=$(df -h "$PROJECT_DIR" 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
    echo "ディスク使用率: ${disk_usage}%"
    
    # Developer活動状況
    echo -e "\n${GREEN}👥 Developer活動状況${NC}"
    echo "---------------------------------------------"
    
    # 各Developerの最新状態を確認
    developers=("Frontend" "Backend/DB/API" "Test/QA/Security" "Test Validation")
    for i in 0 1 2 3; do
        # tmuxペインから最新行を取得
        last_activity=$(tmux capture-pane -t $SESSION_NAME:2.$i -p 2>/dev/null | tail -1)
        
        if [[ "$last_activity" == *"実装中"* ]] || [[ "$last_activity" == *"開発中"* ]]; then
            status="${GREEN}🟢 作業中${NC}"
        elif [[ "$last_activity" == *"エラー"* ]] || [[ "$last_activity" == *"失敗"* ]]; then
            status="${RED}🔴 エラー${NC}"
        elif [[ "$last_activity" == *"完了"* ]] || [[ "$last_activity" == *"成功"* ]]; then
            status="${GREEN}✅ 完了${NC}"
        else
            status="${YELLOW}⏸️  待機中${NC}"
        fi
        
        echo -e "dev$((i+1)) (${developers[$i]}): $status"
    done
    
    # ログファイル監視
    echo -e "\n${BLUE}📄 最新ログエントリ${NC}"
    echo "---------------------------------------------"
    
    # 統合開発ログの最新5行
    if [ -f "$LOG_DIR/integrated-dev.log" ]; then
        tail -5 "$LOG_DIR/integrated-dev.log" | while read line; do
            if [[ "$line" == *"ERROR"* ]]; then
                echo -e "${RED}$line${NC}"
            elif [[ "$line" == *"SUCCESS"* ]]; then
                echo -e "${GREEN}$line${NC}"
            elif [[ "$line" == *"WARNING"* ]]; then
                echo -e "${YELLOW}$line${NC}"
            else
                echo "$line"
            fi
        done
    else
        echo "ログファイルが見つかりません"
    fi
    
    # エラー統計
    echo -e "\n${RED}⚠️  エラー統計 (過去1時間)${NC}"
    echo "---------------------------------------------"
    
    if [ -f "$LOG_DIR/auto-loop.log" ]; then
        # 過去1時間のエラー数をカウント
        one_hour_ago=$(date -d '1 hour ago' '+%Y-%m-%d %H:%M:%S')
        error_count=$(awk -v date="$one_hour_ago" '$0 > date && /ERROR/' "$LOG_DIR/auto-loop.log" | wc -l)
        warning_count=$(awk -v date="$one_hour_ago" '$0 > date && /WARNING/' "$LOG_DIR/auto-loop.log" | wc -l)
        
        echo "エラー数: $error_count"
        echo "警告数: $warning_count"
        
        # 最新のエラー
        if [ $error_count -gt 0 ]; then
            echo -e "\n最新のエラー:"
            grep "ERROR" "$LOG_DIR/auto-loop.log" | tail -1
        fi
    fi
    
    # 自動ループ状態
    echo -e "\n${CYAN}🔄 自動開発ループ状態${NC}"
    echo "---------------------------------------------"
    
    # プロセス確認
    if pgrep -f "auto_development_loop.sh" > /dev/null; then
        echo -e "状態: ${GREEN}実行中${NC}"
        
        # 最新のループ情報
        if [ -f "$LOG_DIR/auto-loop.log" ]; then
            last_loop=$(grep "ループ.*開始" "$LOG_DIR/auto-loop.log" | tail -1)
            echo "最新: $last_loop"
        fi
    else
        echo -e "状態: ${RED}停止中${NC}"
        echo "起動するには: ./auto_development_loop.sh &"
    fi
    
    # tmuxセッション情報
    echo -e "\n${YELLOW}🖥️  tmuxセッション情報${NC}"
    echo "---------------------------------------------"
    
    # セッション確認
    if tmux has-session -t $SESSION_NAME 2>/dev/null; then
        window_count=$(tmux list-windows -t $SESSION_NAME | wc -l)
        echo "セッション: $SESSION_NAME (アクティブ)"
        echo "Window数: $window_count"
        
        # アクティブWindow
        active_window=$(tmux display-message -t $SESSION_NAME -p '#I:#W')
        echo "アクティブWindow: $active_window"
    else
        echo -e "${RED}セッションが見つかりません${NC}"
    fi
    
    # 更新間隔
    echo -e "\n${CYAN}5秒後に更新...${NC}"
    sleep 5
done