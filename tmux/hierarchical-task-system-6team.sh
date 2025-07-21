#!/bin/bash

# 🏢 6人チーム階層的AI開発管理システム v2.0
# CTO + Manager + 4Developers 専用階層的タスク分配・報告システム
# PowerShell 7専門化(Dev04) + Context7統合対応

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/hierarchical-6team-tasks.log"
REPORT_FILE="$SCRIPT_DIR/logs/6team-development-reports.log"
POWERSHELL_LOG="$SCRIPT_DIR/logs/powershell-specialist-logs.log"

# 色付きログ出力
log_info() { echo -e "\\033[36m[INFO]\\033[0m $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "\\033[32m[SUCCESS]\\033[0m $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "\\033[31m[ERROR]\\033[0m $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "\\033[33m[WARN]\\033[0m $1" | tee -a "$LOG_FILE"; }
log_powershell() { echo -e "\\033[35m[POWERSHELL]\\033[0m $1" | tee -a "$POWERSHELL_LOG"; }

# 使用方法表示
show_usage() {
    cat << EOF
🏢 6人チーム階層的AI開発管理システム v2.0

組織構造 (6人チーム特化):
  👑 CTO (ペイン0)          - 戦略決定・全体統括・技術方針
  👔 Manager (ペイン1)      - チーム管理・タスク分配・報告統合
  💻 Dev01 (ペイン2)        - Frontend/Backend開発
  💻 Dev02 (ペイン3)        - Frontend/Backend開発  
  💻 Dev03 (ペイン4)        - QA・テスト・品質保証
  🔧 Dev04 (ペイン5)        - PowerShell 7専門・Microsoft 365自動化

使用方法:
  $0 cto-directive \"全体指示内容\"        # CTO → 全チーム指示
  $0 manager-task \"管理タスク内容\"       # Manager → Developer分配
  $0 dev-assign \"開発タスク内容\"         # Developer向けタスク分配
  
専門分野別タスク分配:
  $0 frontend \"フロントエンド作業内容\"   # Dev01/Dev02対象
  $0 backend \"バックエンド作業内容\"      # Dev01/Dev02対象
  $0 qa \"QA・テスト作業内容\"             # Dev03対象
  $0 powershell \"PowerShell作業内容\"     # Dev04(PowerShell専門)対象
  $0 microsoft365 \"M365管理作業内容\"     # Dev04(Microsoft 365専門)対象
  
自動化機能:
  $0 auto-distribute \"タスク内容\"        # 自動ラウンドロビン分配
  $0 collect-reports                     # 全Developer進捗報告収集
  $0 manager-report                      # Manager統合報告作成
  $0 powershell-status                   # PowerShell専門状況確認
  
システム管理:
  $0 language-switch                     # 全員日本語切替指示  
  $0 status                              # 組織状況表示
  $0 monitor-activity                    # チーム活動監視

例:
  $0 cto-directive "Microsoft 365 Python移行プロジェクト Phase2開始"
  $0 powershell "ExchangeOnline PowerShell V3への移行作業"
  $0 microsoft365 "Microsoft Graph API統合の最新化"
  $0 collect-reports
EOF
}

# 6人チーム組織メンバー定義
get_cto_member() {
    echo "MicrosoftProductTools-6team-Context7:0:CTO-Strategic-Leader"
}

get_manager_member() {
    echo "MicrosoftProductTools-6team-Context7:1:Manager-Team-Coordinator"
}

get_developer_members() {
    echo "MicrosoftProductTools-6team-Context7:2:Developer01-FullStack"
    echo "MicrosoftProductTools-6team-Context7:3:Developer02-FullStack"
    echo "MicrosoftProductTools-6team-Context7:4:Developer03-QA-Specialist"
    echo "MicrosoftProductTools-6team-Context7:5:Developer04-PowerShell-Specialist"
}

get_frontend_developers() {
    echo "MicrosoftProductTools-6team-Context7:2:Developer01-FullStack"
    echo "MicrosoftProductTools-6team-Context7:3:Developer02-FullStack"
}

get_backend_developers() {
    echo "MicrosoftProductTools-6team-Context7:2:Developer01-FullStack"
    echo "MicrosoftProductTools-6team-Context7:3:Developer02-FullStack"
}

get_qa_specialist() {
    echo "MicrosoftProductTools-6team-Context7:4:Developer03-QA-Specialist"
}

get_powershell_specialist() {
    echo "MicrosoftProductTools-6team-Context7:5:Developer04-PowerShell-Specialist"
}

# 全メンバー取得
get_all_members() {
    get_cto_member
    get_manager_member
    get_developer_members
}

# メンバーにメッセージ送信
send_message_to_member() {
    local session_pane="$1"
    local role="$2"
    local message="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # セッション存在確認
    local session=$(echo "$session_pane" | cut -d: -f1)
    local pane=$(echo "$session_pane" | cut -d: -f2)
    
    if ! tmux has-session -t "$session" 2>/dev/null; then
        log_error "セッション '$session' が見つかりません"
        return 1
    fi
    
    log_info "送信中: $role ($session_pane) へ"
    
    # PowerShell専門者向け特別ログ
    if [[ "$role" == *"PowerShell"* ]]; then
        log_powershell "PowerShell専門タスク: $message"
    fi
    
    # メッセージ整形
    local formatted_message="【$timestamp】$message

担当役割: $role
指示者: 6人チーム階層管理システム
対応要求: 即座に作業を開始し、完了後に専門分野の詳細報告をしてください"
    
    # プロンプトクリアしてメッセージ送信
    tmux send-keys -t "$session_pane" C-c 2>/dev/null
    sleep 0.3
    tmux send-keys -t "$session_pane" C-u 2>/dev/null
    sleep 0.2
    
    # 複数行メッセージを送信
    while IFS= read -r line || [[ -n "$line" ]]; do
        tmux send-keys -t "$session_pane" "$line"
        tmux send-keys -t "$session_pane" C-m
        sleep 0.1
    done <<< "$formatted_message"
    
    sleep 0.3
    
    # ログ記録
    echo "[$timestamp] $role ($session_pane) <- $message" >> "$LOG_FILE"
    
    return 0
}

# CTOから全体への指示
cto_directive() {
    local directive="$1"
    if [[ -z "$directive" ]]; then
        log_error "CTO指示内容が指定されていません"
        return 1
    fi
    
    log_info "🏢 CTO全体指示開始: $directive"
    
    local success_count=0
    local total_count=0
    
    # Manager・Developer全員に指示
    while IFS=: read -r session pane role; do
        ((total_count++))
        local cto_directive="【CTO戦略指示】$directive

役割: この指示に基づいて各自の専門分野で作業を開始してください。
- Manager: タスク分配・進捗管理を開始
- Developer01-02: FullStack開発準備
- Developer03: QA・テスト計画策定  
- Developer04: PowerShell・Microsoft 365関連準備"
        
        if send_message_to_member "$session:$pane" "$role" "$cto_directive"; then
            ((success_count++))
        fi
        sleep 0.5
    done < <(get_manager_member; get_developer_members)
    
    log_success "CTO指示完了: $success_count/$total_count メンバーに送信完了"
}

# Manager向けタスク分配
manager_task() {
    local task="$1"
    if [[ -z "$task" ]]; then
        log_error "Managerタスクが指定されていません"
        return 1
    fi
    
    log_info "📋 Manager向けタスク分配: $task"
    
    local manager_task="【Manager専用タスク】$task

管理責任: このタスクを以下の専門分野に適切に分配してください:
- Frontend/Backend: Developer01-02
- QA・テスト: Developer03  
- PowerShell・Microsoft 365: Developer04
進捗監視し、完了後はCTOに統合報告してください。"
    
    while IFS=: read -r session pane role; do
        if send_message_to_member "$session:$pane" "$role" "$manager_task"; then
            log_success "Managerタスク分配完了: $role に送信"
            return 0
        fi
    done < <(get_manager_member)
}

# Developer向けタスク分配（ラウンドロビン）
dev_assign() {
    local task="$1"
    if [[ -z "$task" ]]; then
        log_error "Developerタスクが指定されていません"
        return 1
    fi
    
    log_info "💻 Developer向けタスク分配: $task"
    
    # Developer全員に分配（ラウンドロビン）
    local developers=($(get_developer_members))
    local last_index_file="$SCRIPT_DIR/logs/last_6team_developer_index.txt"
    local current_index=0
    
    if [[ -f "$last_index_file" ]]; then
        current_index=$(cat "$last_index_file")
        current_index=$(( (current_index + 1) % ${#developers[@]} ))
    fi
    
    local selected_dev="${developers[$current_index]}"
    local session=$(echo "$selected_dev" | cut -d: -f1-2)
    local role=$(echo "$selected_dev" | cut -d: -f3)
    
    local dev_task="【開発タスク】$task

専門領域活用: あなたの専門性を活かして実装してください。
- FullStack: Frontend/Backend統合開発
- QA: テスト計画・品質保証実装
- PowerShell: Microsoft 365自動化・PowerShellスクリプト開発
完了後はManagerに詳細な実装報告をしてください。"
    
    if send_message_to_member "$session" "$role" "$dev_task"; then
        echo "$current_index" > "$last_index_file"
        log_success "Developerタスク分配完了: $role に送信"
    fi
}

# 専門分野別タスク分配
assign_specialized_task() {
    local specialty="$1"
    local task="$2"
    
    if [[ -z "$task" ]]; then
        log_error "タスク内容が指定されていません"
        return 1
    fi
    
    local success_count=0
    
    case "$specialty" in
        "frontend")
            log_info "🎨 フロントエンド専門タスク: $task"
            while IFS=: read -r session pane role; do
                local frontend_task="【Frontend専門タスク】$task

専門領域: フロントエンド開発の専門性を最大限活用してください。
技術スタック: React, TypeScript, UI/UX, レスポンシブデザイン"
                
                if send_message_to_member "$session:$pane" "$role" "$frontend_task"; then
                    ((success_count++))
                fi
                sleep 0.3
            done < <(get_frontend_developers)
            ;;
            
        "backend")
            log_info "⚙️ バックエンド専門タスク: $task"
            while IFS=: read -r session pane role; do
                local backend_task="【Backend専門タスク】$task

専門領域: バックエンド開発の専門性を最大限活用してください。
技術スタック: Python, FastAPI, データベース, API設計"
                
                if send_message_to_member "$session:$pane" "$role" "$backend_task"; then
                    ((success_count++))
                fi
                sleep 0.3
            done < <(get_backend_developers)
            ;;
            
        "qa")
            log_info "🧪 QA・テスト専門タスク: $task"
            while IFS=: read -r session pane role; do
                local qa_task="【QA専門タスク】$task

専門領域: QA・テストの専門性を最大限活用してください。
技術スタック: pytest, テスト自動化, 品質保証, CI/CD"
                
                if send_message_to_member "$session:$pane" "$role" "$qa_task"; then
                    ((success_count++))
                    log_powershell "QA専門タスク分配: $task"
                fi
            done < <(get_qa_specialist)
            ;;
            
        "powershell")
            log_info "🔧 PowerShell専門タスク: $task"
            while IFS=: read -r session pane role; do
                local ps_task="【PowerShell専門タスク】$task

専門領域: PowerShell 7・スクリプト開発の専門性を最大限活用してください。
技術スタック: PowerShell 7, スクリプト最適化, クロスプラットフォーム対応
Context7統合: 最新PowerShell情報を自動取得して実装に活用してください"
                
                if send_message_to_member "$session:$pane" "$role" "$ps_task"; then
                    ((success_count++))
                    log_powershell "PowerShell専門タスク分配: $task"
                fi
            done < <(get_powershell_specialist)
            ;;
            
        "microsoft365")
            log_info "☁️ Microsoft 365専門タスク: $task"
            while IFS=: read -r session pane role; do
                local m365_task="【Microsoft 365専門タスク】$task

専門領域: Microsoft 365管理・自動化の専門性を最大限活用してください。
技術スタック: Microsoft Graph API, Exchange Online, Entra ID, Teams管理
Context7統合: 最新Microsoft 365情報を自動取得して実装に活用してください"
                
                if send_message_to_member "$session:$pane" "$role" "$m365_task"; then
                    ((success_count++))
                    log_powershell "Microsoft 365専門タスク分配: $task"
                fi
            done < <(get_powershell_specialist)
            ;;
            
        *)
            log_error "不明な専門分野: $specialty"
            return 1
            ;;
    esac
    
    log_success "$specialty専門タスク分配完了: $success_count 名に送信"
}

# 言語切替指示
language_switch() {
    log_info "🌐 全員日本語切替指示開始"
    
    local switch_message="【言語切替指示】日本語モードに切り替えてください

指示: 以下の手順で日本語設定に変更してください
1. 現在の作業を安全に保存
2. 日本語言語設定に変更  
3. 準備完了後に「日本語切替完了 - [あなたの専門分野]」と報告

専門分野:
- CTO: 戦略統括
- Manager: チーム管理
- Dev01-02: FullStack開発
- Dev03: QA・テスト
- Dev04: PowerShell・Microsoft 365専門"
    
    local success_count=0
    local total_count=0
    
    # 全メンバーに送信
    while IFS=: read -r session pane role; do
        ((total_count++))
        if send_message_to_member "$session:$pane" "$role" "$switch_message"; then
            ((success_count++))
        fi
        sleep 0.2
    done < <(get_all_members)
    
    log_success "言語切替指示完了: $success_count/$total_count メンバーに送信"
}

# Developer進捗報告収集
collect_reports() {
    log_info "📊 6人チーム進捗報告収集開始"
    
    local report_request="【進捗報告要求】現在の作業状況を専門分野別に詳細報告してください

報告項目:
1. 現在実施中のタスク（専門分野明記）
2. 完了した作業内容・成果物
3. 発生した技術的問題・課題
4. 次の予定作業・優先度
5. 他チームメンバーとの連携必要事項
6. サポート・リソース必要事項

フォーマット: 「【進捗報告・[専門分野]】[詳細内容]」

専門分野参考:
- FullStack開発 (Dev01-02)
- QA・テスト (Dev03)  
- PowerShell・Microsoft 365 (Dev04)"
    
    local success_count=0
    
    while IFS=: read -r session pane role; do
        if send_message_to_member "$session:$pane" "$role" "$report_request"; then
            ((success_count++))
        fi
        sleep 0.3
    done < <(get_developer_members)
    
    log_success "報告収集要求完了: $success_count 名のDeveloperに送信"
    
    # Manager報告収集担当に通知
    while IFS=: read -r session pane role; do
        send_message_to_member "$session:$pane" "$role" "【報告収集開始】全4名のDeveloperからの専門分野別進捗報告を収集し、統合レポートを作成してCTOに報告してください

専門分野統合:
- FullStack開発状況 (Dev01-02)
- QA・テスト状況 (Dev03)
- PowerShell・Microsoft 365状況 (Dev04)"
    done < <(get_manager_member)
}

# Manager統合報告作成
manager_report() {
    log_info "📈 Manager統合報告作成開始"
    
    local report_task="【統合報告作成】収集した全Developer報告を専門分野別に統合し、CTOに包括的な状況報告を作成してください

統合報告内容:
1. 6人チーム全体プロジェクト進捗状況
2. 専門分野別状況サマリー:
   - FullStack開発 (Dev01-02): フロントエンド・バックエンド統合状況
   - QA・テスト (Dev03): 品質保証・テスト実行状況  
   - PowerShell・Microsoft 365 (Dev04): 自動化・管理ツール開発状況
3. 専門分野間の連携状況・相互依存関係
4. 発生している課題・技術的リスク・解決策
5. 必要なリソース・サポート・優先度調整
6. 次期計画・マイルストーン・専門分野別目標"
    
    while IFS=: read -r session pane role; do
        send_message_to_member "$session:$pane" "$role" "$report_task"
        log_success "Manager統合報告作成指示完了"
        return 0
    done < <(get_manager_member)
}

# PowerShell専門状況確認
powershell_status() {
    log_info "🔧 PowerShell専門状況確認開始"
    
    local status_request="【PowerShell専門状況確認】PowerShell・Microsoft 365専門担当として現在の状況を詳細報告してください

確認項目:
1. PowerShell 7環境・モジュール状況
2. Microsoft Graph API統合状況
3. Exchange Online PowerShell状況
4. Microsoft 365自動化スクリプト開発状況
5. 既存PowerShellコードのPython移行対応状況
6. Context7統合活用状況・最新情報取得効果
7. 他Developerとの連携状況
8. 緊急対応・障害対応準備状況

フォーマット: 「【PowerShell専門状況】[詳細技術状況]」"
    
    while IFS=: read -r session pane role; do
        if send_message_to_member "$session:$pane" "$role" "$status_request"; then
            log_powershell "PowerShell専門状況確認要求送信"
            log_success "PowerShell専門状況確認完了"
            return 0
        fi
    done < <(get_powershell_specialist)
}

# 自動タスク分散
auto_distribute() {
    local task="$1"
    if [[ -z "$task" ]]; then
        log_error "自動分散タスクが指定されていません"
        return 1
    fi
    
    log_info "🚀 6人チーム自動タスク分散: $task"
    
    # タスク内容から適切な専門分野を自動判定
    local assigned_specialty=""
    local assigned_members=()
    
    if [[ "$task" =~ (PowerShell|powershell|PS|Microsoft|M365|Graph|Exchange|Entra) ]]; then
        assigned_specialty="PowerShell・Microsoft 365専門"
        mapfile -t assigned_members < <(get_powershell_specialist)
    elif [[ "$task" =~ (テスト|test|Test|QA|品質|quality) ]]; then
        assigned_specialty="QA・テスト専門"
        mapfile -t assigned_members < <(get_qa_specialist)
    elif [[ "$task" =~ (frontend|Frontend|フロントエンド|UI|UX|React) ]]; then
        assigned_specialty="フロントエンド専門"
        mapfile -t assigned_members < <(get_frontend_developers)
    elif [[ "$task" =~ (backend|Backend|バックエンド|API|database) ]]; then
        assigned_specialty="バックエンド専門"
        mapfile -t assigned_members < <(get_backend_developers)
    else
        # 一般開発タスクは全Developerに分散
        assigned_specialty="一般開発（ラウンドロビン分散）"
        dev_assign "$task"
        return $?
    fi
    
    log_info "🎯 自動判定結果: $assigned_specialty"
    
    for member in "${assigned_members[@]}"; do
        local session=$(echo "$member" | cut -d: -f1-2)
        local role=$(echo "$member" | cut -d: -f3)
        
        local auto_task="【自動分散タスク・$assigned_specialty】$task

自動判定: このタスクはあなたの専門分野に適合すると判定されました。
専門性活用: あなたの技術的専門知識を最大限活用して実装してください。
Context7統合: 必要に応じて最新技術情報を自動取得して活用してください。"
        
        if send_message_to_member "$session" "$role" "$auto_task"; then
            log_success "自動分散完了: $role ($assigned_specialty)"
        fi
        sleep 0.5
    done
}

# チーム活動監視
monitor_activity() {
    log_info "👀 6人チーム活動監視開始"
    
    local current_time=$(date +%s)
    local inactive_threshold=1800  # 30分
    local warning_sent=false
    
    while IFS=: read -r session pane role; do
        # tmuxペイン活動状況をチェック
        local pane_activity=$(tmux display-message -t "$session:$pane" -p "#{pane_last_activity}" 2>/dev/null || echo "0")
        
        if [[ "$pane_activity" != "0" ]]; then
            local time_diff=$((current_time - pane_activity))
            local minutes_ago=$((time_diff / 60))
            
            if [[ $time_diff -gt $inactive_threshold ]]; then
                log_warn "⚠️ $role: 最後のアクティビティから${minutes_ago}分経過"
                
                # PowerShell専門者の場合は特別監視
                if [[ "$role" == *"PowerShell"* ]]; then
                    log_powershell "PowerShell専門者非アクティブ警告: ${minutes_ago}分"
                fi
                
                # 非アクティブメンバーにping送信
                send_message_to_member "$session:$pane" "$role" "【活動確認ping】現在の状況・作業状態を教えてください。専門分野での作業継続状況をお知らせください。"
                warning_sent=true
            else
                log_info "✅ $role: アクティブ (${minutes_ago}分前)"
            fi
        else
            log_warn "⚠️ $role: アクティビティ情報取得不可"
        fi
        
        sleep 1
    done < <(get_all_members)
    
    if [[ "$warning_sent" == true ]]; then
        log_warn "非アクティブメンバーに活動確認pingを送信しました"
    else
        log_success "全メンバーがアクティブです"
    fi
}

# 組織状況表示
show_status() {
    echo "🏢 6人チーム階層的AI開発システム - 組織状況"
    echo "=============================================="
    
    echo ""
    echo "👑 CTO (1ペイン) - 戦略決定・技術方針・全体統括"
    while IFS=: read -r session pane role; do
        echo "  • $session:$pane - $role"
    done < <(get_cto_member)
    
    echo ""
    echo "👔 Manager (1ペイン) - チーム管理・タスク分配・報告統合"
    while IFS=: read -r session pane role; do
        echo "  • $session:$pane - $role"
    done < <(get_manager_member)
    
    echo ""
    echo "💻 Developer (4ペイン) - 専門開発・分野別実装"
    while IFS=: read -r session pane role; do
        if [[ "$role" == *"PowerShell"* ]]; then
            echo "  • $session:$pane - $role ⭐ PowerShell・Microsoft 365専門"
        elif [[ "$role" == *"QA"* ]]; then
            echo "  • $session:$pane - $role ⭐ QA・テスト専門"
        else
            echo "  • $session:$pane - $role ⭐ FullStack開発"
        fi
    done < <(get_developer_members)
    
    echo ""
    echo "📊 最近の活動 (直近5件):"
    if [[ -f "$LOG_FILE" ]]; then
        tail -5 "$LOG_FILE" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  活動履歴なし"
    fi
    
    echo ""
    echo "🔧 PowerShell専門ログ (直近3件):"
    if [[ -f "$POWERSHELL_LOG" ]]; then
        tail -3 "$POWERSHELL_LOG" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  PowerShell専門活動履歴なし"
    fi
}

# ログディレクトリ作成
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$REPORT_FILE")"
mkdir -p "$(dirname "$POWERSHELL_LOG")"

# メイン処理
main() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] 6人チーム階層的タスクシステム実行: $*" >> "$LOG_FILE"
    
    case "${1:-}" in
        "cto-directive")
            cto_directive "$2"
            ;;
        "manager-task")
            manager_task "$2"
            ;;
        "dev-assign")
            dev_assign "$2"
            ;;
        "frontend")
            assign_specialized_task "frontend" "$2"
            ;;
        "backend")
            assign_specialized_task "backend" "$2"
            ;;
        "qa")
            assign_specialized_task "qa" "$2"
            ;;
        "powershell")
            assign_specialized_task "powershell" "$2"
            ;;
        "microsoft365")
            assign_specialized_task "microsoft365" "$2"
            ;;
        "auto-distribute")
            auto_distribute "$2"
            ;;
        "language-switch")
            language_switch
            ;;
        "collect-reports")
            collect_reports
            ;;
        "manager-report")
            manager_report
            ;;
        "powershell-status")
            powershell_status
            ;;
        "monitor-activity")
            monitor_activity
            ;;
        "status")
            show_status
            ;;
        "--help"|"-h"|"")
            show_usage
            ;;
        *)
            log_error "不明なコマンド: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"