#!/bin/bash
# 進捗収集システム初回テスト
# 全ペインで同時実行

echo "=== 進捗収集システム初回テスト ==="
echo "開始時刻: $(date)"
echo "実行環境: tmux 5ペイン構成"

PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
REPORT_DIR="$PROJECT_ROOT/reports/progress"

# ディレクトリ作成
mkdir -p "$REPORT_DIR"

# 各ペインの模擬データ生成
generate_test_data() {
    local role=$1
    local timestamp=$(date -Iseconds)
    
    case $role in
        "architect")
            cat > "$REPORT_DIR/architect_status.json" << EOF
{
    "timestamp": "$timestamp",
    "developer": "architect",
    "metrics": {
        "design_completion": 95,
        "api_specs_defined": 18,
        "bridge_patterns_documented": 12
    },
    "status": "active"
}
EOF
            ;;
        "backend")
            cat > "$REPORT_DIR/backend_status.json" << EOF
{
    "timestamp": "$timestamp",
    "developer": "backend",
    "metrics": {
        "api_endpoints_completed": 15,
        "test_coverage": 89.5,
        "graph_api_integration": "completed",
        "powershell_bridge_status": "in_progress"
    }
}
EOF
            ;;
        "frontend")
            cat > "$REPORT_DIR/frontend_status.json" << EOF
{
    "timestamp": "$timestamp",
    "developer": "frontend",
    "metrics": {
        "gui_components_completed": 18,
        "pyqt6_coverage": 91.2,
        "ui_consistency_score": 94
    }
}
EOF
            ;;
        "tester")
            cat > "$REPORT_DIR/tester_status.json" << EOF
{
    "timestamp": "$timestamp",
    "developer": "tester",
    "metrics": {
        "test_coverage": 87.0,
        "test_cases_written": 156,
        "regression_tests_passed": 142,
        "compatibility_score": 96
    }
}
EOF
            ;;
        "devops")
            cat > "$REPORT_DIR/devops_status.json" << EOF
{
    "timestamp": "$timestamp",
    "developer": "devops",
    "metrics": {
        "ci_pipeline_status": "operational",
        "docker_builds_successful": 24,
        "deployment_readiness": 90,
        "monitoring_uptime": 99.95
    }
}
EOF
            ;;
    esac
}

# エスカレーションテスト
test_escalation() {
    echo ""
    echo "=== エスカレーション判定テスト ==="
    
    # テスターのカバレッジ87%を検出 (jqがない場合はgrepで代替)
    if command -v jq >/dev/null 2>&1; then
        coverage=$(jq -r '.metrics.test_coverage' "$REPORT_DIR/tester_status.json")
    else
        # jqがない場合はgrepとsedで抽出
        coverage=$(grep -o '"test_coverage": [0-9.]*' "$REPORT_DIR/tester_status.json" | sed 's/.*: //')
    fi
    
    # bcコマンドの代替としてbashの算術比較を使用
    coverage_int=${coverage%.*}  # 小数点以下を削除
    if [ "$coverage_int" -lt 90 ]; then
        echo "⚠️  エスカレーション発動: テストカバレッジ $coverage% (基準90%未満)"
        echo "📨 アーキテクトへの通知送信（テストモード）"
        
        # tmux共有コンテキストに追記
        echo "" >> "$PROJECT_ROOT/tmux_shared_context.md"
        echo "### 🚨 エスカレーションアラート ($(date))" >> "$PROJECT_ROOT/tmux_shared_context.md"
        echo "- テストカバレッジ低下: $coverage% < 90%" >> "$PROJECT_ROOT/tmux_shared_context.md"
        echo "- 対応要求: テスト補強が必要" >> "$PROJECT_ROOT/tmux_shared_context.md"
    else
        echo "✅ エスカレーション基準クリア"
    fi
}

# ダッシュボード表示
display_dashboard() {
    echo ""
    echo "=== 統合進捗ダッシュボード ==="
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║      Python移行プロジェクト進捗 - TEST MODE                     ║
╠════════╬═════════════╬════════╬═══════════╬═══════════╬══════════╣
║ ペイン  │ 役割        │ 進捗率 │ カバレッジ │ 品質スコア │ ステータス ║
╠════════┼═════════════┼════════┼═══════════┼═══════════┼══════════╣
║ Pane 0 │ アーキテクト │  95%   │    N/A    │    A+     │    🟢    ║
║ Pane 1 │ バックエンド │  82%   │   89.5%   │    A      │    🟢    ║
║ Pane 2 │ フロント    │  75%   │   91.2%   │    A      │    🟢    ║
║ Pane 3 │ テスター    │  88%   │   87.0%   │    B+     │    🟡    ║
║ Pane 4 │ DevOps      │  90%   │    N/A    │    A      │    🟢    ║
╚════════╧═════════════╧════════╧═══════════╧═══════════╧══════════╝
EOF
}

# メイン実行
echo "テストデータ生成中..."
for role in architect backend frontend tester devops; do
    generate_test_data $role
    echo "  ✓ $role データ生成完了"
done

test_escalation
display_dashboard

echo ""
echo "=== テスト完了 ==="
echo "次回自動実行: $(date -d '+4 hours')"
echo "レポート保存先: $REPORT_DIR"
echo ""
echo "📝 各ペインはcron設定を確認してください:" 
echo "   crontab -e"
echo "   0 */4 * * * $PROJECT_ROOT/scripts/automation/progress_monitor.sh"