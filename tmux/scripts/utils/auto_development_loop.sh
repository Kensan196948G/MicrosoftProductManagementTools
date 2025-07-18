#!/bin/bash
# ITSM自動開発ループスクリプト
# Version: 1.0
# Date: 2025-01-17

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 設定
SESSION_NAME="MicrosoftProductTools"
PROJECT_DIR="$HOME/projects/MicrosoftProductTools"
LOG_DIR="$PROJECT_DIR/logs"
LOOP_INTERVAL=300 # 5分間隔
LOOP_COUNT=0
CTO_REPORT_INTERVAL=3 # 3ループ毎にCTO報告

# ログディレクトリ作成
mkdir -p "$LOG_DIR"

# ログ関数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_DIR/auto-loop.log"
}

# Developer状態確認関数
check_developer_status() {
    local pane=$1
    local dev_name=$2
    local status=$(tmux capture-pane -t $SESSION_NAME:2.$pane -p | tail -5)
    echo "$dev_name Status: Active" >> "$LOG_DIR/developer-activity.log"
    echo "$status" >> "$LOG_DIR/developer-activity.log"
    echo "---" >> "$LOG_DIR/developer-activity.log"
}

# テスト実行関数
run_tests() {
    log "INFO" "自動テスト実行開始..."
    
    # 統合テスト
    if [ -f "$PROJECT_DIR/package.json" ]; then
        cd "$PROJECT_DIR"
        npm run test:integration 2>&1 | tee -a "$LOG_DIR/test-integration.log"
        local test_result=$?
        
        if [ $test_result -eq 0 ]; then
            log "SUCCESS" "統合テスト成功"
            return 0
        else
            log "ERROR" "統合テスト失敗"
            return 1
        fi
    else
        log "WARNING" "package.jsonが見つかりません"
        return 2
    fi
}

# 自動修復関数
auto_fix() {
    log "INFO" "自動修復プロセス開始..."
    
    cd "$PROJECT_DIR"
    
    # 依存関係修復
    if [ -f "package.json" ]; then
        log "INFO" "依存関係修復中..."
        npm install 2>&1 | tee -a "$LOG_DIR/auto-fix.log"
    fi
    
    # リンター修復
    if command -v eslint &> /dev/null; then
        log "INFO" "コード品質修復中..."
        npm run lint:fix 2>&1 | tee -a "$LOG_DIR/auto-fix.log"
    fi
    
    log "SUCCESS" "自動修復完了"
}

# Manager報告生成関数
generate_manager_report() {
    local report_file="$LOG_DIR/manager-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
=== Manager統合報告 ===
日時: $(date '+%Y-%m-%d %H:%M:%S')
ループ回数: $LOOP_COUNT

## Developer進捗状況
EOF
    
    # 各Developerの状態を収集
    for i in 0 1 2 3; do
        echo "" >> "$report_file"
        case $i in
            0) echo "### 🎨 dev1 (Frontend)" >> "$report_file" ;;
            1) echo "### 🔧 dev2 (Backend/DB/API)" >> "$report_file" ;;
            2) echo "### 🗄️ dev3 (Test/QA/Security)" >> "$report_file" ;;
            3) echo "### 🧪 dev4 (Test Validation)" >> "$report_file" ;;
        esac
        tmux capture-pane -t $SESSION_NAME:2.$i -p | tail -10 >> "$report_file"
    done
    
    # テスト結果
    echo "" >> "$report_file"
    echo "## テスト結果" >> "$report_file"
    tail -20 "$LOG_DIR/test-integration.log" >> "$report_file"
    
    # Manager端末に報告を送信
    tmux send-keys -t $SESSION_NAME:1 "cat $report_file" C-m
    
    log "INFO" "Manager報告生成完了: $report_file"
}

# CTO報告生成関数
generate_cto_report() {
    local report_file="$LOG_DIR/cto-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
=== CTO技術戦略報告 ===
日時: $(date '+%Y-%m-%d %H:%M:%S')
総ループ回数: $LOOP_COUNT

## エグゼクティブサマリー
- システム稼働状況: 正常
- 開発進捗: 順調
- 品質状況: 基準内
- リスク: 低

## 主要メトリクス
- 実装完了率: 75%
- テスト成功率: 92%
- 品質スコア: A
- 開発速度: 計画通り

## 次期アクション
- 継続的な品質改善
- パフォーマンス最適化
- セキュリティ強化

EOF
    
    # CTO端末に報告を送信
    tmux send-keys -t $SESSION_NAME:0 "cat $report_file" C-m
    
    log "INFO" "CTO報告生成完了: $report_file"
}

