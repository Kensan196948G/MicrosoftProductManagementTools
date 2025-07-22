#!/bin/bash
# tmux開発セッション再起動スクリプト
# 既存セッションを安全に終了し、最適化環境で再起動

echo "🔄 tmux開発環境再起動開始"

# 現在のセッション一覧表示
echo "📋 現在のtmuxセッション:"
tmux list-sessions 2>/dev/null || echo "  セッションなし"
echo ""

# 既存のMicrosoft365関連セッション終了
echo "🛑 既存セッション終了中..."
tmux kill-session -t "MicrosoftProductTools-6team-Context7" 2>/dev/null && echo "  ✅ MicrosoftProductTools-6team-Context7 終了"
tmux kill-session -t "microsoft365-optimized-dev" 2>/dev/null && echo "  ✅ microsoft365-optimized-dev 終了"
tmux kill-session -t "ms365-dev" 2>/dev/null && echo "  ✅ ms365-dev 終了"

# 少し待機
sleep 2

# 最適化環境で再起動
echo "🚀 最適化tmux環境起動中..."
if [ -f "tmux_optimized_dev.sh" ]; then
    chmod +x tmux_optimized_dev.sh
    ./tmux_optimized_dev.sh
else
    echo "❌ tmux_optimized_dev.sh が見つかりません"
    exit 1
fi

echo "✅ tmux開発環境再起動完了"