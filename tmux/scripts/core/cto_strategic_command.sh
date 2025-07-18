#!/bin/bash
# CTO技術戦略指示スクリプト
# Version: 1.0
# Date: 2025-01-17

# 色定義
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

SESSION_NAME="ITSM-ITmanagementSystem"
PROJECT_DIR="$HOME/projects/ITSM-ITmanagementSystem"
LOG_DIR="$PROJECT_DIR/logs"

# Claude環境変数読み込み
if [ -f "$HOME/.config/claude/claude_env.sh" ]; then
    source "$HOME/.config/claude/claude_env.sh"
fi

echo -e "${BLUE}🔧 CTO技術戦略指示システム${NC}"
echo "====================================="

# メニュー表示
show_menu() {
    echo ""
    echo "技術戦略オプション:"
    echo "1) 技術アーキテクチャ設定"
    echo "2) 技術優先度変更"
    echo "3) 技術スタック決定"
    echo "4) 緊急技術指示"
    echo "5) コード品質基準設定"
    echo "6) 技術リリース承認"
    echo "7) 全Developer停止"
    echo "8) 技術レビュー実施"
    echo "9) Claude統合管理"
    echo "10) 終了"
    echo ""
}

# 技術アーキテクチャ設定
set_strategy() {
    echo -e "${YELLOW}新しい技術アーキテクチャ方針を入力してください:${NC}"
    read -r strategy
    
    # 戦略をログに記録
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTO技術戦略: $strategy" >> "$LOG_DIR/cto-decisions.log"
    
    # Manager端末に送信
    tmux send-keys -t $SESSION_NAME:1 "echo '${BLUE}[CTO技術指示]${NC} $strategy'" C-m
    
    # 全Developerに通知
    for i in 0 1 2 3; do
        tmux send-keys -t $SESSION_NAME:2.$i "echo '${BLUE}[CTO技術方針]${NC} $strategy'" C-m
    done
    
    echo -e "${GREEN}✅ 技術戦略を全チームに送信しました${NC}"
}

# 技術優先度変更
change_priority() {
    echo -e "${YELLOW}優先度を変更する技術領域を選択してください:${NC}"
    echo "1) Frontend開発"
    echo "2) Backend/API開発"
    echo "3) テスト/品質保証"
    echo "4) セキュリティ対策"
    read -r choice
    
    echo -e "${YELLOW}新しい優先度 (1-最高, 5-最低):${NC}"
    read -r priority
    
    local target=""
    case $choice in
        1) target="Frontend" ;;
        2) target="Backend/API" ;;
        3) target="テスト/品質保証" ;;
        4) target="セキュリティ対策" ;;
        *) echo -e "${RED}無効な選択${NC}"; return ;;
    esac
    
    # Manager端末に優先度変更を指示
    tmux send-keys -t $SESSION_NAME:1 "echo '${YELLOW}[CTO技術優先度]${NC} $target を優先度 $priority に変更'" C-m
    
    echo -e "${GREEN}✅ 技術優先度変更指示を送信しました${NC}"
}

# 技術スタック決定
set_tech_stack() {
    echo -e "${CYAN}技術スタック決定${NC}"
    echo "====================================="
    echo "現在の技術スタック:"
    echo "- Frontend: React/Vue.js"
    echo "- Backend: Node.js/Express"
    echo "- Database: SQLite"
    echo "- Testing: Jest/ESLint"
    echo ""
    echo -e "${YELLOW}変更する技術を選択:${NC}"
    echo "1) Frontend Framework"
    echo "2) Backend Framework"
    echo "3) Database"
    echo "4) Testing Framework"
    echo "5) 新規技術追加"
    read -r tech_choice
    
    echo -e "${YELLOW}新しい技術/フレームワーク名:${NC}"
    read -r new_tech
    
    # 技術決定をログに記録
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTO技術スタック変更: $new_tech" >> "$LOG_DIR/cto-decisions.log"
    
    # 全体に通知
    tmux send-keys -t $SESSION_NAME:1 "echo '${CYAN}[CTO技術決定]${NC} 新技術導入: $new_tech'" C-m
    
    echo -e "${GREEN}✅ 技術スタック変更を通知しました${NC}"
}

# 緊急技術指示
emergency_order() {
    echo -e "${RED}⚠️  緊急技術指示内容を入力してください:${NC}"
    read -r emergency_msg
    
    # 全Window/Paneに緊急指示を送信
    for window in 0 1 2 3 4; do
        if [ $window -eq 2 ]; then
            # Developer Windowは全Paneに送信
            for pane in 0 1 2 3; do
                tmux send-keys -t $SESSION_NAME:$window.$pane "echo '${RED}🚨 [CTO緊急技術指示] $emergency_msg${NC}'" C-m
            done
        else
            tmux send-keys -t $SESSION_NAME:$window "echo '${RED}🚨 [CTO緊急技術指示] $emergency_msg${NC}'" C-m
        fi
    done
    
    # ログに記録
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTO緊急技術指示: $emergency_msg" >> "$LOG_DIR/cto-emergency.log"
    
    echo -e "${GREEN}✅ 緊急技術指示を全システムに送信しました${NC}"
}

# コード品質基準設定
set_code_quality() {
    echo -e "${YELLOW}コード品質基準設定${NC}"
    echo "====================================="
    echo "1) コードカバレッジ目標設定"
    echo "2) リンタールール設定"
    echo "3) セキュリティ基準設定"
    echo "4) パフォーマンス基準設定"
    read -r quality_choice
    
    echo -e "${YELLOW}新しい基準値を入力:${NC}"
    read -r quality_value
    
    local quality_type=""
    case $quality_choice in
        1) quality_type="コードカバレッジ" ;;
        2) quality_type="リンタールール" ;;
        3) quality_type="セキュリティ基準" ;;
        4) quality_type="パフォーマンス基準" ;;
    esac
    
    # 品質基準をログに記録
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTO品質基準: $quality_type = $quality_value" >> "$LOG_DIR/cto-decisions.log"
    
    # Developer端末に通知
    for i in 0 1 2 3; do
        tmux send-keys -t $SESSION_NAME:2.$i "echo '${YELLOW}[CTO品質基準]${NC} $quality_type を $quality_value に設定'" C-m
    done
    
    echo -e "${GREEN}✅ コード品質基準を設定しました${NC}"
}

