"""
Microsoft Graph API統合テスト（モック対応）
Dev1 - Test/QA Developer による基盤構築

Microsoft Graph APIとの統合機能をモック環境でテスト
"""
import sys
import os
import json
import asyncio
from pathlib import Path
from typing import Dict, List, Any, Optional, Union
from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch, AsyncMock
import uuid

import pytest
import requests_mock
import pandas as pd
from msal import ClientApplication

# プロジェクトルートをパスに追加
PROJECT_ROOT = Path(__file__).parent.parent.parent.absolute()
sys.path.insert(0, str(PROJECT_ROOT))


class MockGraphClient:
    """Microsoft Graph APIクライアントのモック"""
    
    def __init__(self, tenant_id: str, client_id: str, client_secret: str):
        self.tenant_id = tenant_id
        self.client_id = client_id
        self.client_secret = client_secret
        self.base_url = "https://graph.microsoft.com/v1.0"
        self._access_token = None
        self._token_expires_at = None
        
        # モックデータ保存
        self.mock_users = self._generate_mock_users(100)
        self.mock_licenses = self._generate_mock_licenses()
        self.mock_usage_reports = self._generate_mock_usage_reports()
        self.mock_groups = self._generate_mock_groups()
        
        # API呼び出し履歴
        self.api_call_history = []
    
    def _generate_mock_users(self, count: int = 100) -> List[Dict[str, Any]]:
        """モックユーザーデータ生成"""
        users = []
        departments = ["IT部門", "営業部", "管理部", "開発部", "人事部", "法務部", "財務部"]
        job_titles = ["Manager", "Senior Member", "Member", "Junior Member", "Director"]
        
        for i in range(count):
            user_id = str(uuid.uuid4())
            user_principal_name = f"testuser{i:03d}@contoso.com"
            
            users.append({
                "@odata.context": f"{self.base_url}/$metadata#users/$entity",
                "id": user_id,
                "businessPhones": [f"+81-3-1234-{i:04d}"],
                "displayName": f"テストユーザー {i:03d}",
                "givenName": f"太郎{i:03d}",
                "surname": f"田中",
                "jobTitle": job_titles[i % len(job_titles)],
                "mail": user_principal_name,
                "mobilePhone": f"+81-90-1234-{i:04d}",
                "officeLocation": f"東京オフィス {(i % 10) + 1}F",
                "preferredLanguage": "ja-JP",
                "userPrincipalName": user_principal_name,
                "accountEnabled": i % 20 != 0,  # 5%は無効化
                "department": departments[i % len(departments)],
                "employeeId": f"EMP{i:06d}",
                "createdDateTime": (datetime.now() - timedelta(days=i*5)).isoformat() + "Z",
                "lastSignInDateTime": (
                    datetime.now() - timedelta(hours=i*2)
                ).isoformat() + "Z" if i % 10 != 0 else None,
                "signInActivity": {
                    "lastSignInDateTime": (
                        datetime.now() - timedelta(hours=i*2)
                    ).isoformat() + "Z" if i % 10 != 0 else None,
                    "lastSignInRequestId": str(uuid.uuid4()) if i % 10 != 0 else None
                },
                "assignedLicenses": [
                    {
                        "disabledPlans": [],
                        "skuId": self._get_license_sku_id(i % 3)
                    }
                ],
                "usageLocation": "JP",
                "companyName": "Contoso Corporation",
                "country": "Japan"
            })
        
        return users
    
    def _generate_mock_licenses(self) -> List[Dict[str, Any]]:
        """モックライセンスデータ生成"""
        return [
            {
                "@odata.context": f"{self.base_url}/$metadata#subscribedSkus",
                "id": str(uuid.uuid4()),
                "skuId": "6fd2c87f-b296-42f0-b197-1e91e994b900",
                "skuPartNumber": "ENTERPRISEPACK",
                "servicePlans": [
                    {
                        "servicePlanId": str(uuid.uuid4()),
                        "servicePlanName": "EXCHANGE_S_ENTERPRISE",
                        "provisioningStatus": "Success",
                        "appliesTo": "User"
                    },
                    {
                        "servicePlanId": str(uuid.uuid4()),
                        "servicePlanName": "TEAMS1",
                        "provisioningStatus": "Success", 
                        "appliesTo": "User"
                    }
                ],
                "prepaidUnits": {
                    "enabled": 50,
                    "suspended": 0,
                    "warning": 0
                },
                "consumedUnits": 42,
                "capabilityStatus": "Enabled"
            },
            {
                "@odata.context": f"{self.base_url}/$metadata#subscribedSkus",
                "id": str(uuid.uuid4()),
                "skuId": "c7df2760-2c81-4ef7-b578-5b5392b571df",
                "skuPartNumber": "ENTERPRISEPREMIUM",
                "servicePlans": [
                    {
                        "servicePlanId": str(uuid.uuid4()),
                        "servicePlanName": "EXCHANGE_S_ENTERPRISE",
                        "provisioningStatus": "Success",
                        "appliesTo": "User"
                    },
                    {
                        "servicePlanId": str(uuid.uuid4()),
                        "servicePlanName": "TEAMS1",
                        "provisioningStatus": "Success",
                        "appliesTo": "User"
                    },
                    {
                        "servicePlanId": str(uuid.uuid4()),
                        "servicePlanName": "THREAT_INTELLIGENCE",
                        "provisioningStatus": "Success",
                        "appliesTo": "User"
                    }
                ],
                "prepaidUnits": {
                    "enabled": 25,
                    "suspended": 0,
                    "warning": 0
                },
                "consumedUnits": 18,
                "capabilityStatus": "Enabled"
            }
        ]
    
    def _generate_mock_usage_reports(self) -> Dict[str, Any]:
        """モック使用状況レポート生成"""
        return {
            "@odata.context": f"{self.base_url}/$metadata#reports/getOffice365ActiveUserDetail(period='D30')",
            "value": [
                {
                    "reportRefreshDate": datetime.now().strftime("%Y-%m-%d"),
                    "userPrincipalName": f"testuser{i:03d}@contoso.com",
                    "displayName": f"テストユーザー {i:03d}",
                    "isDeleted": False,
                    "deletedDate": None,
                    "lastActivityDate": (datetime.now() - timedelta(days=i)).strftime("%Y-%m-%d"),
                    "exchangeLastActivityDate": (datetime.now() - timedelta(days=i+1)).strftime("%Y-%m-%d"),
                    "exchangeLastActivityDate": (datetime.now() - timedelta(days=i+1)).strftime("%Y-%m-%d"),
                    "oneDriveLastActivityDate": (datetime.now() - timedelta(days=i+2)).strftime("%Y-%m-%d"),
                    "sharePointLastActivityDate": (datetime.now() - timedelta(days=i+3)).strftime("%Y-%m-%d"),
                    "skypeForBusinessLastActivityDate": None,
                    "teamsLastActivityDate": (datetime.now() - timedelta(days=i)).strftime("%Y-%m-%d"),
                    "yammerLastActivityDate": None,
                    "assignedProducts": [
                        "OFFICE 365 E3" if i % 2 == 0 else "MICROSOFT 365 E5"
                    ],
                    "exchangeLicenseAssignDate": (datetime.now() - timedelta(days=i*10)).strftime("%Y-%m-%d"),
                    "oneDriveLicenseAssignDate": (datetime.now() - timedelta(days=i*10)).strftime("%Y-%m-%d"),
                    "sharePointLicenseAssignDate": (datetime.now() - timedelta(days=i*10)).strftime("%Y-%m-%d"),
                    "teamsLicenseAssignDate": (datetime.now() - timedelta(days=i*10)).strftime("%Y-%m-%d")
                }
                for i in range(50)
            ]
        }
    
    def _generate_mock_groups(self) -> List[Dict[str, Any]]:
        """モックグループデータ生成"""
        group_types = ["Security", "Distribution", "Microsoft365"]
        return [
            {
                "@odata.context": f"{self.base_url}/$metadata#groups/$entity",
                "id": str(uuid.uuid4()),
                "displayName": f"テストグループ {i:02d}",
                "groupTypes": [group_types[i % len(group_types)]],
                "mailEnabled": i % 2 == 0,
                "mailNickname": f"testgroup{i:02d}",
                "securityEnabled": True,
                "createdDateTime": (datetime.now() - timedelta(days=i*7)).isoformat() + "Z",
                "description": f"テスト用グループ {i:02d} の説明",
                "visibility": "Private" if i % 3 == 0 else "Public"
            }
            for i in range(20)
        ]
    
    def _get_license_sku_id(self, index: int) -> str:
        """ライセンスSKU ID取得"""
        sku_ids = [
            "6fd2c87f-b296-42f0-b197-1e91e994b900",  # Office 365 E3
            "c7df2760-2c81-4ef7-b578-5b5392b571df",  # Microsoft 365 E5
            "18181a46-0d4e-45cd-891e-60aabd171b4e"   # Office 365 E1
        ]
        return sku_ids[index % len(sku_ids)]
    
    async def get_access_token(self) -> str:
        """アクセストークン取得（モック）"""
        if self._access_token and self._token_expires_at:
            if datetime.now() < self._token_expires_at:
                return self._access_token
        
        # モックトークン生成
        self._access_token = f"mock_token_{uuid.uuid4().hex}"
        self._token_expires_at = datetime.now() + timedelta(hours=1)
        
        self.api_call_history.append({
            "endpoint": "https://login.microsoftonline.com/token",
            "method": "POST",
            "timestamp": datetime.now().isoformat(),
            "response_status": 200
        })
        
        return self._access_token
    
    async def get_users(self, select: Optional[List[str]] = None, 
                       filter_query: Optional[str] = None,
                       top: Optional[int] = None) -> Dict[str, Any]:
        """ユーザー一覧取得"""
        await self.get_access_token()
        
        self.api_call_history.append({
            "endpoint": f"{self.base_url}/users",
            "method": "GET",
            "parameters": {
                "select": select,
                "filter": filter_query,
                "top": top
            },
            "timestamp": datetime.now().isoformat(),
            "response_status": 200
        })
        
        users = self.mock_users.copy()
        
        # フィルタリング適用
        if filter_query:
            # 簡単なフィルタリング実装
            if "accountEnabled eq true" in filter_query:
                users = [u for u in users if u.get("accountEnabled", True)]
            elif "accountEnabled eq false" in filter_query:
                users = [u for u in users if not u.get("accountEnabled", True)]
        
        # TOP適用
        if top:
            users = users[:top]
        
        # SELECT適用
        if select:
            filtered_users = []
            for user in users:
                filtered_user = {}
                for field in select:
                    if field in user:
                        filtered_user[field] = user[field]
                filtered_users.append(filtered_user)
            users = filtered_users
        
        return {
            "@odata.context": f"{self.base_url}/$metadata#users",
            "@odata.count": len(self.mock_users),
            "value": users
        }
    
    async def get_licenses(self) -> Dict[str, Any]:
        """ライセンス情報取得"""
        await self.get_access_token()
        
        self.api_call_history.append({
            "endpoint": f"{self.base_url}/subscribedSkus",
            "method": "GET",
            "timestamp": datetime.now().isoformat(),
            "response_status": 200
        })
        
        return {
            "@odata.context": f"{self.base_url}/$metadata#subscribedSkus",
            "value": self.mock_licenses
        }
    
    async def get_usage_reports(self, report_type: str = "getOffice365ActiveUserDetail",
                               period: str = "D30") -> Dict[str, Any]:
        """使用状況レポート取得"""
        await self.get_access_token()
        
        self.api_call_history.append({
            "endpoint": f"{self.base_url}/reports/{report_type}(period='{period}')",
            "method": "GET",
            "parameters": {
                "report_type": report_type,
                "period": period
            },
            "timestamp": datetime.now().isoformat(),
            "response_status": 200
        })
        
        return self.mock_usage_reports
    
    async def get_groups(self, select: Optional[List[str]] = None,
                        filter_query: Optional[str] = None) -> Dict[str, Any]:
        """グループ一覧取得"""
        await self.get_access_token()
        
        self.api_call_history.append({
            "endpoint": f"{self.base_url}/groups",
            "method": "GET",
            "parameters": {
                "select": select,
                "filter": filter_query
            },
            "timestamp": datetime.now().isoformat(),
            "response_status": 200
        })
        
        groups = self.mock_groups.copy()
        
        # SELECT適用
        if select:
            filtered_groups = []
            for group in groups:
                filtered_group = {}
                for field in select:
                    if field in group:
                        filtered_group[field] = group[field]
                filtered_groups.append(filtered_group)
            groups = filtered_groups
        
        return {
            "@odata.context": f"{self.base_url}/$metadata#groups",
            "value": groups
        }
    
    def get_api_call_count(self) -> int:
        """API呼び出し回数取得"""
        return len(self.api_call_history)
    
    def get_last_api_call(self) -> Optional[Dict[str, Any]]:
        """最後のAPI呼び出し情報取得"""
        return self.api_call_history[-1] if self.api_call_history else None


