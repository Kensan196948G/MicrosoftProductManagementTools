#!/usr/bin/env python3
"""
Context Managers - Phase 3 FastAPI 0.115.12
Advanced context management for enterprise dependencies
"""

import asyncio
import logging
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, AsyncGenerator
from dataclasses import dataclass, field
import weakref

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

from src.core.config import get_settings
from src.api.security.multi_tenant import Tenant
from src.api.microsoft_graph_client import AsyncMicrosoftGraphClient

logger = logging.getLogger(__name__)
settings = get_settings()


@dataclass
class RequestContext:
    """Request context information"""
    request_id: str
    method: str
    path: str
    user_id: Optional[str] = None
    tenant_id: Optional[str] = None
    start_time: datetime = field(default_factory=datetime.utcnow)
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def duration(self) -> timedelta:
        """Get request duration"""
        return datetime.utcnow() - self.start_time


class RequestContextManager:
    """Advanced request context management"""
    
    def __init__(self):
        self._contexts: Dict[str, RequestContext] = {}
        self._cleanup_interval = 300  # 5 minutes
        self._max_contexts = 10000
        
    async def create_context(self, 
                           request: Request,
                           request_id: str,
                           user_id: Optional[str] = None,
                           tenant_id: Optional[str] = None) -> RequestContext:
        """
        Create request context
        
        Args:
            request: FastAPI request
            request_id: Unique request identifier
            user_id: User identifier
            tenant_id: Tenant identifier
            
        Returns:
            Request context
        """
        try:
            # Clean up old contexts
            await self._cleanup_old_contexts()
            
            context = RequestContext(
                request_id=request_id,
                method=request.method,
                path=request.url.path,
                user_id=user_id,
                tenant_id=tenant_id,
                metadata={
                    "user_agent": request.headers.get("user-agent"),
                    "client_ip": getattr(request.client, 'host', None) if request.client else None,
                    "query_params": dict(request.query_params),
                    "headers": dict(request.headers)
                }
            )
            
            self._contexts[request_id] = context
            
            logger.debug(f"Created request context: {request_id}")
            return context
            
        except Exception as e:
            logger.error(f"Error creating request context: {e}")
            raise
    
    async def get_context(self, request_id: str) -> Optional[RequestContext]:
        """Get request context by ID"""
        return self._contexts.get(request_id)
    
    async def update_context(self, request_id: str, **kwargs):
        """Update request context"""
        if request_id in self._contexts:
            context = self._contexts[request_id]
            for key, value in kwargs.items():
                if hasattr(context, key):
                    setattr(context, key, value)
                else:
                    context.metadata[key] = value
    
    async def remove_context(self, request_id: str):
        """Remove request context"""
        self._contexts.pop(request_id, None)
        logger.debug(f"Removed request context: {request_id}")
    
    async def get_active_contexts(self) -> List[RequestContext]:
        """Get all active contexts"""
        return list(self._contexts.values())
    
    async def _cleanup_old_contexts(self):
        """Clean up old contexts"""
        try:
            cutoff_time = datetime.utcnow() - timedelta(seconds=self._cleanup_interval)
            old_contexts = [
                request_id for request_id, context in self._contexts.items()
                if context.start_time < cutoff_time
            ]
            
            for request_id in old_contexts:
                self._contexts.pop(request_id, None)
            
            if old_contexts:
                logger.debug(f"Cleaned up {len(old_contexts)} old contexts")
                
        except Exception as e:
            logger.error(f"Error cleaning up contexts: {e}")


@dataclass
class TenantContext:
    """Tenant context information"""
    tenant: Tenant
    settings: Dict[str, Any] = field(default_factory=dict)
    cache: Dict[str, Any] = field(default_factory=dict)
    last_accessed: datetime = field(default_factory=datetime.utcnow)
    
    def is_expired(self, ttl: int = 3600) -> bool:
        """Check if context is expired"""
        return (datetime.utcnow() - self.last_accessed).total_seconds() > ttl


