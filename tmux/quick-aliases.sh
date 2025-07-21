#!/bin/bash

# 🚀 超簡単メッセージ送信エイリアス
# source で読み込んで使用: source ./tmux/quick-aliases.sh

TMUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 色付きメッセージ関数
tmux_success() { echo -e "\033[32m✅ $1\033[0m"; }
tmux_info() { echo -e "\033[36m📋 $1\033[0m"; }

# 👔 Manager宛ショートカット
manager() {
    if [[ -n "$1" ]]; then
        tmux_info "👔 Managerに送信中..."
        "$TMUX_DIR/send-message.sh" manager "$1"
        tmux_success "👔 Manager宛メッセージ送信完了"
    else
        echo "使用例: manager \"現在の開発状況を教えてください\""
    fi
}

# 💻 開発者全員宛ショートカット
developer() {
    if [[ -n "$1" ]]; then
        tmux_info "💻 開発者全員に送信中..."
        "$TMUX_DIR/send-message.sh" broadcast "$1"
        tmux_success "💻 開発者全員宛メッセージ送信完了"
    else
        echo "使用例: developer \"バックエンドAPIの実装を開始してください\""
    fi
}

# 👑 CTO宛ショートカット
cto() {
    if [[ -n "$1" ]]; then
        tmux_info "👑 CTOに送信中..."
        "$TMUX_DIR/send-message.sh" ceo "$1"
        tmux_success "👑 CTO宛メッセージ送信完了"
    else
        echo "使用例: cto \"技術的な判断が必要です\""
    fi
}

# 🌟 全員宛ショートカット
AllMember() {
    if [[ -n "$1" ]]; then
        tmux_info "🌟 全員に送信中..."
        "$TMUX_DIR/send-message.sh" manager "$1"
        "$TMUX_DIR/send-message.sh" broadcast "$1"
        tmux_success "🌟 全員宛メッセージ送信完了"
    else
        echo "使用例: AllMember \"定時ミーティングを開始します\""
    fi
}

# 📋 Manager + Developer 階層指示ショートカット
mgr_dev() {
    if [[ -n "$1" ]]; then
        tmux_info "📋 Manager→Developer階層指示送信中..."
        local hierarchy_msg="【CTOからManager経由Developer指示】$1"
        "$TMUX_DIR/send-message.sh" manager "$hierarchy_msg"
        tmux_success "📋 Manager→Developer階層指示送信完了"
    else
        echo "使用例: mgr_dev \"バックエンドAPIの実装スケジュールを調整してください\""
    fi
}

# 🎯 Manager+Developer同時指示ショートカット
mgr_and_dev() {
    if [[ -n "$1" ]]; then
        tmux_info "🎯 Manager+Developer同時指示送信中..."
        local mgr_msg="【CTOからManager】$1"
        local dev_msg="【CTOからDeveloper】$1"
        "$TMUX_DIR/send-message.sh" manager "$mgr_msg"
        "$TMUX_DIR/send-message.sh" broadcast "$dev_msg"
        tmux_success "🎯 Manager+Developer同時指示送信完了"
    else
        echo "使用例: mgr_and_dev \"プロジェクトの進捗確認をお願いします\""
    fi
}

# 🔄 Manager経由専用指示ショートカット
via_manager() {
    if [[ -n "$1" ]]; then
        tmux_info "🔄 Manager経由Developer指示送信中..."
        local via_msg="【CTOから指示】以下をDeveloperに伝達してください: $1"
        "$TMUX_DIR/send-message.sh" manager "$via_msg"
        tmux_success "🔄 Manager経由指示送信完了"
    else
        echo "使用例: via_manager \"技術仕様変更についてDeveloperに説明してください\""
    fi
}

# 🚀 超簡単エイリアス - 直感的な短縮コマンド

# 📋 両方 - Manager・Developer両方に同時送信
both() {
    if [[ -n "$1" ]]; then
        tmux_info "🎯 両方(Manager+Developer)に同時送信中..."
        local mgr_msg="【CTOからManager】$1"
        local dev_msg="【CTOからDeveloper】$1"
        "$TMUX_DIR/send-message.sh" manager "$mgr_msg"
        "$TMUX_DIR/send-message.sh" broadcast "$dev_msg"
        tmux_success "🎯 両方への送信完了"
    else
        echo "使用例: both \"プロジェクト進捗確認をお願いします\""
    fi
}

# 🔄 経由 - Manager経由でDeveloperに指示
via() {
    if [[ -n "$1" ]]; then
        tmux_info "🔄 Manager経由指示送信中..."
        local via_msg="【CTOから指示】以下をDeveloperに伝達してください: $1"
        "$TMUX_DIR/send-message.sh" manager "$via_msg"
        tmux_success "🔄 Manager経由指示送信完了"
    else
        echo "使用例: via \"技術仕様変更についてDeveloperに説明してください\""
    fi
}

