#!/bin/bash

# Docker エントリーポイント
set -e

# cron開始
service cron start

# ログディレクトリの権限設定
chmod 755 /app/logs /app/reports/progress

# 初回のDevOpsメトリクス収集
echo "Starting initial DevOps metrics collection..."
/app/scripts/automation/devops_monitor.sh

# メインアプリケーション実行
exec "$@"