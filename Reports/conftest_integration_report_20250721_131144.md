# conftest.py競合解消・統合レポート

## プロジェクト情報
- **プロジェクト**: Microsoft 365 Python移行プロジェクト
- **フェーズ**: Phase 3 - 自動統合システム
- **実行日時**: 2025-07-21 13:11:44
- **バックアップ**: /mnt/e/MicrosoftProductManagementTools/Backups/conftest_backups/backup_20250721_131144

## 統合結果サマリー
- **統合対象ファイル**: 6個
- **検出された競合**: 26件
- **統合後テスト**: ❌ 失敗

## 処理されたファイル
- **root**: `/mnt/e/MicrosoftProductManagementTools/conftest.py`
- **tests**: `/mnt/e/MicrosoftProductManagementTools/Tests/conftest.py`
- **src_tests**: `/mnt/e/MicrosoftProductManagementTools/src/tests/conftest.py`
- **gui_tests**: `/mnt/e/MicrosoftProductManagementTools/src/gui/tests/conftest.py`
- **integration_tests**: `/mnt/e/MicrosoftProductManagementTools/src/gui/integration/tests/conftest.py`
- **compatibility**: `/mnt/e/MicrosoftProductManagementTools/Tests/compatibility/conftest.py`

## 競合解消結果
- **fixture_setup_and_teardown**: root, tests
- **fixture_project_root**: root, tests
- **fixture_gui_available**: root, tests
- **fixture_temp_config**: root, tests
- **fixture_temp_directory**: root, gui_tests
- **fixture_performance_monitor**: root, src_tests
- **fixture_mock_m365_users**: root, compatibility
- **fixture_mock_m365_licenses**: root, compatibility
- **fixture_cleanup_session**: root, src_tests
- **fixture_setup_test_environment**: root, gui_tests
- **fixture_mock_config**: src_tests, gui_tests
- **fixture_qapp**: gui_tests, integration_tests
- **fixture_mock_external_dependencies**: gui_tests, integration_tests
- **marker_unit**: root, tests
- **marker_integration**: root, tests
- **marker_e2e**: root, tests
- **marker_e2e_suite**: root, tests
- **marker_gui**: root, tests
- **marker_api**: root, tests
- **marker_compatibility**: root, tests
- **marker_security**: root, tests
- **marker_performance**: root, tests
- **marker_slow**: root, tests
- **marker_frontend_backend**: root, tests
- **marker_dev0_collaboration**: root, tests
- **marker_dev1_collaboration**: root, tests

## 最終構成
- **ルートconftest.py**: 統合設定（全プロジェクト共通）
- **階層別conftest.py**: 最小設定（ルートから継承）

## 次のアクション
⚠️ 問題の修正が必要

## ログファイル
- **詳細ログ**: `/mnt/e/MicrosoftProductManagementTools/Logs/conftest_integration_20250721_131144.log`
- **バックアップ**: `/mnt/e/MicrosoftProductManagementTools/Backups/conftest_backups/backup_20250721_131144`
