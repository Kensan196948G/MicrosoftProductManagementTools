#!/usr/bin/env python3
"""
Azure Key Vault Authentication Module - Phase 2 Enterprise Production
証明書ベース認証・DefaultAzureCredential統合・本格運用対応
"""

import os
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, Union, List
from pathlib import Path

from azure.identity import DefaultAzureCredential, CertificateCredential, ManagedIdentityCredential
from azure.keyvault.secrets import SecretClient
from azure.keyvault.keys import KeyClient
from azure.keyvault.certificates import CertificateClient
from azure.core.exceptions import ResourceNotFoundError, HttpResponseError, ServiceRequestError
from azure.core.credentials import TokenCredential
import asyncio
from azure.identity.aio import DefaultAzureCredential as AsyncDefaultAzureCredential

logger = logging.getLogger(__name__)


class AzureKeyVaultAuth:
    """
    Azure Key Vault Authentication Manager - Enterprise Production
    証明書ベース認証・DefaultAzureCredential・本格運用セキュリティ対応
    """
    
    def __init__(self, 
                 vault_url: str = None,
                 credential: TokenCredential = None,
                 tenant_id: str = None,
                 client_id: str = None,
                 certificate_path: str = None,
                 certificate_password: str = None,
                 managed_identity_client_id: str = None,
                 enable_caching: bool = True,
                 retry_attempts: int = 3):
        """
        Initialize Azure Key Vault Authentication Manager
        
        Args:
            vault_url: Azure Key Vault URL
            credential: Azure credential instance
            tenant_id: Azure tenant ID
            client_id: Azure client ID
            certificate_path: Path to certificate file
            certificate_password: Certificate password
            managed_identity_client_id: Managed Identity client ID
            enable_caching: Enable credential caching
            retry_attempts: Number of retry attempts
        """
        self.vault_url = vault_url or os.getenv("AZURE_KEYVAULT_URL")
        self.tenant_id = tenant_id or os.getenv("AZURE_TENANT_ID")
        self.client_id = client_id or os.getenv("AZURE_CLIENT_ID")
        self.certificate_path = certificate_path or os.getenv("AZURE_CLIENT_CERTIFICATE_PATH")
        self.certificate_password = certificate_password or os.getenv("AZURE_CLIENT_CERTIFICATE_PASSWORD")
        self.managed_identity_client_id = managed_identity_client_id or os.getenv("AZURE_CLIENT_ID")
        self.enable_caching = enable_caching
        self.retry_attempts = retry_attempts
        
        # Initialize credentials
        self.credential = credential or self._create_credential()
        
        # Initialize Key Vault clients
        self.secret_client = None
        self.key_client = None
        self.certificate_client = None
        
        # Cache for credentials and tokens
        self._credential_cache: Dict[str, Any] = {}
        self._token_cache: Dict[str, tuple] = {}
        
        logger.info(f"AzureKeyVaultAuth initialized with vault: {self.vault_url}")
    
    def _create_credential(self) -> TokenCredential:
        """
        Create appropriate Azure credential based on environment
        優先順位: Certificate > Managed Identity > Default
        """
        try:
            # 1. Certificate-based authentication (highest priority)
            if self.certificate_path and Path(self.certificate_path).exists():
                logger.info("Using certificate-based authentication")
                return CertificateCredential(
                    tenant_id=self.tenant_id,
                    client_id=self.client_id,
                    certificate_path=self.certificate_path,
                    password=self.certificate_password
                )
            
            # 2. Managed Identity authentication
            if self.managed_identity_client_id and self._is_managed_identity_environment():
                logger.info("Using managed identity authentication")
                return ManagedIdentityCredential(client_id=self.managed_identity_client_id)
            
            # 3. Default Azure credential (fallback)
            logger.info("Using DefaultAzureCredential")
            return DefaultAzureCredential()
            
        except Exception as e:
            logger.error(f"Failed to create credential: {str(e)}")
            # Fallback to DefaultAzureCredential
            return DefaultAzureCredential()
    
    def _is_managed_identity_environment(self) -> bool:
        """
        Check if running in managed identity environment
        """
        managed_identity_indicators = [
            "IDENTITY_ENDPOINT",
            "IDENTITY_HEADER",
            "MSI_ENDPOINT",
            "MSI_SECRET",
            "AZURE_CLIENT_ID"
        ]
        
        return any(os.getenv(var) for var in managed_identity_indicators)
    
    def get_secret_client(self) -> SecretClient:
        """
        Get Azure Key Vault Secret Client with retry logic
        """
        if self.secret_client is None:
            for attempt in range(self.retry_attempts):
                try:
                    self.secret_client = SecretClient(
                        vault_url=self.vault_url,
                        credential=self.credential
                    )
                    # Test connection
                    list(self.secret_client.list_properties_of_secrets())
                    logger.info("Secret client initialized successfully")
                    break
                except Exception as e:
                    logger.warning(f"Secret client initialization attempt {attempt + 1} failed: {str(e)}")
                    if attempt == self.retry_attempts - 1:
                        raise
                    await asyncio.sleep(2 ** attempt)  # Exponential backoff
        
        return self.secret_client
    
    def get_key_client(self) -> KeyClient:
        """
        Get Azure Key Vault Key Client with retry logic
        """
        if self.key_client is None:
            for attempt in range(self.retry_attempts):
                try:
                    self.key_client = KeyClient(
                        vault_url=self.vault_url,
                        credential=self.credential
                    )
                    # Test connection
                    list(self.key_client.list_properties_of_keys())
                    logger.info("Key client initialized successfully")
                    break
                except Exception as e:
                    logger.warning(f"Key client initialization attempt {attempt + 1} failed: {str(e)}")
                    if attempt == self.retry_attempts - 1:
                        raise
                    await asyncio.sleep(2 ** attempt)  # Exponential backoff
        
        return self.key_client
    
    def get_certificate_client(self) -> CertificateClient:
        """
        Get Azure Key Vault Certificate Client with retry logic
        """
        if self.certificate_client is None:
            for attempt in range(self.retry_attempts):
                try:
                    self.certificate_client = CertificateClient(
                        vault_url=self.vault_url,
                        credential=self.credential
                    )
                    # Test connection
                    list(self.certificate_client.list_properties_of_certificates())
                    logger.info("Certificate client initialized successfully")
                    break
                except Exception as e:
                    logger.warning(f"Certificate client initialization attempt {attempt + 1} failed: {str(e)}")
                    if attempt == self.retry_attempts - 1:
                        raise
                    await asyncio.sleep(2 ** attempt)  # Exponential backoff
        
        return self.certificate_client
    
    def get_secret(self, secret_name: str, version: str = None) -> Optional[str]:
        """
        Get secret from Azure Key Vault with caching
        """
        cache_key = f"{secret_name}:{version or 'latest'}"
        
        # Check cache first
        if self.enable_caching and cache_key in self._credential_cache:
            cached_data = self._credential_cache[cache_key]
            if cached_data['expires_at'] > datetime.utcnow():
                logger.debug(f"Retrieved secret '{secret_name}' from cache")
                return cached_data['value']
        
        try:
            client = self.get_secret_client()
            
            if version:
                secret = client.get_secret(secret_name, version=version)
            else:
                secret = client.get_secret(secret_name)
            
            # Cache the secret
            if self.enable_caching:
                self._credential_cache[cache_key] = {
                    'value': secret.value,
                    'expires_at': datetime.utcnow() + timedelta(hours=1)
                }
            
            logger.info(f"Retrieved secret '{secret_name}' successfully")
            return secret.value
            
        except ResourceNotFoundError:
            logger.warning(f"Secret '{secret_name}' not found")
            return None
        except Exception as e:
            logger.error(f"Failed to retrieve secret '{secret_name}': {str(e)}")
            raise
    
    def set_secret(self, secret_name: str, secret_value: str, **kwargs) -> bool:
        """
        Set secret in Azure Key Vault
        """
        try:
            client = self.get_secret_client()
            client.set_secret(secret_name, secret_value, **kwargs)
            
            # Clear cache for this secret
            if self.enable_caching:
                cache_keys_to_remove = [key for key in self._credential_cache.keys() 
                                      if key.startswith(f"{secret_name}:")]
                for key in cache_keys_to_remove:
                    del self._credential_cache[key]
            
            logger.info(f"Set secret '{secret_name}' successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to set secret '{secret_name}': {str(e)}")
            return False
    
    def get_certificate(self, certificate_name: str, version: str = None) -> Optional[Any]:
        """
        Get certificate from Azure Key Vault
        """
        try:
            client = self.get_certificate_client()
            
            if version:
                certificate = client.get_certificate_version(certificate_name, version)
            else:
                certificate = client.get_certificate(certificate_name)
            
            logger.info(f"Retrieved certificate '{certificate_name}' successfully")
            return certificate
            
        except ResourceNotFoundError:
            logger.warning(f"Certificate '{certificate_name}' not found")
            return None
        except Exception as e:
            logger.error(f"Failed to retrieve certificate '{certificate_name}': {str(e)}")
            raise
    
    def get_microsoft_365_credentials(self) -> Dict[str, str]:
        """
        Get Microsoft 365 credentials from Azure Key Vault
        """
        credentials = {}
        
        # Required Microsoft 365 credentials
        credential_mapping = {
            'tenant_id': 'M365-TENANT-ID',
            'client_id': 'M365-CLIENT-ID',
            'client_secret': 'M365-CLIENT-SECRET',
            'certificate_thumbprint': 'M365-CERT-THUMBPRINT',
            'certificate_path': 'M365-CERT-PATH',
            'certificate_password': 'M365-CERT-PASSWORD'
        }
        
        for key, secret_name in credential_mapping.items():
            try:
                value = self.get_secret(secret_name)
                if value:
                    credentials[key] = value
                    logger.debug(f"Retrieved Microsoft 365 credential: {key}")
            except Exception as e:
                logger.warning(f"Failed to retrieve Microsoft 365 credential '{key}': {str(e)}")
        
        # Validate required credentials
        required_fields = ['tenant_id', 'client_id']
        missing_fields = [field for field in required_fields if field not in credentials]
        
        if missing_fields:
            raise ValueError(f"Missing required Microsoft 365 credentials: {missing_fields}")
        
        # Validate authentication method
        has_secret = 'client_secret' in credentials
        has_certificate = any(k in credentials for k in ['certificate_thumbprint', 'certificate_path'])
        
        if not has_secret and not has_certificate:
            raise ValueError("No valid authentication method found (client_secret or certificate)")
        
        logger.info("Microsoft 365 credentials retrieved successfully")
        return credentials
    
    def test_connection(self) -> Dict[str, Any]:
        """
        Test Azure Key Vault connection and permissions
        """
        test_results = {
            'vault_url': self.vault_url,
            'credential_type': type(self.credential).__name__,
            'connections': {},
            'permissions': {},
            'overall_status': 'success'
        }
        
        # Test Secret client
        try:
            client = self.get_secret_client()
            secrets = list(client.list_properties_of_secrets())
            test_results['connections']['secrets'] = {
                'status': 'success',
                'count': len(secrets)
            }
        except Exception as e:
            test_results['connections']['secrets'] = {
                'status': 'error',
                'error': str(e)
            }
            test_results['overall_status'] = 'partial'
        
        # Test Key client
        try:
            client = self.get_key_client()
            keys = list(client.list_properties_of_keys())
            test_results['connections']['keys'] = {
                'status': 'success',
                'count': len(keys)
            }
        except Exception as e:
            test_results['connections']['keys'] = {
                'status': 'error',
                'error': str(e)
            }
            test_results['overall_status'] = 'partial'
        
        # Test Certificate client
        try:
            client = self.get_certificate_client()
            certificates = list(client.list_properties_of_certificates())
            test_results['connections']['certificates'] = {
                'status': 'success',
                'count': len(certificates)
            }
        except Exception as e:
            test_results['connections']['certificates'] = {
                'status': 'error',
                'error': str(e)
            }
            test_results['overall_status'] = 'partial'
        
        # Test Microsoft 365 credentials
        try:
            credentials = self.get_microsoft_365_credentials()
            test_results['permissions']['microsoft_365'] = {
                'status': 'success',
                'available_credentials': list(credentials.keys())
            }
        except Exception as e:
            test_results['permissions']['microsoft_365'] = {
                'status': 'error',
                'error': str(e)
            }
            test_results['overall_status'] = 'partial'
        
        return test_results
    
    def close(self):
        """
        Close Azure Key Vault clients and clear cache
        """
        try:
            if self.secret_client:
                self.secret_client.close()
            if self.key_client:
                self.key_client.close()
            if self.certificate_client:
                self.certificate_client.close()
            
            # Clear cache
            self._credential_cache.clear()
            self._token_cache.clear()
            
            logger.info("Azure Key Vault clients closed successfully")
            
        except Exception as e:
            logger.error(f"Error closing Azure Key Vault clients: {str(e)}")
    
    def __enter__(self):
        """Context manager entry"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()


class AsyncAzureKeyVaultAuth:
    """
    Async Azure Key Vault Authentication Manager - Enterprise Production
    非同期処理対応・高性能・スケーラブル運用
    """
    
    def __init__(self, 
                 vault_url: str = None,
                 credential: TokenCredential = None,
                 **kwargs):
        """
        Initialize Async Azure Key Vault Authentication Manager
        """
        self.vault_url = vault_url or os.getenv("AZURE_KEYVAULT_URL")
        self.credential = credential or AsyncDefaultAzureCredential()
        self.kwargs = kwargs
        
        # Initialize async clients
        self.secret_client = None
        self.key_client = None
        self.certificate_client = None
        
        logger.info(f"AsyncAzureKeyVaultAuth initialized with vault: {self.vault_url}")
    
    async def get_secret_client(self):
        """Get async Secret Client"""
        if self.secret_client is None:
            from azure.keyvault.secrets.aio import SecretClient
            self.secret_client = SecretClient(
                vault_url=self.vault_url,
                credential=self.credential
            )
        return self.secret_client
    
    async def get_key_client(self):
        """Get async Key Client"""
        if self.key_client is None:
            from azure.keyvault.keys.aio import KeyClient
            self.key_client = KeyClient(
                vault_url=self.vault_url,
                credential=self.credential
            )
        return self.key_client
    
    async def get_certificate_client(self):
        """Get async Certificate Client"""
        if self.certificate_client is None:
            from azure.keyvault.certificates.aio import CertificateClient
            self.certificate_client = CertificateClient(
                vault_url=self.vault_url,
                credential=self.credential
            )
        return self.certificate_client
    
    async def get_secret(self, secret_name: str, version: str = None) -> Optional[str]:
        """Get secret asynchronously"""
        try:
            client = await self.get_secret_client()
            
            if version:
                secret = await client.get_secret(secret_name, version=version)
            else:
                secret = await client.get_secret(secret_name)
            
            logger.info(f"Retrieved secret '{secret_name}' successfully (async)")
            return secret.value
            
        except ResourceNotFoundError:
            logger.warning(f"Secret '{secret_name}' not found (async)")
            return None
        except Exception as e:
            logger.error(f"Failed to retrieve secret '{secret_name}' (async): {str(e)}")
            raise
    
    async def close(self):
        """Close async clients"""
        try:
            if self.secret_client:
                await self.secret_client.close()
            if self.key_client:
                await self.key_client.close()
            if self.certificate_client:
                await self.certificate_client.close()
            if self.credential:
                await self.credential.close()
            
            logger.info("Async Azure Key Vault clients closed successfully")
            
        except Exception as e:
            logger.error(f"Error closing async Azure Key Vault clients: {str(e)}")
    
    async def __aenter__(self):
        """Async context manager entry"""
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        await self.close()


# Factory function for creating Azure Key Vault authentication
def create_azure_key_vault_auth(vault_url: str = None, 
                               async_mode: bool = False,
                               **kwargs) -> Union[AzureKeyVaultAuth, AsyncAzureKeyVaultAuth]:
    """
    Factory function to create Azure Key Vault authentication instance
    
    Args:
        vault_url: Azure Key Vault URL
        async_mode: Whether to create async instance
        **kwargs: Additional arguments
    
    Returns:
        AzureKeyVaultAuth or AsyncAzureKeyVaultAuth instance
    """
    if async_mode:
        return AsyncAzureKeyVaultAuth(vault_url=vault_url, **kwargs)
    else:
        return AzureKeyVaultAuth(vault_url=vault_url, **kwargs)


if __name__ == "__main__":
    # Test Azure Key Vault authentication
    import asyncio
    
    async def test_azure_key_vault():
        """Test Azure Key Vault authentication"""
        print("Testing Azure Key Vault Authentication...")
        
        # Test sync client
        with create_azure_key_vault_auth() as auth:
            test_results = auth.test_connection()
            print(f"Sync test results: {test_results}")
        
        # Test async client
        async with create_azure_key_vault_auth(async_mode=True) as async_auth:
            secret = await async_auth.get_secret("test-secret")
            print(f"Async secret test: {secret}")
    
    if os.getenv("AZURE_KEYVAULT_URL"):
        asyncio.run(test_azure_key_vault())
    else:
        print("AZURE_KEYVAULT_URL not set, skipping test")