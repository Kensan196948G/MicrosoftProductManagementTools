"""
src/gui/tests/conftest.py - GUI専用テスト設定
Phase 3統合版: ルートconftest.pyを継承
"""

import pytest

# ルートconftest.pyから全設定を継承
# GUI専用の追加設定のみここに記述

@pytest.fixture(scope="function") 
def gui_test_marker():
    """GUI tests専用マーカー"""
    return "gui_tests"

# GUI特有のマーカー
def pytest_configure(config):
    """GUI専用マーカー追加"""
    config.addinivalue_line("markers", "gui_specific: GUI固有のテスト")