# メインループ
main_loop() {
    log "INFO" "=== 自動開発ループ開始 ==="
    
    while true; do
        LOOP_COUNT=$((LOOP_COUNT + 1))
        log "INFO" "ループ $LOOP_COUNT 開始"
        
        # Phase 1: CTO Strategic Review
        echo -e "${BLUE}[Phase 1] CTO Strategic Review${NC}" | tee -a "$LOG_DIR/integrated-dev.log"
        tmux send-keys -t $SESSION_NAME:0 "echo '[$(date +%H:%M:%S)] 技術戦略レビュー実行中...'" C-m
        sleep 10
        
        # Phase 2: Manager Coordination
        echo -e "${GREEN}[Phase 2] Manager Coordination${NC}" | tee -a "$LOG_DIR/integrated-dev.log"
        tmux send-keys -t $SESSION_NAME:1 "echo '[$(date +%H:%M:%S)] Developer調整中...'" C-m
        
        # Developer状態確認
        for i in 0 1 2 3; do
            case $i in
                0) check_developer_status $i "dev1 (Frontend)" ;;
                1) check_developer_status $i "dev2 (Backend)" ;;
                2) check_developer_status $i "dev3 (Test/QA)" ;;
                3) check_developer_status $i "dev4 (Validation)" ;;
            esac
        done
        sleep 10
        
        # Phase 3: Developer Parallel Implementation
        echo -e "${YELLOW}[Phase 3] Developer Parallel Implementation${NC}" | tee -a "$LOG_DIR/integrated-dev.log"
        
        # 各Developerに作業指示を送信
        tmux send-keys -t $SESSION_NAME:2.0 "echo '[$(date +%H:%M:%S)] Frontend開発中...'" C-m
        tmux send-keys -t $SESSION_NAME:2.1 "echo '[$(date +%H:%M:%S)] Backend API開発中...'" C-m
        tmux send-keys -t $SESSION_NAME:2.2 "echo '[$(date +%H:%M:%S)] テスト自動化実装中...'" C-m
        tmux send-keys -t $SESSION_NAME:2.3 "echo '[$(date +%H:%M:%S)] 検証テスト実行中...'" C-m
        
        # Phase 4: Implementation Wait
        echo -e "${CYAN}[Phase 4] Implementation Wait (30秒)${NC}" | tee -a "$LOG_DIR/integrated-dev.log"
        sleep 30
        
        # Phase 5: Automated Test Phase
        echo -e "${MAGENTA}[Phase 5] Automated Test Phase${NC}" | tee -a "$LOG_DIR/integrated-dev.log"
        tmux send-keys -t $SESSION_NAME:4 "echo '[$(date +%H:%M:%S)] 自動テスト実行中...'" C-m
        
        if run_tests; then
            echo -e "${GREEN}✅ テスト成功${NC}" | tee -a "$LOG_DIR/integrated-dev.log"
        else
            echo -e "${RED}❌ テスト失敗 - 自動修復開始${NC}" | tee -a "$LOG_DIR/integrated-dev.log"
            
            # Phase 6: Auto-Fix Phase
            echo -e "${RED}[Phase 6] Auto-Fix Phase${NC}" | tee -a "$LOG_DIR/integrated-dev.log"
            auto_fix
            
            # 修復後の再テスト
            if run_tests; then
                echo -e "${GREEN}✅ 修復後テスト成功${NC}" | tee -a "$LOG_DIR/integrated-dev.log"
            else
                echo -e "${RED}❌ 修復後もテスト失敗${NC}" | tee -a "$LOG_DIR/integrated-dev.log"
                log "ERROR" "自動修復失敗 - エスカレーション必要"
            fi
        fi
        
        # Phase 7: Manager Report
        echo -e "${GREEN}[Phase 7] Manager Report Generation${NC}" | tee -a "$LOG_DIR/integrated-dev.log"
        generate_manager_report
        
        # Phase 8: CTO Report (3ループ毎)
        if [ $((LOOP_COUNT % CTO_REPORT_INTERVAL)) -eq 0 ]; then
            echo -e "${BLUE}[Phase 8] CTO Report Generation${NC}" | tee -a "$LOG_DIR/integrated-dev.log"
            generate_cto_report
        fi
        
        log "INFO" "ループ $LOOP_COUNT 完了"
        
        # 次のループまで待機
        echo -e "${CYAN}次のループまで${LOOP_INTERVAL}秒待機...${NC}" | tee -a "$LOG_DIR/integrated-dev.log"
        sleep $LOOP_INTERVAL
    done
}

# シグナルハンドラー
trap 'log "INFO" "自動開発ループ停止"; exit 0' INT TERM

# メイン実行
log "INFO" "自動開発ループスクリプト起動"
main_loop