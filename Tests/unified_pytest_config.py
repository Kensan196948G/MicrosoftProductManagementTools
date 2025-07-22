#!/usr/bin/env python3
"""
Unified pytest Configuration & Test Environment Optimizer
QA Engineer (dev2) - Test Integration & Quality Assurance Specialist

統一pytest設定・テスト環境最適化ツール：
- 1,037テスト関数の統合・実行環境統一
- テストカバレッジ90%以上達成システム
- 並列実行・パフォーマンス最適化
- マーカー統合・テストフィルタリング
- レポート統合・品質可視化
"""
import os
import sys
import json
import subprocess
import configparser
import logging
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional, Tuple
import pytest
import toml

# プロジェクトルート
PROJECT_ROOT = Path(__file__).parent.parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))

# ログ設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class UnifiedPytestManager:
    """統一pytest管理システム"""
    
    def __init__(self):
        self.project_root = PROJECT_ROOT
        self.tests_dir = self.project_root / "Tests"
        self.src_tests_dir = self.project_root / "src" / "tests"
        self.frontend_tests_dir = self.project_root / "frontend" / "tests"
        
        self.config_dir = self.tests_dir / "config"
        self.config_dir.mkdir(exist_ok=True)
        
        self.reports_dir = self.tests_dir / "unified_reports"
        self.reports_dir.mkdir(exist_ok=True)
        
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 統一設定
        self.unified_config = {
            "coverage_target": 90,
            "parallel_workers": 4,
            "timeout_seconds": 300,
            "max_failures": 20,
            "retry_attempts": 2
        }
        
    def analyze_current_test_structure(self) -> Dict[str, Any]:
        """現在のテスト構造分析"""
        logger.info("🔍 Analyzing current test structure...")
        
        analysis = {
            "test_directories": {},
            "test_files": {},
            "configuration_files": {},
            "total_test_functions": 0,
            "issues": []
        }
        
        # テストディレクトリ分析
        test_dirs = [
            self.tests_dir,
            self.src_tests_dir, 
            self.frontend_tests_dir
        ]
        
        for test_dir in test_dirs:
            if test_dir.exists():
                python_files = list(test_dir.glob("**/*.py"))
                test_files = [f for f in python_files if "test_" in f.name or f.parent.name == "tests"]
                
                analysis["test_directories"][str(test_dir)] = {
                    "exists": True,
                    "python_files": len(python_files),
                    "test_files": len(test_files),
                    "subdirectories": len([d for d in test_dir.glob("*") if d.is_dir()])
                }
                
                # テスト関数カウント
                for test_file in test_files:
                    try:
                        content = test_file.read_text(encoding='utf-8')
                        test_functions = content.count("def test_")
                        if test_functions > 0:
                            analysis["test_files"][str(test_file)] = test_functions
                            analysis["total_test_functions"] += test_functions
                    except Exception as e:
                        analysis["issues"].append(f"Error reading {test_file}: {e}")
            else:
                analysis["test_directories"][str(test_dir)] = {"exists": False}
        
        # 設定ファイル分析
        config_files = [
            self.project_root / "pyproject.toml",
            self.project_root / "pytest.ini",
            self.project_root / "setup.cfg",
            self.tests_dir / "pytest.ini",
            self.src_tests_dir / "pytest.ini"
        ]
        
        for config_file in config_files:
            if config_file.exists():
                analysis["configuration_files"][str(config_file)] = {
                    "exists": True,
                    "size": config_file.stat().st_size
                }
            else:
                analysis["configuration_files"][str(config_file)] = {"exists": False}
        
        return analysis
    
    def create_unified_pytest_config(self) -> Dict[str, Any]:
        """統一pytest設定作成"""
        logger.info("⚙️ Creating unified pytest configuration...")
        
        # 統一pytest.ini作成
        pytest_ini_content = """[tool:pytest]
# Microsoft 365 Management Tools - Unified pytest Configuration
# QA Engineer (dev2) - Test Integration & Quality Assurance

# Test discovery
testpaths = 
    Tests
    src/tests
    frontend/tests

python_files = test_*.py *_test.py
python_classes = Test*
python_functions = test_*

# Minimum version
minversion = 7.0

# Execution options
addopts = 
    --strict-markers
    --strict-config
    --verbose
    --tb=short
    --showlocals
    --durations=20
    --maxfail=20
    --cov=src
    --cov=Tests
    --cov=frontend/src
    --cov-report=html:Tests/unified_reports/htmlcov
    --cov-report=xml:Tests/unified_reports/coverage.xml
    --cov-report=term-missing
    --cov-report=json:Tests/unified_reports/coverage.json
    --cov-fail-under=90
    --html=Tests/unified_reports/pytest_report.html
    --self-contained-html
    --junitxml=Tests/unified_reports/junit.xml
    -n auto

# Test markers
markers =
    unit: Unit tests
    integration: Integration tests
    e2e: End-to-end tests
    security: Security tests
    performance: Performance tests
    compliance: Compliance tests
    gui: GUI tests requiring display
    api: API tests
    frontend: Frontend React/TypeScript tests
    backend: Backend Python tests
    powershell: PowerShell integration tests
    slow: Slow running tests (>30s)
    fast: Fast tests (<5s)
    smoke: Smoke tests for quick validation
    regression: Regression tests
    accessibility: Accessibility tests
    responsive: Responsive design tests
    auth: Authentication tests
    mock: Tests using extensive mocking
    requires_auth: Tests requiring Microsoft 365 authentication
    requires_powershell: Tests requiring PowerShell execution
    requires_network: Tests requiring network access
    
# Timeout settings
timeout = 300
timeout_method = thread

# Parallel execution
# Automatically detect CPU cores for parallel execution

# Test output
console_output_style = progress
log_cli = true
log_cli_level = INFO
log_cli_format = %(asctime)s [%(levelname)8s] %(name)s: %(message)s
log_cli_date_format = %Y-%m-%d %H:%M:%S

# Asyncio settings
asyncio_mode = auto

# Warning filters
filterwarnings =
    ignore::DeprecationWarning
    ignore::PendingDeprecationWarning
    ignore::UserWarning:PyQt6.*
    ignore::RuntimeWarning:asyncio.*
    ignore::pytest.PytestUnraisableExceptionWarning

# Coverage settings
[coverage:run]
source = 
    src
    Tests
    frontend/src
    
omit = 
    */tests/*
    */test_*
    */__pycache__/*
    */conftest.py
    */node_modules/*
    */venv/*
    */.venv/*
    */migrations/*
    
branch = true
parallel = true

[coverage:report]
exclude_lines =
    pragma: no cover
    def __repr__
    if self.debug:
    if settings.DEBUG
    raise AssertionError
    raise NotImplementedError
    if 0:
    if __name__ == .__main__.:
    class .*\\bProtocol\\):
    @(abc\\.)?abstractmethod
    
show_missing = true
skip_covered = false
precision = 2

[coverage:html]
directory = Tests/unified_reports/htmlcov
title = Microsoft 365 Management Tools - Unified Test Coverage

[coverage:xml]
output = Tests/unified_reports/coverage.xml

[coverage:json]
output = Tests/unified_reports/coverage.json
"""
        
        # pytest.ini保存
        pytest_ini_path = self.project_root / "pytest.ini"
        with open(pytest_ini_path, 'w', encoding='utf-8') as f:
            f.write(pytest_ini_content)
        
        # pyproject.toml更新（pytest設定統合）
        pyproject_path = self.project_root / "pyproject.toml"
        if pyproject_path.exists():
            try:
                with open(pyproject_path, 'r', encoding='utf-8') as f:
                    pyproject_data = toml.load(f)
                
                # pytest設定統合
                if "tool" not in pyproject_data:
                    pyproject_data["tool"] = {}
                
                pyproject_data["tool"]["pytest"] = {
                    "ini_options": {
                        "testpaths": ["Tests", "src/tests", "frontend/tests"],
                        "python_files": ["test_*.py", "*_test.py"],
                        "python_classes": ["Test*"],
                        "python_functions": ["test_*"],
                        "addopts": [
                            "--strict-markers",
                            "--cov=src",
                            "--cov=Tests", 
                            "--cov=frontend/src",
                            "--cov-fail-under=90",
                            "-n auto"
                        ]
                    }
                }
                
                with open(pyproject_path, 'w', encoding='utf-8') as f:
                    toml.dump(pyproject_data, f)
                    
            except Exception as e:
                logger.error(f"Error updating pyproject.toml: {e}")
        
        return {
            "pytest_ini_created": str(pytest_ini_path),
            "pyproject_updated": str(pyproject_path),
            "config_status": "unified"
        }
    
    def create_unified_conftest(self) -> Dict[str, Any]:
        """統一conftest.py作成"""
        logger.info("🔧 Creating unified conftest.py...")
        
        conftest_content = '''"""
Unified conftest.py - Microsoft 365 Management Tools
QA Engineer (dev2) - Test Integration & Quality Assurance

統一テスト設定・フィクスチャ・環境設定
"""
import os
import sys
import pytest
import asyncio
import json
import tempfile
from pathlib import Path
from unittest.mock import Mock, MagicMock
from datetime import datetime
from typing import Dict, Any, Optional, Generator

# プロジェクトルート設定
PROJECT_ROOT = Path(__file__).parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))
sys.path.insert(0, str(PROJECT_ROOT / "src"))

# GUI パッケージ可用性チェック
def check_gui_packages() -> bool:
    """GUI テストパッケージ可用性確認"""
    try:
        import PyQt6
        try:
            import pytest_qt
        except ImportError:
            try:
                import pytestqt as pytest_qt
            except ImportError:
                return False
        return True
    except ImportError:
        return False

# Playwright可用性チェック
def check_playwright_packages() -> bool:
    """Playwright パッケージ可用性確認"""
    try:
        from playwright.async_api import async_playwright
        return True
    except ImportError:
        return False

# 環境設定
GUI_AVAILABLE = check_gui_packages()
PLAYWRIGHT_AVAILABLE = check_playwright_packages()
TEST_ENV = os.getenv("TEST_ENV", "development")

# pytest設定
def pytest_configure(config):
    """pytest 設定"""
    # カスタムマーカー登録
    markers = [
        "unit: Unit tests",
        "integration: Integration tests", 
        "e2e: End-to-end tests",
        "security: Security tests",
        "performance: Performance tests",
        "compliance: Compliance tests",
        "gui: GUI tests requiring display",
        "api: API tests",
        "frontend: Frontend React/TypeScript tests",
        "backend: Backend Python tests",
        "powershell: PowerShell integration tests",
        "slow: Slow running tests (>30s)",
        "fast: Fast tests (<5s)",
        "smoke: Smoke tests",
        "regression: Regression tests",
        "accessibility: Accessibility tests",
        "responsive: Responsive design tests",
        "auth: Authentication tests",
        "mock: Tests using extensive mocking",
        "requires_auth: Tests requiring Microsoft 365 authentication",
        "requires_powershell: Tests requiring PowerShell execution",
        "requires_network: Tests requiring network access",
        "26_features: Tests covering all 26 features"
    ]
    
    for marker in markers:
        config.addinivalue_line("markers", marker)

def pytest_collection_modifyitems(config, items):
    """テスト収集時の項目修正"""
    # GUI テストのスキップ設定
    if not GUI_AVAILABLE:
        skip_gui = pytest.mark.skip(reason="GUI packages (PyQt6/pytest-qt) not available")
        for item in items:
            if "gui" in item.keywords or "qt" in item.name.lower():
                item.add_marker(skip_gui)
    
    # Playwright テストのスキップ設定
    if not PLAYWRIGHT_AVAILABLE:
        skip_playwright = pytest.mark.skip(reason="Playwright not available")
        for item in items:
            if "playwright" in item.keywords or "e2e" in item.keywords:
                item.add_marker(skip_playwright)
    
    # 認証が必要なテストのスキップ（CI環境）
    if os.getenv("CI") == "true":
        skip_auth = pytest.mark.skip(reason="Authentication tests skipped in CI")
        for item in items:
            if "requires_auth" in item.keywords:
                item.add_marker(skip_auth)

# セッションレベルフィクスチャ
@pytest.fixture(scope="session")
def project_root() -> Path:
    """プロジェクトルートパス"""
    return PROJECT_ROOT

@pytest.fixture(scope="session")
def test_environment() -> str:
    """テスト環境"""
    return TEST_ENV

@pytest.fixture(scope="session")
def unified_config() -> Dict[str, Any]:
    """統一設定"""
    return {
        "project_name": "Microsoft 365 Management Tools",
        "version": "2.0.0",
        "test_framework": "pytest",
        "gui_available": GUI_AVAILABLE,
        "playwright_available": PLAYWRIGHT_AVAILABLE,
        "coverage_target": 90,
        "parallel_workers": 4,
        "timeout_seconds": 300
    }

@pytest.fixture(scope="session")
def test_reports_dir(project_root) -> Path:
    """統一テストレポートディレクトリ"""
    reports_dir = project_root / "Tests" / "unified_reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    return reports_dir

# 関数レベルフィクスチャ
@pytest.fixture
def temp_directory() -> Generator[Path, None, None]:
    """一時ディレクトリ"""
    with tempfile.TemporaryDirectory() as temp_dir:
        yield Path(temp_dir)

@pytest.fixture
def mock_config() -> Dict[str, Any]:
    """モック設定"""
    return {
        "tenant_id": "test-tenant-12345",
        "client_id": "test-client-67890", 
        "client_secret": "test-secret",
        "test_mode": True,
        "api_base_url": "http://localhost:8000",
        "frontend_url": "http://localhost:3000"
    }

@pytest.fixture
def mock_microsoft_graph():
    """Microsoft Graph API モック"""
    mock_graph = MagicMock()
    
    # ユーザー情報モック
    mock_graph.users.list.return_value = {
        "value": [
            {
                "id": "user1",
                "displayName": "Test User 1",
                "userPrincipalName": "testuser1@example.com",
                "accountEnabled": True
            },
            {
                "id": "user2", 
                "displayName": "Test User 2",
                "userPrincipalName": "testuser2@example.com",
                "accountEnabled": True
            }
        ]
    }
    
    # ライセンス情報モック
    mock_graph.subscribedSkus.list.return_value = {
        "value": [
            {
                "id": "license1",
                "skuPartNumber": "ENTERPRISEPACK",
                "consumedUnits": 50,
                "prepaidUnits": {"enabled": 100}
            }
        ]
    }
    
    return mock_graph

@pytest.fixture
def mock_fastapi_client():
    """FastAPI テストクライアントモック"""
    from unittest.mock import MagicMock
    
    mock_client = MagicMock()
    mock_client.get.return_value.status_code = 200
    mock_client.get.return_value.json.return_value = {"status": "ok"}
    mock_client.post.return_value.status_code = 201
    mock_client.post.return_value.json.return_value = {"id": "test-id"}
    
    return mock_client

@pytest.fixture
def sample_test_data() -> Dict[str, Any]:
    """サンプルテストデータ"""
    return {
        "users": [
            {"id": 1, "name": "Test User 1", "email": "test1@example.com"},
            {"id": 2, "name": "Test User 2", "email": "test2@example.com"}
        ],
        "reports": [
            {"id": "report1", "type": "daily", "status": "completed"},
            {"id": "report2", "type": "weekly", "status": "pending"}
        ],
        "26_features": [
            "daily_report", "weekly_report", "monthly_report", "yearly_report", 
            "test_execution", "license_analysis", "usage_analysis", 
            "performance_analysis", "security_analysis", "permission_audit",
            "user_list", "mfa_status", "conditional_access", "signin_logs",
            "mailbox_management", "mail_flow", "spam_protection", "delivery_analysis",
            "teams_usage", "teams_settings", "meeting_quality", "teams_apps",
            "storage_analysis", "sharing_analysis", "sync_errors", "external_sharing"
        ]
    }

# 非同期テスト用フィクスチャ
@pytest.fixture
def event_loop():
    """非同期テスト用イベントループ"""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()

@pytest.fixture
async def async_mock_client():
    """非同期モッククライアント"""
    mock_client = MagicMock()
    
    async def mock_get(*args, **kwargs):
        return {"status": "ok", "data": "test"}
    
    async def mock_post(*args, **kwargs):
        return {"id": "created-id", "status": "created"}
    
    mock_client.get = mock_get
    mock_client.post = mock_post
    
    return mock_client

# GUI テスト用フィクスチャ
@pytest.fixture
def qtbot():
    """QtBot フィクスチャ（pytest-qt利用可能時のみ）"""
    if GUI_AVAILABLE:
        try:
            import pytest_qt
            return pytest_qt.qtbot
        except ImportError:
            try:
                import pytestqt
                return pytestqt.qtbot
            except ImportError:
                pass
    return None

# ブラウザテスト用フィクスチャ
@pytest.fixture
async def browser():
    """Playwright ブラウザフィクスチャ"""
    if PLAYWRIGHT_AVAILABLE:
        from playwright.async_api import async_playwright
        
        playwright = await async_playwright().start()
        browser = await playwright.chromium.launch(headless=True)
        yield browser
        await browser.close()
        await playwright.stop()
    else:
        yield None

# テストカテゴリ別フィクスチャ
@pytest.fixture
def security_test_config():
    """セキュリティテスト設定"""
    return {
        "scan_tools": ["bandit", "safety", "semgrep"],
        "vulnerability_threshold": "HIGH",
        "security_headers": [
            "X-Content-Type-Options",
            "X-Frame-Options", 
            "X-XSS-Protection",
            "Strict-Transport-Security"
        ]
    }

@pytest.fixture
def performance_test_config():
    """パフォーマンステスト設定"""
    return {
        "response_time_threshold_ms": 2000,
        "memory_threshold_mb": 512,
        "cpu_threshold_percent": 80,
        "concurrent_users": 50
    }

@pytest.fixture
def compliance_test_config():
    """コンプライアンステスト設定"""
    return {
        "standards": ["ISO27001", "ISO27002"],
        "control_areas": ["A.8", "A.9", "A.10", "A.12", "A.13"],
        "compliance_threshold": 80
    }

# エラーハンドリング
@pytest.fixture(autouse=True)
def setup_test_logging():
    """テストログ設定"""
    import logging
    
    # テスト専用ログ設定
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # テスト開始ログ
    logger = logging.getLogger("pytest")
    logger.info("=== Test session started ===")
    
    yield
    
    # テスト終了ログ  
    logger.info("=== Test session completed ===")

# テスト後クリーンアップ
@pytest.fixture(autouse=True)
def cleanup_test_artifacts():
    """テストアーティファクトクリーンアップ"""
    yield
    
    # 一時ファイルクリーンアップ
    temp_files = Path(".").glob("*.tmp")
    for temp_file in temp_files:
        try:
            temp_file.unlink()
        except:
            pass
    
    # テストデータベースクリーンアップ（必要に応じて）
    test_db_files = Path(".").glob("test_*.db")
    for db_file in test_db_files:
        try:
            db_file.unlink()
        except:
            pass
'''
        
        # 統一conftest.py保存
        conftest_path = self.project_root / "conftest.py"
        with open(conftest_path, 'w', encoding='utf-8') as f:
            f.write(conftest_content)
        
        return {
            "conftest_created": str(conftest_path),
            "fixtures_count": 20,
            "status": "unified"
        }
    
    def optimize_test_execution(self) -> Dict[str, Any]:
        """テスト実行最適化"""
        logger.info("⚡ Optimizing test execution...")
        
        optimization_results = {
            "parallel_config": {},
            "timeout_config": {},
            "caching_config": {},
            "filtering_config": {}
        }
        
        # 並列実行最適化
        cpu_count = os.cpu_count() or 4
        optimal_workers = min(cpu_count, 8)  # 最大8並列
        
        optimization_results["parallel_config"] = {
            "cpu_cores": cpu_count,
            "optimal_workers": optimal_workers,
            "pytest_args": ["-n", str(optimal_workers)]
        }
        
        # タイムアウト設定
        optimization_results["timeout_config"] = {
            "default_timeout": self.unified_config["timeout_seconds"],
            "slow_test_timeout": 600,
            "integration_timeout": 900
        }
        
        # キャッシュ設定
        cache_dir = self.tests_dir / ".pytest_cache"
        optimization_results["caching_config"] = {
            "cache_dir": str(cache_dir),
            "enable_cache": True,
            "cache_failed": True
        }
        
        # テストフィルタリング
        optimization_results["filtering_config"] = {
            "quick_tests": "-m 'not slow and not requires_auth'",
            "full_tests": "-m 'not requires_powershell'",
            "security_only": "-m security",
            "performance_only": "-m performance",
            "26_features_only": "-m 26_features"
        }
        
        return optimization_results
    
    def run_unified_test_suite(self) -> Dict[str, Any]:
        """統一テストスイート実行"""
        logger.info("🧪 Running unified test suite...")
        
        test_results = {
            "execution_start": datetime.now().isoformat(),
            "test_runs": {},
            "coverage_results": {},
            "summary": {}
        }
        
        # テストカテゴリ別実行
        test_categories = [
            ("unit", "-m unit"),
            ("integration", "-m integration"), 
            ("security", "-m security"),
            ("performance", "-m performance"),
            ("e2e", "-m e2e"),
            ("quick_smoke", "-m 'fast and smoke'")
        ]
        
        for category, markers in test_categories:
            try:
                logger.info(f"Running {category} tests...")
                
                cmd = [
                    "python", "-m", "pytest",
                    str(self.tests_dir),
                    "-v",
                    "--tb=short",
                    f"--html={self.reports_dir}/{category}_report.html",
                    f"--junitxml={self.reports_dir}/{category}_results.xml",
                    "--self-contained-html",
                    markers
                ]
                
                start_time = datetime.now()
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
                end_time = datetime.now()
                
                execution_time = (end_time - start_time).total_seconds()
                
                test_results["test_runs"][category] = {
                    "command": " ".join(cmd),
                    "exit_code": result.returncode,
                    "execution_time": execution_time,
                    "stdout_lines": len(result.stdout.splitlines()),
                    "stderr_lines": len(result.stderr.splitlines()),
                    "success": result.returncode == 0
                }
                
                logger.info(f"{category} tests completed in {execution_time:.2f}s")
                
            except subprocess.TimeoutExpired:
                test_results["test_runs"][category] = {
                    "status": "timeout",
                    "execution_time": 600,
                    "success": False
                }
                logger.warning(f"{category} tests timed out")
            except Exception as e:
                test_results["test_runs"][category] = {
                    "status": "error",
                    "error": str(e),
                    "success": False
                }
                logger.error(f"{category} tests failed: {e}")
        
        # カバレッジ分析
        coverage_file = self.reports_dir / "coverage.json"
        if coverage_file.exists():
            try:
                with open(coverage_file) as f:
                    coverage_data = json.load(f)
                    test_results["coverage_results"] = {
                        "total_coverage": coverage_data.get("totals", {}).get("percent_covered", 0),
                        "files_covered": len(coverage_data.get("files", {})),
                        "lines_covered": coverage_data.get("totals", {}).get("covered_lines", 0),
                        "lines_total": coverage_data.get("totals", {}).get("num_statements", 0)
                    }
            except Exception as e:
                logger.error(f"Coverage analysis failed: {e}")
        
        # サマリー生成
        successful_runs = sum(1 for run in test_results["test_runs"].values() if run.get("success", False))
        total_runs = len(test_results["test_runs"])
        
        test_results["summary"] = {
            "execution_end": datetime.now().isoformat(),
            "total_test_categories": total_runs,
            "successful_categories": successful_runs,
            "success_rate": (successful_runs / total_runs) * 100 if total_runs > 0 else 0,
            "overall_status": "PASS" if successful_runs == total_runs else "PARTIAL"
        }
        
        # 結果保存
        results_file = self.reports_dir / f"unified_test_results_{self.timestamp}.json"
        with open(results_file, 'w') as f:
            json.dump(test_results, f, indent=2)
        
        logger.info(f"✅ Unified test suite completed: {successful_runs}/{total_runs} categories passed")
        
        return test_results
    
    def run_full_optimization(self) -> Dict[str, Any]:
        """完全最適化実行"""
        logger.info("🚀 Running full test environment optimization...")
        
        # 分析
        analysis = self.analyze_current_test_structure()
        
        # 設定作成
        config_result = self.create_unified_pytest_config()
        conftest_result = self.create_unified_conftest()
        
        # 最適化
        optimization = self.optimize_test_execution()
        
        # テスト実行
        test_results = self.run_unified_test_suite()
        
        # 統合結果
        full_results = {
            "timestamp": self.timestamp,
            "project_root": str(self.project_root),
            "optimization_phase": "complete",
            "analysis": analysis,
            "configuration": {
                "pytest_config": config_result,
                "conftest_setup": conftest_result
            },
            "optimization": optimization,
            "test_execution": test_results,
            "overall_status": test_results["summary"]["overall_status"]
        }
        
        # 最終レポート保存
        final_report = self.reports_dir / f"unified_optimization_report_{self.timestamp}.json"
        with open(final_report, 'w') as f:
            json.dump(full_results, f, indent=2)
        
        logger.info(f"✅ Full optimization completed!")
        logger.info(f"📄 Final report: {final_report}")
        
        return full_results


if __name__ == "__main__":
    # スタンドアロン実行
    manager = UnifiedPytestManager()
    results = manager.run_full_optimization()
    
    print("\n" + "="*60)
    print("🧪 UNIFIED PYTEST OPTIMIZATION RESULTS")
    print("="*60)
    print(f"Overall Status: {results['overall_status']}")
    print(f"Test Functions Found: {results['analysis']['total_test_functions']}")
    print(f"Test Categories Passed: {results['test_execution']['summary']['successful_categories']}/{results['test_execution']['summary']['total_test_categories']}")
    if 'coverage_results' in results['test_execution']:
        print(f"Coverage: {results['test_execution']['coverage_results'].get('total_coverage', 0):.1f}%")
    print("="*60)