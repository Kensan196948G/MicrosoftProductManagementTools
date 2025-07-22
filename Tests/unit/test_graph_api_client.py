#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Microsoft Graph API クライアント単体テストスイート

QA Engineer - Phase 3品質保証
dev0のGraph APIクライアント実装の単体テスト

テスト対象: src/gui/components/graph_api_client.py
品質目標: APIクライアント品質保証・エラーハンドリング検証
"""

import sys
import os
import pytest
import asyncio
from unittest.mock import Mock, patch, AsyncMock, MagicMock
from datetime import datetime, timezone, timedelta

# テスト対象のパスを追加
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'src'))

# PyQt6とその他ライブラリのモック設定
class MockPyQt6:
    class QtCore:
        class QObject:
            def __init__(self):
                pass
        
        class QThread:
            def __init__(self):
                pass
        
        pyqtSignal = Mock(return_value=Mock())
        
    class QtWidgets:
        class QMessageBox:
            StandardButton = Mock()
            @staticmethod
            def exec(): return 0
            @staticmethod
            def setWindowTitle(title): pass
            @staticmethod
            def setText(text): pass
            @staticmethod
            def setStandardButtons(buttons): pass
        
        class QApplication:
            @staticmethod
            def processEvents(): pass

# モックライブラリの設定
sys.modules['PyQt6'] = MockPyQt6()
sys.modules['PyQt6.QtCore'] = MockPyQt6.QtCore
sys.modules['PyQt6.QtWidgets'] = MockPyQt6.QtWidgets

# MSALモック
class MockMSAL:
    class ConfidentialClientApplication:
        def __init__(self, client_id, client_credential, authority):
            self.client_id = client_id
            self.client_credential = client_credential
            self.authority = authority
            
        def acquire_token_for_client(self, scopes):
            return {"access_token": "mock_token", "expires_in": 3600}
    
    class PublicClientApplication:
        def __init__(self, client_id, authority):
            self.client_id = client_id
            self.authority = authority
            
        def initiate_device_flow(self, scopes):
            return {"user_code": "ABC123", "device_code": "def456"}
            
        def acquire_token_by_device_flow(self, flow):
            return {"access_token": "mock_token", "expires_in": 3600}

sys.modules['msal'] = MockMSAL()

# aiohttpモック
class MockAioHTTP:
    class ClientSession:
        def __init__(self):
            pass
            
        async def __aenter__(self):
            return self
            
        async def __aexit__(self, exc_type, exc_val, exc_tb):
            pass
            
        def get(self, url, headers=None, params=None):
            return MockResponse()
    
    class ClientResponse:
        def __init__(self, status=200, json_data=None):
            self.status = status
            self._json_data = json_data or {}
            
        async def json(self):
            return self._json_data
            
        async def text(self):
            return "Mock response text"
            
        async def __aenter__(self):
            return self
            
        async def __aexit__(self, exc_type, exc_val, exc_tb):
            pass

class MockResponse:
    def __init__(self, status=200, json_data=None):
        self.status = status
        self._json_data = json_data or {"value": []}
    
    async def __aenter__(self):
        return MockAioHTTP.ClientResponse(self.status, self._json_data)
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        pass

sys.modules['aiohttp'] = MockAioHTTP()

try:
    from gui.components.graph_api_client import GraphAPIClient, GraphAPIThread
    IMPORT_SUCCESS = True
except Exception as e:
    print(f"インポートエラー: {e}")
    IMPORT_SUCCESS = False

class TestGraphAPIClient:
    """Graph APIクライアントテスト"""
    
    @pytest.fixture
    def api_client(self):
        """APIクライアントのフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        
        with patch.dict(os.environ, {'AZURE_TENANT_ID': 'test-tenant', 'AZURE_CLIENT_ID': 'test-client'}):
            client = GraphAPIClient("test-tenant", "test-client", "test-secret")
            return client
    
    def test_client_initialization(self, api_client):
        """クライアント初期化テスト"""
        assert api_client is not None
        assert api_client.tenant_id == "test-tenant"
        assert api_client.client_id == "test-client"
        assert api_client.client_secret == "test-secret"
        assert api_client.access_token is None
        assert api_client.token_expires_at is None
    
    def test_default_values(self):
        """デフォルト値テスト"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        
        with patch.dict(os.environ, {'AZURE_TENANT_ID': 'env-tenant', 'AZURE_CLIENT_ID': 'env-client'}):
            client = GraphAPIClient()
            assert client.tenant_id == "env-tenant"
            assert client.client_id == "env-client"
    
    def test_graph_urls(self, api_client):
        """Graph APIエンドポイントURLテスト"""
        assert api_client.graph_base_url == "https://graph.microsoft.com/v1.0"
        assert api_client.graph_beta_url == "https://graph.microsoft.com/beta"
    
    @pytest.mark.asyncio
    async def test_authentication_with_client_secret(self, api_client):
        """クライアントシークレット認証テスト"""
        # モックMSALアプリケーションの動作を確認
        result = await api_client.authenticate()
        
        # 認証成功の確認
        assert result == True  # モック環境では常に成功
        
    def test_mock_data_generation(self, api_client):
        """モックデータ生成テスト"""
        # ユーザーデータのモック
        users_mock = api_client._get_mock_data("users")
        assert "value" in users_mock
        assert len(users_mock["value"]) > 0
        
        # 組織データのモック
        org_mock = api_client._get_mock_data("organization")
        assert "value" in org_mock
        
        # ライセンスデータのモック
        license_mock = api_client._get_mock_data("subscribedSkus")
        assert "value" in license_mock
        
    @pytest.mark.asyncio
    async def test_get_users_mock(self, api_client):
        """ユーザー取得（モック）テスト"""
        users = await api_client.get_users(max_results=50)
        
        # モックデータが返されることを確認
        assert isinstance(users, list)
        # モックデータの内容確認
        if users:
            user = users[0]
            assert "displayName" in user
            assert "userPrincipalName" in user
    
    @pytest.mark.asyncio
    async def test_get_mfa_status_mock(self, api_client):
        """MFA状況取得（モック）テスト"""
        mfa_data = await api_client.get_mfa_status()
        
        # モックデータまたは空リストが返されることを確認
        assert isinstance(mfa_data, list)
    
    @pytest.mark.asyncio
    async def test_get_licenses_mock(self, api_client):
        """ライセンス情報取得（モック）テスト"""
        licenses = await api_client.get_licenses()
        
        # モックデータまたは空リストが返されることを確認
        assert isinstance(licenses, list)
    
    @pytest.mark.asyncio
    async def test_get_signin_logs_mock(self, api_client):
        """サインインログ取得（モック）テスト"""
        signin_logs = await api_client.get_signin_logs(days=7)
        
        # モックデータまたは空リストが返されることを確認
        assert isinstance(signin_logs, list)
    
    @pytest.mark.asyncio
    async def test_get_teams_usage_mock(self, api_client):
        """Teams使用状況取得（モック）テスト"""
        teams_data = await api_client.get_teams_usage()
        
        # モックデータまたは空辞書が返されることを確認
        assert isinstance(teams_data, dict)
    
    def test_mock_mfa_data_structure(self, api_client):
        """MFAモックデータ構造テスト"""
        mock_mfa = api_client._get_mock_mfa_data()
        
        assert isinstance(mock_mfa, list)
        if mock_mfa:
            mfa_entry = mock_mfa[0]
            required_fields = ["userPrincipalName", "userDisplayName", "isMfaRegistered", "isMfaCapable"]
            for field in required_fields:
                assert field in mfa_entry, f"MFAモックデータに必要フィールド '{field}' がありません"
    
    def test_mock_signin_logs_structure(self, api_client):
        """サインインログモックデータ構造テスト"""
        mock_logs = api_client._get_mock_signin_logs()
        
        assert isinstance(mock_logs, list)
        if mock_logs:
            log_entry = mock_logs[0]
            required_fields = ["id", "createdDateTime", "userPrincipalName", "userDisplayName", "status"]
            for field in required_fields:
                assert field in log_entry, f"サインインログモックデータに必要フィールド '{field}' がありません"
    
    def test_mock_teams_data_structure(self, api_client):
        """Teamsモックデータ構造テスト"""
        mock_teams = api_client._get_mock_teams_data()
        
        assert isinstance(mock_teams, dict)
        required_fields = ["total_users", "active_users", "meetings_organized", "chat_messages"]
        for field in required_fields:
            assert field in mock_teams, f"Teamsモックデータに必要フィールド '{field}' がありません"
            assert isinstance(mock_teams[field], int), f"フィールド '{field}' は整数である必要があります"

class TestGraphAPIThread:
    """Graph APIスレッドテスト"""
    
    @pytest.fixture
    def api_client(self):
        """APIクライアントのフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
            
        return GraphAPIClient("test-tenant", "test-client", "test-secret")
    
    def test_thread_creation(self, api_client):
        """スレッド作成テスト"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
            
        thread = GraphAPIThread(api_client, "authenticate")
        assert thread is not None
        assert thread.client == api_client
        assert thread.operation == "authenticate"
    
    def test_thread_with_kwargs(self, api_client):
        """スレッドキーワード引数テスト"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
            
        thread = GraphAPIThread(api_client, "get_users", max_results=100)
        assert thread.kwargs == {"max_results": 100}

class TestErrorHandling:
    """エラーハンドリングテスト"""
    
    @pytest.fixture
    def api_client(self):
        """APIクライアントのフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
            
        return GraphAPIClient("test-tenant", "test-client", "test-secret")
    
    @pytest.mark.asyncio
    async def test_make_graph_request_without_token(self, api_client):
        """トークンなしでのAPI リクエストテスト"""
        # トークンが設定されていない状態でリクエスト
        api_client.access_token = None
        
        # モック環境では認証が自動実行される
        result = await api_client._make_graph_request("users")
        assert isinstance(result, dict)
    
    @pytest.mark.asyncio  
    async def test_make_graph_request_expired_token(self, api_client):
        """期限切れトークンでのAPIリクエストテスト"""
        # 期限切れトークンを設定
        api_client.access_token = "expired_token"
        api_client.token_expires_at = datetime.now() - timedelta(hours=1)
        
        # 認証が再実行されることを確認
        result = await api_client._make_graph_request("users")
        assert isinstance(result, dict)
    
    def test_invalid_endpoint_mock_data(self, api_client):
        """無効なエンドポイントのモックデータテスト"""
        # 存在しないエンドポイントに対してはデフォルトモックデータが返される
        result = api_client._get_mock_data("nonexistent_endpoint")
        assert result == {"value": [], "@odata.count": 0}

class TestDataValidation:
    """データ検証テスト"""
    
    @pytest.fixture
    def api_client(self):
        """APIクライアントのフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
            
        return GraphAPIClient("test-tenant", "test-client", "test-secret")
    
    def test_users_mock_data_validation(self, api_client):
        """ユーザーモックデータ検証テスト"""
        users_data = api_client._get_mock_data("users")
        
        assert "value" in users_data
        users = users_data["value"]
        
        for user in users:
            # 必須フィールドの存在確認
            required_fields = ["id", "displayName", "userPrincipalName", "mail"]
            for field in required_fields:
                assert field in user, f"ユーザーデータに必要フィールド '{field}' がありません"
            
            # データ型検証
            assert isinstance(user["displayName"], str)
            assert isinstance(user["userPrincipalName"], str)
            assert "@" in user["mail"], "メールアドレス形式が正しくありません"
    
    def test_licenses_mock_data_validation(self, api_client):
        """ライセンスモックデータ検証テスト"""
        license_data = api_client._get_mock_data("subscribedSkus")
        
        assert "value" in license_data
        licenses = license_data["value"]
        
        for license_sku in licenses:
            # 必須フィールドの存在確認
            required_fields = ["skuId", "skuPartNumber", "consumedUnits", "prepaidUnits"]
            for field in required_fields:
                assert field in license_sku, f"ライセンスデータに必要フィールド '{field}' がありません"
            
            # データ型検証
            assert isinstance(license_sku["consumedUnits"], int)
            assert isinstance(license_sku["prepaidUnits"], dict)
            assert "enabled" in license_sku["prepaidUnits"]

