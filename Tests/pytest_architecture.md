# Python テストアーキテクチャ設計書

## 1. 全体アーキテクチャ

### 1.1 テストピラミッド構造

```
            ┌─────────────────────────┐
            │      E2E Tests         │ ← 少数・高価値
            │   (GUI/CLI完全テスト)    │
            ├─────────────────────────┤
            │   Integration Tests     │ ← 中規模・API統合
            │ (Microsoft Graph/EXO)   │
            ├─────────────────────────┤
            │     Unit Tests          │ ← 多数・高速
            │  (個別コンポーネント)    │
            └─────────────────────────┘
```

### 1.2 テストフレームワーク選択

#### 主要フレームワーク
- **pytest**: メインテストフレームワーク
- **pytest-asyncio**: 非同期テスト対応
- **pytest-qt**: PyQt6 GUIテスト
- **pytest-cov**: カバレッジ測定
- **pytest-xdist**: 並列実行
- **pytest-html**: HTMLレポート生成

#### 補助ライブラリ
- **unittest.mock**: モック機能
- **responses**: HTTPリクエストモック
- **freezegun**: 時間制御
- **factory-boy**: テストデータ生成
- **faker**: ダミーデータ生成

### 1.3 ディレクトリ構造

```
Tests/
├── unit/                    # 単体テスト
│   ├── test_auth.py        # 認証モジュール
│   ├── test_config.py      # 設定管理
│   ├── test_graph_client.py # Microsoft Graph
│   └── test_powershell_bridge.py # PowerShell統合
├── integration/             # 統合テスト
│   ├── test_auth_integration.py
│   └── test_e2e_workflows.py
├── e2e/                    # E2Eテスト
│   ├── test_gui_workflows.py
│   └── test_cli_workflows.py
├── performance/            # パフォーマンステスト
│   └── test_performance.py
├── security/               # セキュリティテスト
│   └── test_security.py
├── compatibility/          # 互換性テスト
│   └── test_powershell_compatibility.py
├── fixtures/               # テストフィクスチャ
│   ├── auth_fixtures.py
│   └── data_fixtures.py
├── mocks/                  # モックデータ
│   ├── graph_api_mock.py
│   └── exchange_mock.py
├── conftest.py            # pytest設定
├── pytest.ini            # pytest設定ファイル
└── requirements-test.txt  # テスト依存関係
```

## 2. pytest設定

### 2.1 pytest.ini設定

```ini
[tool:pytest]
minversion = 6.0
addopts = 
    -ra
    --strict-markers
    --strict-config
    --cov=src
    --cov-report=term-missing
    --cov-report=html:htmlcov
    --cov-report=xml
    --html=reports/report.html
    --self-contained-html
    --tb=short
    --maxfail=10
    -p no:warnings
testpaths = Tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
markers =
    unit: ユニットテスト
    integration: 統合テスト
    e2e: エンドツーエンドテスト
    gui: GUIテスト
    cli: CLIテスト
    auth: 認証テスト
    api: APIテスト
    slow: 実行時間の長いテスト
    security: セキュリティテスト
    performance: パフォーマンステスト
    compatibility: 互換性テスト
    requires_auth: 認証が必要なテスト
    requires_powershell: PowerShell実行が必要なテスト
    mock: モックテスト
    real_data: 実データテスト
```

### 2.2 conftest.py設定

