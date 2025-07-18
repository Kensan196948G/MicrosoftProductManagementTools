"""
Enhanced retry handler for Microsoft 365 API calls.
Python equivalent of PowerShell retry logic from Authentication.psm1.
Implements exponential backoff and circuit breaker patterns.
"""

import asyncio
import logging
import random
import time
import re
from datetime import datetime, timedelta
from enum import Enum
from typing import Any, Callable, Dict, Optional, Union, List
from dataclasses import dataclass, field
from functools import wraps

from .auth_exceptions import AuthenticationError, AuthErrorCode


class RetryStrategy(Enum):
    """Retry strategy types."""
    EXPONENTIAL_BACKOFF = "exponential_backoff"
    FIXED_DELAY = "fixed_delay"
    LINEAR_BACKOFF = "linear_backoff"
    IMMEDIATE = "immediate"


class ErrorCategory(Enum):
    """Error categories for retry logic - matches PowerShell implementation."""
    RATE_LIMIT = "RateLimit"
    AUTHENTICATION = "Authentication"
    AUTHORIZATION = "Authorization"
    NETWORK = "Network"
    TRANSIENT = "Transient"
    OTHER = "Other"


@dataclass
class RetryConfig:
    """Configuration for retry behavior."""
    max_attempts: int = 3
    base_delay: float = 1.0
    max_delay: float = 60.0
    backoff_multiplier: float = 2.0
    strategy: RetryStrategy = RetryStrategy.EXPONENTIAL_BACKOFF
    
    # Error codes that should not be retried
    non_retryable_errors: List[str] = field(default_factory=lambda: [
        AuthErrorCode.CERTIFICATE_NOT_FOUND.value,
        AuthErrorCode.CERTIFICATE_EXPIRED.value,
        AuthErrorCode.CERTIFICATE_INVALID.value,
        AuthErrorCode.PERMISSION_DENIED.value,
        AuthErrorCode.INVALID_CREDENTIALS.value,
        AuthErrorCode.INVALID_CONFIGURATION.value,
        AuthErrorCode.MISSING_CONFIGURATION.value,
    ])
    
    # Error codes that should be retried with special handling
    retryable_errors: List[str] = field(default_factory=lambda: [
        AuthErrorCode.CONNECTION_FAILED.value,
        AuthErrorCode.CONNECTION_TIMEOUT.value,
        AuthErrorCode.SERVICE_UNAVAILABLE.value,
        AuthErrorCode.NETWORK_ERROR.value,
        AuthErrorCode.TOKEN_REFRESH_FAILED.value,
    ])


@dataclass
class RetryAttempt:
    """Information about a retry attempt."""
    attempt_number: int
    delay: float
    error: Optional[Exception] = None
    timestamp: datetime = field(default_factory=datetime.utcnow)


class CircuitBreaker:
    """Circuit breaker to prevent cascading failures."""
    
    def __init__(self, failure_threshold: int = 5, 
                 recovery_timeout: int = 30,
                 expected_exception: type = Exception):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.expected_exception = expected_exception
        
        self.failure_count = 0
        self.last_failure_time: Optional[datetime] = None
        self.state = "CLOSED"  # CLOSED, OPEN, HALF_OPEN
        
        self.logger = logging.getLogger(__name__)
    
    def can_execute(self) -> bool:
        """Check if execution is allowed."""
        if self.state == "CLOSED":
            return True
        elif self.state == "OPEN":
            if self.last_failure_time and \
               datetime.utcnow() - self.last_failure_time > timedelta(seconds=self.recovery_timeout):
                self.state = "HALF_OPEN"
                return True
            return False
        elif self.state == "HALF_OPEN":
            return True
        return False
    
    def record_success(self):
        """Record successful execution."""
        self.failure_count = 0
        self.state = "CLOSED"
        self.last_failure_time = None
    
    def record_failure(self, exception: Exception):
        """Record failed execution."""
        if isinstance(exception, self.expected_exception):
            self.failure_count += 1
            self.last_failure_time = datetime.utcnow()
            
            if self.failure_count >= self.failure_threshold:
                self.state = "OPEN"
                self.logger.warning(f"Circuit breaker opened after {self.failure_count} failures")


