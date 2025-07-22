"""Microsoft 365 Python移行プロジェクト統合pytest設定
conftest.py競合解消 - Phase 1-2統合版

統合範囲:
- 全プロジェクト共通設定
- GUI/PowerShell/統合テスト対応
- パフォーマンス・セキュリティ・アクセシビリティテスト
- 重複除去と継承チェーン構築

QA Engineer: dev2 - conftest.py競合解消プロジェクト
Date: 2025-07-21
Version: 2.0.0 (統合版)
"""

import pytest
import sys
import os
import time
import tempfile
import shutil
from pathlib import Path
from unittest.mock import Mock, patch
from typing import Dict, Any, Generator, Optional

# プロジェクトルート設定
PROJECT_ROOT = Path(__file__).parent.absolute()

# パス設定 - 全ディレクトリを統合
path_configs = [
    PROJECT_ROOT / "src",
    PROJECT_ROOT / "Tests", 
    PROJECT_ROOT,
    "/usr/local/lib/python3.12/dist-packages"  # システムライブラリ
]

for path in path_configs:
    if Path(path).exists() and str(path) not in sys.path:
        sys.path.insert(0, str(path))

# GUI可用性統一検出ロジック
def detect_gui_availability() -> bool:
    """GUI テスト環境の統一可用性検出"""
    try:
        import PyQt6
        from PyQt6.QtWidgets import QApplication
        from PyQt6.QtCore import QTimer
        from PyQt6.QtTest import QTest
        # pytest-qt の複数インポートパターン対応
        try:
            import pytest_qt
        except ImportError:
            try:
                import pytestqt as pytest_qt
            except ImportError:
                return False
        return True
    except ImportError as e:
        print(f"⚠️ GUI testing packages unavailable: {e}")
        return False

# グローバル GUI 可用性フラグ
GUI_AVAILABLE = detect_gui_availability()

# =============================================================================
# セッション スコープ フィクスチャ (全テスト共通)
# =============================================================================

@pytest.fixture(scope="session")
def setup_and_teardown():
    """統合テストセッション設定・クリーンアップ"""
    print("\n🚀 === Microsoft 365 Python移行 統合テストセッション開始 ===")
    print(f"📁 プロジェクトルート: {PROJECT_ROOT}")
    print(f"🖥️ GUI環境: {'✅ 利用可能' if GUI_AVAILABLE else '❌ 制限付き'}")
    print(f"🐍 Python: {sys.version}")
    print(f"📊 pytest実行環境: 統合conftest.py v2.0")
    
    yield
    
    print("\n🧹 === 統合テストセッション クリーンアップ ===")
    print("✅ Phase 1-2 conftest.py競合解消テスト完了")

@pytest.fixture(scope="session")
def project_root():
    """プロジェクトルートパス - 統一版"""
    return PROJECT_ROOT

@pytest.fixture(scope="session")
def gui_available():
    """GUI環境可用性 - 統一フラグ"""
    return GUI_AVAILABLE

# =============================================================================
# 機能スコープ フィクスチャ (テスト毎)
# =============================================================================

@pytest.fixture(scope="function")
def temp_config():
    """統合テスト設定 - Microsoft 365環境対応"""
    return {
        # Microsoft 365 認証設定
        "tenant_id": "test-tenant-12345",
        "client_id": "test-client-67890",
        "client_secret": "test-secret-mock",
        
        # API エンドポイント
        "api_base_url": "https://graph.microsoft.com",
        "websocket_url": "ws://localhost:8000/ws",
        
        # テスト モード設定
        "test_mode": True,
        "mock_data_enabled": True,
        "debug_logging": True,
        
        # GUI 設定
        "log_level": "INFO",
        "max_log_entries": 100,
        "reconnect_interval": 5
    }

@pytest.fixture(scope="function")
def temp_directory():
    """一時ディレクトリ - 自動クリーンアップ"""
    temp_dir = tempfile.mkdtemp(prefix="m365_test_")
    yield Path(temp_dir)
    shutil.rmtree(temp_dir, ignore_errors=True)

