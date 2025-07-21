#!/bin/bash

# Claude認証自動化スクリプト（サブスクリプション選択・URL自動アクセス・キー入力統合）

# 動的パス解決
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
AUTH_LOG="$LOG_DIR/claude_auth.log"
AUTH_FILE="$LOG_DIR/claude_auth.txt"

# ログ関数
log_auth() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    mkdir -p "$LOG_DIR"
    echo "[$timestamp] [AUTO-AUTH-$level] $message" >> "$AUTH_LOG"
    echo "[AUTO-AUTH-$level] $message"
}

# expectツールの確認・インストール
ensure_expect() {
    if ! command -v expect &> /dev/null; then
        echo "🔧 expectツールのインストール中..."
        log_auth "INFO" "Installing expect tool"
        
        # Ubuntu/Debian系
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y expect
        # CentOS/RHEL系
        elif command -v yum &> /dev/null; then
            sudo yum install -y expect
        # macOS
        elif command -v brew &> /dev/null; then
            brew install expect
        else
            echo "❌ expectツールのインストールに失敗しました。手動でインストールしてください。"
            log_auth "ERROR" "Failed to install expect tool"
            return 1
        fi
        
        if ! command -v expect &> /dev/null; then
            echo "❌ expectツールのインストールに失敗しました。"
            log_auth "ERROR" "expect tool installation failed"
            return 1
        fi
        
        echo "✅ expectツールのインストール完了"
        log_auth "SUCCESS" "expect tool installed successfully"
    fi
    return 0
}

# ブラウザ自動操作用expectスクリプト生成
generate_expect_script() {
    local auth_url="$1"
    local expect_script="$LOG_DIR/claude_auth.exp"
    
    cat > "$expect_script" << 'EOF'
#!/usr/bin/expect

# タイムアウト設定（秒）
set timeout 60

# 引数確認
if {$argc != 1} {
    puts "Usage: $argv0 <auth_url>"
    exit 1
}

set auth_url [lindex $argv 0]

# Claudeコマンド実行
spawn claude --dangerously-skip-permissions
expect {
    "Press Enter to continue" {
        # 新しいウェルカムメッセージ画面
        send "\r"
        expect {
            "Welcome to Claude Code!" {
                # 既に認証済み - 直接コマンドプロンプトに移行
                puts "✅ Claude Code認証済み - 直接起動完了"
                interact
            }
            "Please choose a subscription:" {
                # サブスクリプション選択（Pro推奨）
                send "2\r"
                expect "Please visit the following URL to authenticate:"
            }
            "Please visit the following URL to authenticate:" {
                # 既にサブスクリプション選択済み
            }
            timeout {
                puts "❌ Timeout: サブスクリプション選択画面が表示されません"
                exit 1
            }
        }
    }
    "Welcome to Claude Code!" {
        # 既に認証済み - 直接コマンドプロンプトに移行
        puts "✅ Claude Code認証済み - 直接起動完了"
        interact
    }
    "Please choose a subscription:" {
        # サブスクリプション選択（Pro推奨）
        send "2\r"
        expect "Please visit the following URL to authenticate:"
    }
    "Please visit the following URL to authenticate:" {
        # 既にサブスクリプション選択済み
    }
    timeout {
        puts "❌ Timeout: 初期画面が表示されません"
        exit 1
    }
}

# 認証URL待機
expect {
    "https://" {
        # 表示されたURLをキャプチャ
        expect -re "(https://[^\r\n]+)"
        set displayed_url $expect_out(1,string)
        puts "🔍 表示されたURL: $displayed_url"
        
        # ブラウザ自動起動
        if {[info exists env(DISPLAY)]} {
            # X11環境でブラウザ起動
            spawn xdg-open $displayed_url
        } else {
            puts "📋 ブラウザでこのURLを開いてください: $displayed_url"
        }
        
        expect "Please enter the authentication code from the browser:"
    }
    timeout {
        puts "❌ Timeout: 認証URLが表示されません"
        exit 1
    }
}

# 認証コード入力待機
expect {
    "Please enter the authentication code from the browser:" {
        puts "🔐 認証コードを自動取得中..."
        
        # 認証コード自動取得（URL解析）
        if {[regexp {code=([^&]+)} $auth_url match auth_code]} {
            puts "✅ 認証コードを自動取得: $auth_code"
            send "$auth_code\r"
        } elseif {[regexp {token=([^&]+)} $auth_url match auth_token]} {
            puts "✅ 認証トークンを自動取得: $auth_token"
            send "$auth_token\r"
        } else {
            puts "❌ 認証コードを自動取得できませんでした"
            puts "💡 手動で認証コードを入力してください"
            interact
            exit 1
        }
    }
    timeout {
        puts "❌ Timeout: 認証コード入力画面が表示されません"
        exit 1
    }
}

# 認証成功確認
expect {
    "Authentication successful" {
        puts "✅ 認証が成功しました"
        puts "🚀 Claudeが起動しました"
        interact
    }
    "Successfully authenticated" {
        puts "✅ 認証が成功しました"
        puts "🚀 Claudeが起動しました"
        interact
    }
    "Invalid authentication code" {
        puts "❌ 認証コードが無効です"
        exit 1
    }
    timeout {
        puts "❌ Timeout: 認証完了を確認できません"
        exit 1
    }
}

EOF

    chmod +x "$expect_script"
    echo "$expect_script"
}

