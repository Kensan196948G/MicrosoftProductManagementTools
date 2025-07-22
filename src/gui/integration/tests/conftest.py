"""
src/gui/integration/tests/conftest.py - 統合テスト設定
Phase 3統合版: ルートconftest.pyを継承
"""

import pytest

# ルートconftest.pyから全設定を継承
# 統合テスト専用の追加設定のみここに記述

@pytest.fixture(scope="function")
def integration_test_marker():
    """統合テスト専用マーカー"""
    return "integration_tests"

# 統合テスト専用マーカー
def pytest_configure(config):
    """統合テスト専用マーカー追加"""
    config.addinivalue_line("markers", "integration_specific: 統合テスト固有")
