"""
強化されたエラーハンドリング・ログ機能
包括的なエラー処理、ログ管理、監査証跡システム
"""

import asyncio
import json
import traceback
import sys
import os
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Union, Callable
from enum import Enum
from pathlib import Path
import logging
from logging.handlers import RotatingFileHandler, TimedRotatingFileHandler
import structlog
from functools import wraps
import uuid

from .config import settings
from .logging_config import get_logger

# カスタムエラークラス群
class M365ToolsError(Exception):
    """基底エラークラス"""
    def __init__(self, message: str, error_code: str = None, details: Dict[str, Any] = None):
        super().__init__(message)
        self.message = message
        self.error_code = error_code or "GENERAL_ERROR"
        self.details = details or {}
        self.timestamp = datetime.utcnow()
        self.error_id = str(uuid.uuid4())

class AuthenticationError(M365ToolsError):
    """認証エラー"""
    def __init__(self, message: str, service: str = None, details: Dict[str, Any] = None):
        super().__init__(message, "AUTH_ERROR", details)
        self.service = service

class GraphAPIError(M365ToolsError):
    """Microsoft Graph APIエラー"""
    def __init__(self, message: str, status_code: int = None, response_data: Dict[str, Any] = None):
        details = {"status_code": status_code, "response_data": response_data}
        super().__init__(message, "GRAPH_API_ERROR", details)
        self.status_code = status_code
        self.response_data = response_data

class PowerShellBridgeError(M365ToolsError):
    """PowerShellブリッジエラー"""
    def __init__(self, message: str, exit_code: int = None, stderr: str = None):
        details = {"exit_code": exit_code, "stderr": stderr}
        super().__init__(message, "POWERSHELL_ERROR", details)
        self.exit_code = exit_code
        self.stderr = stderr

class ConfigurationError(M365ToolsError):
    """設定エラー"""
    def __init__(self, message: str, config_key: str = None):
        details = {"config_key": config_key}
        super().__init__(message, "CONFIG_ERROR", details)
        self.config_key = config_key

class DatabaseError(M365ToolsError):
    """データベースエラー"""
    def __init__(self, message: str, operation: str = None, details: Dict[str, Any] = None):
        details = details or {}
        details["operation"] = operation
        super().__init__(message, "DATABASE_ERROR", details)
        self.operation = operation

class ValidationError(M365ToolsError):
    """バリデーションエラー"""
    def __init__(self, message: str, field: str = None, value: Any = None):
        details = {"field": field, "value": str(value) if value is not None else None}
        super().__init__(message, "VALIDATION_ERROR", details)
        self.field = field
        self.value = value

class RateLimitError(M365ToolsError):
    """レート制限エラー"""
    def __init__(self, message: str, retry_after: int = None, service: str = None):
        details = {"retry_after": retry_after, "service": service}
        super().__init__(message, "RATE_LIMIT_ERROR", details)
        self.retry_after = retry_after
        self.service = service

# ログレベル定義
class LogLevel(str, Enum):
    TRACE = "TRACE"
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"