class TenantContextManager:
    """Advanced tenant context management"""
    
    def __init__(self, cache_ttl: int = 3600):
        self._contexts: Dict[str, TenantContext] = {}
        self._cache_ttl = cache_ttl
        
    async def get_tenant_context(self, tenant_id: str) -> Optional[TenantContext]:
        """
        Get tenant context with caching
        
        Args:
            tenant_id: Tenant identifier
            
        Returns:
            Tenant context or None
        """
        try:
            # Check cache first
            if tenant_id in self._contexts:
                context = self._contexts[tenant_id]
                if not context.is_expired(self._cache_ttl):
                    context.last_accessed = datetime.utcnow()
                    return context
                else:
                    # Remove expired context
                    del self._contexts[tenant_id]
            
            # Load tenant from multi-tenant manager
            from src.api.security.multi_tenant import multi_tenant_manager
            tenant = await multi_tenant_manager.get_tenant(tenant_id)
            
            if not tenant:
                return None
            
            # Create new context
            context = TenantContext(
                tenant=tenant,
                settings=await self._load_tenant_settings(tenant_id),
                cache={}
            )
            
            self._contexts[tenant_id] = context
            logger.debug(f"Created tenant context: {tenant_id}")
            
            return context
            
        except Exception as e:
            logger.error(f"Error getting tenant context: {e}")
            return None
    
    async def _load_tenant_settings(self, tenant_id: str) -> Dict[str, Any]:
        """Load tenant-specific settings"""
        try:
            # Default tenant settings
            settings = {
                "rate_limits": {
                    "api_calls_per_hour": 1000,
                    "concurrent_connections": 100
                },
                "features": {
                    "realtime_notifications": True,
                    "advanced_analytics": True,
                    "export_capabilities": True
                },
                "security": {
                    "require_mfa": True,
                    "session_timeout": 3600,
                    "ip_whitelist": []
                }
            }
            
            # TODO: Load from database or configuration service
            return settings
            
        except Exception as e:
            logger.error(f"Error loading tenant settings: {e}")
            return {}
    
    async def update_tenant_cache(self, tenant_id: str, key: str, value: Any):
        """Update tenant cache"""
        if tenant_id in self._contexts:
            self._contexts[tenant_id].cache[key] = value
            self._contexts[tenant_id].last_accessed = datetime.utcnow()
    
    async def get_tenant_cache(self, tenant_id: str, key: str) -> Any:
        """Get value from tenant cache"""
        if tenant_id in self._contexts:
            return self._contexts[tenant_id].cache.get(key)
        return None
    
    async def clear_tenant_cache(self, tenant_id: str):
        """Clear tenant cache"""
        if tenant_id in self._contexts:
            self._contexts[tenant_id].cache.clear()
    
    async def cleanup_expired_contexts(self):
        """Clean up expired tenant contexts"""
        try:
            expired_tenants = [
                tenant_id for tenant_id, context in self._contexts.items()
                if context.is_expired(self._cache_ttl)
            ]
            
            for tenant_id in expired_tenants:
                del self._contexts[tenant_id]
            
            if expired_tenants:
                logger.debug(f"Cleaned up {len(expired_tenants)} expired tenant contexts")
                
        except Exception as e:
            logger.error(f"Error cleaning up tenant contexts: {e}")


@dataclass
class GraphContext:
    """Microsoft Graph client context"""
    client: AsyncMicrosoftGraphClient
    tenant_id: str
    user_id: str
    last_used: datetime = field(default_factory=datetime.utcnow)
    request_count: int = 0
    error_count: int = 0
    
    def is_expired(self, ttl: int = 1800) -> bool:
        """Check if context is expired"""
        return (datetime.utcnow() - self.last_used).total_seconds() > ttl


class GraphContextManager:
    """Advanced Microsoft Graph client context management"""
    
    def __init__(self, max_clients: int = 100, client_ttl: int = 1800):
        self._contexts: Dict[str, GraphContext] = {}
        self._max_clients = max_clients
        self._client_ttl = client_ttl
        
    def _get_context_key(self, tenant_id: str, user_id: str) -> str:
        """Generate context key"""
        return f"{tenant_id}:{user_id}"
    
    async def get_graph_context(self, 
                              tenant_id: str, 
                              user_id: str) -> Optional[GraphContext]:
        """
        Get Graph client context with connection pooling
        
        Args:
            tenant_id: Tenant identifier
            user_id: User identifier
            
        Returns:
            Graph context or None
        """
        try:
            context_key = self._get_context_key(tenant_id, user_id)
            
            # Check existing context
            if context_key in self._contexts:
                context = self._contexts[context_key]
                if not context.is_expired(self._client_ttl):
                    context.last_used = datetime.utcnow()
                    return context
                else:
                    # Remove expired context
                    await self._remove_context(context_key)
            
            # Create new Graph client
            from src.api.microsoft_graph_client import create_graph_client
            client = create_graph_client(
                async_mode=True,
                tenant_id=tenant_id,
                enable_caching=True,
                enable_batching=True
            )
            
            # Create new context
            context = GraphContext(
                client=client,
                tenant_id=tenant_id,
                user_id=user_id
            )
            
            # Manage context pool size
            await self._manage_context_pool()
            
            self._contexts[context_key] = context
            logger.debug(f"Created Graph context: {context_key}")
            
            return context
            
        except Exception as e:
            logger.error(f"Error getting Graph context: {e}")
            return None
    
    async def _manage_context_pool(self):
        """Manage context pool size"""
        if len(self._contexts) >= self._max_clients:
            # Remove oldest contexts
            oldest_contexts = sorted(
                self._contexts.items(),
                key=lambda x: x[1].last_used
            )
            
            contexts_to_remove = oldest_contexts[:len(self._contexts) - self._max_clients + 1]
            for context_key, _ in contexts_to_remove:
                await self._remove_context(context_key)
    
    async def _remove_context(self, context_key: str):
        """Remove context and cleanup client"""
        if context_key in self._contexts:
            context = self._contexts[context_key]
            try:
                # Cleanup Graph client if needed
                if hasattr(context.client, 'close'):
                    await context.client.close()
            except Exception as e:
                logger.warning(f"Error closing Graph client: {e}")
            
            del self._contexts[context_key]
            logger.debug(f"Removed Graph context: {context_key}")
    
    async def update_context_stats(self, tenant_id: str, user_id: str, success: bool = True):
        """Update context statistics"""
        context_key = self._get_context_key(tenant_id, user_id)
        if context_key in self._contexts:
            context = self._contexts[context_key]
            context.request_count += 1
            context.last_used = datetime.utcnow()
            
            if not success:
                context.error_count += 1
    
    async def get_context_stats(self) -> Dict[str, Any]:
        """Get context statistics"""
        return {
            "total_contexts": len(self._contexts),
            "active_contexts": len([
                c for c in self._contexts.values() 
                if not c.is_expired(self._client_ttl)
            ]),
            "total_requests": sum(c.request_count for c in self._contexts.values()),
            "total_errors": sum(c.error_count for c in self._contexts.values())
        }
    
    async def cleanup_expired_contexts(self):
        """Clean up expired Graph contexts"""
        try:
            expired_contexts = [
                context_key for context_key, context in self._contexts.items()
                if context.is_expired(self._client_ttl)
            ]
            
            for context_key in expired_contexts:
                await self._remove_context(context_key)
            
            if expired_contexts:
                logger.debug(f"Cleaned up {len(expired_contexts)} expired Graph contexts")
                
        except Exception as e:
            logger.error(f"Error cleaning up Graph contexts: {e}")