```python
"""pytest設定とグローバルフィクスチャ"""

import pytest
import asyncio
import sys
from pathlib import Path
from unittest.mock import Mock, patch
from typing import Generator, Dict, Any
import logging

# プロジェクトルートをPythonパスに追加
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "src"))

# ロギング設定
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# 非同期テスト用イベントループ
@pytest.fixture(scope="session")
def event_loop():
    """セッションスコープの非同期イベントループ"""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()

# プロジェクト設定
@pytest.fixture(scope="session")
def project_root() -> Path:
    """プロジェクトルートパス"""
    return PROJECT_ROOT

@pytest.fixture(scope="session")
def config_path(project_root: Path) -> Path:
    """設定ファイルパス"""
    return project_root / "Config" / "appsettings.json"

@pytest.fixture(scope="session")
def test_data_path(project_root: Path) -> Path:
    """テストデータパス"""
    return project_root / "Tests" / "fixtures" / "test_data"

# Microsoft Graph API モック
@pytest.fixture(scope="function")
def mock_graph_client():
    """Microsoft Graph APIクライアントのモック"""
    with patch('src.api.graph.client.GraphClient') as mock:
        mock_instance = Mock()
        mock_instance.get_users.return_value = [
            {"id": "user1", "displayName": "Test User 1"},
            {"id": "user2", "displayName": "Test User 2"}
        ]
        mock_instance.get_licenses.return_value = [
            {"skuId": "license1", "skuPartNumber": "O365_BUSINESS_PREMIUM"}
        ]
        mock.return_value = mock_instance
        yield mock_instance

# Exchange Online モック
@pytest.fixture(scope="function")
def mock_exchange_client():
    """Exchange Online PowerShell クライアントのモック"""
    with patch('src.api.exchange.client.ExchangeClient') as mock:
        mock_instance = Mock()
        mock_instance.get_mailboxes.return_value = [
            {"Identity": "user1@contoso.com", "DisplayName": "User 1"},
            {"Identity": "user2@contoso.com", "DisplayName": "User 2"}
        ]
        mock.return_value = mock_instance
        yield mock_instance

# PowerShell実行モック
@pytest.fixture(scope="function")
def mock_powershell_execution():
    """PowerShell実行のモック"""
    with patch('subprocess.run') as mock_run:
        mock_result = Mock()
        mock_result.returncode = 0
        mock_result.stdout = "PowerShell実行成功"
        mock_result.stderr = ""
        mock_run.return_value = mock_result
        yield mock_run

# 認証モック
@pytest.fixture(scope="function")
def mock_auth_success():
    """認証成功のモック"""
    with patch('src.core.auth.AuthManager') as mock:
        mock_instance = Mock()
        mock_instance.authenticate.return_value = True
        mock_instance.get_access_token.return_value = "mock_token"
        mock.return_value = mock_instance
        yield mock_instance

# テスト環境設定
@pytest.fixture(scope="session")
def test_environment():
    """テスト環境設定"""
    return {
        "AZURE_CLIENT_ID": "test_client_id",
        "AZURE_CLIENT_SECRET": "test_client_secret",
        "AZURE_TENANT_ID": "test_tenant_id",
        "CERTIFICATE_PATH": "test_certificate.pfx",
        "CERTIFICATE_PASSWORD": "test_password"
    }

# GUI テスト用フィクスチャ
@pytest.fixture(scope="function")
def qtbot(qtbot):
    """PyQt6 テストヘルパー"""
    return qtbot

# テストカテゴリ別設定
def pytest_configure(config):
    """pytest設定の動的設定"""
    config.addinivalue_line(
        "markers", "requires_gui: GUI環境が必要なテスト"
    )
    config.addinivalue_line(
        "markers", "requires_network: ネットワーク接続が必要なテスト"
    )

def pytest_collection_modifyitems(config, items):
    """テストアイテムの動的修正"""
    for item in items:
        # スローテストにマーカーを追加
        if "slow" not in item.keywords:
            if any(keyword in item.nodeid for keyword in ["integration", "e2e", "performance"]):
                item.add_marker(pytest.mark.slow)
        
        # GUI環境チェック
        if "gui" in item.keywords:
            item.add_marker(pytest.mark.requires_gui)
        
        # 認証要件チェック
        if any(keyword in item.nodeid for keyword in ["auth", "graph", "exchange"]):
            item.add_marker(pytest.mark.requires_auth)

# テスト実行前後のフック
@pytest.fixture(autouse=True)
def setup_and_teardown():
    """各テストの前後処理"""
    # セットアップ
    print("\\n=== テスト開始 ===")
    
    yield
    
    # ティアダウン
    print("=== テスト終了 ===")

# カスタムマーカー実行制御
def pytest_runtest_setup(item):
    """テスト実行前の条件チェック"""
    if "requires_gui" in item.keywords:
        if not hasattr(item.config, "_gui_available"):
            pytest.skip("GUI環境が利用できません")
    
    if "requires_network" in item.keywords:
        if not hasattr(item.config, "_network_available"):
            pytest.skip("ネットワーク接続が利用できません")

# 並列実行用ワーカー設定
@pytest.fixture(scope="session")
def worker_id(request):
    """並列実行時のワーカーID"""
    return getattr(request.config, "workerinput", {}).get("workerid", "master")
```

