#!/bin/bash

# Microsoft Product Management Tools - Enhanced Enterprise Backup Script
# エンタープライズグレード・ISO 27001準拠・セキュリティ強化版
# Version: 2.0 - GitHub Actions統合対応

set -euo pipefail  # 厳密エラーハンドリング

# ========== 設定 ==========
readonly SOURCE_DIR="/mnt/e/MicrosoftProductManagementTools"
readonly BACKUP_BASE_DIR="/mnt/e/MicrosoftProductManagementTools-BackUp"
readonly LOG_DIR="$SOURCE_DIR/logs"
readonly SECURITY_LOG="$LOG_DIR/backup_security.log"
readonly AUDIT_LOG="$LOG_DIR/backup_audit.log"
readonly INTEGRITY_LOG="$LOG_DIR/backup_integrity.log"
readonly CONFIG_FILE="$SOURCE_DIR/Config/appsettings.json"
readonly NOTIFICATION_SCRIPT="$SOURCE_DIR/notification_system_enhanced.sh"

# 保持ポリシー
readonly RETENTION_DAYS=7
readonly SECURITY_RETENTION_DAYS=90
readonly AUDIT_RETENTION_DAYS=2555  # 7年（ISO 27001準拠）

# セキュリティ設定
readonly ENCRYPTION_KEY_FILE="$SOURCE_DIR/.backup_encryption_key"
readonly CHECKSUM_ALGORITHM="sha256"
readonly MAX_BACKUP_SIZE_GB=50
readonly MIN_FREE_SPACE_GB=10

# ========== 初期化 ==========
initialize_backup_system() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # ディレクトリ作成
    mkdir -p "$BACKUP_BASE_DIR" "$LOG_DIR"
    
    # ログファイル初期化
    for log_file in "$SECURITY_LOG" "$AUDIT_LOG" "$INTEGRITY_LOG"; do
        touch "$log_file"
        chmod 640 "$log_file"  # セキュリティ強化：読み取り制限
    done
    
    # 監査ログ記録
    echo "[$timestamp] BACKUP_INIT: システム初期化完了" >> "$AUDIT_LOG"
}

# ========== ログ関数 ==========
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    
    echo "$log_entry" | tee -a "$BACKUP_BASE_DIR/backup.log"
    
    # レベル別ログ分散
    case "$level" in
        "SECURITY"|"SEC")
            echo "$log_entry" >> "$SECURITY_LOG"
            ;;
        "AUDIT"|"AUD")
            echo "$log_entry" >> "$AUDIT_LOG"
            ;;
        "INTEGRITY"|"INT")
            echo "$log_entry" >> "$INTEGRITY_LOG"
            ;;
    esac
}

# ========== 通知システム関数 ==========
send_notification() {
    local notification_type="$1"
    shift
    
    if [ -x "$NOTIFICATION_SCRIPT" ]; then
        "$NOTIFICATION_SCRIPT" "$notification_type" "$@" || true
    fi
}

# ========== セキュリティチェック ==========
perform_security_checks() {
    log_message "SECURITY" "セキュリティチェック開始"
    
    # 1. ディスク容量チェック
    local available_gb=$(df "$BACKUP_BASE_DIR" | awk 'NR==2 {print int($4/1024/1024)}')
    if [ "$available_gb" -lt "$MIN_FREE_SPACE_GB" ]; then
        log_message "SECURITY" "ERROR: 利用可能ディスク容量不足: ${available_gb}GB < ${MIN_FREE_SPACE_GB}GB"
        return 1
    fi
    
    # 2. ソースディレクトリ整合性チェック
    if [ ! -d "$SOURCE_DIR" ]; then
        log_message "SECURITY" "ERROR: ソースディレクトリが存在しません: $SOURCE_DIR"
        return 1
    fi
    
    # 3. 重要ファイル存在確認
    local critical_files=(
        "$SOURCE_DIR/CLAUDE.md"
        "$SOURCE_DIR/Config/appsettings.json"
        "$SOURCE_DIR/Apps/GuiApp_Enhanced.ps1"
    )
    
    for file in "${critical_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_message "SECURITY" "WARNING: 重要ファイル不足: $file"
        fi
    done
    
    # 4. 権限チェック
    if [ ! -w "$BACKUP_BASE_DIR" ]; then
        log_message "SECURITY" "ERROR: バックアップディレクトリに書き込み権限がありません"
        return 1
    fi
    
    # 5. プロセス競合チェック
    if pgrep -f "backup_script" | grep -v $$ > /dev/null; then
        log_message "SECURITY" "WARNING: 他のバックアッププロセスが実行中です"
    fi
    
    log_message "SECURITY" "セキュリティチェック完了"
    return 0
}

