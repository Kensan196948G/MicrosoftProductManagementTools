#!/usr/bin/env python3
"""
OAuth2 Scopes and Security - Phase 3 Advanced Integration
Advanced OAuth2 flows with Microsoft Graph scopes
"""

import logging
from typing import List, Optional, Dict, Any, Set
from enum import Enum
from dataclasses import dataclass, field

from fastapi import Depends, HTTPException, status
from fastapi.security import SecurityScopes, OAuth2AuthorizationCodeBearer
from fastapi.security.utils import get_authorization_scheme_param
from starlette.requests import Request
from jose import JWTError, jwt

from src.core.config import get_settings

logger = logging.getLogger(__name__)


class OAuth2Scopes:
    """Microsoft Graph OAuth2 scopes"""
    
    # User scopes
    USER_READ = "User.Read"
    USER_READ_ALL = "User.Read.All"
    USER_READWRITE = "User.ReadWrite"
    USER_READWRITE_ALL = "User.ReadWrite.All"
    USER_INVITE_ALL = "User.Invite.All"
    
    # Group scopes
    GROUP_READ_ALL = "Group.Read.All"
    GROUP_READWRITE_ALL = "Group.ReadWrite.All"
    GROUP_CREATE = "Group.Create"
    
    # Directory scopes
    DIRECTORY_READ_ALL = "Directory.Read.All"
    DIRECTORY_READWRITE_ALL = "Directory.ReadWrite.All"
    DIRECTORY_ACCESSASUSER_ALL = "Directory.AccessAsUser.All"
    
    # Mail scopes
    MAIL_READ = "Mail.Read"
    MAIL_READWRITE = "Mail.ReadWrite"
    MAIL_SEND = "Mail.Send"
    
    # Calendar scopes
    CALENDARS_READ = "Calendars.Read"
    CALENDARS_READWRITE = "Calendars.ReadWrite"
    
    # Files scopes
    FILES_READ = "Files.Read"
    FILES_READWRITE = "Files.ReadWrite"
    FILES_READ_ALL = "Files.Read.All"
    FILES_READWRITE_ALL = "Files.ReadWrite.All"
    
    # Teams scopes
    TEAM_READBASIC_ALL = "Team.ReadBasic.All"
    TEAMWORK_MIGRATE_ALL = "Teamwork.Migrate.All"
    CHANNEL_MESSAGE_READ_ALL = "ChannelMessage.Read.All"
    
    # Reports scopes
    REPORTS_READ_ALL = "Reports.Read.All"
    
    # Security scopes
    SECURITY_EVENTS_READ_ALL = "SecurityEvents.Read.All"
    SECURITY_EVENTS_READWRITE_ALL = "SecurityEvents.ReadWrite.All"
    
    # Audit logs
    AUDITLOG_READ_ALL = "AuditLog.Read.All"
    
    # Application scopes
    APPLICATION_READ_ALL = "Application.Read.All"
    APPLICATION_READWRITE_ALL = "Application.ReadWrite.All"
    
    @classmethod
    def get_all_scopes(cls) -> List[str]:
        """Get all available scopes"""
        return [
            value for name, value in cls.__dict__.items()
            if isinstance(value, str) and not name.startswith('_')
        ]
    
    @classmethod
    def get_read_scopes(cls) -> List[str]:
        """Get read-only scopes"""
        all_scopes = cls.get_all_scopes()
        return [scope for scope in all_scopes if '.Read' in scope and '.ReadWrite' not in scope]
    
    @classmethod
    def get_write_scopes(cls) -> List[str]:
        """Get write scopes"""
        all_scopes = cls.get_all_scopes()
        return [scope for scope in all_scopes if any(x in scope for x in ['.ReadWrite', '.Create', '.Send'])]


class PermissionLevel(str, Enum):
    """Permission levels"""
    READ = "read"
    WRITE = "write"
    DELETE = "delete"
    ADMIN = "admin"


@dataclass
class ScopePermission:
    """Scope permission mapping"""
    scope: str
    resource: str
    level: PermissionLevel
    description: str = ""