## 3. テストカテゴリ別実装

### 3.1 単体テスト (Unit Tests)

#### 3.1.1 認証テスト

```python
# Tests/unit/test_auth.py
"""認証モジュールの単体テスト"""

import pytest
from unittest.mock import patch, Mock
from src.core.auth import AuthManager
from src.core.exceptions import AuthenticationError

class TestAuthManager:
    """認証マネージャーのテスト"""
    
    def test_certificate_auth_success(self, mock_auth_success):
        """証明書認証の成功テスト"""
        auth_manager = AuthManager()
        result = auth_manager.authenticate_with_certificate(
            "test_cert.pfx", "password"
        )
        assert result is True
        mock_auth_success.authenticate.assert_called_once()
    
    def test_certificate_auth_failure(self):
        """証明書認証の失敗テスト"""
        with patch('src.core.auth.AuthManager.authenticate') as mock_auth:
            mock_auth.side_effect = AuthenticationError("Invalid certificate")
            
            auth_manager = AuthManager()
            with pytest.raises(AuthenticationError):
                auth_manager.authenticate_with_certificate(
                    "invalid_cert.pfx", "wrong_password"
                )
    
    @pytest.mark.asyncio
    async def test_token_refresh(self, mock_auth_success):
        """トークンリフレッシュテスト"""
        auth_manager = AuthManager()
        mock_auth_success.refresh_token.return_value = "new_token"
        
        new_token = await auth_manager.refresh_access_token()
        assert new_token == "new_token"
        mock_auth_success.refresh_token.assert_called_once()
```

#### 3.1.2 設定管理テスト

```python
# Tests/unit/test_config.py
"""設定管理モジュールの単体テスト"""

import pytest
import json
from pathlib import Path
from src.core.config import ConfigManager
from src.core.exceptions import ConfigurationError

class TestConfigManager:
    """設定管理のテスト"""
    
    def test_load_config_success(self, config_path):
        """設定ファイル読み込み成功テスト"""
        config_manager = ConfigManager(config_path)
        config = config_manager.load_config()
        
        assert config is not None
        assert "azure" in config
        assert "logging" in config
    
    def test_load_invalid_config(self, tmp_path):
        """不正な設定ファイルの読み込みテスト"""
        invalid_config = tmp_path / "invalid_config.json"
        invalid_config.write_text("invalid json")
        
        config_manager = ConfigManager(invalid_config)
        with pytest.raises(ConfigurationError):
            config_manager.load_config()
    
    def test_get_setting(self, config_path):
        """設定値取得テスト"""
        config_manager = ConfigManager(config_path)
        
        # 存在する設定値
        client_id = config_manager.get_setting("azure.client_id")
        assert client_id is not None
        
        # 存在しない設定値
        with pytest.raises(KeyError):
            config_manager.get_setting("non_existent.setting")
```

#### 3.1.3 Microsoft Graph クライアントテスト

```python
# Tests/unit/test_graph_client.py
"""Microsoft Graph APIクライアントの単体テスト"""

import pytest
from unittest.mock import patch, Mock
from src.api.graph.client import GraphClient
from src.core.exceptions import GraphAPIError

class TestGraphClient:
    """Microsoft Graph クライアントのテスト"""
    
    @pytest.fixture
    def graph_client(self, mock_auth_success):
        """GraphClientのフィクスチャ"""
        return GraphClient(auth_manager=mock_auth_success)
    
    @pytest.mark.asyncio
    async def test_get_users_success(self, graph_client, mock_graph_client):
        """ユーザー取得成功テスト"""
        users = await graph_client.get_users()
        
        assert len(users) == 2
        assert users[0]["displayName"] == "Test User 1"
        assert users[1]["displayName"] == "Test User 2"
    
    @pytest.mark.asyncio
    async def test_get_users_api_error(self, graph_client):
        """Graph API エラーテスト"""
        with patch('src.api.graph.client.GraphClient._make_request') as mock_request:
            mock_request.side_effect = GraphAPIError("API Error")
            
            with pytest.raises(GraphAPIError):
                await graph_client.get_users()
    
    @pytest.mark.asyncio
    async def test_get_licenses(self, graph_client, mock_graph_client):
        """ライセンス取得テスト"""
        licenses = await graph_client.get_licenses()
        
        assert len(licenses) == 1
        assert licenses[0]["skuPartNumber"] == "O365_BUSINESS_PREMIUM"
```

### 3.2 統合テスト (Integration Tests)

#### 3.2.1 認証統合テスト

```python
# Tests/integration/test_auth_integration.py
"""認証統合テスト"""

import pytest
from src.core.auth import AuthManager
from src.api.graph.client import GraphClient
from src.api.exchange.client import ExchangeClient

class TestAuthIntegration:
    """認証統合テスト"""
    
    @pytest.mark.integration
    @pytest.mark.requires_auth
    async def test_graph_auth_integration(self, test_environment):
        """Microsoft Graph認証統合テスト"""
        auth_manager = AuthManager()
        
        # 認証実行
        success = await auth_manager.authenticate_with_client_secret(
            test_environment["AZURE_CLIENT_ID"],
            test_environment["AZURE_CLIENT_SECRET"],
            test_environment["AZURE_TENANT_ID"]
        )
        
        assert success is True
        
        # Graph API呼び出し
        graph_client = GraphClient(auth_manager)
        users = await graph_client.get_users()
        
        assert users is not None
        assert len(users) > 0
    
    @pytest.mark.integration
    @pytest.mark.requires_auth
    @pytest.mark.requires_powershell
    async def test_exchange_auth_integration(self, test_environment):
        """Exchange Online認証統合テスト"""
        auth_manager = AuthManager()
        
        # 認証実行
        success = await auth_manager.authenticate_with_certificate(
            test_environment["CERTIFICATE_PATH"],
            test_environment["CERTIFICATE_PASSWORD"]
        )
        
        assert success is True
        
        # Exchange PowerShell呼び出し
        exchange_client = ExchangeClient(auth_manager)
        mailboxes = await exchange_client.get_mailboxes()
        
        assert mailboxes is not None
        assert len(mailboxes) > 0
```

#### 3.2.2 E2Eワークフローテスト

```python
# Tests/integration/test_e2e_workflows.py
"""E2Eワークフローテスト"""

import pytest
from src.main import create_app
from src.core.workflow import WorkflowManager

class TestE2EWorkflows:
    """E2Eワークフロー統合テスト"""
    
    @pytest.mark.integration
    @pytest.mark.e2e
    async def test_daily_report_workflow(self, mock_graph_client, mock_exchange_client):
        """日次レポートワークフローテスト"""
        workflow_manager = WorkflowManager()
        
        # 日次レポートワークフロー実行
        result = await workflow_manager.execute_daily_report()
        
        assert result["status"] == "success"
        assert "user_count" in result
        assert "license_count" in result
        assert "mailbox_count" in result
    
    @pytest.mark.integration
    @pytest.mark.e2e
    async def test_security_audit_workflow(self, mock_graph_client):
        """セキュリティ監査ワークフローテスト"""
        workflow_manager = WorkflowManager()
        
        # セキュリティ監査実行
        result = await workflow_manager.execute_security_audit()
        
        assert result["status"] == "success"
        assert "mfa_enabled_users" in result
        assert "conditional_access_policies" in result
        assert "sign_in_risks" in result
```

### 3.3 E2Eテスト (End-to-End Tests)

#### 3.3.1 GUIワークフローテスト

```python
# Tests/e2e/test_gui_workflows.py
"""GUI E2Eワークフローテスト"""

import pytest
from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import QApplication
from src.gui.main_window import MainWindow

class TestGUIWorkflows:
    """GUI E2Eワークフロー"""
    
    @pytest.mark.e2e
    @pytest.mark.gui
    @pytest.mark.requires_gui
    def test_daily_report_gui_workflow(self, qtbot, mock_graph_client):
        """日次レポートGUIワークフロー"""
        app = QApplication.instance()
        if app is None:
            app = QApplication([])
        
        window = MainWindow()
        qtbot.addWidget(window)
        
        # 日次レポートボタンクリック
        daily_report_button = window.findChild(QPushButton, "btnDailyReport")
        assert daily_report_button is not None
        
        qtbot.mouseClick(daily_report_button, Qt.LeftButton)
        
        # レポート生成完了まで待機
        qtbot.waitUntil(lambda: window.status_label.text() == "レポート生成完了", timeout=10000)
        
        # 結果確認
        assert "完了" in window.status_label.text()
    
    @pytest.mark.e2e
    @pytest.mark.gui
    @pytest.mark.requires_gui
    def test_user_management_gui_workflow(self, qtbot, mock_graph_client):
        """ユーザー管理GUIワークフロー"""
        app = QApplication.instance()
        if app is None:
            app = QApplication([])
        
        window = MainWindow()
        qtbot.addWidget(window)
        
        # ユーザー管理ボタンクリック
        user_mgmt_button = window.findChild(QPushButton, "btnUserManagement")
        qtbot.mouseClick(user_mgmt_button, Qt.LeftButton)
        
        # ユーザー一覧が表示されるまで待機
        qtbot.waitUntil(
            lambda: window.user_table.rowCount() > 0, 
            timeout=10000
        )
        
        # テーブルデータ確認
        assert window.user_table.rowCount() == 2
        assert window.user_table.item(0, 0).text() == "Test User 1"
```

