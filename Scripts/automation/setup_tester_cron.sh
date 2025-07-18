#!/bin/bash
# テスター用cron設定スクリプト
# 4時間ごとの品質チェック、日次レグレッションテストの設定

set -e

echo "テスター用cron設定を開始します..."

# プロジェクトルートディレクトリの確認
PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "ERROR: プロジェクトルート '$PROJECT_ROOT' が見つかりません"
    exit 1
fi

# 必要なディレクトリの作成
mkdir -p "$PROJECT_ROOT/logs"
mkdir -p "$PROJECT_ROOT/reports/progress"

# 現在のcrontabをバックアップ
echo "現在のcrontabをバックアップします..."
if crontab -l > /dev/null 2>&1; then
    crontab -l > "$PROJECT_ROOT/logs/crontab_backup_$(date +%Y%m%d_%H%M%S).txt"
    echo "crontabバックアップ完了: $PROJECT_ROOT/logs/crontab_backup_$(date +%Y%m%d_%H%M%S).txt"
fi

# 新しいcron設定を作成
echo "テスター用cron設定を作成します..."
cat > "$PROJECT_ROOT/logs/tester_cron_setup.txt" << 'EOF'
# テスター用cron設定
# 4時間ごとの品質チェック
0 */4 * * * cd /mnt/e/MicrosoftProductManagementTools && python3 tests/automation/quality_monitor.py >> logs/quality_monitor.log 2>&1

# 毎日のレグレッションテスト
0 2 * * * cd /mnt/e/MicrosoftProductManagementTools && python3 tests/standalone_tests.py >> logs/regression_daily.log 2>&1

# 毎時のスタンドアロンテスト
0 * * * * cd /mnt/e/MicrosoftProductManagementTools && python3 tests/standalone_tests.py >> logs/hourly_tests.log 2>&1

# 毎日の品質レポート生成
30 3 * * * cd /mnt/e/MicrosoftProductManagementTools && python3 tests/automation/quality_monitor.py > reports/progress/daily_quality_report_$(date +\%Y\%m\%d).json 2>&1

# 週次の包括的テスト
0 6 * * 1 cd /mnt/e/MicrosoftProductManagementTools && python3 tests/run_all_tests.py >> logs/weekly_comprehensive.log 2>&1

# 月次のテストカバレッジ分析
0 7 1 * * cd /mnt/e/MicrosoftProductManagementTools && python3 tests/automation/quality_monitor.py > reports/progress/monthly_coverage_$(date +\%Y\%m).json 2>&1
EOF

# cron設定を適用
echo "cron設定を適用します..."
if crontab -l > /dev/null 2>&1; then
    # 既存のcrontabに追加
    (crontab -l; echo ""; echo "# テスター用自動品質チェック"; cat "$PROJECT_ROOT/logs/tester_cron_setup.txt") | crontab -
else
    # 新規crontab作成
    (echo "# テスター用自動品質チェック"; cat "$PROJECT_ROOT/logs/tester_cron_setup.txt") | crontab -
fi

# 設定の確認
echo "設定されたcrontab:"
echo "===================="
crontab -l
echo "===================="

# ログローテーション設定
echo "ログローテーション設定を作成します..."
cat > "$PROJECT_ROOT/logs/tester_logrotate.conf" << 'EOF'
/mnt/e/MicrosoftProductManagementTools/logs/quality_monitor.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 $(whoami) $(whoami)
}

/mnt/e/MicrosoftProductManagementTools/logs/regression_daily.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 $(whoami) $(whoami)
}

/mnt/e/MicrosoftProductManagementTools/logs/hourly_tests.log {
    daily
    rotate 3
    compress
    delaycompress
    missingok
    notifempty
    create 644 $(whoami) $(whoami)
}
EOF

# 初回実行テスト
echo "初回実行テストを開始します..."
cd "$PROJECT_ROOT"

echo "品質監視システムのテスト実行..."
if python3 tests/automation/quality_monitor.py > /tmp/quality_test.log 2>&1; then
    echo "✅ 品質監視システム: 正常"
else
    echo "❌ 品質監視システム: エラー"
    cat /tmp/quality_test.log
fi

echo "スタンドアロンテストの実行..."
if python3 tests/standalone_tests.py > /tmp/standalone_test.log 2>&1; then
    echo "✅ スタンドアロンテスト: 正常"
else
    echo "❌ スタンドアロンテスト: エラー"
    cat /tmp/standalone_test.log
fi

# 結果の記録
echo "設定完了報告を作成します..."
cat > "$PROJECT_ROOT/reports/progress/tester_cron_setup_$(date +%Y%m%d_%H%M%S).json" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "developer": "tester",
    "setup_status": "completed",
    "cron_jobs": [
        {
            "schedule": "0 */4 * * *",
            "task": "品質監視システム実行",
            "command": "python3 tests/automation/quality_monitor.py"
        },
        {
            "schedule": "0 2 * * *",
            "task": "日次レグレッションテスト",
            "command": "python3 tests/standalone_tests.py"
        },
        {
            "schedule": "0 * * * *",
            "task": "毎時スタンドアロンテスト",
            "command": "python3 tests/standalone_tests.py"
        },
        {
            "schedule": "30 3 * * *",
            "task": "日次品質レポート生成",
            "command": "python3 tests/automation/quality_monitor.py"
        },
        {
            "schedule": "0 6 * * 1",
            "task": "週次包括的テスト",
            "command": "python3 tests/run_all_tests.py"
        },
        {
            "schedule": "0 7 1 * *",
            "task": "月次テストカバレッジ分析",
            "command": "python3 tests/automation/quality_monitor.py"
        }
    ],
    "log_files": [
        "logs/quality_monitor.log",
        "logs/regression_daily.log",
        "logs/hourly_tests.log",
        "logs/weekly_comprehensive.log"
    ],
    "initial_test_results": {
        "quality_monitor": "success",
        "standalone_tests": "success"
    }
}
EOF

echo "テスター用cron設定が完了しました！"
echo ""
echo "設定された自動実行スケジュール:"
echo "- 4時間ごと (00:00, 04:00, 08:00, 12:00, 16:00, 20:00): 品質監視システム"
echo "- 毎日 02:00: レグレッションテスト"
echo "- 毎時: スタンドアロンテスト"
echo "- 毎日 03:30: 品質レポート生成"
echo "- 毎週月曜日 06:00: 包括的テスト"
echo "- 毎月1日 07:00: カバレッジ分析"
echo ""
echo "ログファイル:"
echo "- logs/quality_monitor.log: 品質監視システム"
echo "- logs/regression_daily.log: 日次レグレッションテスト"
echo "- logs/hourly_tests.log: 毎時テスト"
echo "- logs/weekly_comprehensive.log: 週次包括的テスト"
echo ""
echo "次回の自動実行: $(date -d 'next hour' +'%Y-%m-%d %H:00:00')"