@pytest.fixture(scope="function")
def mock_graph_client():
    """Microsoft Graph APIクライアントモックのフィクスチャ"""
    return MockGraphClient(
        tenant_id="test-tenant-12345",
        client_id="test-client-67890", 
        client_secret="test-secret-abcdef"
    )


@pytest.fixture(scope="function")
def requests_mock_graph():
    """requests-mockを使用したGraph APIモック"""
    with requests_mock.Mocker() as m:
        # 認証エンドポイント
        m.post(
            "https://login.microsoftonline.com/test-tenant-12345/oauth2/v2.0/token",
            json={
                "access_token": "mock_access_token_12345",
                "token_type": "Bearer",
                "expires_in": 3600,
                "scope": "https://graph.microsoft.com/.default"
            }
        )
        
        # ユーザーエンドポイント
        m.get(
            "https://graph.microsoft.com/v1.0/users",
            json={
                "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#users",
                "value": [
                    {
                        "id": "test-user-001",
                        "displayName": "テストユーザー 001",
                        "userPrincipalName": "testuser001@contoso.com",
                        "accountEnabled": True
                    }
                ]
            }
        )
        
        # ライセンスエンドポイント
        m.get(
            "https://graph.microsoft.com/v1.0/subscribedSkus",
            json={
                "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#subscribedSkus",
                "value": [
                    {
                        "skuId": "6fd2c87f-b296-42f0-b197-1e91e994b900",
                        "skuPartNumber": "ENTERPRISEPACK",
                        "consumedUnits": 42,
                        "prepaidUnits": {"enabled": 50}
                    }
                ]
            }
        )
        
        yield m


