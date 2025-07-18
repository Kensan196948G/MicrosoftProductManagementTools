"""
pytest設定ファイル
Dev1 - Test/QA Developer による基盤構築

プロジェクト全体のテスト設定とフィクスチャ定義
"""
import os
import sys
import tempfile
from pathlib import Path
from typing import Dict, Any, Generator
import pytest
import asyncio
from unittest.mock import Mock, patch

# プロジェクトルートをパスに追加
PROJECT_ROOT = Path(__file__).parent.parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))


def pytest_configure(config):
    """pytestの設定を行う"""
    # カスタムマーカーを登録
    config.addinivalue_line(
        "markers", "unit: ユニットテスト - 単一機能の単体テスト"
    )
    config.addinivalue_line(
        "markers", "integration: 統合テスト - 複数コンポーネント連携テスト"
    )
    config.addinivalue_line(
        "markers", "compatibility: 互換性テスト - PowerShell版との出力互換性テスト"
    )
    config.addinivalue_line(
        "markers", "gui: GUIテスト - PyQt6コンポーネントテスト（pytest-qt使用）"
    )
    config.addinivalue_line(
        "markers", "api: APIテスト - Microsoft Graph API統合テスト"
    )
    config.addinivalue_line(
        "markers", "auth: 認証テスト - Microsoft 365認証機能テスト"
    )
    config.addinivalue_line(
        "markers", "slow: 低速テスト - 実行時間が長いテスト（CI除外可能）"
    )
    config.addinivalue_line(
        "markers", "requires_auth: 認証必須テスト - Microsoft 365認証が必要なテスト"
    )
    config.addinivalue_line(
        "markers", "requires_powershell: PowerShell必須テスト - PowerShell実行が必要なテスト"
    )
    config.addinivalue_line(
        "markers", "e2e: エンドツーエンドテスト - 完全なワークフローテスト"
    )
    config.addinivalue_line(
        "markers", "security: セキュリティテスト - セキュリティ関連機能テスト"
    )
    config.addinivalue_line(
        "markers", "performance: パフォーマンステスト - 性能測定テスト"
    )
    config.addinivalue_line(
        "markers", "real_data: 実データテスト - 本物のMicrosoft 365データを使用"
    )
    config.addinivalue_line(
        "markers", "mock_data: モックテスト - モックデータを使用するテスト"
    )


def pytest_collection_modifyitems(config, items):
    """テストアイテムの収集後処理"""
    # CIでslow マーカーのテストをスキップ
    if config.getoption("--ci"):
        skip_slow = pytest.mark.skip(reason="CI環境でslowテストはスキップされます")
        for item in items:
            if "slow" in item.keywords:
                item.add_marker(skip_slow)
    
    # PowerShell 実行環境がない場合のスキップ
    if not _check_powershell_available():
        skip_ps = pytest.mark.skip(reason="PowerShell実行環境が利用できません")
        for item in items:
            if "requires_powershell" in item.keywords:
                item.add_marker(skip_ps)
    
    # 認証が必要なテストの環境チェック
    if not _check_auth_environment():
        skip_auth = pytest.mark.skip(reason="Microsoft 365認証環境が設定されていません")
        for item in items:
            if "requires_auth" in item.keywords:
                item.add_marker(skip_auth)


def pytest_addoption(parser):
    """pytest コマンドラインオプション追加"""
    parser.addoption(
        "--ci", action="store_true", default=False, help="CI環境での実行モード"
    )
    parser.addoption(
        "--skip-slow", action="store_true", default=False, help="低速テストをスキップ"
    )
    parser.addoption(
        "--real-data", action="store_true", default=False, help="実データテストを実行"
    )
    parser.addoption(
        "--auth-mode", type=str, default="mock", choices=["mock", "interactive", "cert"],
        help="認証モード選択"
    )


