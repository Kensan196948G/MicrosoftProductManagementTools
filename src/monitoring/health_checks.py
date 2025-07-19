#!/usr/bin/env python3
"""
Health Check Manager - Phase 3 FastAPI 0.115.12
Enterprise-grade health monitoring for Microsoft 365 Management Tools
"""

import asyncio
import logging
import time
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List, Callable, Set
from dataclasses import dataclass, field
from enum import Enum
import json
import socket
import ssl
from pathlib import Path

# HTTP requests
import httpx
import aiofiles

# System monitoring
import psutil
import platform

# Database
try:
    import redis.asyncio as redis
    from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
    from sqlalchemy import text
except ImportError:
    redis = None

from src.core.config import get_settings

logger = logging.getLogger(__name__)


class HealthStatus(str, Enum):
    """Health status levels"""
    HEALTHY = "healthy"
    WARNING = "warning"
    CRITICAL = "critical"
    UNKNOWN = "unknown"


@dataclass
class HealthCheckResult:
    """Health check result"""
    status: HealthStatus
    message: str
    details: Dict[str, Any] = field(default_factory=dict)
    timestamp: datetime = field(default_factory=datetime.utcnow)
    duration_ms: Optional[float] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        return {
            "status": self.status.value,
            "message": self.message,
            "details": self.details,
            "timestamp": self.timestamp.isoformat(),
            "duration_ms": self.duration_ms
        }


@dataclass
class HealthCheck:
    """Health check configuration"""
    name: str
    check_func: Callable
    interval: int = 60
    timeout: int = 30
    critical: bool = False
    tags: Set[str] = field(default_factory=set)
    last_run: Optional[datetime] = None
    last_result: Optional[HealthCheckResult] = None
    run_count: int = 0
    success_count: int = 0
    failure_count: int = 0
    enabled: bool = True