class TestGraphClientAuthentication:
    """Graph APIクライアント認証テスト"""
    
    @pytest.mark.api
    @pytest.mark.unit
    @pytest.mark.asyncio
    async def test_access_token_acquisition(self, mock_graph_client):
        """アクセストークン取得テスト"""
        # 初期状態確認
        assert mock_graph_client._access_token is None
        
        # トークン取得
        token = await mock_graph_client.get_access_token()
        
        assert token is not None
        assert token.startswith("mock_token_")
        assert mock_graph_client._access_token == token
        assert mock_graph_client._token_expires_at is not None
    
    @pytest.mark.api
    @pytest.mark.unit
    @pytest.mark.asyncio
    async def test_token_caching(self, mock_graph_client):
        """トークンキャッシュ機能テスト"""
        # 最初のトークン取得
        token1 = await mock_graph_client.get_access_token()
        api_call_count1 = mock_graph_client.get_api_call_count()
        
        # 2回目のトークン取得（キャッシュ利用）
        token2 = await mock_graph_client.get_access_token()
        api_call_count2 = mock_graph_client.get_api_call_count()
        
        assert token1 == token2
        assert api_call_count1 == api_call_count2  # API呼び出し回数が増えない
    
    @pytest.mark.api
    @pytest.mark.unit
    @pytest.mark.asyncio
    async def test_token_expiration_handling(self, mock_graph_client):
        """トークン有効期限処理テスト"""
        # トークン取得
        await mock_graph_client.get_access_token()
        
        # トークン有効期限を過去に設定
        mock_graph_client._token_expires_at = datetime.now() - timedelta(minutes=1)
        
        # 新しいトークン取得
        new_token = await mock_graph_client.get_access_token()
        
        assert new_token != mock_graph_client._access_token  # 新しいトークンが生成される
        assert mock_graph_client.get_api_call_count() == 2  # 2回のAPI呼び出し


