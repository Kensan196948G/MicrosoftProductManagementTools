"""
Security Module - Phase 3 Advanced Integration
Multi-tenant security with OAuth2 and advanced authentication
"""

from .multi_tenant import MultiTenantManager
from .oauth2_scopes import OAuth2Scopes, SecurityScopes
from .permissions import PermissionManager, Permission
from .auth_middleware import AuthMiddleware

__all__ = [
    "MultiTenantManager",
    "OAuth2Scopes", 
    "SecurityScopes",
    "PermissionManager",
    "Permission",
    "AuthMiddleware"
]