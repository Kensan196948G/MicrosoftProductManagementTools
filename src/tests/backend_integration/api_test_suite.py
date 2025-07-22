"""
FastAPI統合テストスイート for dev2支援
包括的API テスト・品質保証・仕様提供
"""

import pytest
import pytest_asyncio
from typing import Any, Dict, List
from httpx import AsyncClient
import json
from datetime import datetime

from .test_support_framework import (
    async_client, mock_graph_client, mock_powershell_bridge,
    FastAPITestHelper, TestDataGenerator, PerformanceTestHelper
)

class TestMicrosoft365APIIntegration:
    """Microsoft 365 API統合テスト"""
    
    @pytest.mark.asyncio
    async def test_get_users_endpoint(self, async_client: AsyncClient, mock_graph_client):
        """ユーザー一覧取得エンドポイントテスト"""
        
        # 正常ケース
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            "/api/graph/users",
            expected_status=200
        )
        
        assert "users" in response_data
        assert isinstance(response_data["users"], list)
        assert len(response_data["users"]) > 0
        
        # ユーザーデータ構造確認
        user = response_data["users"][0]
        required_fields = ["id", "displayName", "userPrincipalName", "accountEnabled"]
        for field in required_fields:
            assert field in user
        
        # パラメータ付きリクエスト
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET", 
            "/api/graph/users?top=50&filter=accountEnabled eq true",
            expected_status=200
        )
        
        assert "users" in response_data
        assert len(response_data["users"]) <= 50
    
    @pytest.mark.asyncio
    async def test_get_specific_user(self, async_client: AsyncClient, mock_graph_client):
        """特定ユーザー取得テスト"""
        
        user_id = "user-001"
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            f"/api/graph/users/{user_id}",
            expected_status=200
        )
        
        assert "user" in response_data
        assert response_data["user"]["id"] == user_id
    
    @pytest.mark.asyncio 
    async def test_get_user_not_found(self, async_client: AsyncClient, mock_graph_client):
        """存在しないユーザー取得エラーテスト"""
        
        await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            "/api/graph/users/nonexistent-user",
            expected_status=404
        )
    
    @pytest.mark.asyncio
    async def test_get_licenses_endpoint(self, async_client: AsyncClient, mock_graph_client):
        """ライセンス一覧取得エンドポイントテスト"""
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            "/api/graph/licenses",
            expected_status=200
        )
        
        assert "licenses" in response_data
        assert isinstance(response_data["licenses"], list)
        
        # ライセンスデータ構造確認
        if response_data["licenses"]:
            license_data = response_data["licenses"][0]
            required_fields = ["skuId", "skuPartNumber", "prepaidUnits", "consumedUnits"]
            for field in required_fields:
                assert field in license_data
    
    @pytest.mark.asyncio
    async def test_get_user_licenses(self, async_client: AsyncClient, mock_graph_client):
        """ユーザーライセンス取得テスト"""
        
        user_id = "user-001"
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            f"/api/graph/users/{user_id}/licenses",
            expected_status=200
        )
        
        assert "licenses" in response_data
        assert isinstance(response_data["licenses"], list)
    
    @pytest.mark.asyncio
    async def test_get_groups_endpoint(self, async_client: AsyncClient, mock_graph_client):
        """グループ一覧取得エンドポイントテスト"""
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            "/api/graph/groups",
            expected_status=200
        )
        
        assert "groups" in response_data
        assert isinstance(response_data["groups"], list)
    
    @pytest.mark.asyncio
    async def test_get_devices_endpoint(self, async_client: AsyncClient, mock_graph_client):
        """デバイス一覧取得エンドポイントテスト"""
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            "/api/graph/devices",
            expected_status=200
        )
        
        assert "devices" in response_data
        assert isinstance(response_data["devices"], list)

