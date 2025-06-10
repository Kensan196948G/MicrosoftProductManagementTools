#!/bin/bash

# Microsoft製品運用管理ツール - クイックテストスクリプト
# ITSM/ISO27001/27002準拠 - 高速検証テスト

set -e

PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
LOG_DIR="${PROJECT_ROOT}/Logs"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
QUICK_LOG="${LOG_DIR}/quick_test_${TIMESTAMP}.log"

mkdir -p "${LOG_DIR}"

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] クイックテスト開始" | tee -a "${QUICK_LOG}"

# テスト結果
TESTS_PASSED=0
TESTS_FAILED=0

# 基本的なファイル存在チェック
check_file() {
    local file="$1"
    local description="$2"
    
    if [[ -f "${file}" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [PASS] ${description}"
        ((TESTS_PASSED++))
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [FAIL] ${description}"
        ((TESTS_FAILED++))
    fi
}

# ディレクトリ存在チェック
check_dir() {
    local dir="$1"
    local description="$2"
    
    if [[ -d "${dir}" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [PASS] ${description}"
        ((TESTS_PASSED++))
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [FAIL] ${description}"
        ((TESTS_FAILED++))
    fi
}

# 実行権限チェック
check_executable() {
    local file="$1"
    local description="$2"
    
    if [[ -x "${file}" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [PASS] ${description}"
        ((TESTS_PASSED++))
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [FAIL] ${description}"
        ((TESTS_FAILED++))
    fi
}

# 基本チェック実行
echo "$(date '+%Y-%m-%d %H:%M:%S') [TEST] 基本構造チェック開始" | tee -a "${QUICK_LOG}"

check_dir "${PROJECT_ROOT}/Scripts/Common" "Commonディレクトリ"
check_dir "${PROJECT_ROOT}/Scripts/AD" "ADディレクトリ"
check_dir "${PROJECT_ROOT}/Scripts/EXO" "EXOディレクトリ"
check_dir "${PROJECT_ROOT}/Scripts/EntraID" "EntraIDディレクトリ"
check_dir "${PROJECT_ROOT}/Config" "Configディレクトリ"
check_dir "${PROJECT_ROOT}/Templates" "Templatesディレクトリ"
check_dir "${PROJECT_ROOT}/Reports" "Reportsディレクトリ"
check_dir "${PROJECT_ROOT}/Logs" "Logsディレクトリ"

check_file "${PROJECT_ROOT}/Config/appsettings.json" "設定ファイル"
check_file "${PROJECT_ROOT}/Templates/ReportTemplate.html" "HTMLテンプレート"

check_file "${PROJECT_ROOT}/Scripts/Common/Common.psm1" "Commonモジュール"
check_file "${PROJECT_ROOT}/Scripts/Common/Authentication.psm1" "Authenticationモジュール"
check_file "${PROJECT_ROOT}/Scripts/Common/Logging.psm1" "Loggingモジュール"
check_file "${PROJECT_ROOT}/Scripts/Common/ErrorHandling.psm1" "ErrorHandlingモジュール"
check_file "${PROJECT_ROOT}/Scripts/Common/ReportGenerator.psm1" "ReportGeneratorモジュール"
check_file "${PROJECT_ROOT}/Scripts/Common/ScheduledReports.ps1" "ScheduledReportsスクリプト"

check_executable "${PROJECT_ROOT}/stop-all.sh" "stop-all.sh実行権限"
check_executable "${PROJECT_ROOT}/start-all.sh" "start-all.sh実行権限"
check_executable "${PROJECT_ROOT}/config-check.sh" "config-check.sh実行権限"
check_executable "${PROJECT_ROOT}/auto-test.sh" "auto-test.sh実行権限"
check_executable "${PROJECT_ROOT}/auto-repair.sh" "auto-repair.sh実行権限"

# JSON構文チェック
echo "$(date '+%Y-%m-%d %H:%M:%S') [TEST] JSON構文チェック" | tee -a "${QUICK_LOG}"
if python3 -m json.tool "${PROJECT_ROOT}/Config/appsettings.json" >/dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [PASS] JSON構文正常" | tee -a "${QUICK_LOG}"
    ((TESTS_PASSED++))
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [FAIL] JSON構文エラー" | tee -a "${QUICK_LOG}"
    ((TESTS_FAILED++))
fi

# PowerShell利用可能性チェック
echo "$(date '+%Y-%m-%d %H:%M:%S') [TEST] PowerShell利用可能性" | tee -a "${QUICK_LOG}"
if command -v powershell >/dev/null 2>&1 || command -v pwsh >/dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [PASS] PowerShell利用可能" | tee -a "${QUICK_LOG}"
    ((TESTS_PASSED++))
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [FAIL] PowerShell利用不可" | tee -a "${QUICK_LOG}"
    ((TESTS_FAILED++))
fi

# 結果サマリー
TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
echo "$(date '+%Y-%m-%d %H:%M:%S') [SUMMARY] クイックテスト完了" | tee -a "${QUICK_LOG}"
echo "$(date '+%Y-%m-%d %H:%M:%S') [SUMMARY] 総テスト数: ${TOTAL_TESTS}" | tee -a "${QUICK_LOG}"
echo "$(date '+%Y-%m-%d %H:%M:%S') [SUMMARY] 成功: ${TESTS_PASSED}, 失敗: ${TESTS_FAILED}" | tee -a "${QUICK_LOG}"
echo "$(date '+%Y-%m-%d %H:%M:%S') [SUMMARY] ログファイル: ${QUICK_LOG}" | tee -a "${QUICK_LOG}"

if [[ ${TESTS_FAILED} -eq 0 ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [RESULT] 全テスト正常完了" | tee -a "${QUICK_LOG}"
    exit 0
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [RESULT] テスト失敗検出" | tee -a "${QUICK_LOG}"
    exit 1
fi