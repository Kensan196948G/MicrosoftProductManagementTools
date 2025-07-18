#!/bin/bash

# 3人構成自動連携システム
# CTO → Manager → Developer → Manager → CTO の完全自動化

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SHARED_CONTEXT="$PROJECT_DIR/tmux_shared_context.md"
SEND_MESSAGE="$SCRIPT_DIR/send-message.sh"

# ログ関数
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️  $1"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1" >&2
}

# セッション検出
detect_session() {
    tmux list-sessions 2>/dev/null | grep -E "MicrosoftProductTools-Python.*3team" | head -1 | cut -d: -f1 || echo ""
}

# 共有コンテキストの更新
update_shared_context() {
    local role="$1"
    local status="$2"
    local message="$3"
    
    if [ -f "$SHARED_CONTEXT" ]; then
        # 現在時刻を更新
        sed -i "s/## 更新時刻: .*/## 更新時刻: $(date)/" "$SHARED_CONTEXT"
        
        # 役割の状態を更新
        sed -i "s/- $role: .*/- $role: $status/" "$SHARED_CONTEXT"
        
        # メッセージを追加
        echo "" >> "$SHARED_CONTEXT"
        echo "### [$role] $(date): $message" >> "$SHARED_CONTEXT"
        
        log_success "共有コンテキスト更新完了: $role -> $status"
    else
        log_error "共有コンテキストファイルが見つかりません: $SHARED_CONTEXT"
    fi
}

# 自動メッセージ送信
send_auto_message() {
    local target="$1"
    local message="$2"
    
    if [ -x "$SEND_MESSAGE" ]; then
        "$SEND_MESSAGE" "$target" "$message"
        log_success "自動メッセージ送信完了: $target"
    else
        log_error "send-message.sh が実行できません: $SEND_MESSAGE"
    fi
}

# CTO→Manager 自動連携
cto_to_manager_flow() {
    local cto_instruction="$1"
    
    log_info "CTO→Manager 自動連携開始"
    
    # 共有コンテキスト更新
    update_shared_context "CTO" "指示発行中" "Managerに技術指示を送信"
    
    # Managerに自動送信
    send_auto_message "manager" "【CTO技術指示】$cto_instruction

技術要件を分析し、Developerに具体的な実装タスクを分配してください。
完了時にはCTOに報告してください。"
    
    # CTO状態更新
    update_shared_context "CTO" "指示完了・待機中" "Manager対応待ち"
    
    log_success "CTO→Manager 自動連携完了"
}

# Manager→Developer 自動連携
manager_to_developer_flow() {
    local manager_task="$1"
    
    log_info "Manager→Developer 自動連携開始"
    
    # 共有コンテキスト更新
    update_shared_context "Manager" "タスク分配中" "Developerに実装タスクを送信"
    
    # Developerに自動送信
    send_auto_message "developer" "【Manager実装指示】$manager_task

技術仕様に従って実装してください。
完了時にはManagerに詳細な完了報告を送信してください。"
    
    # Manager状態更新
    update_shared_context "Manager" "タスク分配完了・監視中" "Developer実装監視中"
    
    log_success "Manager→Developer 自動連携完了"
}

# Developer→Manager 自動連携
developer_to_manager_flow() {
    local developer_report="$1"
    
    log_info "Developer→Manager 自動連携開始"
    
    # 共有コンテキスト更新
    update_shared_context "Developer" "完了報告中" "Managerに実装完了報告を送信"
    
    # Managerに自動送信
    send_auto_message "manager" "【Developer完了報告】$developer_report

実装が完了しました。
品質確認後、CTOに統合報告をお願いします。"
    
    # Developer状態更新
    update_shared_context "Developer" "完了報告済み・待機中" "次のタスク待機中"
    
    log_success "Developer→Manager 自動連携完了"
}

# Manager→CTO 自動連携
manager_to_cto_flow() {
    local manager_report="$1"
    
    log_info "Manager→CTO 自動連携開始"
    
    # 共有コンテキスト更新
    update_shared_context "Manager" "統合報告中" "CTOに統合報告を送信"
    
    # CTOに自動送信
    send_auto_message "cto" "【Manager統合報告】$manager_report

Developer実装完了を確認しました。
技術評価・承認をお願いします。"
    
    # Manager状態更新
    update_shared_context "Manager" "統合報告完了・待機中" "CTO承認待ち"
    
    log_success "Manager→CTO 自動連携完了"
}

# 定期監視システム
start_monitoring() {
    log_info "3人構成自動連携監視システムを開始"
    
    while true; do
        # セッション存在確認
        local session=$(detect_session)
        if [ -z "$session" ]; then
            log_error "3人構成セッションが見つかりません。監視を終了します。"
            break
        fi
        
        # 共有コンテキストの時刻を更新
        if [ -f "$SHARED_CONTEXT" ]; then
            sed -i "s/## 更新時刻: .*/## 更新時刻: $(date)/" "$SHARED_CONTEXT"
        fi
        
        # 12秒間隔で監視
        sleep 12
    done
}

# 初期化
initialize_collaboration() {
    log_info "3人構成自動連携システムを初期化"
    
    # 共有コンテキストファイルの初期化
    if [ ! -f "$SHARED_CONTEXT" ]; then
        cat > "$SHARED_CONTEXT" << EOF
# 3人構成自動連携システム - 共有コンテキスト

## 更新時刻: $(date)

## 連携フロー
CTO → Manager → Developer → Manager → CTO

## 進捗状況
- CTO: 初期化完了
- Manager: 初期化完了
- Developer: 初期化完了

## 自動連携システム
- 自動メッセージ送信: 有効
- 共有コンテキスト更新: 有効
- 定期監視: 有効

## 連携履歴
EOF
    fi
    
    # send-message.sh の実行権限設定
    chmod +x "$SEND_MESSAGE" 2>/dev/null || true
    
    log_success "3人構成自動連携システム初期化完了"
}

# メイン処理
main() {
    case "${1:-}" in
        "init")
            initialize_collaboration
            ;;
        "monitor")
            start_monitoring
            ;;
        "cto-to-manager")
            cto_to_manager_flow "$2"
            ;;
        "manager-to-developer")
            manager_to_developer_flow "$2"
            ;;
        "developer-to-manager")
            developer_to_manager_flow "$2"
            ;;
        "manager-to-cto")
            manager_to_cto_flow "$2"
            ;;
        *)
            echo "使用方法: $0 {init|monitor|cto-to-manager|manager-to-developer|developer-to-manager|manager-to-cto} [メッセージ]"
            echo ""
            echo "コマンド:"
            echo "  init                   - 自動連携システムを初期化"
            echo "  monitor                - 定期監視システムを開始"
            echo "  cto-to-manager         - CTO→Manager 自動連携"
            echo "  manager-to-developer   - Manager→Developer 自動連携"
            echo "  developer-to-manager   - Developer→Manager 自動連携"
            echo "  manager-to-cto         - Manager→CTO 自動連携"
            exit 1
            ;;
    esac
}

# エラートラップ
trap 'log_error "予期しないエラーが発生しました (行: $LINENO)"' ERR

# 実行
main "$@"