class TestGraphClientUserOperations:
    """Graph APIクライアント ユーザー操作テスト"""
    
    @pytest.mark.api
    @pytest.mark.integration
    @pytest.mark.asyncio
    async def test_get_all_users(self, mock_graph_client):
        """全ユーザー取得テスト"""
        result = await mock_graph_client.get_users()
        
        assert "@odata.context" in result
        assert "value" in result
        assert "@odata.count" in result
        assert len(result["value"]) == 100  # モックデータの全ユーザー数
        
        # 最後のAPI呼び出し確認
        last_call = mock_graph_client.get_last_api_call()
        assert last_call["endpoint"] == "https://graph.microsoft.com/v1.0/users"
        assert last_call["method"] == "GET"
    
    @pytest.mark.api
    @pytest.mark.unit
    @pytest.mark.asyncio
    async def test_get_users_with_filter(self, mock_graph_client):
        """フィルタ付きユーザー取得テスト"""
        # 有効なユーザーのみ取得
        result = await mock_graph_client.get_users(filter_query="accountEnabled eq true")
        
        assert "value" in result
        enabled_users = [u for u in result["value"] if u.get("accountEnabled", True)]
        assert len(enabled_users) == len(result["value"])  # 全て有効なユーザー
    
    @pytest.mark.api
    @pytest.mark.unit
    @pytest.mark.asyncio
    async def test_get_users_with_select(self, mock_graph_client):
        """SELECT句付きユーザー取得テスト"""
        select_fields = ["id", "displayName", "userPrincipalName"]
        result = await mock_graph_client.get_users(select=select_fields)
        
        assert "value" in result
        if result["value"]:
            user = result["value"][0]
            # 指定したフィールドのみ存在することを確認
            for field in select_fields:
                assert field in user
            # 指定していないフィールドは存在しない
            assert "jobTitle" not in user
            assert "department" not in user
    
    @pytest.mark.api
    @pytest.mark.unit
    @pytest.mark.asyncio
    async def test_get_users_with_top(self, mock_graph_client):
        """TOP句付きユーザー取得テスト"""
        top_count = 10
        result = await mock_graph_client.get_users(top=top_count)
        
        assert "value" in result
        assert len(result["value"]) == top_count


