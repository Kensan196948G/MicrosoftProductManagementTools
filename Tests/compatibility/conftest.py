"""
Tests/compatibility/conftest.py - PowerShell互換性テスト設定
Phase 3統合版: ルートconftest.pyを継承
"""

import pytest

# ルートconftest.pyから全設定を継承
# PowerShell互換性テスト専用の追加設定のみここに記述

@pytest.fixture(scope="function")
def powershell_compatibility_marker():
    """PowerShell互換性テスト専用マーカー"""
    return "powershell_compatibility"

# PowerShell互換性専用マーカー
def pytest_configure(config):
    """PowerShell互換性専用マーカー追加"""
    config.addinivalue_line("markers", "powershell_compatibility: PowerShell互換性テスト")
