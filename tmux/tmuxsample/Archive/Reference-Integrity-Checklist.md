# 参照整合性チェックリスト
## ITSMディレクトリ構造最適化プロジェクト

### 1. 事前参照関係調査

#### 1.1 ファイル参照関係マッピング
- [ ] **Markdown文書内の相対パス参照調査**
  ```bash
  find . -name "*.md" -exec grep -Hn "\.\./\|\./" {} \; > pre-migration-md-references.txt
  ```
- [ ] **TypeScript/JavaScript import文調査**
  ```bash
  find . -name "*.ts" -o -name "*.js" | xargs grep -Hn "import.*from.*\.\." > pre-migration-import-references.txt
  ```
- [ ] **package.json依存関係調査**
  ```bash
  find . -name "package.json" -exec grep -Hn "file:" {} \; > pre-migration-package-references.txt
  ```
- [ ] **設定ファイル参照調査**
  ```bash
  find . -name "*.config.*" -o -name "*.json" | xargs grep -Hn "\.\./\|\./" > pre-migration-config-references.txt
  ```

#### 1.2 移動対象ファイル影響調査
- [ ] **Archive/Backup-Snapshots/Emergency-Backups/emergency-backup-20250706_160519/ 参照調査**
  ```bash
  grep -r "emergency-backup-20250706_160519" . --exclude-dir=node_modules > emergency-backup-references.txt
  ```
- [ ] **Archive/Temporary-Files/Cache-Files/cookies.txt 参照調査**
  ```bash
  grep -r "Archive/Temporary-Files/Cache-Files/cookies.txt" . --exclude-dir=node_modules > cookies-references.txt
  ```
- [ ] **テストファイル参照調査**
  ```bash
  grep -r "Archive/Test-Data-Archive/Integration-Test-Results/complete_test.txt\|Archive/Test-Data-Archive/Integration-Test-Results/final_clean_test.txt\|Archive/Test-Data-Archive/Integration-Test-Results/integration_test.txt" . --exclude-dir=node_modules > test-file-references.txt
  ```

### 2. 移動実行時チェック

#### 2.1 各Phase実行時確認
- [ ] **Phase 1: 一時ファイル移動**
  - [ ] Archive/Temporary-Files/Cache-Files/cookies.txt 移動確認
  - [ ] csrf_Archive/Temporary-Files/Cache-Files/cookies.txt 移動確認
  - [ ] 参照パス更新確認
  - [ ] 機能テスト実行確認

- [ ] **Phase 2: バックアップファイル移動**
  - [ ] Archive/Backup-Snapshots/Emergency-Backups/emergency-backup-20250706_160519/ 移動確認
  - [ ] Archive/Backup-Snapshots/Daily-Snapshots/data_backup_20250708_212315/ 移動確認
  - [ ] 参照パス更新確認
  - [ ] バックアップスクリプト動作確認

- [ ] **Phase 3: テストデータ移動**
  - [ ] Archive/Test-Data-Archive/Integration-Test-Results/complete_test.txt 移動確認
  - [ ] Archive/Test-Data-Archive/Integration-Test-Results/final_clean_test.txt 移動確認
  - [ ] Archive/Test-Data-Archive/Integration-Test-Results/integration_test.txt 移動確認
  - [ ] テストスクリプト動作確認

- [ ] **Phase 4: ドキュメント移動**
  - [ ] 過去レポート移動確認
  - [ ] 参照リンク更新確認
  - [ ] ドキュメント生成確認

- [ ] **Phase 5: 廃止コンポーネント移動**
  - [ ] 旧コンポーネント移動確認
  - [ ] import文更新確認
  - [ ] ビルドプロセス確認

### 3. 参照パス更新確認

#### 3.1 自動更新対象
- [ ] **Markdown文書内リンク更新**
  ```bash
  # 相対パス更新
  find . -name "*.md" -exec sed -i 's|Archive/Backup-Snapshots/Emergency-Backups/emergency-backup-20250706_160519/|Archive/Backup-Snapshots/Emergency-Backups/Archive/Backup-Snapshots/Emergency-Backups/emergency-backup-20250706_160519/|g' {} \;
  ```
- [ ] **設定ファイル更新**
  ```bash
  # package.jsonファイル参照更新
  find . -name "package.json" -exec sed -i 's|file:Archive/Temporary-Files/Cache-Files/cookies.txt|file:Archive/Temporary-Files/Cache-Files/Archive/Temporary-Files/Cache-Files/cookies.txt|g' {} \;
  ```
- [ ] **スクリプト内パス更新**
  ```bash
  # シェルスクリプト内パス更新
  find . -name "*.sh" -exec sed -i 's|Archive/Temporary-Files/Cache-Files/cookies.txt|Archive/Temporary-Files/Cache-Files/Archive/Temporary-Files/Cache-Files/cookies.txt|g' {} \;
  ```

#### 3.2 手動更新対象
- [ ] **TypeScript/JavaScript import文**
  - [ ] 相対パス確認・更新
  - [ ] モジュール解決確認
  - [ ] バンドラー設定確認

