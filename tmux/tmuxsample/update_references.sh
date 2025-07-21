#!/bin/bash

# 参照関係修正スクリプト
echo "=== 参照関係修正開始 ==="

# emergency-backup参照更新
echo "emergency-backup参照更新中..."
find /media/kensan/LinuxHDD/ITSM-ITmanagementSystem -name "*.md" -exec sed -i 's/emergency-backup-20250706_160519\//Archive\/Backup-Snapshots\/Emergency-Backups\/emergency-backup-20250706_160519\//g' {} \;

# data_backup参照更新
echo "data_backup参照更新中..."
find /media/kensan/LinuxHDD/ITSM-ITmanagementSystem -name "*.md" -exec sed -i 's/data_backup_20250708_212315\//Archive\/Backup-Snapshots\/Daily-Snapshots\/data_backup_20250708_212315\//g' {} \;

# cookies.txt参照更新
echo "cookies.txt参照更新中..."
find /media/kensan/LinuxHDD/ITSM-ITmanagementSystem -name "*.md" -exec sed -i 's/cookies\.txt/Archive\/Temporary-Files\/Cache-Files\/cookies.txt/g' {} \;

# test files参照更新
echo "test files参照更新中..."
find /media/kensan/LinuxHDD/ITSM-ITmanagementSystem -name "*.md" -exec sed -i 's/complete_test\.txt/Archive\/Test-Data-Archive\/Integration-Test-Results\/complete_test.txt/g' {} \;
find /media/kensan/LinuxHDD/ITSM-ITmanagementSystem -name "*.md" -exec sed -i 's/final_clean_test\.txt/Archive\/Test-Data-Archive\/Integration-Test-Results\/final_clean_test.txt/g' {} \;
find /media/kensan/LinuxHDD/ITSM-ITmanagementSystem -name "*.md" -exec sed -i 's/integration_test\.txt/Archive\/Test-Data-Archive\/Integration-Test-Results\/integration_test.txt/g' {} \;

echo "=== 参照関係修正完了 ==="