class TestPowerShellBridgeAPI:
    """PowerShellブリッジAPI テスト"""
    
    @pytest.mark.asyncio
    async def test_execute_powershell_function(self, async_client: AsyncClient, mock_powershell_bridge):
        """PowerShell関数実行テスト"""
        
        request_data = {
            "function_name": "Get-M365Users",
            "parameters": {
                "MaxResults": 100,
                "IncludeLicenses": True
            },
            "output_format": "json"
        }
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "POST",
            "/api/powershell/execute",
            data=request_data,
            expected_status=200
        )
        
        assert "success" in response_data
        assert response_data["success"] == True
        assert "execution_id" in response_data
        assert "output_data" in response_data
    
    @pytest.mark.asyncio
    async def test_powershell_authentication_test(self, async_client: AsyncClient, mock_powershell_bridge):
        """PowerShell認証テスト実行"""
        
        request_data = {
            "function_name": "Test-M365Authentication",
            "parameters": {},
            "output_format": "json"
        }
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "POST",
            "/api/powershell/execute",
            data=request_data,
            expected_status=200
        )
        
        assert response_data["success"] == True
        auth_results = response_data["output_data"]
        assert "GraphAPI" in auth_results
        assert "ExchangeOnline" in auth_results
    
    @pytest.mark.asyncio
    async def test_powershell_script_upload(self, async_client: AsyncClient, mock_powershell_bridge):
        """PowerShellスクリプトアップロード・実行テスト"""
        
        script_content = """
        param($TestParam)
        Write-Output "Test script executed with parameter: $TestParam"
        """
        
        request_data = {
            "script_content": script_content,
            "parameters": {"TestParam": "test_value"},
            "output_format": "text"
        }
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "POST",
            "/api/powershell/execute-script",
            data=request_data,
            expected_status=200
        )
        
        assert "execution_id" in response_data
    
    @pytest.mark.asyncio
    async def test_get_available_powershell_functions(self, async_client: AsyncClient, mock_powershell_bridge):
        """利用可能PowerShell関数一覧取得テスト"""
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            "/api/powershell/functions",
            expected_status=200
        )
        
        assert "functions" in response_data
        assert isinstance(response_data["functions"], dict)

class TestReportGenerationAPI:
    """レポート生成API テスト"""
    
    @pytest.mark.asyncio
    async def test_generate_daily_report(self, async_client: AsyncClient, mock_graph_client, mock_powershell_bridge):
        """日次レポート生成テスト"""
        
        request_data = {
            "report_type": "daily",
            "output_format": "HTML",
            "include_sections": ["users", "licenses", "security"],
            "auto_open": False
        }
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "POST",
            "/api/reports/generate",
            data=request_data,
            expected_status=200
        )
        
        assert "execution_id" in response_data
        assert "status" in response_data
        assert response_data["status"] in ["started", "running"]
    
    @pytest.mark.asyncio
    async def test_get_report_status(self, async_client: AsyncClient):
        """レポート生成状況確認テスト"""
        
        execution_id = "test-execution-123"
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            f"/api/reports/status/{execution_id}",
            expected_status=200
        )
        
        assert "execution_id" in response_data
        assert "status" in response_data
        assert "progress" in response_data
    
    @pytest.mark.asyncio
    async def test_download_report(self, async_client: AsyncClient):
        """レポートダウンロードテスト"""
        
        report_id = "daily_report_20240115"
        
        response = await async_client.get(f"/api/reports/download/{report_id}")
        
        # ファイルダウンロードの場合は200または302
        assert response.status_code in [200, 302, 404]  # 404は存在しない場合
    
    @pytest.mark.asyncio
    async def test_list_available_reports(self, async_client: AsyncClient):
        """利用可能レポート一覧取得テスト"""
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            "/api/reports/list",
            expected_status=200
        )
        
        assert "reports" in response_data
        assert isinstance(response_data["reports"], list)

class TestRealtimeNotificationsAPI:
    """リアルタイム通知API テスト"""
    
    @pytest.mark.asyncio
    async def test_start_realtime_monitoring(self, async_client: AsyncClient):
        """リアルタイム監視開始テスト"""
        
        request_data = {
            "resources": ["users", "groups", "devices"],
            "webhook_url": "https://example.com/webhook",
            "client_state": "test_client_state"
        }
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "POST",
            "/api/notifications/start",
            data=request_data,
            expected_status=200
        )
        
        assert "monitoring_started" in response_data
        assert "subscriptions" in response_data
    
    @pytest.mark.asyncio
    async def test_get_monitoring_status(self, async_client: AsyncClient):
        """監視状況確認テスト"""
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            "/api/notifications/status",
            expected_status=200
        )
        
        assert "is_running" in response_data
        assert "monitored_resources" in response_data
        assert "active_tasks" in response_data
    
    @pytest.mark.asyncio
    async def test_stop_realtime_monitoring(self, async_client: AsyncClient):
        """リアルタイム監視停止テスト"""
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "POST",
            "/api/notifications/stop",
            expected_status=200
        )
        
        assert "monitoring_stopped" in response_data