# Global instances
request_context_manager = RequestContextManager()
tenant_context_manager = TenantContextManager()
graph_context_manager = GraphContextManager()


# Context managers
@asynccontextmanager
async def request_context(request: Request, 
                         request_id: str,
                         user_id: Optional[str] = None,
                         tenant_id: Optional[str] = None) -> AsyncGenerator[RequestContext, None]:
    """Request context manager"""
    context = await request_context_manager.create_context(
        request=request,
        request_id=request_id,
        user_id=user_id,
        tenant_id=tenant_id
    )
    
    try:
        yield context
    finally:
        await request_context_manager.remove_context(request_id)


@asynccontextmanager
async def tenant_context(tenant_id: str) -> AsyncGenerator[Optional[TenantContext], None]:
    """Tenant context manager"""
    context = await tenant_context_manager.get_tenant_context(tenant_id)
    
    try:
        yield context
    finally:
        # Context cleanup handled by manager
        pass


@asynccontextmanager
async def graph_context(tenant_id: str, user_id: str) -> AsyncGenerator[Optional[GraphContext], None]:
    """Graph context manager"""
    context = await graph_context_manager.get_graph_context(tenant_id, user_id)
    
    try:
        yield context
        if context:
            await graph_context_manager.update_context_stats(tenant_id, user_id, True)
    except Exception as e:
        if context:
            await graph_context_manager.update_context_stats(tenant_id, user_id, False)
        raise


# Background cleanup task
async def cleanup_contexts_task():
    """Background task to cleanup expired contexts"""
    while True:
        try:
            await asyncio.gather(
                request_context_manager._cleanup_old_contexts(),
                tenant_context_manager.cleanup_expired_contexts(),
                graph_context_manager.cleanup_expired_contexts(),
                return_exceptions=True
            )
            
            # Sleep for 5 minutes
            await asyncio.sleep(300)
            
        except Exception as e:
            logger.error(f"Error in context cleanup task: {e}")
            await asyncio.sleep(60)  # Retry after 1 minute


# Middleware for automatic context management
class ContextMiddleware(BaseHTTPMiddleware):
    """Middleware for automatic context management"""
    
    async def dispatch(self, request: Request, call_next):
        """Process request with context management"""
        import uuid
        
        # Generate request ID
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id
        
        # Create request context
        context = await request_context_manager.create_context(
            request=request,
            request_id=request_id
        )
        
        try:
            # Process request
            response = await call_next(request)
            
            # Add request ID to response headers
            response.headers["X-Request-ID"] = request_id
            
            return response
            
        except Exception as e:
            logger.error(f"Request {request_id} failed: {e}")
            raise
        finally:
            # Update context with response info
            duration = context.duration()
            await request_context_manager.update_context(
                request_id,
                duration_ms=duration.total_seconds() * 1000
            )


if __name__ == "__main__":
    # Test context managers
    import asyncio
    
    async def test_context_managers():
        """Test context management functionality"""
        print("Testing context managers...")
        
        # Test request context
        from fastapi import Request
        from starlette.datastructures import URL
        
        # Mock request
        mock_request = Request({
            "type": "http",
            "method": "GET",
            "url": URL("http://localhost:8000/test"),
            "headers": [],
            "query_string": b"",
        })
        
        async with request_context(mock_request, "test-123", "user-1", "tenant-1") as ctx:
            print(f"Request context created: {ctx.request_id}")
        
        # Test tenant context
        async with tenant_context("tenant-1") as ctx:
            if ctx:
                print(f"Tenant context: {ctx.tenant.id}")
        
        print("Context manager test completed")
    
    asyncio.run(test_context_managers())