class TestGraphClientLicenseOperations:
    """Graph APIクライアント ライセンス操作テスト"""
    
    @pytest.mark.api
    @pytest.mark.integration
    @pytest.mark.asyncio
    async def test_get_licenses(self, mock_graph_client):
        """ライセンス情報取得テスト"""
        result = await mock_graph_client.get_licenses()
        
        assert "@odata.context" in result
        assert "value" in result
        assert len(result["value"]) == 2  # モックライセンス数
        
        # ライセンス構造確認
        license_data = result["value"][0]
        required_fields = ["skuId", "skuPartNumber", "consumedUnits", "prepaidUnits"]
        for field in required_fields:
            assert field in license_data
        
        assert "enabled" in license_data["prepaidUnits"]
    
    @pytest.mark.api
    @pytest.mark.unit
    @pytest.mark.asyncio
    async def test_license_consumption_calculation(self, mock_graph_client):
        """ライセンス消費率計算テスト"""
        result = await mock_graph_client.get_licenses()
        
        for license_data in result["value"]:
            consumed = license_data["consumedUnits"]
            enabled = license_data["prepaidUnits"]["enabled"]
            
            assert consumed <= enabled  # 消費数は有効数以下
            assert consumed >= 0  # 消費数は非負
            assert enabled > 0  # 有効数は正数
            
            consumption_rate = (consumed / enabled) * 100
            assert 0 <= consumption_rate <= 100  # 消費率は0-100%の範囲


class TestGraphClientUsageReports:
    """Graph APIクライアント 使用状況レポートテスト"""
    
    @pytest.mark.api
    @pytest.mark.integration
    @pytest.mark.asyncio
    async def test_get_usage_reports_default(self, mock_graph_client):
        """デフォルト使用状況レポート取得テスト"""
        result = await mock_graph_client.get_usage_reports()
        
        assert "@odata.context" in result
        assert "value" in result
        assert len(result["value"]) == 50  # モックデータのユーザー数
        
        # レポート構造確認
        report_entry = result["value"][0]
        required_fields = [
            "userPrincipalName", "displayName", "lastActivityDate",
            "exchangeLastActivityDate", "oneDriveLastActivityDate",
            "teamsLastActivityDate", "assignedProducts"
        ]
        for field in required_fields:
            assert field in report_entry
    
    @pytest.mark.api
    @pytest.mark.unit
    @pytest.mark.asyncio
    async def test_get_usage_reports_custom_period(self, mock_graph_client):
        """カスタム期間の使用状況レポート取得テスト"""
        result = await mock_graph_client.get_usage_reports(
            report_type="getOffice365ActiveUserDetail",
            period="D7"
        )
        
        assert "value" in result
        
        # API呼び出しパラメータ確認
        last_call = mock_graph_client.get_last_api_call()
        assert "D7" in last_call["endpoint"]
        assert last_call["parameters"]["period"] == "D7"


