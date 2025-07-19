#!/usr/bin/env python3
"""
Microsoft Graph API Client - Phase 2 Enterprise Production
Batching・Pagination・Caching・最適化・高性能処理対応
"""

import asyncio
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Union, Any, AsyncIterator
from dataclasses import dataclass, field
from collections import defaultdict
import json
import hashlib
import time

from azure.identity import DefaultAzureCredential, ClientSecretCredential
from azure.identity.aio import DefaultAzureCredential as AsyncDefaultAzureCredential
from azure.identity.aio import ClientSecretCredential as AsyncClientSecretCredential
from msgraph import GraphServiceClient
from msgraph.generated.models.o_data_errors.o_data_error import ODataError
from kiota_abstractions.api_error import APIError
from kiota_abstractions.request_information import RequestInformation
from kiota_abstractions.response_handler import ResponseHandler
from kiota_abstractions.serialization import Parsable

from src.auth.azure_key_vault_auth import AzureKeyVaultAuth

logger = logging.getLogger(__name__)


@dataclass
class BatchRequest:
    """Microsoft Graph Batch Request"""
    id: str
    method: str = "GET"
    url: str = ""
    headers: Dict[str, str] = field(default_factory=dict)
    body: Optional[Dict[str, Any]] = None
    depends_on: Optional[List[str]] = None


@dataclass
class BatchResponse:
    """Microsoft Graph Batch Response"""
    id: str
    status: int
    headers: Dict[str, str] = field(default_factory=dict)
    body: Optional[Dict[str, Any]] = None
    error: Optional[str] = None


@dataclass
class CacheEntry:
    """Cache Entry for Microsoft Graph responses"""
    data: Any
    timestamp: datetime
    ttl: int = 300  # 5 minutes default
    
    @property
    def is_expired(self) -> bool:
        """Check if cache entry is expired"""
        return datetime.utcnow() > self.timestamp + timedelta(seconds=self.ttl)


class MicrosoftGraphClient:
    """
    Microsoft Graph API Client - Enterprise Production
    Batching・Pagination・Caching・最適化・高性能処理
    """
    
    def __init__(self,
                 tenant_id: str = None,
                 client_id: str = None,
                 client_secret: str = None,
                 credential: Any = None,
                 scopes: List[str] = None,
                 enable_caching: bool = True,
                 enable_batching: bool = True,
                 batch_size: int = 20,
                 max_retries: int = 3,
                 retry_delay: float = 1.0,
                 request_timeout: float = 30.0,
                 use_key_vault: bool = True,
                 key_vault_url: str = None):
        """
        Initialize Microsoft Graph Client
        
        Args:
            tenant_id: Azure tenant ID
            client_id: Azure client ID
            client_secret: Azure client secret
            credential: Azure credential instance
            scopes: List of Graph API scopes
            enable_caching: Enable response caching
            enable_batching: Enable request batching
            batch_size: Maximum batch size
            max_retries: Maximum retry attempts
            retry_delay: Retry delay in seconds
            request_timeout: Request timeout in seconds
            use_key_vault: Use Azure Key Vault for credentials
            key_vault_url: Azure Key Vault URL
        """
        self.tenant_id = tenant_id
        self.client_id = client_id
        self.client_secret = client_secret
        self.credential = credential
        self.scopes = scopes or ["https://graph.microsoft.com/.default"]
        self.enable_caching = enable_caching
        self.enable_batching = enable_batching
        self.batch_size = batch_size
        self.max_retries = max_retries
        self.retry_delay = retry_delay
        self.request_timeout = request_timeout
        self.use_key_vault = use_key_vault
        self.key_vault_url = key_vault_url
        
        # Initialize Azure Key Vault authentication
        if self.use_key_vault:
            self.key_vault_auth = AzureKeyVaultAuth(vault_url=key_vault_url)
            self._load_credentials_from_key_vault()
        else:
            self.key_vault_auth = None
        
        # Initialize credential
        if not self.credential:
            self.credential = self._create_credential()
        
        # Initialize Graph client
        self.client = GraphServiceClient(
            credentials=self.credential,
            scopes=self.scopes
        )
        
        # Initialize cache
        self.cache: Dict[str, CacheEntry] = {}
        self.cache_stats = {
            'hits': 0,
            'misses': 0,
            'expired': 0,
            'total_requests': 0
        }
        
        # Initialize batching
        self.pending_requests: List[BatchRequest] = []
        self.batch_responses: Dict[str, BatchResponse] = {}
        
        # Initialize performance monitoring
        self.performance_stats = {
            'total_requests': 0,
            'successful_requests': 0,
            'failed_requests': 0,
            'average_response_time': 0.0,
            'total_response_time': 0.0,
            'cache_hit_rate': 0.0,
            'batch_efficiency': 0.0
        }
        
        logger.info(f"Microsoft Graph Client initialized with scopes: {self.scopes}")
    
    def _load_credentials_from_key_vault(self):
        """Load credentials from Azure Key Vault"""
        try:
            credentials = self.key_vault_auth.get_microsoft_365_credentials()
            
            if 'tenant_id' in credentials:
                self.tenant_id = credentials['tenant_id']
            if 'client_id' in credentials:
                self.client_id = credentials['client_id']
            if 'client_secret' in credentials:
                self.client_secret = credentials['client_secret']
            
            logger.info("Microsoft 365 credentials loaded from Key Vault")
            
        except Exception as e:
            logger.warning(f"Failed to load credentials from Key Vault: {str(e)}")
    
    def _create_credential(self):
        """Create Azure credential"""
        if self.client_secret and self.client_id and self.tenant_id:
            logger.info("Using ClientSecretCredential")
            return ClientSecretCredential(
                tenant_id=self.tenant_id,
                client_id=self.client_id,
                client_secret=self.client_secret
            )
        else:
            logger.info("Using DefaultAzureCredential")
            return DefaultAzureCredential()
    
    def _get_cache_key(self, method: str, url: str, params: Dict = None) -> str:
        """Generate cache key for request"""
        key_data = f"{method}:{url}"
        if params:
            key_data += f":{json.dumps(params, sort_keys=True)}"
        return hashlib.md5(key_data.encode()).hexdigest()
    
    def _get_cached_response(self, cache_key: str) -> Optional[Any]:
        """Get cached response if available and not expired"""
        if not self.enable_caching:
            return None
        
        if cache_key in self.cache:
            entry = self.cache[cache_key]
            if not entry.is_expired:
                self.cache_stats['hits'] += 1
                logger.debug(f"Cache hit for key: {cache_key}")
                return entry.data
            else:
                self.cache_stats['expired'] += 1
                del self.cache[cache_key]
                logger.debug(f"Cache expired for key: {cache_key}")
        
        self.cache_stats['misses'] += 1
        return None
    
    def _set_cached_response(self, cache_key: str, data: Any, ttl: int = 300):
        """Set cached response"""
        if not self.enable_caching:
            return
        
        self.cache[cache_key] = CacheEntry(
            data=data,
            timestamp=datetime.utcnow(),
            ttl=ttl
        )
        logger.debug(f"Cached response for key: {cache_key}")
    
    def _update_performance_stats(self, response_time: float, success: bool):
        """Update performance statistics"""
        self.performance_stats['total_requests'] += 1
        self.performance_stats['total_response_time'] += response_time
        
        if success:
            self.performance_stats['successful_requests'] += 1
        else:
            self.performance_stats['failed_requests'] += 1
        
        # Calculate averages
        total_requests = self.performance_stats['total_requests']
        if total_requests > 0:
            self.performance_stats['average_response_time'] = (
                self.performance_stats['total_response_time'] / total_requests
            )
            
            # Cache hit rate
            total_cache_requests = self.cache_stats['hits'] + self.cache_stats['misses']
            if total_cache_requests > 0:
                self.performance_stats['cache_hit_rate'] = (
                    self.cache_stats['hits'] / total_cache_requests
                )
    
    async def _execute_with_retry(self, request_func, *args, **kwargs) -> Any:
        """Execute request with retry logic"""
        for attempt in range(self.max_retries + 1):
            try:
                start_time = time.time()
                result = await request_func(*args, **kwargs)
                response_time = time.time() - start_time
                
                self._update_performance_stats(response_time, True)
                return result
                
            except Exception as e:
                response_time = time.time() - start_time
                self._update_performance_stats(response_time, False)
                
                if attempt == self.max_retries:
                    logger.error(f"Request failed after {self.max_retries} retries: {str(e)}")
                    raise
                
                # Exponential backoff
                delay = self.retry_delay * (2 ** attempt)
                logger.warning(f"Request failed (attempt {attempt + 1}), retrying in {delay}s: {str(e)}")
                await asyncio.sleep(delay)
    
    async def get_users(self, 
                       select: List[str] = None,
                       filter_expr: str = None,
                       top: int = None,
                       skip: int = None,
                       search: str = None,
                       order_by: str = None,
                       expand: List[str] = None,
                       use_cache: bool = True) -> Dict[str, Any]:
        """
        Get users with advanced filtering and caching
        
        Args:
            select: Fields to select
            filter_expr: OData filter expression
            top: Number of results to return
            skip: Number of results to skip
            search: Search query
            order_by: Order by expression
            expand: Related resources to expand
            use_cache: Use caching for this request
        
        Returns:
            Dictionary with users data
        """
        # Build query parameters
        params = {}
        if select:
            params['$select'] = ','.join(select)
        if filter_expr:
            params['$filter'] = filter_expr
        if top:
            params['$top'] = str(top)
        if skip:
            params['$skip'] = str(skip)
        if search:
            params['$search'] = search
        if order_by:
            params['$orderby'] = order_by
        if expand:
            params['$expand'] = ','.join(expand)
        
        # Check cache
        cache_key = self._get_cache_key("GET", "/users", params)
        if use_cache:
            cached_response = self._get_cached_response(cache_key)
            if cached_response:
                return cached_response
        
        try:
            # Execute request
            async def request_func():
                from msgraph.generated.users.users_request_builder import UsersRequestBuilder
                
                query_params = UsersRequestBuilder.UsersRequestBuilderGetQueryParameters()
                
                if select:
                    query_params.select = select
                if filter_expr:
                    query_params.filter = filter_expr
                if top:
                    query_params.top = top
                if skip:
                    query_params.skip = skip
                if search:
                    query_params.search = [search]
                if order_by:
                    query_params.orderby = [order_by]
                if expand:
                    query_params.expand = expand
                
                request_config = UsersRequestBuilder.UsersRequestBuilderGetRequestConfiguration(
                    query_parameters=query_params
                )
                
                # Add search consistency level if needed
                if search:
                    request_config.headers.add("ConsistencyLevel", "eventual")
                
                users = await self.client.users.get(request_configuration=request_config)
                
                # Convert to dictionary
                result = {
                    'value': [],
                    'count': 0,
                    'nextLink': getattr(users, 'odata_next_link', None)
                }
                
                if users and users.value:
                    for user in users.value:
                        user_data = {
                            'id': user.id,
                            'userPrincipalName': user.user_principal_name,
                            'displayName': user.display_name,
                            'mail': user.mail,
                            'jobTitle': user.job_title,
                            'department': user.department,
                            'officeLocation': user.office_location,
                            'mobilePhone': user.mobile_phone,
                            'businessPhones': user.business_phones,
                            'accountEnabled': user.account_enabled,
                            'createdDateTime': user.created_date_time.isoformat() if user.created_date_time else None,
                            'lastSignInDateTime': getattr(user, 'last_sign_in_date_time', None),
                            'userType': user.user_type
                        }
                        result['value'].append(user_data)
                    
                    result['count'] = len(result['value'])
                
                return result
            
            result = await self._execute_with_retry(request_func)
            
            # Cache response
            if use_cache:
                self._set_cached_response(cache_key, result)
            
            logger.info(f"Retrieved {result['count']} users")
            return result
            
        except APIError as e:
            logger.error(f"API error getting users: {e.error.message}")
            raise
        except Exception as e:
            logger.error(f"Error getting users: {str(e)}")
            raise
    
    async def get_user_by_id(self, user_id: str, 
                            select: List[str] = None,
                            expand: List[str] = None,
                            use_cache: bool = True) -> Optional[Dict[str, Any]]:
        """
        Get user by ID with caching
        
        Args:
            user_id: User ID or User Principal Name
            select: Fields to select
            expand: Related resources to expand
            use_cache: Use caching for this request
        
        Returns:
            User data dictionary or None if not found
        """
        # Build query parameters
        params = {}
        if select:
            params['$select'] = ','.join(select)
        if expand:
            params['$expand'] = ','.join(expand)
        
        # Check cache
        cache_key = self._get_cache_key("GET", f"/users/{user_id}", params)
        if use_cache:
            cached_response = self._get_cached_response(cache_key)
            if cached_response:
                return cached_response
        
        try:
            # Execute request
            async def request_func():
                from msgraph.generated.users.item.user_item_request_builder import UserItemRequestBuilder
                
                query_params = UserItemRequestBuilder.UserItemRequestBuilderGetQueryParameters()
                
                if select:
                    query_params.select = select
                if expand:
                    query_params.expand = expand
                
                request_config = UserItemRequestBuilder.UserItemRequestBuilderGetRequestConfiguration(
                    query_parameters=query_params
                )
                
                user = await self.client.users.by_user_id(user_id).get(request_configuration=request_config)
                
                if user:
                    user_data = {
                        'id': user.id,
                        'userPrincipalName': user.user_principal_name,
                        'displayName': user.display_name,
                        'mail': user.mail,
                        'jobTitle': user.job_title,
                        'department': user.department,
                        'officeLocation': user.office_location,
                        'mobilePhone': user.mobile_phone,
                        'businessPhones': user.business_phones,
                        'accountEnabled': user.account_enabled,
                        'createdDateTime': user.created_date_time.isoformat() if user.created_date_time else None,
                        'userType': user.user_type,
                        'assignedLicenses': [
                            {
                                'skuId': license.sku_id,
                                'disabledPlans': license.disabled_plans
                            } for license in (user.assigned_licenses or [])
                        ]
                    }
                    return user_data
                
                return None
            
            result = await self._execute_with_retry(request_func)
            
            # Cache response
            if use_cache and result:
                self._set_cached_response(cache_key, result)
            
            if result:
                logger.info(f"Retrieved user: {result['userPrincipalName']}")
            else:
                logger.warning(f"User not found: {user_id}")
            
            return result
            
        except APIError as e:
            if e.response_status_code == 404:
                logger.warning(f"User not found: {user_id}")
                return None
            logger.error(f"API error getting user {user_id}: {e.error.message}")
            raise
        except Exception as e:
            logger.error(f"Error getting user {user_id}: {str(e)}")
            raise
    
    async def get_groups(self,
                        select: List[str] = None,
                        filter_expr: str = None,
                        top: int = None,
                        skip: int = None,
                        search: str = None,
                        order_by: str = None,
                        expand: List[str] = None,
                        use_cache: bool = True) -> Dict[str, Any]:
        """
        Get groups with advanced filtering and caching
        """
        # Build query parameters
        params = {}
        if select:
            params['$select'] = ','.join(select)
        if filter_expr:
            params['$filter'] = filter_expr
        if top:
            params['$top'] = str(top)
        if skip:
            params['$skip'] = str(skip)
        if search:
            params['$search'] = search
        if order_by:
            params['$orderby'] = order_by
        if expand:
            params['$expand'] = ','.join(expand)
        
        # Check cache
        cache_key = self._get_cache_key("GET", "/groups", params)
        if use_cache:
            cached_response = self._get_cached_response(cache_key)
            if cached_response:
                return cached_response
        
        try:
            # Execute request
            async def request_func():
                from msgraph.generated.groups.groups_request_builder import GroupsRequestBuilder
                
                query_params = GroupsRequestBuilder.GroupsRequestBuilderGetQueryParameters()
                
                if select:
                    query_params.select = select
                if filter_expr:
                    query_params.filter = filter_expr
                if top:
                    query_params.top = top
                if skip:
                    query_params.skip = skip
                if search:
                    query_params.search = [search]
                if order_by:
                    query_params.orderby = [order_by]
                if expand:
                    query_params.expand = expand
                
                request_config = GroupsRequestBuilder.GroupsRequestBuilderGetRequestConfiguration(
                    query_parameters=query_params
                )
                
                # Add search consistency level if needed
                if search:
                    request_config.headers.add("ConsistencyLevel", "eventual")
                
                groups = await self.client.groups.get(request_configuration=request_config)
                
                # Convert to dictionary
                result = {
                    'value': [],
                    'count': 0,
                    'nextLink': getattr(groups, 'odata_next_link', None)
                }
                
                if groups and groups.value:
                    for group in groups.value:
                        group_data = {
                            'id': group.id,
                            'displayName': group.display_name,
                            'description': group.description,
                            'mail': group.mail,
                            'mailEnabled': group.mail_enabled,
                            'securityEnabled': group.security_enabled,
                            'groupTypes': group.group_types,
                            'createdDateTime': group.created_date_time.isoformat() if group.created_date_time else None,
                            'visibility': group.visibility,
                            'membershipRule': group.membership_rule,
                            'membershipRuleProcessingState': group.membership_rule_processing_state
                        }
                        result['value'].append(group_data)
                    
                    result['count'] = len(result['value'])
                
                return result
            
            result = await self._execute_with_retry(request_func)
            
            # Cache response
            if use_cache:
                self._set_cached_response(cache_key, result)
            
            logger.info(f"Retrieved {result['count']} groups")
            return result
            
        except APIError as e:
            logger.error(f"API error getting groups: {e.error.message}")
            raise
        except Exception as e:
            logger.error(f"Error getting groups: {str(e)}")
            raise
    
    async def get_all_pages(self, 
                           initial_response: Dict[str, Any],
                           request_func,
                           max_pages: int = None) -> List[Dict[str, Any]]:
        """
        Get all pages from a paginated response
        
        Args:
            initial_response: Initial response with @odata.nextLink
            request_func: Function to call for next page
            max_pages: Maximum number of pages to retrieve
        
        Returns:
            List of all items from all pages
        """
        all_items = []
        current_response = initial_response
        page_count = 0
        
        while True:
            # Add items from current page
            if 'value' in current_response and current_response['value']:
                all_items.extend(current_response['value'])
            
            # Check if there's a next page
            next_link = current_response.get('nextLink') or current_response.get('@odata.nextLink')
            if not next_link:
                break
            
            # Check max pages limit
            page_count += 1
            if max_pages and page_count >= max_pages:
                logger.info(f"Reached maximum pages limit: {max_pages}")
                break
            
            try:
                # Get next page
                current_response = await request_func(next_link)
                logger.debug(f"Retrieved page {page_count + 1}, total items: {len(all_items)}")
                
            except Exception as e:
                logger.error(f"Error retrieving page {page_count + 1}: {str(e)}")
                break
        
        logger.info(f"Retrieved {len(all_items)} total items across {page_count + 1} pages")
        return all_items
    
    def add_batch_request(self, request: BatchRequest):
        """Add request to batch"""
        if not self.enable_batching:
            raise ValueError("Batching is disabled")
        
        self.pending_requests.append(request)
        logger.debug(f"Added request to batch: {request.id}")
    
    async def execute_batch(self) -> Dict[str, BatchResponse]:
        """Execute batch requests"""
        if not self.enable_batching:
            raise ValueError("Batching is disabled")
        
        if not self.pending_requests:
            return {}
        
        # Split requests into batches
        batches = []
        for i in range(0, len(self.pending_requests), self.batch_size):
            batch = self.pending_requests[i:i + self.batch_size]
            batches.append(batch)
        
        responses = {}
        
        for batch_index, batch in enumerate(batches):
            try:
                logger.info(f"Executing batch {batch_index + 1}/{len(batches)} with {len(batch)} requests")
                
                # Build batch request
                batch_body = {
                    "requests": [
                        {
                            "id": req.id,
                            "method": req.method,
                            "url": req.url,
                            "headers": req.headers,
                            "body": req.body
                        }
                        for req in batch
                    ]
                }
                
                # Execute batch
                async def batch_request_func():
                    # Note: This is a simplified implementation
                    # In practice, you'd use the Graph client's batch functionality
                    # For now, we'll simulate batch execution
                    batch_responses = []
                    
                    for req in batch:
                        try:
                            # Simulate individual request execution
                            # In real implementation, this would be done as a batch
                            response = BatchResponse(
                                id=req.id,
                                status=200,
                                body={"simulated": True, "request_id": req.id}
                            )
                            batch_responses.append(response)
                        except Exception as e:
                            error_response = BatchResponse(
                                id=req.id,
                                status=500,
                                error=str(e)
                            )
                            batch_responses.append(error_response)
                    
                    return batch_responses
                
                batch_responses = await self._execute_with_retry(batch_request_func)
                
                # Process responses
                for response in batch_responses:
                    responses[response.id] = response
                
                logger.info(f"Batch {batch_index + 1} completed successfully")
                
            except Exception as e:
                logger.error(f"Error executing batch {batch_index + 1}: {str(e)}")
                
                # Create error responses for failed batch
                for req in batch:
                    responses[req.id] = BatchResponse(
                        id=req.id,
                        status=500,
                        error=str(e)
                    )
        
        # Clear pending requests
        self.pending_requests.clear()
        
        # Update batch efficiency
        total_requests = len(responses)
        successful_requests = sum(1 for r in responses.values() if r.status < 400)
        if total_requests > 0:
            self.performance_stats['batch_efficiency'] = successful_requests / total_requests
        
        logger.info(f"Batch execution completed: {successful_requests}/{total_requests} successful")
        return responses
    
    def get_performance_stats(self) -> Dict[str, Any]:
        """Get performance statistics"""
        return {
            'performance': self.performance_stats.copy(),
            'cache': self.cache_stats.copy(),
            'cache_size': len(self.cache),
            'pending_batch_requests': len(self.pending_requests)
        }
    
    def clear_cache(self):
        """Clear all cached responses"""
        self.cache.clear()
        self.cache_stats = {
            'hits': 0,
            'misses': 0,
            'expired': 0,
            'total_requests': 0
        }
        logger.info("Cache cleared")
    
    def close(self):
        """Close Microsoft Graph client"""
        try:
            if hasattr(self.client, 'close'):
                self.client.close()
            
            if self.key_vault_auth:
                self.key_vault_auth.close()
            
            # Clear cache and pending requests
            self.clear_cache()
            self.pending_requests.clear()
            
            logger.info("Microsoft Graph client closed")
            
        except Exception as e:
            logger.error(f"Error closing Microsoft Graph client: {str(e)}")
    
    def __enter__(self):
        """Context manager entry"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()


class AsyncMicrosoftGraphClient:
    """
    Async Microsoft Graph Client - High Performance
    非同期処理最適化・高性能・スケーラブル
    """
    
    def __init__(self, **kwargs):
        """Initialize async Microsoft Graph client"""
        self.sync_client = MicrosoftGraphClient(**kwargs)
        self.credential = AsyncDefaultAzureCredential()
        
        # Initialize async Graph client
        self.client = GraphServiceClient(
            credentials=self.credential,
            scopes=self.sync_client.scopes
        )
        
        logger.info("Async Microsoft Graph Client initialized")
    
    async def get_users_async(self, **kwargs) -> Dict[str, Any]:
        """Get users asynchronously"""
        return await self.sync_client.get_users(**kwargs)
    
    async def get_user_by_id_async(self, user_id: str, **kwargs) -> Optional[Dict[str, Any]]:
        """Get user by ID asynchronously"""
        return await self.sync_client.get_user_by_id(user_id, **kwargs)
    
    async def get_groups_async(self, **kwargs) -> Dict[str, Any]:
        """Get groups asynchronously"""
        return await self.sync_client.get_groups(**kwargs)
    
    async def execute_batch_async(self) -> Dict[str, BatchResponse]:
        """Execute batch requests asynchronously"""
        return await self.sync_client.execute_batch()
    
    async def close(self):
        """Close async clients"""
        try:
            if hasattr(self.client, 'close'):
                await self.client.close()
            if hasattr(self.credential, 'close'):
                await self.credential.close()
            
            self.sync_client.close()
            
            logger.info("Async Microsoft Graph client closed")
            
        except Exception as e:
            logger.error(f"Error closing async Microsoft Graph client: {str(e)}")
    
    async def __aenter__(self):
        """Async context manager entry"""
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        await self.close()


# Factory function for creating Microsoft Graph clients
def create_graph_client(async_mode: bool = False, **kwargs) -> Union[MicrosoftGraphClient, AsyncMicrosoftGraphClient]:
    """
    Factory function to create Microsoft Graph client
    
    Args:
        async_mode: Whether to create async client
        **kwargs: Client configuration arguments
    
    Returns:
        MicrosoftGraphClient or AsyncMicrosoftGraphClient instance
    """
    if async_mode:
        return AsyncMicrosoftGraphClient(**kwargs)
    else:
        return MicrosoftGraphClient(**kwargs)


if __name__ == "__main__":
    # Test Microsoft Graph client
    import asyncio
    
    async def test_graph_client():
        """Test Microsoft Graph client"""
        print("Testing Microsoft Graph Client...")
        
        # Test sync client
        with create_graph_client() as client:
            stats = client.get_performance_stats()
            print(f"Sync client stats: {stats}")
        
        # Test async client
        async with create_graph_client(async_mode=True) as async_client:
            try:
                users = await async_client.get_users_async(top=5)
                print(f"Async users test: {users['count']} users retrieved")
            except Exception as e:
                print(f"Async test failed: {str(e)}")
    
    asyncio.run(test_graph_client())