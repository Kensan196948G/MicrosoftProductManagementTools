# ファイル移動計画書
## ITSMディレクトリ構造最適化プロジェクト

### 1. 移動対象ファイル分類

#### 1.1 High Priority - 即座移動対象
```
移動対象ファイル一覧:
- Archive/Backup-Snapshots/Emergency-Backups/emergency-backup-20250706_160519/ → Archive/Backup-Snapshots/Emergency-Backups/
- Archive/Temporary-Files/Cache-Files/cookies.txt → Archive/Temporary-Files/Cache-Files/
- csrf_Archive/Temporary-Files/Cache-Files/cookies.txt → Archive/Temporary-Files/Cache-Files/
- Archive/Test-Data-Archive/Integration-Test-Results/complete_test.txt → Archive/Test-Data-Archive/Integration-Test-Results/
- Archive/Test-Data-Archive/Integration-Test-Results/final_clean_test.txt → Archive/Test-Data-Archive/Integration-Test-Results/
- final_hooks_test.txt → Archive/Test-Data-Archive/Integration-Test-Results/
- final_integration.txt → Archive/Test-Data-Archive/Integration-Test-Results/
- Archive/Test-Data-Archive/Integration-Test-Results/integration_test.txt → Archive/Test-Data-Archive/Integration-Test-Results/
- hook_test_file.txt → Archive/Test-Data-Archive/Integration-Test-Results/
- hooks_Archive/Test-Data-Archive/Integration-Test-Results/integration_test.txt → Archive/Test-Data-Archive/Integration-Test-Results/
- hooks_test_success.txt → Archive/Test-Data-Archive/Integration-Test-Results/
- settings_test.txt → Archive/Test-Data-Archive/Integration-Test-Results/
- test_hook_file.txt → Archive/Test-Data-Archive/Integration-Test-Results/
- emergency-fix-report.txt → Archive/Documentation-Archive/Historical-Reports/
- itsm_development_directive.txt → Archive/Documentation-Archive/Historical-Reports/
- progress_check_directive.txt → Archive/Documentation-Archive/Historical-Reports/
- team_notification_message.txt → Archive/Documentation-Archive/Historical-Reports/
```

#### 1.2 Medium Priority - 段階的移動対象
```
移動対象ファイル一覧:
- Archive/Backup-Snapshots/Daily-Snapshots/data_backup_20250708_212315/ → Archive/Backup-Snapshots/Daily-Snapshots/
- logs/ (過去のログファイル) → Archive/Temporary-Files/Log-Files/
- node_modules/ → Archive/Temporary-Files/Cache-Files/
- coverage/ → Archive/Test-Data-Archive/Performance-Test-Results/
- dist/ → Archive/Temporary-Files/Cache-Files/
- .backup ファイル → Archive/Backup-Snapshots/Pre-Migration-Backups/
- .temp ファイル → Archive/Temporary-Files/Temp-Development/
```

#### 1.3 Low Priority - 最終移動対象
```
移動対象ファイル一覧:
- 完了済みPhase1ドキュメント → Archive/Phase-Development/Phase1-Completed/
- 完了済みPhase2ドキュメント → Archive/Phase-Development/Phase2-Completed/
- 旧バージョンコンポーネント → Archive/Outdated-Components/Legacy-Frontend/
- 廃止API仕様 → Archive/Outdated-Components/Deprecated-APIs/
```

### 2. 移動優先度マトリックス

#### 2.1 優先度判定基準
| 項目 | High | Medium | Low |
|------|------|--------|-----|
| 使用頻度 | 未使用 | 低頻度 | 中頻度 |
| ファイルサイズ | 大容量 | 中容量 | 小容量 |
| 参照関係 | 独立 | 部分参照 | 多重参照 |
| セキュリティ | 機密性低 | 機密性中 | 機密性高 |
| 開発影響 | 影響なし | 影響小 | 影響大 |

#### 2.2 移動実行順序
1. **Phase 1**: 一時ファイル・キャッシュファイル (1-2時間)
2. **Phase 2**: バックアップファイル (2-3時間)
3. **Phase 3**: テストデータファイル (1-2時間)
4. **Phase 4**: 過去ドキュメント (1-2時間)
5. **Phase 5**: 廃止コンポーネント (2-3時間)

### 3. 具体的移動手順

#### 3.1 Pre-Migration チェック
```bash
# ディスク容量確認
df -h

# 参照関係確認
find . -type f -name "*.ts" -o -name "*.js" -o -name "*.md" | xargs grep -l "対象ファイル名"

# バックアップ作成
tar -czf pre-migration-backup-$(date +%Y%m%d_%H%M%S).tar.gz .
```

#### 3.2 移動実行コマンド例
```bash
# Phase 1: 一時ファイル移動
mkdir -p Archive/Temporary-Files/Cache-Files
mv Archive/Temporary-Files/Cache-Files/cookies.txt Archive/Temporary-Files/Cache-Files/
mv csrf_Archive/Temporary-Files/Cache-Files/cookies.txt Archive/Temporary-Files/Cache-Files/

# Phase 2: バックアップファイル移動
mkdir -p Archive/Backup-Snapshots/Emergency-Backups
mv Archive/Backup-Snapshots/Emergency-Backups/emergency-backup-20250706_160519/ Archive/Backup-Snapshots/Emergency-Backups/

# Phase 3: テストデータ移動
mkdir -p Archive/Test-Data-Archive/Integration-Test-Results
mv Archive/Test-Data-Archive/Integration-Test-Results/complete_test.txt Archive/Test-Data-Archive/Integration-Test-Results/
mv Archive/Test-Data-Archive/Integration-Test-Results/final_clean_test.txt Archive/Test-Data-Archive/Integration-Test-Results/
```