class TestGraphClientGroupOperations:
    """Graph APIクライアント グループ操作テスト"""
    
    @pytest.mark.api
    @pytest.mark.integration
    @pytest.mark.asyncio
    async def test_get_groups(self, mock_graph_client):
        """グループ一覧取得テスト"""
        result = await mock_graph_client.get_groups()
        
        assert "@odata.context" in result
        assert "value" in result
        assert len(result["value"]) == 20  # モックグループ数
        
        # グループ構造確認
        group = result["value"][0]
        required_fields = ["id", "displayName", "groupTypes", "mailEnabled", "securityEnabled"]
        for field in required_fields:
            assert field in group
    
    @pytest.mark.api
    @pytest.mark.unit
    @pytest.mark.asyncio
    async def test_get_groups_with_select(self, mock_graph_client):
        """SELECT句付きグループ取得テスト"""
        select_fields = ["id", "displayName", "groupTypes"]
        result = await mock_graph_client.get_groups(select=select_fields)
        
        assert "value" in result
        if result["value"]:
            group = result["value"][0]
            for field in select_fields:
                assert field in group
            # 指定していないフィールドは存在しない
            assert "description" not in group
            assert "createdDateTime" not in group


class TestGraphClientPerformance:
    """Graph APIクライアント パフォーマンステスト"""
    
    @pytest.mark.api
    @pytest.mark.performance
    @pytest.mark.asyncio
    async def test_concurrent_api_calls(self, mock_graph_client):
        """並行API呼び出しテスト"""
        import time
        
        start_time = time.time()
        
        # 複数のAPI呼び出しを並行実行
        tasks = [
            mock_graph_client.get_users(top=10),
            mock_graph_client.get_licenses(),
            mock_graph_client.get_groups(select=["id", "displayName"]),
            mock_graph_client.get_usage_reports(period="D7")
        ]
        
        results = await asyncio.gather(*tasks)
        
        end_time = time.time()
        execution_time = end_time - start_time
        
        # 全ての結果が正常に取得されていることを確認
        assert len(results) == 4
        for result in results:
            assert "value" in result or "@odata.context" in result
        
        # パフォーマンス確認（並行実行により高速化されている）
        assert execution_time < 2.0, f"並行API呼び出しが遅すぎます: {execution_time}秒"
        
        # API呼び出し履歴確認
        assert mock_graph_client.get_api_call_count() >= 5  # 認証 + 4つのAPI呼び出し
    
    @pytest.mark.api
    @pytest.mark.performance
    @pytest.mark.asyncio
    async def test_large_dataset_handling(self, mock_graph_client):
        """大量データ処理テスト"""
        import time
        
        # 大量のユーザーデータ生成（追加）
        additional_users = mock_graph_client._generate_mock_users(1000)
        mock_graph_client.mock_users.extend(additional_users)
        
        start_time = time.time()
        result = await mock_graph_client.get_users()
        end_time = time.time()
        
        processing_time = end_time - start_time
        
        assert len(result["value"]) == 1100  # 元の100 + 追加の1000
        assert processing_time < 5.0, f"大量データ処理が遅すぎます: {processing_time}秒"


class TestGraphClientErrorHandling:
    """Graph APIクライアント エラーハンドリングテスト"""
    
    @pytest.mark.api
    @pytest.mark.unit
    @pytest.mark.asyncio
    async def test_invalid_parameters_handling(self, mock_graph_client):
        """無効なパラメータ処理テスト"""
        # 無効なTOP値でもエラーにならないことを確認
        result = await mock_graph_client.get_users(top=0)
        assert "value" in result
        assert len(result["value"]) == 0
        
        # 無効なSELECTフィールドでもエラーにならないことを確認
        result = await mock_graph_client.get_users(select=["invalid_field"])
        assert "value" in result
    
    @pytest.mark.api
    @pytest.mark.unit
    def test_client_initialization_validation(self):
        """クライアント初期化時のバリデーションテスト"""
        # 有効な初期化
        client = MockGraphClient("tenant", "client", "secret")
        assert client.tenant_id == "tenant"
        assert client.client_id == "client"
        assert client.client_secret == "secret"
        
        # 空の値でも初期化できる（実際のアプリケーションではバリデーションが必要）
        client2 = MockGraphClient("", "", "")
        assert client2.tenant_id == ""