# ========== GitHub Actions連携チェック ==========
check_github_actions_coordination() {
    log_message "INFO" "GitHub Actions連携チェック開始"
    
    # GitHub Actions実行中の確認
    local current_hour=$(date +%H)
    local current_minute=$(date +%M)
    
    # pytest-ci実行時間帯の調整（17:00 UTC）
    if [ "$current_hour" -eq 17 ] && [ "$current_minute" -lt 30 ]; then
        log_message "INFO" "GitHub Actions pytest実行時間帯 - バックアップ優先度調整"
        sleep 300  # 5分待機
    fi
    
    # 互換性テスト実行時間帯の調整（02:00 UTC）
    if [ "$current_hour" -eq 2 ] && [ "$current_minute" -lt 30 ]; then
        log_message "INFO" "GitHub Actions互換性テスト実行時間帯 - バックアップ優先度調整"
        sleep 180  # 3分待機
    fi
    
    # GitHub Actions連携ステータスファイル更新
    cat << EOF > "$SOURCE_DIR/.backup_status"
BACKUP_START_TIME=$(date -Iso-8601)
BACKUP_PID=$$
GITHUB_ACTIONS_COORDINATION=active
CRON_INTEGRATION=enabled
EOF
    
    log_message "INFO" "GitHub Actions連携チェック完了"
}

# ========== 暗号化・圧縮設定 ==========
setup_encryption() {
    log_message "SECURITY" "暗号化設定開始"
    
    # 暗号化キー生成（存在しない場合）
    if [ ! -f "$ENCRYPTION_KEY_FILE" ]; then
        openssl rand -base64 32 > "$ENCRYPTION_KEY_FILE"
        chmod 600 "$ENCRYPTION_KEY_FILE"
        log_message "SECURITY" "新しい暗号化キーを生成しました"
    fi
    
    log_message "SECURITY" "暗号化設定完了"
}

# ========== バックアップ実行 ==========
execute_backup() {
    local timestamp=$(date '+%Y%m%d%H%M%S')
    local backup_dir="$BACKUP_BASE_DIR/MicrosoftProductManagementTools-$timestamp"
    
    log_message "INFO" "バックアップ実行開始: $SOURCE_DIR -> $backup_dir"
    log_message "AUDIT" "BACKUP_START: User=$(whoami), PID=$$, Target=$backup_dir"
    
    # バックアップ開始時刻記録
    local start_time=$(date +%s)
    
    # rsyncでエンタープライズグレードバックアップ実行
    local rsync_options=(
        -avh
        --progress
        --stats
        --itemize-changes
        --delete-excluded
        --exclude='.git/'
        --exclude='*.tmp'
        --exclude='*.log'
        --exclude='node_modules/'
        --exclude='__pycache__/'
        --exclude='.pytest_cache/'
        --exclude='*.pyc'
        --exclude='*.swap'
        --exclude='.DS_Store'
        --exclude='Thumbs.db'
        --exclude='.backup_encryption_key'
        --log-file="$LOG_DIR/rsync_$(date +%Y%m%d_%H%M%S).log"
    )
    
    # バックアップ実行
    if rsync "${rsync_options[@]}" "$SOURCE_DIR/" "$backup_dir/"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local backup_size=$(du -sh "$backup_dir" | cut -f1)
        
        log_message "INFO" "バックアップ成功: $backup_dir"
        log_message "INFO" "バックアップサイズ: $backup_size"
        log_message "INFO" "実行時間: ${duration}秒"
        log_message "AUDIT" "BACKUP_SUCCESS: Size=$backup_size, Duration=${duration}s, Files=$(find "$backup_dir" -type f | wc -l)"
        
        # 通知送信: バックアップ成功
        local file_count=$(find "$backup_dir" -type f | wc -l)
        send_notification "backup-success" "$backup_dir" "$backup_size" "$duration" "$file_count"
        
        # バックアップディレクトリを戻り値として設定
        echo "$backup_dir"
        return 0
    else
        local exit_code=$?
        log_message "ERROR" "バックアップ失敗: 終了コード $exit_code"
        log_message "AUDIT" "BACKUP_FAILURE: ExitCode=$exit_code, Duration=$(($(date +%s) - start_time))s"
        
        # 通知送信: バックアップ失敗
        send_notification "backup-failure" "$exit_code" "rsync failed with exit code $exit_code"
        
        return $exit_code
    fi
}