# Claude統合管理
manage_claude() {
    echo -e "${CYAN}Claude統合管理${NC}"
    echo "====================================="
    echo "1) 全DeveloperでClaude起動"
    echo "2) 特定DeveloperでClaude起動"
    echo "3) Claude設定更新"
    echo "4) Claude認証設定"
    echo "5) Claudeセッション確認"
    read -r claude_choice
    
    case $claude_choice in
        1)
            # 全DeveloperでClaude起動
            echo -e "${YELLOW}全DeveloperでClaude起動中...${NC}"
            
            # Claude関数読み込み
            if [ -f "./tmux_claude_functions.sh" ]; then
                source ./tmux_claude_functions.sh
                launch_all_claude
            else
                # 直接起動
                tmux send-keys -t $SESSION_NAME:2.0 "claude --dangerously-skip-permissions 'Frontend Developer として作業します'" C-m
                tmux send-keys -t $SESSION_NAME:2.1 "claude --dangerously-skip-permissions 'Backend Developer として作業します'" C-m
                tmux send-keys -t $SESSION_NAME:2.2 "claude --dangerously-skip-permissions 'Test/QA Developer として作業します'" C-m
                tmux send-keys -t $SESSION_NAME:2.3 "claude --dangerously-skip-permissions 'Validation Developer として作業します'" C-m
            fi
            echo -e "${GREEN}✅ 全DeveloperでClaude起動しました${NC}"
            ;;
        2)
            # 特定DeveloperでClaude起動
            echo "Developer を選択:"
            echo "1) Frontend Developer"
            echo "2) Backend Developer"
            echo "3) Test/QA Developer"
            echo "4) Validation Developer"
            read -r dev_choice
            
            case $dev_choice in
                1) tmux send-keys -t $SESSION_NAME:2.0 "claude --dangerously-skip-permissions 'Frontend Developer として作業します'" C-m ;;
                2) tmux send-keys -t $SESSION_NAME:2.1 "claude --dangerously-skip-permissions 'Backend Developer として作業します'" C-m ;;
                3) tmux send-keys -t $SESSION_NAME:2.2 "claude --dangerously-skip-permissions 'Test/QA Developer として作業します'" C-m ;;
                4) tmux send-keys -t $SESSION_NAME:2.3 "claude --dangerously-skip-permissions 'Validation Developer として作業します'" C-m ;;
            esac
            ;;
        3)
            # Claude設定更新
            echo "Claude設定を更新します..."
            ./claude_auth_config.sh
            ;;
        4)
            # Claude認証設定
            echo "Claude認証を設定します..."
            ./claude_auth_config.sh
            ;;
        5)
            # Claudeセッション確認
            echo "Claudeセッション状態:"
            ps aux | grep claude | grep -v grep
            ;;
    esac
}

# 技術リリース承認
approve_release() {
    echo -e "${GREEN}技術リリース承認プロセス${NC}"
    echo "====================================="
    
    # 品質レポート確認
    echo "最新の技術品質レポート:"
    if [ -f "$LOG_DIR/quality-report-latest.txt" ]; then
        tail -20 "$LOG_DIR/quality-report-latest.txt"
    else
        echo "品質レポートが見つかりません"
    fi
    
    echo ""
    echo -e "${YELLOW}技術的にリリース可能ですか? (yes/no):${NC}"
    read -r approval
    
    if [ "$approval" = "yes" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTO: 技術リリース承認" >> "$LOG_DIR/cto-decisions.log"
        
        # Automation端末にリリース実行を指示
        tmux send-keys -t $SESSION_NAME:4 "echo '${GREEN}[CTO承認] 技術リリース実行開始${NC}'" C-m
        tmux send-keys -t $SESSION_NAME:4 "./deploy_production.sh" C-m
        
        echo -e "${GREEN}✅ 技術リリースを承認しました${NC}"
    else
        echo -e "${RED}技術リリースは承認されませんでした${NC}"
    fi
}

# 全Developer停止
stop_all_developers() {
    echo -e "${RED}⚠️  全Developer作業を停止しますか? (yes/no):${NC}"
    read -r confirm
    
    if [ "$confirm" = "yes" ]; then
        for i in 0 1 2 3; do
            tmux send-keys -t $SESSION_NAME:2.$i C-c
            tmux send-keys -t $SESSION_NAME:2.$i "echo '${RED}[CTO指示] 作業停止${NC}'" C-m
        done
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTO: 全Developer作業停止指示" >> "$LOG_DIR/cto-decisions.log"
        echo -e "${GREEN}✅ 全Developer作業を停止しました${NC}"
    fi
}

# メインループ
while true; do
    show_menu
    echo -n "選択してください: "
    read -r choice
    
    case $choice in
        1) set_strategy ;;
        2) change_priority ;;
        3) set_tech_stack ;;
        4) emergency_order ;;
        5) set_code_quality ;;
        6) approve_release ;;
        7) stop_all_developers ;;
        8) ./cto_progress_review.sh ;;
        9) manage_claude ;;
        10) echo -e "${BLUE}CTO技術戦略システムを終了します${NC}"; exit 0 ;;
        *) echo -e "${RED}無効な選択です${NC}" ;;
    esac
done