# メイン処理
main() {
    echo "🤖 Claude認証自動化システム v2.0"
    echo "=================================================="
    log_auth "INFO" "Auto-authentication system started"
    
    # expectツールの確認
    if ! ensure_expect; then
        exit 1
    fi
    
    # 認証URL確認
    if [[ -f "$AUTH_FILE" ]]; then
        local auth_url=$(cat "$AUTH_FILE" 2>/dev/null | tr -d '\n\r')
        if [[ -n "$auth_url" ]]; then
            echo "✅ 保存済み認証URLを発見: ${auth_url:0:50}..."
            log_auth "INFO" "Found saved auth URL"
        else
            echo "❌ 認証URLファイルが空です"
            log_auth "ERROR" "Auth URL file is empty"
            exit 1
        fi
    else
        echo "❌ 認証URLファイルが見つかりません: $AUTH_FILE"
        echo "💡 まず手動で認証URLを取得してください: ./get-auth-url-manual.sh"
        log_auth "ERROR" "Auth URL file not found"
        exit 1
    fi
    
    echo "🔧 自動認証スクリプトを生成中..."
    local expect_script=$(generate_expect_script "$auth_url")
    log_auth "INFO" "Generated expect script: $expect_script"
    
    echo "🚀 Claude自動認証を開始します..."
    echo "   サブスクリプション: Pro (自動選択)"
    echo "   認証URL: 自動適用"
    echo "   認証コード: 自動入力"
    echo ""
    
    # 自動認証実行
    log_auth "INFO" "Starting automated authentication"
    
    if expect "$expect_script" "$auth_url"; then
        echo ""
        echo "✅ 自動認証が完了しました"
        log_auth "SUCCESS" "Automated authentication completed successfully"
        
        # 認証ファイルを削除（セキュリティ）
        rm -f "$AUTH_FILE"
        log_auth "INFO" "Auth file removed for security"
        
        echo "🔒 セキュリティ: 認証ファイルを削除しました"
        echo "🎉 Claudeが使用可能になりました"
    else
        echo "❌ 自動認証に失敗しました"
        log_auth "ERROR" "Automated authentication failed"
        
        echo ""
        echo "🔧 トラブルシューティング:"
        echo "1. 認証URLの有効性確認: cat $AUTH_FILE"
        echo "2. 手動認証: claude --dangerously-skip-permissions"
        echo "3. ログ確認: tail -f $AUTH_LOG"
        echo "4. 再試行: $0"
        
        exit 1
    fi
    
    # 一時ファイル削除
    rm -f "$expect_script"
    log_auth "INFO" "Temporary files cleaned up"
}

