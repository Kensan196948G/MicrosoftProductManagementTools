"""認証モジュールの単体テスト"""

import pytest
import asyncio
from unittest.mock import Mock, patch, MagicMock
from pathlib import Path
from datetime import datetime, timedelta
import json

from src.core.auth import AuthManager
from src.core.exceptions import AuthenticationError, ConfigurationError


class TestAuthManager:
    """認証マネージャーのテスト"""
    
    @pytest.fixture
    def auth_manager(self):
        """AuthManagerのフィクスチャ"""
        return AuthManager()
    
    @pytest.fixture
    def mock_config(self):
        """認証設定のモック"""
        return {
            "azure": {
                "client_id": "test_client_id",
                "client_secret": "test_client_secret",
                "tenant_id": "test_tenant_id",
                "certificate_path": "test_cert.pfx",
                "certificate_password": "test_password"
            }
        }
    
    def test_init_auth_manager(self, auth_manager):
        """認証マネージャーの初期化テスト"""
        assert auth_manager is not None
        assert auth_manager.access_token is None
        assert auth_manager.token_expiry is None
        assert auth_manager.authenticated is False
    
    @pytest.mark.asyncio
    async def test_certificate_auth_success(self, auth_manager):
        """証明書認証の成功テスト"""
        with patch('src.core.auth.AuthManager._validate_certificate') as mock_validate:
            with patch('src.core.auth.AuthManager._get_access_token_with_cert') as mock_get_token:
                mock_validate.return_value = True
                mock_get_token.return_value = {
                    "access_token": "test_token",
                    "expires_in": 3600
                }
                
                result = await auth_manager.authenticate_with_certificate(
                    "test_cert.pfx", "password"
                )
                
                assert result is True
                assert auth_manager.access_token == "test_token"
                assert auth_manager.authenticated is True
                mock_validate.assert_called_once_with("test_cert.pfx", "password")
                mock_get_token.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_certificate_auth_invalid_cert(self, auth_manager):
        """無効な証明書での認証失敗テスト"""
        with patch('src.core.auth.AuthManager._validate_certificate') as mock_validate:
            mock_validate.side_effect = AuthenticationError("Invalid certificate")
            
            with pytest.raises(AuthenticationError) as exc_info:
                await auth_manager.authenticate_with_certificate(
                    "invalid_cert.pfx", "wrong_password"
                )
            
            assert "Invalid certificate" in str(exc_info.value)
            assert auth_manager.authenticated is False
    
    @pytest.mark.asyncio
    async def test_certificate_auth_file_not_found(self, auth_manager):
        """証明書ファイルが見つからない場合のテスト"""
        with patch('pathlib.Path.exists', return_value=False):
            with pytest.raises(AuthenticationError) as exc_info:
                await auth_manager.authenticate_with_certificate(
                    "nonexistent_cert.pfx", "password"
                )
            
            assert "Certificate file not found" in str(exc_info.value)
    
    @pytest.mark.asyncio
    async def test_client_secret_auth_success(self, auth_manager):
        """クライアントシークレット認証の成功テスト"""
        with patch('src.core.auth.AuthManager._get_access_token_with_secret') as mock_get_token:
            mock_get_token.return_value = {
                "access_token": "test_token",
                "expires_in": 3600
            }
            
            result = await auth_manager.authenticate_with_client_secret(
                "client_id", "client_secret", "tenant_id"
            )
            
            assert result is True
            assert auth_manager.access_token == "test_token"
            assert auth_manager.authenticated is True
            mock_get_token.assert_called_once_with("client_id", "client_secret", "tenant_id")
    
    @pytest.mark.asyncio
    async def test_client_secret_auth_invalid_credentials(self, auth_manager):
        """無効なクライアントシークレットでの認証失敗テスト"""
        with patch('src.core.auth.AuthManager._get_access_token_with_secret') as mock_get_token:
            mock_get_token.side_effect = AuthenticationError("Invalid client credentials")
            
            with pytest.raises(AuthenticationError) as exc_info:
                await auth_manager.authenticate_with_client_secret(
                    "invalid_client", "invalid_secret", "tenant_id"
                )
            
            assert "Invalid client credentials" in str(exc_info.value)
            assert auth_manager.authenticated is False
    
    @pytest.mark.asyncio
    async def test_token_refresh_success(self, auth_manager):
        """トークンリフレッシュの成功テスト"""
        # 既存の認証状態を設定
        auth_manager.access_token = "old_token"
        auth_manager.authenticated = True
        auth_manager.token_expiry = datetime.now() + timedelta(minutes=5)
        
        with patch('src.core.auth.AuthManager._refresh_access_token') as mock_refresh:
            mock_refresh.return_value = {
                "access_token": "new_token",
                "expires_in": 3600
            }
            
            new_token = await auth_manager.refresh_access_token()
            
            assert new_token == "new_token"
            assert auth_manager.access_token == "new_token"
            mock_refresh.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_token_refresh_not_authenticated(self, auth_manager):
        """未認証状態でのトークンリフレッシュ失敗テスト"""
        with pytest.raises(AuthenticationError) as exc_info:
            await auth_manager.refresh_access_token()
        
        assert "Not authenticated" in str(exc_info.value)
    
    def test_is_token_expired_not_set(self, auth_manager):
        """トークン有効期限未設定の場合のテスト"""
        assert auth_manager.is_token_expired() is True
    
    def test_is_token_expired_valid(self, auth_manager):
        """トークンが有効な場合のテスト"""
        auth_manager.token_expiry = datetime.now() + timedelta(minutes=10)
        assert auth_manager.is_token_expired() is False
    
    def test_is_token_expired_expired(self, auth_manager):
        """トークンが期限切れの場合のテスト"""
        auth_manager.token_expiry = datetime.now() - timedelta(minutes=10)
        assert auth_manager.is_token_expired() is True
    
    def test_is_token_expired_near_expiry(self, auth_manager):
        """トークンが期限切れ間近の場合のテスト"""
        # 5分以内の場合は期限切れとして扱う
        auth_manager.token_expiry = datetime.now() + timedelta(minutes=3)
        assert auth_manager.is_token_expired() is True
    
    def test_get_authorization_header_success(self, auth_manager):
        """認証ヘッダー取得の成功テスト"""
        auth_manager.access_token = "test_token"
        auth_manager.authenticated = True
        
        header = auth_manager.get_authorization_header()
        
        assert header == {"Authorization": "Bearer test_token"}
    
    def test_get_authorization_header_not_authenticated(self, auth_manager):
        """未認証状態での認証ヘッダー取得テスト"""
        with pytest.raises(AuthenticationError) as exc_info:
            auth_manager.get_authorization_header()
        
        assert "Not authenticated" in str(exc_info.value)
    
    def test_clear_authentication(self, auth_manager):
        """認証情報クリアテスト"""
        # 認証状態を設定
        auth_manager.access_token = "test_token"
        auth_manager.authenticated = True
        auth_manager.token_expiry = datetime.now() + timedelta(hours=1)
        
        # 認証情報をクリア
        auth_manager.clear_authentication()
        
        assert auth_manager.access_token is None
        assert auth_manager.authenticated is False
        assert auth_manager.token_expiry is None
    
    @pytest.mark.asyncio
    async def test_validate_certificate_success(self, auth_manager):
        """証明書検証の成功テスト"""
        with patch('pathlib.Path.exists', return_value=True):
            with patch('cryptography.hazmat.primitives.serialization.pkcs12.load_key_and_certificates') as mock_load:
                mock_load.return_value = (Mock(), Mock(), [])
                
                result = auth_manager._validate_certificate("test_cert.pfx", "password")
                
                assert result is True
                mock_load.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_validate_certificate_wrong_password(self, auth_manager):
        """証明書パスワード間違いのテスト"""
        with patch('pathlib.Path.exists', return_value=True):
            with patch('cryptography.hazmat.primitives.serialization.pkcs12.load_key_and_certificates') as mock_load:
                mock_load.side_effect = ValueError("Invalid password")
                
                with pytest.raises(AuthenticationError) as exc_info:
                    auth_manager._validate_certificate("test_cert.pfx", "wrong_password")
                
                assert "Invalid certificate password" in str(exc_info.value)
    
    @pytest.mark.asyncio
    async def test_get_access_token_with_cert_success(self, auth_manager):
        """証明書でのアクセストークン取得成功テスト"""
        mock_response = {
            "access_token": "test_token",
            "token_type": "Bearer",
            "expires_in": 3600
        }
        
        with patch('requests.post') as mock_post:
            mock_response_obj = Mock()
            mock_response_obj.status_code = 200
            mock_response_obj.json.return_value = mock_response
            mock_post.return_value = mock_response_obj
            
            result = await auth_manager._get_access_token_with_cert(
                "client_id", "tenant_id", "cert_path", "cert_password"
            )
            
            assert result == mock_response
            mock_post.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_access_token_with_cert_api_error(self, auth_manager):
        """証明書でのアクセストークン取得API エラーテスト"""
        with patch('requests.post') as mock_post:
            mock_response_obj = Mock()
            mock_response_obj.status_code = 401
            mock_response_obj.json.return_value = {"error": "invalid_client"}
            mock_post.return_value = mock_response_obj
            
            with pytest.raises(AuthenticationError) as exc_info:
                await auth_manager._get_access_token_with_cert(
                    "client_id", "tenant_id", "cert_path", "cert_password"
                )
            
            assert "Authentication failed" in str(exc_info.value)
    
    @pytest.mark.asyncio
    async def test_get_access_token_with_secret_success(self, auth_manager):
        """クライアントシークレットでのアクセストークン取得成功テスト"""
        mock_response = {
            "access_token": "test_token",
            "token_type": "Bearer",
            "expires_in": 3600
        }
        
        with patch('requests.post') as mock_post:
            mock_response_obj = Mock()
            mock_response_obj.status_code = 200
            mock_response_obj.json.return_value = mock_response
            mock_post.return_value = mock_response_obj
            
            result = await auth_manager._get_access_token_with_secret(
                "client_id", "client_secret", "tenant_id"
            )
            
            assert result == mock_response
            mock_post.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_access_token_with_secret_network_error(self, auth_manager):
        """クライアントシークレットでのアクセストークン取得ネットワークエラーテスト"""
        import requests
        
        with patch('requests.post') as mock_post:
            mock_post.side_effect = requests.exceptions.ConnectionError("Network error")
            
            with pytest.raises(AuthenticationError) as exc_info:
                await auth_manager._get_access_token_with_secret(
                    "client_id", "client_secret", "tenant_id"
                )
            
            assert "Network error during authentication" in str(exc_info.value)
    
    @pytest.mark.asyncio
    async def test_auto_refresh_token_needed(self, auth_manager):
        """自動トークンリフレッシュが必要な場合のテスト"""
        # 期限切れ間近のトークンを設定
        auth_manager.access_token = "old_token"
        auth_manager.authenticated = True
        auth_manager.token_expiry = datetime.now() + timedelta(minutes=3)
        
        with patch('src.core.auth.AuthManager.refresh_access_token') as mock_refresh:
            mock_refresh.return_value = "new_token"
            
            token = await auth_manager.get_valid_token()
            
            assert token == "new_token"
            mock_refresh.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_auto_refresh_token_not_needed(self, auth_manager):
        """自動トークンリフレッシュが不要な場合のテスト"""
        # 有効なトークンを設定
        auth_manager.access_token = "valid_token"
        auth_manager.authenticated = True
        auth_manager.token_expiry = datetime.now() + timedelta(minutes=30)
        
        with patch('src.core.auth.AuthManager.refresh_access_token') as mock_refresh:
            token = await auth_manager.get_valid_token()
            
            assert token == "valid_token"
            mock_refresh.assert_not_called()
    
    def test_validate_auth_config_success(self, auth_manager, mock_config):
        """認証設定検証の成功テスト"""
        result = auth_manager._validate_auth_config(mock_config["azure"])
        
        assert result is True
    
    def test_validate_auth_config_missing_client_id(self, auth_manager):
        """client_id 欠如の設定検証テスト"""
        config = {
            "client_secret": "secret",
            "tenant_id": "tenant"
        }
        
        with pytest.raises(ConfigurationError) as exc_info:
            auth_manager._validate_auth_config(config)
        
        assert "client_id is required" in str(exc_info.value)
    
    def test_validate_auth_config_missing_tenant_id(self, auth_manager):
        """tenant_id 欠如の設定検証テスト"""
        config = {
            "client_id": "client",
            "client_secret": "secret"
        }
        
        with pytest.raises(ConfigurationError) as exc_info:
            auth_manager._validate_auth_config(config)
        
        assert "tenant_id is required" in str(exc_info.value)
    
    def test_validate_auth_config_missing_auth_method(self, auth_manager):
        """認証方法欠如の設定検証テスト"""
        config = {
            "client_id": "client",
            "tenant_id": "tenant"
        }
        
        with pytest.raises(ConfigurationError) as exc_info:
            auth_manager._validate_auth_config(config)
        
        assert "Either client_secret or certificate_path is required" in str(exc_info.value)
    
    @pytest.mark.asyncio
    async def test_concurrent_authentication_requests(self, auth_manager):
        """並行認証リクエストのテスト"""
        with patch('src.core.auth.AuthManager._get_access_token_with_secret') as mock_get_token:
            mock_get_token.return_value = {
                "access_token": "test_token",
                "expires_in": 3600
            }
            
            # 並行で認証を実行
            tasks = [
                auth_manager.authenticate_with_client_secret("client", "secret", "tenant")
                for _ in range(5)
            ]
            
            results = await asyncio.gather(*tasks)
            
            # 全ての認証が成功すること
            assert all(result is True for result in results)
            # トークンは一度だけ取得されること（キャッシュされる）
            assert mock_get_token.call_count == 1
    
    def test_thread_safety(self, auth_manager):
        """スレッドセーフティのテスト"""
        import threading
        import time
        
        results = []
        
        def authenticate_thread():
            try:
                # 認証状態を設定
                auth_manager.access_token = "thread_token"
                auth_manager.authenticated = True
                time.sleep(0.1)  # 競合状態を作るための遅延
                
                # 認証状態を確認
                if auth_manager.authenticated:
                    results.append("success")
                else:
                    results.append("failed")
            except Exception as e:
                results.append(f"error: {e}")
        
        # 複数スレッドで実行
        threads = []
        for _ in range(10):
            thread = threading.Thread(target=authenticate_thread)
            threads.append(thread)
            thread.start()
        
        # 全スレッドの完了を待機
        for thread in threads:
            thread.join()
        
        # 結果の検証
        assert len(results) == 10
        assert all(result == "success" for result in results)