def _check_powershell_available() -> bool:
    """PowerShell実行環境の確認"""
    try:
        import subprocess
        result = subprocess.run(
            ["pwsh", "--version"], 
            capture_output=True, 
            text=True, 
            timeout=10
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return False


def _check_auth_environment() -> bool:
    """Microsoft 365認証環境の確認"""
    # 環境変数またはconfigファイルの存在確認
    config_file = PROJECT_ROOT / "Config" / "appsettings.json"
    return (
        config_file.exists() or
        os.getenv("AZURE_CLIENT_ID") is not None or
        os.getenv("M365_TENANT_ID") is not None
    )


@pytest.fixture(scope="session")
def project_root() -> Path:
    """プロジェクトルートパスのフィクスチャ"""
    return PROJECT_ROOT


@pytest.fixture(scope="session")
def config_data() -> Dict[str, Any]:
    """設定データのフィクスチャ"""
    config_file = PROJECT_ROOT / "Config" / "appsettings.json"
    if config_file.exists():
        import json
        with open(config_file, "r", encoding="utf-8") as f:
            return json.load(f)
    else:
        # テスト用デフォルト設定
        return {
            "Authentication": {
                "TenantId": "test-tenant-id",
                "ClientId": "test-client-id",
                "CertificateThumbprint": "test-thumbprint"
            },
            "PowerShell": {
                "ExecutionPolicy": "RemoteSigned",
                "Version": "7.5.1"
            },
            "Testing": {
                "MockData": True,
                "Timeout": 300,
                "RetryCount": 3
            }
        }


@pytest.fixture(scope="session")
def temp_project_dir() -> Generator[Path, None, None]:
    """一時プロジェクトディレクトリのフィクスチャ"""
    with tempfile.TemporaryDirectory(prefix="m365_test_") as temp_dir:
        temp_path = Path(temp_dir)
        
        # 必要なディレクトリ構造を作成
        (temp_path / "Reports").mkdir()
        (temp_path / "TestScripts" / "TestReports").mkdir(parents=True)
        (temp_path / "tests" / "logs").mkdir(parents=True)
        (temp_path / "tests" / "temp").mkdir(parents=True)
        
        yield temp_path


@pytest.fixture(scope="function")
def mock_graph_client():
    """Microsoft Graph クライアントのモックフィクスチャ"""
    mock_client = Mock()
    
    # 基本的なメソッドのモック設定
    mock_client.get_users.return_value = {
        "value": [
            {
                "id": "test-user-1",
                "displayName": "テストユーザー1",
                "userPrincipalName": "test1@contoso.com"
            }
        ]
    }
    
    mock_client.get_licenses.return_value = {
        "value": [
            {
                "skuId": "test-sku-1",
                "skuPartNumber": "ENTERPRISEPACK",
                "consumedUnits": 10
            }
        ]
    }
    
    return mock_client


@pytest.fixture(scope="function")
def mock_powershell_execution():
    """PowerShell実行のモックフィクスチャ"""
    with patch('subprocess.run') as mock_run:
        # 成功ケース
        mock_result = Mock()
        mock_result.returncode = 0
        mock_result.stdout = "PowerShell実行成功"
        mock_result.stderr = ""
        mock_run.return_value = mock_result
        
        yield mock_run


@pytest.fixture(scope="function")
def sample_test_data() -> Dict[str, Any]:
    """サンプルテストデータのフィクスチャ"""
    return {
        "users": [
            {
                "ID": "user-001",
                "表示名": "山田太郎",
                "メールアドレス": "yamada@contoso.com",
                "部署": "IT部門",
                "状態": "有効"
            },
            {
                "ID": "user-002",
                "表示名": "田中花子",
                "メールアドレス": "tanaka@contoso.com",
                "部署": "営業部",
                "状態": "有効"
            }
        ],
        "licenses": [
            {
                "SKU ID": "sku-001",
                "製品名": "Office 365 E3",
                "消費数": "85",
                "利用率": "85%"
            }
        ]
    }


@pytest.fixture(scope="function", autouse=True)
def test_isolation():
    """テスト間の分離を保証するフィクスチャ"""
    # テスト前処理
    original_env = os.environ.copy()
    
    yield
    
    # テスト後処理: 環境変数をリセット
    os.environ.clear()
    os.environ.update(original_env)


@pytest.fixture(scope="function")
def event_loop():
    """asyncio イベントループのフィクスチャ"""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="function")
def mock_file_operations():
    """ファイル操作のモックフィクスチャ"""
    with patch('builtins.open', create=True) as mock_open, \
         patch('pathlib.Path.exists') as mock_exists, \
         patch('pathlib.Path.mkdir') as mock_mkdir:
        
        # デフォルトの戻り値設定
        mock_exists.return_value = True
        mock_mkdir.return_value = None
        
        yield {
            'open': mock_open,
            'exists': mock_exists,
            'mkdir': mock_mkdir
        }