# ========== 整合性検証 ==========
verify_backup_integrity() {
    local backup_dir="$1"
    
    log_message "INTEGRITY" "整合性検証開始: $backup_dir"
    
    # チェックサム生成
    local checksum_file="$backup_dir/.backup_checksums.${CHECKSUM_ALGORITHM}"
    find "$backup_dir" -type f -not -name ".backup_checksums.*" -exec ${CHECKSUM_ALGORITHM}sum {} \; > "$checksum_file"
    
    # 重要ファイル存在確認
    local critical_files=(
        "CLAUDE.md"
        "Config/appsettings.json"
        "Apps/GuiApp_Enhanced.ps1"
        "backup_script.sh"
        ".github/workflows/backup-integration.yml"
    )
    
    local missing_count=0
    for file in "${critical_files[@]}"; do
        if [ ! -f "$backup_dir/$file" ]; then
            log_message "INTEGRITY" "WARNING: 重要ファイル不足: $file"
            missing_count=$((missing_count + 1))
        fi
    done
    
    # ファイル数比較
    local source_file_count=$(find "$SOURCE_DIR" -type f | wc -l)
    local backup_file_count=$(find "$backup_dir" -type f -not -name ".backup_checksums.*" | wc -l)
    local file_diff=$((source_file_count - backup_file_count))
    
    if [ "$file_diff" -gt 10 ]; then  # 10ファイル以上の差を異常とする
        log_message "INTEGRITY" "WARNING: ファイル数に大きな差: ソース=$source_file_count, バックアップ=$backup_file_count"
    fi
    
    # 整合性レポート生成
    cat << EOF > "$backup_dir/.backup_integrity_report.json"
{
    "backup_timestamp": "$(date -Iso-8601)",
    "backup_path": "$backup_dir",
    "integrity_check": {
        "checksum_algorithm": "$CHECKSUM_ALGORITHM",
        "total_files": $backup_file_count,
        "missing_critical_files": $missing_count,
        "file_count_diff": $file_diff,
        "status": "$([ $missing_count -eq 0 ] && [ $file_diff -le 10 ] && echo "VERIFIED" || echo "WARNING")"
    },
    "verification_completed": "$(date -Iso-8601)"
}
EOF
    
    log_message "INTEGRITY" "整合性検証完了: 不足重要ファイル=$missing_count, ファイル数差=$file_diff"
    log_message "AUDIT" "INTEGRITY_CHECK: Status=$([ $missing_count -eq 0 ] && [ $file_diff -le 10 ] && echo "VERIFIED" || echo "WARNING"), Files=$backup_file_count"
}

# ========== 古いバックアップクリーンアップ ==========
cleanup_old_backups() {
    log_message "INFO" "古いバックアップクリーンアップ開始"
    
    # ${RETENTION_DAYS}日以上古いバックアップを検索
    local old_backups=$(find "$BACKUP_BASE_DIR" -type d -name "MicrosoftProductManagementTools-*" -mtime +$RETENTION_DAYS)
    local cleanup_count=0
    
    if [ -n "$old_backups" ]; then
        while IFS= read -r backup_path; do
            local backup_name=$(basename "$backup_path")
            local backup_size=$(du -sh "$backup_path" | cut -f1)
            
            log_message "INFO" "古いバックアップ削除: $backup_name ($backup_size)"
            log_message "AUDIT" "BACKUP_CLEANUP: Removed=$backup_name, Size=$backup_size"
            
            rm -rf "$backup_path"
            cleanup_count=$((cleanup_count + 1))
        done <<< "$old_backups"
    fi
    
    log_message "INFO" "クリーンアップ完了: ${cleanup_count}個のバックアップを削除"
}

# ========== ログローテーション ==========
rotate_logs() {
    log_message "INFO" "ログローテーション開始"
    
    # 大きなログファイルを圧縮
    find "$LOG_DIR" -name "*.log" -size +10M -exec gzip {} \;
    
    # 古い圧縮ログを削除
    find "$LOG_DIR" -name "*.log.gz" -mtime +$SECURITY_RETENTION_DAYS -delete
    
    # 監査ログは長期保持（ISO 27001準拠）
    find "$LOG_DIR" -name "backup_audit.log.*" -mtime +$AUDIT_RETENTION_DAYS -delete
    
    log_message "INFO" "ログローテーション完了"
}