@pytest.mark.api
@pytest.mark.integration
class TestGraphClientDataValidation:
    """Graph APIクライアント データ検証テスト"""
    
    @pytest.mark.asyncio
    async def test_user_data_structure_validation(self, mock_graph_client):
        """ユーザーデータ構造検証テスト"""
        result = await mock_graph_client.get_users()
        
        for user in result["value"]:
            # 必須フィールド確認
            assert "id" in user
            assert "userPrincipalName" in user
            assert "displayName" in user
            
            # データ型確認
            assert isinstance(user["id"], str)
            assert isinstance(user["accountEnabled"], bool)
            
            # メールアドレス形式確認
            assert "@" in user["userPrincipalName"]
            assert user["userPrincipalName"].endswith("@contoso.com")
    
    @pytest.mark.asyncio
    async def test_license_data_structure_validation(self, mock_graph_client):
        """ライセンスデータ構造検証テスト"""
        result = await mock_graph_client.get_licenses()
        
        for license_info in result["value"]:
            # 必須フィールド確認
            assert "skuId" in license_info
            assert "skuPartNumber" in license_info
            assert "consumedUnits" in license_info
            assert "prepaidUnits" in license_info
            
            # データ型確認
            assert isinstance(license_info["consumedUnits"], int)
            assert isinstance(license_info["prepaidUnits"]["enabled"], int)
            
            # 論理的制約確認
            assert license_info["consumedUnits"] >= 0
            assert license_info["prepaidUnits"]["enabled"] >= 0


# 統合テスト実行用のヘルパー関数
async def run_full_graph_integration_test(mock_client: MockGraphClient) -> Dict[str, Any]:
    """完全なGraph API統合テスト実行"""
    results = {}
    
    # 認証テスト
    token = await mock_client.get_access_token()
    results["authentication"] = {"success": bool(token), "token_length": len(token)}
    
    # ユーザー取得テスト
    users = await mock_client.get_users(top=50)
    results["users"] = {
        "success": "value" in users,
        "count": len(users.get("value", [])),
        "has_required_fields": all("userPrincipalName" in u for u in users.get("value", []))
    }
    
    # ライセンス取得テスト
    licenses = await mock_client.get_licenses()
    results["licenses"] = {
        "success": "value" in licenses,
        "count": len(licenses.get("value", [])),
        "total_consumption": sum(l.get("consumedUnits", 0) for l in licenses.get("value", []))
    }
    
    # 使用状況レポートテスト
    usage_reports = await mock_client.get_usage_reports()
    results["usage_reports"] = {
        "success": "value" in usage_reports,
        "count": len(usage_reports.get("value", [])),
        "active_users": len([u for u in usage_reports.get("value", []) if u.get("lastActivityDate")])
    }
    
    # API呼び出し統計
    results["api_statistics"] = {
        "total_calls": mock_client.get_api_call_count(),
        "last_call_endpoint": mock_client.get_last_api_call()["endpoint"] if mock_client.api_call_history else None
    }
    
    return results


@pytest.mark.api
@pytest.mark.slow
@pytest.mark.asyncio
async def test_full_integration_workflow(mock_graph_client):
    """完全統合ワークフローテスト"""
    results = await run_full_graph_integration_test(mock_graph_client)
    
    # 認証成功確認
    assert results["authentication"]["success"]
    assert results["authentication"]["token_length"] > 20
    
    # ユーザー取得成功確認
    assert results["users"]["success"]
    assert results["users"]["count"] == 50
    assert results["users"]["has_required_fields"]
    
    # ライセンス取得成功確認
    assert results["licenses"]["success"]
    assert results["licenses"]["count"] == 2
    assert results["licenses"]["total_consumption"] > 0
    
    # 使用状況レポート成功確認
    assert results["usage_reports"]["success"]
    assert results["usage_reports"]["count"] == 50
    assert results["usage_reports"]["active_users"] >= 0
    
    # API統計確認
    assert results["api_statistics"]["total_calls"] >= 4
    assert results["api_statistics"]["last_call_endpoint"] is not None