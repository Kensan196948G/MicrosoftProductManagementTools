#!/bin/bash
# create-itsm-session.sh - ITSM開発セッション構築スクリプト (実際のitmux環境対応版)

SESSION_NAME="MicrosoftProductManagementTools"
WORKSPACE_BASE="/cygdrive/c/workspace/MicrosoftProductManagementTools"

echo "🎯 ITSM開発セッション構築を開始します"
echo "📁 作業ディレクトリ: $WORKSPACE_BASE"
echo "🔗 セッション名: $SESSION_NAME"

# 作業ディレクトリ確認・作成
echo "🔍 作業ディレクトリ構造を確認中..."
mkdir -p "$WORKSPACE_BASE"/{frontend,backend,tests,integration,scripts,logs,docs,config}

# 既存セッション削除
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
    echo "🗑️ 既存のセッションを削除中..."
    tmux kill-session -t $SESSION_NAME
fi

# 新セッション作成
echo "🚀 新しいITSM開発セッションを作成中..."
tmux new-session -d -s $SESSION_NAME

# Window 0: 👑 CEO Strategy Terminal
echo "👑 CEO Strategy Terminal を設定中..."
tmux rename-window -t $SESSION_NAME:0 "CEO-Strategy"
tmux send-keys -t $SESSION_NAME:0 "clear" C-m
tmux send-keys -t $SESSION_NAME:0 "echo '👑 CEO Strategy Terminal - ITSM Project Management'" C-m
tmux send-keys -t $SESSION_NAME:0 "echo '📁 Workspace: $WORKSPACE_BASE'" C-m
tmux send-keys -t $SESSION_NAME:0 "cd $WORKSPACE_BASE" C-m
tmux send-keys -t $SESSION_NAME:0 "echo '🎯 Current tasks:'" C-m
tmux send-keys -t $SESSION_NAME:0 "echo '  - Review development progress'" C-m
tmux send-keys -t $SESSION_NAME:0 "echo '  - Approve feature implementations'" C-m
tmux send-keys -t $SESSION_NAME:0 "echo '  - Strategic decisions'" C-m
tmux send-keys -t $SESSION_NAME:0 "echo '  - Project oversight'" C-m

# Window 1: 👔 Manager Coordination Terminal
echo "👔 Manager Coordination Terminal を設定中..."
tmux new-window -t $SESSION_NAME:1 -n "Manager-Coord"
tmux send-keys -t $SESSION_NAME:1 "clear" C-m
tmux send-keys -t $SESSION_NAME:1 "echo '👔 Manager Coordination Terminal - Team Management'" C-m
tmux send-keys -t $SESSION_NAME:1 "cd $WORKSPACE_BASE" C-m
tmux send-keys -t $SESSION_NAME:1 "echo '📊 Team coordination tasks:'" C-m
tmux send-keys -t $SESSION_NAME:1 "echo '  - Monitor developer progress'" C-m
tmux send-keys -t $SESSION_NAME:1 "echo '  - Resolve blockers'" C-m
tmux send-keys -t $SESSION_NAME:1 "echo '  - Quality assurance'" C-m
tmux send-keys -t $SESSION_NAME:1 "echo '  - Resource allocation'" C-m

# Window 2: 💻 dev1 Frontend Development (4ペイン構成)
echo "💻 dev1 Frontend Development を設定中..."
tmux new-window -t $SESSION_NAME:2 -n "dev1-Frontend"
tmux send-keys -t $SESSION_NAME:2 "clear" C-m
tmux send-keys -t $SESSION_NAME:2 "echo '💻 Developer 1 - Frontend Development (React/Vue.js)'" C-m
tmux send-keys -t $SESSION_NAME:2 "cd $WORKSPACE_BASE/frontend" C-m
tmux send-keys -t $SESSION_NAME:2 "echo '🎨 Frontend development environment ready'" C-m

# dev1用4ペイン構成を作成
tmux split-window -h -t $SESSION_NAME:2
tmux select-pane -t $SESSION_NAME:2.1
tmux split-window -v -t $SESSION_NAME:2
tmux select-pane -t $SESSION_NAME:2.0
tmux split-window -v -t $SESSION_NAME:2

# 各ペインに初期コマンド設定
tmux send-keys -t $SESSION_NAME:2.0 "echo '📝 メインターミナル - コーディング作業'" C-m
tmux send-keys -t $SESSION_NAME:2.1 "echo '📊 ログ・モニタリング - ビルド結果'" C-m
tmux send-keys -t $SESSION_NAME:2.2 "echo '🚀 開発サーバー - npm run dev'" C-m
tmux send-keys -t $SESSION_NAME:2.3 "echo '🧪 テスト実行 - npm test'" C-m

# Window 3: 🔧 dev2 Backend/DB/API Development (4ペイン構成)
echo "🔧 dev2 Backend/DB/API Development を設定中..."
tmux new-window -t $SESSION_NAME:3 -n "dev2-Backend"
tmux send-keys -t $SESSION_NAME:3 "clear" C-m
tmux send-keys -t $SESSION_NAME:3 "echo '🔧 Developer 2 - Backend/Database/API Development'" C-m
tmux send-keys -t $SESSION_NAME:3 "cd $WORKSPACE_BASE/backend" C-m