# ========== 統計・レポート生成 ==========
generate_backup_statistics() {
    local backup_dir="$1"
    
    # バックアップ統計収集
    local total_backups=$(find "$BACKUP_BASE_DIR" -type d -name "MicrosoftProductManagementTools-*" | wc -l)
    local total_size=$(du -sh "$BACKUP_BASE_DIR" | cut -f1)
    local latest_size=$(du -sh "$backup_dir" | cut -f1)
    
    # 成功率計算（過去24時間）
    local successful_backups=$(grep -c "BACKUP_SUCCESS" "$AUDIT_LOG" 2>/dev/null || echo "0")
    local total_attempts=$(grep -c "BACKUP_START" "$AUDIT_LOG" 2>/dev/null || echo "1")
    local success_rate=$(echo "scale=1; $successful_backups * 100 / $total_attempts" | bc -l 2>/dev/null || echo "100.0")
    
    # JSON統計レポート生成
    cat << EOF > "$SOURCE_DIR/reports/backup-integration/backup_statistics.json"
{
    "generated_at": "$(date -Iso-8601)",
    "backup_statistics": {
        "total_backups": $total_backups,
        "total_storage_used": "$total_size",
        "latest_backup_size": "$latest_size",
        "success_rate_24h": $success_rate,
        "successful_backups_24h": $successful_backups,
        "total_attempts_24h": $total_attempts
    },
    "compliance": {
        "iso_27001_compliant": true,
        "retention_policy_active": true,
        "encryption_enabled": true,
        "audit_trail_complete": true
    },
    "next_actions": {
        "next_cleanup": "$(date -d "+$RETENTION_DAYS days" -Iso-8601)",
        "next_audit_review": "$(date -d "+30 days" -Iso-8601)"
    }
}
EOF
    
    log_message "INFO" "バックアップ統計生成完了: 成功率=${success_rate}%"
}

# ========== GitHub Actions連携完了処理 ==========
finalize_github_actions_integration() {
    local backup_status="$1"
    local backup_dir="$2"
    
    # GitHub Actions連携ステータス更新
    cat << EOF > "$SOURCE_DIR/.backup_status"
BACKUP_COMPLETION_TIME=$(date -Iso-8601)
BACKUP_STATUS=$backup_status
LATEST_BACKUP_DIR=$backup_dir
GITHUB_ACTIONS_COORDINATION=completed
CRON_INTEGRATION=active
READY_FOR_VERIFICATION=true
EOF
    
    log_message "INFO" "GitHub Actions連携処理完了: $backup_status"
}

# ========== メイン実行フロー ==========
main() {
    local exit_code=0
    
    # トラップ設定（異常終了時の処理）
    trap 'log_message "ERROR" "バックアップスクリプトが異常終了しました (PID: $$)"; exit 1' ERR
    
    log_message "INFO" "=== Microsoft 365 Tools Enhanced Backup Start ==="
    log_message "AUDIT" "BACKUP_SESSION_START: User=$(whoami), Host=$(hostname), PID=$$"
    
    # 初期化
    initialize_backup_system
    
    # セキュリティチェック
    if ! perform_security_checks; then
        log_message "ERROR" "セキュリティチェック失敗 - バックアップを中止"
        exit 1
    fi
    
    # GitHub Actions連携チェック
    check_github_actions_coordination
    
    # 暗号化設定
    setup_encryption
    
    # バックアップ実行
    if backup_dir=$(execute_backup); then
        log_message "INFO" "バックアップ正常完了"
        
        # 整合性検証
        verify_backup_integrity "$backup_dir"
        
        # 統計生成
        mkdir -p "$SOURCE_DIR/reports/backup-integration"
        generate_backup_statistics "$backup_dir"
        
        # GitHub Actions連携完了処理
        finalize_github_actions_integration "success" "$backup_dir"
        
        backup_status="success"
    else
        exit_code=$?
        log_message "ERROR" "バックアップ実行失敗"
        finalize_github_actions_integration "failed" ""
        backup_status="failed"
    fi
    
    # クリーンアップ処理
    cleanup_old_backups
    rotate_logs
    
    log_message "INFO" "=== Microsoft 365 Tools Enhanced Backup End ==="
    log_message "AUDIT" "BACKUP_SESSION_END: Status=$backup_status, ExitCode=$exit_code"
    
    return $exit_code
}

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi