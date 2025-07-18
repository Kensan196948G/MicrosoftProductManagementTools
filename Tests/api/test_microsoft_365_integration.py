#!/usr/bin/env python3
"""
Microsoft 365 Integration Tests
Comprehensive testing of Microsoft Graph API and Exchange Online integration
"""

import pytest
import asyncio
from unittest.mock import Mock, AsyncMock, patch
from typing import Dict, Any, List, Optional
import json
from datetime import datetime, timedelta

from fastapi.testclient import TestClient
from fastapi import status
from httpx import AsyncClient
import pytest_asyncio

from src.api.main import app
from src.api.graph.client import GraphClient
from src.api.exchange.client import ExchangeClient


class TestMicrosoft365Integration:
    """
    Test suite for Microsoft 365 API integration.
    Covers Graph API, Exchange Online, Teams, and OneDrive functionality.
    """
    
    @pytest.fixture(scope="class")
    def client(self):
        """Create test client with mocked Microsoft 365 services."""
        with TestClient(app) as client:
            yield client
    
    @pytest.fixture(scope="class")
    def auth_headers(self):
        """Authentication headers for Microsoft 365 API tests."""
        return {
            "Authorization": "Bearer test-token",
            "X-Token": "fake-super-secret-token"
        }
    
    @pytest.fixture(scope="class")
    def mock_graph_data(self):
        """Mock Microsoft Graph API data."""
        return {
            "users": [
                {
                    "id": "user1",
                    "displayName": "Alice Johnson",
                    "userPrincipalName": "alice.johnson@company.com",
                    "mail": "alice.johnson@company.com",
                    "jobTitle": "Senior Developer",
                    "department": "Engineering",
                    "officeLocation": "Building A, Floor 3",
                    "businessPhones": ["+1-555-0101"],
                    "mobilePhone": "+1-555-0102",
                    "accountEnabled": True,
                    "createdDateTime": "2023-01-15T10:30:00Z",
                    "lastSignInDateTime": "2024-01-18T08:15:00Z"
                },
                {
                    "id": "user2",
                    "displayName": "Bob Smith",
                    "userPrincipalName": "bob.smith@company.com",
                    "mail": "bob.smith@company.com",
                    "jobTitle": "Project Manager",
                    "department": "Operations",
                    "officeLocation": "Building B, Floor 2",
                    "businessPhones": ["+1-555-0103"],
                    "mobilePhone": "+1-555-0104",
                    "accountEnabled": True,
                    "createdDateTime": "2023-02-20T14:45:00Z",
                    "lastSignInDateTime": "2024-01-17T16:30:00Z"
                }
            ],
            "licenses": [
                {
                    "skuId": "6fd2c87f-b296-42f0-b197-1e91e994b900",
                    "skuPartNumber": "ENTERPRISEPACK",
                    "consumedUnits": 75,
                    "enabledUnits": 100,
                    "suspendedUnits": 0,
                    "warningUnits": 20,
                    "appliesTo": "User",
                    "capabilityStatus": "Enabled"
                },
                {
                    "skuId": "f8a1db68-be16-40ed-86d5-cb42ce701560",
                    "skuPartNumber": "POWER_BI_PRO",
                    "consumedUnits": 45,
                    "enabledUnits": 100,
                    "suspendedUnits": 0,
                    "warningUnits": 55,
                    "appliesTo": "User",
                    "capabilityStatus": "Enabled"
                }
            ],
            "groups": [
                {
                    "id": "group1",
                    "displayName": "Engineering Team",
                    "description": "All engineering department members",
                    "groupTypes": ["Unified"],
                    "mailEnabled": True,
                    "securityEnabled": True,
                    "mail": "engineering@company.com",
                    "createdDateTime": "2023-01-10T09:00:00Z"
                }
            ],
            "applications": [
                {
                    "id": "app1",
                    "displayName": "Microsoft Teams",
                    "appId": "1fec8e78-bce4-4aaf-ab1b-5451cc387264",
                    "publisherDomain": "microsoft.com",
                    "createdDateTime": "2023-01-01T00:00:00Z"
                }
            ]
        }
    
    # =================================================================
    # Graph API User Management Tests
    # =================================================================
    
    def test_graph_api_get_all_users(self, client, auth_headers, mock_graph_data):
        """Test retrieving all users from Microsoft Graph API."""
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_users = AsyncMock(return_value=mock_graph_data["users"])
            
            response = client.get("/m365/users", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert len(data) == 2
            assert data[0]["display_name"] == "Alice Johnson"
            assert data[0]["job_title"] == "Senior Developer"
            assert data[1]["display_name"] == "Bob Smith"
            assert data[1]["job_title"] == "Project Manager"
    
    def test_graph_api_get_user_by_id(self, client, auth_headers, mock_graph_data):
        """Test retrieving specific user by ID from Microsoft Graph API."""
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_user = AsyncMock(return_value=mock_graph_data["users"][0])
            
            response = client.get("/m365/users/user1", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert data["id"] == "user1"
            assert data["display_name"] == "Alice Johnson"
            assert data["user_principal_name"] == "alice.johnson@company.com"
            assert data["job_title"] == "Senior Developer"
            assert data["department"] == "Engineering"
    
    def test_graph_api_search_users(self, client, auth_headers, mock_graph_data):
        """Test searching users with filter parameters."""
        # Filter to return only engineering users
        filtered_users = [user for user in mock_graph_data["users"] if user["department"] == "Engineering"]
        
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_users = AsyncMock(return_value=filtered_users)
            
            response = client.get("/m365/users?search=Engineering&limit=50", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert len(data) == 1
            assert data[0]["department"] == "Engineering"
            assert data[0]["display_name"] == "Alice Johnson"
    
    def test_graph_api_user_not_found(self, client, auth_headers):
        """Test handling of non-existent user ID."""
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_user = AsyncMock(return_value=None)
            
            response = client.get("/m365/users/nonexistent-id", headers=auth_headers)
            assert response.status_code == status.HTTP_404_NOT_FOUND
            
            data = response.json()
            assert data["error"] == "User not found"
    
    # =================================================================
    # Graph API License Management Tests
    # =================================================================
    
    def test_graph_api_get_licenses(self, client, auth_headers, mock_graph_data):
        """Test retrieving Microsoft 365 licenses."""
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_licenses = AsyncMock(return_value=mock_graph_data["licenses"])
            
            response = client.get("/m365/licenses", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert len(data) == 2
            assert data[0]["sku_part_number"] == "ENTERPRISEPACK"
            assert data[0]["consumed_units"] == 75
            assert data[0]["enabled_units"] == 100
            assert data[1]["sku_part_number"] == "POWER_BI_PRO"
            assert data[1]["consumed_units"] == 45
    
    def test_graph_api_license_usage_analysis(self, client, auth_headers, mock_graph_data):
        """Test license usage analysis."""
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_licenses = AsyncMock(return_value=mock_graph_data["licenses"])
            
            response = client.get("/m365/licenses", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            
            # Verify license utilization calculations
            enterprise_pack = next(license for license in data if license["sku_part_number"] == "ENTERPRISEPACK")
            utilization_rate = enterprise_pack["consumed_units"] / enterprise_pack["enabled_units"]
            assert utilization_rate == 0.75  # 75% utilization
            
            power_bi = next(license for license in data if license["sku_part_number"] == "POWER_BI_PRO")
            utilization_rate = power_bi["consumed_units"] / power_bi["enabled_units"]
            assert utilization_rate == 0.45  # 45% utilization
    
    # =================================================================
    # Exchange Online Integration Tests
    # =================================================================
    
    def test_exchange_online_mailbox_stats(self, client, auth_headers):
        """Test Exchange Online mailbox statistics."""
        mock_mailbox_data = [
            {
                "UserPrincipalName": "alice.johnson@company.com",
                "DisplayName": "Alice Johnson",
                "TotalItemSize": "2.5 GB",
                "ItemCount": 15420,
                "LastLogonTime": "2024-01-18T08:15:00Z",
                "ProhibitSendQuota": "50 GB",
                "ProhibitSendReceiveQuota": "55 GB"
            },
            {
                "UserPrincipalName": "bob.smith@company.com",
                "DisplayName": "Bob Smith",
                "TotalItemSize": "1.8 GB",
                "ItemCount": 12350,
                "LastLogonTime": "2024-01-17T16:30:00Z",
                "ProhibitSendQuota": "50 GB",
                "ProhibitSendReceiveQuota": "55 GB"
            }
        ]
        
        with patch.object(app.state, 'exchange_client') as mock_exchange_client:
            mock_exchange_client.get_mailbox_statistics = AsyncMock(return_value=mock_mailbox_data)
            
            response = client.get("/exchange/mailboxes/stats", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert len(data) == 2
            assert data[0]["UserPrincipalName"] == "alice.johnson@company.com"
            assert data[0]["TotalItemSize"] == "2.5 GB"
            assert data[1]["UserPrincipalName"] == "bob.smith@company.com"
            assert data[1]["TotalItemSize"] == "1.8 GB"
    
    def test_exchange_online_message_trace(self, client, auth_headers):
        """Test Exchange Online message trace functionality."""
        mock_message_trace = [
            {
                "MessageId": "message1",
                "RecipientAddress": "alice.johnson@company.com",
                "SenderAddress": "external@partner.com",
                "Subject": "Project Update",
                "Status": "Delivered",
                "ToIP": "192.168.1.100",
                "FromIP": "203.0.113.1",
                "Size": 52480,
                "MessageTraceId": "trace1",
                "Received": "2024-01-18T10:30:00Z"
            }
        ]
        
        with patch.object(app.state, 'exchange_client') as mock_exchange_client:
            mock_exchange_client.get_message_trace = AsyncMock(return_value=mock_message_trace)
            
            response = client.get("/exchange/messages/trace", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert len(data) == 1
            assert data[0]["MessageId"] == "message1"
            assert data[0]["Status"] == "Delivered"
            assert data[0]["RecipientAddress"] == "alice.johnson@company.com"
    
    # =================================================================
    # Teams Integration Tests
    # =================================================================
    
    def test_teams_usage_analytics(self, client, auth_headers):
        """Test Microsoft Teams usage analytics."""
        mock_teams_data = [
            {
                "UserPrincipalName": "alice.johnson@company.com",
                "DisplayName": "Alice Johnson",
                "TeamChatMessageCount": 245,
                "PrivateChatMessageCount": 89,
                "CallCount": 12,
                "MeetingCount": 18,
                "LastActivityDate": "2024-01-18",
                "IsDeleted": False,
                "IsLicensed": True
            },
            {
                "UserPrincipalName": "bob.smith@company.com",
                "DisplayName": "Bob Smith",
                "TeamChatMessageCount": 156,
                "PrivateChatMessageCount": 67,
                "CallCount": 8,
                "MeetingCount": 22,
                "LastActivityDate": "2024-01-17",
                "IsDeleted": False,
                "IsLicensed": True
            }
        ]
        
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_teams_usage_analytics = AsyncMock(return_value=mock_teams_data)
            
            response = client.get("/teams/usage/analytics", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert len(data) == 2
            assert data[0]["UserPrincipalName"] == "alice.johnson@company.com"
            assert data[0]["TeamChatMessageCount"] == 245
            assert data[1]["MeetingCount"] == 22
    
    def test_teams_device_usage(self, client, auth_headers):
        """Test Microsoft Teams device usage statistics."""
        mock_device_data = [
            {
                "UserPrincipalName": "alice.johnson@company.com",
                "DisplayName": "Alice Johnson",
                "UsedWindows": True,
                "UsedMac": False,
                "UsedIOS": True,
                "UsedAndroid": False,
                "UsedWeb": True,
                "LastActivityDate": "2024-01-18",
                "IsLicensed": True
            }
        ]
        
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_teams_device_usage = AsyncMock(return_value=mock_device_data)
            
            response = client.get("/teams/usage/devices", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert len(data) == 1
            assert data[0]["UsedWindows"] == True
            assert data[0]["UsedIOS"] == True
            assert data[0]["UsedMac"] == False
    
    # =================================================================
    # OneDrive Integration Tests
    # =================================================================
    
    def test_onedrive_usage_analytics(self, client, auth_headers):
        """Test OneDrive usage analytics."""
        mock_onedrive_data = [
            {
                "UserPrincipalName": "alice.johnson@company.com",
                "DisplayName": "Alice Johnson",
                "StorageUsedInBytes": 5368709120,  # 5GB
                "StorageAllocatedInBytes": 1099511627776,  # 1TB
                "FileCount": 1250,
                "ActiveFileCount": 89,
                "LastActivityDate": "2024-01-18",
                "IsDeleted": False,
                "IsLicensed": True
            },
            {
                "UserPrincipalName": "bob.smith@company.com",
                "DisplayName": "Bob Smith",
                "StorageUsedInBytes": 3221225472,  # 3GB
                "StorageAllocatedInBytes": 1099511627776,  # 1TB
                "FileCount": 890,
                "ActiveFileCount": 67,
                "LastActivityDate": "2024-01-17",
                "IsDeleted": False,
                "IsLicensed": True
            }
        ]
        
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_onedrive_usage_analytics = AsyncMock(return_value=mock_onedrive_data)
            
            response = client.get("/onedrive/usage/analytics", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert len(data) == 2
            assert data[0]["UserPrincipalName"] == "alice.johnson@company.com"
            assert data[0]["StorageUsedInBytes"] == 5368709120
            assert data[1]["FileCount"] == 890
    
    def test_onedrive_sharing_analysis(self, client, auth_headers):
        """Test OneDrive sharing and collaboration analysis."""
        mock_sharing_data = [
            {
                "UserPrincipalName": "alice.johnson@company.com",
                "DisplayName": "Alice Johnson",
                "InternalSharingCount": 25,
                "ExternalSharingCount": 3,
                "AnonymousSharingCount": 0,
                "SharedWithCount": 12,
                "LastActivityDate": "2024-01-18"
            }
        ]
        
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_onedrive_sharing_analytics = AsyncMock(return_value=mock_sharing_data)
            
            response = client.get("/onedrive/sharing/analysis", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert len(data) == 1
            assert data[0]["InternalSharingCount"] == 25
            assert data[0]["ExternalSharingCount"] == 3
            assert data[0]["AnonymousSharingCount"] == 0
    
    # =================================================================
    # Report Generation Tests
    # =================================================================
    
    def test_generate_comprehensive_daily_report(self, client, auth_headers, mock_graph_data):
        """Test comprehensive daily report generation."""
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_users = AsyncMock(return_value=mock_graph_data["users"])
            mock_graph_client.get_licenses = AsyncMock(return_value=mock_graph_data["licenses"])
            
            response = client.post("/reports/generate?report_type=daily&format=json", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert data["report"]["type"] == "daily"
            assert data["report"]["format"] == "json"
            assert "generated_at" in data["report"]
            assert "generated_by" in data["report"]
    
    def test_generate_weekly_usage_report(self, client, auth_headers):
        """Test weekly usage report generation."""
        response = client.post("/reports/generate?report_type=weekly&format=json", headers=auth_headers)
        assert response.status_code == status.HTTP_200_OK
        
        data = response.json()
        assert data["report"]["type"] == "weekly"
        assert data["report"]["format"] == "json"
    
    def test_generate_monthly_license_report(self, client, auth_headers):
        """Test monthly license report generation."""
        response = client.post("/reports/generate?report_type=monthly&format=json", headers=auth_headers)
        assert response.status_code == status.HTTP_200_OK
        
        data = response.json()
        assert data["report"]["type"] == "monthly"
        assert data["report"]["format"] == "json"
    
    def test_generate_yearly_compliance_report(self, client, auth_headers):
        """Test yearly compliance report generation."""
        response = client.post("/reports/generate?report_type=yearly&format=json", headers=auth_headers)
        assert response.status_code == status.HTTP_200_OK
        
        data = response.json()
        assert data["report"]["type"] == "yearly"
        assert data["report"]["format"] == "json"
    
    # =================================================================
    # Error Handling and Resilience Tests
    # =================================================================
    
    def test_graph_api_timeout_handling(self, client, auth_headers):
        """Test handling of Graph API timeout errors."""
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_users = AsyncMock(side_effect=asyncio.TimeoutError("Request timeout"))
            
            response = client.get("/m365/users", headers=auth_headers)
            assert response.status_code == status.HTTP_500_INTERNAL_SERVER_ERROR
            
            data = response.json()
            assert data["error"] == "Failed to fetch users"
    
    def test_graph_api_rate_limit_handling(self, client, auth_headers):
        """Test handling of Graph API rate limiting."""
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_users = AsyncMock(side_effect=Exception("Rate limit exceeded"))
            
            response = client.get("/m365/users", headers=auth_headers)
            assert response.status_code == status.HTTP_500_INTERNAL_SERVER_ERROR
            
            data = response.json()
            assert data["error"] == "Failed to fetch users"
    
    def test_exchange_online_connection_error(self, client, auth_headers):
        """Test handling of Exchange Online connection errors."""
        with patch.object(app.state, 'exchange_client') as mock_exchange_client:
            mock_exchange_client.get_mailbox_statistics = AsyncMock(side_effect=Exception("Connection failed"))
            
            response = client.get("/exchange/mailboxes/stats", headers=auth_headers)
            assert response.status_code == status.HTTP_500_INTERNAL_SERVER_ERROR
    
    def test_authentication_token_expiry(self, client):
        """Test handling of expired authentication tokens."""
        expired_headers = {"Authorization": "Bearer expired-token"}
        
        with patch("src.api.main.get_current_user") as mock_get_user:
            mock_get_user.side_effect = Exception("Token expired")
            
            response = client.get("/m365/users", headers=expired_headers)
            assert response.status_code == status.HTTP_401_UNAUTHORIZED
    
    # =================================================================
    # Performance and Load Tests
    # =================================================================
    
    def test_concurrent_graph_api_requests(self, client, auth_headers, mock_graph_data):
        """Test concurrent Graph API requests handling."""
        import threading
        import time
        
        results = []
        
        def make_request():
            with patch.object(app.state, 'graph_client') as mock_graph_client:
                mock_graph_client.get_users = AsyncMock(return_value=mock_graph_data["users"])
                
                response = client.get("/m365/users", headers=auth_headers)
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
    
    def test_large_dataset_handling(self, client, auth_headers):
        """Test handling of large datasets from Microsoft 365."""
        # Create a large mock dataset
        large_user_dataset = []
        for i in range(1000):
            large_user_dataset.append({
                "id": f"user{i}",
                "displayName": f"User {i}",
                "userPrincipalName": f"user{i}@company.com",
                "mail": f"user{i}@company.com",
                "jobTitle": f"Role {i}",
                "department": f"Department {i % 10}"
            })
        
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_users = AsyncMock(return_value=large_user_dataset)
            
            response = client.get("/m365/users?limit=1000", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            assert len(data) == 1000
    
    # =================================================================
    # Data Validation Tests
    # =================================================================
    
    def test_user_data_validation(self, client, auth_headers):
        """Test validation of user data from Microsoft Graph."""
        invalid_user_data = [
            {
                "id": "user1",
                "displayName": None,  # Invalid null display name
                "userPrincipalName": "invalid-email",  # Invalid email format
                "mail": "alice.johnson@company.com"
            }
        ]
        
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_users = AsyncMock(return_value=invalid_user_data)
            
            response = client.get("/m365/users", headers=auth_headers)
            assert response.status_code == status.HTTP_200_OK
            
            data = response.json()
            # Should handle null values gracefully
            assert data[0]["display_name"] is None
            assert data[0]["user_principal_name"] == "invalid-email"
    
    def test_license_data_validation(self, client, auth_headers):
        """Test validation of license data from Microsoft Graph."""
        invalid_license_data = [
            {
                "skuId": "license1",
                "skuPartNumber": "ENTERPRISEPACK",
                "consumedUnits": "invalid",  # Should be integer
                "enabledUnits": -1,  # Negative value
                "suspendedUnits": None,  # Null value
                "warningUnits": 0
            }
        ]
        
        with patch.object(app.state, 'graph_client') as mock_graph_client:
            mock_graph_client.get_licenses = AsyncMock(return_value=invalid_license_data)
            
            response = client.get("/m365/licenses", headers=auth_headers)
            # Should handle data validation errors
            assert response.status_code in [status.HTTP_200_OK, status.HTTP_500_INTERNAL_SERVER_ERROR]


# =================================================================
# Async Integration Tests
# =================================================================

class TestAsyncMicrosoft365Integration:
    """Async integration tests for Microsoft 365 services."""
    
    @pytest_asyncio.async_def
    async def test_async_graph_api_calls(self):
        """Test async Graph API calls."""
        async with AsyncClient(app=app, base_url="http://test") as ac:
            with patch.object(app.state, 'graph_client') as mock_graph_client:
                mock_graph_client.get_users = AsyncMock(return_value=[{"id": "user1", "displayName": "Test User"}])
                
                response = await ac.get("/m365/users", headers={"Authorization": "Bearer test-token"})
                assert response.status_code == status.HTTP_200_OK
    
    @pytest_asyncio.async_def
    async def test_async_report_generation(self):
        """Test async report generation."""
        async with AsyncClient(app=app, base_url="http://test") as ac:
            response = await ac.post(
                "/reports/generate?report_type=daily",
                headers={"Authorization": "Bearer test-token"}
            )
            assert response.status_code == status.HTTP_200_OK


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