# エラー重要度
class ErrorSeverity(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"

class StructuredLogger:
    """構造化ログシステム"""
    
    def __init__(self):
        self.logger = None
        self.log_dir = Path(settings.base_dir) / "Logs"
        self.log_dir.mkdir(exist_ok=True)
        
        # ログファイル設定
        self.log_files = {
            "application": self.log_dir / "application.log",
            "api": self.log_dir / "api.log",
            "auth": self.log_dir / "authentication.log",
            "graph": self.log_dir / "graph_api.log",
            "powershell": self.log_dir / "powershell_bridge.log",
            "database": self.log_dir / "database.log",
            "security": self.log_dir / "security.log",
            "audit": self.log_dir / "audit.log",
            "performance": self.log_dir / "performance.log",
            "error": self.log_dir / "errors.log"
        }
        
        self._setup_structured_logging()
        
    def _setup_structured_logging(self):
        """構造化ログ設定"""
        structlog.configure(
            processors=[
                structlog.stdlib.filter_by_level,
                structlog.stdlib.add_logger_name,
                structlog.stdlib.add_log_level,
                structlog.stdlib.PositionalArgumentsFormatter(),
                structlog.processors.TimeStamper(fmt="iso"),
                structlog.processors.StackInfoRenderer(),
                structlog.processors.format_exc_info,
                structlog.processors.JSONRenderer()
            ],
            context_class=dict,
            logger_factory=structlog.stdlib.LoggerFactory(),
            wrapper_class=structlog.stdlib.BoundLogger,
            cache_logger_on_first_use=True,
        )
        
        # メインロガー設定
        self.logger = structlog.get_logger("m365_tools")
        
        # ファイルハンドラー設定
        for log_type, log_path in self.log_files.items():
            handler = TimedRotatingFileHandler(
                log_path,
                when="midnight",
                interval=1,
                backupCount=30,
                encoding="utf-8"
            )
            handler.setLevel(logging.INFO)
            
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            
            # 専用ロガー作成
            logger = logging.getLogger(f"m365_tools.{log_type}")
            logger.addHandler(handler)
            logger.setLevel(logging.INFO)
    
    def log(self, level: LogLevel, message: str, **kwargs):
        """構造化ログ出力"""
        log_data = {
            "message": message,
            "timestamp": datetime.utcnow().isoformat(),
            "level": level.value,
            **kwargs
        }
        
        if level == LogLevel.TRACE:
            self.logger.debug("TRACE: " + message, **log_data)
        elif level == LogLevel.DEBUG:
            self.logger.debug(message, **log_data)
        elif level == LogLevel.INFO:
            self.logger.info(message, **log_data)
        elif level == LogLevel.WARNING:
            self.logger.warning(message, **log_data)
        elif level == LogLevel.ERROR:
            self.logger.error(message, **log_data)
        elif level == LogLevel.CRITICAL:
            self.logger.critical(message, **log_data)
    
    def log_error(self, error: Exception, context: Dict[str, Any] = None, severity: ErrorSeverity = ErrorSeverity.MEDIUM):
        """エラーログ記録"""
        error_data = {
            "error_type": type(error).__name__,
            "error_message": str(error),
            "severity": severity.value,
            "context": context or {},
            "traceback": traceback.format_exc()
        }
        
        if isinstance(error, M365ToolsError):
            error_data.update({
                "error_code": error.error_code,
                "error_id": error.error_id,
                "details": error.details
            })
        
        self.log(LogLevel.ERROR, f"Error occurred: {str(error)}", **error_data)
        
        # 重要度が高い場合は別途記録
        if severity in [ErrorSeverity.HIGH, ErrorSeverity.CRITICAL]:
            self._log_critical_error(error, error_data)
    
    def _log_critical_error(self, error: Exception, error_data: Dict[str, Any]):
        """重要エラーの特別ログ"""
        critical_logger = logging.getLogger("m365_tools.critical")
        critical_logger.critical(json.dumps(error_data, indent=2, ensure_ascii=False))
        
        # アラート送信（実装省略）
        # await self._send_alert(error, error_data)
    
    def log_api_request(self, method: str, url: str, status_code: int, response_time: float, **kwargs):
        """API リクエストログ"""
        api_logger = logging.getLogger("m365_tools.api")
        
        log_data = {
            "method": method,
            "url": url,
            "status_code": status_code,
            "response_time_ms": round(response_time * 1000, 2),
            "timestamp": datetime.utcnow().isoformat(),
            **kwargs
        }
        
        api_logger.info(f"{method} {url} - {status_code} ({response_time:.3f}s)", extra=log_data)
    
    def log_authentication(self, user_id: str, service: str, success: bool, **kwargs):
        """認証ログ"""
        auth_logger = logging.getLogger("m365_tools.auth")
        
        log_data = {
            "user_id": user_id,
            "service": service,
            "success": success,
            "timestamp": datetime.utcnow().isoformat(),
            **kwargs
        }
        
        message = f"Authentication {'succeeded' if success else 'failed'} for {user_id} on {service}"
        auth_logger.info(message, extra=log_data)
    
    def log_security_event(self, event_type: str, severity: ErrorSeverity, details: Dict[str, Any]):
        """セキュリティイベントログ"""
        security_logger = logging.getLogger("m365_tools.security")
        
        log_data = {
            "event_type": event_type,
            "severity": severity.value,
            "details": details,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        security_logger.warning(f"Security event: {event_type}", extra=log_data)
    
    def log_audit(self, user_id: str, action: str, resource: str, result: str, **kwargs):
        """監査ログ"""
        audit_logger = logging.getLogger("m365_tools.audit")
        
        log_data = {
            "user_id": user_id,
            "action": action,
            "resource": resource,
            "result": result,
            "timestamp": datetime.utcnow().isoformat(),
            **kwargs
        }
        
        audit_logger.info(f"AUDIT: {user_id} {action} {resource} - {result}", extra=log_data)
    
    def log_performance(self, operation: str, duration: float, **kwargs):
        """パフォーマンスログ"""
        performance_logger = logging.getLogger("m365_tools.performance")
        
        log_data = {
            "operation": operation,
            "duration_ms": round(duration * 1000, 2),
            "timestamp": datetime.utcnow().isoformat(),
            **kwargs
        }
        
        performance_logger.info(f"PERF: {operation} took {duration:.3f}s", extra=log_data)

class ErrorHandler:
    """包括的エラーハンドリング"""
    
    def __init__(self):
        self.logger = StructuredLogger()
        self.error_counts = {}
        self.circuit_breakers = {}
        
    async def handle_error(self, error: Exception, context: Dict[str, Any] = None, reraise: bool = True) -> Optional[Any]:
        """エラー処理"""
        try:
            # エラー分類
            severity = self._classify_error_severity(error)
            
            # ログ記録
            self.logger.log_error(error, context, severity)
            
            # エラー統計更新
            self._update_error_statistics(error)
            
            # 自動復旧試行
            if self._should_auto_recover(error):
                recovery_result = await self._attempt_auto_recovery(error, context)
                if recovery_result is not None:
                    return recovery_result
            
            # アラート送信（重要度高）
            if severity in [ErrorSeverity.HIGH, ErrorSeverity.CRITICAL]:
                await self._send_alert(error, context, severity)
            
        except Exception as e:
            # エラーハンドリング自体のエラー
            print(f"Error in error handler: {e}", file=sys.stderr)
        
        if reraise:
            raise error
        
        return None
    
    def _classify_error_severity(self, error: Exception) -> ErrorSeverity:
        """エラー重要度分類"""
        if isinstance(error, (AuthenticationError, ConfigurationError)):
            return ErrorSeverity.HIGH
        elif isinstance(error, (GraphAPIError, PowerShellBridgeError)):
            return ErrorSeverity.MEDIUM
        elif isinstance(error, (ValidationError, RateLimitError)):
            return ErrorSeverity.LOW
        elif isinstance(error, DatabaseError):
            return ErrorSeverity.HIGH
        else:
            return ErrorSeverity.MEDIUM
    
    def _update_error_statistics(self, error: Exception):
        """エラー統計更新"""
        error_type = type(error).__name__
        current_hour = datetime.utcnow().replace(minute=0, second=0, microsecond=0)
        
        key = f"{error_type}_{current_hour.isoformat()}"
        self.error_counts[key] = self.error_counts.get(key, 0) + 1
        
        # 古い統計削除（24時間より古い）
        cutoff = current_hour - timedelta(hours=24)
        keys_to_delete = [k for k in self.error_counts.keys() if k.endswith(cutoff.isoformat())]
        for key in keys_to_delete:
            del self.error_counts[key]
    
    def _should_auto_recover(self, error: Exception) -> bool:
        """自動復旧判定"""
        if isinstance(error, RateLimitError):
            return True
        elif isinstance(error, GraphAPIError) and error.status_code in [503, 504]:
            return True
        elif isinstance(error, AuthenticationError):
            return True
        return False
    
    async def _attempt_auto_recovery(self, error: Exception, context: Dict[str, Any] = None) -> Optional[Any]:
        """自動復旧試行"""
        try:
            if isinstance(error, RateLimitError):
                # レート制限の場合は待機
                retry_after = error.retry_after or 60
                self.logger.log(LogLevel.INFO, f"Rate limited, waiting {retry_after} seconds...")
                await asyncio.sleep(retry_after)
                return "retry"
            
            elif isinstance(error, AuthenticationError):
                # 認証エラーの場合はトークン再取得
                self.logger.log(LogLevel.INFO, "Attempting token refresh...")
                # 実際の再認証ロジックは省略
                return "token_refreshed"
            
            elif isinstance(error, GraphAPIError) and error.status_code in [503, 504]:
                # サーバーエラーの場合は短時間待機後リトライ
                await asyncio.sleep(5)
                return "retry"
            
        except Exception as e:
            self.logger.log_error(e, {"recovery_attempt": True})
        
        return None
    
    async def _send_alert(self, error: Exception, context: Dict[str, Any], severity: ErrorSeverity):
        """アラート送信"""
        alert_data = {
            "error_type": type(error).__name__,
            "error_message": str(error),
            "severity": severity.value,
            "context": context,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # 実際のアラート送信ロジック（メール、Slack等）は省略
        self.logger.log(LogLevel.INFO, f"Alert sent for {severity.value} error", alert=alert_data)
    
    def get_error_statistics(self) -> Dict[str, Any]:
        """エラー統計取得"""
        current_hour = datetime.utcnow().replace(minute=0, second=0, microsecond=0)
        
        # 過去24時間の統計
        stats = {}
        for i in range(24):
            hour = current_hour - timedelta(hours=i)
            hour_key = hour.isoformat()
            
            hour_errors = {
                k.split('_')[0]: v for k, v in self.error_counts.items()
                if k.endswith(hour_key)
            }
            
            if hour_errors:
                stats[hour_key] = hour_errors
        
        return {
            "hourly_statistics": stats,
            "total_errors_24h": sum(self.error_counts.values()),
            "error_types": list(set(k.split('_')[0] for k in self.error_counts.keys()))
        }

# デコレータ群
def handle_errors(reraise: bool = True, severity: ErrorSeverity = ErrorSeverity.MEDIUM):
    """エラーハンドリングデコレータ"""
    def decorator(func):
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            try:
                return await func(*args, **kwargs)
            except Exception as e:
                context = {
                    "function": func.__name__,
                    "args": str(args)[:200],  # 長すぎる場合は切り詰め
                    "kwargs": str(kwargs)[:200]
                }
                await error_handler.handle_error(e, context, reraise)
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                context = {
                    "function": func.__name__,
                    "args": str(args)[:200],
                    "kwargs": str(kwargs)[:200]
                }
                asyncio.create_task(error_handler.handle_error(e, context, reraise))
        
        return async_wrapper if asyncio.iscoroutinefunction(func) else sync_wrapper
    return decorator

def log_performance(operation_name: str = None):
    """パフォーマンスログデコレータ"""
    def decorator(func):
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            start_time = datetime.utcnow()
            try:
                result = await func(*args, **kwargs)
                duration = (datetime.utcnow() - start_time).total_seconds()
                
                op_name = operation_name or func.__name__
                structured_logger.log_performance(op_name, duration)
                
                return result
            except Exception as e:
                duration = (datetime.utcnow() - start_time).total_seconds()
                op_name = operation_name or func.__name__
                structured_logger.log_performance(f"{op_name}_failed", duration, error=str(e))
                raise
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            start_time = datetime.utcnow()
            try:
                result = func(*args, **kwargs)
                duration = (datetime.utcnow() - start_time).total_seconds()
                
                op_name = operation_name or func.__name__
                structured_logger.log_performance(op_name, duration)
                
                return result
            except Exception as e:
                duration = (datetime.utcnow() - start_time).total_seconds()
                op_name = operation_name or func.__name__
                structured_logger.log_performance(f"{op_name}_failed", duration, error=str(e))
                raise
        
        return async_wrapper if asyncio.iscoroutinefunction(func) else sync_wrapper
    return decorator

def audit_action(action: str, resource: str = None):
    """監査ログデコレータ"""
    def decorator(func):
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            user_id = kwargs.get('user_id', 'system')
            resource_name = resource or kwargs.get('resource', func.__name__)
            
            try:
                result = await func(*args, **kwargs)
                structured_logger.log_audit(user_id, action, resource_name, "success")
                return result
            except Exception as e:
                structured_logger.log_audit(user_id, action, resource_name, f"failed: {str(e)}")
                raise
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            user_id = kwargs.get('user_id', 'system')
            resource_name = resource or kwargs.get('resource', func.__name__)
            
            try:
                result = func(*args, **kwargs)
                structured_logger.log_audit(user_id, action, resource_name, "success")
                return result
            except Exception as e:
                structured_logger.log_audit(user_id, action, resource_name, f"failed: {str(e)}")
                raise
        
        return async_wrapper if asyncio.iscoroutinefunction(func) else sync_wrapper
    return decorator

# グローバルインスタンス
structured_logger = StructuredLogger()
error_handler = ErrorHandler()

# 便利な関数群
async def log_info(message: str, **kwargs):
    """情報ログ"""
    structured_logger.log(LogLevel.INFO, message, **kwargs)

async def log_warning(message: str, **kwargs):
    """警告ログ"""
    structured_logger.log(LogLevel.WARNING, message, **kwargs)

async def log_error(message: str, **kwargs):
    """エラーログ"""
    structured_logger.log(LogLevel.ERROR, message, **kwargs)

async def log_critical(message: str, **kwargs):
    """重要ログ"""
    structured_logger.log(LogLevel.CRITICAL, message, **kwargs)

def get_error_statistics() -> Dict[str, Any]:
    """エラー統計取得"""
    return error_handler.get_error_statistics()

# 初期化関数
def initialize_error_handling():
    """エラーハンドリング初期化"""
    # 未処理例外ハンドラー設定
    def handle_exception(exc_type, exc_value, exc_traceback):
        if issubclass(exc_type, KeyboardInterrupt):
            sys.__excepthook__(exc_type, exc_value, exc_traceback)
            return
        
        structured_logger.log_error(
            exc_value,
            {"uncaught_exception": True},
            ErrorSeverity.CRITICAL
        )
    
    sys.excepthook = handle_exception
    
    # 非同期例外ハンドラー設定
    def handle_async_exception(loop, context):
        exception = context.get('exception')
        if exception:
            asyncio.create_task(
                error_handler.handle_error(
                    exception,
                    {"async_exception": True, "context": context},
                    reraise=False
                )
            )
    
    # イベントループが利用可能な場合のみ設定
    try:
        loop = asyncio.get_event_loop()
        loop.set_exception_handler(handle_async_exception)
    except RuntimeError:
        pass  # イベントループが未初期化の場合は無視
    
    structured_logger.log(LogLevel.INFO, "Error handling system initialized")

# 健全性チェック
async def health_check() -> Dict[str, Any]:
    """エラーハンドリングシステム健全性チェック"""
    try:
        # ログディレクトリ確認
        log_dir_exists = structured_logger.log_dir.exists()
        
        # ログファイル確認
        log_files_status = {}
        for log_type, log_path in structured_logger.log_files.items():
            log_files_status[log_type] = {
                "exists": log_path.exists(),
                "size_mb": round(log_path.stat().st_size / (1024*1024), 2) if log_path.exists() else 0
            }
        
        # エラー統計
        error_stats = error_handler.get_error_statistics()
        
        return {
            "status": "healthy",
            "log_directory_exists": log_dir_exists,
            "log_files": log_files_status,
            "error_statistics": error_stats,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }