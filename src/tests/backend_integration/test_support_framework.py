"""
dev2テスト統合技術支援フレームワーク
pytest環境最適化・FastAPI統合テスト・Microsoft Graph モック支援
"""

import asyncio
import json
import pytest
import pytest_asyncio
from typing import Any, Dict, List, Optional, AsyncGenerator, Generator
from unittest.mock import AsyncMock, Mock, patch
from httpx import AsyncClient
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker
import tempfile
import os
from pathlib import Path

from ...main_fastapi import app
from ...core.config import settings
from ...core.database import Base, get_async_session
from ...api.graph.client import GraphClient
from ...api.bridge.powershell_bridge import PowerShellBridge

# テスト設定クラス
class TestConfiguration:
    """テスト設定管理"""
    
    def __init__(self):
        self.test_database_url = "sqlite+aiosqlite:///:memory:"
        self.mock_mode = True
        self.log_level = "DEBUG"
        self.test_data_dir = Path(__file__).parent / "test_data"
        self.test_data_dir.mkdir(exist_ok=True)
        
        # モック設定
        self.mock_microsoft_graph = True
        self.mock_powershell_bridge = True
        self.mock_external_apis = True
        
        # テストユーザー設定
        self.test_tenant_id = "test-tenant-12345"
        self.test_client_id = "test-client-67890"
        self.test_user_id = "test-user@example.com"

test_config = TestConfiguration()

# pytest fixtures

@pytest.fixture(scope="session")
def event_loop():
    """セッションスコープのイベントループ"""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest_asyncio.fixture(scope="session")
async def test_database():
    """テスト用データベース"""
    engine = create_async_engine(
        test_config.test_database_url,
        echo=False
    )
    
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    yield engine
    
    await engine.dispose()

@pytest_asyncio.fixture
async def test_session(test_database):
    """テスト用データベースセッション"""
    async_session = sessionmaker(
        bind=test_database,
        class_=AsyncSession,
        expire_on_commit=False
    )
    
    async with async_session() as session:
        yield session
        await session.rollback()

@pytest.fixture
def override_get_session(test_session):
    """データベースセッション依存性オーバーライド"""
    async def _override_get_session():
        yield test_session
    
    app.dependency_overrides[get_async_session] = _override_get_session
    yield
    app.dependency_overrides.clear()

@pytest_asyncio.fixture
async def async_client(override_get_session):
    """非同期HTTPクライアント"""
    async with AsyncClient(app=app, base_url="http://test") as client:
        yield client

@pytest.fixture
def sync_client(override_get_session):
    """同期HTTPクライアント"""
    with TestClient(app) as client:
        yield client

# Microsoft Graph API モック支援

class GraphAPIMockHelper:
    """Microsoft Graph API モックヘルパー"""
    
    def __init__(self):
        self.mock_users_data = self._generate_mock_users()
        self.mock_licenses_data = self._generate_mock_licenses()
        self.mock_groups_data = self._generate_mock_groups()
        self.mock_devices_data = self._generate_mock_devices()
        
    def _generate_mock_users(self) -> List[Dict[str, Any]]:
        """モックユーザーデータ生成"""
        return [
            {
                "id": f"user-{i:03d}",
                "displayName": f"Test User {i}",
                "userPrincipalName": f"testuser{i}@example.com",
                "givenName": f"Test{i}",
                "surname": f"User{i}",
                "jobTitle": ["Manager", "Developer", "Analyst", "Administrator"][i % 4],
                "department": ["IT", "HR", "Finance", "Marketing"][i % 4],
                "accountEnabled": True,
                "createdDateTime": "2023-01-01T00:00:00Z",
                "lastSignInDateTime": "2024-01-15T10:30:00Z",
                "assignedLicenses": [
                    {
                        "skuId": "license-sku-001",
                        "disabledPlans": []
                    }
                ] if i % 3 == 0 else []
            }
            for i in range(1, 151)  # 150ユーザー
        ]
    
    def _generate_mock_licenses(self) -> List[Dict[str, Any]]:
        """モックライセンスデータ生成"""
        return [
            {
                "skuId": "license-sku-001",
                "skuPartNumber": "ENTERPRISEPACK",
                "servicePlans": [
                    {
                        "servicePlanId": "service-001",
                        "servicePlanName": "EXCHANGE_S_ENTERPRISE"
                    },
                    {
                        "servicePlanId": "service-002", 
                        "servicePlanName": "TEAMS1"
                    }
                ],
                "prepaidUnits": {
                    "enabled": 200,
                    "suspended": 0,
                    "warning": 0
                },
                "consumedUnits": 150
            },
            {
                "skuId": "license-sku-002",
                "skuPartNumber": "POWER_BI_PRO",
                "servicePlans": [
                    {
                        "servicePlanId": "service-003",
                        "servicePlanName": "POWER_BI_PRO"
                    }
                ],
                "prepaidUnits": {
                    "enabled": 50,
                    "suspended": 0,
                    "warning": 0
                },
                "consumedUnits": 25
            }
        ]
    
    def _generate_mock_groups(self) -> List[Dict[str, Any]]:
        """モックグループデータ生成"""
        return [
            {
                "id": f"group-{i:03d}",
                "displayName": f"Test Group {i}",
                "description": f"Test group {i} for testing purposes",
                "groupTypes": ["Unified"] if i % 2 == 0 else [],
                "mailEnabled": True,
                "securityEnabled": True,
                "createdDateTime": "2023-01-01T00:00:00Z"
            }
            for i in range(1, 21)  # 20グループ
        ]
    
    def _generate_mock_devices(self) -> List[Dict[str, Any]]:
        """モックデバイスデータ生成"""
        return [
            {
                "id": f"device-{i:03d}",
                "displayName": f"Test-Device-{i:03d}",
                "deviceId": f"device-id-{i:03d}",
                "operatingSystem": ["Windows", "macOS", "iOS", "Android"][i % 4],
                "operatingSystemVersion": "10.0.19041.1234",
                "isCompliant": i % 3 != 0,
                "isManaged": True,
                "registrationDateTime": "2023-01-01T00:00:00Z",
                "approximateLastSignInDateTime": "2024-01-15T10:30:00Z"
            }
            for i in range(1, 101)  # 100デバイス
        ]

    async def mock_graph_api_calls(self, mock_client: AsyncMock):
        """Graph API 呼び出しのモック設定"""
        
        # ユーザー関連
        mock_client.get_users.return_value = self.mock_users_data
        mock_client.get_user.side_effect = lambda user_id: next(
            (user for user in self.mock_users_data if user["id"] == user_id),
            None
        )
        
        # ライセンス関連
        mock_client.get_licenses.return_value = self.mock_licenses_data
        mock_client.get_user_licenses.return_value = [
            {
                "skuId": "license-sku-001",
                "skuPartNumber": "ENTERPRISEPACK"
            }
        ]
        
        # グループ関連
        mock_client.get_groups.return_value = self.mock_groups_data
        
        # デバイス関連
        mock_client.get_devices.return_value = self.mock_devices_data
        
        # 統計データ
        mock_client.get_organization_stats.return_value = {
            "totalUsers": len(self.mock_users_data),
            "totalGroups": len(self.mock_groups_data),
            "totalDevices": len(self.mock_devices_data),
            "activeLicenses": sum(lic["consumedUnits"] for lic in self.mock_licenses_data)
        }

graph_mock_helper = GraphAPIMockHelper()

@pytest_asyncio.fixture
async def mock_graph_client():
    """Microsoft Graph クライアントモック"""
    with patch('src.api.graph.client.GraphClient') as mock:
        mock_instance = AsyncMock()
        mock.return_value = mock_instance
        
        await graph_mock_helper.mock_graph_api_calls(mock_instance)
        
        yield mock_instance

# PowerShell Bridge モック支援

