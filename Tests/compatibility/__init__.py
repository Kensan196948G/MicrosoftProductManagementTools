"""
PowerShell版との互換性テストモジュール
Dev1 - Test/QA Developer による基盤構築

Python版とPowerShell版の機能・出力互換性を検証するテストスイート

テストファイル:
- test_powershell_bridge.py: PowerShellBridge基本機能テスト
- test_data_format_compatibility.py: データフォーマット互換性テスト
- test_advanced_scenarios.py: 高度なシナリオテスト（非同期・パフォーマンス）
- conftest.py: pytest設定とフィクスチャー

実行方法:
python Tests/run_powershell_bridge_tests.py
"""

# バージョン情報
__version__ = "2.0.0"
__author__ = "Dev1 - Test/QA Developer"
__last_updated__ = "2025-01-18"

# テストカテゴリ
TEST_CATEGORIES = {
    "basic": "基本機能テスト",
    "data_format": "データフォーマット互換性",
    "advanced": "高度なシナリオテスト",
    "async": "非同期処理テスト",
    "performance": "パフォーマンステスト",
    "error_handling": "エラーハンドリングテスト"
}

# テストマーカー
PYTEST_MARKERS = {
    "compatibility": "互換性テスト",
    "slow": "実行時間が長いテスト",
    "async": "非同期処理テスト",
    "performance": "パフォーマンステスト",
    "integration": "統合テスト"
}