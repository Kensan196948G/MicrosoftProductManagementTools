"""
Data sanitizer for Microsoft 365 Management Tools.
Prevents sensitive information leakage in logs, outputs, and error messages.
"""

import re
import logging
from typing import Any, Dict, List, Union, Optional


class DataSanitizer:
    """
    Enterprise-grade data sanitizer to prevent sensitive information exposure.
    Compliant with ISO/IEC 27001 and 27002 security standards.
    """
    
    # Sensitive patterns to redact
    SENSITIVE_PATTERNS = {
        'certificate_thumbprint': r'[A-Fa-f0-9]{40}',
        'guid': r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
        'access_token': r'eyJ[A-Za-z0-9_-]{100,}',
        'bearer_token': r'Bearer\s+[A-Za-z0-9._-]+',
        'client_secret': r'[A-Za-z0-9~._-]{34,}',
        'password': r'(?i)(password|pwd|pass)\s*[:=]\s*[^\s,}\]]+',
        'api_key': r'(?i)(api[_-]?key|apikey)\s*[:=]\s*[^\s,}\]]+',
        'connection_string': r'(?i)(server|data\s+source)\s*=.*?(?:;|$)',
        'email_pattern': r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
        'ip_address': r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b',
        'correlation_id': r'(?i)correlation[_-]?id\s*[:=]\s*[a-fA-F0-9-]{32,}',
        'tenant_id': r'(?i)tenant[_-]?id\s*[:=]\s*[a-fA-F0-9-]{32,}',
        'client_id': r'(?i)client[_-]?id\s*[:=]\s*[a-fA-F0-9-]{32,}',
    }
    
    # Known sensitive certificate thumbprints (for immediate blocking)
    KNOWN_SENSITIVE_THUMBPRINTS = {
        '94B6BAF7E9E459F2280F665CA5B6F17AC554A7E6',  # From appsettings.json
    }
    
    def __init__(self, mask_char: str = '*', preserve_prefix: int = 4, preserve_suffix: int = 4):
        """
        Initialize sanitizer.
        
        Args:
            mask_char: Character to use for masking
            preserve_prefix: Number of characters to preserve at start
            preserve_suffix: Number of characters to preserve at end
        """
        self.mask_char = mask_char
        self.preserve_prefix = preserve_prefix
        self.preserve_suffix = preserve_suffix
        self.logger = logging.getLogger(__name__)
    
    def sanitize_text(self, text: str, complete_redaction: bool = False) -> str:
        """
        Sanitize text by replacing sensitive patterns.
        
        Args:
            text: Text to sanitize
            complete_redaction: If True, completely redact instead of partial masking
            
        Returns:
            Sanitized text
        """
        if not text or not isinstance(text, str):
            return text
        
        sanitized = text
        
        # Check for known sensitive thumbprints first (complete redaction)
        for thumbprint in self.KNOWN_SENSITIVE_THUMBPRINTS:
            if thumbprint in sanitized:
                sanitized = sanitized.replace(thumbprint, '[REDACTED_THUMBPRINT]')
                self.logger.warning("🚨 SECURITY: Known sensitive thumbprint detected and redacted")
        
        # Apply pattern-based sanitization
        for pattern_name, pattern in self.SENSITIVE_PATTERNS.items():
            matches = re.finditer(pattern, sanitized, re.IGNORECASE)
            for match in matches:
                original = match.group(0)
                
                if complete_redaction:
                    replacement = f'[REDACTED_{pattern_name.upper()}]'
                else:
                    replacement = self._mask_value(original, pattern_name)
                
                sanitized = sanitized.replace(original, replacement)
        
        return sanitized
    
    def sanitize_dict(self, data: Dict[str, Any], complete_redaction: bool = False) -> Dict[str, Any]:
        """
        Sanitize dictionary recursively.
        
        Args:
            data: Dictionary to sanitize
            complete_redaction: If True, completely redact instead of partial masking
            
        Returns:
            Sanitized dictionary
        """
        if not isinstance(data, dict):
            return data
        
        sanitized = {}
        
        for key, value in data.items():
            # Sanitize key
            sanitized_key = self.sanitize_text(key, complete_redaction)
            
            # Sanitize value based on type
            if isinstance(value, str):
                sanitized_value = self.sanitize_text(value, complete_redaction)
            elif isinstance(value, dict):
                sanitized_value = self.sanitize_dict(value, complete_redaction)
            elif isinstance(value, list):
                sanitized_value = self.sanitize_list(value, complete_redaction)
            else:
                sanitized_value = value
            
            # Check for sensitive key names
            if self._is_sensitive_key(key):
                if complete_redaction:
                    sanitized_value = '[REDACTED]'
                else:
                    sanitized_value = self._mask_value(str(sanitized_value), 'sensitive_key')
            
            sanitized[sanitized_key] = sanitized_value
        
        return sanitized
    
    def sanitize_list(self, data: List[Any], complete_redaction: bool = False) -> List[Any]:
        """
        Sanitize list recursively.
        
        Args:
            data: List to sanitize
            complete_redaction: If True, completely redact instead of partial masking
            
        Returns:
            Sanitized list
        """
        if not isinstance(data, list):
            return data
        
        sanitized = []
        
        for item in data:
            if isinstance(item, str):
                sanitized.append(self.sanitize_text(item, complete_redaction))
            elif isinstance(item, dict):
                sanitized.append(self.sanitize_dict(item, complete_redaction))
            elif isinstance(item, list):
                sanitized.append(self.sanitize_list(item, complete_redaction))
            else:
                sanitized.append(item)
        
        return sanitized
    
    def _mask_value(self, value: str, pattern_type: str) -> str:
        """
        Mask a sensitive value while preserving some characters for debugging.
        
        Args:
            value: Value to mask
            pattern_type: Type of pattern being masked
            
        Returns:
            Masked value
        """
        if len(value) <= (self.preserve_prefix + self.preserve_suffix):
            # Value too short, mask completely
            return self.mask_char * len(value)
        
        # Special handling for specific patterns
        if pattern_type == 'email_pattern':
            # For emails, preserve domain
            parts = value.split('@')
            if len(parts) == 2:
                username_masked = self.mask_char * max(1, len(parts[0]) - 2) 
                return f"{parts[0][:1]}{username_masked}{parts[0][-1:]}@{parts[1]}"
        
        if pattern_type == 'certificate_thumbprint':
            # For thumbprints, show first 4 and last 4 characters
            return f"{value[:4]}{self.mask_char * (len(value) - 8)}{value[-4:]}"
        
        # Default masking: preserve prefix and suffix
        prefix = value[:self.preserve_prefix]
        suffix = value[-self.preserve_suffix:]
        middle_length = len(value) - self.preserve_prefix - self.preserve_suffix
        
        return f"{prefix}{self.mask_char * middle_length}{suffix}"
    
    def _is_sensitive_key(self, key: str) -> bool:
        """
        Check if a key name indicates sensitive data.
        
        Args:
            key: Key name to check
            
        Returns:
            True if key indicates sensitive data
        """
        sensitive_keywords = [
            'password', 'secret', 'token', 'key', 'credential',
            'thumbprint', 'private', 'confidential', 'auth',
            'pwd', 'pass', 'api', 'cert', 'signature'
        ]
        
        key_lower = key.lower()
        return any(keyword in key_lower for keyword in sensitive_keywords)
    
    def sanitize_error_message(self, error_message: str) -> str:
        """
        Sanitize error messages for safe logging.
        
        Args:
            error_message: Error message to sanitize
            
        Returns:
            Sanitized error message
        """
        # Apply complete redaction for error messages
        return self.sanitize_text(error_message, complete_redaction=True)
    
    def sanitize_log_entry(self, log_entry: str) -> str:
        """
        Sanitize log entries for safe storage.
        
        Args:
            log_entry: Log entry to sanitize
            
        Returns:
            Sanitized log entry
        """
        return self.sanitize_text(log_entry, complete_redaction=False)


