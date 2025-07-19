#!/usr/bin/env python3
"""
Advanced Dependency Injection - Phase 3 FastAPI 0.115.12
Enterprise-grade dependency system with caching, rate limiting, and context management
"""

import asyncio
import logging
import time
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Callable, AsyncGenerator, Union
from functools import wraps, lru_cache
import weakref

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from starlette.background import BackgroundTasks
import redis.asyncio as redis
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from jose import JWTError, jwt

from src.core.config import get_settings
from src.api.security.multi_tenant import MultiTenantManager, Tenant
from src.api.microsoft_graph_client import create_graph_client, AsyncMicrosoftGraphClient
from src.core.auth.authenticator import get_current_user_from_token

logger = logging.getLogger(__name__)

# Global instances
security = HTTPBearer(auto_error=False)
settings = get_settings()


class DependencyCache:
    """Advanced caching system for dependencies"""
    
    def __init__(self, ttl: int = 300, max_size: int = 1000):
        self.cache: Dict[str, Any] = {}
        self.timestamps: Dict[str, float] = {}
        self.ttl = ttl
        self.max_size = max_size
        self._access_times: Dict[str, float] = {}
    
    def get(self, key: str) -> Optional[Any]:
        """Get cached value"""
        if key not in self.cache:
            return None
        
        # Check TTL
        if time.time() - self.timestamps[key] > self.ttl:
            self._remove(key)
            return None
        
        # Update access time for LRU
        self._access_times[key] = time.time()
        return self.cache[key]
    
    def set(self, key: str, value: Any):
        """Set cached value"""
        # Evict if cache is full
        if len(self.cache) >= self.max_size:
            self._evict_lru()
        
        self.cache[key] = value
        self.timestamps[key] = time.time()
        self._access_times[key] = time.time()
    
    def _remove(self, key: str):
        """Remove key from cache"""
        self.cache.pop(key, None)
        self.timestamps.pop(key, None)
        self._access_times.pop(key, None)
    
    def _evict_lru(self):
        """Evict least recently used item"""
        if not self._access_times:
            return
        
        lru_key = min(self._access_times.keys(), key=lambda k: self._access_times[k])
        self._remove(lru_key)
    
    def clear(self):
        """Clear all cache"""
        self.cache.clear()
        self.timestamps.clear()
        self._access_times.clear()


class RateLimiter:
    """Advanced rate limiting with sliding window"""
    
    def __init__(self, redis_client: Optional[redis.Redis] = None):
        self.redis_client = redis_client
        self.local_cache: Dict[str, List[float]] = {}
    
    async def is_allowed(self, 
                        key: str, 
                        limit: int, 
                        window: int) -> bool:
        """Check if request is allowed within rate limit"""
        now = time.time()
        window_start = now - window
        
        if self.redis_client:
            return await self._redis_rate_limit(key, limit, window, now, window_start)
        else:
            return self._local_rate_limit(key, limit, window_start, now)
    
    async def _redis_rate_limit(self, 
                               key: str, 
                               limit: int, 
                               window: int, 
                               now: float, 
                               window_start: float) -> bool:
        """Redis-based distributed rate limiting"""
        try:
            pipe = self.redis_client.pipeline()
            
            # Remove old entries
            pipe.zremrangebyscore(key, 0, window_start)
            
            # Count current entries
            pipe.zcard(key)
            
            # Add current request
            pipe.zadd(key, {str(now): now})
            
            # Set expiration
            pipe.expire(key, window)
            
            results = await pipe.execute()
            current_count = results[1]
            
            return current_count < limit
            
        except Exception as e:
            logger.error(f"Redis rate limiting error: {e}")
            # Fallback to local rate limiting
            return self._local_rate_limit(key, limit, window_start, now)
    
    def _local_rate_limit(self, 
                         key: str, 
                         limit: int, 
                         window_start: float, 
                         now: float) -> bool:
        """Local in-memory rate limiting"""
        if key not in self.local_cache:
            self.local_cache[key] = []
        
        # Remove old entries
        self.local_cache[key] = [
            timestamp for timestamp in self.local_cache[key] 
            if timestamp > window_start
        ]
        
        # Check limit
        if len(self.local_cache[key]) >= limit:
            return False
        
        # Add current request
        self.local_cache[key].append(now)
        return True