#### 3.3 Post-Migration 検証
```bash
# 参照整合性確認
./scripts/verify-references.sh

# 機能テスト実行
npm test

# 性能テスト実行
npm run test:performance
```

### 4. 日本語ファイル名変換計画

#### 4.1 変換対象ファイル一覧
```
変換対象:
- tmux_Docs/tmux仕様書.md → tmux_Docs/tmux-specification.md
- tmux_Docs/操作手順書.md → tmux_Docs/operation-manual.md
- 操作手順書.md → operation-manual.md
- scripts/visual-verification/tmux使用ガイド.md → scripts/visual-verification/tmux-usage-guide.md
- scripts/visual-verification/クイックリファレンス.md → scripts/visual-verification/quick-reference.md
- scripts/visual-verification/スクリプト内容詳細.md → scripts/visual-verification/script-details.md
- scripts/visual-verification/スクリプト操作手順書.md → scripts/visual-verification/script-operation-manual.md
```

#### 4.2 変換実行スクリプト
```bash
#!/bin/bash
# 日本語ファイル名変換スクリプト

# 変換マッピング
declare -A file_mapping=(
    ["tmux_Docs/tmux仕様書.md"]="tmux_Docs/tmux-specification.md"
    ["tmux_Docs/操作手順書.md"]="tmux_Docs/operation-manual.md"
    ["操作手順書.md"]="operation-manual.md"
    ["scripts/visual-verification/tmux使用ガイド.md"]="scripts/visual-verification/tmux-usage-guide.md"
    ["scripts/visual-verification/クイックリファレンス.md"]="scripts/visual-verification/quick-reference.md"
    ["scripts/visual-verification/スクリプト内容詳細.md"]="scripts/visual-verification/script-details.md"
    ["scripts/visual-verification/スクリプト操作手順書.md"]="scripts/visual-verification/script-operation-manual.md"
)

# ファイル名変換実行
for old_name in "${!file_mapping[@]}"; do
    new_name="${file_mapping[$old_name]}"
    if [ -f "$old_name" ]; then
        mv "$old_name" "$new_name"
        echo "変換完了: $old_name → $new_name"
    fi
done
```

### 5. 参照整合性維持戦略

#### 5.1 参照関係調査
```bash
# 参照関係調査スクリプト
#!/bin/bash
echo "参照関係調査開始..."

# Markdown内の相対パス参照調査
find . -name "*.md" -exec grep -l "\.\./\|\./" {} \; > reference-files.txt

# TypeScript/JavaScript内のimport文調査
find . -name "*.ts" -o -name "*.js" | xargs grep -l "import.*from.*\.\." > import-files.txt

# package.jsonの依存関係調査
find . -name "package.json" -exec grep -l "file:" {} \; > package-references.txt
```

#### 5.2 参照パス更新
```bash
# 参照パス更新スクリプト
#!/bin/bash
echo "参照パス更新開始..."

# 移動したファイルの参照パス更新
sed -i 's|Archive/Backup-Snapshots/Emergency-Backups/emergency-backup-20250706_160519/|Archive/Backup-Snapshots/Emergency-Backups/Archive/Backup-Snapshots/Emergency-Backups/emergency-backup-20250706_160519/|g' **/*.md **/*.ts **/*.js
```

### 6. 移行実行チェックリスト

#### 6.1 移行前チェック
- [ ] 完全バックアップ作成完了
- [ ] 参照関係マッピング完了
- [ ] ディスク容量十分確認
- [ ] 開発チーム通知完了
- [ ] 移行スクリプト準備完了

#### 6.2 移行中チェック
- [ ] Phase 1完了・確認済み
- [ ] Phase 2完了・確認済み
- [ ] Phase 3完了・確認済み
- [ ] Phase 4完了・確認済み
- [ ] Phase 5完了・確認済み

#### 6.3 移行後チェック
- [ ] 参照整合性確認完了
- [ ] 機能テスト実行・合格
- [ ] 性能テスト実行・合格
- [ ] セキュリティチェック完了
- [ ] 開発環境動作確認完了

### 7. ロールバック手順

#### 7.1 ロールバック判定基準
- 参照整合性エラー発生
- 機能テスト失敗
- 性能劣化発生
- セキュリティ問題発生

#### 7.2 ロールバック実行
```bash
# 緊急ロールバック
tar -xzf pre-migration-backup-YYYYMMDD_HHMMSS.tar.gz
./scripts/restore-references.sh
npm test
```

### 8. 完了基準

#### 8.1 技術的完了基準
- 全ファイル移動完了
- 参照整合性100%維持
- 機能テスト100%合格
- 性能劣化0%
- セキュリティ問題0件

#### 8.2 運用完了基準
- 開発チーム移行確認完了
- ドキュメント更新完了
- 運用手順書更新完了
- 緊急時手順書作成完了