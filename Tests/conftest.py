"""pytest設定とグローバルフィクスチャ"""

import pytest
import asyncio
import sys
import os
import json
from pathlib import Path
from unittest.mock import Mock, patch
from typing import Generator, Dict, Any
import logging
import tempfile
import shutil

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

@pytest.fixture(scope="session")
def test_config():
    """テスト用設定"""
    return {
        "azure": {
            "client_id": "test_client_id",
            "client_secret": "test_client_secret", 
            "tenant_id": "test_tenant_id",
            "certificate_path": "test_cert.pfx",
            "certificate_password": "test_password"
        },
        "logging": {
            "level": "DEBUG",
            "file_path": "Tests/logs/test.log"
        },
        "reports": {
            "output_directory": "Tests/output",
            "formats": ["html", "csv"],
            "auto_open": False
        }
    }

@pytest.fixture(scope="function")
def temp_dir():
    """一時ディレクトリ"""
    temp_dir = tempfile.mkdtemp()
    yield Path(temp_dir)
    shutil.rmtree(temp_dir)

# Microsoft Graph API モック
@pytest.fixture(scope="function")
def mock_graph_client():
    """Microsoft Graph APIクライアントのモック"""
    with patch('src.api.graph.client.GraphClient') as mock:
        mock_instance = Mock()
        mock_instance.get_users.return_value = [
            {
                "id": "user1",
                "displayName": "Test User 1",
                "userPrincipalName": "user1@contoso.com",
                "mail": "user1@contoso.com",
                "accountEnabled": True
            },
            {
                "id": "user2", 
                "displayName": "Test User 2",
                "userPrincipalName": "user2@contoso.com",
                "mail": "user2@contoso.com",
                "accountEnabled": True
            }
        ]
        mock_instance.get_licenses.return_value = [
            {
                "skuId": "license1",
                "skuPartNumber": "O365_BUSINESS_PREMIUM",
                "consumedUnits": 10,
                "prepaidUnits": {"enabled": 25}
            }
        ]
        mock_instance.get_groups.return_value = [
            {
                "id": "group1",
                "displayName": "Test Group 1",
                "mail": "group1@contoso.com"
            }
        ]
        mock_instance.get_sign_ins.return_value = [
            {
                "id": "signin1",
                "userPrincipalName": "user1@contoso.com",
                "appDisplayName": "Microsoft Teams",
                "status": {"errorCode": 0}
            }
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
            {
                "Identity": "user1@contoso.com",
                "DisplayName": "Test User 1",
                "PrimarySmtpAddress": "user1@contoso.com",
                "RecipientTypeDetails": "UserMailbox"
            },
            {
                "Identity": "user2@contoso.com",
                "DisplayName": "Test User 2", 
                "PrimarySmtpAddress": "user2@contoso.com",
                "RecipientTypeDetails": "UserMailbox"
            }
        ]
        mock_instance.get_message_trace.return_value = [
            {
                "MessageId": "msg1",
                "SenderAddress": "sender@contoso.com",
                "RecipientAddress": "user1@contoso.com",
                "Status": "Delivered"
            }
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
        mock_instance.get_authorization_header.return_value = {
            "Authorization": "Bearer mock_token"
        }
        mock_instance.is_token_expired.return_value = False
        mock_instance.authenticated = True
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
        "CERTIFICATE_PASSWORD": "test_password",
        "EXCHANGE_USERNAME": "admin@contoso.com",
        "EXCHANGE_PASSWORD": "test_password"
    }

# GUI テスト用フィクスチャ
@pytest.fixture(scope="function")
def qtbot(qtbot):
    """PyQt6 テストヘルパー"""
    return qtbot

