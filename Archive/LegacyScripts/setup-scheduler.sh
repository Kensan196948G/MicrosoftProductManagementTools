#!/bin/bash

# ================================================================================
# スケジューラー設定スクリプト（Linux/WSL対応）
# ITSM/ISO27001/27002準拠 - 定期レポート自動生成
# ================================================================================

PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
LOG_DIR="${PROJECT_ROOT}/Logs"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
SETUP_LOG="${LOG_DIR}/scheduler_setup_${TIMESTAMP}.log"

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] スケジューラー設定開始" | tee -a "${SETUP_LOG}"

# 設定ファイル読み込み
if [[ -f "${PROJECT_ROOT}/Config/appsettings.json" ]]; then
    # 設定からスケジュール時間を抽出
    DAILY_TIME=$(python3 -c "import json; data=json.load(open('${PROJECT_ROOT}/Config/appsettings.json')); print(data['Scheduling']['DailyReportTime'])" 2>/dev/null || echo "06:00")
    WEEKLY_TIME=$(python3 -c "import json; data=json.load(open('${PROJECT_ROOT}/Config/appsettings.json')); print(data['Scheduling']['WeeklyReportTime'])" 2>/dev/null || echo "07:00")
    MONTHLY_TIME=$(python3 -c "import json; data=json.load(open('${PROJECT_ROOT}/Config/appsettings.json')); print(data['Scheduling']['MonthlyReportTime'])" 2>/dev/null || echo "08:00")
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] 設定読み込み完了" | tee -a "${SETUP_LOG}"
    echo "  日次レポート時刻: ${DAILY_TIME}" | tee -a "${SETUP_LOG}"
    echo "  週次レポート時刻: ${WEEKLY_TIME}" | tee -a "${SETUP_LOG}"
    echo "  月次レポート時刻: ${MONTHLY_TIME}" | tee -a "${SETUP_LOG}"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] 設定ファイルが見つかりません" | tee -a "${SETUP_LOG}"
    exit 1
fi

# cron時間形式に変換
DAILY_HOUR=$(echo "${DAILY_TIME}" | cut -d':' -f1)
DAILY_MIN=$(echo "${DAILY_TIME}" | cut -d':' -f2)
WEEKLY_HOUR=$(echo "${WEEKLY_TIME}" | cut -d':' -f1)
WEEKLY_MIN=$(echo "${WEEKLY_TIME}" | cut -d':' -f2)
MONTHLY_HOUR=$(echo "${MONTHLY_TIME}" | cut -d':' -f1)
MONTHLY_MIN=$(echo "${MONTHLY_TIME}" | cut -d':' -f2)

# PowerShellコマンド確認
if command -v pwsh >/dev/null 2>&1; then
    PS_CMD="pwsh"
elif command -v powershell >/dev/null 2>&1; then
    PS_CMD="powershell"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] PowerShellが見つかりません" | tee -a "${SETUP_LOG}"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] PowerShell: ${PS_CMD}" | tee -a "${SETUP_LOG}"

# レート制限チェック関数
create_safe_command() {
    local script_name="$1"
    local ps_command="$2"
    
    cat << EOF
#!/bin/bash
source "${PROJECT_ROOT}/log-management-config.sh"
if create_rate_limit '${script_name}' 3600; then
    cd "${PROJECT_ROOT}"
    ${ps_command} >> "${LOG_DIR}/scheduled_${script_name}_\$(date '+%Y%m%d_%H%M%S').log" 2>&1
else
    echo "\$(date '+%Y-%m-%d %H:%M:%S') [INFO] Rate limited: ${script_name}" >> "${LOG_DIR}/rate_limit.log"
fi
EOF
}

# スケジュールスクリプト作成
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] スケジュールスクリプト作成中..." | tee -a "${SETUP_LOG}"

# 日次レポートスクリプト
create_safe_command "daily-report" "${PS_CMD} -ExecutionPolicy Bypass -File '${PROJECT_ROOT}/Scripts/Common/ScheduledReports.ps1' -ReportType Daily" > "${PROJECT_ROOT}/run-daily-report.sh"
chmod +x "${PROJECT_ROOT}/run-daily-report.sh"

