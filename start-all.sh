#!/bin/bash

# Microsoft製品運用管理ツール - 自動開始スクリプト
# ITSM/ISO27001/27002準拠 - 完全自動修復ループ対応

set -e
set -o pipefail

PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
LOG_DIR="${PROJECT_ROOT}/Logs"
REPORTS_DIR="${PROJECT_ROOT}/Reports"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
START_LOG="${LOG_DIR}/start_all_${TIMESTAMP}.log"

# 必要ディレクトリ作成
mkdir -p "${LOG_DIR}" "${REPORTS_DIR}"/{Daily,Weekly,Monthly,Yearly}

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Microsoft製品運用管理ツール自動開始" | tee -a "${START_LOG}"

# システム状態チェック
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] システム状態チェック実行中..." | tee -a "${START_LOG}"

# PowerShellモジュール確認
if command -v powershell >/dev/null 2>&1; then
    POWERSHELL_CMD="powershell"
elif command -v pwsh >/dev/null 2>&1; then
    POWERSHELL_CMD="pwsh"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] PowerShellが見つかりません" | tee -a "${START_LOG}"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] PowerShell: ${POWERSHELL_CMD}" | tee -a "${START_LOG}"

# 構成整合性チェック実行
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] 構成整合性チェック実行中..." | tee -a "${START_LOG}"
cd "${PROJECT_ROOT}"
bash config-check.sh --auto --force 2>&1 | tee -a "${START_LOG}"

# 自動テスト実行
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] 自動テスト実行中..." | tee -a "${START_LOG}"
bash auto-test.sh --comprehensive --fix-errors --force 2>&1 | tee -a "${START_LOG}"

# タスクスケジューラー有効化（Windows）
if command -v schtasks >/dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] タスクスケジューラー有効化中..." | tee -a "${START_LOG}"
    schtasks /change /tn "MS365DailyReport" /enable 2>/dev/null || true
    schtasks /change /tn "MS365WeeklyReport" /enable 2>/dev/null || true
    schtasks /change /tn "MS365MonthlyReport" /enable 2>/dev/null || true
    schtasks /change /tn "MS365YearlyReport" /enable 2>/dev/null || true
fi

# 初回レポート生成
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] 初回レポート生成中..." | tee -a "${START_LOG}"
${POWERSHELL_CMD} -ExecutionPolicy Bypass -File "${PROJECT_ROOT}/Scripts/Common/ScheduledReports.ps1" -ReportType "Daily" -Force -Y 2>&1 | tee -a "${START_LOG}"

# 開始完了フラグファイル作成
touch "${LOG_DIR}/SYSTEM_STARTED_${TIMESTAMP}"

# 停止フラグファイル削除
rm -f "${LOG_DIR}"/SYSTEM_STOPPED_* 2>/dev/null || true

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] システム開始完了" | tee -a "${START_LOG}"
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ログファイル: ${START_LOG}" | tee -a "${START_LOG}"

exit 0