class RetryHandler:
    """
    Enhanced retry handler for Microsoft 365 API calls.
    Python equivalent of PowerShell Invoke-GraphAPIWithRetry function.
    """
    
    def __init__(self, config: Optional[RetryConfig] = None):
        self.config = config or RetryConfig()
        self.logger = logging.getLogger(__name__)
        self.circuit_breaker = CircuitBreaker()
    
    def categorize_error(self, error_message: str) -> ErrorCategory:
        """
        Categorize error based on error message.
        Python equivalent of PowerShell Get-ErrorCategory function.
        """
        error_lower = error_message.lower()
        
        # Rate limit errors - matches PowerShell regex patterns
        if any(keyword in error_lower for keyword in [
            "429", "throttle", "rate limit", "toomanyrequests", "quota", "exceeded"
        ]):
            return ErrorCategory.RATE_LIMIT
        
        # Authentication errors
        elif any(keyword in error_lower for keyword in [
            "401", "unauthorized", "authentication", "failed", "invalid", "token", "expired"
        ]):
            return ErrorCategory.AUTHENTICATION
        
        # Authorization errors
        elif any(keyword in error_lower for keyword in [
            "403", "forbidden", "access", "denied", "insufficient", "privileges"
        ]):
            return ErrorCategory.AUTHORIZATION
        
        # Network errors
        elif any(keyword in error_lower for keyword in [
            "timeout", "connection", "reset", "name", "not", "resolved", "network", "dns"
        ]):
            return ErrorCategory.NETWORK
        
        # Transient server errors
        elif any(keyword in error_lower for keyword in [
            "500", "502", "503", "504", "internal", "server", "service", "unavailable", "bad", "gateway"
        ]):
            return ErrorCategory.TRANSIENT
        
        else:
            return ErrorCategory.OTHER
    
    def calculate_adaptive_delay(self, attempt: int, error_category: ErrorCategory, error_message: str) -> float:
        """
        Calculate adaptive delay based on error category and message.
        Python equivalent of PowerShell Get-AdaptiveDelay function.
        """
        # Extract Retry-After header value if present
        retry_after_match = re.search(r'retry.*?after.*?(\d+)', error_message.lower())
        if retry_after_match:
            retry_after = int(retry_after_match.group(1))
            return min(retry_after + 1, 300)  # Max 5 minutes
        
        # Category-specific delay calculation
        if error_category == ErrorCategory.RATE_LIMIT:
            # Exponential backoff with jitter for rate limits
            base_delay = self.config.base_delay * (2 ** attempt)
            jitter = random.uniform(0, base_delay * 0.1)
            return min(base_delay + jitter, 120)  # Max 2 minutes
        
        elif error_category == ErrorCategory.AUTHENTICATION:
            # Shorter delay for auth errors
            return min(self.config.base_delay * attempt, 30)  # Max 30 seconds
        
        elif error_category == ErrorCategory.NETWORK:
            # Linear backoff for network errors
            return min(self.config.base_delay * attempt, 60)  # Max 1 minute
        
        elif error_category == ErrorCategory.TRANSIENT:
            # Exponential backoff with jitter for transient errors
            base_delay = self.config.base_delay * (2 ** attempt)
            jitter = random.uniform(0, base_delay * 0.1)
            return min(base_delay + jitter, 60)  # Max 1 minute
        
        else:
            # Default exponential backoff
            return min(self.config.base_delay * (2 ** attempt), 30)  # Max 30 seconds
    
    def get_delay_message(self, error_category: ErrorCategory, delay: float) -> str:
        """
        Get appropriate delay message based on error category.
        Matches PowerShell logging messages.
        """
        delay_str = f"{delay:.1f}s"
        
        if error_category == ErrorCategory.RATE_LIMIT:
            return f"🕒 API制限検出。{delay_str}後にリトライします..."
        elif error_category == ErrorCategory.AUTHENTICATION:
            return f"🔐 認証エラー検出。{delay_str}後にリトライします..."
        elif error_category == ErrorCategory.NETWORK:
            return f"🌐 ネットワークエラー。{delay_str}後にリトライします..."
        elif error_category == ErrorCategory.TRANSIENT:
            return f"⏳ 一時的エラー。{delay_str}後にリトライします..."
        else:
            return f"🔄 エラー検出。{delay_str}後にリトライします..."
    
    def should_retry(self, exception: Exception, attempt: int, error_category: ErrorCategory) -> bool:
        """
        Determine if an operation should be retried.
        Enhanced with PowerShell-style error categorization.
        """
        if attempt >= self.config.max_attempts:
            return False
        
        # Authorization errors should not be retried (permissions issues)
        if error_category == ErrorCategory.AUTHORIZATION:
            return False
        
        if isinstance(exception, AuthenticationError):
            error_code = exception.error_code
            
            # Don't retry non-retryable errors
            if error_code in self.config.non_retryable_errors:
                self.logger.debug(f"Not retrying non-retryable error: {error_code}")
                return False
            
            # Retry known retryable errors
            if error_code in self.config.retryable_errors:
                return True
            
            # For other auth errors, check error details
            if "timeout" in str(exception).lower():
                return True
            if "connection" in str(exception).lower():
                return True
            
            return False
        
        # Retry other categories that might be temporary
        if error_category in [ErrorCategory.RATE_LIMIT, ErrorCategory.NETWORK, ErrorCategory.TRANSIENT]:
            return True
        
        # Retry other exceptions that might be temporary
        if isinstance(exception, (ConnectionError, TimeoutError)):
            return True
        
        return False
    
    def calculate_delay(self, attempt: int) -> float:
        """Calculate delay for next retry attempt."""
        if self.config.strategy == RetryStrategy.EXPONENTIAL_BACKOFF:
            delay = self.config.base_delay * (self.config.backoff_multiplier ** (attempt - 1))
        elif self.config.strategy == RetryStrategy.LINEAR_BACKOFF:
            delay = self.config.base_delay * attempt
        elif self.config.strategy == RetryStrategy.FIXED_DELAY:
            delay = self.config.base_delay
        else:  # IMMEDIATE
            delay = 0
        
        return min(delay, self.config.max_delay)
    
    def execute_with_retry(self, func: Callable, operation: str = "API Call", 
                          diagnostic_context: Optional[Dict[str, Any]] = None, 
                          *args, **kwargs) -> Any:
        """
        Execute function with retry logic.
        Python equivalent of PowerShell Invoke-GraphAPIWithRetry function.
        """
        attempts = []
        last_exception = None
        start_time = time.time()
        
        for attempt in range(1, self.config.max_attempts + 1):
            # Check circuit breaker
            if not self.circuit_breaker.can_execute():
                raise AuthenticationError(
                    "Circuit breaker is open",
                    error_code=AuthErrorCode.SERVICE_UNAVAILABLE.value,
                    error_description="Service temporarily unavailable due to repeated failures"
                )
            
            try:
                self.logger.info(f"🔄 API呼び出し試行 {attempt}/{self.config.max_attempts} - {operation}")
                
                # Add timing for performance monitoring
                call_start = time.time()
                result = func(*args, **kwargs)
                duration = (time.time() - call_start) * 1000  # Convert to milliseconds
                
                # Record success
                self.circuit_breaker.record_success()
                
                self.logger.info(f"✅ API呼び出し成功 - {operation} ({duration:.0f}ms)")
                
                if attempts:
                    self.logger.info(f"Operation succeeded after {attempt} attempts")
                
                return result
                
            except Exception as e:
                last_exception = e
                error_message = str(e)
                error_category = self.categorize_error(error_message)
                
                attempts.append(RetryAttempt(
                    attempt_number=attempt,
                    delay=0,
                    error=e
                ))
                
                # Record failure
                self.circuit_breaker.record_failure(e)
                
                self.logger.warning(f"⚠️ API呼び出しエラー (試行 {attempt}): {error_message}")
                
                if not self.should_retry(e, attempt, error_category):
                    if error_category == ErrorCategory.AUTHORIZATION:
                        self.logger.error(f"❌ 権限エラー（リトライ不可）: {error_message}")
                    else:
                        self.logger.error(f"❌ 重大エラー（リトライ不可）: {error_message}")
                    break
                
                if attempt < self.config.max_attempts:
                    delay = self.calculate_adaptive_delay(attempt, error_category, error_message)
                    attempts[-1].delay = delay
                    
                    self.logger.warning(self.get_delay_message(error_category, delay))
                    time.sleep(delay)
                else:
                    self.logger.error(f"❌ 最大リトライ回数に到達: {error_message}")
        
        # All attempts failed
        total_duration = time.time() - start_time
        self.logger.error(f"Operation failed after {len(attempts)} attempts in {total_duration:.2f}s")
        
        # Raise the last exception with retry information
        if isinstance(last_exception, AuthenticationError):
            last_exception.details['retry_attempts'] = len(attempts)
            last_exception.details['total_delay'] = sum(a.delay for a in attempts)
        
        raise last_exception
    
    async def execute_with_retry_async(self, func: Callable, *args, **kwargs) -> Any:
        """Execute async function with retry logic."""
        attempts = []
        last_exception = None
        
        for attempt in range(1, self.config.max_attempts + 1):
            # Check circuit breaker
            if not self.circuit_breaker.can_execute():
                raise AuthenticationError(
                    "Circuit breaker is open",
                    error_code=AuthErrorCode.SERVICE_UNAVAILABLE.value,
                    error_description="Service temporarily unavailable due to repeated failures"
                )
            
            try:
                result = await func(*args, **kwargs)
                
                # Record success
                self.circuit_breaker.record_success()
                
                if attempts:
                    self.logger.info(f"Operation succeeded after {attempt} attempts")
                
                return result
                
            except Exception as e:
                last_exception = e
                attempts.append(RetryAttempt(
                    attempt_number=attempt,
                    delay=0,
                    error=e
                ))
                
                # Record failure
                self.circuit_breaker.record_failure(e)
                
                if not self.should_retry(e, attempt):
                    break
                
                if attempt < self.config.max_attempts:
                    delay = self.calculate_delay(attempt)
                    attempts[-1].delay = delay
                    
                    self.logger.warning(
                        f"Attempt {attempt} failed: {e}. "
                        f"Retrying in {delay:.2f}s..."
                    )
                    
                    await asyncio.sleep(delay)
        
        # All attempts failed
        self.logger.error(f"Operation failed after {len(attempts)} attempts")
        
        # Raise the last exception with retry information
        if isinstance(last_exception, AuthenticationError):
            last_exception.details['retry_attempts'] = len(attempts)
            last_exception.details['total_delay'] = sum(a.delay for a in attempts)
        
        raise last_exception


def retry_auth_operation(config: Optional[RetryConfig] = None):
    """Decorator for retrying authentication operations."""
    
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            handler = RetryHandler(config)
            return handler.execute_with_retry(func, *args, **kwargs)
        return wrapper
    
    return decorator


def retry_auth_operation_async(config: Optional[RetryConfig] = None):
    """Decorator for retrying async authentication operations."""
    
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs):
            handler = RetryHandler(config)
            return await handler.execute_with_retry_async(func, *args, **kwargs)
        return wrapper
    
    return decorator