# dev2用4ペイン構成を作成
tmux split-window -h -t $SESSION_NAME:3
tmux select-pane -t $SESSION_NAME:3.1
tmux split-window -v -t $SESSION_NAME:3
tmux select-pane -t $SESSION_NAME:3.0
tmux split-window -v -t $SESSION_NAME:3

# 各ペインに初期コマンド設定
tmux send-keys -t $SESSION_NAME:3.0 "echo '💻 メインターミナル - バックエンド開発'" C-m
tmux send-keys -t $SESSION_NAME:3.1 "echo '🚀 APIサーバー監視 - node server.js'" C-m
tmux send-keys -t $SESSION_NAME:3.2 "echo '🗄️ データベース管理 - SQLite管理'" C-m
tmux send-keys -t $SESSION_NAME:3.3 "echo '🧪 APIテスト - レスポンス確認'" C-m

# Window 4: 🗄️ dev3 Test/QA/Security (4ペイン構成)
echo "🗄️ dev3 Test/QA/Security を設定中..."
tmux new-window -t $SESSION_NAME:4 -n "dev3-TestQA"
tmux send-keys -t $SESSION_NAME:4 "clear" C-m
tmux send-keys -t $SESSION_NAME:4 "echo '🗄️ Developer 3 - Test Automation/QA/Security'" C-m
tmux send-keys -t $SESSION_NAME:4 "cd $WORKSPACE_BASE/tests" C-m

# dev3用4ペイン構成を作成
tmux split-window -h -t $SESSION_NAME:4
tmux select-pane -t $SESSION_NAME:4.1
tmux split-window -v -t $SESSION_NAME:4
tmux select-pane -t $SESSION_NAME:4.0
tmux split-window -v -t $SESSION_NAME:4

# 各ペインに初期コマンド設定
tmux send-keys -t $SESSION_NAME:4.0 "echo '🧪 テスト自動化 - Jest実行'" C-m
tmux send-keys -t $SESSION_NAME:4.1 "echo '🛡️ セキュリティスキャン - 脆弱性チェック'" C-m
tmux send-keys -t $SESSION_NAME:4.2 "echo '📏 品質管理 - ESLint実行'" C-m
tmux send-keys -t $SESSION_NAME:4.3 "echo '⚡ パフォーマンステスト - 負荷テスト'" C-m

# Window 5: 🧪 dev4 Integration/Validation (4ペイン構成)
echo "🧪 dev4 Integration/Validation を設定中..."
tmux new-window -t $SESSION_NAME:5 -n "dev4-Integration"
tmux send-keys -t $SESSION_NAME:5 "clear" C-m
tmux send-keys -t $SESSION_NAME:5 "echo '🧪 Developer 4 - Integration/Validation Testing'" C-m
tmux send-keys -t $SESSION_NAME:5 "cd $WORKSPACE_BASE/integration" C-m

# dev4用4ペイン構成を作成
tmux split-window -h -t $SESSION_NAME:5
tmux select-pane -t $SESSION_NAME:5.1
tmux split-window -v -t $SESSION_NAME:5
tmux select-pane -t $SESSION_NAME:5.0
tmux split-window -v -t $SESSION_NAME:5

# 各ペインに初期コマンド設定
tmux send-keys -t $SESSION_NAME:5.0 "echo '🔄 統合テスト実行 - 結合テスト'" C-m
tmux send-keys -t $SESSION_NAME:5.1 "echo '🌐 E2Eテスト - ブラウザ自動化'" C-m
tmux send-keys -t $SESSION_NAME:5.2 "echo '✅ 受入テスト - ユーザー受入テスト'" C-m
tmux send-keys -t $SESSION_NAME:5.3 "echo '🎯 最終検証 - 総合レポート'" C-m

# プロジェクト情報表示
echo ""
echo "✅ ITSM開発セッションが正常に作成されました!"
echo "🔗 セッション: $SESSION_NAME"
echo "📋 ウィンドウ構成:"
echo "  0: CEO-Strategy     (1ペイン)"
echo "  1: Manager-Coord    (1ペイン)"
echo "  2: dev1-Frontend    (4ペイン)"
echo "  3: dev2-Backend     (4ペイン)"
echo "  4: dev3-TestQA      (4ペイン)"
echo "  5: dev4-Integration (4ペイン)"
echo ""
echo "🎯 接続方法: tmux attach-session -t $SESSION_NAME"
echo "⌨️  操作方法:"
echo "  - Ctrl+a + [0-5]: ウィンドウ切り替え"
echo "  - Ctrl+a + h/j/k/l: ペイン移動"
echo "  - Ctrl+a + |: 垂直分割"
echo "  - Ctrl+a + -: 水平分割"
echo "  - Ctrl+a + d: セッションデタッチ"
echo ""
echo "🚀 セッションにアタッチしています..."

# セッションアタッチ
tmux attach-session -t $SESSION_NAME