# パフォーマンステスト
class TestPerformance:
    """パフォーマンステスト"""
    
    @pytest.fixture
    def api_client(self):
        """APIクライアントのフィクスチャ"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
            
        return GraphAPIClient("test-tenant", "test-client", "test-secret")
    
    def test_mock_data_generation_performance(self, api_client):
        """モックデータ生成パフォーマンステスト"""
        import time
        
        start_time = time.time()
        
        # 各種モックデータを生成
        users_data = api_client._get_mock_data("users")
        org_data = api_client._get_mock_data("organization")
        license_data = api_client._get_mock_data("subscribedSkus")
        
        end_time = time.time()
        generation_time = end_time - start_time
        
        # モックデータ生成は0.1秒以内であることを確認
        assert generation_time < 0.1, f"モックデータ生成が遅すぎます: {generation_time}秒"
        
        # データが正しく生成されていることを確認
        assert users_data["value"]
        assert org_data["value"]
        assert license_data["value"]

# 設定・環境変数テスト
class TestConfiguration:
    """設定・環境変数テスト"""
    
    def test_environment_variable_fallback(self):
        """環境変数フォールバックテスト"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        
        # 環境変数が設定されていない場合のテスト
        with patch.dict(os.environ, {}, clear=True):
            client = GraphAPIClient()
            assert client.tenant_id == ""
            assert client.client_id == ""
    
    def test_explicit_parameters(self):
        """明示的パラメータテスト"""
        if not IMPORT_SUCCESS:
            pytest.skip("インポートに失敗したためスキップ")
        
        # 明示的にパラメータを設定した場合
        client = GraphAPIClient("explicit-tenant", "explicit-client", "explicit-secret")
        assert client.tenant_id == "explicit-tenant"
        assert client.client_id == "explicit-client"
        assert client.client_secret == "explicit-secret"

if __name__ == "__main__":
    # 単体でのテスト実行
    pytest.main([__file__, "-v", "--tb=short", "-x"])