"""
Advanced Dependency Injection - Phase 3 FastAPI 0.115.12
Enterprise-grade dependency system with advanced features
"""

from .advanced_dependencies import (
    AdvancedDependencyManager,
    get_tenant_context,
    get_graph_client,
    get_authenticated_user,
    require_permissions,
    rate_limit_dependency,
    cache_dependency,
    database_session,
    redis_client,
    get_request_context
)

from .context_managers import (
    RequestContextManager,
    TenantContextManager,
    GraphContextManager
)

from .performance_dependencies import (
    StreamingResponseDependency,
    CachingDependency,
    ConnectionPoolDependency
)

__all__ = [
    "AdvancedDependencyManager",
    "get_tenant_context",
    "get_graph_client", 
    "get_authenticated_user",
    "require_permissions",
    "rate_limit_dependency",
    "cache_dependency",
    "database_session",
    "redis_client",
    "get_request_context",
    "RequestContextManager",
    "TenantContextManager", 
    "GraphContextManager",
    "StreamingResponseDependency",
    "CachingDependency",
    "ConnectionPoolDependency"
]