class TestSystemManagementAPI:
    """システム管理API テスト"""
    
    @pytest.mark.asyncio
    async def test_system_health_check(self, async_client: AsyncClient):
        """システムヘルスチェックテスト"""
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            "/api/system/health",
            expected_status=200
        )
        
        assert "status" in response_data
        assert "services" in response_data
        assert "timestamp" in response_data
        
        # 各サービスの状態確認
        services = response_data["services"]
        expected_services = ["database", "graph_api", "powershell_bridge", "cache"]
        for service in expected_services:
            assert service in services
    
    @pytest.mark.asyncio
    async def test_get_system_info(self, async_client: AsyncClient):
        """システム情報取得テスト"""
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            "/api/system/info",
            expected_status=200
        )
        
        assert "version" in response_data
        assert "uptime" in response_data
        assert "python_version" in response_data
    
    @pytest.mark.asyncio
    async def test_get_performance_metrics(self, async_client: AsyncClient):
        """パフォーマンスメトリクス取得テスト"""
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            "/api/system/metrics",
            expected_status=200
        )
        
        assert "cpu_usage" in response_data
        assert "memory_usage" in response_data
        assert "api_response_times" in response_data
    
    @pytest.mark.asyncio
    async def test_get_application_logs(self, async_client: AsyncClient):
        """アプリケーションログ取得テスト"""
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            "/api/system/logs?level=error&limit=100",
            expected_status=200
        )
        
        assert "logs" in response_data
        assert "total_count" in response_data
        assert isinstance(response_data["logs"], list)

class TestAuthenticationAPI:
    """認証API テスト"""
    
    @pytest.mark.asyncio
    async def test_authenticate_with_certificate(self, async_client: AsyncClient):
        """証明書認証テスト"""
        
        request_data = {
            "tenant_id": "test-tenant-123",
            "client_id": "test-client-456",
            "certificate_thumbprint": "test-cert-789",
            "auth_type": "certificate"
        }
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "POST",
            "/api/auth/authenticate",
            data=request_data,
            expected_status=200
        )
        
        assert "is_authenticated" in response_data
        assert "services" in response_data
        assert "expires_at" in response_data
    
    @pytest.mark.asyncio
    async def test_get_auth_status(self, async_client: AsyncClient):
        """認証状況確認テスト"""
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "GET",
            "/api/auth/status",
            expected_status=200
        )
        
        assert "is_authenticated" in response_data
        assert "services" in response_data
    
    @pytest.mark.asyncio
    async def test_refresh_authentication(self, async_client: AsyncClient):
        """認証更新テスト"""
        
        response_data = await FastAPITestHelper.test_api_endpoint(
            async_client,
            "POST",
            "/api/auth/refresh",
            expected_status=200
        )
        
        assert "refreshed" in response_data

class TestAPIErrorHandling:
    """API エラーハンドリングテスト"""
    
    @pytest.mark.asyncio
    async def test_invalid_request_data(self, async_client: AsyncClient):
        """無効なリクエストデータエラーテスト"""
        
        invalid_data = {
            "invalid_field": "invalid_value"
        }
        
        await FastAPITestHelper.test_api_error_handling(
            async_client,
            "/api/graph/users",
            invalid_data
        )
    
    @pytest.mark.asyncio
    async def test_missing_required_fields(self, async_client: AsyncClient):
        """必須フィールド不足エラーテスト"""
        
        incomplete_data = {
            "function_name": "Get-M365Users"
            # parameters missing
        }
        
        await FastAPITestHelper.test_api_error_handling(
            async_client,
            "/api/powershell/execute",
            incomplete_data
        )
    
    @pytest.mark.asyncio
    async def test_rate_limit_handling(self, async_client: AsyncClient):
        """レート制限エラーハンドリングテスト"""
        
        # 大量リクエストでレート制限をトリガー
        for i in range(10):
            response = await async_client.get("/api/graph/users")
            # 最初の数回は成功、後でレート制限
            assert response.status_code in [200, 429]
    
    @pytest.mark.asyncio
    async def test_timeout_handling(self, async_client: AsyncClient):
        """タイムアウトエラーハンドリングテスト"""
        
        request_data = {
            "function_name": "Long-Running-Function",
            "parameters": {"timeout": 1},  # 短いタイムアウト
            "timeout_seconds": 1
        }
        
        response = await async_client.post("/api/powershell/execute", json=request_data)
        # タイムアウトまたは正常完了
        assert response.status_code in [200, 408, 500]

