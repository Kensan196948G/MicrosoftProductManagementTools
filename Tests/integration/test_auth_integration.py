"""
Integration tests for authentication module.
Tests real authentication scenarios with Microsoft 365 services.
"""

import pytest
import asyncio
from pathlib import Path
import os
import sys
from unittest.mock import patch, Mock

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))

from core.auth import (
    GraphAuthenticator, ExchangeAuthenticator, CertificateManager,
    AuthenticationMethod, AuthenticationResult
)
from core.config import Config


class TestGraphAuthIntegration:
    """Integration tests for Graph authentication."""
    
    @pytest.fixture
    def config(self):
        """Load test configuration."""
        config_path = Path(__file__).parent.parent.parent / "Config" / "appsettings.json"
        return Config(config_path)
    
    @pytest.fixture
    def graph_auth(self, config):
        """Create Graph authenticator with test config."""
        return GraphAuthenticator(
            tenant_id=config.get("Authentication.TenantId", "test_tenant"),
            client_id=config.get("Authentication.ClientId", "test_client"),
            cache_tokens=True
        )
    
    @pytest.mark.integration
    @pytest.mark.skipif(not os.getenv("RUN_INTEGRATION_TESTS"), 
                       reason="Integration tests require RUN_INTEGRATION_TESTS=1")
    def test_certificate_auth_real(self, graph_auth, config):
        """Test real certificate authentication to Graph API."""
        cert_path = config.get("Authentication.CertificatePath")
        cert_password = config.get("Authentication.CertificatePassword")
        
        if not cert_path or not Path(cert_path).exists():
            pytest.skip("Certificate file not found")
        
        # Test authentication
        result = graph_auth.authenticate(
            AuthenticationMethod.CERTIFICATE,
            certificate_path=cert_path,
            certificate_password=cert_password
        )
        
        assert result.success is True
        assert result.access_token is not None
        assert result.token_type == "Bearer"
        assert not result.is_expired
        
        # Test token validation
        assert graph_auth.validate_token(result.access_token) is True
        
        # Test getting token info
        token_info = graph_auth.get_token_info(result.access_token)
        assert token_info is not None
        assert "app_id" in token_info
        assert "expires_at" in token_info
    
    @pytest.mark.integration
    @pytest.mark.skipif(not os.getenv("RUN_INTEGRATION_TESTS"), 
                       reason="Integration tests require RUN_INTEGRATION_TESTS=1")
    def test_client_secret_auth_real(self, graph_auth, config):
        """Test real client secret authentication to Graph API."""
        client_secret = config.get("Authentication.ClientSecret")
        
        if not client_secret:
            pytest.skip("Client secret not configured")
        
        # Test authentication
        result = graph_auth.authenticate(
            AuthenticationMethod.CLIENT_SECRET,
            client_secret=client_secret
        )
        
        assert result.success is True
        assert result.access_token is not None
        assert result.token_type == "Bearer"
        assert not result.is_expired
    
    @pytest.mark.integration
    @pytest.mark.slow
    def test_device_code_auth_mock(self, graph_auth):
        """Test device code authentication (mocked)."""
        # Mock MSAL to avoid real device code flow
        with patch('core.auth.graph_auth.PublicClientApplication') as mock_app_class:
            mock_app = Mock()
            mock_app_class.return_value = mock_app
            
            # Mock device code flow
            mock_app.initiate_device_flow.return_value = {
                'user_code': 'TEST123',
                'device_code': 'device_code_123',
                'verification_uri': 'https://microsoft.com/devicelogin',
                'message': 'Go to https://microsoft.com/devicelogin and enter code TEST123'
            }
            
            mock_app.acquire_token_by_device_flow.return_value = {
                'access_token': 'test_token',
                'expires_in': 3600,
                'token_type': 'Bearer'
            }
            
            # Test authentication
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                result = loop.run_until_complete(
                    graph_auth._auth_device_code()
                )
                
                assert result.success is True
                assert result.access_token == 'test_token'
            finally:
                loop.close()
    
    def test_token_caching(self, graph_auth, config):
        """Test token caching functionality."""
        # Mock authentication to avoid real API calls
        with patch.object(graph_auth, '_auth_certificate') as mock_auth:
            mock_auth.return_value = AuthenticationResult(
                success=True,
                access_token="cached_token",
                expires_at=graph_auth.token_cache.get_token("test_key").expires_at if graph_auth.token_cache else None
            )
            
            # First authentication
            result1 = graph_auth.authenticate(
                AuthenticationMethod.CERTIFICATE,
                certificate_path="test.pfx"
            )
            
            # Second authentication should use cache
            result2 = graph_auth.authenticate(
                AuthenticationMethod.CERTIFICATE,
                certificate_path="test.pfx"
            )
            
            assert result1.access_token == result2.access_token
            # Should only call auth once due to caching
            assert mock_auth.call_count == 1