@pytest.fixture(scope="function")
def performance_monitor():
    """パフォーマンス監視 - 統合版"""
    class PerformanceMonitor:
        def __init__(self):
            self.start_time = None
            self.measurements = {}
        
        def start(self, operation_name: str = "default"):
            self.start_time = time.time()
            self.operation_name = operation_name
        
        def stop(self, max_duration: float = None):
            if self.start_time is None:
                raise ValueError("Performance monitoring not started")
            
            duration = time.time() - self.start_time
            self.measurements[self.operation_name] = duration
            
            if max_duration and duration > max_duration:
                pytest.fail(f"操作'{self.operation_name}'が制限時間を超過: {duration:.2f}s (最大: {max_duration}s)")
            
            self.start_time = None
            return duration
        
        def get_measurement(self, operation_name: str = "default"):
            return self.measurements.get(operation_name)
    
    return PerformanceMonitor()

# =============================================================================
# pytest 設定・マーカー統合
# =============================================================================

def pytest_configure(config):
    """pytest統合設定 - 全マーカー統合版"""
    # 基本テストタイプ
    config.addinivalue_line("markers", "unit: 単体テスト")
    config.addinivalue_line("markers", "integration: 統合テスト")
    config.addinivalue_line("markers", "e2e: エンドツーエンドテスト")
    config.addinivalue_line("markers", "e2e_suite: E2Eテストスイート")
    
    # 技術領域別
    config.addinivalue_line("markers", "gui: GUIテスト (PyQt6)")
    config.addinivalue_line("markers", "api: APIテスト (Microsoft Graph)")
    config.addinivalue_line("markers", "compatibility: PowerShell互換性テスト")
    config.addinivalue_line("markers", "security: セキュリティテスト")
    
    # 品質・パフォーマンス
    config.addinivalue_line("markers", "performance: パフォーマンステスト")
    config.addinivalue_line("markers", "slow: 長時間実行テスト")
    config.addinivalue_line("markers", "accessibility: アクセシビリティテスト")
    
    # 開発チーム連携
    config.addinivalue_line("markers", "frontend_backend: フロントエンド・バックエンド統合")
    config.addinivalue_line("markers", "dev0_collaboration: dev0連携テスト")
    config.addinivalue_line("markers", "dev1_collaboration: dev1連携テスト")
    config.addinivalue_line("markers", "dev2_collaboration: dev2 QA連携テスト")
    
    # Phase 1-2 conftest競合解消専用
    config.addinivalue_line("markers", "conftest_integration: conftest統合テスト")
    config.addinivalue_line("markers", "phase1_2: Phase 1-2 競合解消テスト")

def pytest_collection_modifyitems(config, items):
    """テスト収集時の自動マーカー適用 - 統合版"""
    for item in items:
        # GUI環境チェック - GUIテストを自動スキップ
        if not GUI_AVAILABLE:
            if "gui" in item.keywords or "qt" in item.name.lower():
                skip_gui = pytest.mark.skip(reason="GUI packages (PyQt6/pytest-qt) not available")
                item.add_marker(skip_gui)
        
        # ファイルパスベースの自動マーカー適用
        if "gui" in str(item.fspath):
            item.add_marker(pytest.mark.gui)
        
        if "integration" in str(item.fspath) or "integration" in item.name:
            item.add_marker(pytest.mark.integration)
        
        if "performance" in item.name or "stress" in item.name:
            item.add_marker(pytest.mark.slow)
            item.add_marker(pytest.mark.performance)
        
        # conftest競合解消テスト専用マーカー
        if "conftest" in item.name or "phase1" in item.name or "phase2" in item.name:
            item.add_marker(pytest.mark.conftest_integration)
            item.add_marker(pytest.mark.phase1_2)

# =============================================================================
# Microsoft 365 モックデータ統合フィクスチャ
# =============================================================================

