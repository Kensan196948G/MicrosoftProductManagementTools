#!/bin/bash

# Microsoft製品運用管理ツール - 日次レポート生成スクリプト
# ITSM/ISO27001/27002準拠

set -e

PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

echo "=== 日次レポート生成開始 ==="
echo "実行時刻: $(date '+%Y年%m月%d日 %H:%M:%S')"

cd "$PROJECT_ROOT"

# 簡易日次レポート実行
echo "日次レポートを生成中..."
pwsh -File test-daily-report.ps1 -ReportType Daily

echo "=== 日次レポート生成完了 ==="