#!/bin/bash
# Backend Developer - Cron Setup Script for Progress Collection
# 進捗収集システムのcron設定スクリプト

# 設定変数
PROJECT_DIR="/mnt/e/MicrosoftProductManagementTools"
PYTHON_EXEC="python3"
LOG_DIR="$PROJECT_DIR/logs"
BACKEND_LOG="$LOG_DIR/backend_progress.log"

# ログディレクトリ作成
mkdir -p "$LOG_DIR"

# 現在のcrontab設定を確認
echo "=== 現在のcrontab設定 ==="
crontab -l 2>/dev/null || echo "crontabが設定されていません"

# バックアップ作成
echo "=== crontabのバックアップ作成 ==="
crontab -l > "$PROJECT_DIR/backup_crontab_$(date +%Y%m%d_%H%M%S).txt" 2>/dev/null || echo "既存のcrontabなし"

# 新しいcron設定を追加
echo "=== バックエンド進捗収集のcron設定追加 ==="

# 一時ファイル作成
TEMP_CRON=$(mktemp)

# 既存のcron設定を保持
crontab -l > "$TEMP_CRON" 2>/dev/null || echo "# New crontab" > "$TEMP_CRON"

# バックエンド進捗収集の設定を追加（4時間ごと）
cat >> "$TEMP_CRON" << EOF

# Backend Developer - Progress Collection System
# 4時間ごとのバックエンド進捗収集
0 */4 * * * cd $PROJECT_DIR && $PYTHON_EXEC -m src.automation.progress_api >> $BACKEND_LOG 2>&1

# 毎日午前2時の詳細レポート生成
0 2 * * * cd $PROJECT_DIR && $PYTHON_EXEC -c "
import asyncio
import sys
sys.path.append('$PROJECT_DIR')
from src.automation.progress_api import ProgressCollector
async def daily_report():
    collector = ProgressCollector()
    report = await collector.generate_progress_report()
    print('Daily backend report generated')
asyncio.run(daily_report())
" >> $BACKEND_LOG 2>&1

# 毎週月曜日の週次レポート
0 8 * * 1 cd $PROJECT_DIR && $PYTHON_EXEC -c "
import asyncio
import sys
sys.path.append('$PROJECT_DIR')
from src.automation.progress_api import ProgressCollector
async def weekly_report():
    collector = ProgressCollector()
    report = await collector.generate_progress_report()
    print('Weekly backend report generated')
asyncio.run(weekly_report())
" >> $BACKEND_LOG 2>&1

EOF

# 新しいcron設定を適用
crontab "$TEMP_CRON"

# 一時ファイルを削除
rm "$TEMP_CRON"

# 設定確認
echo "=== 新しいcrontab設定 ==="
crontab -l

# ログファイル初期化
echo "=== ログファイル初期化 ==="
echo "Backend progress collection system initialized at $(date)" > "$BACKEND_LOG"

# 権限設定
chmod 644 "$BACKEND_LOG"

echo "=== Backend cron setup completed ==="
echo "Log file: $BACKEND_LOG"
echo "Next execution times:"
echo "- 4時間ごとの進捗収集: 次回実行時刻を確認してください"
echo "- 毎日午前2時: 詳細レポート生成"
echo "- 毎週月曜日午前8時: 週次レポート生成"