# 週次レポートスクリプト
create_safe_command "weekly-report" "${PS_CMD} -ExecutionPolicy Bypass -File '${PROJECT_ROOT}/Scripts/Common/ScheduledReports.ps1' -ReportType Weekly" > "${PROJECT_ROOT}/run-weekly-report.sh"
chmod +x "${PROJECT_ROOT}/run-weekly-report.sh"

# 月次レポートスクリプト
create_safe_command "monthly-report" "${PS_CMD} -ExecutionPolicy Bypass -File '${PROJECT_ROOT}/Scripts/Common/ScheduledReports.ps1' -ReportType Monthly" > "${PROJECT_ROOT}/run-monthly-report.sh"
chmod +x "${PROJECT_ROOT}/run-monthly-report.sh"

# システムヘルスチェックスクリプト
create_safe_command "health-check" "bash '${PROJECT_ROOT}/config-check.sh' --auto" > "${PROJECT_ROOT}/run-health-check.sh"
chmod +x "${PROJECT_ROOT}/run-health-check.sh"

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] スケジュールスクリプト作成完了" | tee -a "${SETUP_LOG}"

# crontab設定提案
CRONTAB_CONTENT=$(cat << EOF
# Microsoft製品運用管理ツール - 自動スケジュール
# 日次レポート (${DAILY_TIME})
${DAILY_MIN} ${DAILY_HOUR} * * * ${PROJECT_ROOT}/run-daily-report.sh

# 週次レポート (月曜日 ${WEEKLY_TIME})
${WEEKLY_MIN} ${WEEKLY_HOUR} * * 1 ${PROJECT_ROOT}/run-weekly-report.sh

# 月次レポート (毎月1日 ${MONTHLY_TIME})
${MONTHLY_MIN} ${MONTHLY_HOUR} 1 * * ${PROJECT_ROOT}/run-monthly-report.sh

# システムヘルスチェック (毎時)
0 * * * * ${PROJECT_ROOT}/run-health-check.sh

# ログローテーション (毎日深夜)
0 0 * * * ${PROJECT_ROOT}/log-management-config.sh > /dev/null 2>&1
EOF
)

# crontab設定ファイル出力
echo "${CRONTAB_CONTENT}" > "${PROJECT_ROOT}/crontab-schedule.txt"

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] crontab設定ファイル作成: ${PROJECT_ROOT}/crontab-schedule.txt" | tee -a "${SETUP_LOG}"

# 現在のcrontab確認
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] 現在のcrontab確認..." | tee -a "${SETUP_LOG}"
crontab -l 2>/dev/null | tee -a "${SETUP_LOG}" || echo "crontabエントリなし" | tee -a "${SETUP_LOG}"

# インストール指示
cat << EOF | tee -a "${SETUP_LOG}"

=== スケジューラー設定完了 ===

以下のコマンドでcrontabに追加してください:

# 設定を確認
cat ${PROJECT_ROOT}/crontab-schedule.txt

# crontabに追加（既存設定と統合）
crontab -l 2>/dev/null; cat ${PROJECT_ROOT}/crontab-schedule.txt) | crontab -

# または手動でcrontab編集
crontab -e

=== 作成されたファイル ===
- ${PROJECT_ROOT}/run-daily-report.sh
- ${PROJECT_ROOT}/run-weekly-report.sh 
- ${PROJECT_ROOT}/run-monthly-report.sh
- ${PROJECT_ROOT}/run-health-check.sh
- ${PROJECT_ROOT}/crontab-schedule.txt

=== スケジュール詳細 ===
- 日次レポート: 毎日 ${DAILY_TIME}
- 週次レポート: 毎週月曜日 ${WEEKLY_TIME}
- 月次レポート: 毎月1日 ${MONTHLY_TIME}
- ヘルスチェック: 毎時
- ログローテーション: 毎日深夜

EOF

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] スケジューラー設定完了" | tee -a "${SETUP_LOG}"
exit 0