@pytest.fixture(scope="function")
def mock_m365_users():
    """Microsoft 365ユーザーデータ統合モック"""
    return {
        "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#users",
        "@odata.count": 3,
        "value": [
            {
                "id": "87d349ed-44d7-43e1-9a83-5f2406dee5bd",
                "displayName": "田中 太郎",
                "userPrincipalName": "tanaka.taro@contoso.onmicrosoft.com",
                "mail": "tanaka.taro@contoso.com",
                "accountEnabled": True,
                "department": "営業部",
                "jobTitle": "営業部長"
            },
            {
                "id": "45b7d2e7-b882-4989-a5f7-3573b8fbf9e4", 
                "displayName": "佐藤 花子",
                "userPrincipalName": "sato.hanako@contoso.onmicrosoft.com",
                "mail": "sato.hanako@contoso.com",
                "accountEnabled": True,
                "department": "人事部",
                "jobTitle": "人事マネージャー"
            }
        ]
    }

@pytest.fixture(scope="function")
def mock_m365_licenses():
    """Microsoft 365ライセンス統合モック"""
    return {
        "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#subscribedSkus",
        "value": [
            {
                "id": "b05e124f-c7cc-45a0-a6aa-8cf78c946968",
                "skuPartNumber": "ENTERPRISEPREMIUM",
                "consumedUnits": 23,
                "prepaidUnits": {"enabled": 25, "suspended": 0, "warning": 0}
            }
        ]
    }

# =============================================================================
# GUI テスト専用フィクスチャ (PyQt6)
# =============================================================================

if GUI_AVAILABLE:
    @pytest.fixture(scope="session")
    def qapp():
        """PyQt6アプリケーション - セッションスコープ"""
        from PyQt6.QtWidgets import QApplication
        from PyQt6.QtCore import Qt
        
        app = QApplication.instance()
        if app is None:
            app = QApplication([])
            # PyQt6では一部の属性名が変更されているため条件分岐
            try:
                app.setAttribute(Qt.ApplicationAttribute.AA_DisableWindowContextHelpButton)
            except AttributeError:
                # PyQt6での代替設定
                pass
        yield app
        # pytest-qtがクリーンアップを処理

    @pytest.fixture(scope="function")
    def gui_test_helper():
        """GUI テストヘルパー統合版"""
        from PyQt6.QtWidgets import QApplication
        from PyQt6.QtTest import QTest
        import asyncio
        
        class GuiTestHelper:
            @staticmethod
            def wait_for_signal(signal, timeout_ms=5000):
                """PyQtシグナル待機"""
                signal_received = False
                
                def on_signal(*args):
                    nonlocal signal_received
                    signal_received = True
                
                signal.connect(on_signal)
                start_time = time.time()
                while not signal_received and (time.time() - start_time) * 1000 < timeout_ms:
                    QApplication.processEvents()
                    time.sleep(0.01)
                
                signal.disconnect(on_signal)
                return signal_received
            
            @staticmethod
            def simulate_user_delay(ms=100):
                """ユーザー操作遅延シミュレーション"""
                QTest.qWait(ms)
        
        return GuiTestHelper()
else:
    # GUI非対応環境用のダミーフィクスチャ
    @pytest.fixture(scope="session")
    def qapp():
        pytest.skip("GUI packages not available")
    
    @pytest.fixture(scope="function")
    def gui_test_helper():
        pytest.skip("GUI packages not available")

# =============================================================================
# セッション終了時クリーンアップ
# =============================================================================

@pytest.fixture(scope="session", autouse=True)
def cleanup_session():
    """セッション終了時の統合クリーンアップ"""
    yield
    print("\n🧹 統合conftest.py セッションクリーンアップ完了")
    print("✅ Phase 1-2 conftest.py競合解消プロジェクト成功")

# =============================================================================
# 環境変数設定 - テスト実行時
# =============================================================================

@pytest.fixture(autouse=True)
def setup_test_environment():
    """テスト環境変数統一設定"""
    # 共通テスト環境変数
    test_env = {
        'PYTEST_RUNNING': 'true',
        'CONFTEST_INTEGRATION_MODE': 'true',
        'M365_TEST_MODE': 'enabled',
        'QT_QPA_PLATFORM': 'offscreen'  # ヘッドレステスト
    }
    
    # 環境変数設定
    original_env = {}
    for key, value in test_env.items():
        original_env[key] = os.environ.get(key)
        os.environ[key] = value
    
    yield
    
    # 環境変数復元
    for key, original_value in original_env.items():
        if original_value is None:
            os.environ.pop(key, None)
        else:
            os.environ[key] = original_value