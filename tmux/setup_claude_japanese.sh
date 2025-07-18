#!/bin/bash
# Claude日本語環境設定スクリプト
# Version: 1.0
# Date: 2025-07-17

# 色定義
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== Claude日本語環境設定 ===${NC}"
echo ""

# Claude環境変数ファイルのパス
CLAUDE_ENV_FILE="$HOME/.config/claude/claude_env.sh"

# ディレクトリ作成
mkdir -p "$HOME/.config/claude"

# 環境変数ファイル作成/更新
cat > "$CLAUDE_ENV_FILE" << 'EOF'
#!/bin/bash
# Claude環境変数設定

# 日本語対応を含むデフォルトプロンプト
export CLAUDE_DEFAULT_LANGUAGE="ja"
export CLAUDE_INIT_MESSAGE="日本語で解説・対応してください。"

# その他のClaude設定
export CLAUDE_OPTIONS="--dangerously-skip-permissions"
EOF

chmod +x "$CLAUDE_ENV_FILE"

echo -e "${GREEN}✅ Claude環境変数を設定しました${NC}"
echo ""
echo -e "${YELLOW}設定内容:${NC}"
echo "  - デフォルト言語: 日本語"
echo "  - 初期メッセージ: 日本語対応を要求"
echo ""
echo -e "${CYAN}次のステップ:${NC}"
echo "  1. シェルを再起動するか、以下を実行:"
echo "     source $CLAUDE_ENV_FILE"
echo "  2. tmuxセッションを再作成"
echo "     ./tmux_itsm_setup.sh"