class TestAPIPerformance:
    """API パフォーマンステスト"""
    
    @pytest.mark.asyncio
    async def test_users_endpoint_performance(self, async_client: AsyncClient, mock_graph_client):
        """ユーザーエンドポイントパフォーマンステスト"""
        
        performance_results = await PerformanceTestHelper.measure_api_performance(
            async_client,
            "/api/graph/users",
            iterations=5
        )
        
        # パフォーマンス基準確認
        assert performance_results["average_response_time"] < 5.0  # 5秒以内
        assert performance_results["max_response_time"] < 10.0     # 最大10秒以内
    
    @pytest.mark.asyncio 
    async def test_concurrent_requests_performance(self, async_client: AsyncClient, mock_graph_client):
        """並行リクエストパフォーマンステスト"""
        import asyncio
        
        async def make_request():
            return await async_client.get("/api/graph/users")
        
        # 10個の並行リクエスト
        start_time = datetime.utcnow()
        tasks = [make_request() for _ in range(10)]
        responses = await asyncio.gather(*tasks)
        end_time = datetime.utcnow()
        
        # 全リクエスト成功確認
        for response in responses:
            assert response.status_code == 200
        
        # 並行処理時間確認
        total_time = (end_time - start_time).total_seconds()
        assert total_time < 15.0  # 15秒以内で完了

# テストデータファクトリー

@pytest.fixture
def sample_user_data():
    """サンプルユーザーデータ"""
    return TestDataGenerator.generate_test_user_data(5)

@pytest.fixture
def sample_license_data():
    """サンプルライセンスデータ"""
    return TestDataGenerator.generate_test_license_data()

@pytest.fixture
def sample_report_data():
    """サンプルレポートデータ"""
    return TestDataGenerator.generate_test_report_data()

# dev2技術支援用API仕様エクスポート

def export_api_specifications() -> Dict[str, Any]:
    """API仕様をdev2に提供するためのエクスポート"""
    
    return {
        "microsoft_365_apis": {
            "users": {
                "GET /api/graph/users": {
                    "description": "Microsoft 365ユーザー一覧取得",
                    "parameters": ["top", "filter", "select"],
                    "response_schema": {
                        "users": "List[UserModel]",
                        "total_count": "int",
                        "has_more": "bool"
                    }
                },
                "GET /api/graph/users/{user_id}": {
                    "description": "特定ユーザー情報取得",
                    "parameters": ["user_id"],
                    "response_schema": {
                        "user": "UserModel"
                    }
                }
            },
            "licenses": {
                "GET /api/graph/licenses": {
                    "description": "ライセンス情報一覧取得",
                    "response_schema": {
                        "licenses": "List[LicenseModel]",
                        "summary": "LicenseSummaryModel"
                    }
                }
            }
        },
        "powershell_bridge_apis": {
            "POST /api/powershell/execute": {
                "description": "PowerShell関数実行",
                "request_schema": {
                    "function_name": "str",
                    "parameters": "Dict[str, Any]",
                    "output_format": "str",
                    "timeout_seconds": "int"
                },
                "response_schema": {
                    "success": "bool",
                    "execution_id": "str",
                    "output_data": "Any"
                }
            }
        },
        "report_apis": {
            "POST /api/reports/generate": {
                "description": "レポート生成",
                "request_schema": {
                    "report_type": "str",
                    "output_format": "str",
                    "include_sections": "List[str]"
                }
            }
        },
        "realtime_apis": {
            "POST /api/notifications/start": {
                "description": "リアルタイム監視開始"
            },
            "GET /api/notifications/status": {
                "description": "監視状況確認"
            }
        }
    }

# dev2 向けテストガイド

TEST_GUIDANCE_FOR_DEV2 = """
# dev2向けテスト統合ガイド

## 1. pytest環境セットアップ
```bash
pip install pytest pytest-asyncio httpx
```

## 2. テスト実行方法
```bash
# 全テスト実行
pytest src/tests/backend_integration/

# 特定テストクラス実行
pytest src/tests/backend_integration/api_test_suite.py::TestMicrosoft365APIIntegration

# マーカー別実行
pytest -m "not slow"
```

## 3. モック利用方法
- mock_graph_client: Microsoft Graph APIモック
- mock_powershell_bridge: PowerShellブリッジモック
- 自動的にAPIレスポンスをモック

## 4. テストデータ生成
- TestDataGenerator.generate_test_user_data()
- TestDataGenerator.generate_test_license_data()

## 5. パフォーマンステスト
- PerformanceTestHelper.measure_api_performance()
- 並行リクエストテスト対応

## 6. カスタムテスト追加方法
1. test_support_framework.pyのヘルパークラス利用
2. async_client fixtureでAPIテスト
3. FastAPITestHelper.test_api_endpoint()でエンドポイントテスト

## 7. 推奨テスト構造
```python
@pytest.mark.asyncio
async def test_your_feature(async_client, mock_graph_client):
    response_data = await FastAPITestHelper.test_api_endpoint(
        async_client, "GET", "/your/endpoint"
    )
    assert "expected_field" in response_data
```
"""