class ScopeMapper:
    """Maps OAuth2 scopes to application permissions"""
    
    SCOPE_PERMISSIONS = [
        # User permissions
        ScopePermission(OAuth2Scopes.USER_READ, "user", PermissionLevel.READ, "Read own user profile"),
        ScopePermission(OAuth2Scopes.USER_READ_ALL, "users", PermissionLevel.READ, "Read all user profiles"),
        ScopePermission(OAuth2Scopes.USER_READWRITE, "user", PermissionLevel.WRITE, "Read and write own user profile"),
        ScopePermission(OAuth2Scopes.USER_READWRITE_ALL, "users", PermissionLevel.WRITE, "Read and write all user profiles"),
        ScopePermission(OAuth2Scopes.USER_INVITE_ALL, "users", PermissionLevel.ADMIN, "Invite users"),
        
        # Group permissions
        ScopePermission(OAuth2Scopes.GROUP_READ_ALL, "groups", PermissionLevel.READ, "Read all groups"),
        ScopePermission(OAuth2Scopes.GROUP_READWRITE_ALL, "groups", PermissionLevel.WRITE, "Read and write all groups"),
        ScopePermission(OAuth2Scopes.GROUP_CREATE, "groups", PermissionLevel.ADMIN, "Create groups"),
        
        # Directory permissions
        ScopePermission(OAuth2Scopes.DIRECTORY_READ_ALL, "directory", PermissionLevel.READ, "Read directory data"),
        ScopePermission(OAuth2Scopes.DIRECTORY_READWRITE_ALL, "directory", PermissionLevel.WRITE, "Read and write directory data"),
        ScopePermission(OAuth2Scopes.DIRECTORY_ACCESSASUSER_ALL, "directory", PermissionLevel.ADMIN, "Access directory as user"),
        
        # Mail permissions
        ScopePermission(OAuth2Scopes.MAIL_READ, "mail", PermissionLevel.READ, "Read user's mail"),
        ScopePermission(OAuth2Scopes.MAIL_READWRITE, "mail", PermissionLevel.WRITE, "Read and write user's mail"),
        ScopePermission(OAuth2Scopes.MAIL_SEND, "mail", PermissionLevel.ADMIN, "Send mail as user"),
        
        # Calendar permissions
        ScopePermission(OAuth2Scopes.CALENDARS_READ, "calendar", PermissionLevel.READ, "Read user's calendar"),
        ScopePermission(OAuth2Scopes.CALENDARS_READWRITE, "calendar", PermissionLevel.WRITE, "Read and write user's calendar"),
        
        # Files permissions
        ScopePermission(OAuth2Scopes.FILES_READ, "files", PermissionLevel.READ, "Read user's files"),
        ScopePermission(OAuth2Scopes.FILES_READWRITE, "files", PermissionLevel.WRITE, "Read and write user's files"),
        ScopePermission(OAuth2Scopes.FILES_READ_ALL, "files", PermissionLevel.READ, "Read all files"),
        ScopePermission(OAuth2Scopes.FILES_READWRITE_ALL, "files", PermissionLevel.WRITE, "Read and write all files"),
        
        # Teams permissions
        ScopePermission(OAuth2Scopes.TEAM_READBASIC_ALL, "teams", PermissionLevel.READ, "Read basic team info"),
        ScopePermission(OAuth2Scopes.TEAMWORK_MIGRATE_ALL, "teams", PermissionLevel.ADMIN, "Migrate teams data"),
        ScopePermission(OAuth2Scopes.CHANNEL_MESSAGE_READ_ALL, "teams", PermissionLevel.READ, "Read channel messages"),
        
        # Reports permissions
        ScopePermission(OAuth2Scopes.REPORTS_READ_ALL, "reports", PermissionLevel.READ, "Read usage reports"),
        
        # Security permissions
        ScopePermission(OAuth2Scopes.SECURITY_EVENTS_READ_ALL, "security", PermissionLevel.READ, "Read security events"),
        ScopePermission(OAuth2Scopes.SECURITY_EVENTS_READWRITE_ALL, "security", PermissionLevel.WRITE, "Read and write security events"),
        
        # Audit log permissions
        ScopePermission(OAuth2Scopes.AUDITLOG_READ_ALL, "auditlog", PermissionLevel.READ, "Read audit logs"),
        
        # Application permissions
        ScopePermission(OAuth2Scopes.APPLICATION_READ_ALL, "applications", PermissionLevel.READ, "Read applications"),
        ScopePermission(OAuth2Scopes.APPLICATION_READWRITE_ALL, "applications", PermissionLevel.WRITE, "Read and write applications"),
    ]
    
    @classmethod
    def get_permissions_for_scopes(cls, scopes: List[str]) -> Set[str]:
        """
        Get application permissions for OAuth2 scopes
        
        Args:
            scopes: List of OAuth2 scopes
            
        Returns:
            Set of application permissions
        """
        permissions = set()
        
        for scope in scopes:
            for scope_permission in cls.SCOPE_PERMISSIONS:
                if scope_permission.scope == scope:
                    permission = f"{scope_permission.resource}.{scope_permission.level.value}"
                    permissions.add(permission)
        
        return permissions
    
    @classmethod
    def get_required_scopes_for_permission(cls, permission: str) -> List[str]:
        """
        Get required OAuth2 scopes for application permission
        
        Args:
            permission: Application permission (e.g., "users.read")
            
        Returns:
            List of required OAuth2 scopes
        """
        try:
            resource, level = permission.split('.', 1)
            permission_level = PermissionLevel(level)
            
            scopes = []
            for scope_permission in cls.SCOPE_PERMISSIONS:
                if (scope_permission.resource == resource and 
                    scope_permission.level == permission_level):
                    scopes.append(scope_permission.scope)
            
            return scopes
            
        except (ValueError, AttributeError):
            logger.warning(f"Invalid permission format: {permission}")
            return []


class OAuth2AuthorizationCodeBearerWithScopes(OAuth2AuthorizationCodeBearer):
    """Enhanced OAuth2 bearer with scope validation"""
    
    def __init__(self, 
                 authorization_url: str,
                 token_url: str,
                 scopes: Dict[str, str] = None,
                 scheme_name: Optional[str] = None,
                 auto_error: bool = True):
        super().__init__(
            authorization_url=authorization_url,
            token_url=token_url,
            scopes=scopes or {},
            scheme_name=scheme_name,
            auto_error=auto_error
        )
    
    async def __call__(self, request: Request, security_scopes: SecurityScopes) -> Optional[str]:
        """Extract and validate token with scopes"""
        authorization = request.headers.get("Authorization")
        scheme, credentials = get_authorization_scheme_param(authorization)
        
        if not authorization or scheme.lower() != "bearer":
            if self.auto_error:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Not authenticated",
                    headers={"WWW-Authenticate": "Bearer"},
                )
            else:
                return None
        
        return credentials


# OAuth2 scheme with Microsoft Graph scopes
oauth2_scheme = OAuth2AuthorizationCodeBearerWithScopes(
    authorization_url="https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
    token_url="https://login.microsoftonline.com/common/oauth2/v2.0/token",
    scopes={
        OAuth2Scopes.USER_READ: "Read user profile",
        OAuth2Scopes.USER_READ_ALL: "Read all user profiles",
        OAuth2Scopes.GROUP_READ_ALL: "Read all groups",
        OAuth2Scopes.DIRECTORY_READ_ALL: "Read directory data",
        OAuth2Scopes.MAIL_READ: "Read user's mail",
        OAuth2Scopes.CALENDARS_READ: "Read user's calendar",
        OAuth2Scopes.FILES_READ: "Read user's files",
        OAuth2Scopes.REPORTS_READ_ALL: "Read usage reports",
    }
)


