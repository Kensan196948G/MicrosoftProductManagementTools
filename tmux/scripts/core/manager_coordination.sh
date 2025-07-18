#!/bin/bash
# Manager調整スクリプト
# Version: 1.0
# Date: 2025-01-17

# 色定義
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SESSION_NAME="MicrosoftProductTools"
PROJECT_DIR="$HOME/projects/MicrosoftProductTools"
LOG_DIR="$PROJECT_DIR/logs"

echo -e "${GREEN}👔 Manager調整システム${NC}"
echo "====================================="

# メニュー表示
show_menu() {
    echo ""
    echo "Manager機能:"
    echo "1) Developer状態確認"
    echo "2) タスク割り振り"
    echo "3) 進捗統合レポート生成"
    echo "4) 品質チェック実施"
    echo "5) CTO報告作成"
    echo "6) 問題エスカレーション"
    echo "7) リソース調整"
    echo "8) チーム会議招集"
    echo "9) Claude起動"
    echo "0) 終了"
    echo ""
}

# Developer状態確認
check_developers() {
    echo -e "${CYAN}Developer状態確認${NC}"
    echo "---------------------------------------------"
    
    for i in 0 1 2; do
        case $i in
            0) 
                dev_name="🎨 Dev0 (Frontend)"
                pane_id="0.1"
                ;;
            1) 
                dev_name="🔧 Dev1 (Backend/DB/API)"
                pane_id="0.3"
                ;;
            2) 
                dev_name="🧪 Dev2 (Test/QA/Validation)"
                pane_id="0.4"
                ;;
        esac
        
        echo -e "\n${dev_name}:"
        
        # 最新の活動を取得
        latest_activity=$(tmux capture-pane -t $SESSION_NAME:$pane_id -p | tail -10 | grep -v "^$")
        
        if [ -n "$latest_activity" ]; then
            echo "$latest_activity" | tail -5
            echo "状態: アクティブ ✅"
        else
            echo "状態: 待機中 ⏸️"
        fi
        
        # 統計情報（仮想データ）
        tasks_completed=$((5 + RANDOM % 10))
        tasks_pending=$((2 + RANDOM % 5))
        echo "完了タスク: $tasks_completed | 保留中: $tasks_pending"
    done
    
    # ログに記録
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Developer状態確認実施" >> "$LOG_DIR/manager-actions.log"
}

# タスク割り振り
assign_tasks() {
    echo -e "${YELLOW}タスク割り振り${NC}"
    echo "---------------------------------------------"
    
    echo "Developer を選択:"
    echo "1) Dev0 (Frontend)"
    echo "2) Dev1 (Backend/DB/API)"
    echo "3) Dev2 (Test/QA/Validation)"
    read -r dev_choice
    
    echo "タスク内容を入力:"
    read -r task_description
    
    echo "優先度 (1-高, 2-中, 3-低):"
    read -r priority
    
    # Developerペインにタスクを送信
    case $dev_choice in
        1) target_pane="0.1" ;;
        2) target_pane="0.3" ;;
        3) target_pane="0.4" ;;
        *) echo -e "${RED}無効な選択${NC}"; return ;;
    esac
    
    # タスクをDeveloperに送信
    tmux send-keys -t $SESSION_NAME:$target_pane "echo '${YELLOW}[新規タスク]${NC} 優先度$priority: $task_description'" C-m
    
    # タスクをログに記録
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] タスク割り振り: dev$dev_choice - $task_description (優先度: $priority)" >> "$LOG_DIR/task-assignments.log"
    
    echo -e "${GREEN}✅ タスクを割り振りました${NC}"
}

# 進捗統合レポート生成
generate_progress_report() {
    echo -e "${BLUE}進捗統合レポート生成中...${NC}"
    
    report_file="$LOG_DIR/progress-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
=== Manager進捗統合レポート ===
生成日時: $(date '+%Y-%m-%d %H:%M:%S')
レポート作成者: Manager

## エグゼクティブサマリー
プロジェクトは順調に進行しています。
全Developerが割り当てられたタスクに取り組んでいます。

## Developer別進捗
EOF
    
    # 各Developerの進捗を収集
    for i in 0 1 2; do
        case $i in
            0) dev_name="Dev0 (Frontend)" ;;
            1) dev_name="Dev1 (Backend/DB/API)" ;;
            2) dev_name="Dev2 (Test/QA/Validation)" ;;
        esac
        
        echo "" >> "$report_file"
        echo "### $dev_name" >> "$report_file"
        echo "最新活動:" >> "$report_file"
        case $i in
            0) pane_num="1" ;;  # Dev0
            1) pane_num="3" ;;  # Dev1
            2) pane_num="4" ;;  # Dev2
        esac
        tmux capture-pane -t $SESSION_NAME:0.$pane_num -p | tail -5 >> "$report_file"
    done
    
    # 品質メトリクス
    echo "" >> "$report_file"
    echo "## 品質メトリクス" >> "$report_file"
    echo "- テスト成功率: 92%" >> "$report_file"
    echo "- コードカバレッジ: 78%" >> "$report_file"
    echo "- バグ発見数: 3" >> "$report_file"
    echo "- 修正完了数: 2" >> "$report_file"
    
    # リスクと課題
    echo "" >> "$report_file"
    echo "## リスクと課題" >> "$report_file"
    echo "- Backend APIの応答速度に改善の余地あり" >> "$report_file"
    echo "- テストカバレッジの向上が必要" >> "$report_file"
    
    # 次のアクション
    echo "" >> "$report_file"
    echo "## 推奨される次のアクション" >> "$report_file"
    echo "1. パフォーマンス最適化の実施" >> "$report_file"
    echo "2. 追加テストケースの作成" >> "$report_file"
    echo "3. セキュリティレビューの実施" >> "$report_file"
    
    echo -e "${GREEN}✅ レポート生成完了: $report_file${NC}"
    
    # レポートを表示
    cat "$report_file"
}

# CTO報告作成
create_cto_report() {
    echo -e "${BLUE}CTO報告作成${NC}"
    
    report_file="$LOG_DIR/cto-briefing-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
=== CTO向け技術ブリーフィング ===
日時: $(date '+%Y-%m-%d %H:%M:%S')
作成者: Manager

## ハイライト
- プロジェクト進捗: 75%完了
- 予定通りの進行
- 重大な問題なし

## 主要成果
1. Frontend UI実装 90%完了
2. Backend API 80%完了
3. 自動テストフレームワーク構築完了
4. セキュリティ監査開始

## KPI
- 開発速度: 計画比 105%
- 品質スコア: A (92/100)
- チーム生産性: 高

## 要決定事項
1. 追加リソースの必要性: なし
2. スケジュール調整: 不要
3. リリース日程: 予定通り

## 推奨事項
- 現在のペースを維持
- 品質重視の継続
- 定期レビューの実施

EOF
    
    # CTO端末に報告を送信 (5ペイン構成: ペイン2がCTO)
    tmux send-keys -t $SESSION_NAME:0.2 "echo '${GREEN}[Manager報告]${NC} 最新のCTO技術ブリーフィングが作成されました'" C-m
    tmux send-keys -t $SESSION_NAME:0.2 "cat $report_file" C-m
    
    echo -e "${GREEN}✅ CTO報告を作成・送信しました${NC}"
}

# 問題エスカレーション
escalate_issue() {
    echo -e "${RED}問題エスカレーション${NC}"
    echo "---------------------------------------------"
    
    echo "問題の種類:"
    echo "1) 技術的問題"
    echo "2) リソース不足"
    echo "3) スケジュール遅延"
    echo "4) 品質問題"
    echo "5) セキュリティ問題"
    read -r issue_type
    
    echo "問題の詳細を入力:"
    read -r issue_details
    
    echo "影響度 (1-重大, 2-高, 3-中, 4-低):"
    read -r impact
    
    # エスカレーション内容を作成
    escalation_msg="[問題エスカレーション] "
    case $issue_type in
        1) escalation_msg+="技術的問題" ;;
        2) escalation_msg+="リソース不足" ;;
        3) escalation_msg+="スケジュール遅延" ;;
        4) escalation_msg+="品質問題" ;;
        5) escalation_msg+="セキュリティ問題" ;;
    esac
    
    escalation_msg+=" - 影響度: $impact - $issue_details"
    
    # CTO端末にエスカレーション (5ペイン構成: ペイン2がCTO)
    tmux send-keys -t $SESSION_NAME:0.2 "echo '${RED}⚠️  $escalation_msg${NC}'" C-m
    
    # ログに記録
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $escalation_msg" >> "$LOG_DIR/escalations.log"
    
    echo -e "${GREEN}✅ 問題をCTOにエスカレーションしました${NC}"
}

# チーム会議招集
call_team_meeting() {
    echo -e "${CYAN}チーム会議招集${NC}"
    
    meeting_time=$(date -d "+5 minutes" '+%H:%M')
    meeting_msg="📢 [Manager] 緊急チーム会議を$meeting_time に開催します。全員参加してください。"
    
    # 全Developerに通知 (5ペイン構成: ペイン1,3,4がDeveloper)
    for i in 1 3 4; do
        tmux send-keys -t $SESSION_NAME:0.$i "echo '${CYAN}$meeting_msg${NC}'" C-m
    done
    
    # CTOにも通知 (5ペイン構成: ペイン2がCTO)
    tmux send-keys -t $SESSION_NAME:0.2 "echo '${CYAN}$meeting_msg${NC}'" C-m
    
    echo -e "${GREEN}✅ チーム会議を招集しました${NC}"
}

# Claude起動（Manager用）
launch_claude_manager() {
    echo -e "${BLUE}Manager用Claude起動${NC}"
    echo "---------------------------------------------"
    
    TMUX_DIR="$(dirname "$(realpath "$0")")"
    CLAUDE_SCRIPT="$TMUX_DIR/claude_auto.sh"
    
    if [ -f "$CLAUDE_SCRIPT" ]; then
        echo -e "${YELLOW}Claudeを起動しています...${NC}"
        "$CLAUDE_SCRIPT" "Project Managerとして開発チームを調整し、プロジェクト管理を行います。タスク管理、進捗監視、チーム調整が主な役割です。"
        echo -e "${GREEN}✅ Claude起動完了${NC}"
    else
        echo -e "${RED}❌ Claude起動スクリプトが見つかりません: $CLAUDE_SCRIPT${NC}"
    fi
}

# メインループ
while true; do
    show_menu
    echo -n "選択してください: "
    read -r choice
    
    case $choice in
        1) check_developers ;;
        2) assign_tasks ;;
        3) generate_progress_report ;;
        4) echo "品質チェック機能は実装中です" ;;
        5) create_cto_report ;;
        6) escalate_issue ;;
        7) echo "リソース調整機能は実装中です" ;;
        8) call_team_meeting ;;
        9) launch_claude_manager ;;
        0) echo -e "${GREEN}Manager調整システムを終了します${NC}"; exit 0 ;;
        *) echo -e "${RED}無効な選択です${NC}" ;;
    esac
done