@pytest.fixture(scope="function")
def capture_logs():
    """ログキャプチャのフィクスチャ"""
    import logging
    from io import StringIO
    
    log_capture_string = StringIO()
    ch = logging.StreamHandler(log_capture_string)
    ch.setLevel(logging.DEBUG)
    
    # テスト用ロガー設定
    logger = logging.getLogger('test_logger')
    logger.setLevel(logging.DEBUG)
    logger.addHandler(ch)
    
    yield log_capture_string
    
    # クリーンアップ
    logger.removeHandler(ch)


@pytest.fixture(scope="function")
def gui_test_env():
    """GUIテスト環境のフィクスチャ（pytest-qt使用時）"""
    import os
    
    # GUI テスト用環境変数設定
    os.environ['QT_QPA_PLATFORM'] = 'offscreen'
    os.environ['QT_LOGGING_RULES'] = 'qt.qpa.xcb.glx=false'
    
    yield
    
    # クリーンアップ
    if 'QT_QPA_PLATFORM' in os.environ:
        del os.environ['QT_QPA_PLATFORM']
    if 'QT_LOGGING_RULES' in os.environ:
        del os.environ['QT_LOGGING_RULES']


# カスタムアサート関数
def assert_file_created(file_path: Path, min_size: int = 0):
    """ファイル作成のカスタムアサート"""
    assert file_path.exists(), f"ファイルが作成されませんでした: {file_path}"
    if min_size > 0:
        assert file_path.stat().st_size >= min_size, \
            f"ファイルサイズが小さすぎます: {file_path} (実際: {file_path.stat().st_size}, 期待: {min_size}以上)"


def assert_csv_format(csv_path: Path):
    """CSV形式のカスタムアサート"""
    assert csv_path.suffix.lower() == '.csv', f"CSV拡張子ではありません: {csv_path}"
    
    # UTF-8 BOM確認
    with open(csv_path, 'rb') as f:
        bom = f.read(3)
        assert bom == b'\xef\xbb\xbf', f"UTF-8 BOMが正しくありません: {csv_path}"


def assert_html_format(html_path: Path):
    """HTML形式のカスタムアサート"""
    assert html_path.suffix.lower() == '.html', f"HTML拡張子ではありません: {html_path}"
    
    with open(html_path, 'r', encoding='utf-8') as f:
        content = f.read()
        assert '<!DOCTYPE html>' in content or '<html' in content.lower(), \
            f"HTML形式が正しくありません: {html_path}"


def assert_json_format(json_path: Path):
    """JSON形式のカスタムアサート"""
    import json
    
    assert json_path.suffix.lower() == '.json', f"JSON拡張子ではありません: {json_path}"
    
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            json.load(f)
    except json.JSONDecodeError as e:
        pytest.fail(f"JSON形式が正しくありません: {json_path} - {e}")


# pytest フック
def pytest_report_header(config):
    """テストレポートヘッダー"""
    return [
        f"Microsoft 365管理ツール pytest互換性テストスイート",
        f"プロジェクトルート: {PROJECT_ROOT}",
        f"Python バージョン: {sys.version}",
        f"PowerShell 利用可能: {'はい' if _check_powershell_available() else 'いいえ'}",
        f"認証環境: {'設定済み' if _check_auth_environment() else '未設定'}"
    ]


def pytest_sessionstart(session):
    """テストセッション開始時の処理"""
    # ログディレクトリ作成
    log_dir = PROJECT_ROOT / "tests" / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    
    # テスト開始ログ
    print("\n🚀 Microsoft 365管理ツール pytest互換性テスト開始")


def pytest_sessionfinish(session, exitstatus):
    """テストセッション終了時の処理"""
    # テスト終了ログ
    if exitstatus == 0:
        print("\n✅ Microsoft 365管理ツール pytest互換性テスト完了 - 全テスト成功")
    else:
        print(f"\n❌ Microsoft 365管理ツール pytest互換性テスト完了 - 終了コード: {exitstatus}")


# 実行時設定
if __name__ == "__main__":
    print("このファイルはpytestのconftest.pyです。直接実行せず、pytestコマンドを使用してください。")
    print("使用例: python -m pytest Tests/")