class PowerShellBridgeMockHelper:
    """PowerShellブリッジモックヘルパー"""
    
    def __init__(self):
        self.mock_script_results = self._generate_mock_script_results()
    
    def _generate_mock_script_results(self) -> Dict[str, Dict[str, Any]]:
        """モックスクリプト結果生成"""
        return {
            "Get-M365Users": {
                "success": True,
                "exit_code": 0,
                "stdout": json.dumps([
                    {
                        "DisplayName": "PowerShell Test User 1",
                        "UserPrincipalName": "psuser1@example.com",
                        "Enabled": True,
                        "Licenses": ["ENTERPRISEPACK"]
                    },
                    {
                        "DisplayName": "PowerShell Test User 2", 
                        "UserPrincipalName": "psuser2@example.com",
                        "Enabled": True,
                        "Licenses": ["POWER_BI_PRO"]
                    }
                ]),
                "stderr": "",
                "execution_time_seconds": 2.5
            },
            "Get-M365Licenses": {
                "success": True,
                "exit_code": 0,
                "stdout": json.dumps({
                    "TotalLicenses": 250,
                    "AssignedLicenses": 175,
                    "AvailableLicenses": 75,
                    "LicenseTypes": ["ENTERPRISEPACK", "POWER_BI_PRO"]
                }),
                "stderr": "",
                "execution_time_seconds": 1.8
            },
            "Generate-DailyReport": {
                "success": True,
                "exit_code": 0,
                "stdout": "Daily report generated successfully",
                "stderr": "",
                "execution_time_seconds": 15.2,
                "output_path": "/tmp/daily_report_20240115.html"
            },
            "Test-M365Authentication": {
                "success": True,
                "exit_code": 0,
                "stdout": json.dumps({
                    "GraphAPI": True,
                    "ExchangeOnline": True,
                    "Teams": True,
                    "OneDrive": True
                }),
                "stderr": "",
                "execution_time_seconds": 5.0
            }
        }

    async def mock_powershell_calls(self, mock_bridge: AsyncMock):
        """PowerShell呼び出しのモック設定"""
        
        async def mock_execute_script(request):
            function_name = request.function_name or "unknown"
            mock_result = self.mock_script_results.get(function_name, {
                "success": False,
                "exit_code": 1,
                "stdout": "",
                "stderr": f"Unknown function: {function_name}",
                "execution_time_seconds": 0.1
            })
            
            # PowerShellExecutionResult オブジェクトのモック
            from ...api.bridge.powershell_bridge import PowerShellExecutionResult
            from datetime import datetime
            import uuid
            
            return PowerShellExecutionResult(
                success=mock_result["success"],
                exit_code=mock_result["exit_code"],
                stdout=mock_result["stdout"],
                stderr=mock_result["stderr"],
                execution_time_seconds=mock_result["execution_time_seconds"],
                output_data=json.loads(mock_result["stdout"]) if mock_result["stdout"] and mock_result["success"] else None,
                execution_id=str(uuid.uuid4()),
                timestamp=datetime.utcnow()
            )
        
        mock_bridge.execute_script.side_effect = mock_execute_script
        mock_bridge.execute_mapped_function.side_effect = lambda name, params: mock_execute_script(
            type('Request', (), {'function_name': name, 'parameters': params})()
        )
        
        # 接続テスト
        mock_bridge.test_powershell_connectivity.return_value = {
            "success": True,
            "powershell_version": {"PSVersion": "7.3.0"},
            "execution_time": 0.5,
            "executable": "pwsh"
        }

powershell_mock_helper = PowerShellBridgeMockHelper()

@pytest_asyncio.fixture
async def mock_powershell_bridge():
    """PowerShellブリッジモック"""
    with patch('src.api.bridge.powershell_bridge.PowerShellBridge') as mock:
        mock_instance = AsyncMock()
        mock.return_value = mock_instance
        
        await powershell_mock_helper.mock_powershell_calls(mock_instance)
        
        yield mock_instance

# FastAPI統合テストヘルパー

class FastAPITestHelper:
    """FastAPI統合テストヘルパー"""
    
    @staticmethod
    async def test_api_endpoint(
        client: AsyncClient,
        method: str,
        endpoint: str,
        data: Optional[Dict[str, Any]] = None,
        headers: Optional[Dict[str, str]] = None,
        expected_status: int = 200
    ) -> Dict[str, Any]:
        """API エンドポイントテストヘルパー"""
        
        headers = headers or {"Content-Type": "application/json"}
        
        if method.upper() == "GET":
            response = await client.get(endpoint, headers=headers)
        elif method.upper() == "POST":
            response = await client.post(endpoint, json=data, headers=headers)
        elif method.upper() == "PUT":
            response = await client.put(endpoint, json=data, headers=headers)
        elif method.upper() == "DELETE":
            response = await client.delete(endpoint, headers=headers)
        else:
            raise ValueError(f"Unsupported HTTP method: {method}")
        
        assert response.status_code == expected_status, f"Expected {expected_status}, got {response.status_code}: {response.text}"
        
        if response.headers.get("content-type", "").startswith("application/json"):
            return response.json()
        else:
            return {"content": response.text, "status_code": response.status_code}
    
    @staticmethod
    async def test_authentication_required(
        client: AsyncClient,
        endpoint: str,
        method: str = "GET"
    ):
        """認証が必要なエンドポイントのテスト"""
        
        # 認証なしでアクセス
        if method.upper() == "GET":
            response = await client.get(endpoint)
        elif method.upper() == "POST":
            response = await client.post(endpoint, json={})
        
        assert response.status_code == 401, f"Expected 401 Unauthorized, got {response.status_code}"
    
    @staticmethod
    async def test_api_error_handling(
        client: AsyncClient,
        endpoint: str,
        invalid_data: Dict[str, Any],
        expected_error_code: str = None
    ):
        """APIエラーハンドリングテスト"""
        
        response = await client.post(endpoint, json=invalid_data)
        
        assert response.status_code >= 400, f"Expected error status, got {response.status_code}"
        
        if expected_error_code:
            error_data = response.json()
            assert error_data.get("error_code") == expected_error_code

