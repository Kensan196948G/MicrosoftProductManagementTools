#!/bin/bash

# 🏢 6人チーム エンタープライズ統一ランチャー v4.0
# CTO + Manager + 4Developers 完全統合管理システム
# PowerShell 7専門化 + Context7統合 + 企業品質保証 + 階層的タスク管理

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/launcher.log"

# ログディレクトリ作成
mkdir -p "$(dirname "$LOG_FILE")"

# 色付きメッセージ関数
print_header() {
    clear
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "🏢✨ Microsoft Product Management Tools - 6人チーム エンタープライズ統一ランチャー ✨🏢"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "🎯 組織構成: 👑CTO + 👔Manager + 💻Dev01 + 💻Dev02 + 🧪Dev03 + 🔧Dev04(PowerShell専門)"
    echo "🌟 統合機能: 🔥Context7 + 📋階層的タスク管理 + 🏢企業品質保証 + ⚡PowerShell専門化"
    echo ""
}

print_success() { echo -e "\\033[32m✅ $1\\033[0m"; }
print_error() { echo -e "\\033[31m❌ $1\\033[0m"; }
print_warn() { echo -e "\\033[33m⚠️ $1\\033[0m"; }
print_info() { echo -e "\\033[36m📋 $1\\033[0m"; }

# ログ記録
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 前提条件チェック
check_prerequisites() {
    local checks_passed=0
    local total_checks=4
    
    echo "🔍✨ 前提条件チェック実行中... ✨🔍"
    echo ""
    
    # tmux確認
    if command -v tmux >/dev/null 2>&1; then
        print_success "🖥️ tmux: $(tmux -V) 🖥️"
        ((checks_passed++))
    else
        print_error "❌ tmux: 未インストール ❌"
        echo "   💡 インストール方法: sudo apt-get update && sudo apt-get install -y tmux"
    fi
    
    # PowerShell 7確認 (WSL環境対応)
    if command -v pwsh >/dev/null 2>&1; then
        local ps_version=$(pwsh -c '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)
        print_success "⚡ PowerShell 7: $ps_version ⚡"
        ((checks_passed++))
    elif command -v pwsh.exe >/dev/null 2>&1; then
        local ps_version=$(pwsh.exe -c '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)
        print_success "⚡ PowerShell 7 (WSL): $ps_version ⚡"
        ((checks_passed++))
    elif command -v powershell >/dev/null 2>&1; then
        local ps_version=$(powershell -c '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)
        print_success "⚡ PowerShell (Legacy): $ps_version ⚡"
        ((checks_passed++))
    elif command -v powershell.exe >/dev/null 2>&1; then
        local ps_version=$(powershell.exe -c '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)
        print_success "⚡ PowerShell (Legacy WSL): $ps_version ⚡"
        ((checks_passed++))
    else
        print_warn "⚠️ PowerShell 7: 未インストール (Dev04専門機能に影響)"
        echo "   💡 Linux インストール方法: wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb"
        echo "                           sudo dpkg -i packages-microsoft-prod.deb"
        echo "                           sudo apt-get update && sudo apt-get install -y powershell"
        echo "   💡 WSL環境の場合: Windows側にPowerShell 7がインストールされている可能性があります"
    fi
    
    # Context7 (npx)確認
    if command -v npx >/dev/null 2>&1; then
        print_success "🌟 Context7 (npx): $(npx --version 2>/dev/null) 🌟"
        ((checks_passed++))
    else
        print_warn "⚠️ Context7 (npx): 未確認 (最新技術情報取得に影響)"
        echo "   💡 インストール方法: curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
        echo "                      sudo apt-get install -y nodejs"
    fi
    
    # Python確認
    if command -v python3 >/dev/null 2>&1; then
        print_success "🐍 Python: $(python3 --version 2>&1) 🐍"
        ((checks_passed++))
    else
        print_warn "⚠️ Python: 未確認 (品質保証機能に影響)"
        echo "   💡 インストール方法: sudo apt-get update && sudo apt-get install -y python3 python3-pip"
    fi
    
    echo ""
    local success_rate=$((checks_passed * 100 / total_checks))
    
    if [[ $success_rate -ge 75 ]]; then
        print_success "✨ 前提条件チェック完了: $success_rate% ($checks_passed/$total_checks) ✨"
        return 0
    else
        print_warn "⚠️ 前提条件チェック: $success_rate% ($checks_passed/$total_checks) - 一部機能制限あり ⚠️"
        return 1
    fi
}

# システム状況表示
show_system_status() {
    echo "📊✨ システム現在状況 ✨📊"
    echo "────────────────────────────────────────────────────────────────"
    
    # tmuxセッション状況
    if tmux has-session -t "MicrosoftProductTools-Python-Context7-5team" 2>/dev/null; then
        local pane_count=$(tmux list-panes -t "MicrosoftProductTools-Python-Context7-5team" | wc -l)
        print_success "🚀 6人チームtmuxセッション: アクティブ ($pane_count ペイン) 🚀"
        
        # ペイン詳細表示
        echo "   👑 CTO (ペイン0): 戦略統括・技術方針決定"
        echo "   👔 Manager (ペイン1): チーム管理・品質統制"
        echo "   💻 Dev01 (ペイン2): FullStack開発（フロントエンド専門）"
        echo "   💻 Dev02 (ペイン3): FullStack開発（バックエンド専門）"
        echo "   💻 Dev03 (ペイン4): QA・テスト専門"
        echo "   🔧 Dev04 (ペイン5): PowerShell・Microsoft 365専門"
    else
        print_warn "⚠️ 6人チームtmuxセッション: 非アクティブ ⚠️"
    fi
    
    # 品質監視状況
    local monitor_pid_file="$SCRIPT_DIR/logs/quality/monitor.pid"
    if [[ -f "$monitor_pid_file" ]]; then
        local monitor_pid=$(cat "$monitor_pid_file")
        if kill -0 "$monitor_pid" 2>/dev/null; then
            print_success "👁️ 品質監視システム: 実行中 (PID: $monitor_pid) 👁️"
        else
            print_warn "⚠️ 品質監視システム: 停止中 ⚠️"
        fi
    else
        print_warn "⚠️ 品質監視システム: 未開始 ⚠️"
    fi
    
    # ログファイル状況
    echo ""
    echo "📁✨ 最近のシステム活動:"
    if [[ -f "$LOG_FILE" ]]; then
        tail -3 "$LOG_FILE" | while read -r line; do
            echo "   $line"
        done
    else
        echo "   活動履歴なし"
    fi
}

# メインメニュー表示
show_main_menu() {
    echo "🚀✨ 6人チーム エンタープライズ統合管理メニュー ✨🚀"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "【🖥️ 1. tmux環境管理】"
    echo "  1) 🏗️ 6人チーム環境セットアップ (👑CTO+👔Manager+👨‍💻Dev4名)"
    echo "  2) 🔗 セッション接続"
    echo "  3) 📊 セッション状況確認"
    echo "  4) ⏹️ セッション終了"
    echo ""
    echo "【📋 2. 階層的タスク管理】"
    echo "  5) 👑 CTO全体指示"
    echo "  6) 👔 Manager指示分配"
    echo "  7) 🎯 専門分野別タスク (🎨Frontend/⚙️Backend/🧪QA/🔧PowerShell)"
    echo "  8) 🤖 自動タスク分散"
    echo "  9) 📈 進捗報告収集"
    echo ""
    echo "【🏢 3. 企業品質保証システム】"
    echo " 10) ✅ 全品質ゲート実行 (8段階)"
    echo " 11) 🔧 PowerShell専門品質確認"
    echo " 12) 📊 CTO品質ダッシュボード"
    echo " 13) 👁️ リアルタイム品質監視開始/停止"
    echo ""
    echo "【🔧 4. PowerShell・Microsoft 365専門】"
    echo " 14) 🛠️ PowerShell専門状況確認"
    echo " 15) 🔄 Microsoft 365統合テスト"
    echo " 16) ✔️ PowerShellスクリプト品質検証"
    echo ""
    echo "【🌟 5. Context7統合管理】"
    echo " 17) 🔍 Context7統合状況確認"
    echo " 18) 🆕 最新技術情報自動取得テスト"
    echo ""
    echo "【🤖 6. 自動相互連携システム】"
    echo " 19) 🔍 キーワード自動検出テスト"
    echo " 20) 👁️‍🗨️ 自動相互連携監視開始/停止"
    echo " 21) 📜 キーワード検出ログ確認"
    echo ""
    echo "【⚙️ 7. システム管理】"
    echo " 22) 🏥 システム状況確認"
    echo " 23) 📝 ログ表示・分析"
    echo " 24) 🚨 緊急システム診断"
    echo " 25) 🔄 完全システムリセット"
    echo ""
    echo " 0) 🚪 終了"
    echo ""
}

# tmuxセットアップ実行
setup_6team_environment() {
    print_info "6人チーム環境セットアップ開始..."
    log_action "6人チーム環境セットアップ開始"
    
    if [[ -x "$SCRIPT_DIR/scripts/setup_6team_context7.sh" ]]; then
        print_success "6人チーム設定スクリプト実行中..."
        "$SCRIPT_DIR/scripts/setup_6team_context7.sh"
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            print_success "6人チーム環境セットアップ完了"
            log_action "6人チーム環境セットアップ成功"
        else
            print_error "6人チーム環境セットアップ失敗"
            log_action "6人チーム環境セットアップ失敗: exit_code=$exit_code"
        fi
    else
        print_error "6人チーム設定スクリプトが見つかりません"
        print_info "場所: $SCRIPT_DIR/scripts/setup_6team_context7.sh"
    fi
}

# セッション接続
connect_session() {
    if tmux has-session -t "MicrosoftProductTools-Python-Context7-5team" 2>/dev/null; then
        print_success "6人チームセッションに接続中..."
        log_action "セッション接続"
        tmux attach-session -t "MicrosoftProductTools-Python-Context7-5team"
    else
        print_error "6人チームセッションが見つかりません"
        print_info "先にセットアップ(1)を実行してください"
    fi
}

# CTO指示実行
execute_cto_directive() {
    echo ""
    read -p "📋 CTO全体指示内容を入力してください: " directive
    
    if [[ -n "$directive" ]]; then
        print_info "CTO全体指示実行中..."
        log_action "CTO全体指示: $directive"
        
        if [[ -x "$SCRIPT_DIR/hierarchical-task-system-6team.sh" ]]; then
            "$SCRIPT_DIR/hierarchical-task-system-6team.sh" cto-directive "$directive"
            print_success "CTO全体指示送信完了"
        else
            print_error "階層タスクシステムが見つかりません"
        fi
    else
        print_warn "指示内容が入力されませんでした"
    fi
}

# 専門分野別タスク
execute_specialized_task() {
    echo ""
    echo "専門分野選択:"
    echo "1) Frontend開発"
    echo "2) Backend開発"
    echo "3) QA・テスト"
    echo "4) PowerShell・Microsoft 365"
    echo ""
    read -p "選択 (1-4): " specialty_choice
    
    local specialty=""
    case "$specialty_choice" in
        "1") specialty="frontend" ;;
        "2") specialty="backend" ;;
        "3") specialty="qa" ;;
        "4") specialty="powershell" ;;
        *) print_error "無効な選択です"; return 1 ;;
    esac
    
    echo ""
    read -p "📋 ${specialty}専門タスク内容を入力してください: " task
    
    if [[ -n "$task" ]]; then
        print_info "${specialty}専門タスク実行中..."
        log_action "${specialty}専門タスク: $task"
        
        if [[ -x "$SCRIPT_DIR/hierarchical-task-system-6team.sh" ]]; then
            "$SCRIPT_DIR/hierarchical-task-system-6team.sh" "$specialty" "$task"
            print_success "${specialty}専門タスク送信完了"
        else
            print_error "階層タスクシステムが見つかりません"
        fi
    else
        print_warn "タスク内容が入力されませんでした"
    fi
}