# テストデータベース
@pytest.fixture(scope="function")
def test_database(temp_dir):
    """テスト用データベース"""
    db_path = temp_dir / "test.db"
    # SQLite テストデータベースの初期化
    import sqlite3
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()
    
    # テーブル作成
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS reports (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            data TEXT
        )
    ''')
    
    # テストデータ挿入
    cursor.executemany('''
        INSERT INTO users (name, email) VALUES (?, ?)
    ''', [
        ("Test User 1", "user1@contoso.com"),
        ("Test User 2", "user2@contoso.com"),
        ("Test User 3", "user3@contoso.com")
    ])
    
    conn.commit()
    conn.close()
    
    yield str(db_path)

# モックデータファイル
@pytest.fixture(scope="session")
def mock_data_files(project_root):
    """モックデータファイル"""
    mock_data_dir = project_root / "Tests" / "fixtures" / "mock_data"
    mock_data_dir.mkdir(parents=True, exist_ok=True)
    
    # ユーザーデータ
    users_data = {
        "value": [
            {
                "id": "user1",
                "displayName": "Test User 1",
                "userPrincipalName": "user1@contoso.com",
                "mail": "user1@contoso.com",
                "accountEnabled": True,
                "createdDateTime": "2023-01-01T00:00:00Z"
            },
            {
                "id": "user2",
                "displayName": "Test User 2", 
                "userPrincipalName": "user2@contoso.com",
                "mail": "user2@contoso.com",
                "accountEnabled": True,
                "createdDateTime": "2023-01-02T00:00:00Z"
            }
        ]
    }
    
    users_file = mock_data_dir / "users.json"
    users_file.write_text(json.dumps(users_data, indent=2))
    
    # ライセンスデータ
    licenses_data = {
        "value": [
            {
                "skuId": "license1",
                "skuPartNumber": "O365_BUSINESS_PREMIUM",
                "consumedUnits": 10,
                "prepaidUnits": {"enabled": 25, "suspended": 0}
            },
            {
                "skuId": "license2",
                "skuPartNumber": "ENTERPRISEPACK",
                "consumedUnits": 5,
                "prepaidUnits": {"enabled": 100, "suspended": 0}
            }
        ]
    }
    
    licenses_file = mock_data_dir / "licenses.json"
    licenses_file.write_text(json.dumps(licenses_data, indent=2))
    
    # メールボックスデータ
    mailboxes_data = [
        {
            "Identity": "user1@contoso.com",
            "DisplayName": "Test User 1",
            "PrimarySmtpAddress": "user1@contoso.com",
            "RecipientTypeDetails": "UserMailbox",
            "ProhibitSendQuota": "50 GB"
        },
        {
            "Identity": "user2@contoso.com",
            "DisplayName": "Test User 2",
            "PrimarySmtpAddress": "user2@contoso.com", 
            "RecipientTypeDetails": "UserMailbox",
            "ProhibitSendQuota": "50 GB"
        }
    ]
    
    mailboxes_file = mock_data_dir / "mailboxes.json"
    mailboxes_file.write_text(json.dumps(mailboxes_data, indent=2))
    
    return {
        "users": users_file,
        "licenses": licenses_file,
        "mailboxes": mailboxes_file
    }

# テストカテゴリ別設定
def pytest_configure(config):
    """pytest設定の動的設定"""
    config.addinivalue_line(
        "markers", "requires_gui: GUI環境が必要なテスト"
    )
    config.addinivalue_line(
        "markers", "requires_network: ネットワーク接続が必要なテスト"
    )
    config.addinivalue_line(
        "markers", "requires_powershell: PowerShell実行が必要なテスト"
    )
    config.addinivalue_line(
        "markers", "slow: 実行時間の長いテスト"
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
    print("\n=== テスト開始 ===")
    
    # テストログディレクトリ作成
    log_dir = PROJECT_ROOT / "Tests" / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    
    # テスト出力ディレクトリ作成
    output_dir = PROJECT_ROOT / "Tests" / "output"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    yield
    
    # ティアダウン
    print("=== テスト終了 ===")

# カスタムマーカー実行制御
def pytest_runtest_setup(item):
    """テスト実行前の条件チェック"""
    if "requires_gui" in item.keywords:
        # GUI環境の確認
        try:
            import PyQt6
            os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
        except ImportError:
            pytest.skip("PyQt6 GUI環境が利用できません")
    
    if "requires_network" in item.keywords:
        # ネットワーク接続の確認
        import socket
        try:
            socket.create_connection(("8.8.8.8", 53), timeout=3)
        except OSError:
            pytest.skip("ネットワーク接続が利用できません")
    
    if "requires_powershell" in item.keywords:
        # PowerShell実行環境の確認
        import subprocess
        try:
            subprocess.run(["pwsh", "-Version"], capture_output=True, timeout=5)
        except (subprocess.TimeoutExpired, FileNotFoundError):
            try:
                subprocess.run(["powershell", "-Version"], capture_output=True, timeout=5)
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pytest.skip("PowerShell実行環境が利用できません")

# 並列実行用ワーカー設定
@pytest.fixture(scope="session")
def worker_id(request):
    """並列実行時のワーカーID"""
    return getattr(request.config, "workerinput", {}).get("workerid", "master")

# パフォーマンス測定
@pytest.fixture(scope="function")
def performance_monitor():
    """パフォーマンス測定"""
    import time
    import psutil
    import os
    
    start_time = time.time()
    process = psutil.Process(os.getpid())
    start_memory = process.memory_info().rss / 1024 / 1024  # MB
    
    yield
    
    end_time = time.time()
    end_memory = process.memory_info().rss / 1024 / 1024  # MB
    
    execution_time = end_time - start_time
    memory_usage = end_memory - start_memory
    
    if execution_time > 10:  # 10秒以上のテストは警告
        print(f"\n⚠️  長時間実行テスト: {execution_time:.2f}秒")
    
    if memory_usage > 100:  # 100MB以上のメモリ使用は警告
        print(f"\n⚠️  大量メモリ使用: {memory_usage:.2f}MB")

# テスト結果レポート
@pytest.fixture(scope="session", autouse=True)
def test_report(request):
    """テスト結果レポート"""
    yield
    
    # テスト完了後にレポート生成
    if hasattr(request.config, "test_results"):
        results = request.config.test_results
        
        report_file = PROJECT_ROOT / "Tests" / "reports" / "test_summary.json"
        report_file.parent.mkdir(parents=True, exist_ok=True)
        
        report_data = {
            "timestamp": str(datetime.now()),
            "total_tests": results.get("total", 0),
            "passed": results.get("passed", 0),
            "failed": results.get("failed", 0),
            "skipped": results.get("skipped", 0),
            "coverage": results.get("coverage", "N/A")
        }
        
        report_file.write_text(json.dumps(report_data, indent=2))

# エラーハンドリング
@pytest.fixture(scope="function")
def error_handler():
    """エラーハンドリング"""
    errors = []
    
    def add_error(error_message):
        errors.append(error_message)
    
    yield add_error
    
    if errors:
        print(f"\n⚠️  テスト中のエラー: {len(errors)}件")
        for error in errors:
            print(f"   - {error}")

# クリーンアップ
def pytest_sessionfinish(session, exitstatus):
    """テストセッション終了時の処理"""
    # 一時ファイルのクリーンアップ
    temp_dirs = [
        PROJECT_ROOT / "Tests" / "tmp",
        PROJECT_ROOT / "Tests" / "output" / "tmp"
    ]
    
    for temp_dir in temp_dirs:
        if temp_dir.exists():
            shutil.rmtree(temp_dir, ignore_errors=True)
    
    print(f"\n✅ テストセッション完了 (終了コード: {exitstatus})")

# 並列実行サポート
def pytest_configure_node(node):
    """並列実行ノードの設定"""
    node.slaveinput["project_root"] = str(PROJECT_ROOT)

# テストデータ検証
@pytest.fixture(scope="function")
def validate_test_data():
    """テストデータの検証"""
    def validator(data, schema):
        """データとスキーマの検証"""
        if not isinstance(data, dict):
            raise ValueError("データは辞書形式である必要があります")
        
        for key, expected_type in schema.items():
            if key not in data:
                raise ValueError(f"必須フィールド '{key}' が見つかりません")
            
            if not isinstance(data[key], expected_type):
                raise ValueError(f"フィールド '{key}' の型が正しくありません")
        
        return True
    
    return validator