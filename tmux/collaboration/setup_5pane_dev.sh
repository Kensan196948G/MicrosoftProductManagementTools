#!/bin/bash
# 5ペイン開発環境自動セットアップスクリプト
# Microsoft365管理ツールPython版開発用
# 仕様書準拠版 (2025-01-18)

SESSION_NAME="MicrosoftProductTools-Python"
PROJECT_DIR="/mnt/e/MicrosoftProductManagementTools"

# 既存セッションチェック
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
    echo "セッション '$SESSION_NAME' は既に存在します。"
    read -p "既存セッションを削除して新規作成しますか？ (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tmux kill-session -t $SESSION_NAME
    else
        echo "既存セッションに接続します..."
        tmux attach-session -t $SESSION_NAME
        exit 0
    fi
fi

echo "5ペイン開発環境を構築中..."

# セッション作成 (Window 0: Development Session)
tmux new-session -d -s $SESSION_NAME -c $PROJECT_DIR

# 5ペイン分割（仕様書準拠）
# 右半分を作成
tmux split-window -h -p 50
# 右下ペインを作成（dev1用）
tmux split-window -v -p 50
# 左ペインを選択
tmux select-pane -t 0
# 左中ペインを作成（Manager用）
tmux split-window -v -p 67
# 左下ペインを作成（dev2用）  
tmux split-window -v -p 50

# ペイン番号の確認と調整
# 正しいペイン配置:
# ┌─────────────────┬─────────────────┐
# │  👔 Manager     │  🐍 Dev0        │
# │   (ペイン0)     │   (ペイン2)     │
# ├─────────────────┼─────────────────┤
# │  👑 CTO         │  🧪 Dev1        │
# │   (ペイン1)     │   (ペイン3)     │
# │                 ├─────────────────┤
# │                 │  🔄 Dev2        │
# │                 │   (ペイン4)     │
# └─────────────────┴─────────────────┘

# ペイン設定
echo "各ペインを初期化中..."

# Pane 0: Manager (左上)
tmux select-pane -t 0 -T "👔 Manager"
tmux send-keys -t 0 "cd $PROJECT_DIR" C-m
tmux send-keys -t 0 "echo '👔 Manager - Progress Coordination Terminal'" C-m
tmux send-keys -t 0 "echo '========================================'" C-m
tmux send-keys -t 0 "echo '責任範囲:'" C-m
tmux send-keys -t 0 "echo '- 進捗管理とタスク調整'" C-m
tmux send-keys -t 0 "echo '- 3名開発者のリソース配分'" C-m
tmux send-keys -t 0 "echo '- 品質管理とレビュー'" C-m
tmux send-keys -t 0 "echo '========================================'" C-m

# Pane 1: CTO (左中)
tmux select-pane -t 1 -T "👑 CTO"
tmux send-keys -t 1 "cd $PROJECT_DIR" C-m
tmux send-keys -t 1 "echo '👑 CTO - Strategic Decision Terminal'" C-m
tmux send-keys -t 1 "echo '========================================'" C-m
tmux send-keys -t 1 "echo '責任範囲:'" C-m
tmux send-keys -t 1 "echo '- Python移行の戦略的決定'" C-m
tmux send-keys -t 1 "echo '- 技術アーキテクチャ承認'" C-m
tmux send-keys -t 1 "echo '- 品質基準設定'" C-m
tmux send-keys -t 1 "echo '========================================'" C-m

# Pane 2: Developer dev0 (GUI/API)
tmux select-pane -t 2 -T "🐍 dev0-GUI"
tmux send-keys -t 2 "cd $PROJECT_DIR" C-m
tmux send-keys -t 2 "echo '🐍 Developer dev0 - Python GUI & API Development'" C-m
tmux send-keys -t 2 "echo '========================================'" C-m
tmux send-keys -t 2 "echo '担当範囲:'" C-m
tmux send-keys -t 2 "echo '- PyQt6による26機能GUI実装'" C-m
tmux send-keys -t 2 "echo '- Microsoft Graph API統合'" C-m
tmux send-keys -t 2 "echo '- レポート生成エンジン'" C-m
tmux send-keys -t 2 "echo '========================================'" C-m

# Pane 3: Developer dev1 (Test/QA)
tmux select-pane -t 3 -T "🧪 dev1-Test"
tmux send-keys -t 3 "cd $PROJECT_DIR" C-m
tmux send-keys -t 3 "echo '🧪 Developer dev1 - Testing & Quality Assurance'" C-m
tmux send-keys -t 3 "echo '========================================'" C-m
tmux send-keys -t 3 "echo '担当範囲:'" C-m
tmux send-keys -t 3 "echo '- pytest基盤とテスト実装'" C-m
tmux send-keys -t 3 "echo '- CI/CDパイプライン構築'" C-m
tmux send-keys -t 3 "echo '- 互換性・性能テスト'" C-m
tmux send-keys -t 3 "echo '========================================'" C-m