#### 3.3.2 CLIワークフローテスト

```python
# Tests/e2e/test_cli_workflows.py
"""CLI E2Eワークフローテスト"""

import pytest
import subprocess
import json
from pathlib import Path

class TestCLIWorkflows:
    """CLI E2Eワークフロー"""
    
    @pytest.mark.e2e
    @pytest.mark.cli
    def test_daily_report_cli_workflow(self, project_root):
        """日次レポートCLIワークフロー"""
        cli_script = project_root / "src" / "cli" / "main.py"
        
        # CLI実行
        result = subprocess.run([
            "python", str(cli_script), 
            "daily-report", 
            "--output", "json",
            "--mock-data"
        ], capture_output=True, text=True)
        
        assert result.returncode == 0
        
        # JSON出力確認
        output_data = json.loads(result.stdout)
        assert "user_count" in output_data
        assert "license_count" in output_data
        assert output_data["status"] == "success"
    
    @pytest.mark.e2e
    @pytest.mark.cli
    def test_batch_user_export_cli_workflow(self, project_root):
        """ユーザー一括エクスポートCLIワークフロー"""
        cli_script = project_root / "src" / "cli" / "main.py"
        
        # CLI実行
        result = subprocess.run([
            "python", str(cli_script),
            "export-users",
            "--format", "csv",
            "--output", "/tmp/users.csv",
            "--mock-data"
        ], capture_output=True, text=True)
        
        assert result.returncode == 0
        
        # CSV出力確認
        output_file = Path("/tmp/users.csv")
        assert output_file.exists()
        assert output_file.stat().st_size > 0
```

### 3.4 パフォーマンステスト

```python
# Tests/performance/test_performance.py
"""パフォーマンステスト"""

import pytest
import time
import asyncio
from src.core.performance import PerformanceMonitor

class TestPerformance:
    """パフォーマンステスト"""
    
    @pytest.mark.performance
    @pytest.mark.slow
    async def test_bulk_user_processing_performance(self, mock_graph_client):
        """大量ユーザー処理パフォーマンステスト"""
        # 大量ユーザーデータのモック
        mock_users = [
            {"id": f"user{i}", "displayName": f"User {i}"}
            for i in range(10000)
        ]
        mock_graph_client.get_users.return_value = mock_users
        
        performance_monitor = PerformanceMonitor()
        
        start_time = time.time()
        
        # 処理実行
        result = await performance_monitor.process_bulk_users(mock_users)
        
        end_time = time.time()
        processing_time = end_time - start_time
        
        # パフォーマンス検証
        assert processing_time < 30.0  # 30秒以内
        assert result["processed_count"] == 10000
        assert result["errors"] == 0
    
    @pytest.mark.performance
    async def test_memory_usage_monitoring(self, mock_graph_client):
        """メモリ使用量監視テスト"""
        import psutil
        import os
        
        process = psutil.Process(os.getpid())
        initial_memory = process.memory_info().rss / 1024 / 1024  # MB
        
        # 処理実行
        performance_monitor = PerformanceMonitor()
        await performance_monitor.generate_large_report()
        
        final_memory = process.memory_info().rss / 1024 / 1024  # MB
        memory_increase = final_memory - initial_memory
        
        # メモリ増加量検証
        assert memory_increase < 100  # 100MB以内の増加
```

### 3.5 セキュリティテスト

