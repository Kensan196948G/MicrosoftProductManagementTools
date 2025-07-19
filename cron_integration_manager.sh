#!/bin/bash

# Microsoft 365 Management Tools - 統合Cron管理スクリプト
# GitHub Actions連携対応・完全協調スケジュール

# 設定
PROJECT_ROOT="/mnt/e/MicrosoftProductManagementTools"
BACKUP_DEST="/mnt/e/MicrosoftProductManagementTools-BackUp"
LOG_DIR="$PROJECT_ROOT/logs"
REPORTS_DIR="$PROJECT_ROOT/reports"

# ログ関数
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/cron_integration.log"
}

# 時間帯別実行制御
get_current_hour() {
    date +%H
}

get_current_minute() {
    date +%M
}

# プリバックアップ検証（01:00 UTC）
pre_backup_verification() {
    log_message "🔍 プリバックアップ検証開始"
    
    # システムリソースチェック
    MEMORY_USAGE=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100.0}')
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    log_message "メモリ使用率: ${MEMORY_USAGE}%, ディスク使用率: ${DISK_USAGE}%"
    
    # GitHub Actionsワークフロートリガー準備
    if [ "$MEMORY_USAGE" -lt 85 ] && [ "$DISK_USAGE" -lt 90 ]; then
        log_message "✅ システム状態良好 - バックアップ実行可能"
        echo "BACKUP_READY=true" > "$PROJECT_ROOT/.backup_status"
        return 0
    else
        log_message "⚠️ システムリソース不足 - バックアップ延期"
        echo "BACKUP_READY=false" > "$PROJECT_ROOT/.backup_status"
        return 1
    fi
}

# バックアップ実行協調制御（毎30分）
backup_execution_coordinator() {
    local current_hour=$(get_current_hour)
    local current_minute=$(get_current_minute)
    
    log_message "🔄 バックアップ実行協調制御: ${current_hour}:${current_minute}"
    
    # GitHub Actionsテスト実行時間帯の調整
    if [ "$current_hour" -eq 2 ] && [ "$current_minute" -eq 0 ]; then
        log_message "⏳ GitHub Actions互換性テスト実行中 - バックアップ一時停止"
        return 1
    fi
    
    if [ "$current_hour" -eq 17 ] && [ "$current_minute" -eq 0 ]; then
        log_message "⏳ GitHub Actions pytest実行中 - バックアップ一時停止"
        return 1
    fi
    
    # バックアップ実行
    log_message "🚀 バックアップ実行開始"
    "$PROJECT_ROOT/backup_script.sh"
    
    if [ $? -eq 0 ]; then
        log_message "✅ バックアップ実行成功"
        echo "LAST_BACKUP_STATUS=success" > "$PROJECT_ROOT/.backup_status"
        echo "LAST_BACKUP_TIME=$(date -Iso-8601)" >> "$PROJECT_ROOT/.backup_status"
    else
        log_message "❌ バックアップ実行失敗"
        echo "LAST_BACKUP_STATUS=failed" > "$PROJECT_ROOT/.backup_status"
        return 1
    fi
}

# ポストバックアップ検証（03:00 UTC）
post_backup_verification() {
    log_message "✅ ポストバックアップ検証開始"
    
    # 最新バックアップ検証
    local latest_backup=$(find "$BACKUP_DEST" -name "MicrosoftProductManagementTools-*" -type d | sort | tail -1)
    
    if [ -n "$latest_backup" ]; then
        local backup_name=$(basename "$latest_backup")
        local backup_size=$(du -sh "$latest_backup" | cut -f1)
        
        log_message "📊 最新バックアップ: $backup_name ($backup_size)"
        
        # 重要ファイル整合性チェック
        local critical_files=(
            "CLAUDE.md"
            "backup_script.sh"
            "Config/appsettings.json"
            "Apps/GuiApp_Enhanced.ps1"
        )
        
        local missing_count=0
        for file in "${critical_files[@]}"; do
            if [ ! -f "$latest_backup/$file" ]; then
                log_message "⚠️ 重要ファイル不足: $file"
                missing_count=$((missing_count + 1))
            fi
        done
        
        if [ "$missing_count" -eq 0 ]; then
            log_message "✅ バックアップ整合性確認完了"
            echo "BACKUP_INTEGRITY=verified" >> "$PROJECT_ROOT/.backup_status"
        else
            log_message "❌ バックアップ整合性問題: ${missing_count}個のファイル不足"
            echo "BACKUP_INTEGRITY=corrupted" >> "$PROJECT_ROOT/.backup_status"
        fi
    else
        log_message "❌ バックアップが見つかりません"
        echo "BACKUP_INTEGRITY=missing" >> "$PROJECT_ROOT/.backup_status"
    fi
}

