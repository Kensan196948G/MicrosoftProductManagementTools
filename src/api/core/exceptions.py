"""
Custom exceptions for Microsoft 365 Management Tools API
Production-grade error handling with comprehensive error types.
"""

from typing import Optional, Dict, Any
from fastapi import HTTPException, status


class M365Exception(Exception):
    """Base exception for Microsoft 365 Management Tools."""
    
    def __init__(
        self,
        message: str,
        error_code: str = "generic_error",
        status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR,
        details: Optional[Dict[str, Any]] = None
    ):
        self.message = message
        self.error_code = error_code
        self.status_code = status_code
        self.details = details or {}
        super().__init__(self.message)


class AuthenticationError(M365Exception):
    """Authentication related errors."""
    
    def __init__(self, message: str = "Authentication failed", details: Optional[Dict[str, Any]] = None):
        super().__init__(
            message=message,
            error_code="authentication_failed",
            status_code=status.HTTP_401_UNAUTHORIZED,
            details=details
        )


class AuthorizationError(M365Exception):
    """Authorization/permission related errors."""
    
    def __init__(self, message: str = "Insufficient permissions", details: Optional[Dict[str, Any]] = None):
        super().__init__(
            message=message,
            error_code="authorization_failed",
            status_code=status.HTTP_403_FORBIDDEN,
            details=details
        )


class ValidationError(M365Exception):
    """Data validation errors."""
    
    def __init__(self, message: str, field: Optional[str] = None, details: Optional[Dict[str, Any]] = None):
        if not details:
            details = {}
        if field:
            details["field"] = field
            
        super().__init__(
            message=message,
            error_code="validation_error",
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            details=details
        )


class NotFoundError(M365Exception):
    """Resource not found errors."""
    
    def __init__(self, message: str, resource_type: Optional[str] = None, resource_id: Optional[str] = None):
        details = {}
        if resource_type:
            details["resource_type"] = resource_type
        if resource_id:
            details["resource_id"] = resource_id
            
        super().__init__(
            message=message,
            error_code="resource_not_found",
            status_code=status.HTTP_404_NOT_FOUND,
            details=details
        )


class ConflictError(M365Exception):
    """Resource conflict errors."""
    
    def __init__(self, message: str, details: Optional[Dict[str, Any]] = None):
        super().__init__(
            message=message,
            error_code="resource_conflict",
            status_code=status.HTTP_409_CONFLICT,
            details=details
        )


class APIError(M365Exception):
    """External API related errors."""
    
    def __init__(
        self,
        message: str,
        api_name: str = "unknown",
        status_code: int = status.HTTP_502_BAD_GATEWAY,
        details: Optional[Dict[str, Any]] = None
    ):
        if not details:
            details = {}
        details["api_name"] = api_name
        
        super().__init__(
            message=message,
            error_code="external_api_error",
            status_code=status_code,
            details=details
        )


class GraphAPIError(APIError):
    """Microsoft Graph API specific errors."""
    
    def __init__(self, message: str, graph_error_code: Optional[str] = None, details: Optional[Dict[str, Any]] = None):
        if not details:
            details = {}
        if graph_error_code:
            details["graph_error_code"] = graph_error_code
            
        super().__init__(
            message=message,
            api_name="Microsoft Graph",
            details=details
        )


class ExchangeAPIError(APIError):
    """Exchange Online API specific errors."""
    
    def __init__(self, message: str, exchange_error_code: Optional[str] = None, details: Optional[Dict[str, Any]] = None):
        if not details:
            details = {}
        if exchange_error_code:
            details["exchange_error_code"] = exchange_error_code
            
        super().__init__(
            message=message,
            api_name="Exchange Online",
            details=details
        )


class RateLimitError(M365Exception):
    """Rate limiting errors."""
    
    def __init__(self, message: str = "Rate limit exceeded", retry_after: Optional[int] = None):
        details = {}
        if retry_after:
            details["retry_after"] = retry_after
            
        super().__init__(
            message=message,
            error_code="rate_limit_exceeded",
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            details=details
        )


class ConfigurationError(M365Exception):
    """Configuration related errors."""
    
    def __init__(self, message: str, config_key: Optional[str] = None):
        details = {}
        if config_key:
            details["config_key"] = config_key
            
        super().__init__(
            message=message,
            error_code="configuration_error",
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            details=details
        )


class DatabaseError(M365Exception):
    """Database related errors."""
    
    def __init__(self, message: str, operation: Optional[str] = None, details: Optional[Dict[str, Any]] = None):
        if not details:
            details = {}
        if operation:
            details["operation"] = operation
            
        super().__init__(
            message=message,
            error_code="database_error",
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            details=details
        )


class ServiceUnavailableError(M365Exception):
    """Service unavailable errors."""
    
    def __init__(self, message: str = "Service temporarily unavailable", service_name: Optional[str] = None):
        details = {}
        if service_name:
            details["service_name"] = service_name
            
        super().__init__(
            message=message,
            error_code="service_unavailable",
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            details=details
        )


class TimeoutError(M365Exception):
    """Timeout related errors."""
    
    def __init__(self, message: str = "Operation timed out", timeout_seconds: Optional[int] = None):
        details = {}
        if timeout_seconds:
            details["timeout_seconds"] = timeout_seconds
            
        super().__init__(
            message=message,
            error_code="operation_timeout",
            status_code=status.HTTP_408_REQUEST_TIMEOUT,
            details=details
        )


class BusinessLogicError(M365Exception):
    """Business logic validation errors."""
    
    def __init__(self, message: str, rule: Optional[str] = None, details: Optional[Dict[str, Any]] = None):
        if not details:
            details = {}
        if rule:
            details["business_rule"] = rule
            
        super().__init__(
            message=message,
            error_code="business_logic_error",
            status_code=status.HTTP_400_BAD_REQUEST,
            details=details
        )


# Exception mapping for common scenarios
EXCEPTION_MAPPING = {
    "authentication": AuthenticationError,
    "authorization": AuthorizationError,
    "validation": ValidationError,
    "not_found": NotFoundError,
    "conflict": ConflictError,
    "api_error": APIError,
    "graph_api": GraphAPIError,
    "exchange_api": ExchangeAPIError,
    "rate_limit": RateLimitError,
    "configuration": ConfigurationError,
    "database": DatabaseError,
    "service_unavailable": ServiceUnavailableError,
    "timeout": TimeoutError,
    "business_logic": BusinessLogicError
}


def get_exception_class(exception_type: str) -> type:
    """Get exception class by type string."""
    return EXCEPTION_MAPPING.get(exception_type, M365Exception)


def create_exception(exception_type: str, message: str, **kwargs) -> M365Exception:
    """Create exception instance by type."""
    exception_class = get_exception_class(exception_type)
    return exception_class(message, **kwargs)