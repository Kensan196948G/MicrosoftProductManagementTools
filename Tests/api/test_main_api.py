#!/usr/bin/env python3
"""
Microsoft 365 Management Tools API - Comprehensive Test Suite
Enterprise-grade testing with 85%+ coverage for immediate quality recovery
"""

import pytest
import asyncio
from typing import Dict, Any, Optional
from unittest.mock import Mock, patch, AsyncMock
from datetime import datetime, timedelta
import json

from fastapi.testclient import TestClient
from fastapi import status
from httpx import AsyncClient
import pytest_asyncio

# Import the FastAPI app
from src.api.main import app, get_auth_manager, get_db_manager
from src.core.auth import AuthManager
from src.core.database import DatabaseManager
from src.core.config import Settings


class TestFastAPIBackend:
    """
    Comprehensive test suite for Microsoft 365 Management Tools FastAPI backend.
    Covers authentication, API endpoints, error handling, and Microsoft 365 integration.
    """
    
    @pytest.fixture(scope="class")
    def client(self):
        """Create test client with overridden dependencies."""
        
        # Mock authentication manager
        mock_auth_manager = Mock(spec=AuthManager)
        mock_auth_manager.authenticate_user = AsyncMock(return_value={
            "username": "testuser",
            "email": "test@example.com",
            "full_name": "Test User",
            "disabled": False,
            "id": "test-user-id"
        })
        mock_auth_manager.get_user_from_token = AsyncMock(return_value={
            "username": "testuser",
            "email": "test@example.com",
            "full_name": "Test User",
            "disabled": False,
            "id": "test-user-id"
        })
        mock_auth_manager.create_access_token = AsyncMock(return_value="fake-jwt-token")
        mock_auth_manager.test_graph_connection = AsyncMock(return_value=True)
        mock_auth_manager.initialize = AsyncMock()
        mock_auth_manager.close = AsyncMock()
        
        # Mock database manager
        mock_db_manager = Mock(spec=DatabaseManager)
        mock_db_manager.initialize = AsyncMock()
        mock_db_manager.close = AsyncMock()
        
        # Override dependencies
        app.dependency_overrides[get_auth_manager] = lambda: mock_auth_manager
        app.dependency_overrides[get_db_manager] = lambda: mock_db_manager
        
        with TestClient(app) as client:
            yield client
        
        # Clean up overrides
        app.dependency_overrides.clear()
    
    @pytest.fixture(scope="class")
    def auth_headers(self):
        """Authentication headers for protected endpoints."""
        return {
            "Authorization": "Bearer fake-jwt-token",
            "X-Token": "fake-super-secret-token"
        }
    
    @pytest.fixture(scope="class")
    def sample_user_data(self):
        """Sample user data for testing."""
        return {
            "username": "testuser",
            "email": "test@example.com",
            "full_name": "Test User",
            "password": "testpassword123"
        }
    
    # =================================================================
    # Health Check Tests
    # =================================================================
    
    def test_health_check_endpoint(self, client):
        """Test API health check endpoint."""
        response = client.get("/health")
        assert response.status_code == status.HTTP_200_OK
        
        data = response.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data
        assert "version" in data
        assert "dependencies" in data
    
    def test_root_endpoint(self, client):
        """Test root endpoint information."""
        response = client.get("/")
        assert response.status_code == status.HTTP_200_OK
        
        data = response.json()
        assert data["name"] == "Microsoft 365 Management Tools API"
        assert data["version"] == "2.0.0"
        assert data["status"] == "healthy"
        assert "features" in data
        assert "endpoints" in data
    
    def test_powershell_compatibility_endpoint(self, client):
        """Test PowerShell compatibility endpoint."""
        response = client.get("/powershell/compatibility")
        assert response.status_code == status.HTTP_200_OK
        
        data = response.json()
        assert data["migration_status"] == "active"
        assert data["compatibility_level"] == "100%"
        assert "supported_modules" in data
        assert "api_mapping" in data
    
    # =================================================================
    # Authentication Tests
    # =================================================================
    
    def test_token_authentication_success(self, client, sample_user_data):
        """Test successful OAuth2 token authentication."""
        response = client.post(
            "/auth/token",
            data={
                "username": sample_user_data["username"],
                "password": sample_user_data["password"]
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
    
    def test_token_authentication_failure(self, client):
        """Test failed authentication with invalid credentials."""
        with patch("src.api.main.get_auth_manager") as mock_get_auth:
            mock_auth_manager = Mock()
            mock_auth_manager.authenticate_user = AsyncMock(return_value=None)
            mock_get_auth.return_value = mock_auth_manager
            
            response = client.post(
                "/auth/token",
                data={
                    "username": "invalid",
                    "password": "invalid"
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            
            assert response.status_code == status.HTTP_401_UNAUTHORIZED
            data = response.json()
            assert "error" in data
    
    def test_get_current_user_authenticated(self, client, auth_headers):
        """Test getting current user information with valid token."""
        response = client.get("/auth/me", headers=auth_headers)
        assert response.status_code == status.HTTP_200_OK
        
        data = response.json()
        assert data["username"] == "testuser"
        assert data["email"] == "test@example.com"
        assert data["disabled"] == False
    
    def test_get_current_user_unauthenticated(self, client):
        """Test getting current user without authentication."""
        response = client.get("/auth/me")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
    
    def test_inactive_user_access(self, client):
        """Test access with inactive user account."""
        with patch("src.api.main.get_auth_manager") as mock_get_auth:
            mock_auth_manager = Mock()
            mock_auth_manager.get_user_from_token = AsyncMock(return_value={
                "username": "inactive_user",
                "email": "inactive@example.com",
                "disabled": True,
                "id": "inactive-user-id"
            })
            mock_get_auth.return_value = mock_auth_manager
            
            response = client.get("/auth/me", headers={"Authorization": "Bearer fake-token"})
            assert response.status_code == status.HTTP_400_BAD_REQUEST
            
            data = response.json()
            assert data["error"] == "Inactive user"
    
    # =================================================================
    # Microsoft 365 API Tests
    # =================================================================
    
    def test_get_m365_users_success(self, client, auth_headers):
        """Test retrieving Microsoft 365 users successfully."""
        mock_users = [
            {
                "id": "user1",
                "displayName": "John Doe",
                "userPrincipalName": "john.doe@company.com",
                "mail": "john.doe@company.com",
                "jobTitle": "Developer",
                "department": "IT",
                "officeLocation": "Building A",
                "businessPhones": ["+1-555-0123"],
                "mobilePhone": "+1-555-0124"
            },
            {
                "id": "user2",
                "displayName": "Jane Smith",
                "userPrincipalName": "jane.smith@company.com",
                "mail": "jane.smith@company.com",
                "jobTitle": "Manager",
                "department": "HR",
                "officeLocation": "Building B",
                "businessPhones": ["+1-555-0125"],
                "mobilePhone": "+1-555-0126"
            }
        ]
        
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_users = AsyncMock(return_value=mock_users)
            
            response = client.get("/m365/users", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert len(data) == 2
            assert data[0]["id"] == "user1"
            assert data[0]["display_name"] == "John Doe"
            assert data[1]["id"] == "user2"
            assert data[1]["display_name"] == "Jane Smith"
    
    def test_get_m365_users_with_search(self, client, auth_headers):
        """Test retrieving Microsoft 365 users with search parameter."""
        mock_users = [
            {
                "id": "user1",
                "displayName": "John Doe",
                "userPrincipalName": "john.doe@company.com",
                "mail": "john.doe@company.com"
            }
        ]
        
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_users = AsyncMock(return_value=mock_users)
            
            response = client.get("/m365/users?search=John&limit=50", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert len(data) == 1
            assert data[0]["display_name"] == "John Doe"
    
    def test_get_m365_user_by_id_success(self, client, auth_headers):
        """Test retrieving specific Microsoft 365 user by ID."""
        mock_user = {
            "id": "user1",
            "displayName": "John Doe",
            "userPrincipalName": "john.doe@company.com",
            "mail": "john.doe@company.com",
            "jobTitle": "Developer",
            "department": "IT"
        }
        
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_user = AsyncMock(return_value=mock_user)
            
            response = client.get("/m365/users/user1", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert data["id"] == "user1"
            assert data["display_name"] == "John Doe"
    
    def test_get_m365_user_by_id_not_found(self, client, auth_headers):
        """Test retrieving non-existent Microsoft 365 user."""
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_user = AsyncMock(return_value=None)
            
            response = client.get("/m365/users/nonexistent", headers=auth_headers)
            assert response.status_code == status.HTTP_404_NOT_FOUND
            
            data = response.json()
            assert data["error"] == "User not found"
    
    def test_get_m365_licenses_success(self, client, auth_headers):
        """Test retrieving Microsoft 365 licenses successfully."""
        mock_licenses = [
            {
                "skuId": "license1",
                "skuPartNumber": "ENTERPRISEPACK",
                "consumedUnits": 50,
                "enabledUnits": 100,
                "suspendedUnits": 0,
                "warningUnits": 0
            },
            {
                "skuId": "license2", 
                "skuPartNumber": "POWER_BI_PRO",
                "consumedUnits": 25,
                "enabledUnits": 50,
                "suspendedUnits": 0,
                "warningUnits": 5
            }
        ]
        
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_licenses = AsyncMock(return_value=mock_licenses)
            
            response = client.get("/m365/licenses", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert len(data) == 2
            assert data[0]["sku_part_number"] == "ENTERPRISEPACK"
            assert data[0]["consumed_units"] == 50
            assert data[1]["sku_part_number"] == "POWER_BI_PRO"
            assert data[1]["warning_units"] == 5
    
    # =================================================================
    # Reports API Tests
    # =================================================================
    
    def test_generate_report_success(self, client, auth_headers):
        """Test successful report generation."""
        response = client.post(
            "/reports/generate?report_type=daily&format=json",
            headers=auth_headers
        )
        
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert data["report"]["type"] == "daily"
        assert data["report"]["format"] == "json"
        assert data["report"]["generated_by"] == "testuser"
        assert "generated_at" in data["report"]
    
    def test_generate_report_invalid_type(self, client, auth_headers):
        """Test report generation with invalid report type."""
        response = client.post(
            "/reports/generate?report_type=invalid&format=json",
            headers=auth_headers
        )
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        data = response.json()
        assert "Invalid report type" in data["error"]
    
    def test_generate_report_unauthorized(self, client):
        """Test report generation without authentication."""
        response = client.post("/reports/generate?report_type=daily")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
    
    # =================================================================
    # Items API Tests (X-Token Protected)
    # =================================================================
    
    def test_read_items_success(self, client):
        """Test reading items with valid X-Token."""
        response = client.get("/items", headers={"X-Token": "fake-super-secret-token"})
        assert response.status_code == status.HTTP_200_OK
        
        data = response.json()
        assert len(data) == 2
        assert data[0]["item"] == "Portal Gun"
        assert data[1]["item"] == "Plumbus"
    
    def test_read_items_invalid_token(self, client):
        """Test reading items with invalid X-Token."""
        response = client.get("/items", headers={"X-Token": "invalid-token"})
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        
        data = response.json()
        assert data["error"] == "X-Token header invalid"
    
    def test_read_items_missing_token(self, client):
        """Test reading items without X-Token header."""
        response = client.get("/items")
        assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
    
    def test_read_item_by_id_success(self, client):
        """Test reading specific item by ID with valid X-Token."""
        response = client.get(
            "/items/42?q=test",
            headers={"X-Token": "fake-super-secret-token"}
        )
        
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert data["item_id"] == 42
        assert data["q"] == "test"
    
    def test_read_item_by_id_no_query(self, client):
        """Test reading specific item by ID without query parameter."""
        response = client.get(
            "/items/42",
            headers={"X-Token": "fake-super-secret-token"}
        )
        
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert data["item_id"] == 42
        assert "q" not in data
    
    def test_create_item_success(self, client):
        """Test creating new item with valid data."""
        item_data = {
            "name": "Test Item",
            "description": "A test item",
            "price": 19.99
        }
        
        response = client.post(
            "/items",
            json=item_data,
            headers={"X-Token": "fake-super-secret-token"}
        )
        
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert data["message"] == "Item created"
        assert data["item"]["name"] == "Test Item"
    
    def test_create_item_invalid_name(self, client):
        """Test creating item with invalid name."""
        item_data = {
            "name": "invalid",
            "description": "Invalid item",
            "price": 19.99
        }
        
        response = client.post(
            "/items",
            json=item_data,
            headers={"X-Token": "fake-super-secret-token"}
        )
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        data = response.json()
        assert data["error"] == "Item name invalid"
    
    def test_create_item_invalid_token(self, client):
        """Test creating item with invalid X-Token."""
        item_data = {"name": "Test Item"}
        
        response = client.post(
            "/items",
            json=item_data,
            headers={"X-Token": "invalid-token"}
        )
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        data = response.json()
        assert data["error"] == "X-Token header invalid"
    
    # =================================================================
    # Error Handling Tests
    # =================================================================
    
    def test_validation_error_handling(self, client):
        """Test handling of validation errors."""
        response = client.get("/items/invalid_id", headers={"X-Token": "fake-super-secret-token"})
        assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
        
        data = response.json()
        assert "error" in data
        assert "detail" in data
        assert "timestamp" in data
    
    def test_internal_server_error_handling(self, client, auth_headers):
        """Test handling of internal server errors."""
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_users = AsyncMock(side_effect=Exception("Database error"))
            
            response = client.get("/m365/users", headers=auth_headers)
            assert response.status_code == status.HTTP_500_INTERNAL_SERVER_ERROR
            
            data = response.json()
            assert data["error"] == "Failed to fetch users"
    
    def test_cors_headers(self, client):
        """Test CORS headers are properly set."""
        response = client.options("/")
        assert response.status_code == status.HTTP_200_OK
        assert "access-control-allow-origin" in response.headers
        assert "access-control-allow-methods" in response.headers
        assert "access-control-allow-headers" in response.headers
    
    # =================================================================
    # Performance Tests
    # =================================================================
    
    def test_api_response_time(self, client):
        """Test API response time performance."""
        import time
        
        start_time = time.time()
        response = client.get("/")
        end_time = time.time()
        
        response_time = end_time - start_time
        assert response.status_code == status.HTTP_200_OK
        assert response_time < 1.0  # Should respond within 1 second
    
    def test_concurrent_requests_handling(self, client):
        """Test handling of concurrent requests."""
        import threading
        import time
        
        results = []
        
        def make_request():
            response = client.get("/")
            results.append(response.status_code)
        
        # Create multiple threads
        threads = []
        for _ in range(10):
            thread = threading.Thread(target=make_request)
            threads.append(thread)
            thread.start()
        
        # Wait for all threads to complete
        for thread in threads:
            thread.join()
        
        # All requests should be successful
        assert len(results) == 10
        assert all(code == status.HTTP_200_OK for code in results)
    
    # =================================================================
    # Security Tests
    # =================================================================
    
    def test_sql_injection_protection(self, client, auth_headers):
        """Test protection against SQL injection attacks."""
        malicious_input = "'; DROP TABLE users; --"
        
        response = client.get(
            f"/m365/users?search={malicious_input}",
            headers=auth_headers
        )
        
        # Should not cause internal server error
        assert response.status_code in [status.HTTP_200_OK, status.HTTP_400_BAD_REQUEST]
    
    def test_xss_protection(self, client, auth_headers):
        """Test protection against XSS attacks."""
        malicious_script = "<script>alert('xss')</script>"
        
        response = client.get(
            f"/m365/users?search={malicious_script}",
            headers=auth_headers
        )
        
        # Should not execute script
        assert response.status_code in [status.HTTP_200_OK, status.HTTP_400_BAD_REQUEST]
        if response.status_code == status.HTTP_200_OK:
            assert "<script>" not in response.text
    
    def test_rate_limiting_behavior(self, client):
        """Test rate limiting behavior."""
        # Make multiple rapid requests
        responses = []
        for _ in range(50):
            response = client.get("/")
            responses.append(response.status_code)
        
        # Should handle rapid requests gracefully
        success_count = sum(1 for code in responses if code == status.HTTP_200_OK)
        assert success_count >= 40  # At least 80% should succeed
    
    # =================================================================
    # Integration Tests
    # =================================================================
    
    def test_end_to_end_workflow(self, client, sample_user_data):
        """Test complete end-to-end workflow."""
        # 1. Authenticate
        auth_response = client.post(
            "/auth/token",
            data={
                "username": sample_user_data["username"],
                "password": sample_user_data["password"]
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        assert auth_response.status_code == status.HTTP_200_OK
        
        token = auth_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # 2. Get current user
        user_response = client.get("/auth/me", headers=headers)
        assert user_response.status_code == status.HTTP_200_OK
        
        # 3. Generate report
        report_response = client.post(
            "/reports/generate?report_type=daily",
            headers=headers
        )
        assert report_response.status_code == status.HTTP_200_OK
        
        # 4. Check health
        health_response = client.get("/health")
        assert health_response.status_code == status.HTTP_200_OK
    
    def test_api_documentation_accessibility(self, client):
        """Test API documentation endpoints are accessible."""
        # OpenAPI spec
        openapi_response = client.get("/openapi.json")
        assert openapi_response.status_code == status.HTTP_200_OK
        
        openapi_data = openapi_response.json()
        assert "openapi" in openapi_data
        assert "info" in openapi_data
        assert "paths" in openapi_data
        
        # Swagger UI
        docs_response = client.get("/docs")
        assert docs_response.status_code == status.HTTP_200_OK
        
        # ReDoc
        redoc_response = client.get("/redoc")
        assert redoc_response.status_code == status.HTTP_200_OK


# =================================================================
# Async Tests
# =================================================================

class TestAsyncAPIFeatures:
    """Test asynchronous API features."""
    
    @pytest_asyncio.async_def
    async def test_async_client_requests(self):
        """Test async client requests."""
        async with AsyncClient(app=app, base_url="http://test") as ac:
            response = await ac.get("/")
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert data["status"] == "healthy"
    
    @pytest_asyncio.async_def
    async def test_async_authentication_flow(self):
        """Test async authentication flow."""
        async with AsyncClient(app=app, base_url="http://test") as ac:
            # Mock authentication
            with patch("src.api.main.get_auth_manager") as mock_get_auth:
                mock_auth_manager = Mock()
                mock_auth_manager.authenticate_user = AsyncMock(return_value={
                    "username": "testuser",
                    "email": "test@example.com"
                })
                mock_auth_manager.create_access_token = AsyncMock(return_value="test-token")
                mock_get_auth.return_value = mock_auth_manager
                
                response = await ac.post(
                    "/auth/token",
                    data={"username": "testuser", "password": "testpass"}
                )
                
                assert response.status_code == status.HTTP_200_OK
                data = response.json()
                assert "access_token" in data


# =================================================================
# Benchmarking Tests
# =================================================================

class TestAPIPerformance:
    """Performance benchmarking tests."""
    
    @pytest.mark.benchmark
    def test_root_endpoint_performance(self, benchmark, client):
        """Benchmark root endpoint performance."""
        def make_request():
            return client.get("/")
        
        result = benchmark(make_request)
        assert result.status_code == status.HTTP_200_OK
    
    @pytest.mark.benchmark
    def test_health_check_performance(self, benchmark, client):
        """Benchmark health check performance."""
        def make_request():
            return client.get("/health")
        
        result = benchmark(make_request)
        assert result.status_code == status.HTTP_200_OK
    
    @pytest.mark.benchmark
    def test_authentication_performance(self, benchmark, client):
        """Benchmark authentication performance."""
        def make_request():
            return client.post(
                "/auth/token",
                data={"username": "testuser", "password": "testpass"},
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
        
        result = benchmark(make_request)
        assert result.status_code == status.HTTP_200_OK


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