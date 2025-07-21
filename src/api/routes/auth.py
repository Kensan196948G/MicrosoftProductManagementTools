"""
Authentication API Router - Microsoft 365 Authentication
Provides authentication endpoints for the API.
"""

from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPBearer
from typing import Dict, Any
from datetime import datetime
import logging

from ..core.auth import AuthManager, get_auth_manager
from ..dependencies.advanced_dependencies import get_authenticated_user

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
    responses={
        401: {"description": "Authentication failed"},
        403: {"description": "Authorization failed"}
    }
)

@router.get("/me", summary="Get current user info")
async def get_current_user_info(
    current_user: Dict[str, Any] = Depends(get_authenticated_user)
):
    """Get information about the currently authenticated user."""
    return {
        "user_id": current_user.get("user_id"),
        "username": current_user.get("username"),
        "tenant_id": current_user.get("tenant_id"),
        "permissions": current_user.get("permissions", []),
        "roles": current_user.get("roles", []),
        "authenticated_at": current_user.get("authenticated_at")
    }

@router.get("/permissions", summary="Get user permissions")
async def get_user_permissions(
    current_user: Dict[str, Any] = Depends(get_authenticated_user)
):
    """Get detailed permissions for the current user."""
    return {
        "permissions": current_user.get("permissions", []),
        "roles": current_user.get("roles", []),
        "scopes": current_user.get("scopes", [])
    }

@router.post("/validate", summary="Validate token")
async def validate_token(
    auth_manager: AuthManager = Depends(get_auth_manager),
    current_user: Dict[str, Any] = Depends(get_authenticated_user)
):
    """Validate the current authentication token."""
    return {
        "valid": True,
        "user_id": current_user.get("user_id"),
        "expires_at": current_user.get("expires_at"),
        "timestamp": datetime.utcnow().isoformat()
    }