- [ ] **設定ファイル高度設定**
  - [ ] webpack.config.js 更新
  - [ ] tsconfig.json 更新
  - [ ] jest.config.js 更新

### 4. 移行後整合性確認

#### 4.1 自動確認項目
- [ ] **ファイル存在確認**
  ```bash
  # 移動したファイルの存在確認
  ./scripts/verify-migrated-files.sh
  ```
- [ ] **参照リンク確認**
  ```bash
  # 全参照リンクの有効性確認
  ./scripts/verify-references.sh
  ```
- [ ] **ビルドプロセス確認**
  ```bash
  # フロントエンド・バックエンドビルド確認
  npm run build
  cd itsm-backend && npm run build
  ```

#### 4.2 手動確認項目
- [ ] **機能テスト実行**
  - [ ] 認証機能テスト
  - [ ] API機能テスト
  - [ ] UI機能テスト
  - [ ] 統合テスト

- [ ] **性能テスト実行**
  - [ ] ページ読み込み時間測定
  - [ ] API応答時間測定
  - [ ] メモリ使用量測定

- [ ] **セキュリティチェック**
  - [ ] 認証・認可確認
  - [ ] ファイルアクセス権限確認
  - [ ] 機密情報漏洩チェック

### 5. 日本語ファイル名対応確認

#### 5.1 変換前確認
- [ ] **対象ファイル一覧確認**
  ```bash
  find . -name "*[^[:ascii:]]*" > japanese-filename-list.txt
  ```
- [ ] **参照関係調査**
  ```bash
  # 日本語ファイル名の参照調査
  while IFS= read -r file; do
    grep -r "$(basename "$file")" . --exclude-dir=node_modules
  done < japanese-filename-list.txt > japanese-references.txt
  ```

#### 5.2 変換後確認
- [ ] **ファイル名変換確認**
  - [ ] tmux仕様書.md → tmux-specification.md
  - [ ] 操作手順書.md → operation-manual.md
  - [ ] クイックリファレンス.md → quick-reference.md

- [ ] **参照更新確認**
  - [ ] Markdown内リンク更新
  - [ ] インデックスファイル更新
  - [ ] 目次ファイル更新

### 6. 緊急時対応確認

#### 6.1 ロールバック準備
- [ ] **完全バックアップ存在確認**
  ```bash
  ls -la pre-migration-backup-*.tar.gz
  ```
- [ ] **ロールバックスクリプト準備**
  ```bash
  ./scripts/prepare-rollback.sh
  ```

#### 6.2 ロールバック実行確認
- [ ] **バックアップ復元テスト**
  ```bash
  # テスト環境でロールバック実行
  ./scripts/test-rollback.sh
  ```
- [ ] **システム復旧確認**
  - [ ] 全機能動作確認
  - [ ] 参照整合性確認
  - [ ] 性能確認

### 7. 最終確認項目

#### 7.1 システム全体確認
- [ ] **フロントエンド動作確認**
  - [ ] 画面表示確認
  - [ ] 機能動作確認
  - [ ] エラー発生なし

- [ ] **バックエンド動作確認**
  - [ ] API応答確認
  - [ ] データベース接続確認
  - [ ] ログ出力確認

- [ ] **統合システム確認**
  - [ ] フロントエンド・バックエンド連携確認
  - [ ] 認証フロー確認
  - [ ] データ整合性確認

#### 7.2 運用環境確認
- [ ] **開発環境確認**
  - [ ] ローカル開発環境動作確認
  - [ ] 開発者アクセス確認
  - [ ] デバッグ機能確認

- [ ] **本番環境準備確認**
  - [ ] 本番環境設定確認
  - [ ] デプロイプロセス確認
  - [ ] 監視システム確認

### 8. 完了報告準備

#### 8.1 技術レポート作成
- [ ] **移行結果サマリー**
  - 移動ファイル数
  - 参照更新件数
  - 発生問題・対応状況
  - 性能影響評価

- [ ] **品質確認レポート**
  - テスト実行結果
  - 性能測定結果
  - セキュリティチェック結果
  - 整合性確認結果

#### 8.2 運用ドキュメント更新
- [ ] **運用手順書更新**
- [ ] **緊急時対応手順更新**
- [ ] **開発者向けガイド更新**
- [ ] **アーキテクチャ図更新**

### 9. 確認実行コマンド集

#### 9.1 参照整合性確認コマンド
```bash
# 全参照リンク確認
./scripts/verify-all-references.sh

# 移動ファイル確認
./scripts/verify-migrated-files.sh

# 機能テスト実行
npm test && cd itsm-backend && npm test

# 性能テスト実行
npm run test:performance
```

#### 9.2 緊急時対応コマンド
```bash
# 緊急ロールバック
./scripts/emergency-rollback.sh

# システム復旧確認
./scripts/verify-system-recovery.sh

# 緊急時通知
./scripts/notify-emergency-status.sh
```