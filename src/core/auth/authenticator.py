"""
Base authenticator module providing common authentication functionality.
"""

import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum
from typing import Optional, Dict, Any, List
import json
from pathlib import Path


class AuthenticationMethod(Enum):
    """Supported authentication methods."""
    CERTIFICATE = "Certificate"
    CLIENT_SECRET = "ClientSecret"
    INTERACTIVE = "Interactive"
    DEVICE_CODE = "DeviceCode"
    USERNAME_PASSWORD = "UsernamePassword"  # Not recommended
    MANAGED_IDENTITY = "ManagedIdentity"


@dataclass
class AuthenticationResult:
    """Result of authentication attempt."""
    success: bool
    access_token: Optional[str] = None
    expires_at: Optional[datetime] = None
    refresh_token: Optional[str] = None
    token_type: str = "Bearer"
    scope: Optional[str] = None
    error: Optional[str] = None
    error_description: Optional[str] = None
    id_token: Optional[str] = None
    
    @property
    def is_expired(self) -> bool:
        """Check if the token is expired."""
        if not self.expires_at:
            return True
        return datetime.utcnow() >= self.expires_at
    
    @property
    def expires_in_seconds(self) -> int:
        """Get seconds until token expiration."""
        if not self.expires_at:
            return 0
        delta = self.expires_at - datetime.utcnow()
        return max(0, int(delta.total_seconds()))


class TokenCache:
    """Simple token cache implementation."""
    
    def __init__(self, cache_file: Optional[Path] = None):
        self.cache_file = cache_file or Path.home() / ".m365_token_cache.json"
        self._cache: Dict[str, Dict[str, Any]] = {}
        self._load_cache()
    
    def _load_cache(self):
        """Load cache from file."""
        if self.cache_file.exists():
            try:
                with open(self.cache_file, 'r') as f:
                    self._cache = json.load(f)
            except Exception:
                self._cache = {}
    
    def _save_cache(self):
        """Save cache to file with secure permissions."""
        try:
            import os
            import stat
            
            self.cache_file.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            
            # Create file with secure permissions (owner read/write only)
            with open(self.cache_file, 'w') as f:
                json.dump(self._cache, f, indent=2, default=str)
            
            # Set secure file permissions (600 - owner read/write only)
            os.chmod(self.cache_file, stat.S_IRUSR | stat.S_IWUSR)
            
        except Exception as e:
            # Log security-relevant errors
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"Failed to save token cache securely: {e}")
            pass  # Cache is optional
    
    def get_token(self, key: str) -> Optional[AuthenticationResult]:
        """Get token from cache."""
        if key in self._cache:
            token_data = self._cache[key]
            expires_at = datetime.fromisoformat(token_data['expires_at'])
            
            # Check if token is still valid (with 5 minute buffer)
            if datetime.utcnow() < (expires_at - timedelta(minutes=5)):
                return AuthenticationResult(
                    success=True,
                    access_token=token_data['access_token'],
                    expires_at=expires_at,
                    refresh_token=token_data.get('refresh_token'),
                    token_type=token_data.get('token_type', 'Bearer'),
                    scope=token_data.get('scope')
                )
        return None
    
    def set_token(self, key: str, result: AuthenticationResult):
        """Store token in cache."""
        if result.success and result.access_token:
            self._cache[key] = {
                'access_token': result.access_token,
                'expires_at': result.expires_at.isoformat(),
                'refresh_token': result.refresh_token,
                'token_type': result.token_type,
                'scope': result.scope
            }
            self._save_cache()
    
    def clear_token(self, key: str):
        """Remove token from cache."""
        if key in self._cache:
            del self._cache[key]
            self._save_cache()


class Authenticator(ABC):
    """Base authenticator class."""
    
    def __init__(self, tenant_id: str, client_id: str, 
                 scopes: Optional[List[str]] = None,
                 cache_tokens: bool = True):
        """
        Initialize authenticator.
        
        Args:
            tenant_id: Azure AD tenant ID
            client_id: Application (client) ID
            scopes: List of scopes to request
            cache_tokens: Whether to cache tokens
        """
        self.tenant_id = tenant_id
        self.client_id = client_id
        self.scopes = scopes or []
        self.logger = logging.getLogger(f"{__name__}.{self.__class__.__name__}")
        
        # Token cache
        self.token_cache = TokenCache() if cache_tokens else None
        self._current_token: Optional[AuthenticationResult] = None
    
    @abstractmethod
    async def authenticate_async(self, method: AuthenticationMethod, 
                                **kwargs) -> AuthenticationResult:
        """Authenticate asynchronously."""
        pass
    
    def authenticate(self, method: AuthenticationMethod, 
                    **kwargs) -> AuthenticationResult:
        """Authenticate synchronously."""
        import asyncio
        
        # Check cache first
        cache_key = self._get_cache_key(method, **kwargs)
        if self.token_cache:
            cached_token = self.token_cache.get_token(cache_key)
            if cached_token:
                self.logger.info("Using cached token")
                self._current_token = cached_token
                return cached_token
        
        # Run async authentication
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            result = loop.run_until_complete(
                self.authenticate_async(method, **kwargs)
            )
            
            # Cache successful result
            if result.success and self.token_cache:
                self.token_cache.set_token(cache_key, result)
            
            self._current_token = result
            return result
        finally:
            loop.close()
    
    def get_current_token(self) -> Optional[str]:
        """Get current access token if valid."""
        if self._current_token and not self._current_token.is_expired:
            return self._current_token.access_token
        return None
    
    def _get_cache_key(self, method: AuthenticationMethod, **kwargs) -> str:
        """Generate cache key for token."""
        key_parts = [
            self.tenant_id,
            self.client_id,
            method.value,
            "-".join(sorted(self.scopes))
        ]
        
        # Add method-specific parts
        if method == AuthenticationMethod.CERTIFICATE:
            key_parts.append(kwargs.get('thumbprint', ''))
        elif method == AuthenticationMethod.CLIENT_SECRET:
            # Don't include secret in key
            pass
        elif method == AuthenticationMethod.USERNAME_PASSWORD:
            key_parts.append(kwargs.get('username', ''))
        
        return ":".join(key_parts)
    
    def _handle_token_response(self, response: Dict[str, Any]) -> AuthenticationResult:
        """Handle token response from authentication endpoint."""
        if 'error' in response:
            return AuthenticationResult(
                success=False,
                error=response.get('error'),
                error_description=response.get('error_description')
            )
        
        if 'access_token' in response:
            # Calculate expiration time
            expires_in = response.get('expires_in', 3600)
            expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
            
            return AuthenticationResult(
                success=True,
                access_token=response['access_token'],
                expires_at=expires_at,
                refresh_token=response.get('refresh_token'),
                token_type=response.get('token_type', 'Bearer'),
                scope=response.get('scope'),
                id_token=response.get('id_token')
            )
        
        return AuthenticationResult(
            success=False,
            error='invalid_response',
            error_description='No access token in response'
        )
    
    async def refresh_token_async(self, refresh_token: str) -> AuthenticationResult:
        """Refresh access token using refresh token."""
        self.logger.info("Refreshing access token")
        # Implementation depends on specific service
        raise NotImplementedError("Subclass must implement refresh_token_async")
    
    def clear_cache(self):
        """Clear all cached tokens."""
        if self.token_cache:
            # Clear all tokens for this authenticator
            # In a real implementation, we'd clear only relevant tokens
            self.logger.info("Clearing token cache")
        self._current_token = None