# Global sanitizer instance
_global_sanitizer = DataSanitizer()


def sanitize_for_logging(data: Union[str, Dict, List]) -> Union[str, Dict, List]:
    """
    Convenience function to sanitize data for logging.
    
    Args:
        data: Data to sanitize
        
    Returns:
        Sanitized data
    """
    if isinstance(data, str):
        return _global_sanitizer.sanitize_log_entry(data)
    elif isinstance(data, dict):
        return _global_sanitizer.sanitize_dict(data)
    elif isinstance(data, list):
        return _global_sanitizer.sanitize_list(data)
    else:
        return data


def sanitize_for_output(data: Union[str, Dict, List]) -> Union[str, Dict, List]:
    """
    Convenience function to sanitize data for output (reports, etc).
    
    Args:
        data: Data to sanitize
        
    Returns:
        Sanitized data
    """
    if isinstance(data, str):
        return _global_sanitizer.sanitize_text(data)
    elif isinstance(data, dict):
        return _global_sanitizer.sanitize_dict(data)
    elif isinstance(data, list):
        return _global_sanitizer.sanitize_list(data)
    else:
        return data


def sanitize_error(error_message: str) -> str:
    """
    Convenience function to sanitize error messages.
    
    Args:
        error_message: Error message to sanitize
        
    Returns:
        Sanitized error message
    """
    return _global_sanitizer.sanitize_error_message(error_message)