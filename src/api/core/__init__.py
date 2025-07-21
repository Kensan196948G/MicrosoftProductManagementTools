"""
Core API components for Microsoft 365 Management Tools
"""

from .exceptions import *
from .auth import AuthManager, get_auth_manager
from .database import DatabaseManager, get_db_manager

__all__ = [
    "AuthManager",
    "get_auth_manager", 
    "DatabaseManager",
    "get_db_manager",
    "M365Exception",
    "AuthenticationError",
    "ValidationError",
    "NotFoundError"
]