async def get_current_user_with_scopes(
    security_scopes: SecurityScopes,
    token: str = Depends(oauth2_scheme)
) -> Dict[str, Any]:
    """
    Get current user with scope validation
    
    Args:
        security_scopes: Required security scopes
        token: JWT token
        
    Returns:
        User information with validated scopes
        
    Raises:
        HTTPException: If authentication or authorization fails
    """
    # Build authentication exception
    if security_scopes.scopes:
        authenticate_value = f'Bearer scope="{security_scopes.scope_str}"'
    else:
        authenticate_value = "Bearer"
    
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": authenticate_value},
    )
    
    try:
        # Decode JWT token
        settings = get_settings()
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
        
        # Get token scopes
        token_scopes = payload.get("scopes", [])
        if isinstance(token_scopes, str):
            token_scopes = token_scopes.split()
        
        # Validate required scopes
        for scope in security_scopes.scopes:
            if scope not in token_scopes:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Not enough permissions",
                    headers={"WWW-Authenticate": authenticate_value},
                )
        
        # Get application permissions from scopes
        permissions = ScopeMapper.get_permissions_for_scopes(token_scopes)
        
        return {
            "user_id": user_id,
            "tenant_id": payload.get("tenant_id"),
            "username": payload.get("username"),
            "scopes": token_scopes,
            "permissions": list(permissions),
            "roles": payload.get("roles", [])
        }
        
    except JWTError:
        raise credentials_exception


def require_scopes(*scopes: str):
    """
    Decorator to require specific OAuth2 scopes
    
    Args:
        *scopes: Required OAuth2 scopes
        
    Returns:
        Dependency function
    """
    def dependency(
        current_user: Dict[str, Any] = Depends(get_current_user_with_scopes),
        security_scopes: SecurityScopes = SecurityScopes(scopes=list(scopes))
    ):
        return current_user
    
    return dependency


def require_permissions(*permissions: str):
    """
    Decorator to require specific application permissions
    
    Args:
        *permissions: Required application permissions
        
    Returns:
        Dependency function
    """
    def dependency(current_user: Dict[str, Any] = Depends(get_current_user_with_scopes)):
        user_permissions = set(current_user.get("permissions", []))
        required_permissions = set(permissions)
        
        if not required_permissions.issubset(user_permissions):
            missing_permissions = required_permissions - user_permissions
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Missing required permissions: {', '.join(missing_permissions)}"
            )
        
        return current_user
    
    return dependency


class ScopeChecker:
    """Helper class for scope validation"""
    
    @staticmethod
    def has_scope(user_scopes: List[str], required_scope: str) -> bool:
        """Check if user has required scope"""
        return required_scope in user_scopes
    
    @staticmethod
    def has_any_scope(user_scopes: List[str], required_scopes: List[str]) -> bool:
        """Check if user has any of the required scopes"""
        return any(scope in user_scopes for scope in required_scopes)
    
    @staticmethod
    def has_all_scopes(user_scopes: List[str], required_scopes: List[str]) -> bool:
        """Check if user has all required scopes"""
        return all(scope in user_scopes for scope in required_scopes)
    
    @staticmethod
    def can_access_resource(user_scopes: List[str], resource: str, action: str) -> bool:
        """
        Check if user can access resource with specific action
        
        Args:
            user_scopes: User's OAuth2 scopes
            resource: Resource type (users, groups, etc.)
            action: Action type (read, write, delete)
            
        Returns:
            True if user can access resource
        """
        permissions = ScopeMapper.get_permissions_for_scopes(user_scopes)
        required_permission = f"{resource}.{action}"
        
        # Check exact permission
        if required_permission in permissions:
            return True
        
        # Check admin permission
        admin_permission = f"{resource}.admin"
        if admin_permission in permissions:
            return True
        
        # Check write permission for read actions
        if action == "read":
            write_permission = f"{resource}.write"
            if write_permission in permissions:
                return True
        
        return False


if __name__ == "__main__":
    # Test OAuth2 scopes
    print("OAuth2 Scopes and Security configuration loaded")
    print(f"Available scopes: {len(OAuth2Scopes.get_all_scopes())}")
    print(f"Read scopes: {len(OAuth2Scopes.get_read_scopes())}")
    print(f"Write scopes: {len(OAuth2Scopes.get_write_scopes())}")
    
    # Test scope mapping
    test_scopes = [OAuth2Scopes.USER_READ_ALL, OAuth2Scopes.GROUP_READ_ALL]
    permissions = ScopeMapper.get_permissions_for_scopes(test_scopes)
    print(f"Permissions for test scopes: {permissions}")
    
    # Test scope checker
    can_read_users = ScopeChecker.can_access_resource(test_scopes, "users", "read")
    print(f"Can read users: {can_read_users}")