class TestExchangeAuthIntegration:
    """Integration tests for Exchange authentication."""
    
    @pytest.fixture
    def config(self):
        """Load test configuration."""
        config_path = Path(__file__).parent.parent.parent / "Config" / "appsettings.json"
        return Config(config_path)
    
    @pytest.fixture
    def exchange_auth(self, config):
        """Create Exchange authenticator with test config."""
        return ExchangeAuthenticator(
            tenant_id=config.get("Authentication.TenantId", "test_tenant"),
            client_id=config.get("Authentication.ClientId", "test_client"),
            organization=config.get("ExchangeOnline.Organization", "test.onmicrosoft.com"),
            cache_tokens=True
        )
    
    @pytest.mark.integration
    @pytest.mark.skipif(not os.getenv("RUN_INTEGRATION_TESTS"), 
                       reason="Integration tests require RUN_INTEGRATION_TESTS=1")
    def test_exchange_certificate_auth_real(self, exchange_auth, config):
        """Test real certificate authentication to Exchange Online."""
        cert_path = config.get("Authentication.CertificatePath")
        cert_password = config.get("Authentication.CertificatePassword")
        
        if not cert_path or not Path(cert_path).exists():
            pytest.skip("Certificate file not found")
        
        # Test authentication
        result = exchange_auth.authenticate(
            AuthenticationMethod.CERTIFICATE,
            certificate_path=cert_path,
            certificate_password=cert_password
        )
        
        assert result.success is True
        assert result.access_token is not None
        
        # Test PowerShell connection
        assert exchange_auth._connected is True
        
        # Test basic Exchange command
        try:
            mailboxes = exchange_auth.get_mailboxes(limit=5)
            assert isinstance(mailboxes, list)
        except Exception as e:
            # May fail if no mailboxes or permissions issue
            pytest.skip(f"Exchange command failed: {e}")
        
        # Clean up
        exchange_auth.disconnect()
        assert exchange_auth._connected is False
    
    @pytest.mark.integration
    def test_exchange_module_installation(self, exchange_auth):
        """Test Exchange module installation check."""
        # Mock PowerShell bridge
        with patch('core.auth.exchange_auth.PowerShellBridge') as mock_bridge_class:
            mock_bridge = Mock()
            mock_bridge_class.return_value = mock_bridge
            
            # Mock module not found initially
            mock_bridge.execute_command.side_effect = [
                Mock(success=False, data=None),  # Module not found
                Mock(success=True, data=None),   # Install success
                Mock(success=True, data=['ExchangeOnlineManagement'])  # Module check after install
            ]
            
            # Test module installation
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                result = loop.run_until_complete(
                    exchange_auth._install_exo_module()
                )
                
                assert result is True
            finally:
                loop.close()
    
    def test_exchange_command_execution(self, exchange_auth):
        """Test Exchange command execution."""
        # Mock PowerShell bridge
        mock_bridge = Mock()
        mock_bridge.execute_command.return_value = Mock(
            success=True,
            data=[
                {"DisplayName": "Test User", "UserPrincipalName": "test@test.com"}
            ]
        )
        exchange_auth._ps_bridge = mock_bridge
        exchange_auth._connected = True
        
        # Test command execution
        result = exchange_auth.execute_exchange_command(
            "Get-Mailbox -ResultSize 1"
        )
        
        assert result.success is True
        assert result.data is not None
        
        # Test mailbox retrieval
        mailboxes = exchange_auth.get_mailboxes(limit=1)
        assert len(mailboxes) == 1
        assert mailboxes[0]["DisplayName"] == "Test User"