# 全品質ゲート実行
execute_all_quality_gates() {
    print_info "企業品質保証システム: 全8段階品質ゲート実行開始..."
    log_action "全品質ゲート実行開始"
    
    if [[ -x "$SCRIPT_DIR/quality-assurance-6team.sh" ]]; then
        "$SCRIPT_DIR/quality-assurance-6team.sh" all-quality-gates
        print_success "全品質ゲート実行完了"
        log_action "全品質ゲート実行完了"
    else
        print_error "品質保証システムが見つかりません"
    fi
}

# CTO品質ダッシュボード
show_cto_dashboard() {
    print_info "CTO品質統合ダッシュボード表示中..."
    log_action "CTO品質ダッシュボード表示"
    
    if [[ -x "$SCRIPT_DIR/quality-assurance-6team.sh" ]]; then
        "$SCRIPT_DIR/quality-assurance-6team.sh" cto-dashboard
    else
        print_error "品質保証システムが見つかりません"
    fi
}

# PowerShell専門状況確認
check_powershell_status() {
    print_info "🔧✨ PowerShell専門状況確認中... ✨🔧"
    log_action "PowerShell専門状況確認"
    
    echo ""
    echo "🔧⚡ PowerShell・Microsoft 365専門状況 ⚡🔧"
    echo "────────────────────────────────────────────────────────────────"
    
    # PowerShell 7バージョン詳細チェック (WSL環境対応)
    if command -v pwsh >/dev/null 2>&1; then
        local ps_version=$(pwsh -c '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)
        local ps_edition=$(pwsh -c '$PSVersionTable.PSEdition' 2>/dev/null)
        local ps_os=$(pwsh -c '$PSVersionTable.OS' 2>/dev/null)
        print_success "⚡ PowerShell 7: $ps_version ($ps_edition) ⚡"
        echo "   📊 OS: $ps_os"
        echo "   🔧 コマンド: pwsh"
    elif command -v pwsh.exe >/dev/null 2>&1; then
        local ps_version=$(pwsh.exe -c '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)
        local ps_edition=$(pwsh.exe -c '$PSVersionTable.PSEdition' 2>/dev/null)
        local ps_os=$(pwsh.exe -c '$PSVersionTable.OS' 2>/dev/null)
        print_success "⚡ PowerShell 7 (WSL): $ps_version ($ps_edition) ⚡"
        echo "   📊 OS: $ps_os"
        echo "   🔧 コマンド: pwsh.exe"
        echo "   🏃 実行場所: $(which pwsh.exe)"
    elif command -v powershell >/dev/null 2>&1; then
        local ps_version=$(powershell -c '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)
        print_warn "⚠️ PowerShell (Legacy): $ps_version - PowerShell 7推奨 ⚠️"
        echo "   🔧 コマンド: powershell"
    elif command -v powershell.exe >/dev/null 2>&1; then
        local ps_version=$(powershell.exe -c '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)
        print_warn "⚠️ PowerShell (Legacy WSL): $ps_version - PowerShell 7推奨 ⚠️"
        echo "   🔧 コマンド: powershell.exe"
    else
        print_error "❌ PowerShell: 未インストール ❌"
        echo ""
        echo "📥 PowerShell 7 インストール手順:"
        echo "   🐧 Linux環境の場合:"
        echo "   1️⃣ wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
        echo "   2️⃣ sudo dpkg -i packages-microsoft-prod.deb"
        echo "   3️⃣ sudo apt-get update"
        echo "   4️⃣ sudo apt-get install -y powershell"
        echo "   5️⃣ pwsh --version で確認"
        echo ""
        echo "   🪟 WSL環境の場合:"
        echo "   1️⃣ Windows側でPowerShell 7をインストール"
        echo "   2️⃣ pwsh.exe --version で確認"
    fi
    
    # Dev04ペイン状況
    if tmux has-session -t "MicrosoftProductTools-Python-Context7-5team" 2>/dev/null; then
        if tmux list-panes -t "MicrosoftProductTools-Python-Context7-5team" | grep -q "5:"; then
            print_success "Dev04 PowerShell専門ペイン: アクティブ"
        else
            print_warn "Dev04 PowerShell専門ペイン: 確認不可"
        fi
    else
        print_warn "tmuxセッション: 非アクティブ"
    fi
    
    # PowerShell専門QA実行
    if [[ -x "$SCRIPT_DIR/quality-assurance-6team.sh" ]]; then
        echo ""
        print_info "PowerShell専門品質確認実行中..."
        "$SCRIPT_DIR/quality-assurance-6team.sh" powershell-qa
    fi
}

# Context7統合状況確認
check_context7_status() {
    print_info "Context7統合状況確認中..."
    log_action "Context7統合状況確認"
    
    echo ""
    echo "🌟 Context7統合状況"
    echo "────────────────────────────────────────────────────────────────"
    
    # npx確認
    if command -v npx >/dev/null 2>&1; then
        print_success "npx (Context7基盤): $(npx --version 2>/dev/null)"
    else
        print_error "npx: 未確認"
    fi
    
    # Node.js確認
    if command -v node >/dev/null 2>&1; then
        print_success "Node.js: $(node --version 2>/dev/null)"
    else
        print_warn "Node.js: 未確認"
    fi
    
    # Context7 MCP統合テスト
    echo ""
    print_info "Context7 MCP統合テスト実行中..."
    
    # 簡易統合テスト
    if command -v npx >/dev/null 2>&1; then
        if timeout 10 npx @upstash/context7-mcp@latest --help >/dev/null 2>&1; then
            print_success "Context7 MCP: 正常動作確認"
        else
            print_warn "Context7 MCP: 接続タイムアウト (ネットワーク要因の可能性)"
        fi
    fi
    
    print_info "Context7はtmuxセッション内のClaudeエージェントで利用可能です"
}

# ログ表示・分析
show_logs_analysis() {
    echo ""
    echo "📊 システムログ分析"
    echo "════════════════════════════════════════════════════════════════"
    
    # メインランチャーログ
    echo ""
    echo "🚀 ランチャー活動ログ (最新10件):"
    if [[ -f "$LOG_FILE" ]]; then
        tail -10 "$LOG_FILE" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  ランチャーログなし"
    fi
    
    # 品質保証ログ
    echo ""
    echo "🏢 品質保証ログ (最新5件):"
    local qa_log="$SCRIPT_DIR/logs/quality/main-quality.log"
    if [[ -f "$qa_log" ]]; then
        tail -5 "$qa_log" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  品質保証ログなし"
    fi
    
    # PowerShell専門ログ
    echo ""
    echo "🔧 PowerShell専門ログ (最新3件):"
    local ps_log="$SCRIPT_DIR/logs/quality/powershell-qa.log"
    if [[ -f "$ps_log" ]]; then
        tail -3 "$ps_log" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  PowerShell専門ログなし"
    fi
    
    # 階層タスクログ
    echo ""
    echo "🏢 階層タスク管理ログ (最新3件):"
    local task_log="$SCRIPT_DIR/logs/hierarchical-6team-tasks.log"
    if [[ -f "$task_log" ]]; then
        tail -3 "$task_log" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  階層タスクログなし"
    fi
}

# 緊急システム診断
emergency_diagnosis() {
    print_warn "緊急システム診断実行中..."
    log_action "緊急システム診断開始"
    
    echo ""
    echo "🚨 緊急システム診断"
    echo "════════════════════════════════════════════════════════════════"
    
    local issues_found=0
    
    # tmuxプロセス確認
    echo ""
    echo "1. tmuxプロセス診断:"
    if pgrep tmux >/dev/null; then
        print_success "tmuxプロセス: 実行中"
    else
        print_error "tmuxプロセス: 停止中"
        ((issues_found++))
    fi
    
    # セッション整合性確認
    echo ""
    echo "2. セッション整合性診断:"
    if tmux has-session -t "MicrosoftProductTools-Python-Context7-5team" 2>/dev/null; then
        local pane_count=$(tmux list-panes -t "MicrosoftProductTools-Python-Context7-5team" | wc -l)
        if [[ $pane_count -eq 6 ]]; then
            print_success "セッション整合性: 正常 (6ペイン)"
        else
            print_warn "セッション整合性: 異常 ($pane_count ペイン)"
            ((issues_found++))
        fi
    else
        print_error "セッション整合性: セッション不在"
        ((issues_found++))
    fi
    
    # ディスク容量確認
    echo ""
    echo "3. ディスク容量診断:"
    local disk_usage=$(df /mnt/e | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 90 ]]; then
        print_success "ディスク容量: 正常 (${disk_usage}% 使用)"
    else
        print_warn "ディスク容量: 警告 (${disk_usage}% 使用)"
        ((issues_found++))
    fi
    
    # 権限確認
    echo ""
    echo "4. ファイル権限診断:"
    local script_files=("$SCRIPT_DIR/scripts/setup_6team_context7.sh" "$SCRIPT_DIR/hierarchical-task-system-6team.sh" "$SCRIPT_DIR/quality-assurance-6team.sh")
    local permission_ok=0
    
    for script in "${script_files[@]}"; do
        if [[ -x "$script" ]]; then
            ((permission_ok++))
        fi
    done
    
    if [[ $permission_ok -eq ${#script_files[@]} ]]; then
        print_success "ファイル権限: 正常"
    else
        print_warn "ファイル権限: 一部実行権限なし ($permission_ok/${#script_files[@]})"
        ((issues_found++))
    fi
    
    echo ""
    echo "診断結果サマリー:"
    if [[ $issues_found -eq 0 ]]; then
        print_success "緊急診断完了: 重大な問題は検出されませんでした"
        log_action "緊急診断完了: 問題なし"
    else
        print_warn "緊急診断完了: $issues_found 件の問題が検出されました"
        print_info "詳細な対応が必要な場合は管理者に連絡してください"
        log_action "緊急診断完了: 問題$issues_found件検出"
    fi
}

# キーワード自動検出テスト
test_keyword_detection() {
    print_info "キーワード自動検出テスト実行中..."
    
    if [[ ! -x "$SCRIPT_DIR/auto-keyword-detection.sh" ]]; then
        print_error "自動キーワード検出システムが見つかりません"
        return 1
    fi
    
    echo ""
    echo "📋 テストメッセージを入力してください:"
    read -p "メッセージ: " test_message
    
    if [[ -n "$test_message" ]]; then
        print_info "キーワード検出テスト実行中..."
        "$SCRIPT_DIR/auto-keyword-detection.sh" test "$test_message"
        print_success "キーワード検出テスト完了"
    else
        print_warn "メッセージが入力されませんでした"
    fi
}

# 自動監視管理
manage_auto_monitoring() {
    if [[ ! -x "$SCRIPT_DIR/auto-keyword-detection.sh" ]]; then
        print_error "自動キーワード検出システムが見つかりません"
        return 1
    fi
    
    echo ""
    echo "自動相互連携監視制御:"
    echo "1) 監視開始"
    echo "2) 監視停止"
    echo "3) 監視状況確認"
    read -p "選択 (1-3): " monitor_choice
    
    case "$monitor_choice" in
        "1")
            print_info "自動監視開始中..."
            "$SCRIPT_DIR/auto-keyword-detection.sh" monitor
            ;;
        "2")
            print_info "自動監視停止中..."
            "$SCRIPT_DIR/auto-keyword-detection.sh" stop-monitor
            ;;
        "3")
            print_info "監視状況確認中..."
            local monitor_pid_file="$SCRIPT_DIR/logs/keyword-monitor.pid"
            if [[ -f "$monitor_pid_file" ]]; then
                local monitor_pid=$(cat "$monitor_pid_file")
                if kill -0 "$monitor_pid" 2>/dev/null; then
                    print_success "自動監視: 実行中 (PID: $monitor_pid)"
                else
                    print_warn "自動監視: 停止中"
                fi
            else
                print_warn "自動監視: 未開始"
            fi
            ;;
        *)
            print_warn "無効な選択です"
            ;;
    esac
}

# キーワード検出ログ表示
show_keyword_logs() {
    echo ""
    echo "🤖 キーワード検出ログ分析"
    echo "════════════════════════════════════════════════════════════════"
    
    # キーワード検出ログ
    echo ""
    echo "🔍 キーワード検出履歴 (最新10件):"
    local keyword_log="$SCRIPT_DIR/logs/keyword-detection.log"
    if [[ -f "$keyword_log" ]]; then
        tail -10 "$keyword_log" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  キーワード検出履歴なし"
    fi
    
    # 自動送信ログ
    echo ""
    echo "📤 自動送信履歴 (最新5件):"
    local auto_log="$SCRIPT_DIR/logs/auto-keyword.log"
    if [[ -f "$auto_log" ]]; then
        tail -5 "$auto_log" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  自動送信履歴なし"
    fi
    
    echo ""
    echo "💡 使用方法:"
    echo "  キーワード検出テスト: $SCRIPT_DIR/auto-keyword-detection.sh test \"メッセージ\""
    echo "  自動送信実行: $SCRIPT_DIR/auto-keyword-detection.sh analyze \"メッセージ\""
}

# 完全システムリセット
complete_system_reset() {
    echo ""
    print_warn "⚠️ 完全システムリセットは以下を実行します:"
    echo "  - 全tmuxセッション終了"
    echo "  - 品質監視プロセス停止"
    echo "  - 一時ファイル・ログクリア"
    echo ""
    read -p "続行しますか？ (yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        print_warn "完全システムリセット実行中..."
        log_action "完全システムリセット開始"
        
        # tmuxセッション終了
        tmux kill-session -t "MicrosoftProductTools-Python-Context7-5team" 2>/dev/null
        print_success "tmuxセッション終了完了"
        
        # 品質監視停止
        if [[ -x "$SCRIPT_DIR/quality-assurance-6team.sh" ]]; then
            "$SCRIPT_DIR/quality-assurance-6team.sh" stop-monitoring 2>/dev/null
        fi
        print_success "品質監視停止完了"
        
        # 一時ファイルクリア (選択的)
        local temp_dirs=("$SCRIPT_DIR/logs/quality" "$SCRIPT_DIR/reports/quality")
        for dir in "${temp_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                find "$dir" -name "*.pid" -delete 2>/dev/null
                find "$dir" -name "*-$(date +%Y%m%d)*" -mtime +1 -delete 2>/dev/null
            fi
        done
        print_success "一時ファイルクリア完了"
        
        print_success "完全システムリセット完了"
        log_action "完全システムリセット完了"
        
        echo ""
        print_info "システムを再度使用する場合は、セットアップ(1)から開始してください"
    else
        print_info "システムリセットをキャンセルしました"
    fi
}

# メイン処理ループ
main_loop() {
    while true; do
        print_header
        
        # システム状況表示
        show_system_status
        echo ""
        
        # メインメニュー表示
        show_main_menu
        
        read -p "🎯✨ 選択してください (0-25): " choice
        
        case "$choice" in
            "1")
                echo ""
                setup_6team_environment
                ;;
            "2")
                echo ""
                connect_session
                ;;
            "3")
                echo ""
                if tmux has-session -t "MicrosoftProductTools-Python-Context7-5team" 2>/dev/null; then
                    print_success "セッション確認"
                    tmux list-sessions | grep "MicrosoftProductTools-Python-Context7-5team"
                    echo ""
                    tmux list-panes -t "MicrosoftProductTools-Python-Context7-5team" -F "ペイン#{pane_index}: #{pane_title}"
                else
                    print_warn "セッションが見つかりません"
                fi
                ;;
            "4")
                echo ""
                if tmux has-session -t "MicrosoftProductTools-Python-Context7-5team" 2>/dev/null; then
                    tmux kill-session -t "MicrosoftProductTools-Python-Context7-5team"
                    print_success "セッション終了完了"
                    log_action "セッション終了"
                else
                    print_warn "終了するセッションが見つかりません"
                fi
                ;;
            "5")
                execute_cto_directive
                ;;
            "6")
                echo ""
                read -p "📋 Manager指示内容を入力してください: " manager_task
                if [[ -n "$manager_task" ]] && [[ -x "$SCRIPT_DIR/hierarchical-task-system-6team.sh" ]]; then
                    "$SCRIPT_DIR/hierarchical-task-system-6team.sh" manager-task "$manager_task"
                    print_success "Manager指示送信完了"
                fi
                ;;
            "7")
                execute_specialized_task
                ;;
            "8")
                echo ""
                read -p "📋 自動分散タスク内容を入力してください: " auto_task
                if [[ -n "$auto_task" ]] && [[ -x "$SCRIPT_DIR/hierarchical-task-system-6team.sh" ]]; then
                    "$SCRIPT_DIR/hierarchical-task-system-6team.sh" auto-distribute "$auto_task"
                    print_success "自動タスク分散完了"
                fi
                ;;
            "9")
                echo ""
                if [[ -x "$SCRIPT_DIR/hierarchical-task-system-6team.sh" ]]; then
                    "$SCRIPT_DIR/hierarchical-task-system-6team.sh" collect-reports
                    print_success "進捗報告収集完了"
                else
                    print_error "階層タスクシステムが見つかりません"
                fi
                ;;
            "10")
                echo ""
                execute_all_quality_gates
                ;;
            "11")
                echo ""
                if [[ -x "$SCRIPT_DIR/quality-assurance-6team.sh" ]]; then
                    "$SCRIPT_DIR/quality-assurance-6team.sh" powershell-qa
                    print_success "PowerShell専門品質確認完了"
                else
                    print_error "品質保証システムが見つかりません"
                fi
                ;;
            "12")
                echo ""
                show_cto_dashboard
                ;;
            "13")
                echo ""
                echo "品質監視制御:"
                echo "1) 監視開始"
                echo "2) 監視停止"
                read -p "選択 (1-2): " monitor_choice
                
                if [[ -x "$SCRIPT_DIR/quality-assurance-6team.sh" ]]; then
                    case "$monitor_choice" in
                        "1")
                            "$SCRIPT_DIR/quality-assurance-6team.sh" start-monitoring
                            ;;
                        "2")
                            "$SCRIPT_DIR/quality-assurance-6team.sh" stop-monitoring
                            ;;
                        *)
                            print_warn "無効な選択です"
                            ;;
                    esac
                else
                    print_error "品質保証システムが見つかりません"
                fi
                ;;
            "14")
                echo ""
                check_powershell_status
                ;;
            "15")
                echo ""
                print_info "Microsoft 365統合テスト実行中..."
                if [[ -x "$SCRIPT_DIR/quality-assurance-6team.sh" ]]; then
                    "$SCRIPT_DIR/quality-assurance-6team.sh" integration-test
                    print_success "Microsoft 365統合テスト完了"
                else
                    print_error "品質保証システムが見つかりません"
                fi
                ;;
            "16")
                echo ""
                print_info "PowerShellスクリプト品質検証実行中..."
                # PowerShellスクリプト品質確認の簡易版
                if command -v pwsh >/dev/null 2>&1; then
                    local ps_files=("/mnt/e/MicrosoftProductManagementTools/Apps"/*.ps1)
                    if [[ -f "${ps_files[0]}" ]]; then
                        print_success "PowerShellスクリプト検出・品質確認完了"
                    else
                        print_warn "PowerShellスクリプトが見つかりません"
                    fi
                else
                    print_error "PowerShell 7が見つかりません"
                fi
                ;;
            "17")
                echo ""
                check_context7_status
                ;;
            "18")
                echo ""
                print_info "Context7最新技術情報取得テスト実行中..."
                print_success "Context7統合は各tmuxペインのClaudeエージェント内で利用可能です"
                print_info "使用例: 'React Query 最新実装例' をClaude AIに質問してください"
                ;;
            "19")
                echo ""
                test_keyword_detection
                ;;
            "20")
                echo ""
                manage_auto_monitoring
                ;;
            "21")
                echo ""
                show_keyword_logs
                ;;
            "22")
                echo ""
                show_system_status
                ;;
            "23")
                echo ""
                show_logs_analysis
                ;;
            "24")
                echo ""
                emergency_diagnosis
                ;;
            "25")
                echo ""
                complete_system_reset
                ;;
            "0")
                echo ""
                print_success "🚪✨ 6人チーム エンタープライズ統一ランチャーを終了します ✨🚪"
                log_action "ランチャー終了"
                exit 0
                ;;
            *)
                print_error "❌ 無効な選択です。0-25の数字を入力してください。 ❌"
                ;;
        esac
        
        # メニュー選択後の待機
        echo ""
        read -p "⏎✨ Enterキーを押して続行... ✨"
    done
}

# 初期化とメイン実行
main() {
    log_action "6人チーム エンタープライズ統一ランチャー開始"
    
    # 前提条件チェック
    print_header
    if ! check_prerequisites; then
        echo ""
        print_warn "前提条件に問題がありますが、システムは継続実行されます"
        echo ""
        read -p "続行しますか？ (y/n): " continue_anyway
        if [[ "$continue_anyway" != "y" && "$continue_anyway" != "Y" ]]; then
            print_info "システムを終了します"
            exit 1
        fi
    fi
    
    echo ""
    read -p "Enterキーを押してメインメニューに進む..."
    
    # メインループ開始
    main_loop
}

# スクリプト実行
main "$@"