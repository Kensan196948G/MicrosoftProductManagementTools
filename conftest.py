"""
Microsoft 365管理ツール - pytest 共通設定・フィクスチャ定義
Dev1 - Test/QA Developer による基盤構築

全テストスイートで使用される共通設定、フィクスチャ、ヘルパー関数を定義
"""
import os
import sys
import json
import tempfile
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional, Union
from unittest.mock import MagicMock, patch
import asyncio
from datetime import datetime, timedelta

import pytest
import pandas as pd
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import QTimer
import requests_mock
import vcrpy

# プロジェクトルートをPythonパスに追加
PROJECT_ROOT = Path(__file__).parent.absolute()
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

# テスト用ディレクトリ定義
TEST_DIR = PROJECT_ROOT / "tests"
TEST_DATA_DIR = TEST_DIR / "data"
TEST_LOGS_DIR = TEST_DIR / "logs"
TEST_REPORTS_DIR = TEST_DIR / "reports"
TEST_TEMP_DIR = TEST_DIR / "temp"

# 必要なディレクトリを作成
for dir_path in [TEST_DATA_DIR, TEST_LOGS_DIR, TEST_REPORTS_DIR, TEST_TEMP_DIR]:
    dir_path.mkdir(parents=True, exist_ok=True)


# =============================================================================
# セッション開始時の設定
# =============================================================================
def pytest_sessionstart(session):
    """テストセッション開始時の初期化処理"""
    print(f"\n{'='*80}")
    print("Microsoft 365管理ツール - pytest テストセッション開始")
    print(f"テスト開始時刻: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"プロジェクトルート: {PROJECT_ROOT}")
    print(f"{'='*80}\n")
    
    # テスト環境の検証
    verify_test_environment()


def pytest_sessionfinish(session, exitstatus):
    """テストセッション終了時の処理"""
    print(f"\n{'='*80}")
    print("Microsoft 365管理ツール - pytest テストセッション終了")
    print(f"テスト終了時刻: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"終了ステータス: {exitstatus}")
    print(f"{'='*80}\n")


def verify_test_environment():
    """テスト環境の検証"""
    # 必要なモジュールの確認
    required_modules = ["PyQt6", "msal", "pandas", "requests", "jinja2"]
    missing_modules = []
    
    for module in required_modules:
        try:
            __import__(module)
        except ImportError:
            missing_modules.append(module)
    
    if missing_modules:
        pytest.exit(f"必須モジュールが不足しています: {', '.join(missing_modules)}")


# =============================================================================
# 共通フィクスチャ
# =============================================================================
@pytest.fixture(scope="session")
def project_root():
    """プロジェクトルートパスを提供"""
    return PROJECT_ROOT


@pytest.fixture(scope="session")
def test_config():
    """テスト用設定データを提供"""
    return {
        "tenant_id": "test-tenant-12345",
        "client_id": "test-client-67890",
        "client_secret": "test-secret-abcdef",
        "authority": "https://login.microsoftonline.com/test-tenant-12345",
        "scopes": ["https://graph.microsoft.com/.default"],
        "test_timeout": 30,
        "mock_api": True,
        "test_user_count": 100,
        "test_license_types": ["Office 365 E3", "Office 365 E5", "Microsoft 365 E3"],
    }


@pytest.fixture(scope="function")
def temp_dir():
    """テスト用一時ディレクトリを提供"""
    with tempfile.TemporaryDirectory(dir=TEST_TEMP_DIR) as temp_dir:
        yield Path(temp_dir)


@pytest.fixture(scope="function")
def mock_config_file(temp_dir, test_config):
    """テスト用設定ファイルを作成"""
    config_file = temp_dir / "test_appsettings.json"
    config_data = {
        "Authentication": {
            "TenantId": test_config["tenant_id"],
            "ClientId": test_config["client_id"],
            "ClientSecret": test_config["client_secret"],
            "Authority": test_config["authority"]
        },
        "API": {
            "GraphEndpoint": "https://graph.microsoft.com/v1.0",
            "Timeout": test_config["test_timeout"]
        },
        "Testing": {
            "MockAPI": test_config["mock_api"],
            "TestUserCount": test_config["test_user_count"]
        }
    }
    
    with open(config_file, "w", encoding="utf-8") as f:
        json.dump(config_data, f, indent=2, ensure_ascii=False)
    
    return config_file


# =============================================================================
# Microsoft Graph API モックフィクスチャ
# =============================================================================
@pytest.fixture(scope="function")
def mock_graph_client():
    """Microsoft Graph APIクライアントのモックを提供"""
    with patch("src.api.graph.client.GraphClient") as mock_client:
        mock_instance = MagicMock()
        mock_client.return_value = mock_instance
        
        # 基本的なAPIレスポンスをモック
        mock_instance.get_users.return_value = generate_mock_users(50)
        mock_instance.get_licenses.return_value = generate_mock_licenses()
        mock_instance.get_usage_reports.return_value = generate_mock_usage_data()
        
        yield mock_instance


@pytest.fixture(scope="function")
def requests_mock_fixture():
    """HTTP リクエストモックを提供"""
    with requests_mock.Mocker() as m:
        # Microsoft Graph API エンドポイントのモック
        m.get(
            "https://graph.microsoft.com/v1.0/users",
            json={"value": generate_mock_users(10)}
        )
        m.get(
            "https://graph.microsoft.com/v1.0/subscribedSkus",
            json={"value": generate_mock_licenses()}
        )
        yield m


@pytest.fixture(scope="function")
def vcr_cassette():
    """VCR カセットを使用したHTTPレコーディング"""
    cassette_dir = TEST_DATA_DIR / "vcr_cassettes"
    cassette_dir.mkdir(exist_ok=True)
    
    return vcrpy.VCR(
        cassette_library_dir=str(cassette_dir),
        record_mode="once",
        match_on=["method", "scheme", "host", "port", "path", "query"],
        filter_headers=["authorization", "x-ms-client-request-id"],
    )


# =============================================================================
# GUI テスト用フィクスチャ（pytest-qt）
# =============================================================================
@pytest.fixture(scope="session")
def qapp():
    """QApplicationインスタンスを提供（セッション共有）"""
    app = QApplication.instance()
    if app is None:
        app = QApplication([])
    yield app
    # app.quit() # セッション終了時に自動クローズ


@pytest.fixture(scope="function")
def qtbot(qapp):
    """pytest-qt の qtbot フィクスチャをラップ"""
    from pytestqt.qtbot import QtBot
    bot = QtBot(qapp)
    yield bot


@pytest.fixture(scope="function")
def mock_main_window(qtbot):
    """メインウィンドウのモックを提供"""
    from src.gui.main_window import MainWindow
    
    with patch("src.gui.main_window.MainWindow") as mock_window:
        mock_instance = MagicMock(spec=MainWindow)
        mock_window.return_value = mock_instance
        yield mock_instance


# =============================================================================
# PowerShell互換性テスト用フィクスチャ
# =============================================================================
@pytest.fixture(scope="function")
def powershell_runner():
    """PowerShellスクリプト実行用ヘルパー"""
    class PowerShellRunner:
        def __init__(self):
            self.scripts_dir = PROJECT_ROOT / "TestScripts"
            self.timeout = 120
        
        def run_script(self, script_name: str, args: List[str] = None) -> Dict[str, Any]:
            """PowerShellスクリプトを実行"""
            script_path = self.scripts_dir / script_name
            if not script_path.exists():
                raise FileNotFoundError(f"スクリプトが見つかりません: {script_path}")
            
            cmd = ["pwsh", "-File", str(script_path)]
            if args:
                cmd.extend(args)
            
            try:
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=self.timeout,
                    cwd=str(PROJECT_ROOT)
                )
                
                return {
                    "returncode": result.returncode,
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                    "success": result.returncode == 0
                }
            except subprocess.TimeoutExpired:
                return {
                    "returncode": -1,
                    "stdout": "",
                    "stderr": f"スクリプト実行がタイムアウトしました ({self.timeout}秒)",
                    "success": False
                }
            except Exception as e:
                return {
                    "returncode": -1,
                    "stdout": "",
                    "stderr": f"スクリプト実行エラー: {str(e)}",
                    "success": False
                }
    
    return PowerShellRunner()


@pytest.fixture(scope="function")
def compatibility_checker():
    """Python版とPowerShell版の出力互換性チェッカー"""
    class CompatibilityChecker:
        def compare_csv_outputs(self, python_csv: Path, powershell_csv: Path) -> Dict[str, Any]:
            """CSV出力の比較"""
            try:
                py_df = pd.read_csv(python_csv, encoding="utf-8-sig")
                ps_df = pd.read_csv(powershell_csv, encoding="utf-8-sig")
                
                return {
                    "columns_match": list(py_df.columns) == list(ps_df.columns),
                    "row_count_match": len(py_df) == len(ps_df),
                    "data_types_match": py_df.dtypes.equals(ps_df.dtypes),
                    "python_shape": py_df.shape,
                    "powershell_shape": ps_df.shape,
                    "column_diff": {
                        "python_only": set(py_df.columns) - set(ps_df.columns),
                        "powershell_only": set(ps_df.columns) - set(py_df.columns)
                    }
                }
            except Exception as e:
                return {"error": str(e), "success": False}
        
        def compare_html_structure(self, python_html: Path, powershell_html: Path) -> Dict[str, Any]:
            """HTML構造の比較（基本的なタグ構造のみ）"""
            try:
                with open(python_html, "r", encoding="utf-8") as f:
                    py_content = f.read()
                with open(powershell_html, "r", encoding="utf-8") as f:
                    ps_content = f.read()
                
                # 基本的な構造要素の存在確認
                common_tags = ["<html", "<head", "<body", "<table", "<tr", "<td"]
                py_tags = {tag: tag in py_content for tag in common_tags}
                ps_tags = {tag: tag in ps_content for tag in common_tags}
                
                return {
                    "basic_structure_match": py_tags == ps_tags,
                    "python_tags": py_tags,
                    "powershell_tags": ps_tags,
                    "length_diff": abs(len(py_content) - len(ps_content))
                }
            except Exception as e:
                return {"error": str(e), "success": False}
    
    return CompatibilityChecker()


# =============================================================================
# テストデータ生成ヘルパー
# =============================================================================
def generate_mock_users(count: int = 50) -> List[Dict[str, Any]]:
    """モックユーザーデータを生成"""
    users = []
    for i in range(count):
        users.append({
            "id": f"user-{i:03d}",
            "displayName": f"テストユーザー {i:03d}",
            "userPrincipalName": f"testuser{i:03d}@contoso.com",
            "mail": f"testuser{i:03d}@contoso.com",
            "department": "IT部門" if i % 3 == 0 else "営業部" if i % 3 == 1 else "管理部",
            "jobTitle": "Manager" if i % 5 == 0 else "Member",
            "accountEnabled": i % 10 != 0,  # 10%は無効化
            "createdDateTime": (datetime.now() - timedelta(days=i*10)).isoformat(),
            "lastSignInDateTime": (datetime.now() - timedelta(hours=i)).isoformat() if i % 20 != 0 else None,
            "assignedLicenses": [
                {"skuId": "license-sku-001"} if i % 2 == 0 else {"skuId": "license-sku-002"}
            ]
        })
    return users


def generate_mock_licenses() -> List[Dict[str, Any]]:
    """モックライセンスデータを生成"""
    return [
        {
            "skuId": "license-sku-001",
            "skuPartNumber": "ENTERPRISEPACK",
            "capabilityStatus": "Enabled",
            "consumedUnits": 45,
            "prepaidUnits": {"enabled": 50, "suspended": 0, "warning": 0}
        },
        {
            "skuId": "license-sku-002", 
            "skuPartNumber": "ENTERPRISEPREMIUM",
            "capabilityStatus": "Enabled",
            "consumedUnits": 23,
            "prepaidUnits": {"enabled": 30, "suspended": 0, "warning": 0}
        }
    ]


def generate_mock_usage_data() -> Dict[str, Any]:
    """モック使用状況データを生成"""
    return {
        "reportRefreshDate": datetime.now().isoformat(),
        "value": [
            {
                "userPrincipalName": f"testuser{i:03d}@contoso.com",
                "lastActivityDate": (datetime.now() - timedelta(days=i)).isoformat(),
                "teamsUsage": {"meetingCount": i * 2, "chatMessageCount": i * 10},
                "oneDriveUsage": {"storageUsedInBytes": i * 1024 * 1024 * 100},
                "exchangeUsage": {"mailboxStorageUsedInBytes": i * 1024 * 1024 * 50}
            }
            for i in range(20)
        ]
    }


# =============================================================================
# カスタムマーカー処理
# =============================================================================
def pytest_configure(config):
    """pytest設定の追加処理"""
    # カスタムマーカーの説明を動的に追加
    markers = {
        "unit": "ユニットテスト - 単一機能の単体テスト",
        "integration": "統合テスト - 複数コンポーネント連携テスト", 
        "compatibility": "互換性テスト - PowerShell版との出力互換性テスト",
        "gui": "GUIテスト - PyQt6コンポーネントテスト",
        "api": "APIテスト - Microsoft Graph API統合テスト",
        "slow": "低速テスト - 実行時間が長いテスト",
        "requires_auth": "認証必須テスト - Microsoft 365認証が必要",
        "requires_powershell": "PowerShell必須テスト - PowerShell実行が必要"
    }
    
    for marker, description in markers.items():
        config.addinivalue_line("markers", f"{marker}: {description}")


def pytest_collection_modifyitems(config, items):
    """テスト収集後の項目修正"""
    # CI環境では遅いテストをスキップ
    if config.getoption("--ci", default=False):
        skip_slow = pytest.mark.skip(reason="CI環境では低速テストをスキップ")
        for item in items:
            if "slow" in item.keywords:
                item.add_marker(skip_slow)
    
    # 認証が必要なテストの処理
    if not config.getoption("--auth", default=False):
        skip_auth = pytest.mark.skip(reason="認証テストは --auth オプションで有効化")
        for item in items:
            if "requires_auth" in item.keywords:
                item.add_marker(skip_auth)


def pytest_addoption(parser):
    """カスタムコマンドラインオプションの追加"""
    parser.addoption(
        "--auth", action="store_true", default=False,
        help="認証が必要なテストを実行"
    )
    parser.addoption(
        "--ci", action="store_true", default=False,
        help="CI環境での実行（低速テストをスキップ）"
    )
    parser.addoption(
        "--powershell", action="store_true", default=False,
        help="PowerShell互換性テストを実行"
    )


# =============================================================================
# 非同期テスト用フィクスチャ
# =============================================================================
@pytest.fixture(scope="function")
def event_loop():
    """非同期テスト用のイベントループ"""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()