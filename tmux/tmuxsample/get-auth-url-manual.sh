#!/bin/bash

# Claude認証URL手動入力スクリプト

# 動的パス解決
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
AUTH_LOG="$LOG_DIR/auth_url.log"

# ログ関数
log_auth() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    mkdir -p "$LOG_DIR"
    echo "[$timestamp] [AUTH-$level] $message" >> "$AUTH_LOG"
    echo "[AUTH-$level] $message"
}

# 高度なURL検証関数
validate_auth_url() {
    local url="$1"
    
    # URL形式の詳細検証
    if [[ ! "$url" =~ ^https:// ]]; then
        echo "invalid_protocol"
        return 1
    fi
    
    # ドメイン検証
    if [[ "$url" =~ (claude\.ai|anthropic\.com|console\.anthropic\.com) ]]; then
        # 認証パラメータの存在確認
        if [[ "$url" =~ (token=|code=|auth=|oauth|login|authorize) ]]; then
            # URLの長さチェック
            if [[ ${#url} -gt 30 && ${#url} -lt 2000 ]]; then
                # 異常文字チェック
                if [[ ! "$url" =~ [\<\>\"\'] ]]; then
                    echo "valid"
                    return 0
                else
                    echo "invalid_characters"
                    return 1
                fi
            else
                echo "invalid_length"
                return 1
            fi
        else
            echo "missing_auth_params"
            return 1
        fi
    else
        echo "invalid_domain"
        return 1
    fi
}

# セキュリティチェック
security_check_url() {
    local url="$1"
    
    # サスピシャスなパターンをチェック
    if [[ "$url" =~ (javascript:|data:|file:|ftp:) ]]; then
        echo "suspicious_protocol"
        return 1
    fi
    
    # サスピシャスなドメインをチェック
    if [[ "$url" =~ (bit\.ly|tinyurl|t\.co|goo\.gl|short) ]]; then
        echo "suspicious_domain"
        return 1
    fi
    
    # 正規のClaude/Anthropicドメインのみ許可
    if [[ ! "$url" =~ ^https://(claude\.ai|console\.anthropic\.com|anthropic\.com|www\.claude\.ai|app\.claude\.ai) ]]; then
        echo "untrusted_domain"
        return 1
    fi
    
    echo "secure"
    return 0
}

echo "🔐 Claude認証URL手動入力ツール (強化版)"
echo "=================================================="

echo "📋 手順説明:"
echo "1. 別のターミナルで 'claude --dangerously-skip-permissions' を実行"
echo "2. ブラウザが開き、認証ページが表示されます"
echo "3. ブラウザのURLをコピーしてください"
echo "4. このプロンプトに貼り付けてEnterを押してください"
echo ""
echo "💡 URLの形式例:"
echo "   • https://claude.ai/login?token=..."
echo "   • https://claude.ai/oauth/authorize?..."
echo "   • https://console.anthropic.com/..."
echo ""

# 安全な手動URL入力
local attempts=0
local max_attempts=5

while [[ $attempts -lt $max_attempts ]]; do
    echo -n "認証URLを貼り付けてください ($((attempts+1))/$max_attempts): "
    read -r auth_url
    
    ((attempts++))
    
    if [[ -z "$auth_url" ]]; then
        echo "❌ URLを入力してください。"
        log_auth "WARNING" "Empty URL entered (attempt $attempts)"
        echo ""
        continue
    fi
    
    # 基本的なサニタイズ
    auth_url=$(echo "$auth_url" | tr -d '\n\r\t' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    echo "🔍 URLセキュリティチェック中..."
    
    # セキュリティチェック
    local security_result=$(security_check_url "$auth_url")
    if [[ "$security_result" != "secure" ]]; then
        echo "❌ セキュリティチェック失敗: $security_result"
        log_auth "ERROR" "Security check failed: $security_result for URL: ${auth_url:0:50}..."
        
        case "$security_result" in
            "suspicious_protocol")
                echo "   → 不正なプロトコルが検出されました"
                ;;
            "suspicious_domain")
                echo "   → 短縮 URL や不明なドメインが検出されました"
                ;;
            "untrusted_domain")
                echo "   → 信頼できないドメインです。Claude/Anthropicの公式URLのみ許可されています"
                ;;
        esac
        echo ""
        continue
    fi
    
    echo "✅ セキュリティチェック通過"
    
    # 詳細URL検証
    local validation_result=$(validate_auth_url "$auth_url")
    if [[ "$validation_result" == "valid" ]]; then
        echo "✅ URL検証成功"
        log_auth "SUCCESS" "Valid auth URL entered: ${auth_url:0:50}..."
        
        # 安全にファイルに保存
        mkdir -p "$LOG_DIR"
        echo "$auth_url" > "$LOG_DIR/claude_auth.txt"
        chmod 600 "$LOG_DIR/claude_auth.txt"  # ファイル権限を制限
        
        echo "💾 認証URLを安全に保存しました: $LOG_DIR/claude_auth.txt"
        
        echo ""
        echo "📄 保存された認証情報:"
        echo "   URL: ${auth_url:0:50}..."
        echo "   ファイル: $LOG_DIR/claude_auth.txt"
        echo "   権限: 600 (所有者のみ読み書き可能)"
        
        log_auth "SUCCESS" "Auth URL saved successfully"
        break
    else
        echo "❌ URL検証失敗: $validation_result"
        log_auth "ERROR" "URL validation failed: $validation_result for URL: ${auth_url:0:50}..."
        
        case "$validation_result" in
            "invalid_protocol")
                echo "   → HTTPSプロトコルが必要です"
                ;;
            "invalid_domain")
                echo "   → Claude/Anthropicの公式ドメインではありません"
                ;;
            "missing_auth_params")
                echo "   → 認証パラメータが見つかりません"
                ;;
            "invalid_length")
                echo "   → URLの長さが不適切です"
                ;;
            "invalid_characters")
                echo "   → 不正な文字が含まれています"
                ;;
        esac
        
        echo ""
        echo "💡 正しいURL形式の例:"
        echo "   • https://claude.ai/login?token=..."
        echo "   • https://claude.ai/oauth/authorize?..."
        echo "   • https://console.anthropic.com/login?..."
        echo "   • https://app.claude.ai/auth/..."
        echo ""
    fi
done

if [[ $attempts -ge $max_attempts ]]; then
    echo "❌ 最大試行回数に達しました。スクリプトを終了します。"
    log_auth "ERROR" "Maximum attempts reached"
    exit 1
fi

echo ""
echo "✅ 認証URL取得プロセス完了"
log_auth "SUCCESS" "Auth URL acquisition process completed"
echo ""
echo "🔒 セキュリティ情報:"
echo "   • URLは安全に検証されました"
echo "   • ファイル権限は600に設定されています"
echo "   • 信頼できるドメインのみ許可されています"
echo ""
echo "🚀 次の手順:"
echo "1. AIシステムを起動: ./start-ai-team.sh"
echo "2. 保存済み認証URLを使用を選択"
echo "3. 必要に応じて手動で認証を適用: ./auto-auth.sh --apply"
echo ""
echo "📊 ログ確認: tail -f $AUTH_LOG"
echo "🔍 認証ファイル確認: cat $LOG_DIR/claude_auth.txt"