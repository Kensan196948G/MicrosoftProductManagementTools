"""
Tests/conftest.py - 従来テスト互換性設定
Phase 3統合版: ルートconftest.pyを継承
"""

import pytest

# ルートconftest.pyから全設定を継承
# 従来テスト互換性のための追加設定のみここに記述

@pytest.fixture(scope="function")
def legacy_test_marker():
    """従来テスト専用マーカー"""
    return "legacy_tests"
