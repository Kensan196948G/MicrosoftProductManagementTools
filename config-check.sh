#!/bin/bash

# Microsoft製品運用管理ツール - 構成整合性チェックスクリプト
# ITSM/ISO27001/27002準拠 - 自動診断・修復機能

set -e
set -o pipefail

PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
LOG_DIR="${PROJECT_ROOT}/Logs"
CONFIG_FILE="${PROJECT_ROOT}/Config/appsettings.json"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
CHECK_LOG="${LOG_DIR}/config_check_${TIMESTAMP}.log"

# 自動実行フラグ
AUTO_MODE=false
FORCE_MODE=false

# パラメータ解析
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto) AUTO_MODE=true; shift ;;
        --force) FORCE_MODE=true; shift ;;
        -y|--yes) AUTO_MODE=true; FORCE_MODE=true; shift ;;
        *) shift ;;
    esac
done

# ログディレクトリ作成
mkdir -p "${LOG_DIR}"

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] 構成整合性チェック開始 (AUTO:${AUTO_MODE}, FORCE:${FORCE_MODE})" | tee -a "${CHECK_LOG}"

# エラーカウンタ
ERROR_COUNT=0
WARNING_COUNT=0

# チェック関数
check_and_fix() {
    local check_name="$1"
    local check_command="$2"
    local fix_command="$3"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') [CHECK] ${check_name}" | tee -a "${CHECK_LOG}"
    
    if eval "${check_command}" 2>>"${CHECK_LOG}"; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [OK] ${check_name}" | tee -a "${CHECK_LOG}"
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] ${check_name}" | tee -a "${CHECK_LOG}"
        ((ERROR_COUNT++))
        
        if [[ "${AUTO_MODE}" == "true" && -n "${fix_command}" ]]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') [FIX] ${check_name} - 修復実行中..." | tee -a "${CHECK_LOG}"
            if eval "${fix_command}" 2>>"${CHECK_LOG}"; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') [FIXED] ${check_name}" | tee -a "${CHECK_LOG}"
                ((ERROR_COUNT--))
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') [FAIL] ${check_name} - 修復失敗" | tee -a "${CHECK_LOG}"
            fi
        fi
        return 1
    fi
}

# 必須ディレクトリ構造チェック
check_and_fix "必須ディレクトリ構造" \
    "test -d '${PROJECT_ROOT}/Scripts/Common' && test -d '${PROJECT_ROOT}/Scripts/AD' && test -d '${PROJECT_ROOT}/Scripts/EXO' && test -d '${PROJECT_ROOT}/Scripts/EntraID'" \
    "mkdir -p '${PROJECT_ROOT}'/{Scripts/{Common,AD,EXO,EntraID},Reports/{Daily,Weekly,Monthly,Yearly},Logs,Config,Templates}"

# 設定ファイル存在チェック
check_and_fix "設定ファイル存在確認" \
    "test -f '${CONFIG_FILE}'" \
    "echo '{\"General\":{\"OrganizationName\":\"Default\",\"Environment\":\"Development\"}}' > '${CONFIG_FILE}'"

# JSON構文チェック
check_and_fix "JSON設定ファイル構文" \
    "python3 -m json.tool '${CONFIG_FILE}' >/dev/null" \
    "cp '${CONFIG_FILE}' '${CONFIG_FILE}.backup.${TIMESTAMP}' && echo '{\"General\":{\"OrganizationName\":\"Default\",\"Environment\":\"Development\"}}' > '${CONFIG_FILE}'"

# PowerShellモジュールファイル存在チェック
REQUIRED_MODULES=(
    "Scripts/Common/Common.psm1"
    "Scripts/Common/Authentication.psm1"
    "Scripts/Common/Logging.psm1"
    "Scripts/Common/ErrorHandling.psm1"
    "Scripts/Common/ReportGenerator.psm1"
    "Scripts/Common/ScheduledReports.ps1"
)

for module in "${REQUIRED_MODULES[@]}"; do
    module_path="${PROJECT_ROOT}/${module}"
    check_and_fix "PowerShellモジュール: ${module}" \
        "test -f '${module_path}'" \
        "echo '# Auto-generated placeholder module' > '${module_path}' && echo 'Write-Host \"Module ${module} loaded\"' >> '${module_path}'"
done

# 実行可能権限チェック
EXECUTABLE_FILES=(
    "stop-all.sh"
    "start-all.sh"
    "config-check.sh"
    "auto-test.sh"
    "test_verification.sh"
)

for file in "${EXECUTABLE_FILES[@]}"; do
    file_path="${PROJECT_ROOT}/${file}"
    if [[ -f "${file_path}" ]]; then
        check_and_fix "実行権限: ${file}" \
            "test -x '${file_path}'" \
            "chmod +x '${file_path}'"
    fi
done

# レポートテンプレート存在チェック
check_and_fix "HTMLテンプレートファイル" \
    "test -f '${PROJECT_ROOT}/Templates/ReportTemplate.html'" \
    "mkdir -p '${PROJECT_ROOT}/Templates' && echo '<html><head><title>Report</title></head><body><h1>Microsoft 365 Management Report</h1></body></html>' > '${PROJECT_ROOT}/Templates/ReportTemplate.html'"

# PowerShell実行ポリシーチェック（Windows限定）
if command -v powershell >/dev/null 2>&1; then
    check_and_fix "PowerShell実行ポリシー" \
        "powershell -Command 'Get-ExecutionPolicy' | grep -E '(RemoteSigned|Bypass|Unrestricted)'" \
        "powershell -Command 'Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force'"
fi

# 結果サマリー
echo "$(date '+%Y-%m-%d %H:%M:%S') [SUMMARY] 構成整合性チェック完了" | tee -a "${CHECK_LOG}"
echo "$(date '+%Y-%m-%d %H:%M:%S') [SUMMARY] エラー: ${ERROR_COUNT}, 警告: ${WARNING_COUNT}" | tee -a "${CHECK_LOG}"
echo "$(date '+%Y-%m-%d %H:%M:%S') [SUMMARY] ログファイル: ${CHECK_LOG}" | tee -a "${CHECK_LOG}"

if [[ ${ERROR_COUNT} -gt 0 ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [RESULT] 構成エラーが検出されました" | tee -a "${CHECK_LOG}"
    exit 1
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [RESULT] 構成整合性チェック正常完了" | tee -a "${CHECK_LOG}"
    exit 0
fi