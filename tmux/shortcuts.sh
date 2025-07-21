#!/bin/bash

# 🚀 tmux メッセージ送信ショートカット集
# CTOからの指示及び報告用簡単コマンド

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 色付きメッセージ関数
print_success() { echo -e "\033[32m✅ $1\033[0m"; }
print_info() { echo -e "\033[36m📋 $1\033[0m"; }
print_warn() { echo -e "\033[33m⚠️ $1\033[0m"; }

# 使用方法表示
show_usage() {
    echo "🚀✨ tmux メッセージ送信ショートカット ✨🚀"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "📋 使用方法:"
    echo "  manager: \"メッセージ内容\"      # Managerに送信"
    echo "  developer: \"メッセージ内容\"    # 開発者全員に送信"
    echo "  cto: \"メッセージ内容\"          # CTOに送信"
    echo "  AllMember: \"メッセージ内容\"    # 全員に送信"
    echo ""
    echo "📝 例:"
    echo "  manager: \"現在の開発状況を教えてください\""
    echo "  developer: \"バックエンドAPIの実装を開始してください\""
    echo "  AllMember: \"定時ミーティングを開始します\""
    echo ""
    echo "🔗 従来のコマンド:"
    echo "  ./tmux/send-message.sh manager \"メッセージ\""
    echo "  ./tmux/send-message.sh broadcast \"メッセージ\""
    echo ""
}

# メイン処理
case "$1" in
    "manager:")
        if [[ -n "$2" ]]; then
            print_info "👔 Managerに送信中..."
            "$SCRIPT_DIR/send-message.sh" manager "$2"
            print_success "👔 Manager宛メッセージ送信完了"
        else
            print_warn "メッセージ内容を指定してください"
            echo "使用例: manager: \"現在の開発状況を教えてください\""
        fi
        ;;
    "developer:")
        if [[ -n "$2" ]]; then
            print_info "💻 開発者全員に送信中..."
            "$SCRIPT_DIR/send-message.sh" broadcast "$2"
            print_success "💻 開発者全員宛メッセージ送信完了"
        else
            print_warn "メッセージ内容を指定してください"
            echo "使用例: developer: \"バックエンドAPIの実装を開始してください\""
        fi
        ;;
    "cto:")
        if [[ -n "$2" ]]; then
            print_info "👑 CTOに送信中..."
            "$SCRIPT_DIR/send-message.sh" ceo "$2"
            print_success "👑 CTO宛メッセージ送信完了"
        else
            print_warn "メッセージ内容を指定してください"
            echo "使用例: cto: \"技術的な判断が必要です\""
        fi
        ;;
    "AllMember:")
        if [[ -n "$2" ]]; then
            print_info "🌟 全員に送信中..."
            # Manager + 全開発者に送信
            "$SCRIPT_DIR/send-message.sh" manager "$2"
            "$SCRIPT_DIR/send-message.sh" broadcast "$2"
            print_success "🌟 全員宛メッセージ送信完了"
        else
            print_warn "メッセージ内容を指定してください"
            echo "使用例: AllMember: \"定時ミーティングを開始します\""
        fi
        ;;
    *)
        show_usage
        ;;
esac