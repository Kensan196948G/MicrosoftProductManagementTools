#!/bin/bash

# DevOps用cron設定スクリプト
# 自動実行スケジュールの設定

set -euo pipefail

PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
CRON_FILE="/tmp/devops_cron"

echo "Setting up DevOps cron jobs..."

# 既存のcrontabを取得
crontab -l 2>/dev/null > "$CRON_FILE" || echo "# DevOps cron jobs" > "$CRON_FILE"

# DevOps固有のcronジョブを追加
cat >> "$CRON_FILE" << EOF

# DevOps 進捗監視 - 4時間ごと
0 */4 * * * cd $PROJECT_ROOT && ./scripts/automation/devops_monitor.sh >> logs/devops_monitor.log 2>&1

# 統合メトリクス収集 - 4時間ごと
15 */4 * * * cd $PROJECT_ROOT && python3 scripts/automation/collect_all_metrics.py >> logs/metrics_collector.log 2>&1

# 日次システムヘルスチェック - 毎朝6時
0 6 * * * cd $PROJECT_ROOT && ./scripts/automation/daily_health_check.sh >> logs/health_check.log 2>&1

# 週次Docker環境クリーンアップ - 毎週日曜日2時
0 2 * * 0 cd $PROJECT_ROOT && ./scripts/automation/weekly_cleanup.sh >> logs/cleanup.log 2>&1

# 月次レポート統合 - 毎月1日1時
0 1 1 * * cd $PROJECT_ROOT && ./scripts/automation/monthly_report.sh >> logs/monthly_report.log 2>&1

EOF

# crontabに設定
if crontab "$CRON_FILE"; then
    echo "✅ DevOps cron jobs installed successfully"
    echo "Current crontab:"
    crontab -l | grep -E "(devops|metrics|health|cleanup|monthly)"
else
    echo "❌ Failed to install cron jobs"
    exit 1
fi

# 一時ファイル削除
rm -f "$CRON_FILE"

echo "DevOps cron setup completed"