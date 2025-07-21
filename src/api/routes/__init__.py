"""
API Routes for Microsoft 365 Management Tools
"""

from .users import router as users_router
from .licenses import router as licenses_router
from .reports import router as reports_router
from .audit import router as audit_router
from .health import router as health_router
from .auth import router as auth_router
from .exchange import router as exchange_router
from .teams import router as teams_router
from .onedrive import router as onedrive_router
from .entra import router as entra_router
from .analytics import router as analytics_router

__all__ = [
    "users_router",
    "licenses_router", 
    "reports_router",
    "audit_router",
    "health_router",
    "auth_router",
    "exchange_router",
    "teams_router",
    "onedrive_router",
    "entra_router",
    "analytics_router"
]