class AdvancedDependencyManager:
    """
    Advanced dependency manager with caching, rate limiting, and context management
    """
    
    def __init__(self):
        self.cache = DependencyCache()
        self.rate_limiter = RateLimiter()
        self.redis_client: Optional[redis.Redis] = None
        self.db_engine = None
        self.db_session_factory = None
        self._graph_clients: weakref.WeakValueDictionary = weakref.WeakValueDictionary()
        
    async def initialize(self):
        """Initialize dependency manager"""
        try:
            # Initialize Redis
            if hasattr(settings, 'REDIS_URL') and settings.REDIS_URL:
                self.redis_client = redis.from_url(settings.REDIS_URL)
                await self.redis_client.ping()
                self.rate_limiter.redis_client = self.redis_client
                logger.info("Redis connected for dependencies")
            
            # Initialize database
            if hasattr(settings, 'DATABASE_URL') and settings.DATABASE_URL:
                self.db_engine = create_async_engine(
                    settings.DATABASE_URL,
                    echo=False,
                    pool_size=20,
                    max_overflow=0,
                    pool_pre_ping=True,
                    pool_recycle=300
                )
                self.db_session_factory = async_sessionmaker(
                    self.db_engine,
                    class_=AsyncSession,
                    expire_on_commit=False
                )
                logger.info("Database connection pool initialized")
            
            logger.info("AdvancedDependencyManager initialized")
            
        except Exception as e:
            logger.error(f"Failed to initialize dependency manager: {e}")
            raise
    
    async def close(self):
        """Close dependency manager"""
        try:
            if self.redis_client:
                await self.redis_client.close()
            
            if self.db_engine:
                await self.db_engine.dispose()
            
            self.cache.clear()
            logger.info("AdvancedDependencyManager closed")
            
        except Exception as e:
            logger.error(f"Error closing dependency manager: {e}")


# Global dependency manager
dependency_manager = AdvancedDependencyManager()


# Context dependency functions

async def get_request_context(request: Request) -> Dict[str, Any]:
    """Get comprehensive request context"""
    return {
        "method": request.method,
        "url": str(request.url),
        "path": request.url.path,
        "query_params": dict(request.query_params),
        "headers": dict(request.headers),
        "client": request.client,
        "timestamp": datetime.utcnow(),
        "request_id": getattr(request.state, 'request_id', None)
    }


async def get_authenticated_user(
    request: Request,
    authorization: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> Dict[str, Any]:
    """
    Advanced user authentication with caching
    """
    try:
        # Get token
        token = None
        if authorization:
            token = authorization.credentials
        elif request.query_params.get("token"):
            token = request.query_params.get("token")
        
        if not token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required"
            )
        
        # Check cache first
        cache_key = f"auth:{token[:20]}"  # Use token prefix for cache key
        cached_user = dependency_manager.cache.get(cache_key)
        if cached_user:
            return cached_user
        
        # Verify JWT token
        try:
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
            user_id = payload.get("sub")
            tenant_id = payload.get("tenant_id")
            
            if not user_id:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid token"
                )
            
            user_info = {
                "user_id": user_id,
                "tenant_id": tenant_id,
                "username": payload.get("username"),
                "permissions": payload.get("permissions", []),
                "roles": payload.get("roles", []),
                "scopes": payload.get("scopes", []),
                "authenticated_at": datetime.utcnow()
            }
            
            # Cache user info for 5 minutes
            dependency_manager.cache.set(cache_key, user_info)
            
            return user_info
            
        except JWTError as e:
            logger.error(f"JWT verification failed: {e}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication token"
            )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Authentication service error"
        )


async def get_tenant_context(
    user: Dict[str, Any] = Depends(get_authenticated_user)
) -> Tenant:
    """
    Get tenant context with caching
    """
    try:
        tenant_id = user["tenant_id"]
        if not tenant_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Tenant ID required"
            )
        
        # Check cache first
        cache_key = f"tenant:{tenant_id}"
        cached_tenant = dependency_manager.cache.get(cache_key)
        if cached_tenant:
            return cached_tenant
        
        # Get tenant from multi-tenant manager
        from src.api.security.multi_tenant import multi_tenant_manager
        tenant = await multi_tenant_manager.get_tenant(tenant_id)
        
        if not tenant:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Tenant not found"
            )
        
        if not tenant.is_active():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Tenant is not active"
            )
        
        # Cache tenant for 10 minutes
        dependency_manager.cache.set(cache_key, tenant)
        
        return tenant
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Tenant context error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Tenant service error"
        )


async def get_graph_client(
    user: Dict[str, Any] = Depends(get_authenticated_user),
    tenant: Tenant = Depends(get_tenant_context)
) -> AsyncMicrosoftGraphClient:
    """
    Get Microsoft Graph client with connection pooling
    """
    try:
        client_key = f"{tenant.id}:{user['user_id']}"
        
        # Check if client already exists
        if client_key in dependency_manager._graph_clients:
            return dependency_manager._graph_clients[client_key]
        
        # Create new client
        client = create_graph_client(
            async_mode=True,
            tenant_id=tenant.id,
            enable_caching=True,
            enable_batching=True
        )
        
        # Store in weak reference dictionary
        dependency_manager._graph_clients[client_key] = client
        
        return client
        
    except Exception as e:
        logger.error(f"Graph client creation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Microsoft Graph service error"
        )


