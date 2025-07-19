"""
Enterprise Security Manager for Microsoft 365 Management Tools.
Implements comprehensive security controls and monitoring.
"""

import os
import logging
import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from pathlib import Path
import json

from src.security.data_sanitizer import DataSanitizer, sanitize_for_logging


class SecurityManager:
    """
    Enterprise security manager implementing defense-in-depth strategy.
    Compliant with ISO/IEC 27001, 27002, and ITSM security requirements.
    """
    
    # Security configuration
    SECURE_FILE_PERMISSIONS = 0o600  # Owner read/write only
    SECURE_DIR_PERMISSIONS = 0o700   # Owner read/write/execute only
    
    # Rate limiting configuration
    MAX_API_CALLS_PER_MINUTE = 60
    MAX_LOGIN_ATTEMPTS = 3
    LOCKOUT_DURATION_MINUTES = 15
    
    def __init__(self, config_path: Optional[Path] = None):
        """
        Initialize security manager.
        
        Args:
            config_path: Path to security configuration file
        """
        self.logger = logging.getLogger(__name__)
        self.sanitizer = DataSanitizer()
        
        # Security state tracking
        self._api_call_counts: Dict[str, List[datetime]] = {}
        self._login_attempts: Dict[str, List[datetime]] = {}
        self._blocked_users: Dict[str, datetime] = {}
        
        # Load security configuration
        self.config = self._load_security_config(config_path)
        
        # Initialize security audit log
        self._init_audit_log()
    
    def _load_security_config(self, config_path: Optional[Path]) -> Dict[str, Any]:
        """Load security configuration."""
        default_config = {
            "enable_audit_logging": True,
            "enable_intrusion_detection": True,
            "enable_data_sanitization": True,
            "token_cache_expiry_hours": 1,
            "certificate_validation": True,
            "require_secure_transport": True,
            "max_log_file_size_mb": 50,
            "log_retention_days": 365,
            "security_scan_interval_hours": 24
        }
        
        if config_path and config_path.exists():
            try:
                with open(config_path, 'r') as f:
                    user_config = json.load(f)
                default_config.update(user_config)
            except Exception as e:
                self.logger.warning(f"Failed to load security config: {e}")
        
        return default_config
    
    def _init_audit_log(self):
        """Initialize security audit logging."""
        audit_log_path = Path("Logs/security_audit.log")
        audit_log_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Set secure permissions for audit log
        self._set_secure_permissions(audit_log_path)
        
        # Configure audit logger
        audit_logger = logging.getLogger("security_audit")
        if not audit_logger.handlers:
            handler = logging.FileHandler(audit_log_path)
            formatter = logging.Formatter(
                '%(asctime)s - SECURITY_AUDIT - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            audit_logger.addHandler(handler)
            audit_logger.setLevel(logging.INFO)
    
    def _set_secure_permissions(self, file_path: Path):
        """Set secure file permissions."""
        try:
            if file_path.exists():
                os.chmod(file_path, self.SECURE_FILE_PERMISSIONS)
            
            # Also secure parent directory
            if file_path.parent.exists():
                os.chmod(file_path.parent, self.SECURE_DIR_PERMISSIONS)
                
        except Exception as e:
            self.logger.warning(f"Failed to set secure permissions: {e}")
    
    def validate_certificate_security(self, cert_path: str, thumbprint: str) -> bool:
        """
        Validate certificate security properties.
        
        Args:
            cert_path: Path to certificate file
            thumbprint: Certificate thumbprint to validate
            
        Returns:
            True if certificate passes security validation
        """
        try:
            cert_file = Path(cert_path)
            
            # Check if certificate file exists
            if not cert_file.exists():
                self._log_security_event("CERT_NOT_FOUND", f"Certificate file not found: {cert_path}")
                return False
            
            # Check file permissions
            file_stat = cert_file.stat()
            file_mode = file_stat.st_mode & 0o777
            
            if file_mode != self.SECURE_FILE_PERMISSIONS:
                self._log_security_event(
                    "CERT_INSECURE_PERMISSIONS", 
                    f"Certificate has insecure permissions: {oct(file_mode)}"
                )
                # Attempt to fix permissions
                os.chmod(cert_file, self.SECURE_FILE_PERMISSIONS)
            
            # Validate thumbprint format
            if not self._is_valid_thumbprint(thumbprint):
                self._log_security_event("CERT_INVALID_THUMBPRINT", "Invalid certificate thumbprint format")
                return False
            
            # Additional certificate validation could be added here
            # (e.g., expiration check, issuer validation, etc.)
            
            self._log_security_event("CERT_VALIDATED", "Certificate security validation passed")
            return True
            
        except Exception as e:
            self._log_security_event("CERT_VALIDATION_ERROR", f"Certificate validation error: {e}")
            return False
    
    def _is_valid_thumbprint(self, thumbprint: str) -> bool:
        """Validate certificate thumbprint format."""
        import re
        # SHA-1 thumbprint should be 40 hex characters
        pattern = r'^[A-Fa-f0-9]{40}$'
        return bool(re.match(pattern, thumbprint.replace(' ', '').replace(':', '')))
    
    def check_rate_limits(self, user_id: str, operation: str) -> bool:
        """
        Check if user is within rate limits.
        
        Args:
            user_id: User identifier
            operation: Operation being performed
            
        Returns:
            True if within limits, False if rate limited
        """
        now = datetime.now()
        key = f"{user_id}:{operation}"
        
        # Clean old entries (older than 1 minute)
        if key in self._api_call_counts:
            self._api_call_counts[key] = [
                call_time for call_time in self._api_call_counts[key]
                if now - call_time < timedelta(minutes=1)
            ]
        else:
            self._api_call_counts[key] = []
        
        # Check if user is blocked
        if user_id in self._blocked_users:
            if now - self._blocked_users[user_id] < timedelta(minutes=self.LOCKOUT_DURATION_MINUTES):
                self._log_security_event("RATE_LIMIT_BLOCKED", f"User {user_id} is blocked")
                return False
            else:
                # Unblock user
                del self._blocked_users[user_id]
        
        # Check current rate
        current_count = len(self._api_call_counts[key])
        if current_count >= self.MAX_API_CALLS_PER_MINUTE:
            self._blocked_users[user_id] = now
            self._log_security_event(
                "RATE_LIMIT_EXCEEDED", 
                f"User {user_id} exceeded rate limit for {operation}"
            )
            return False
        
        # Record this call
        self._api_call_counts[key].append(now)
        return True
    
    def track_authentication_attempt(self, user_id: str, success: bool, source_ip: str = "unknown"):
        """
        Track authentication attempts for intrusion detection.
        
        Args:
            user_id: User identifier
            success: Whether authentication was successful
            source_ip: Source IP address
        """
        now = datetime.now()
        
        if success:
            # Clear failed attempts on successful login
            if user_id in self._login_attempts:
                del self._login_attempts[user_id]
            
            self._log_security_event(
                "AUTH_SUCCESS", 
                f"Successful authentication for user {user_id} from {source_ip}"
            )
        else:
            # Track failed attempts
            if user_id not in self._login_attempts:
                self._login_attempts[user_id] = []
            
            # Clean old attempts (older than 1 hour)
            self._login_attempts[user_id] = [
                attempt_time for attempt_time in self._login_attempts[user_id]
                if now - attempt_time < timedelta(hours=1)
            ]
            
            self._login_attempts[user_id].append(now)
            
            # Check if user should be blocked
            if len(self._login_attempts[user_id]) >= self.MAX_LOGIN_ATTEMPTS:
                self._blocked_users[user_id] = now
                self._log_security_event(
                    "AUTH_FAILURE_LOCKOUT", 
                    f"User {user_id} locked out after {self.MAX_LOGIN_ATTEMPTS} failed attempts from {source_ip}"
                )
            else:
                self._log_security_event(
                    "AUTH_FAILURE", 
                    f"Failed authentication for user {user_id} from {source_ip}"
                )
    
    def sanitize_sensitive_data(self, data: Any) -> Any:
        """
        Sanitize sensitive data using the data sanitizer.
        
        Args:
            data: Data to sanitize
            
        Returns:
            Sanitized data
        """
        return sanitize_for_logging(data)
    
    def create_secure_token_cache_path(self, user_id: str) -> Path:
        """
        Create secure path for token cache.
        
        Args:
            user_id: User identifier
            
        Returns:
            Secure path for token cache
        """
        # Create user-specific cache directory
        cache_dir = Path.home() / ".m365_cache" / hashlib.sha256(user_id.encode()).hexdigest()[:16]
        cache_dir.mkdir(parents=True, exist_ok=True, mode=self.SECURE_DIR_PERMISSIONS)
        
        # Set secure permissions
        os.chmod(cache_dir, self.SECURE_DIR_PERMISSIONS)
        
        cache_file = cache_dir / "token_cache.json"
        return cache_file
    
    def validate_api_endpoint(self, endpoint: str) -> bool:
        """
        Validate API endpoint for security.
        
        Args:
            endpoint: API endpoint to validate
            
        Returns:
            True if endpoint is safe
        """
        # Whitelist of allowed endpoints
        allowed_endpoints = [
            "https://graph.microsoft.com",
            "https://login.microsoftonline.com",
            "https://outlook.office365.com"
        ]
        
        # Check if endpoint starts with an allowed base
        for allowed in allowed_endpoints:
            if endpoint.startswith(allowed):
                return True
        
        self._log_security_event("INVALID_ENDPOINT", f"Blocked access to invalid endpoint: {endpoint}")
        return False
    
    def _log_security_event(self, event_type: str, message: str, level: str = "INFO"):
        """Log security events to audit log."""
        audit_logger = logging.getLogger("security_audit")
        
        # Sanitize the message
        sanitized_message = self.sanitizer.sanitize_log_entry(message)
        
        log_entry = f"[{event_type}] {sanitized_message}"
        
        if level == "WARNING":
            audit_logger.warning(log_entry)
        elif level == "ERROR":
            audit_logger.error(log_entry)
        elif level == "CRITICAL":
            audit_logger.critical(log_entry)
        else:
            audit_logger.info(log_entry)
    
    def get_security_metrics(self) -> Dict[str, Any]:
        """
        Get current security metrics.
        
        Returns:
            Dictionary containing security metrics
        """
        now = datetime.now()
        
        # Count active rate limits
        active_rate_limits = len([
            calls for calls in self._api_call_counts.values()
            if any(now - call_time < timedelta(minutes=1) for call_time in calls)
        ])
        
        # Count blocked users
        blocked_users = len([
            block_time for block_time in self._blocked_users.values()
            if now - block_time < timedelta(minutes=self.LOCKOUT_DURATION_MINUTES)
        ])
        
        # Count recent failed logins
        recent_failures = sum(
            len([
                attempt for attempt in attempts
                if now - attempt < timedelta(hours=1)
            ])
            for attempts in self._login_attempts.values()
        )
        
        return {
            "active_rate_limits": active_rate_limits,
            "blocked_users": blocked_users,
            "recent_failed_logins": recent_failures,
            "security_config": self.config,
            "last_updated": now.isoformat()
        }


# Global security manager instance
_security_manager = None


def get_security_manager() -> SecurityManager:
    """Get global security manager instance."""
    global _security_manager
    if _security_manager is None:
        _security_manager = SecurityManager()
    return _security_manager


def validate_certificate_security(cert_path: str, thumbprint: str) -> bool:
    """Convenience function to validate certificate security."""
    return get_security_manager().validate_certificate_security(cert_path, thumbprint)


def check_rate_limits(user_id: str, operation: str) -> bool:
    """Convenience function to check rate limits."""
    return get_security_manager().check_rate_limits(user_id, operation)


def track_auth_attempt(user_id: str, success: bool, source_ip: str = "unknown"):
    """Convenience function to track authentication attempts."""
    return get_security_manager().track_authentication_attempt(user_id, success, source_ip)