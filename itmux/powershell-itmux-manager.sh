#!/bin/bash
# powershell-itmux-manager.sh - PowerShell統合実行スクリプト (MicrosoftProductManagementTools対応版)

SCRIPT_DIR="/cygdrive/c/workspace/MicrosoftProductManagementTools/Scripts"
LOG_DIR="/cygdrive/c/workspace/MicrosoftProductManagementTools/logs"
CONFIG_DIR="/cygdrive/c/workspace/MicrosoftProductManagementTools/config"
SESSION_NAME="MicrosoftProductManagementTools"

# 初期化
initialize_itmux_environment() {
    echo "🔧 MicrosoftProductManagementTools開発環境を初期化中..."
    
    # 必要ディレクトリ作成
    mkdir -p "$SCRIPT_DIR" "$LOG_DIR" "$CONFIG_DIR"
    
    # Cygwin環境確認
    echo "📋 Cygwin環境チェック:"
    echo "  - Cygwin version: $(uname -a)"
    echo "  - tmux version: $(tmux -V)"
    echo "  - bash version: $BASH_VERSION"
    
    # Windows統合確認
    echo "🖥️ Windows統合チェック:"
    if cmd.exe /c "echo Windows command available" 2>/dev/null; then
        echo "  - Windows commands: ✅ Available"
    else
        echo "  - Windows commands: ❌ Not available"
    fi
    
    if cmd.exe /c "powershell.exe -Command \"Write-Host 'PowerShell test'\"" 2>/dev/null; then
        echo "  - PowerShell: ✅ Available"
    else
        echo "  - PowerShell: ❌ Not available"
    fi
    
    # マウントポイント確認
    echo "📁 マウントポイント:"
    mount | grep cygdrive
    
    # 作業ディレクトリ確認
    echo "📂 作業ディレクトリ:"
    ls -la /cygdrive/c/workspace/MicrosoftProductManagementTools/
}

# PowerShell実行関数（Microsoft製品管理ツール特化）
execute_powershell_script() {
    local script_name=$1
    local dev_window=$2
    local iteration=$3
    local max_iterations=$4
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local log_file="$LOG_DIR/${script_name%.*}_${timestamp}.log"
    
    echo "⚡ PowerShellスクリプトを実行中: $script_name"
    echo "📝 ログファイル: $log_file"
    
    # Windows パス変換
    local win_script_path=$(cygpath -w "$SCRIPT_DIR/$script_name")
    local win_log_path=$(cygpath -w "$log_file")
    
    # PowerShell実行（itmux/Cygwin経由）
    echo "🔄 実行中: $win_script_path"
    cmd.exe /c "powershell.exe -ExecutionPolicy Bypass -File \"$win_script_path\"" > "$log_file" 2>&1
    
    local exit_code=$?
    local current_time=$(date '+%H:%M:%S')
    
    # 結果をtmuxウィンドウに通知
    if [ -n "$dev_window" ]; then
        if [ $exit_code -eq 0 ]; then
            tmux send-keys -t "$SESSION_NAME:$dev_window" "echo '✅ [$current_time] $script_name 完了 (iteration $iteration/$max_iterations)'" C-m
        else
            tmux send-keys -t "$SESSION_NAME:$dev_window" "echo '❌ [$current_time] $script_name 失敗 code:$exit_code (iteration $iteration/$max_iterations)'" C-m
        fi
    fi
    
    # Manager窓に報告
    tmux send-keys -t "$SESSION_NAME:1" "echo '📊 [$current_time] Dev$dev_window: $script_name - Exit Code: $exit_code'" C-m
    
    # 結果表示
    if [ $exit_code -eq 0 ]; then
        echo "✅ 成功: $script_name 完了"
        
        # 成功時の後処理
        if [ -f "$SCRIPT_DIR/Post-${script_name}" ]; then
            echo "🔄 後処理スクリプト実行中..."
            local win_post_path=$(cygpath -w "$SCRIPT_DIR/Post-${script_name}")
            cmd.exe /c "powershell.exe -ExecutionPolicy Bypass -File \"$win_post_path\""
        fi
    else
        echo "❌ エラー: $script_name が終了コード $exit_code で失敗"
        
        # エラー時の自動修復
        if [ -f "$SCRIPT_DIR/Fix-${script_name}" ]; then
            echo "🔧 自動修復スクリプト実行中..."
            local win_fix_path=$(cygpath -w "$SCRIPT_DIR/Fix-${script_name}")
            cmd.exe /c "powershell.exe -ExecutionPolicy Bypass -File \"$win_fix_path\""
        fi
    fi
    
    return $exit_code
}