# 統合レポート生成準備（18:00 UTC）
integrated_report_preparation() {
    log_message "📈 統合レポート生成準備開始"
    
    # レポートディレクトリ準備
    mkdir -p "$REPORTS_DIR/backup-integration"
    
    # バックアップ統計収集
    local total_backups=$(find "$BACKUP_DEST" -name "MicrosoftProductManagementTools-*" -type d | wc -l)
    local total_size=$(du -sh "$BACKUP_DEST" 2>/dev/null | cut -f1 || echo "0")
    local success_rate=0
    
    # 成功率計算（過去24時間）
    local successful_backups=$(grep -c "Backup completed successfully" "$BACKUP_DEST/backup.log" 2>/dev/null || echo "0")
    local total_attempts=$(grep -c "Starting backup" "$BACKUP_DEST/backup.log" 2>/dev/null || echo "1")
    
    if [ "$total_attempts" -gt 0 ]; then
        success_rate=$(echo "scale=1; $successful_backups * 100 / $total_attempts" | bc -l 2>/dev/null || echo "0")
    fi
    
    # 統合レポートデータ生成
    cat << EOF > "$REPORTS_DIR/backup-integration/daily_stats.json"
{
    "generated_at": "$(date -Iso-8601)",
    "backup_statistics": {
        "total_backups": $total_backups,
        "total_size": "$total_size",
        "success_rate": $success_rate,
        "successful_backups_24h": $successful_backups,
        "total_attempts_24h": $total_attempts
    },
    "system_status": {
        "cron_integration_active": true,
        "github_actions_compatible": true,
        "last_verification": "$(date -Iso-8601)"
    }
}
EOF
    
    log_message "📊 統合レポートデータ生成完了"
    log_message "📈 成功率: ${success_rate}% (${successful_backups}/${total_attempts})"
}

# 品質監視システム協調
quality_system_coordination() {
    log_message "🎯 品質監視システム協調開始"
    
    # 既存品質監視との連携
    if [ -f "$PROJECT_ROOT/tests/automation/quality_monitor.py" ]; then
        # バックアップステータスを品質監視に統合
        if [ -f "$PROJECT_ROOT/.backup_status" ]; then
            local backup_status=$(grep "LAST_BACKUP_STATUS" "$PROJECT_ROOT/.backup_status" | cut -d'=' -f2)
            local backup_integrity=$(grep "BACKUP_INTEGRITY" "$PROJECT_ROOT/.backup_status" | cut -d'=' -f2)
            
            log_message "📊 品質監視連携: バックアップ状態=$backup_status, 整合性=$backup_integrity"
            
            # 品質レポートにバックアップ情報を追加
            echo "{\"backup_status\": \"$backup_status\", \"backup_integrity\": \"$backup_integrity\", \"timestamp\": \"$(date -Iso-8601)\"}" > "$REPORTS_DIR/backup_quality_metrics.json"
        fi
    fi
}

# メイン実行ロジック
main() {
    local current_hour=$(get_current_hour)
    local current_minute=$(get_current_minute)
    
    log_message "🚀 統合Cron管理開始: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 時間帯別処理実行
    case "$current_hour" in
        01)
            if [ "$current_minute" -eq 0 ]; then
                pre_backup_verification
            fi
            ;;
        03)
            if [ "$current_minute" -eq 0 ]; then
                post_backup_verification
            fi
            ;;
        18)
            if [ "$current_minute" -eq 0 ]; then
                integrated_report_preparation
            fi
            ;;
    esac
    
    # 30分間隔でのバックアップ協調制御
    if [ $((current_minute % 30)) -eq 0 ]; then
        backup_execution_coordinator
    fi
    
    # 4時間ごとの品質監視協調
    if [ $((current_hour % 4)) -eq 0 ] && [ "$current_minute" -eq 0 ]; then
        quality_system_coordination
    fi
    
    log_message "✅ 統合Cron管理完了"
}

# 引数処理
case "${1:-main}" in
    "pre-backup")
        pre_backup_verification
        ;;
    "post-backup")
        post_backup_verification
        ;;
    "report-prep")
        integrated_report_preparation
        ;;
    "quality-coord")
        quality_system_coordination
        ;;
    "main"|*)
        main
        ;;
esac