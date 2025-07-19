"""
Microsoft Graph API client implementation.
Python equivalent of PowerShell RealM365DataProvider.psm1.
Provides authentication and API access for Microsoft 365 services.
"""

import logging
import time
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List, Union
from dataclasses import dataclass
import asyncio
from msal import ConfidentialClientApplication, PublicClientApplication
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from src.core.config import Config
from src.core.auth.retry_handler import RetryHandler
from src.security.security_manager import get_security_manager
from src.security.data_sanitizer import sanitize_for_logging


@dataclass
class CacheEntry:
    """Cache entry for API data."""
    data: Any
    last_updated: Optional[datetime]
    ttl: int  # Time to live in seconds
    
    def is_valid(self) -> bool:
        """Check if cache entry is still valid."""
        if not self.last_updated or not self.data:
            return False
        
        elapsed = datetime.now() - self.last_updated
        return elapsed.total_seconds() < self.ttl


@dataclass
class PerformanceMetrics:
    """Performance metrics tracking."""
    api_call_count: int = 0
    cache_hit_count: int = 0
    total_response_time: float = 0.0
    last_reset_time: Optional[datetime] = None
    
    def __post_init__(self) -> None:
        if not self.last_reset_time:
            self.last_reset_time = datetime.now()


class GraphClient:
    """
    Microsoft Graph API client with authentication support.
    Python equivalent of PowerShell RealM365DataProvider.psm1.
    Supports certificate-based and client secret authentication with caching.
    """
    
    GRAPH_API_ENDPOINT = 'https://graph.microsoft.com'
    DEFAULT_SCOPES = ['https://graph.microsoft.com/.default']
    
    def __init__(self, config: Config) -> None:
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.access_token = None
        self.app = None
        self.session = self._create_session()
        self.retry_handler = RetryHandler()
        self.security_manager = get_security_manager()
        
        # Initialize caching system (matches PowerShell implementation)
        self.data_cache: Dict[str, CacheEntry] = {
            'users': CacheEntry(None, None, 300),      # 5 minutes
            'groups': CacheEntry(None, None, 600),     # 10 minutes
            'licenses': CacheEntry(None, None, 1800),  # 30 minutes
            'mailboxes': CacheEntry(None, None, 900),  # 15 minutes
            'teams_usage': CacheEntry(None, None, 3600), # 1 hour
            'reports': CacheEntry(None, None, 1800),   # 30 minutes
        }
        
        # Performance metrics (matches PowerShell implementation)
        self.performance_metrics = PerformanceMetrics()
        
        # Connection state tracking
        self.graph_connected = False
        self.last_connection_check = None
        self.token_expiry_time = None
        
    def _create_session(self) -> requests.Session:
        """Create HTTP session with retry logic."""
        session = requests.Session()
        
        # Configure retry strategy
        retry_strategy = Retry(
            total=self.config.get('ApiSettings.RetryCount', 3),
            backoff_factor=self.config.get('ApiSettings.RetryDelay', 5),
            status_forcelist=[429, 500, 502, 503, 504],
        )
        
        adapter = HTTPAdapter(max_retries=retry_strategy)
        session.mount("https://", adapter)
        session.mount("http://", adapter)
        
        return session
    
    def initialize(self) -> None:
        """Initialize the Graph client with authentication."""
        auth_method = self.config.get('Authentication.AuthMethod', 'Certificate')
        
        if auth_method == 'Certificate':
            self._init_certificate_auth()
        elif auth_method == 'ClientSecret':
            self._init_client_secret_auth()
        elif auth_method == 'Interactive':
            self._init_interactive_auth()
        else:
            raise ValueError(f"Unsupported authentication method: {auth_method}")
            
        self.logger.info(f"Graph client initialized with {auth_method} authentication")
    
    def _init_certificate_auth(self) -> None:
        """Initialize certificate-based authentication with enhanced error handling."""
        # Support both new and legacy config structures
        cert_path = (self.config.get('Authentication.CertificatePath') or 
                    self.config.get('ExchangeOnline.CertificatePath') or
                    self.config.get('EntraID.CertificatePath'))
        cert_thumbprint = (self.config.get('Authentication.CertificateThumbprint') or
                          self.config.get('ExchangeOnline.CertificateThumbprint') or
                          self.config.get('EntraID.CertificateThumbprint'))
        cert_password = (self.config.get('Authentication.CertificatePassword') or
                        self.config.get('ExchangeOnline.CertificatePassword') or
                        self.config.get('EntraID.CertificatePassword'))
        
        if not cert_path and not cert_thumbprint:
            raise ValueError("証明書パスまたはサムプリントが必要です")
        
        try:
            # Load certificate
            if cert_path:
                import os
                from pathlib import Path
                
                # Support relative paths from project root
                if not os.path.isabs(cert_path):
                    cert_path = Path(__file__).parent.parent.parent.parent / cert_path
                    
                if not os.path.exists(cert_path):
                    raise FileNotFoundError(f"証明書ファイルが見つかりません: {cert_path}")
                    
                with open(cert_path, 'rb') as cert_file:
                    cert_data = cert_file.read()
                    
                self.logger.info(f"証明書を読み込みました: {cert_path}")
                
            else:
                # Load certificate from Windows certificate store by thumbprint
                if not cert_thumbprint:
                    raise ValueError("証明書ストアアクセスにはサムプリントが必要です")
                    
                try:
                    import platform
                    if platform.system() == "Windows":
                        cert_data = self._load_cert_from_store(cert_thumbprint)
                    else:
                        raise NotImplementedError("証明書ストアアクセスはWindowsでのみサポートされています")
                except ImportError:
                    raise NotImplementedError("証明書ストアアクセスライブラリが利用できません")
            
            # Initialize MSAL app with certificate
            tenant_id = (self.config.get('Authentication.TenantId') or 
                        self.config.get('EntraID.TenantId'))
            client_id = (self.config.get('Authentication.ClientId') or 
                        self.config.get('EntraID.ClientId'))
            
            if not tenant_id or not client_id:
                raise ValueError("TenantIdとClientIdが必要です")
            
            self.app = ConfidentialClientApplication(
                client_id,
                authority=f"https://login.microsoftonline.com/{tenant_id}",
                client_credential={
                    "private_key": cert_data,
                    "password": cert_password
                }
            )
            
            self.logger.info("証明書認証の初期化が完了しました")
            
        except Exception as e:
            self.logger.error(f"証明書認証の初期化に失敗しました: {e}")
            raise
    
    def _init_client_secret_auth(self) -> None:
        """Initialize client secret authentication with enhanced error handling."""
        # Support both new and legacy config structures
        tenant_id = (self.config.get('Authentication.TenantId') or 
                    self.config.get('EntraID.TenantId'))
        client_id = (self.config.get('Authentication.ClientId') or 
                    self.config.get('EntraID.ClientId'))
        client_secret = (self.config.get('Authentication.ClientSecret') or 
                        self.config.get('EntraID.ClientSecret'))
        
        if not tenant_id or not client_id or not client_secret:
            raise ValueError("TenantId、ClientId、ClientSecretが必要です")
        
        try:
            self.app = ConfidentialClientApplication(
                client_id,
                authority=f"https://login.microsoftonline.com/{tenant_id}",
                client_credential=client_secret
            )
            self.logger.info("クライアント秘密認証の初期化が完了しました")
            
        except Exception as e:
            self.logger.error(f"クライアント秘密認証の初期化に失敗しました: {e}")
            raise
    
    def _init_interactive_auth(self) -> None:
        """Initialize interactive authentication."""
        self.app = PublicClientApplication(
            self.config.get('Authentication.ClientId'),
            authority=f"https://login.microsoftonline.com/{self.config.get('Authentication.TenantId')}"
        )
    
    def acquire_token(self) -> str:
        """Acquire access token for Graph API with enhanced error handling."""
        if not self.app:
            self.initialize()
        
        try:
            # Try to get token from cache first
            accounts = self.app.get_accounts()
            if accounts:
                self.logger.debug("キャッシュからトークンを取得を試行中...")
                result = self.app.acquire_token_silent(self.DEFAULT_SCOPES, account=accounts[0])
                if result and 'access_token' in result:
                    self.access_token = result['access_token']
                    self.logger.info("キャッシュからトークンを取得しました")
                    return self.access_token
            
            # Get new token
            self.logger.info("新しいアクセストークンを取得中...")
            if isinstance(self.app, ConfidentialClientApplication):
                result = self.app.acquire_token_for_client(scopes=self.DEFAULT_SCOPES)
            else:
                # Interactive flow
                result = self.app.acquire_token_interactive(scopes=self.DEFAULT_SCOPES)
            
            if result and 'access_token' in result:
                self.access_token = result['access_token']
                self.logger.info("アクセストークンを正常に取得しました")
                return self.access_token
            else:
                # Import sanitizer for secure error handling
                from src.security.data_sanitizer import sanitize_error
                
                error = result.get('error', 'Unknown error') if result else 'No result returned'
                error_desc = result.get('error_description', '') if result else ''
                
                # Build sanitized error message (excluding correlation_id for security)
                error_msg = f"トークン取得に失敗: {error}"
                if error_desc:
                    error_msg += f" - {error_desc}"
                
                # Sanitize error message before logging
                sanitized_error_msg = sanitize_error(error_msg)
                self.logger.error(sanitized_error_msg)
                raise Exception(error_msg)
                
        except Exception as e:
            self.logger.error(f"トークン取得中にエラーが発生: {e}")
            raise
    
    def _ensure_token(self) -> None:
        """Ensure we have a valid access token."""
        if not self.access_token:
            self.acquire_token()
    
    def _get_headers(self) -> Dict[str, str]:
        """Get headers for API requests."""
        self._ensure_token()
        return {
            'Authorization': f'Bearer {self.access_token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
    
    def get(self, endpoint: str, params: Optional[Dict] = None) -> Dict[str, Any]:
        """
        Make GET request to Graph API with enhanced error handling.
        
        Args:
            endpoint: API endpoint (e.g., '/users', '/me/messages')
            params: Query parameters
            
        Returns:
            JSON response
        """
        url = f"{self.GRAPH_API_ENDPOINT}/{self.config.get('ApiSettings.GraphApiVersion', 'v1.0')}{endpoint}"
        
        try:
            self.logger.debug(f"GET request: {endpoint}")
            response = self.session.get(
                url,
                headers=self._get_headers(),
                params=params,
                timeout=self.config.get('ApiSettings.Timeout', 300)
            )
            
            # Handle HTTP errors
            if response.status_code == 401:
                self.logger.warning("認証エラー - トークンを再取得します")
                self.access_token = None  # Force token refresh
                response = self.session.get(
                    url,
                    headers=self._get_headers(),
                    params=params,
                    timeout=self.config.get('ApiSettings.Timeout', 300)
                )
            
            response.raise_for_status()
            return response.json()
            
        except requests.exceptions.Timeout:
            error_msg = f"API要求がタイムアウトしました: {endpoint}"
            self.logger.error(error_msg)
            raise Exception(error_msg)
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 403:
                error_msg = f"API権限不足: {endpoint} - 必要な権限が付与されていません"
            elif e.response.status_code == 429:
                error_msg = f"API使用制限に達しました: {endpoint} - しばらく待ってから再試行してください"
            else:
                error_msg = f"HTTP error {e.response.status_code}: {endpoint}"
            
            self.logger.error(error_msg)
            raise Exception(error_msg)
        except requests.exceptions.RequestException as e:
            error_msg = f"ネットワークエラー: {endpoint} - {str(e)}"
            self.logger.error(error_msg)
            raise Exception(error_msg)
        except Exception as e:
            error_msg = f"予期しないエラー: {endpoint} - {str(e)}"
            self.logger.error(error_msg)
            raise
    
    def post(self, endpoint: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Make POST request to Graph API.
        
        Args:
            endpoint: API endpoint
            data: Request body
            
        Returns:
            JSON response
        """
        url = f"{self.GRAPH_API_ENDPOINT}/{self.config.get('ApiSettings.GraphApiVersion', 'v1.0')}{endpoint}"
        
        response = self.session.post(
            url,
            headers=self._get_headers(),
            json=data,
            timeout=self.config.get('ApiSettings.Timeout', 300)
        )
        
        response.raise_for_status()
        return response.json()
    
    def get_all_pages(self, endpoint: str, params: Optional[Dict] = None) -> List[Dict[str, Any]]:
        """
        Get all pages of results from paginated endpoint.
        
        Args:
            endpoint: API endpoint
            params: Query parameters
            
        Returns:
            List of all results
        """
        results = []
        next_link = None
        
        while True:
            if next_link:
                response = self.session.get(
                    next_link,
                    headers=self._get_headers(),
                    timeout=self.config.get('ApiSettings.Timeout', 300)
                )
                response.raise_for_status()
                data = response.json()
            else:
                data = self.get(endpoint, params)
            
            # Add results
            if 'value' in data:
                results.extend(data['value'])
            else:
                results.append(data)
            
            # Check for next page
            next_link = data.get('@odata.nextLink')
            if not next_link:
                break
                
        return results
    
    # Convenience methods for common operations
    
    def get_users(self, select: Optional[List[str]] = None, limit: Optional[int] = None) -> List[Dict[str, Any]]:
        """Get all users."""
        params = {}
        if select:
            params['$select'] = ','.join(select)
        if limit:
            params['$top'] = min(limit, 999)
        
        if limit and limit <= 999:
            # Single request for small limits
            response = self.get('/users', params)
            return response.get('value', [])
        else:
            # Paginated request for larger limits
            return self.get_all_pages('/users', params)
    
    def get_user(self, user_id: str) -> Dict[str, Any]:
        """Get specific user."""
        return self.get(f'/users/{user_id}')
    
    def get_groups(self, select: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        """Get all groups."""
        params = {}
        if select:
            params['$select'] = ','.join(select)
        return self.get_all_pages('/groups', params)
    
    def get_licenses(self) -> List[Dict[str, Any]]:
        """Get organization licenses."""
        return self.get_all_pages('/subscribedSkus')
    
    def get_users_with_auth_methods(self, limit: int = 1000) -> List[Dict[str, Any]]:
        """Get users with their authentication methods."""
        params = {
            '$select': 'id,displayName,userPrincipalName,accountEnabled,signInActivity',
            '$top': min(limit, 999)
        }
        users = self.get('/users', params).get('value', [])
        
        # Get authentication methods for each user (simplified for demo)
        for user in users:
            try:
                auth_methods = self.get(f"/users/{user['id']}/authentication/methods")
                user['authenticationMethods'] = auth_methods.get('value', [])
            except:
                user['authenticationMethods'] = []
        
        return users
    
    def get_subscriptions(self) -> List[Dict[str, Any]]:
        """Get organization subscriptions."""
        return self.get_all_pages('/subscribedSkus')
    
    def _load_cert_from_store(self, thumbprint: str) -> bytes:
        """Load certificate from Windows certificate store by thumbprint."""
        try:
            import wincertstore
            import binascii
            
            # Remove any spaces or colons from thumbprint
            clean_thumbprint = thumbprint.replace(" ", "").replace(":", "").upper()
            
            # Search in different certificate stores
            stores = ["MY", "ROOT", "CA"]
            
            for store_name in stores:
                store = wincertstore.CertSystemStore(store_name)
                
                for cert in store.itercerts(usage=wincertstore.SERVER_AUTH):
                    cert_thumbprint = binascii.hexlify(cert.get_fingerprint()).decode().upper()
                    
                    if cert_thumbprint == clean_thumbprint:
                        self.logger.info(f"証明書が見つかりました: {store_name}ストア")
                        return cert.get_pem().encode()
            
            raise FileNotFoundError(f"証明書が見つかりません (サムプリント: {thumbprint})")
            
        except ImportError:
            self.logger.error("wincertstoreライブラリが利用できません")
            raise NotImplementedError("Windows証明書ストアアクセスにはwincertstoreが必要です")
    
    def get_license_usage(self) -> List[Dict[str, Any]]:
        """Get license usage statistics."""
        try:
            return self.get('/reports/getOffice365ServicesUserCounts(period=\'D7\')').get('value', [])
        except:
            # Fallback to basic subscription data
            return self.get_subscriptions()
    
    def get_teams_usage_reports(self) -> List[Dict[str, Any]]:
        """Get Teams usage reports."""
        try:
            teams_data = self.get('/reports/getTeamsUserActivityUserDetail(period=\'D7\')').get('value', [])
            return teams_data
        except:
            # Return mock data if reporting APIs are not available
            return []
    
    def get_onedrive_usage(self) -> List[Dict[str, Any]]:
        """Get OneDrive usage data."""
        try:
            return self.get('/reports/getOneDriveUsageAccountDetail(period=\'D7\')').get('value', [])
        except:
            return []
    
    def get_mailbox_usage(self) -> List[Dict[str, Any]]:
        """Get mailbox usage data."""
        try:
            return self.get('/reports/getMailboxUsageDetail(period=\'D7\')').get('value', [])
        except:
            return []