# テストデータ生成ヘルパー

class TestDataGenerator:
    """テストデータ生成ヘルパー"""
    
    @staticmethod
    def generate_test_user_data(count: int = 10) -> List[Dict[str, Any]]:
        """テストユーザーデータ生成"""
        return [
            {
                "id": f"test-user-{i:03d}",
                "displayName": f"Test User {i}",
                "userPrincipalName": f"testuser{i}@testdomain.com",
                "givenName": f"Test{i}",
                "surname": f"User{i}",
                "jobTitle": ["Manager", "Developer", "Analyst"][i % 3],
                "department": ["IT", "HR", "Finance"][i % 3],
                "accountEnabled": True
            }
            for i in range(1, count + 1)
        ]
    
    @staticmethod
    def generate_test_license_data() -> Dict[str, Any]:
        """テストライセンスデータ生成"""
        return {
            "totalLicenses": 100,
            "assignedLicenses": 75,
            "availableLicenses": 25,
            "licenseTypes": [
                {
                    "skuPartNumber": "ENTERPRISEPACK",
                    "assigned": 50,
                    "available": 15
                },
                {
                    "skuPartNumber": "POWER_BI_PRO", 
                    "assigned": 25,
                    "available": 10
                }
            ]
        }
    
    @staticmethod
    def generate_test_report_data() -> Dict[str, Any]:
        """テストレポートデータ生成"""
        return {
            "reportType": "daily",
            "generatedAt": "2024-01-15T10:00:00Z",
            "summary": {
                "totalUsers": 150,
                "activeUsers": 142,
                "newUsers": 3,
                "disabledUsers": 5
            },
            "sections": [
                {
                    "title": "User Activity",
                    "data": {"activeUsers": 142, "inactiveUsers": 8}
                },
                {
                    "title": "License Usage",
                    "data": {"totalLicenses": 200, "usedLicenses": 175}
                }
            ]
        }

# パフォーマンステストヘルパー

class PerformanceTestHelper:
    """パフォーマンステストヘルパー"""
    
    @staticmethod
    async def measure_api_performance(
        client: AsyncClient,
        endpoint: str,
        method: str = "GET",
        data: Optional[Dict[str, Any]] = None,
        iterations: int = 10
    ) -> Dict[str, float]:
        """API パフォーマンス測定"""
        import time
        
        response_times = []
        
        for _ in range(iterations):
            start_time = time.time()
            
            if method.upper() == "GET":
                response = await client.get(endpoint)
            elif method.upper() == "POST":
                response = await client.post(endpoint, json=data)
            
            end_time = time.time()
            response_times.append(end_time - start_time)
            
            assert response.status_code < 500, f"Server error: {response.status_code}"
        
        return {
            "average_response_time": sum(response_times) / len(response_times),
            "min_response_time": min(response_times),
            "max_response_time": max(response_times),
            "total_requests": iterations
        }

# テストユーティリティ

def create_temp_test_file(content: str, suffix: str = ".json") -> str:
    """一時テストファイル作成"""
    with tempfile.NamedTemporaryFile(mode='w', suffix=suffix, delete=False) as f:
        f.write(content)
        return f.name

def cleanup_temp_files(file_paths: List[str]):
    """一時ファイルクリーンアップ"""
    for file_path in file_paths:
        try:
            os.unlink(file_path)
        except FileNotFoundError:
            pass

# pytest マーカー定義

# カスタムマーカー
pytest_plugins = []

# テスト分類マーカー
pytestmark = [
    pytest.mark.backend_integration,
    pytest.mark.test_support_framework
]

# エクスポート用のヘルパークラス・関数
__all__ = [
    "TestConfiguration", 
    "test_config",
    "GraphAPIMockHelper",
    "graph_mock_helper", 
    "PowerShellBridgeMockHelper",
    "powershell_mock_helper",
    "FastAPITestHelper",
    "TestDataGenerator",
    "PerformanceTestHelper",
    "create_temp_test_file",
    "cleanup_temp_files",
    # Fixtures
    "test_database",
    "test_session", 
    "override_get_session",
    "async_client",
    "sync_client",
    "mock_graph_client",
    "mock_powershell_bridge"
]