```python
# Tests/security/test_security.py
"""セキュリティテスト"""

import pytest
from src.core.security import SecurityScanner
from src.core.exceptions import SecurityViolationError

class TestSecurity:
    """セキュリティテスト"""
    
    @pytest.mark.security
    def test_password_strength_validation(self):
        """パスワード強度検証テスト"""
        scanner = SecurityScanner()
        
        # 強いパスワード
        assert scanner.validate_password_strength("StrongP@ssw0rd123!")
        
        # 弱いパスワード
        assert not scanner.validate_password_strength("weak")
        assert not scanner.validate_password_strength("12345678")
        assert not scanner.validate_password_strength("password")
    
    @pytest.mark.security
    def test_certificate_validation(self):
        """証明書検証テスト"""
        scanner = SecurityScanner()
        
        # 有効期限切れ証明書の検出
        with pytest.raises(SecurityViolationError):
            scanner.validate_certificate("expired_cert.pfx")
        
        # 無効な証明書の検出
        with pytest.raises(SecurityViolationError):
            scanner.validate_certificate("invalid_cert.pfx")
    
    @pytest.mark.security
    async def test_api_rate_limiting(self, mock_graph_client):
        """API レート制限テスト"""
        scanner = SecurityScanner()
        
        # 大量リクエスト実行
        requests = []
        for i in range(1000):
            requests.append(scanner.check_api_rate_limit())
        
        results = await asyncio.gather(*requests, return_exceptions=True)
        
        # レート制限の検証
        rate_limited_count = sum(1 for r in results if isinstance(r, Exception))
        assert rate_limited_count > 0  # レート制限が発生すること
```

## 4. CI/CD統合

### 4.1 GitHub Actions設定

```yaml
# .github/workflows/python-tests.yml
name: Python Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: [3.9, 3.10, 3.11, 3.12]

    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Python ${{ matrix.python-version }}
      uses: actions/setup-python@v4
      with:
        python-version: ${{ matrix.python-version }}
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
        pip install -r Tests/requirements-test.txt
    
    - name: Run unit tests
      run: |
        pytest Tests/unit/ -v --cov=src --cov-report=xml
    
    - name: Run integration tests
      run: |
        pytest Tests/integration/ -v --cov=src --cov-append --cov-report=xml
      env:
        AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
        AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
        AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
    
    - name: Run security tests
      run: |
        pytest Tests/security/ -v
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.xml
        flags: unittests
        name: codecov-umbrella
```

### 4.2 テスト実行スクリプト