class HealthCheckManager:
    """Advanced health check management system"""
    
    def __init__(self, max_history: int = 100):
        self.checks: Dict[str, HealthCheck] = {}
        self.results_history: List[Dict[str, Any]] = []
        self.max_history = max_history
        self.running = False
        self.background_task: Optional[asyncio.Task] = None
        self.settings = get_settings()
        
    async def initialize(self):
        """Initialize health check manager"""
        try:
            await self.register_default_checks()
            await self.start_background_monitoring()
            logger.info("HealthCheckManager initialized")
        except Exception as e:
            logger.error(f"Failed to initialize HealthCheckManager: {e}")
            raise
    
    async def close(self):
        """Close health check manager"""
        try:
            await self.stop_background_monitoring()
            logger.info("HealthCheckManager closed")
        except Exception as e:
            logger.error(f"Error closing HealthCheckManager: {e}")
    
    def register_check(self, 
                      name: str, 
                      check_func: Callable,
                      interval: int = 60,
                      timeout: int = 30,
                      critical: bool = False,
                      tags: Optional[Set[str]] = None) -> None:
        """Register a health check"""
        health_check = HealthCheck(
            name=name,
            check_func=check_func,
            interval=interval,
            timeout=timeout,
            critical=critical,
            tags=tags or set()
        )
        
        self.checks[name] = health_check
        logger.info(f"Registered health check: {name}")
    
    def unregister_check(self, name: str) -> None:
        """Unregister a health check"""
        if name in self.checks:
            del self.checks[name]
            logger.info(f"Unregistered health check: {name}")
    
    async def run_check(self, name: str) -> HealthCheckResult:
        """Run a specific health check"""
        if name not in self.checks:
            return HealthCheckResult(
                status=HealthStatus.UNKNOWN,
                message=f"Health check '{name}' not found"
            )
        
        check = self.checks[name]
        if not check.enabled:
            return HealthCheckResult(
                status=HealthStatus.UNKNOWN,
                message=f"Health check '{name}' is disabled"
            )
        
        start_time = time.time()
        
        try:
            # Run check with timeout
            if asyncio.iscoroutinefunction(check.check_func):
                result = await asyncio.wait_for(
                    check.check_func(),
                    timeout=check.timeout
                )
            else:
                result = await asyncio.wait_for(
                    asyncio.to_thread(check.check_func),
                    timeout=check.timeout
                )
            
            duration_ms = (time.time() - start_time) * 1000
            
            # Update check statistics
            check.last_run = datetime.utcnow()
            check.run_count += 1
            
            if isinstance(result, HealthCheckResult):
                result.duration_ms = duration_ms
                check.last_result = result
                if result.status == HealthStatus.HEALTHY:
                    check.success_count += 1
                else:
                    check.failure_count += 1
                return result
            elif isinstance(result, dict):
                health_result = HealthCheckResult(
                    status=HealthStatus(result.get('status', 'unknown')),
                    message=result.get('message', ''),
                    details=result.get('details', {}),
                    duration_ms=duration_ms
                )
                check.last_result = health_result
                check.success_count += 1
                return health_result
            else:
                # Assume success if no specific format
                health_result = HealthCheckResult(
                    status=HealthStatus.HEALTHY,
                    message=str(result),
                    duration_ms=duration_ms
                )
                check.last_result = health_result
                check.success_count += 1
                return health_result
                
        except asyncio.TimeoutError:
            duration_ms = (time.time() - start_time) * 1000
            result = HealthCheckResult(
                status=HealthStatus.CRITICAL,
                message=f"Health check '{name}' timed out after {check.timeout}s",
                duration_ms=duration_ms
            )
            check.last_result = result
            check.failure_count += 1
            check.last_run = datetime.utcnow()
            check.run_count += 1
            return result
        except Exception as e:
            duration_ms = (time.time() - start_time) * 1000
            result = HealthCheckResult(
                status=HealthStatus.CRITICAL,
                message=f"Health check '{name}' failed: {str(e)}",
                details={"error": str(e)},
                duration_ms=duration_ms
            )
            check.last_result = result
            check.failure_count += 1
            check.last_run = datetime.utcnow()
            check.run_count += 1
            return result
    
    async def check_all(self) -> Dict[str, Any]:
        """Run all health checks and return summary"""
        results = {}
        critical_failures = []
        warning_count = 0
        healthy_count = 0
        
        # Run all checks concurrently
        tasks = {}
        for name in self.checks.keys():
            if self.checks[name].enabled:
                tasks[name] = asyncio.create_task(self.run_check(name))
        
        # Wait for all tasks to complete
        completed_tasks = await asyncio.gather(*tasks.values(), return_exceptions=True)
        
        # Process results
        for name, result in zip(tasks.keys(), completed_tasks):
            if isinstance(result, Exception):
                health_result = HealthCheckResult(
                    status=HealthStatus.CRITICAL,
                    message=f"Health check execution failed: {str(result)}",
                    details={"error": str(result)}
                )
            else:
                health_result = result
            
            results[name] = health_result.to_dict()
            
            # Track status counts
            if health_result.status == HealthStatus.HEALTHY:
                healthy_count += 1
            elif health_result.status == HealthStatus.WARNING:
                warning_count += 1
            elif health_result.status == HealthStatus.CRITICAL:
                if self.checks[name].critical:
                    critical_failures.append(name)
        
        # Determine overall status
        if critical_failures:
            overall_status = HealthStatus.CRITICAL
        elif warning_count > 0:
            overall_status = HealthStatus.WARNING
        else:
            overall_status = HealthStatus.HEALTHY
        
        # Store in history
        history_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "overall_status": overall_status.value,
            "healthy_count": healthy_count,
            "warning_count": warning_count,
            "critical_count": len(critical_failures),
            "total_count": len(results),
            "critical_failures": critical_failures,
            "results": results
        }
        
        self.results_history.append(history_entry)
        
        # Limit history size
        if len(self.results_history) > self.max_history:
            self.results_history = self.results_history[-self.max_history:]
        
        return {
            "status": overall_status.value,
            "timestamp": datetime.utcnow().isoformat(),
            "services": {name: result["status"] for name, result in results.items()},
            "details": results,
            "summary": {
                "total": len(results),
                "healthy": healthy_count,
                "warning": warning_count,
                "critical": len(critical_failures),
                "critical_services": critical_failures
            },
            "uptime_seconds": int((datetime.utcnow() - self._start_time).total_seconds()) if hasattr(self, '_start_time') else 0
        }
    
    async def get_check_history(self, name: Optional[str] = None, limit: int = 10) -> List[Dict[str, Any]]:
        """Get health check history"""
        if name:
            # Filter by specific check name
            filtered_history = []
            for entry in self.results_history:
                if name in entry.get("results", {}):
                    filtered_entry = {
                        "timestamp": entry["timestamp"],
                        "result": entry["results"][name]
                    }
                    filtered_history.append(filtered_entry)
            return filtered_history[-limit:]
        else:
            return self.results_history[-limit:]
    
    async def start_background_monitoring(self):
        """Start background health monitoring"""
        if not self.running:
            self.running = True
            self._start_time = datetime.utcnow()
            self.background_task = asyncio.create_task(self._background_monitor())
            logger.info("Background health monitoring started")
    
    async def stop_background_monitoring(self):
        """Stop background health monitoring"""
        if self.running:
            self.running = False
            if self.background_task:
                self.background_task.cancel()
                try:
                    await self.background_task
                except asyncio.CancelledError:
                    pass
            logger.info("Background health monitoring stopped")
    
    async def _background_monitor(self):
        """Background monitoring task"""
        while self.running:
            try:
                # Check if any checks need to run
                current_time = datetime.utcnow()
                
                for name, check in self.checks.items():
                    if not check.enabled:
                        continue
                    
                    # Check if it's time to run this check
                    if (check.last_run is None or 
                        (current_time - check.last_run).total_seconds() >= check.interval):
                        
                        # Run check in background
                        asyncio.create_task(self.run_check(name))
                
                # Sleep for 10 seconds before next cycle
                await asyncio.sleep(10)
                
            except Exception as e:
                logger.error(f"Error in background health monitoring: {e}")
                await asyncio.sleep(30)  # Wait longer on error
    
    # Default health checks
    
    async def register_default_checks(self):
        """Register default health checks"""
        
        # System resources check
        self.register_check(
            name="system_resources",
            check_func=self._check_system_resources,
            interval=30,
            critical=True,
            tags={"system", "resources"}
        )
        
        # Network connectivity check
        self.register_check(
            name="network_connectivity",
            check_func=self._check_network_connectivity,
            interval=60,
            tags={"network"}
        )
        
        # Database connectivity check
        if hasattr(self.settings, 'DATABASE_URL') and self.settings.DATABASE_URL:
            self.register_check(
                name="database",
                check_func=self._check_database,
                interval=120,
                critical=True,
                tags={"database"}
            )
        
        # Redis connectivity check
        if hasattr(self.settings, 'REDIS_URL') and self.settings.REDIS_URL:
            self.register_check(
                name="redis",
                check_func=self._check_redis,
                interval=60,
                tags={"cache", "redis"}
            )
        
        # Microsoft Graph API check
        self.register_check(
            name="microsoft_graph",
            check_func=self._check_microsoft_graph,
            interval=120,
            critical=True,
            tags={"external", "microsoft", "graph"}
        )
        
        logger.info("Default health checks registered")
    
    async def _check_system_resources(self) -> HealthCheckResult:
        """Check system resources"""
        try:
            # CPU usage
            cpu_percent = psutil.cpu_percent(interval=1)
            
            # Memory usage
            memory = psutil.virtual_memory()
            
            # Disk usage
            disk = psutil.disk_usage('/')
            
            # Network I/O
            network_io = psutil.net_io_counters()
            
            issues = []
            status = HealthStatus.HEALTHY
            
            # Check thresholds
            if cpu_percent > 90:
                issues.append(f"High CPU usage: {cpu_percent}%")
                status = HealthStatus.CRITICAL
            elif cpu_percent > 70:
                issues.append(f"Moderate CPU usage: {cpu_percent}%")
                status = HealthStatus.WARNING
            
            if memory.percent > 90:
                issues.append(f"High memory usage: {memory.percent}%")
                status = HealthStatus.CRITICAL
            elif memory.percent > 80:
                issues.append(f"Moderate memory usage: {memory.percent}%")
                if status == HealthStatus.HEALTHY:
                    status = HealthStatus.WARNING
            
            disk_percent = (disk.used / disk.total) * 100
            if disk_percent > 90:
                issues.append(f"High disk usage: {disk_percent:.1f}%")
                status = HealthStatus.CRITICAL
            elif disk_percent > 80:
                issues.append(f"Moderate disk usage: {disk_percent:.1f}%")
                if status == HealthStatus.HEALTHY:
                    status = HealthStatus.WARNING
            
            return HealthCheckResult(
                status=status,
                message="System resources normal" if not issues else "; ".join(issues),
                details={
                    "cpu_percent": cpu_percent,
                    "memory_percent": memory.percent,
                    "disk_percent": disk_percent,
                    "memory_available_gb": memory.available / (1024**3),
                    "disk_free_gb": disk.free / (1024**3),
                    "network_bytes_sent": network_io.bytes_sent,
                    "network_bytes_recv": network_io.bytes_recv
                }
            )
            
        except Exception as e:
            return HealthCheckResult(
                status=HealthStatus.CRITICAL,
                message=f"System resources check failed: {str(e)}",
                details={"error": str(e)}
            )
    
    async def _check_network_connectivity(self) -> HealthCheckResult:
        """Check network connectivity"""
        try:
            endpoints = [
                ('google.com', 80),
                ('microsoft.com', 443),
                ('graph.microsoft.com', 443),
                ('login.microsoftonline.com', 443)
            ]
            
            results = []
            failed_count = 0
            
            for host, port in endpoints:
                start_time = time.time()
                try:
                    # Create connection with timeout
                    future = asyncio.open_connection(host, port)
                    reader, writer = await asyncio.wait_for(future, timeout=10)
                    
                    if writer:
                        writer.close()
                        await writer.wait_closed()
                    
                    response_time = time.time() - start_time
                    results.append({
                        'host': host,
                        'port': port,
                        'status': 'success',
                        'response_time': response_time
                    })
                    
                except Exception as e:
                    response_time = time.time() - start_time
                    results.append({
                        'host': host,
                        'port': port,
                        'status': 'failed',
                        'error': str(e),
                        'response_time': response_time
                    })
                    failed_count += 1
            
            # Determine status
            if failed_count == 0:
                status = HealthStatus.HEALTHY
                message = "All network endpoints accessible"
            elif failed_count < len(endpoints) / 2:
                status = HealthStatus.WARNING
                message = f"{failed_count}/{len(endpoints)} endpoints failed"
            else:
                status = HealthStatus.CRITICAL
                message = f"Network connectivity issues: {failed_count}/{len(endpoints)} endpoints failed"
            
            return HealthCheckResult(
                status=status,
                message=message,
                details={
                    "endpoints": results,
                    "failed_count": failed_count,
                    "total_count": len(endpoints)
                }
            )
            
        except Exception as e:
            return HealthCheckResult(
                status=HealthStatus.CRITICAL,
                message=f"Network connectivity check failed: {str(e)}",
                details={"error": str(e)}
            )
    
    async def _check_database(self) -> HealthCheckResult:
        """Check database connectivity"""
        try:
            if not hasattr(self.settings, 'DATABASE_URL'):
                return HealthCheckResult(
                    status=HealthStatus.WARNING,
                    message="Database URL not configured"
                )
            
            start_time = time.time()
            
            # Create engine and test connection
            engine = create_async_engine(self.settings.DATABASE_URL)
            
            async with engine.begin() as conn:
                result = await conn.execute(text("SELECT 1"))
                test_result = result.scalar()
            
            await engine.dispose()
            
            response_time = time.time() - start_time
            
            return HealthCheckResult(
                status=HealthStatus.HEALTHY,
                message="Database connection successful",
                details={
                    "response_time": response_time,
                    "test_result": test_result
                }
            )
            
        except Exception as e:
            return HealthCheckResult(
                status=HealthStatus.CRITICAL,
                message=f"Database connection failed: {str(e)}",
                details={"error": str(e)}
            )
    
    async def _check_redis(self) -> HealthCheckResult:
        """Check Redis connectivity"""
        try:
            if not redis:
                return HealthCheckResult(
                    status=HealthStatus.WARNING,
                    message="Redis client not available"
                )
            
            if not hasattr(self.settings, 'REDIS_URL'):
                return HealthCheckResult(
                    status=HealthStatus.WARNING,
                    message="Redis URL not configured"
                )
            
            start_time = time.time()
            
            client = redis.from_url(self.settings.REDIS_URL)
            await client.ping()
            await client.close()
            
            response_time = time.time() - start_time
            
            return HealthCheckResult(
                status=HealthStatus.HEALTHY,
                message="Redis connection successful",
                details={"response_time": response_time}
            )
            
        except Exception as e:
            return HealthCheckResult(
                status=HealthStatus.CRITICAL,
                message=f"Redis connection failed: {str(e)}",
                details={"error": str(e)}
            )
    
    async def _check_microsoft_graph(self) -> HealthCheckResult:
        """Check Microsoft Graph API connectivity"""
        try:
            start_time = time.time()
            
            # Test Graph API endpoint
            async with httpx.AsyncClient(timeout=30) as client:
                response = await client.get(
                    "https://graph.microsoft.com/v1.0",
                    headers={"Accept": "application/json"}
                )
            
            response_time = time.time() - start_time
            
            if response.status_code in [200, 401]:  # 401 is expected without auth
                status = HealthStatus.HEALTHY
                message = "Microsoft Graph API accessible"
            else:
                status = HealthStatus.WARNING
                message = f"Microsoft Graph API returned status {response.status_code}"
            
            return HealthCheckResult(
                status=status,
                message=message,
                details={
                    "response_time": response_time,
                    "status_code": response.status_code
                }
            )
            
        except Exception as e:
            return HealthCheckResult(
                status=HealthStatus.CRITICAL,
                message=f"Microsoft Graph API check failed: {str(e)}",
                details={"error": str(e)}
            )


# Global health check manager instance
health_manager = HealthCheckManager()


if __name__ == "__main__":
    # Test health checks
    import asyncio
    
    async def test_health_checks():
        """Test health check functionality"""
        print("Testing health check manager...")
        
        manager = HealthCheckManager()
        await manager.initialize()
        
        # Run all checks
        results = await manager.check_all()
        
        print(f"Overall status: {results['status']}")
        print(f"Services checked: {results['summary']['total']}")
        print(f"Healthy: {results['summary']['healthy']}")
        print(f"Warning: {results['summary']['warning']}")
        print(f"Critical: {results['summary']['critical']}")
        
        # Print individual results
        for service, status in results['services'].items():
            print(f"  {service}: {status}")
        
        await manager.close()
        print("Health check test completed")
    
    asyncio.run(test_health_checks())