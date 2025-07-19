#!/bin/bash

# Microsoft Product Management Tools - Automated Backup Script
# バックアップを30分おきに実行するスクリプト

# 設定
SOURCE_DIR="/mnt/e/MicrosoftProductManagementTools"
BACKUP_BASE_DIR="/mnt/e/MicrosoftProductManagementTools-BackUp"
LOG_FILE="$BACKUP_BASE_DIR/backup.log"

# ログ関数
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# バックアップディレクトリが存在しない場合は作成
if [ ! -d "$BACKUP_BASE_DIR" ]; then
    mkdir -p "$BACKUP_BASE_DIR"
    log_message "Created backup base directory: $BACKUP_BASE_DIR"
fi

# タイムスタンプ付きフォルダ名を生成（YYYYMMDDHHMMSS形式）
TIMESTAMP=$(date '+%Y%m%d%H%M%S')
BACKUP_DIR="$BACKUP_BASE_DIR/MicrosoftProductManagementTools-$TIMESTAMP"

log_message "Starting backup from $SOURCE_DIR to $BACKUP_DIR"

# rsyncを使用してフルバックアップを実行
# -a: アーカイブモード（権限、タイムスタンプ等を保持）
# -v: 詳細出力
# -h: 人間が読みやすい形式
# --progress: 進捗表示
# --exclude: .gitやその他の一時ファイルを除外
rsync -avh --progress \
    --exclude='.git/' \
    --exclude='*.tmp' \
    --exclude='*.log' \
    --exclude='node_modules/' \
    --exclude='__pycache__/' \
    --exclude='.pytest_cache/' \
    --exclude='*.pyc' \
    "$SOURCE_DIR/" "$BACKUP_DIR/"

# バックアップ結果をチェック
if [ $? -eq 0 ]; then
    log_message "Backup completed successfully: $BACKUP_DIR"
    
    # バックアップサイズを記録
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
    log_message "Backup size: $BACKUP_SIZE"
    
    # 古いバックアップの削除（7日以上古いものを削除）
    find "$BACKUP_BASE_DIR" -type d -name "MicrosoftProductManagementTools-*" -mtime +7 -exec rm -rf {} \; 2>/dev/null
    log_message "Cleaned up old backups (older than 7 days)"
    
else
    log_message "ERROR: Backup failed with exit code $?"
    exit 1
fi

log_message "Backup process completed"