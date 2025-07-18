"""
Unit tests for Microsoft Graph API client.
Tests authentication, HTTP methods, pagination, error handling, and compatibility.
"""

import json
import pytest
import requests
from datetime import datetime, timedelta
from unittest.mock import Mock, MagicMock, patch, call
from requests.exceptions import HTTPError, Timeout, RequestException

from src.api.graph.client import GraphClient
from src.core.config import Config


class TestGraphClient:
    """Test suite for GraphClient class."""
    
    def setup_method(self):
        """Setup test environment."""
        self.mock_config = Mock(spec=Config)
        self.mock_config.get.side_effect = self._mock_config_get
        
        self.client = GraphClient(self.mock_config)
        
        # Mock MSAL app
        self.mock_msal_app = Mock()
        self.client.app = self.mock_msal_app
    
    def _mock_config_get(self, key, default=None):
        """Mock configuration getter."""
        config_values = {
            'ApiSettings.RetryCount': 3,
            'ApiSettings.RetryDelay': 5,
            'ApiSettings.Timeout': 300,
            'ApiSettings.GraphApiVersion': 'v1.0',
            'Authentication.AuthMethod': 'Certificate',
            'Authentication.TenantId': 'test-tenant-id',
            'Authentication.ClientId': 'test-client-id',
            'Authentication.ClientSecret': 'test-client-secret',
            'Authentication.CertificatePath': 'test/cert.pfx',
            'Authentication.CertificatePassword': 'test-password',
            'Authentication.CertificateThumbprint': 'test-thumbprint'
        }
        return config_values.get(key, default)
    
    def test_graph_client_initialization(self):
        """Test GraphClient initialization."""
        assert self.client.config is self.mock_config
        assert self.client.access_token is None
        assert self.client.app is not None
        assert self.client.session is not None
    
    def test_create_session_with_retry_strategy(self):
        """Test HTTP session creation with retry strategy."""
        session = self.client._create_session()
        
        assert isinstance(session, requests.Session)
        # Check that adapters are mounted
        assert 'https://' in session.adapters
        assert 'http://' in session.adapters
    
    def test_initialize_certificate_auth(self):
        """Test certificate authentication initialization."""
        with patch('builtins.open', mock_open(read_data=b'cert_data')):
            with patch('pathlib.Path.exists', return_value=True):
                with patch('os.path.exists', return_value=True):
                    with patch('os.path.isabs', return_value=True):
                        with patch('msal.ConfidentialClientApplication') as mock_app:
                            self.client._init_certificate_auth()
                            
                            mock_app.assert_called_once()
                            args, kwargs = mock_app.call_args
                            assert args[0] == 'test-client-id'
                            assert 'authority' in kwargs
                            assert 'client_credential' in kwargs
    
    def test_initialize_certificate_auth_missing_cert_path(self):
        """Test certificate authentication with missing certificate path."""
        self.mock_config.get.side_effect = lambda key, default=None: {
            'Authentication.CertificatePath': '',
            'Authentication.CertificateThumbprint': '',
            'Authentication.TenantId': 'test-tenant-id',
            'Authentication.ClientId': 'test-client-id'
        }.get(key, default)
        
        with pytest.raises(ValueError, match="証明書パスまたはサムプリントが必要です"):
            self.client._init_certificate_auth()
    
    def test_initialize_certificate_auth_file_not_found(self):
        """Test certificate authentication with missing certificate file."""
        with patch('os.path.exists', return_value=False):
            with patch('os.path.isabs', return_value=True):
                with pytest.raises(FileNotFoundError, match="証明書ファイルが見つかりません"):
                    self.client._init_certificate_auth()
    
    def test_initialize_client_secret_auth(self):
        """Test client secret authentication initialization."""
        with patch('msal.ConfidentialClientApplication') as mock_app:
            self.client._init_client_secret_auth()
            
            mock_app.assert_called_once()
            args, kwargs = mock_app.call_args
            assert args[0] == 'test-client-id'
            assert 'authority' in kwargs
            assert kwargs['client_credential'] == 'test-client-secret'
    
    def test_initialize_client_secret_auth_missing_credentials(self):
        """Test client secret authentication with missing credentials."""
        self.mock_config.get.side_effect = lambda key, default=None: {
            'Authentication.TenantId': '',
            'Authentication.ClientId': 'test-client-id',
            'Authentication.ClientSecret': 'test-client-secret'
        }.get(key, default)
        
        with pytest.raises(ValueError, match="TenantId、ClientId、ClientSecretが必要です"):
            self.client._init_client_secret_auth()
    
    def test_initialize_interactive_auth(self):
        """Test interactive authentication initialization."""
        with patch('msal.PublicClientApplication') as mock_app:
            self.client._init_interactive_auth()
            
            mock_app.assert_called_once()
            args, kwargs = mock_app.call_args
            assert args[0] == 'test-client-id'
            assert 'authority' in kwargs
    
    def test_initialize_unsupported_auth_method(self):
        """Test initialization with unsupported authentication method."""
        self.mock_config.get.side_effect = lambda key, default=None: {
            'Authentication.AuthMethod': 'UnsupportedMethod'
        }.get(key, default)
        
        with pytest.raises(ValueError, match="Unsupported authentication method"):
            self.client.initialize()
    
    def test_acquire_token_success(self):
        """Test successful token acquisition."""
        # Mock token response
        mock_token_response = {
            'access_token': 'test-access-token',
            'expires_in': 3600,
            'token_type': 'Bearer'
        }
        
        self.mock_msal_app.acquire_token_for_client.return_value = mock_token_response
        self.mock_msal_app.get_accounts.return_value = []
        
        token = self.client.acquire_token()
        
        assert token == 'test-access-token'
        assert self.client.access_token == 'test-access-token'
        self.mock_msal_app.acquire_token_for_client.assert_called_once()
    
    def test_acquire_token_from_cache(self):
        """Test token acquisition from cache."""
        # Mock cached token response
        mock_cached_token = {
            'access_token': 'cached-token',
            'expires_in': 3600,
            'token_type': 'Bearer'
        }
        
        mock_account = {'username': 'test@example.com'}
        self.mock_msal_app.get_accounts.return_value = [mock_account]
        self.mock_msal_app.acquire_token_silent.return_value = mock_cached_token
        
        token = self.client.acquire_token()
        
        assert token == 'cached-token'
        self.mock_msal_app.acquire_token_silent.assert_called_once()
    
    def test_acquire_token_error(self):
        """Test token acquisition error handling."""
        # Mock error response
        mock_error_response = {
            'error': 'invalid_client',
            'error_description': 'Invalid client credentials',
            'correlation_id': 'test-correlation-id'
        }
        
        self.mock_msal_app.acquire_token_for_client.return_value = mock_error_response
        self.mock_msal_app.get_accounts.return_value = []
        
        with pytest.raises(Exception, match="トークン取得に失敗"):
            self.client.acquire_token()
    
    def test_acquire_token_no_result(self):
        """Test token acquisition with no result."""
        self.mock_msal_app.acquire_token_for_client.return_value = None
        self.mock_msal_app.get_accounts.return_value = []
        
        with pytest.raises(Exception, match="トークン取得に失敗"):
            self.client.acquire_token()
    
    def test_get_headers(self):
        """Test HTTP headers generation."""
        self.client.access_token = 'test-token'
        
        headers = self.client._get_headers()
        
        expected_headers = {
            'Authorization': 'Bearer test-token',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        assert headers == expected_headers
    
    def test_get_headers_ensures_token(self):
        """Test that get_headers ensures token is available."""
        self.client.access_token = None
        
        # Mock token acquisition
        with patch.object(self.client, 'acquire_token', return_value='new-token'):
            headers = self.client._get_headers()
            
            assert headers['Authorization'] == 'Bearer new-token'
    
    @patch('requests.Session.get')
    def test_get_request_success(self, mock_get):
        """Test successful GET request."""
        # Mock response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {'value': [{'id': '1', 'name': 'test'}]}
        mock_get.return_value = mock_response
        
        self.client.access_token = 'test-token'
        
        result = self.client.get('/users')
        
        assert result == {'value': [{'id': '1', 'name': 'test'}]}
        mock_get.assert_called_once()
    
    @patch('requests.Session.get')
    def test_get_request_401_retry(self, mock_get):
        """Test GET request with 401 error and retry."""
        # Mock initial 401 response
        mock_401_response = Mock()
        mock_401_response.status_code = 401
        mock_401_response.raise_for_status.side_effect = HTTPError()
        
        # Mock successful retry response
        mock_success_response = Mock()
        mock_success_response.status_code = 200
        mock_success_response.json.return_value = {'value': []}
        
        mock_get.side_effect = [mock_401_response, mock_success_response]
        
        self.client.access_token = 'test-token'
        
        with patch.object(self.client, 'acquire_token', return_value='new-token'):
            result = self.client.get('/users')
            
            assert result == {'value': []}
            assert mock_get.call_count == 2
    
    @patch('requests.Session.get')
    def test_get_request_timeout(self, mock_get):
        """Test GET request timeout handling."""
        mock_get.side_effect = Timeout("Request timed out")
        
        self.client.access_token = 'test-token'
        
        with pytest.raises(Exception, match="API要求がタイムアウトしました"):
            self.client.get('/users')
    
    @patch('requests.Session.get')
    def test_get_request_403_error(self, mock_get):
        """Test GET request with 403 permission error."""
        mock_response = Mock()
        mock_response.status_code = 403
        mock_response.raise_for_status.side_effect = HTTPError(response=mock_response)
        mock_get.return_value = mock_response
        
        self.client.access_token = 'test-token'
        
        with pytest.raises(Exception, match="API権限不足"):
            self.client.get('/users')
    
    @patch('requests.Session.get')
    def test_get_request_429_throttling(self, mock_get):
        """Test GET request with 429 throttling error."""
        mock_response = Mock()
        mock_response.status_code = 429
        mock_response.raise_for_status.side_effect = HTTPError(response=mock_response)
        mock_get.return_value = mock_response
        
        self.client.access_token = 'test-token'
        
        with pytest.raises(Exception, match="API使用制限に達しました"):
            self.client.get('/users')
    
    @patch('requests.Session.get')
    def test_get_request_network_error(self, mock_get):
        """Test GET request with network error."""
        mock_get.side_effect = RequestException("Network error")
        
        self.client.access_token = 'test-token'
        
        with pytest.raises(Exception, match="ネットワークエラー"):
            self.client.get('/users')
    
    @patch('requests.Session.post')
    def test_post_request_success(self, mock_post):
        """Test successful POST request."""
        mock_response = Mock()
        mock_response.status_code = 201
        mock_response.json.return_value = {'id': '1', 'name': 'created'}
        mock_post.return_value = mock_response
        
        self.client.access_token = 'test-token'
        
        data = {'name': 'test'}
        result = self.client.post('/users', data)
        
        assert result == {'id': '1', 'name': 'created'}
        mock_post.assert_called_once()
    
    @patch('requests.Session.get')
    def test_get_all_pages_single_page(self, mock_get):
        """Test get_all_pages with single page."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'value': [{'id': '1'}, {'id': '2'}]
        }
        mock_get.return_value = mock_response
        
        self.client.access_token = 'test-token'
        
        result = self.client.get_all_pages('/users')
        
        assert result == [{'id': '1'}, {'id': '2'}]
        mock_get.assert_called_once()
    
    @patch('requests.Session.get')
    def test_get_all_pages_multiple_pages(self, mock_get):
        """Test get_all_pages with multiple pages."""
        # Mock first page response
        mock_response1 = Mock()
        mock_response1.status_code = 200
        mock_response1.json.return_value = {
            'value': [{'id': '1'}, {'id': '2'}],
            '@odata.nextLink': 'https://graph.microsoft.com/v1.0/users?$skip=2'
        }
        
        # Mock second page response
        mock_response2 = Mock()
        mock_response2.status_code = 200
        mock_response2.json.return_value = {
            'value': [{'id': '3'}, {'id': '4'}]
        }
        
        mock_get.side_effect = [mock_response1, mock_response2]
        
        self.client.access_token = 'test-token'
        
        result = self.client.get_all_pages('/users')
        
        assert result == [{'id': '1'}, {'id': '2'}, {'id': '3'}, {'id': '4'}]
        assert mock_get.call_count == 2
    
    def test_get_users_convenience_method(self):
        """Test get_users convenience method."""
        with patch.object(self.client, 'get') as mock_get:
            mock_get.return_value = {'value': [{'id': '1', 'name': 'user1'}]}
            
            result = self.client.get_users(select=['id', 'name'], limit=10)
            
            assert result == [{'id': '1', 'name': 'user1'}]
            mock_get.assert_called_once_with('/users', {'$select': 'id,name', '$top': 10})
    
    def test_get_users_large_limit(self):
        """Test get_users with large limit using pagination."""
        with patch.object(self.client, 'get_all_pages') as mock_get_all:
            mock_get_all.return_value = [{'id': '1'}, {'id': '2'}]
            
            result = self.client.get_users(limit=2000)
            
            assert result == [{'id': '1'}, {'id': '2'}]
            mock_get_all.assert_called_once_with('/users', {})
    
    def test_get_user_by_id(self):
        """Test get_user convenience method."""
        with patch.object(self.client, 'get') as mock_get:
            mock_get.return_value = {'id': '1', 'name': 'user1'}
            
            result = self.client.get_user('user1@example.com')
            
            assert result == {'id': '1', 'name': 'user1'}
            mock_get.assert_called_once_with('/users/user1@example.com')
    
    def test_get_groups_convenience_method(self):
        """Test get_groups convenience method."""
        with patch.object(self.client, 'get_all_pages') as mock_get_all:
            mock_get_all.return_value = [{'id': '1', 'name': 'group1'}]
            
            result = self.client.get_groups(select=['id', 'name'])
            
            assert result == [{'id': '1', 'name': 'group1'}]
            mock_get_all.assert_called_once_with('/groups', {'$select': 'id,name'})
    
    def test_get_licenses_convenience_method(self):
        """Test get_licenses convenience method."""
        with patch.object(self.client, 'get_all_pages') as mock_get_all:
            mock_get_all.return_value = [{'skuId': '1', 'skuPartNumber': 'E3'}]
            
            result = self.client.get_licenses()
            
            assert result == [{'skuId': '1', 'skuPartNumber': 'E3'}]
            mock_get_all.assert_called_once_with('/subscribedSkus')
    
    def test_get_users_with_auth_methods(self):
        """Test get_users_with_auth_methods method."""
        with patch.object(self.client, 'get') as mock_get:
            # Mock users response
            mock_get.side_effect = [
                {'value': [{'id': '1', 'displayName': 'User 1'}]},
                {'value': [{'@odata.type': 'microsoft.graph.smsAuthenticationMethod'}]}
            ]
            
            result = self.client.get_users_with_auth_methods(limit=1)
            
            assert len(result) == 1
            assert result[0]['id'] == '1'
            assert 'authenticationMethods' in result[0]
    
    def test_get_users_with_auth_methods_error_handling(self):
        """Test get_users_with_auth_methods with auth method error."""
        with patch.object(self.client, 'get') as mock_get:
            # Mock users response, then error for auth methods
            mock_get.side_effect = [
                {'value': [{'id': '1', 'displayName': 'User 1'}]},
                Exception("Auth method error")
            ]
            
            result = self.client.get_users_with_auth_methods(limit=1)
            
            assert len(result) == 1
            assert result[0]['authenticationMethods'] == []
    
    def test_get_license_usage_with_fallback(self):
        """Test get_license_usage with fallback to subscriptions."""
        with patch.object(self.client, 'get') as mock_get:
            with patch.object(self.client, 'get_subscriptions') as mock_get_subs:
                # Mock reports API failure
                mock_get.side_effect = Exception("Reports API error")
                mock_get_subs.return_value = [{'skuId': '1', 'skuPartNumber': 'E3'}]
                
                result = self.client.get_license_usage()
                
                assert result == [{'skuId': '1', 'skuPartNumber': 'E3'}]
                mock_get_subs.assert_called_once()
    
    def test_get_teams_usage_reports_fallback(self):
        """Test get_teams_usage_reports with fallback."""
        with patch.object(self.client, 'get') as mock_get:
            mock_get.side_effect = Exception("Teams API error")
            
            result = self.client.get_teams_usage_reports()
            
            assert result == []
    
    def test_get_onedrive_usage_fallback(self):
        """Test get_onedrive_usage with fallback."""
        with patch.object(self.client, 'get') as mock_get:
            mock_get.side_effect = Exception("OneDrive API error")
            
            result = self.client.get_onedrive_usage()
            
            assert result == []
    
    def test_get_mailbox_usage_fallback(self):
        """Test get_mailbox_usage with fallback."""
        with patch.object(self.client, 'get') as mock_get:
            mock_get.side_effect = Exception("Mailbox API error")
            
            result = self.client.get_mailbox_usage()
            
            assert result == []
    
    def test_load_cert_from_store_windows(self):
        """Test loading certificate from Windows store."""
        # Mock Windows certificate store
        with patch('wincertstore.CertSystemStore') as mock_store:
            mock_cert = Mock()
            mock_cert.get_fingerprint.return_value = b'\xab\xcd\xef'
            mock_cert.get_pem.return_value = b'-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----'
            
            mock_store_instance = Mock()
            mock_store_instance.itercerts.return_value = [mock_cert]
            mock_store.return_value = mock_store_instance
            
            with patch('binascii.hexlify', return_value=b'ABCDEF'):
                result = self.client._load_cert_from_store('AB:CD:EF')
                
                assert result == b'-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----'
    
    def test_load_cert_from_store_not_found(self):
        """Test loading certificate from store when not found."""
        with patch('wincertstore.CertSystemStore') as mock_store:
            mock_store_instance = Mock()
            mock_store_instance.itercerts.return_value = []
            mock_store.return_value = mock_store_instance
            
            with pytest.raises(FileNotFoundError, match="証明書が見つかりません"):
                self.client._load_cert_from_store('NOT-FOUND-THUMBPRINT')
    
    def test_load_cert_from_store_import_error(self):
        """Test loading certificate from store with import error."""
        with patch('wincertstore.CertSystemStore', side_effect=ImportError()):
            with pytest.raises(NotImplementedError, match="Windows証明書ストアアクセスにはwincertstoreが必要です"):
                self.client._load_cert_from_store('test-thumbprint')


class TestGraphClientErrorHandling:
    """Test suite for GraphClient error handling scenarios."""
    
    def setup_method(self):
        """Setup test environment."""
        self.mock_config = Mock(spec=Config)
        self.mock_config.get.side_effect = lambda key, default=None: {
            'ApiSettings.RetryCount': 3,
            'ApiSettings.RetryDelay': 1,
            'ApiSettings.Timeout': 30,
            'ApiSettings.GraphApiVersion': 'v1.0',
            'Authentication.AuthMethod': 'ClientSecret',
            'Authentication.TenantId': 'test-tenant-id',
            'Authentication.ClientId': 'test-client-id',
            'Authentication.ClientSecret': 'test-client-secret'
        }.get(key, default)
        
        self.client = GraphClient(self.mock_config)
    
    def test_initialization_error_handling(self):
        """Test initialization error handling."""
        with patch('msal.ConfidentialClientApplication', side_effect=Exception("MSAL error")):
            with pytest.raises(Exception, match="MSAL error"):
                self.client.initialize()
    
    def test_acquire_token_exception_handling(self):
        """Test acquire_token exception handling."""
        self.client.app = Mock()
        self.client.app.get_accounts.side_effect = Exception("Account error")
        
        with pytest.raises(Exception, match="トークン取得中にエラーが発生"):
            self.client.acquire_token()
    
    @patch('requests.Session.get')
    def test_get_request_unexpected_error(self, mock_get):
        """Test GET request with unexpected error."""
        mock_get.side_effect = Exception("Unexpected error")
        
        self.client.access_token = 'test-token'
        
        with pytest.raises(Exception, match="予期しないエラー"):
            self.client.get('/users')
    
    def test_certificate_auth_invalid_path(self):
        """Test certificate auth with invalid path."""
        self.mock_config.get.side_effect = lambda key, default=None: {
            'Authentication.CertificatePath': '/invalid/path/cert.pfx',
            'Authentication.CertificatePassword': 'password',
            'Authentication.TenantId': 'test-tenant-id',
            'Authentication.ClientId': 'test-client-id'
        }.get(key, default)
        
        with patch('os.path.exists', return_value=False):
            with patch('os.path.isabs', return_value=True):
                with pytest.raises(FileNotFoundError, match="証明書ファイルが見つかりません"):
                    self.client._init_certificate_auth()
    
    def test_certificate_auth_read_error(self):
        """Test certificate auth with file read error."""
        self.mock_config.get.side_effect = lambda key, default=None: {
            'Authentication.CertificatePath': '/test/cert.pfx',
            'Authentication.CertificatePassword': 'password',
            'Authentication.TenantId': 'test-tenant-id',
            'Authentication.ClientId': 'test-client-id'
        }.get(key, default)
        
        with patch('os.path.exists', return_value=True):
            with patch('os.path.isabs', return_value=True):
                with patch('builtins.open', side_effect=IOError("Permission denied")):
                    with pytest.raises(IOError, match="Permission denied"):
                        self.client._init_certificate_auth()


class TestGraphClientCompatibility:
    """Test suite for GraphClient PowerShell compatibility."""
    
    def setup_method(self):
        """Setup test environment."""
        self.mock_config = Mock(spec=Config)
        self.client = GraphClient(self.mock_config)
    
    def test_legacy_config_structure_support(self):
        """Test support for legacy PowerShell config structure."""
        # Mock legacy config structure
        def mock_legacy_config(key, default=None):
            legacy_config = {
                'Authentication.TenantId': None,
                'Authentication.ClientId': None,
                'Authentication.CertificatePath': None,
                'ExchangeOnline.CertificatePath': 'legacy/cert.pfx',
                'EntraID.TenantId': 'legacy-tenant-id',
                'EntraID.ClientId': 'legacy-client-id',
                'EntraID.CertificateThumbprint': 'legacy-thumbprint'
            }
            return legacy_config.get(key, default)
        
        self.mock_config.get.side_effect = mock_legacy_config
        
        # Test that legacy config is properly handled
        with patch('builtins.open', mock_open(read_data=b'cert_data')):
            with patch('pathlib.Path.exists', return_value=True):
                with patch('os.path.exists', return_value=True):
                    with patch('os.path.isabs', return_value=True):
                        with patch('msal.ConfidentialClientApplication') as mock_app:
                            self.client._init_certificate_auth()
                            
                            # Should use legacy config values
                            mock_app.assert_called_once()
                            args, kwargs = mock_app.call_args
                            assert args[0] == 'legacy-client-id'
                            assert 'legacy-tenant-id' in kwargs['authority']
    
    def test_error_message_localization(self):
        """Test that error messages are properly localized."""
        self.mock_config.get.return_value = None
        
        with pytest.raises(ValueError) as exc_info:
            self.client._init_certificate_auth()
        
        # Should have Japanese error message
        assert "証明書パスまたはサムプリントが必要です" in str(exc_info.value)
    
    def test_powershell_compatible_data_structures(self):
        """Test that returned data structures are PowerShell compatible."""
        with patch.object(self.client, 'get') as mock_get:
            # Mock response in PowerShell-compatible format
            mock_get.return_value = {
                'value': [
                    {
                        'id': '12345',
                        'displayName': 'Test User',
                        'userPrincipalName': 'test@example.com',
                        'accountEnabled': True,
                        'assignedLicenses': [
                            {'skuId': 'license-1'},
                            {'skuId': 'license-2'}
                        ]
                    }
                ]
            }
            
            result = self.client.get_users(limit=1)
            
            # Should maintain PowerShell-compatible structure
            assert len(result) == 1
            user = result[0]
            assert user['id'] == '12345'
            assert user['displayName'] == 'Test User'
            assert user['userPrincipalName'] == 'test@example.com'
            assert user['accountEnabled'] is True
            assert len(user['assignedLicenses']) == 2
    
    def test_report_api_compatibility(self):
        """Test compatibility with PowerShell report API calls."""
        with patch.object(self.client, 'get') as mock_get:
            mock_get.return_value = {'value': [{'reportDate': '2023-01-01'}]}
            
            # Test various report API calls
            result1 = self.client.get_license_usage()
            result2 = self.client.get_teams_usage_reports()
            result3 = self.client.get_onedrive_usage()
            result4 = self.client.get_mailbox_usage()
            
            # Should handle all report types
            assert isinstance(result1, list)
            assert isinstance(result2, list)
            assert isinstance(result3, list)
            assert isinstance(result4, list)


def mock_open(read_data=b''):
    """Mock open function for file operations."""
    from unittest.mock import mock_open as _mock_open
    return _mock_open(read_data=read_data)