def require_permissions(*required_permissions: str):
    """
    Dependency factory for permission-based access control
    """
    def permission_dependency(
        user: Dict[str, Any] = Depends(get_authenticated_user)
    ) -> Dict[str, Any]:
        user_permissions = set(user.get("permissions", []))
        missing_permissions = set(required_permissions) - user_permissions
        
        if missing_permissions:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Missing required permissions: {', '.join(missing_permissions)}"
            )
        
        return user
    
    return permission_dependency


def rate_limit_dependency(limit: int = 100, window: int = 3600):
    """
    Dependency factory for rate limiting
    """
    async def rate_limit_check(
        request: Request,
        user: Dict[str, Any] = Depends(get_authenticated_user)
    ):
        # Create rate limit key
        rate_key = f"rate_limit:{user['tenant_id']}:{user['user_id']}"
        
        # Check rate limit
        allowed = await dependency_manager.rate_limiter.is_allowed(
            key=rate_key,
            limit=limit,
            window=window
        )
        
        if not allowed:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Rate limit exceeded",
                headers={
                    "X-RateLimit-Limit": str(limit),
                    "X-RateLimit-Window": str(window),
                    "Retry-After": str(window)
                }
            )
        
        return True
    
    return rate_limit_check


def cache_dependency(ttl: int = 300, key_prefix: str = "api"):
    """
    Dependency factory for response caching
    """
    def cache_decorator(func: Callable):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Generate cache key
            cache_key = f"{key_prefix}:{func.__name__}:{hash(str(args) + str(kwargs))}"
            
            # Check cache
            cached_result = dependency_manager.cache.get(cache_key)
            if cached_result is not None:
                return cached_result
            
            # Execute function
            result = await func(*args, **kwargs)
            
            # Cache result
            dependency_manager.cache.set(cache_key, result)
            
            return result
        
        return wrapper
    
    return cache_decorator


async def database_session() -> AsyncGenerator[AsyncSession, None]:
    """
    Database session dependency with connection pooling
    """
    if not dependency_manager.db_session_factory:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database not available"
        )
    
    async with dependency_manager.db_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def redis_client() -> redis.Redis:
    """
    Redis client dependency
    """
    if not dependency_manager.redis_client:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Redis not available"
        )
    
    return dependency_manager.redis_client


# Advanced dependency utilities

class DependencyScope:
    """Scoped dependency container"""
    
    def __init__(self):
        self._instances: Dict[str, Any] = {}
        self._factories: Dict[str, Callable] = {}
    
    def register(self, name: str, factory: Callable):
        """Register dependency factory"""
        self._factories[name] = factory
    
    async def get(self, name: str) -> Any:
        """Get dependency instance"""
        if name not in self._instances:
            if name not in self._factories:
                raise ValueError(f"Dependency '{name}' not registered")
            
            factory = self._factories[name]
            if asyncio.iscoroutinefunction(factory):
                self._instances[name] = await factory()
            else:
                self._instances[name] = factory()
        
        return self._instances[name]
    
    def clear(self):
        """Clear all instances"""
        self._instances.clear()


@asynccontextmanager
async def dependency_scope():
    """Context manager for scoped dependencies"""
    scope = DependencyScope()
    try:
        yield scope
    finally:
        scope.clear()


# Background task dependencies

class BackgroundTaskManager:
    """Advanced background task management"""
    
    def __init__(self):
        self.tasks: List[asyncio.Task] = []
    
    def add_task(self, coro):
        """Add background task"""
        task = asyncio.create_task(coro)
        self.tasks.append(task)
        
        # Clean up completed tasks
        self.tasks = [t for t in self.tasks if not t.done()]
        
        return task
    
    async def wait_all(self, timeout: Optional[float] = None):
        """Wait for all tasks to complete"""
        if self.tasks:
            await asyncio.wait(self.tasks, timeout=timeout)
    
    def cancel_all(self):
        """Cancel all pending tasks"""
        for task in self.tasks:
            if not task.done():
                task.cancel()
        self.tasks.clear()


async def get_background_tasks() -> BackgroundTaskManager:
    """Get background task manager"""
    return BackgroundTaskManager()


# Startup dependency
async def startup_dependencies():
    """Initialize all dependencies"""
    await dependency_manager.initialize()
    logger.info("All dependencies initialized")


async def shutdown_dependencies():
    """Cleanup all dependencies"""
    await dependency_manager.close()
    logger.info("All dependencies closed")


if __name__ == "__main__":
    # Test dependencies
    import asyncio
    
    async def test_dependencies():
        """Test dependency system"""
        print("Testing AdvancedDependencyManager...")
        
        await dependency_manager.initialize()
        
        # Test cache
        dependency_manager.cache.set("test_key", "test_value")
        cached_value = dependency_manager.cache.get("test_key")
        print(f"Cache test: {cached_value}")
        
        # Test rate limiter
        allowed = await dependency_manager.rate_limiter.is_allowed("test_user", 10, 60)
        print(f"Rate limit test: {allowed}")
        
        await dependency_manager.close()
        print("Dependency test completed")
    
    asyncio.run(test_dependencies())