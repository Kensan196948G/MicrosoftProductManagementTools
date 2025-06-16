#!/bin/bash

# Microsoft製品運用管理ツール - 緊急停止スクリプト
# ITSM/ISO27001/27002準拠 - 自動修復ループ対応

set -e
set -o pipefail

LOG_DIR="/mnt/e/MicrosoftProductManagementTools/Logs"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
STOP_LOG="${LOG_DIR}/stop_all_${TIMESTAMP}.log"

# ログディレクトリ作成
mkdir -p "${LOG_DIR}"

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Microsoft製品運用管理ツール緊急停止開始" | tee -a "${STOP_LOG}"

# PowerShellプロセス停止
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] PowerShellプロセス停止中..." | tee -a "${STOP_LOG}"
pkill -f "powershell" 2>/dev/null || true
pkill -f "pwsh" 2>/dev/null || true

# タスクスケジューラーの無効化（Windows）
if command -v schtasks >/dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] タスクスケジューラー無効化中..." | tee -a "${STOP_LOG}"
    schtasks /change /tn "MS365DailyReport" /disable 2>/dev/null || true
    schtasks /change /tn "MS365WeeklyReport" /disable 2>/dev/null || true
    schtasks /change /tn "MS365MonthlyReport" /disable 2>/dev/null || true
    schtasks /change /tn "MS365YearlyReport" /disable 2>/dev/null || true
fi

# 実行中のバックグラウンドジョブ停止
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] バックグラウンドジョブ停止中..." | tee -a "${STOP_LOG}"
jobs -p | xargs -r kill -TERM 2>/dev/null || true

# ログローテーション実行
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ログローテーション実行中..." | tee -a "${STOP_LOG}"
find "${LOG_DIR}" -type f -name "*.log" -mtime +7 -exec gzip {} \; 2>/dev/null || true

# 停止完了フラグファイル作成
touch "${LOG_DIR}/SYSTEM_STOPPED_${TIMESTAMP}"

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] システム停止完了" | tee -a "${STOP_LOG}"
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ログファイル: ${STOP_LOG}" | tee -a "${STOP_LOG}"

exit 0