```python
# Tests/run_all_tests.py
"""全テスト実行スクリプト"""

import sys
import subprocess
import json
from pathlib import Path
from typing import List, Dict, Any

class TestRunner:
    """テスト実行管理"""
    
    def __init__(self):
        self.project_root = Path(__file__).parent.parent
        self.test_results = {}
    
    def run_unit_tests(self) -> Dict[str, Any]:
        """単体テスト実行"""
        print("🧪 単体テスト実行中...")
        result = subprocess.run([
            "pytest", "Tests/unit/", 
            "-v", "--tb=short",
            "--cov=src", "--cov-report=json"
        ], capture_output=True, text=True)
        
        return {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr
        }
    
    def run_integration_tests(self) -> Dict[str, Any]:
        """統合テスト実行"""
        print("🔗 統合テスト実行中...")
        result = subprocess.run([
            "pytest", "Tests/integration/", 
            "-v", "--tb=short",
            "-m", "not slow"
        ], capture_output=True, text=True)
        
        return {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr
        }
    
    def run_e2e_tests(self) -> Dict[str, Any]:
        """E2Eテスト実行"""
        print("🎯 E2Eテスト実行中...")
        result = subprocess.run([
            "pytest", "Tests/e2e/", 
            "-v", "--tb=short",
            "--maxfail=5"
        ], capture_output=True, text=True)
        
        return {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr
        }
    
    def run_performance_tests(self) -> Dict[str, Any]:
        """パフォーマンステスト実行"""
        print("⚡ パフォーマンステスト実行中...")
        result = subprocess.run([
            "pytest", "Tests/performance/", 
            "-v", "--tb=short"
        ], capture_output=True, text=True)
        
        return {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr
        }
    
    def run_security_tests(self) -> Dict[str, Any]:
        """セキュリティテスト実行"""
        print("🔒 セキュリティテスト実行中...")
        result = subprocess.run([
            "pytest", "Tests/security/", 
            "-v", "--tb=short"
        ], capture_output=True, text=True)
        
        return {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr
        }
    
    def generate_report(self) -> None:
        """テスト結果レポート生成"""
        print("📊 テスト結果レポート生成中...")
        
        # HTMLレポート生成
        subprocess.run([
            "pytest", "Tests/", 
            "--html=Tests/reports/test_report.html",
            "--self-contained-html"
        ])
        
        # カバレッジレポート生成
        subprocess.run([
            "coverage", "html", 
            "-d", "Tests/reports/coverage"
        ])
        
        print("✅ レポート生成完了")
        print(f"   HTML: {self.project_root}/Tests/reports/test_report.html")
        print(f"   Coverage: {self.project_root}/Tests/reports/coverage/index.html")
    
    def run_all_tests(self, test_types: List[str] = None) -> bool:
        """全テスト実行"""
        if test_types is None:
            test_types = ["unit", "integration", "e2e", "performance", "security"]
        
        all_passed = True
        
        for test_type in test_types:
            if test_type == "unit":
                result = self.run_unit_tests()
            elif test_type == "integration":
                result = self.run_integration_tests()
            elif test_type == "e2e":
                result = self.run_e2e_tests()
            elif test_type == "performance":
                result = self.run_performance_tests()
            elif test_type == "security":
                result = self.run_security_tests()
            else:
                continue
            
            self.test_results[test_type] = result
            
            if result["returncode"] != 0:
                all_passed = False
                print(f"❌ {test_type}テストが失敗しました")
                print(result["stderr"])
            else:
                print(f"✅ {test_type}テスト成功")
        
        # レポート生成
        self.generate_report()
        
        return all_passed

if __name__ == "__main__":
    runner = TestRunner()
    
    # コマンドライン引数解析
    test_types = sys.argv[1:] if len(sys.argv) > 1 else None
    
    success = runner.run_all_tests(test_types)
    sys.exit(0 if success else 1)
```

## 5. 品質保証プロセス

### 5.1 テスト実行フロー

```
1. 開発者ローカルテスト
   └── pytest Tests/unit/ -v

2. プルリクエスト時
   ├── 単体テスト (必須)
   ├── 統合テスト (必須)
   └── セキュリティテスト (必須)

3. メインブランチマージ後
   ├── 全テスト実行
   ├── パフォーマンステスト
   ├── E2Eテスト
   └── カバレッジレポート生成

4. リリース前
   ├── 完全テストスイート
   ├── セキュリティスキャン
   └── パフォーマンス検証
```

### 5.2 品質メトリクス

```python
# Tests/quality_metrics.py
"""品質メトリクス計算"""

class QualityMetrics:
    """品質メトリクス"""
    
    def __init__(self):
        self.metrics = {}
    
    def calculate_test_coverage(self) -> float:
        """テストカバレッジ計算"""
        # coverage.py を使用してカバレッジを計算
        pass
    
    def calculate_code_quality(self) -> Dict[str, Any]:
        """コード品質指標計算"""
        return {
            "complexity": self.calculate_complexity(),
            "maintainability": self.calculate_maintainability(),
            "reliability": self.calculate_reliability(),
            "security": self.calculate_security_score()
        }
    
    def generate_quality_report(self) -> None:
        """品質レポート生成"""
        pass
```

## 6. まとめ

このPythonテストアーキテクチャにより、以下を実現します：

### 6.1 実現する品質目標
- **テストカバレッジ**: 90%以上
- **テスト実行時間**: 単体テスト 5分以内、統合テスト 15分以内
- **CI/CD統合**: 自動テスト実行とレポート生成
- **クロスプラットフォーム**: Windows/Linux/macOS対応

### 6.2 移行戦略
1. **Phase 1**: 単体テストの完全移行
2. **Phase 2**: 統合テストの実装
3. **Phase 3**: E2Eテストの実装
4. **Phase 4**: CI/CD統合
5. **Phase 5**: パフォーマンス・セキュリティテスト

### 6.3 成功指標
- PowerShellテスト機能の100%カバー
- 自動化されたテスト実行
- 継続的品質監視
- 高速なフィードバックループ

このアーキテクチャにより、Microsoft 365管理ツールの品質を担保しながら、Python移行を成功させることができます。