# 使用方法表示
show_usage() {
    echo "📚 Claude認証自動化システム使用方法"
    echo "=================================================="
    echo ""
    echo "🔧 セットアップ:"
    echo "1. ./get-auth-url-manual.sh  # 認証URL取得"
    echo "2. ./auto-claude-auth.sh     # 自動認証実行"
    echo ""
    echo "⚡ 高速起動:"
    echo "./auto-claude-auth.sh --quick"
    echo ""
    echo "🔍 オプション:"
    echo "--help    : このヘルプを表示"
    echo "--quick   : 高速モード（確認をスキップ）"
    echo "--debug   : デバッグモード（詳細ログ）"
    echo "--status  : 認証状態確認"
    echo ""
    echo "🚨 緊急時:"
    echo "./auto-claude-auth.sh --reset  # 認証リセット"
}

# 認証状態確認
check_auth_status() {
    echo "🔍 Claude認証状態確認"
    echo "======================="
    
    if [[ -f "$AUTH_FILE" ]]; then
        local auth_url=$(cat "$AUTH_FILE" 2>/dev/null)
        if [[ -n "$auth_url" ]]; then
            echo "✅ 認証URL: 保存済み"
            echo "   ファイル: $AUTH_FILE"
            echo "   長さ: ${#auth_url} 文字"
            echo "   URL: ${auth_url:0:50}..."
        else
            echo "❌ 認証URL: ファイルが空"
        fi
    else
        echo "❌ 認証URL: 未保存"
    fi
    
    # Claude実行確認
    if command -v claude &> /dev/null; then
        echo "✅ Claude Code: インストール済み"
        claude --version 2>/dev/null || echo "❌ Claude Code: バージョン確認に失敗"
    else
        echo "❌ Claude Code: 未インストール"
    fi
    
    # expectツール確認
    if command -v expect &> /dev/null; then
        echo "✅ expect: インストール済み"
    else
        echo "❌ expect: 未インストール"
    fi
}

# 認証リセット
reset_auth() {
    echo "🔄 Claude認証リセット"
    echo "====================="
    
    # 認証ファイル削除
    if [[ -f "$AUTH_FILE" ]]; then
        rm -f "$AUTH_FILE"
        echo "✅ 認証URLファイルを削除しました"
        log_auth "INFO" "Auth file reset"
    else
        echo "💡 認証URLファイルは存在しません"
    fi
    
    # 一時ファイル削除
    rm -f "$LOG_DIR"/*.exp
    echo "✅ 一時ファイルを削除しました"
    
    # Claude設定リセット（オプション）
    echo -n "Claude設定もリセットしますか? [y/N]: "
    read -r reset_config
    if [[ "$reset_config" =~ ^[Yy]$ ]]; then
        # Claude設定ディレクトリ削除
        local claude_config_dir="$HOME/.local/share/claude"
        if [[ -d "$claude_config_dir" ]]; then
            rm -rf "$claude_config_dir"
            echo "✅ Claude設定をリセットしました"
            log_auth "INFO" "Claude config reset"
        fi
    fi
    
    echo "🔄 リセット完了"
}

# 引数処理
case "${1:-}" in
    --help|-h)
        show_usage
        exit 0
        ;;
    --status|-s)
        check_auth_status
        exit 0
        ;;
    --reset|-r)
        reset_auth
        exit 0
        ;;
    --quick|-q)
        echo "⚡ 高速モードで自動認証を実行します"
        main
        ;;
    --debug|-d)
        set -x
        main
        ;;
    "")
        main
        ;;
    *)
        echo "❌ 不明なオプション: $1"
        show_usage
        exit 1
        ;;
esac