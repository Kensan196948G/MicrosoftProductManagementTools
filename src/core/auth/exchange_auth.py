"""
Exchange Online authentication implementation.
Supports PowerShell-based and modern authentication methods.
"""

import logging
from typing import Optional, List, Dict, Any
from pathlib import Path
import base64
import json
from datetime import datetime, timedelta

from .authenticator import Authenticator, AuthenticationMethod, AuthenticationResult
from .graph_auth import GraphAuthenticator
from ..powershell_bridge import PowerShellBridge, PowerShellResult


class ExchangeAuthenticator(Authenticator):
    """Exchange Online authenticator."""
    
    EXO_PS_MODULE = "ExchangeOnlineManagement"
    EXO_SCOPE = "https://outlook.office365.com/.default"
    
    def __init__(self, tenant_id: str, client_id: str,
                 organization: Optional[str] = None,
                 scopes: Optional[List[str]] = None,
                 cache_tokens: bool = True,
                 use_powershell: bool = True):
        """
        Initialize Exchange authenticator.
        
        Args:
            tenant_id: Azure AD tenant ID
            client_id: Application (client) ID
            organization: Organization name for PowerShell connection
            scopes: List of scopes to request
            cache_tokens: Whether to cache tokens
            use_powershell: Whether to use PowerShell for Exchange management
        """
        # Default to Exchange scope if none provided
        if not scopes:
            scopes = [self.EXO_SCOPE]
        
        super().__init__(tenant_id, client_id, scopes, cache_tokens)
        
        self.organization = organization or tenant_id
        self.use_powershell = use_powershell
        self._ps_bridge: Optional[PowerShellBridge] = None
        self._graph_auth: Optional[GraphAuthenticator] = None
        self._connected = False
    
    async def authenticate_async(self, method: AuthenticationMethod,
                                **kwargs) -> AuthenticationResult:
        """Authenticate to Exchange Online."""
        self.logger.info(f"Authenticating to Exchange Online using {method.value}")
        
        try:
            # For modern auth, use Graph authenticator
            if method in [AuthenticationMethod.CERTIFICATE, 
                         AuthenticationMethod.CLIENT_SECRET]:
                # Use Graph auth for token acquisition
                if not self._graph_auth:
                    self._graph_auth = GraphAuthenticator(
                        self.tenant_id,
                        self.client_id,
                        scopes=self.scopes,
                        cache_tokens=self.token_cache is not None
                    )
                
                result = await self._graph_auth.authenticate_async(method, **kwargs)
                
                # If successful and using PowerShell, connect to Exchange
                if result.success and self.use_powershell:
                    await self._connect_exchange_powershell(result.access_token, method, **kwargs)
                
                return result
            
            elif method == AuthenticationMethod.INTERACTIVE:
                # Use PowerShell interactive auth
                return await self._auth_interactive_powershell(**kwargs)
            
            else:
                return AuthenticationResult(
                    success=False,
                    error="unsupported_method",
                    error_description=f"Authentication method {method.value} not supported for Exchange"
                )
                
        except Exception as e:
            self.logger.error(f"Exchange authentication failed: {e}")
            return AuthenticationResult(
                success=False,
                error="authentication_error",
                error_description=str(e)
            )
    
    async def _connect_exchange_powershell(self, access_token: Optional[str],
                                          method: AuthenticationMethod,
                                          **kwargs) -> bool:
        """Connect to Exchange Online PowerShell."""
        try:
            if not self._ps_bridge:
                self._ps_bridge = PowerShellBridge()
            
            # Check if module is installed
            check_module = self._ps_bridge.execute_command(
                f"Get-Module -ListAvailable -Name {self.EXO_PS_MODULE}"
            )
            
            if not check_module.success or not check_module.data:
                self.logger.error(f"{self.EXO_PS_MODULE} module not found")
                # Try to install module
                install_result = await self._install_exo_module()
                if not install_result:
                    return False
            
            # Import module
            import_result = self._ps_bridge.import_module(self.EXO_PS_MODULE)
            if not import_result.success:
                self.logger.error(f"Failed to import {self.EXO_PS_MODULE}")
                return False
            
            # Build connection command based on method
            if method == AuthenticationMethod.CERTIFICATE:
                cert_path = kwargs.get('certificate_path')
                cert_thumbprint = kwargs.get('thumbprint')
                
                if cert_thumbprint:
                    connect_cmd = f"""
                    Connect-ExchangeOnline -CertificateThumbprint '{cert_thumbprint}' `
                        -AppId '{self.client_id}' `
                        -Organization '{self.organization}' `
                        -ShowBanner:$false
                    """
                elif cert_path:
                    # Load certificate first
                    cert_password = kwargs.get('certificate_password', '')
                    load_cert_cmd = f"""
                    $certPath = '{cert_path}'
                    $certPassword = ConvertTo-SecureString -String '{cert_password}' -AsPlainText -Force
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath, $certPassword)
                    """
                    self._ps_bridge.execute_command(load_cert_cmd, return_json=False)
                    
                    connect_cmd = f"""
                    Connect-ExchangeOnline -Certificate $cert `
                        -AppId '{self.client_id}' `
                        -Organization '{self.organization}' `
                        -ShowBanner:$false
                    """
                else:
                    raise ValueError("証明書パスまたはサムプリントが必要です")
            
            elif access_token:
                # Use access token
                connect_cmd = f"""
                Connect-ExchangeOnline -AccessToken '{access_token}' `
                    -Organization '{self.organization}' `
                    -ShowBanner:$false
                """
            
            else:
                raise ValueError("認証情報が不足しています")
            
            # Connect to Exchange Online
            connect_result = self._ps_bridge.execute_command(connect_cmd, return_json=False)
            
            if connect_result.success:
                self._connected = True
                self.logger.info("Successfully connected to Exchange Online PowerShell")
                
                # Verify connection
                verify_result = self._ps_bridge.execute_command(
                    "Get-ConnectionInformation | Select-Object State, UserPrincipalName"
                )
                if verify_result.success and verify_result.data:
                    self.logger.info(f"Connection verified: {verify_result.data}")
                
                return True
            else:
                self.logger.error(f"Failed to connect: {connect_result.error_message}")
                return False
                
        except Exception as e:
            self.logger.error(f"PowerShell connection failed: {e}")
            return False
    
    async def _auth_interactive_powershell(self, **kwargs) -> AuthenticationResult:
        """Interactive authentication using PowerShell."""
        try:
            if not self._ps_bridge:
                self._ps_bridge = PowerShellBridge()
            
            # Import module
            import_result = self._ps_bridge.import_module(self.EXO_PS_MODULE)
            if not import_result.success:
                return AuthenticationResult(
                    success=False,
                    error="module_import_failed",
                    error_description=f"Failed to import {self.EXO_PS_MODULE}"
                )
            
            # Connect interactively
            connect_cmd = f"""
            Connect-ExchangeOnline -Organization '{self.organization}' `
                -ShowBanner:$false
            """
            
            connect_result = self._ps_bridge.execute_command(connect_cmd, return_json=False)
            
            if connect_result.success:
                self._connected = True
                
                # Get connection info
                info_result = self._ps_bridge.execute_command(
                    "Get-ConnectionInformation | Select-Object -First 1"
                )
                
                # Create pseudo token for compatibility
                expires_at = datetime.utcnow() + timedelta(hours=1)
                
                return AuthenticationResult(
                    success=True,
                    access_token="PowerShell-Session",  # Placeholder
                    expires_at=expires_at,
                    scope=self.EXO_SCOPE
                )
            else:
                return AuthenticationResult(
                    success=False,
                    error="connection_failed",
                    error_description=connect_result.error_message or "Connection failed"
                )
                
        except Exception as e:
            return AuthenticationResult(
                success=False,
                error="interactive_auth_failed",
                error_description=str(e)
            )
    
    async def _install_exo_module(self) -> bool:
        """Install Exchange Online Management module."""
        try:
            self.logger.info(f"Installing {self.EXO_PS_MODULE} module...")
            
            install_cmd = f"""
            if (-not (Get-Module -ListAvailable -Name {self.EXO_PS_MODULE})) {{
                Install-Module -Name {self.EXO_PS_MODULE} -Force -AllowClobber -Scope CurrentUser
            }}
            """
            
            result = self._ps_bridge.execute_command(install_cmd, return_json=False, timeout=300)
            
            if result.success:
                self.logger.info(f"{self.EXO_PS_MODULE} module installed successfully")
                return True
            else:
                self.logger.error(f"Failed to install module: {result.error_message}")
                return False
                
        except Exception as e:
            self.logger.error(f"Module installation failed: {e}")
            return False
    
    def disconnect(self):
        """Disconnect from Exchange Online."""
        if self._connected and self._ps_bridge:
            try:
                disconnect_result = self._ps_bridge.execute_command(
                    "Disconnect-ExchangeOnline -Confirm:$false",
                    return_json=False
                )
                if disconnect_result.success:
                    self.logger.info("Disconnected from Exchange Online")
                self._connected = False
            except Exception as e:
                self.logger.error(f"Disconnect failed: {e}")
    
    def execute_exchange_command(self, command: str, **kwargs) -> PowerShellResult:
        """Execute Exchange Online PowerShell command."""
        if not self._connected:
            raise RuntimeError("Not connected to Exchange Online")
        
        if not self._ps_bridge:
            raise RuntimeError("PowerShell bridge not initialized")
        
        return self._ps_bridge.execute_command(command, **kwargs)
    
    def get_mailboxes(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get mailboxes using Exchange PowerShell."""
        if not self._connected:
            return []
        
        result = self.execute_exchange_command(
            f"Get-Mailbox -ResultSize {limit} | Select-Object DisplayName, UserPrincipalName, PrimarySmtpAddress, WhenCreated"
        )
        
        if result.success and result.data:
            return result.data if isinstance(result.data, list) else [result.data]
        return []
    
    def __enter__(self):
        """Context manager entry."""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.disconnect()