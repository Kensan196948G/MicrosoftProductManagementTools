#!/bin/bash

# Claude起動状況確認スクリプト

echo "🔍 Claude起動状況チェック"
echo "========================================"

# セッション存在確認
if ! tmux has-session -t team 2>/dev/null; then
    echo "❌ teamセッションが見つかりません"
    exit 1
fi

# ペイン情報取得
pane_list=($(tmux list-panes -t team -F "#{pane_index}" | sort -n))
echo "📊 検出されたペイン数: ${#pane_list[@]}"
echo "📋 ペイン番号: ${pane_list[*]}"

echo ""
echo "🔍 各ペインの状況:"

for pane in "${pane_list[@]}"; do
    echo "----------------------------------------"
    echo "ペイン team:0.$pane の状況:"
    
    # ペイン内容を取得（最後の5行）
    content=$(tmux capture-pane -t team:0.$pane -p | tail -5)
    
    # Claudeプロセス検出
    if echo "$content" | grep -q -i "claude"; then
        echo "✅ Claude関連の出力を検出"
    else
        echo "❌ Claude関連の出力なし"
    fi
    
    # 認証要求検出
    if echo "$content" | grep -q -E "(authenticate|認証|auth|login|Visit this URL|claude\.ai)"; then
        echo "🔐 認証要求を検出"
    else
        echo "👤 認証要求なし"
    fi
    
    # エラーメッセージ検出
    if echo "$content" | grep -q -E "(コマンドが見つかりません|command not found|error|Error)"; then
        echo "❌ エラーメッセージを検出"
        echo "   エラー内容:"
        echo "$content" | grep -E "(コマンドが見つかりません|command not found|error|Error)" | sed 's/^/   → /'
    else
        echo "✅ エラーなし"
    fi
    
    # 最後の数行を表示
    echo "📝 最後の出力:"
    echo "$content" | sed 's/^/   │ /'
    echo ""
done

# より詳細なClaudeステータス分析
analyze_claude_status() {
    local pane="$1"
    local content="$2"
    
    # Claudeバージョン検出
    local claude_version=$(echo "$content" | grep -oE "claude.*[0-9]+\.[0-9]+" | head -1)
    
    # 接続状態詳細分析
    if echo "$content" | grep -q "Human:"; then
        echo "READY - 対話モード準備完了"
    elif echo "$content" | grep -q "Assistant:"; then
        echo "ACTIVE - 応答モード中"
    elif echo "$content" | grep -q -E "(Loading|Connecting|Starting|初期化中|接続中)"; then
        echo "LOADING - 初期化中"
    elif echo "$content" | grep -q -E "(Welcome to Claude|Claude Code|コード|アシスタント)"; then
        echo "WELCOME - 歓迎画面表示中"
    elif echo "$content" | grep -q -E "(authenticate|認証|auth|login)"; then
        echo "AUTH_REQUIRED - 認証が必要"
    elif echo "$content" | grep -q -E "(Error|error|Failed|failed|エラー|失敗)"; then
        echo "ERROR - エラー状態"
    elif echo "$content" | grep -q -E "(\$|#|%)"; then
        echo "SHELL - シェルプロンプト"
    else
        echo "UNKNOWN - 状態不明"
    fi
}

# Claudeバージョン検出
detect_claude_version() {
    local content="$1"
    
    # 複数のパターンでバージョンを検出
    if echo "$content" | grep -q -E "claude.*[0-9]+\.[0-9]+"; then
        echo "$content" | grep -oE "claude.*[0-9]+\.[0-9]+" | head -1
    elif echo "$content" | grep -q -E "Claude Code|Claude AI"; then
        echo "Claude Code/AI"
    elif echo "$content" | grep -q "Claude"; then
        echo "Claude (バージョン不明)"
    else
        echo ""
    fi
}

# 認証状態詳細分析
analyze_auth_status() {
    local content="$1"
    
    if echo "$content" | grep -q -E "(Visit this URL|claude\.ai/chat)"; then
        echo "URL認証が必要"
    elif echo "$content" | grep -q -E "(login|sign in|ログイン)"; then
        echo "ログインが必要"
    elif echo "$content" | grep -q -E "(authenticate|認証)"; then
        echo "認証が必要"
    elif echo "$content" | grep -q -E "(authenticated|認証済み)"; then
        echo "認証済み"
    else
        echo "認証状態不明"
    fi
}

# エラー状態詳細分析
analyze_error_status() {
    local content="$1"
    
    if echo "$content" | grep -q -E "(コマンドが見つかりません|command not found)"; then
        echo "Claudeコマンドが見つからない"
    elif echo "$content" | grep -q -E "(Connection refused|ECONNREFUSED)"; then
        echo "接続拒否エラー"
    elif echo "$content" | grep -q -E "(timeout|タイムアウト)"; then
        echo "タイムアウトエラー"
    elif echo "$content" | grep -q -E "(Permission denied|アクセス拒否)"; then
        echo "アクセス権限エラー"
    elif echo "$content" | grep -q -E "(Error|error|エラー)"; then
        echo "一般エラー"
    else
        echo "no_errors"
    fi
}

# 接続状態分析
analyze_connection_status() {
    local content="$1"
    
    if echo "$content" | grep -q -E "(Connected|接続済み|接続完了)"; then
        echo "接続済み"
    elif echo "$content" | grep -q -E "(Connecting|接続中)"; then
        echo "接続中"
    elif echo "$content" | grep -q -E "(Disconnected|切断|未接続)"; then
        echo "未接続"
    elif echo "$content" | grep -q -E "(Connection failed|接続失敗)"; then
        echo "接続失敗"
    else
        echo "接続状態不明"
    fi
}

echo "========================================"
echo "💡 Claudeが起動していない場合の対処法:"
echo "   1. 各ペインで手動実行: claude --dangerously-skip-permissions instructions/[role].md"
echo "   2. 認証が必要な場合: ./auto-auth.sh [認証URL]"
echo "   3. システム再起動: tmux kill-server && ./start-ai-team.sh"
echo "   4. ステータスログ確認: tail -f $STATUS_LOG"

echo "✅ Claude status check completed"