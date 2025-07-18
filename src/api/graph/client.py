"""
Microsoft Graph API client implementation.
Provides authentication and API access for Microsoft 365 services.
"""

import logging
from typing import Dict, Any, Optional, List
import asyncio
from msal import ConfidentialClientApplication, PublicClientApplication
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from src.core.config import Config


class GraphClient:
    """
    Microsoft Graph API client with authentication support.
    Supports certificate-based and client secret authentication.
    """
    
    GRAPH_API_ENDPOINT = 'https://graph.microsoft.com'
    DEFAULT_SCOPES = ['https://graph.microsoft.com/.default']
    
    def __init__(self, config: Config):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.access_token = None
        self.app = None
        self.session = self._create_session()
        
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
    
    def initialize(self):
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
    
    def _init_certificate_auth(self):
        """Initialize certificate-based authentication."""
        cert_path = self.config.get('Authentication.CertificatePath')
        cert_thumbprint = self.config.get('Authentication.CertificateThumbprint')
        cert_password = self.config.get('Authentication.CertificatePassword')
        
        if not cert_path and not cert_thumbprint:
            raise ValueError("Certificate path or thumbprint required for certificate auth")
        
        # Load certificate
        if cert_path:
            with open(cert_path, 'rb') as cert_file:
                cert_data = cert_file.read()
        else:
            # TODO: Load certificate from Windows certificate store by thumbprint
            raise NotImplementedError("Certificate store access not yet implemented")
        
        self.app = ConfidentialClientApplication(
            self.config.get('Authentication.ClientId'),
            authority=f"https://login.microsoftonline.com/{self.config.get('Authentication.TenantId')}",
            client_credential={
                "private_key": cert_data,
                "password": cert_password
            }
        )
    
    def _init_client_secret_auth(self):
        """Initialize client secret authentication."""
        self.app = ConfidentialClientApplication(
            self.config.get('Authentication.ClientId'),
            authority=f"https://login.microsoftonline.com/{self.config.get('Authentication.TenantId')}",
            client_credential=self.config.get('Authentication.ClientSecret')
        )
    
    def _init_interactive_auth(self):
        """Initialize interactive authentication."""
        self.app = PublicClientApplication(
            self.config.get('Authentication.ClientId'),
            authority=f"https://login.microsoftonline.com/{self.config.get('Authentication.TenantId')}"
        )
    
    def acquire_token(self) -> str:
        """Acquire access token for Graph API."""
        if not self.app:
            self.initialize()
        
        # Try to get token from cache first
        accounts = self.app.get_accounts()
        if accounts:
            result = self.app.acquire_token_silent(self.DEFAULT_SCOPES, account=accounts[0])
            if result and 'access_token' in result:
                self.access_token = result['access_token']
                return self.access_token
        
        # Get new token
        if isinstance(self.app, ConfidentialClientApplication):
            result = self.app.acquire_token_for_client(scopes=self.DEFAULT_SCOPES)
        else:
            # Interactive flow
            result = self.app.acquire_token_interactive(scopes=self.DEFAULT_SCOPES)
        
        if 'access_token' in result:
            self.access_token = result['access_token']
            self.logger.info("Successfully acquired access token")
            return self.access_token
        else:
            error = result.get('error', 'Unknown error')
            error_desc = result.get('error_description', '')
            raise Exception(f"Failed to acquire token: {error} - {error_desc}")
    
    def _ensure_token(self):
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
        Make GET request to Graph API.
        
        Args:
            endpoint: API endpoint (e.g., '/users', '/me/messages')
            params: Query parameters
            
        Returns:
            JSON response
        """
        url = f"{self.GRAPH_API_ENDPOINT}/{self.config.get('ApiSettings.GraphApiVersion', 'v1.0')}{endpoint}"
        
        response = self.session.get(
            url,
            headers=self._get_headers(),
            params=params,
            timeout=self.config.get('ApiSettings.Timeout', 300)
        )
        
        response.raise_for_status()
        return response.json()
    
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