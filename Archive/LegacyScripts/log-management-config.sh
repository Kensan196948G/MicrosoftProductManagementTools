#!/bin/bash

# ログ管理設定スクリプト
# 無限ループ防止とログローテーション設定

PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
LOG_DIR="${PROJECT_ROOT}/Logs"
LOCK_DIR="${LOG_DIR}/locks"

# ロックディレクトリ作成
mkdir -p "${LOCK_DIR}"

# 無限ループ防止設定
create_rate_limit() {
    local script_name="$1"
    local min_interval="$2"  # 最小実行間隔（秒）
    
    local lock_file="${LOCK_DIR}/${script_name}.lock"
    local last_run_file="${LOCK_DIR}/${script_name}.lastrun"
    
    # 前回実行時刻確認
    if [[ -f "${last_run_file}" ]]; then
        local last_run=$(cat "${last_run_file}")
        local current_time=$(date +%s)
        local elapsed=$((current_time - last_run))
        
        if [[ ${elapsed} -lt ${min_interval} ]]; then
            echo "Rate limit: ${script_name} は ${min_interval} 秒間隔で実行してください"
            echo "前回実行からの経過時間: ${elapsed} 秒"
            return 1
        fi
    fi
    
    # 実行時刻記録
    date +%s > "${last_run_file}"
    return 0
}

# ログローテーション設定
setup_log_rotation() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ログローテーション設定中..."
    
    # 7日以上古いログファイルを圧縮
    find "${LOG_DIR}" -name "config_check_*.log" -mtime +0 -exec gzip {} \;
    find "${LOG_DIR}" -name "auto_test_*.log" -mtime +0 -exec gzip {} \;
    find "${LOG_DIR}" -name "auto_repair_*.log" -mtime +0 -exec gzip {} \;
    
    # 30日以上古い圧縮ログを削除
    find "${LOG_DIR}" -name "*.log.gz" -mtime +30 -delete
    
    # ログファイル数制限（最新50個まで保持）
    ls -t "${LOG_DIR}"/config_check_*.log.gz 2>/dev/null | tail -n +51 | xargs -r rm -f
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ログローテーション完了"
}

# システム状態確認
check_system_health() {
    local log_count=$(ls -1 "${LOG_DIR}"/config_check_*.log 2>/dev/null | wc -l)
    local gz_count=$(ls -1 "${LOG_DIR}"/config_check_*.log.gz 2>/dev/null | wc -l)
    
    echo "現在のログファイル数: ${log_count}"
    echo "圧縮済みログファイル数: ${gz_count}"
    
    # 大量ログ警告
    if [[ ${log_count} -gt 10 ]]; then
        echo "警告: config_checkログが大量に生成されています (${log_count}個)"
        echo "自動実行の設定を確認してください"
    fi
}

# メイン実行
echo "=== ログ管理設定 ==="
setup_log_rotation
check_system_health

echo ""
echo "=== 実行間隔制限設定 ==="
echo "config-check.sh: 最小300秒（5分）間隔"
echo "auto-test.sh: 最小600秒（10分）間隔"
echo "auto-repair.sh: 最小1800秒（30分）間隔"

# 使用例の表示
echo ""
echo "=== 使用方法 ==="
echo "# スクリプト実行前にレート制限チェック"
echo "source log-management-config.sh"
echo "if create_rate_limit 'config-check' 300; then"
echo "    bash config-check.sh"
echo "else"
echo "    echo 'Rate limited'"
echo "fi"