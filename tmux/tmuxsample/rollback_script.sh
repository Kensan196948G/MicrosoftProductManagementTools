#!/bin/bash

# ロールバック機能スクリプト
echo "=== ロールバック機能準備 ==="

BACKUP_FILE="/media/kensan/LinuxHDD/ITSM-ITmanagementSystem/Archive/Backup-Snapshots/Pre-Migration-Backups/pre-migration-backup-20250711_120311.tar.gz"

if [ -f "$BACKUP_FILE" ]; then
    echo "バックアップファイル確認済み: $BACKUP_FILE"
    echo "サイズ: $(du -h $BACKUP_FILE | cut -f1)"
    
    # ロールバック関数
    rollback_function() {
        echo "=== 緊急ロールバック実行 ==="
        
        # 現在の状態をバックアップ
        tar -czf /media/kensan/LinuxHDD/ITSM-ITmanagementSystem/Archive/Backup-Snapshots/Pre-Migration-Backups/current-state-backup-$(date +%Y%m%d_%H%M%S).tar.gz -C /media/kensan/LinuxHDD/ITSM-ITmanagementSystem --exclude=Archive .
        
        # 元の状態に復元
        cd /media/kensan/LinuxHDD/ITSM-ITmanagementSystem
        tar -xzf "$BACKUP_FILE"
        
        echo "ロールバック完了"
    }
    
    echo "ロールバック機能は待機中..."
    echo "必要時は 'rollback_function' を実行してください"
else
    echo "エラー: バックアップファイルが見つかりません"
    exit 1
fi