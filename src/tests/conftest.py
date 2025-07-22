"""
src/tests/conftest.py - 基本テスト設定
Phase 3統合版: ルートconftest.pyを継承
"""

# ルートconftest.pyから設定を継承
# 追加設定が必要な場合のみここに記述

import pytest
from pathlib import Path

# プロジェクトルートのconftest.pyから継承
# (pytestが自動的に親ディレクトリのconftest.pyを読み込む)

@pytest.fixture(scope="function")
def src_test_marker():
    """src/tests専用マーカー"""
    return "src_tests"