class TestCertificateManagerIntegration:
    """Integration tests for certificate manager."""
    
    @pytest.fixture
    def cert_manager(self):
        """Create certificate manager instance."""
        return CertificateManager()
    
    @pytest.fixture
    def test_cert_path(self):
        """Get test certificate path from config."""
        config_path = Path(__file__).parent.parent.parent / "Config" / "appsettings.json"
        config = Config(config_path)
        return config.get("Authentication.CertificatePath")
    
    @pytest.mark.integration
    @pytest.mark.skipif(not os.getenv("RUN_INTEGRATION_TESTS"), 
                       reason="Integration tests require RUN_INTEGRATION_TESTS=1")
    def test_real_certificate_loading(self, cert_manager, test_cert_path):
        """Test loading real certificate file."""
        if not test_cert_path or not Path(test_cert_path).exists():
            pytest.skip("Test certificate file not found")
        
        # Test certificate loading
        cert_data = cert_manager.load_certificate_from_file(
            Path(test_cert_path)
        )
        
        assert "thumbprint" in cert_data
        assert "subject" in cert_data
        assert "issuer" in cert_data
        assert "not_valid_before" in cert_data
        assert "not_valid_after" in cert_data
        
        # Test certificate validation
        is_valid = cert_manager.validate_certificate(Path(test_cert_path))
        assert isinstance(is_valid, bool)
        
        # Test certificate info retrieval
        cert_info = cert_manager.get_certificate_info(Path(test_cert_path))
        assert "thumbprint" in cert_info
        assert "is_valid" in cert_info
        assert "expires_in_days" in cert_info
    
    @pytest.mark.skipif(not os.name == 'nt', reason="Windows certificate store test")
    def test_windows_certificate_store(self, cert_manager):
        """Test Windows certificate store access."""
        # This test only runs on Windows
        if not cert_manager.is_windows:
            pytest.skip("Windows-only test")
        
        # Test with invalid thumbprint
        with pytest.raises(ValueError):
            cert_manager.load_certificate_from_store("invalid_thumbprint")


class TestAuthenticationFlow:
    """Integration tests for complete authentication flows."""
    
    @pytest.fixture
    def config(self):
        """Load test configuration."""
        config_path = Path(__file__).parent.parent.parent / "Config" / "appsettings.json"
        return Config(config_path)
    
    @pytest.mark.integration
    @pytest.mark.skipif(not os.getenv("RUN_INTEGRATION_TESTS"), 
                       reason="Integration tests require RUN_INTEGRATION_TESTS=1")
    def test_complete_auth_flow(self, config):
        """Test complete authentication flow from config."""
        # Create authenticators
        graph_auth = GraphAuthenticator(
            tenant_id=config.get("Authentication.TenantId", "test_tenant"),
            client_id=config.get("Authentication.ClientId", "test_client")
        )
        
        exchange_auth = ExchangeAuthenticator(
            tenant_id=config.get("Authentication.TenantId", "test_tenant"),
            client_id=config.get("Authentication.ClientId", "test_client"),
            organization=config.get("ExchangeOnline.Organization", "test.onmicrosoft.com")
        )
        
        # Test Graph authentication
        cert_path = config.get("Authentication.CertificatePath")
        if cert_path and Path(cert_path).exists():
            graph_result = graph_auth.authenticate(
                AuthenticationMethod.CERTIFICATE,
                certificate_path=cert_path,
                certificate_password=config.get("Authentication.CertificatePassword")
            )
            assert graph_result.success is True
            
            # Test Exchange authentication with same credentials
            exchange_result = exchange_auth.authenticate(
                AuthenticationMethod.CERTIFICATE,
                certificate_path=cert_path,
                certificate_password=config.get("Authentication.CertificatePassword")
            )
            assert exchange_result.success is True
            
            # Clean up
            exchange_auth.disconnect()
        else:
            pytest.skip("Certificate file not found for complete flow test")
    
    @pytest.mark.integration
    def test_error_handling_flow(self, config):
        """Test error handling in authentication flow."""
        # Test with invalid certificate
        graph_auth = GraphAuthenticator(
            tenant_id="invalid_tenant",
            client_id="invalid_client"
        )
        
        result = graph_auth.authenticate(
            AuthenticationMethod.CERTIFICATE,
            certificate_path="nonexistent.pfx"
        )
        
        assert result.success is False
        assert result.error is not None
        assert result.error_description is not None


if __name__ == "__main__":
    # Run integration tests with specific markers
    pytest.main([
        __file__, 
        "-v", 
        "-m", "integration",
        "--tb=short"
    ])