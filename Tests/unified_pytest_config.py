"""
Microsoft 365管理ツール 統一pytest設定
===================================

全テスト環境の統一設定
- conftest.py重複問題解決
- FastAPI TestClient対応
- 非同期テスト対応
- データベーステスト対応
"""

import pytest
import asyncio
import os
import sys
from pathlib import Path
from typing import AsyncGenerator, Generator

# プロジェクトルートをパスに追加
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))
sys.path.insert(0, str(project_root / "src"))

# 非同期テスト設定
pytest_plugins = ["pytest_asyncio"]


@pytest.fixture(scope="session")
def event_loop():
    """セッションスコープのイベントループ"""
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
    
    yield loop
    loop.close()


@pytest.fixture(scope="session")
async def database_engine():
    """テスト用データベースエンジン"""
    from sqlalchemy.ext.asyncio import create_async_engine
    
    # テスト用SQLite（インメモリ）
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        echo=False
    )
    
    # テーブル作成
    from src.database.models import Base
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    yield engine
    
    # クリーンアップ
    await engine.dispose()


@pytest.fixture(scope="function")
async def db_session(database_engine):
    """テスト用データベースセッション"""
    from sqlalchemy.ext.asyncio import AsyncSession
    
    async with AsyncSession(database_engine) as session:
        try:
            yield session
        finally:
            await session.rollback()


@pytest.fixture(scope="function")
def fastapi_client():
    """FastAPI TestClient"""
    from fastapi.testclient import TestClient
    from src.api.main import app
    
    with TestClient(app) as client:
        yield client


@pytest.fixture(scope="function") 
async def async_fastapi_client():
    """非同期FastAPI TestClient"""
    import httpx
    from src.api.main import app
    
    async with httpx.AsyncClient(app=app, base_url="http://test") as client:
        yield client


@pytest.fixture(scope="session")
def sample_user_data():
    """テスト用サンプルユーザーデータ"""
    return {
        "display_name": "テスト太郎",
        "user_principal_name": "test.user@contoso.com",
        "email": "test.user@contoso.com",
        "department": "情報システム部",
        "job_title": "システム管理者",
        "account_status": "有効",
        "usage_location": "JP"
    }


@pytest.fixture(scope="session")
def sample_mailbox_data():
    """テスト用サンプルメールボックスデータ"""
    return {
        "email": "test.mailbox@contoso.com",
        "display_name": "テストメールボックス",
        "mailbox_type": "UserMailbox",
        "total_size_mb": 1024.5,
        "quota_mb": 50000.0,
        "usage_percent": 2.05,
        "message_count": 150,
        "forwarding_enabled": False,
        "auto_reply_enabled": False
    }


@pytest.fixture(scope="session")
def mock_graph_response():
    """Microsoft Graph APIモックレスポンス"""
    return {
        "value": [
            {
                "id": "test-user-id",
                "displayName": "テスト太郎",
                "userPrincipalName": "test.user@contoso.com",
                "mail": "test.user@contoso.com",
                "department": "情報システム部",
                "jobTitle": "システム管理者",
                "accountEnabled": True,
                "createdDateTime": "2023-01-01T00:00:00Z",
                "usageLocation": "JP"
            }
        ]
    }


@pytest.fixture(scope="function")
def mock_auth_config():
    """テスト用認証設定"""
    from src.auth.msal_authentication import AuthenticationConfig
    
    return AuthenticationConfig(
        tenant_id="test-tenant-id",
        client_id="test-client-id",
        client_secret="test-client-secret",
        authority="https://login.microsoftonline.com/test-tenant-id"
    )


# pytest設定
def pytest_configure(config):
    """pytest設定"""
    # 警告抑制
    import warnings
    warnings.filterwarnings("ignore", category=DeprecationWarning)
    
    # asyncio設定
    asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy() if os.name == 'nt' else None)


def pytest_collection_modifyitems(config, items):
    """テスト項目修正"""
    for item in items:
        # 非同期テストにマーカー追加
        if asyncio.iscoroutinefunction(item.function):
            item.add_marker(pytest.mark.asyncio)


# マーカー定義
pytest_markers = [
    "unit: 単体テスト",
    "integration: 統合テスト", 
    "api: APIテスト",
    "database: データベーステスト",
    "auth: 認証テスト",
    "slow: 実行時間の長いテスト",
    "external: 外部サービス依存テスト"
]


class DatabaseTestCase:
    """データベーステストベースクラス"""
    
    async def setup_test_data(self, session):
        """テストデータセットアップ"""
        pass
    
    async def teardown_test_data(self, session):
        """テストデータクリーンアップ"""
        await session.rollback()


class APITestCase:
    """APIテストベースクラス"""
    
    def setup_headers(self):
        """APIテスト用ヘッダー設定"""
        return {
            "Content-Type": "application/json",
            "Accept": "application/json"
        }


# ヘルパー関数
def create_test_user_model(**kwargs):
    """テスト用ユーザーモデル作成"""
    from src.database.models import User
    
    default_data = {
        "display_name": "テストユーザー",
        "user_principal_name": "test@example.com",
        "email": "test@example.com",
        "account_status": "有効"
    }
    
    default_data.update(kwargs)
    return User(**default_data)


def create_test_mailbox_model(**kwargs):
    """テスト用メールボックスモデル作成"""
    from src.database.models import Mailbox
    
    default_data = {
        "email": "test@example.com",
        "display_name": "テストメールボックス",
        "mailbox_type": "UserMailbox",
        "total_size_mb": 1000.0,
        "quota_mb": 50000.0,
        "usage_percent": 2.0,
        "message_count": 100
    }
    
    default_data.update(kwargs)
    return Mailbox(**default_data)