# 📋 階層 - Manager→Developer階層指示
階層() {
    if [[ -n "$1" ]]; then
        tmux_info "📋 Manager→Developer階層指示送信中..."
        local hierarchy_msg="【CTOからManager経由Developer指示】$1"
        "$TMUX_DIR/send-message.sh" manager "$hierarchy_msg"
        tmux_success "📋 Manager→Developer階層指示送信完了"
    else
        echo "使用例: 階層 \"バックエンドAPIの実装スケジュールを調整してください\""
    fi
}

# 📝 個別開発者宛ショートカット
dev0() {
    if [[ -n "$1" ]]; then
        tmux_info "💻 Dev0 (Frontend) に送信中..."
        "$TMUX_DIR/send-message.sh" dev0 "$1"
        tmux_success "💻 Dev0宛メッセージ送信完了"
    else
        echo "使用例: dev0 \"React UIコンポーネントの実装をお願いします\""
    fi
}

dev1() {
    if [[ -n "$1" ]]; then
        tmux_info "💻 Dev1 (Backend) に送信中..."
        "$TMUX_DIR/send-message.sh" dev1 "$1"
        tmux_success "💻 Dev1宛メッセージ送信完了"
    else
        echo "使用例: dev1 \"FastAPI エンドポイントの実装をお願いします\""
    fi
}

dev2() {
    if [[ -n "$1" ]]; then
        tmux_info "💻 Dev2 (QA) に送信中..."
        "$TMUX_DIR/send-message.sh" dev2 "$1"
        tmux_success "💻 Dev2宛メッセージ送信完了"
    else
        echo "使用例: dev2 \"テスト自動化の実装をお願いします\""
    fi
}

# 📋 使用方法表示
tmux_help() {
    echo "🚀✨ tmux メッセージ送信 超簡単エイリアス ✨🚀"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "📋 基本コマンド:"
    echo "  manager \"メッセージ内容\"         # 👔 Managerに送信"
    echo "  developer \"メッセージ内容\"       # 💻 開発者全員に送信"
    echo "  cto \"メッセージ内容\"             # 👑 CTOに送信"
    echo "  AllMember \"メッセージ内容\"       # 🌟 全員に送信"
    echo ""
    echo "🎯 階層的指示コマンド:"
    echo "  mgr_dev \"メッセージ内容\"         # 📋 Manager→Developer階層指示"
    echo "  mgr_and_dev \"メッセージ内容\"     # 🎯 Manager+Developer同時指示"
    echo "  via_manager \"メッセージ内容\"     # 🔄 Manager経由Developer指示"
    echo ""
    echo "🚀 超簡単エイリアス:"
    echo "  both \"メッセージ内容\"            # 🎯 両方(Manager+Developer)に同時送信"
    echo "  via \"メッセージ内容\"             # 🔄 Manager経由でDeveloperに指示"
    echo "  階層 \"メッセージ内容\"            # 📋 Manager→Developer階層指示"
    echo ""
    echo "📝 個別開発者:"
    echo "  dev0 \"メッセージ内容\"            # 💻 Dev0 (Frontend) に送信"
    echo "  dev1 \"メッセージ内容\"            # 💻 Dev1 (Backend) に送信"
    echo "  dev2 \"メッセージ内容\"            # 💻 Dev2 (QA) に送信"
    echo ""
    echo "🔄 エイリアス有効化:"
    echo "  source ./tmux/quick-aliases.sh"
    echo ""
    echo "📝 使用例:"
    echo "  manager \"現在の開発状況を教えてください\""
    echo "  both \"プロジェクト進捗確認をお願いします\"    # 超簡単！"
    echo "  via \"技術仕様変更をDeveloperに説明して\"     # 超簡単！"
    echo "  階層 \"APIスケジュールを調整してください\"    # 超簡単！"
    echo ""
    echo "💡 超簡単エイリアスの違い:"
    echo "  🎯 both: Manager・Developer両方に直接送信"
    echo "  🔄 via: Manager経由でDeveloperに伝達指示"
    echo "  📋 階層: Manager→Developer階層指示"
    echo ""
    echo "💫 一番簡単な使い方:"
    echo "  both 進捗確認        # 引用符なしでもOK！"
    echo "  via 仕様変更説明     # 引用符なしでもOK！"
    echo "  階層 スケジュール調整 # 引用符なしでもOK！"
    echo ""
}

echo "🚀✨ tmux メッセージ送信エイリアス読み込み完了 ✨🚀"
echo "使用方法: tmux_help"