# 自動実行ループ
run_development_loop() {
    local script_pattern=$1
    local dev_window=$2
    local max_iterations=${3:-3}
    
    echo "🔄 開発ループを開始: $script_pattern"
    
    # 該当スクリプトを検索
    local scripts=($(find "$SCRIPT_DIR" -name "$script_pattern" -type f))
    
    if [ ${#scripts[@]} -eq 0 ]; then
        echo "⚠️ パターンに一致するスクリプトが見つかりません: $script_pattern"
        return 1
    fi
    
    for script in "${scripts[@]}"; do
        local script_name=$(basename "$script")
        echo "📋 処理中スクリプト: $script_name"
        
        for ((i=1; i<=max_iterations; i++)); do
            echo "🔄 実行 $i/$max_iterations"
            
            if execute_powershell_script "$script_name" "$dev_window" "$i" "$max_iterations"; then
                echo "✅ 実行 $i 成功"
            else
                echo "❌ 実行 $i 失敗"
                
                # エラー時の選択
                read -p "🤔 次の実行を続けますか? (y/n/s=スクリプトスキップ): " choice
                case $choice in
                    [Nn]* ) echo "🛑 ループを停止"; return 1;;
                    [Ss]* ) echo "⏭️ 次のスクリプトへスキップ"; break;;
                    * ) echo "➡️ 継続中...";;
                esac
            fi
            
            # 間隔調整
            sleep 2
        done
    done
}

# Microsoft製品管理ツール専用実行関数
run_gui_development() {
    echo "🖥️ GUI開発ループを開始"
    run_development_loop "GuiApp*.ps1" 2 2
    run_development_loop "Test-GUI*.ps1" 2 1
}

run_cli_development() {
    echo "💻 CLI開発ループを開始"
    run_development_loop "CliApp*.ps1" 3 2
    run_development_loop "Test-CLI*.ps1" 3 1
}

run_authentication_testing() {
    echo "🔐 認証テストループを開始"
    run_development_loop "Test-Auth*.ps1" 4 2
    run_development_loop "Authentication*.ps1" 4 1
}

run_integration_testing() {
    echo "🔗 統合テストループを開始"
    run_development_loop "Test-Integration*.ps1" 5 2
    run_development_loop "Complete-System-Test*.ps1" 5 1
}

run_report_generation() {
    echo "📊 レポート生成ループを開始"
    run_development_loop "Generate-*Report*.ps1" 2 1
    run_development_loop "Daily*.ps1" 2 1
    run_development_loop "Weekly*.ps1" 2 1
    run_development_loop "Monthly*.ps1" 2 1
}

run_microsoft365_management() {
    echo "🌐 Microsoft365管理ループを開始"
    run_development_loop "*Exchange*.ps1" 3 1
    run_development_loop "*Teams*.ps1" 3 1
    run_development_loop "*OneDrive*.ps1" 3 1
    run_development_loop "*EntraID*.ps1" 3 1
}

# メイン処理
main() {
    case $1 in
        init|initialize)
            initialize_itmux_environment
            ;;
        gui)
            run_gui_development
            ;;
        cli)
            run_cli_development
            ;;
        auth|authentication)
            run_authentication_testing
            ;;
        integration|test)
            run_integration_testing
            ;;
        report|reports)
            run_report_generation
            ;;
        m365|microsoft365)
            run_microsoft365_management
            ;;
        all)
            initialize_itmux_environment
            run_gui_development
            run_cli_development
            run_authentication_testing
            run_integration_testing
            run_report_generation
            run_microsoft365_management
            ;;
        *)
            echo "🎯 Microsoft製品管理ツール開発マネージャー (itmux/Cygwin)"
            echo "使用方法: $0 {init|gui|cli|auth|integration|report|m365|all}"
            echo ""
            echo "コマンド:"
            echo "  init        - itmux環境初期化"
            echo "  gui         - GUI開発ループ実行"
            echo "  cli         - CLI開発ループ実行"
            echo "  auth        - 認証テストループ実行"
            echo "  integration - 統合テストループ実行"
            echo "  report      - レポート生成ループ実行"
            echo "  m365        - Microsoft365管理ループ実行"
            echo "  all         - 全開発ループ実行"
            echo ""
            echo "🔗 itmux tmuxセッション内から実行してください"
            ;;
    esac
}

# 実行
main "$@"