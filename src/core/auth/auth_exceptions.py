"""
Authentication-related exceptions and error handling.
"""

from enum import Enum
from typing import Optional, Dict, Any


class AuthenticationError(Exception):
    """Base authentication error."""
    
    def __init__(self, message: str, error_code: Optional[str] = None,
                 error_description: Optional[str] = None,
                 details: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.error_code = error_code
        self.error_description = error_description
        self.details = details or {}


class CertificateError(AuthenticationError):
    """Certificate-related errors."""
    pass


class TokenError(AuthenticationError):
    """Token-related errors."""
    pass


class ConnectionError(AuthenticationError):
    """Connection-related errors."""
    pass


class ConfigurationError(AuthenticationError):
    """Configuration-related errors."""
    pass


class AuthErrorCode(Enum):
    """Common authentication error codes."""
    
    # Certificate errors
    CERTIFICATE_NOT_FOUND = "certificate_not_found"
    CERTIFICATE_EXPIRED = "certificate_expired"
    CERTIFICATE_INVALID = "certificate_invalid"
    CERTIFICATE_PASSWORD_WRONG = "certificate_password_wrong"
    
    # Token errors
    TOKEN_EXPIRED = "token_expired"
    TOKEN_INVALID = "token_invalid"
    TOKEN_REFRESH_FAILED = "token_refresh_failed"
    
    # Connection errors
    CONNECTION_FAILED = "connection_failed"
    CONNECTION_TIMEOUT = "connection_timeout"
    SERVICE_UNAVAILABLE = "service_unavailable"
    
    # Configuration errors
    MISSING_CONFIGURATION = "missing_configuration"
    INVALID_CONFIGURATION = "invalid_configuration"
    
    # Authentication errors
    AUTHENTICATION_FAILED = "authentication_failed"
    PERMISSION_DENIED = "permission_denied"
    INVALID_CREDENTIALS = "invalid_credentials"
    MFA_REQUIRED = "mfa_required"
    
    # Network errors
    NETWORK_ERROR = "network_error"
    DNS_ERROR = "dns_error"
    
    # Module errors
    MODULE_NOT_FOUND = "module_not_found"
    MODULE_IMPORT_FAILED = "module_import_failed"


def create_auth_error(error_code: AuthErrorCode, message: str,
                     error_description: Optional[str] = None,
                     details: Optional[Dict[str, Any]] = None) -> AuthenticationError:
    """Create appropriate authentication error based on error code."""
    
    error_type_map = {
        AuthErrorCode.CERTIFICATE_NOT_FOUND: CertificateError,
        AuthErrorCode.CERTIFICATE_EXPIRED: CertificateError,
        AuthErrorCode.CERTIFICATE_INVALID: CertificateError,
        AuthErrorCode.CERTIFICATE_PASSWORD_WRONG: CertificateError,
        
        AuthErrorCode.TOKEN_EXPIRED: TokenError,
        AuthErrorCode.TOKEN_INVALID: TokenError,
        AuthErrorCode.TOKEN_REFRESH_FAILED: TokenError,
        
        AuthErrorCode.CONNECTION_FAILED: ConnectionError,
        AuthErrorCode.CONNECTION_TIMEOUT: ConnectionError,
        AuthErrorCode.SERVICE_UNAVAILABLE: ConnectionError,
        
        AuthErrorCode.MISSING_CONFIGURATION: ConfigurationError,
        AuthErrorCode.INVALID_CONFIGURATION: ConfigurationError,
    }
    
    error_class = error_type_map.get(error_code, AuthenticationError)
    
    return error_class(
        message=message,
        error_code=error_code.value,
        error_description=error_description,
        details=details
    )