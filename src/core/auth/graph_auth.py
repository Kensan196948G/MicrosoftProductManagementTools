"""
Microsoft Graph API authentication implementation.
Supports multiple authentication methods including certificate-based auth.
"""

import logging
from typing import Optional, List, Dict, Any
from pathlib import Path
import base64
import json
from datetime import datetime, timedelta

try:
    from msal import ConfidentialClientApplication, PublicClientApplication
    MSAL_AVAILABLE = True
except ImportError:
    MSAL_AVAILABLE = False
    
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.serialization import pkcs12

from .authenticator import Authenticator, AuthenticationMethod, AuthenticationResult
from .certificate_manager import CertificateManager


class GraphAuthenticator(Authenticator):
    """Microsoft Graph API authenticator."""
    
    AUTHORITY_URL = "https://login.microsoftonline.com/{tenant_id}"
    GRAPH_SCOPE = "https://graph.microsoft.com/.default"
    
    def __init__(self, tenant_id: str, client_id: str,
                 scopes: Optional[List[str]] = None,
                 cache_tokens: bool = True):
        """Initialize Graph authenticator."""
        # Default to Graph scope if none provided
        if not scopes:
            scopes = [self.GRAPH_SCOPE]
        
        super().__init__(tenant_id, client_id, scopes, cache_tokens)
        
        self.authority = self.AUTHORITY_URL.format(tenant_id=tenant_id)
        self._msal_app: Optional[Any] = None
        self._cert_manager = CertificateManager()
        
        if not MSAL_AVAILABLE:
            self.logger.warning("MSAL not available. Install with: pip install msal")
    
    async def authenticate_async(self, method: AuthenticationMethod,
                                **kwargs) -> AuthenticationResult:
        """Authenticate to Microsoft Graph."""
        self.logger.info(f"Authenticating to Graph API using {method.value}")
        
        if not MSAL_AVAILABLE:
            return AuthenticationResult(
                success=False,
                error="msal_not_available",
                error_description="MSAL library is not installed"
            )
        
        try:
            if method == AuthenticationMethod.CERTIFICATE:
                return await self._auth_certificate(**kwargs)
            elif method == AuthenticationMethod.CLIENT_SECRET:
                return await self._auth_client_secret(**kwargs)
            elif method == AuthenticationMethod.INTERACTIVE:
                return await self._auth_interactive(**kwargs)
            elif method == AuthenticationMethod.DEVICE_CODE:
                return await self._auth_device_code(**kwargs)
            else:
                return AuthenticationResult(
                    success=False,
                    error="unsupported_method",
                    error_description=f"Authentication method {method.value} not supported"
                )
        except Exception as e:
            self.logger.error(f"Authentication failed: {e}")
            return AuthenticationResult(
                success=False,
                error="authentication_error",
                error_description=str(e)
            )
    
    async def _auth_certificate(self, certificate_path: Optional[str] = None,
                               certificate_data: Optional[bytes] = None,
                               certificate_password: Optional[str] = None,
                               thumbprint: Optional[str] = None,
                               **kwargs) -> AuthenticationResult:
        """Authenticate using certificate."""
        try:
            # Load certificate
            if certificate_path:
                cert_data = self._cert_manager.load_certificate_from_file(
                    Path(certificate_path),
                    password=certificate_password
                )
            elif certificate_data:
                cert_data = self._cert_manager.load_certificate_from_bytes(
                    certificate_data,
                    password=certificate_password
                )
            elif thumbprint:
                # Windows証明書ストアから読み込み
                cert_data = self._cert_manager.load_certificate_from_store(thumbprint)
            else:
                raise ValueError("証明書パス、データ、またはサムプリントが必要です")
            
            # Create MSAL app with certificate
            app = ConfidentialClientApplication(
                self.client_id,
                authority=self.authority,
                client_credential={
                    "private_key": cert_data['private_key'],
                    "thumbprint": cert_data['thumbprint'],
                    "public_certificate": cert_data.get('public_certificate', 
                                                       cert_data.get('certificate'))
                }
            )
            
            # Acquire token
            result = app.acquire_token_for_client(scopes=self.scopes)
            
            return self._handle_token_response(result)
            
        except Exception as e:
            self.logger.error(f"Certificate authentication failed: {e}")
            return AuthenticationResult(
                success=False,
                error="certificate_auth_failed",
                error_description=str(e)
            )
    
    async def _auth_client_secret(self, client_secret: str, **kwargs) -> AuthenticationResult:
        """Authenticate using client secret."""
        try:
            app = ConfidentialClientApplication(
                self.client_id,
                authority=self.authority,
                client_credential=client_secret
            )
            
            result = app.acquire_token_for_client(scopes=self.scopes)
            
            return self._handle_token_response(result)
            
        except Exception as e:
            self.logger.error(f"Client secret authentication failed: {e}")
            return AuthenticationResult(
                success=False,
                error="client_secret_auth_failed",
                error_description=str(e)
            )
    
    async def _auth_interactive(self, **kwargs) -> AuthenticationResult:
        """Authenticate using interactive browser flow."""
        try:
            app = PublicClientApplication(
                self.client_id,
                authority=self.authority
            )
            
            # Try to get token from cache first
            accounts = app.get_accounts()
            if accounts:
                result = app.acquire_token_silent(
                    self.scopes,
                    account=accounts[0]
                )
                if result:
                    return self._handle_token_response(result)
            
            # Interactive authentication
            result = app.acquire_token_interactive(
                scopes=self.scopes,
                prompt="select_account"
            )
            
            return self._handle_token_response(result)
            
        except Exception as e:
            self.logger.error(f"Interactive authentication failed: {e}")
            return AuthenticationResult(
                success=False,
                error="interactive_auth_failed",
                error_description=str(e)
            )
    
    async def _auth_device_code(self, **kwargs) -> AuthenticationResult:
        """Authenticate using device code flow."""
        try:
            app = PublicClientApplication(
                self.client_id,
                authority=self.authority
            )
            
            # Start device code flow
            flow = app.initiate_device_flow(scopes=self.scopes)
            
            if "user_code" not in flow:
                raise ValueError("Failed to create device flow")
            
            # Display instructions to user
            print(f"\n{flow['message']}\n")
            
            # Wait for user to complete authentication
            result = app.acquire_token_by_device_flow(flow)
            
            return self._handle_token_response(result)
            
        except Exception as e:
            self.logger.error(f"Device code authentication failed: {e}")
            return AuthenticationResult(
                success=False,
                error="device_code_auth_failed",
                error_description=str(e)
            )
    
    async def refresh_token_async(self, refresh_token: str) -> AuthenticationResult:
        """Refresh access token using refresh token."""
        try:
            # For public client apps only
            app = PublicClientApplication(
                self.client_id,
                authority=self.authority
            )
            
            # MSAL doesn't directly expose refresh token flow
            # It handles it internally through acquire_token_silent
            accounts = app.get_accounts()
            if accounts:
                result = app.acquire_token_silent(
                    self.scopes,
                    account=accounts[0]
                )
                if result:
                    return self._handle_token_response(result)
            
            return AuthenticationResult(
                success=False,
                error="refresh_failed",
                error_description="Could not refresh token"
            )
            
        except Exception as e:
            self.logger.error(f"Token refresh failed: {e}")
            return AuthenticationResult(
                success=False,
                error="refresh_error",
                error_description=str(e)
            )
    
    def validate_token(self, token: str) -> bool:
        """Validate Graph API token."""
        try:
            # Decode token (without verification for now)
            parts = token.split('.')
            if len(parts) != 3:
                return False
            
            # Decode payload
            payload = parts[1]
            # Add padding if needed
            payload += '=' * (4 - len(payload) % 4)
            decoded = base64.urlsafe_b64decode(payload)
            claims = json.loads(decoded)
            
            # Check expiration
            exp = claims.get('exp', 0)
            if datetime.utcnow().timestamp() >= exp:
                return False
            
            # Check audience
            aud = claims.get('aud', '')
            if 'graph.microsoft.com' not in aud and '00000003-0000-0000-c000-000000000000' not in aud:
                return False
            
            return True
            
        except Exception:
            return False
    
    def get_token_info(self, token: str) -> Dict[str, Any]:
        """Get information from token."""
        try:
            parts = token.split('.')
            if len(parts) != 3:
                return {}
            
            # Decode payload
            payload = parts[1]
            payload += '=' * (4 - len(payload) % 4)
            decoded = base64.urlsafe_b64decode(payload)
            claims = json.loads(decoded)
            
            # Extract relevant info
            exp_timestamp = claims.get('exp', 0)
            exp_datetime = datetime.utcfromtimestamp(exp_timestamp)
            
            return {
                'app_id': claims.get('appid', ''),
                'tenant_id': claims.get('tid', ''),
                'scope': claims.get('scp', ''),
                'expires_at': exp_datetime.isoformat(),
                'expires_in': int((exp_datetime - datetime.utcnow()).total_seconds()),
                'app_name': claims.get('app_displayname', ''),
                'issued_at': datetime.utcfromtimestamp(claims.get('iat', 0)).isoformat()
            }
            
        except Exception:
            return {}