# Pane 4: Developer dev2 (Infrastructure/Compatibility)
tmux select-pane -t 4 -T "🔄 dev2-Infra"
tmux send-keys -t 4 "cd $PROJECT_DIR" C-m
tmux send-keys -t 4 "echo '🔄 Developer dev2 - PowerShell Compatibility & Infrastructure'" C-m
tmux send-keys -t 4 "echo '========================================'" C-m
tmux send-keys -t 4 "echo '担当範囲:'" C-m
tmux send-keys -t 4 "echo '- 既存PowerShell版との互換性確保'" C-m
tmux send-keys -t 4 "echo '- WSL環境とインフラ管理'" C-m
tmux send-keys -t 4 "echo '- 移行ツールとドキュメント'" C-m
tmux send-keys -t 4 "echo '========================================'" C-m

# メッセージングシステムのソース
sleep 1
echo "メッセージングシステムを初期化中..."
for pane in 0 1 2 3 4; do
    tmux send-keys -t $pane "# メッセージングシステム読み込み" C-m
    tmux send-keys -t $pane "if [ -f ./tmux/collaboration/messaging_system.sh ]; then" C-m
    tmux send-keys -t $pane "    source ./tmux/collaboration/messaging_system.sh" C-m
    tmux send-keys -t $pane "    echo 'メッセージングシステム準備完了'" C-m
    tmux send-keys -t $pane "else" C-m
    tmux send-keys -t $pane "    echo '警告: messaging_system.sh が見つかりません'" C-m
    tmux send-keys -t $pane "fi" C-m
done

# チームコマンドのエイリアス設定
sleep 1
echo "チームコマンドを設定中..."
for pane in 0 1 2 3 4; do
    tmux send-keys -t $pane "# チームコマンドエイリアス" C-m
    tmux send-keys -t $pane "alias team='./tmux/collaboration/team_commands.sh'" C-m
    tmux send-keys -t $pane "echo 'teamコマンド準備完了 (team status/request/consult/emergency)'" C-m
done

# 初期ステータス送信
sleep 2
echo "初期ステータスを送信中..."

# Manager (Pane 0)
tmux send-keys -t 0 "# 初期ステータス" C-m
tmux send-keys -t 0 "echo '[Manager] 本日のスプリント計画:'" C-m
tmux send-keys -t 0 "echo '- Phase 1: 基盤構築（2週間）'" C-m
tmux send-keys -t 0 "echo '- dev0: GUI基盤 60%担当'" C-m
tmux send-keys -t 0 "echo '- dev1: テスト基盤 30%担当'" C-m
tmux send-keys -t 0 "echo '- dev2: 環境構築 40%担当'" C-m

# CTO (Pane 1)
tmux send-keys -t 1 "# 初期ステータス" C-m
tmux send-keys -t 1 "echo '[CTO] Python移行戦略策定中...'" C-m
tmux send-keys -t 1 "echo '既存PowerShell版の価値を維持しつつ段階的移行を実施'" C-m

tmux send-keys -t 2 "# 初期ステータス" C-m
tmux send-keys -t 2 "echo '[dev0] PyQt6環境セットアップ開始'" C-m
tmux send-keys -t 2 "cd src/gui" C-m

tmux send-keys -t 3 "# 初期ステータス" C-m
tmux send-keys -t 3 "echo '[dev1] pytest環境準備開始'" C-m
tmux send-keys -t 3 "cd src/tests" C-m

tmux send-keys -t 4 "# 初期ステータス" C-m
tmux send-keys -t 4 "echo '[dev2] PowerShell仕様分析開始'" C-m
tmux send-keys -t 4 "cd Scripts/Common" C-m

# 便利なコマンド一覧表示
sleep 1
echo ""
echo "=== 5ペイン開発環境準備完了 ==="
echo ""
echo "便利なコマンド:"
echo "  team status <role> <message>     - ステータス更新"
echo "  team request <from> <to> <task>  - タスク依頼"
echo "  team consult <from> <to> <topic> - 技術相談"
echo "  team emergency <from> <message>  - 緊急連絡"
echo "  team sync                        - チーム同期"
echo ""
echo "ペイン切り替え: Ctrl-b → 矢印キー"
echo "ペイン番号表示: Ctrl-b q"
echo ""

# セッション接続
echo "セッションに接続します..."
sleep 1
tmux attach-session -t $SESSION_NAME