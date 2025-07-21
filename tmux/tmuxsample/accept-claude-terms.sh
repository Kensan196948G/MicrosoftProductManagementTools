#!/bin/bash

# Claude利用規約自動同意スクリプト

# 動的パス解決
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"

# ログ関数
log_terms() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    mkdir -p "$LOG_DIR"
    echo "[$timestamp] [TERMS-$level] $message" >> "$LOG_DIR/terms_acceptance.log"
    echo "[TERMS-$level] $message"
}

echo "📋 Claude利用規約自動同意処理"
echo "=================================================="

# tmuxセッション確認
if ! tmux has-session -t team 2>/dev/null; then
    echo "❌ teamセッションが見つかりません"
    exit 1
fi

# ペイン情報取得
pane_list=($(tmux list-panes -t team -F "#{pane_index}" | sort -n))
echo "📊 対象ペイン数: ${#pane_list[@]}"
echo "📋 ペイン番号: ${pane_list[*]}"

echo ""
echo "✅ 各ペインでClaude利用規約に同意中..."

for pane in "${pane_list[@]}"; do
    echo "📝 ペイン team:0.$pane で利用規約同意..."
    
    # ペイン内容を確認
    content=$(tmux capture-pane -t team:0.$pane -p)
    
    # デバッグ: ペイン内容の最後の3行を表示
    echo "   📋 ペイン内容(最後の3行):"
    echo "$content" | tail -3 | sed 's/^/      │ /'
    
    # より柔軟な利用規約検出
    terms_result=$(detect_terms_screen "$content")
    
    if [[ "$terms_result" == "accept_screen" ]]; then
        echo "   🎯 利用規約画面を検出 - 同意処理"
        log_terms "INFO" "Terms screen detected in pane $pane"
        
        # 下矢印キー + Enterで「Yes, I accept」を選択
        tmux send-keys -t team:0.$pane Down C-m
        sleep 1
        
        # 再度内容確認
        new_content=$(tmux capture-pane -t team:0.$pane -p)
        if echo "$new_content" | grep -q "Welcome to Claude"; then
            echo "   ✅ 同意完了 - Claude画面に到達"
            log_terms "SUCCESS" "Terms accepted successfully in pane $pane"
        elif echo "$new_content" | grep -q -E "(claude|>|$)"; then
            echo "   ✅ 同意完了 - シェルに戻りました"
            log_terms "SUCCESS" "Terms accepted, returned to shell in pane $pane"
        else
            echo "   🔄 Enterキーで続行"
            tmux send-keys -t team:0.$pane C-m
            sleep 1
            log_terms "INFO" "Additional Enter sent in pane $pane"
        fi
    elif [[ "$terms_result" == "terms_visible" ]]; then
        echo "   📋 利用規約関連画面 - 同意試行"
        log_terms "INFO" "Terms-related screen detected in pane $pane"
        
        # より確実な同意処理
        handle_terms_agreement "$pane"
    elif echo "$content" | grep -q "Welcome to Claude"; then
        echo "   🎉 既にClaude画面に到達済み"
    elif echo "$content" | grep -q -E "(claude|$|>|#)"; then
        echo "   ✅ シェルプロンプト状態"
    else
        echo "   📋 状況不明 - 手動確認が必要"
        echo "   🔄 Enterキーを送信して処理を進める"
        tmux send-keys -t team:0.$pane C-m
        sleep 1
    fi
    
    sleep 0.5
done

echo ""
echo "⏳ Claude完全起動待機中（5秒）..."
sleep 5

# より柔軟な利用規約検出関数
detect_terms_screen() {
    local content="$1"
    
    # 複数パターンに対応した詳細な検出
    if echo "$content" | grep -q -E "(Yes, I accept|I accept the|Accept and|I agree|Accept these|同意する|同意します)"; then
        echo "accept_screen"
    elif echo "$content" | grep -q -E "(Terms|利用規約|規約|Agreement|License|EULA|Privacy Policy|Cookie Policy)"; then
        echo "terms_visible"
    elif echo "$content" | grep -q -E "(Accept|Agree|同意|Continue|Proceed|Next)"; then
        echo "accept_button"
    else
        echo "no_terms"
    fi
}

# 利用規約同意処理の詳細ハンドリング
handle_terms_agreement() {
    local pane="$1"
    
    log_terms "INFO" "Attempting terms agreement in pane $pane"
    
    # 複数の同意方法を試行
    local methods=("Down C-m" "Tab C-m" "y" "Y" "1" "C-m")
    
    for method in "${methods[@]}"; do
        echo "   🔄 試行: $method"
        tmux send-keys -t team:0.$pane $method
        sleep 1.5
        
        # 結果確認
        local new_content=$(tmux capture-pane -t team:0.$pane -p)
        
        if echo "$new_content" | grep -q -E "(Welcome to Claude|Claude Code|Human:|Assistant:)"; then
            echo "   ✅ 同意成功 - Claude起動確認"
            log_terms "SUCCESS" "Terms accepted with method: $method in pane $pane"
            return 0
        elif echo "$new_content" | grep -q -E "(\$|#|%)"; then
            echo "   ✅ 同意成功 - シェルに戻り"
            log_terms "SUCCESS" "Terms accepted, shell prompt in pane $pane"
            return 0
        fi
    done
    
    echo "   ⚠️ 自動同意に失敗 - 手動確認が必要"
    log_terms "WARNING" "Automatic terms acceptance failed in pane $pane"
    return 1
}

echo ""
echo "✅ Claude利用規約同意処理完了"
echo ""
echo "🔍 最終状況確認..."
"$SCRIPT_DIR/check-claude-status.sh"