#!/usr/bin/env python3
"""
Prometheus FastAPI Integration - CTO技術監督評価承認対応
Microsoft 365 Management Tools - Enterprise監視基盤強化

Features:
- Prometheus FastAPI Instrumentator統合
- Microsoft Graph API メトリクス収集
- カスタムメトリクス定義・追跡
- 多層監視アーキテクチャ
- Context7最新技術適用

Author: Operations Manager - CTO技術監督評価承認対応
Version: 1.0.0 CTO-APPROVED
Date: 2025-07-19
"""

import asyncio
import logging
import time
from typing import Dict, List, Optional, Any, Callable
from datetime import datetime
from pathlib import Path

try:
    from fastapi import FastAPI, Request, Response
    from prometheus_fastapi_instrumentator import Instrumentator, metrics
    from prometheus_fastapi_instrumentator.metrics import Info
    from prometheus_client import Counter, Histogram, Gauge, CollectorRegistry, REGISTRY
    import uvicorn
    import psutil
except ImportError as e:
    print(f"⚠️ FastAPI/Prometheus dependencies not available: {e}")
    print("Install with: pip install fastapi prometheus-fastapi-instrumentator uvicorn psutil")

# Configure logging for enterprise monitoring
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[
        logging.FileHandler('/var/log/microsoft365-prometheus.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class Microsoft365PrometheusIntegration:
    """
    Enterprise-grade Prometheus FastAPI統合
    CTO技術監督評価承認レベル実装
    """
    
    def __init__(self, 
                 app: Optional[FastAPI] = None,
                 metric_namespace: str = "microsoft365",
                 metric_subsystem: str = "management"):
        """
        初期化
        
        Args:
            app: FastAPI application instance
            metric_namespace: Prometheus metrics namespace
            metric_subsystem: Prometheus metrics subsystem
        """
        self.app = app or self._create_fastapi_app()
        self.metric_namespace = metric_namespace
        self.metric_subsystem = metric_subsystem
        
        # Prometheus Instrumentator initialization
        self.instrumentator = Instrumentator(
            should_group_status_codes=False,
            should_ignore_untemplated=True,
            should_respect_env_var=True,
            should_instrument_requests_inprogress=True,
            excluded_handlers=[".*admin.*", "/metrics", "/health"],
            env_var_name="ENABLE_PROMETHEUS_METRICS",
            inprogress_name="microsoft365_requests_inprogress",
            inprogress_labels=True,
            custom_labels={
                "service": "microsoft365_management",
                "component": "enterprise_monitoring",
                "version": "1.0.0"
            }
        )
        
        # Custom metrics registry
        self.custom_metrics = {}
        self._init_custom_metrics()
        
        logger.info("✅ Microsoft 365 Prometheus Integration initialized")
    
    def _create_fastapi_app(self) -> FastAPI:
        """Create FastAPI application for metrics exposure"""
        app = FastAPI(
            title="Microsoft 365 Management Tools - Prometheus Metrics",
            description="Enterprise monitoring and metrics collection",
            version="1.0.0",
            docs_url="/docs",
            redoc_url="/redoc"
        )
        
        @app.get("/health")
        async def health_check():
            """Health check endpoint"""
            return {
                "status": "healthy",
                "timestamp": datetime.utcnow().isoformat(),
                "service": "microsoft365_prometheus_integration",
                "version": "1.0.0"
            }
        
        @app.get("/ping")
        async def ping():
            """Simple ping endpoint for testing"""
            return {"message": "pong", "timestamp": datetime.utcnow().isoformat()}
        
        return app
    
    def _init_custom_metrics(self):
        """Initialize custom Prometheus metrics for Microsoft 365"""
        
        # Microsoft Graph API metrics
        self.custom_metrics['graph_api_requests'] = Counter(
            f'{self.metric_namespace}_{self.metric_subsystem}_graph_api_requests_total',
            'Total Microsoft Graph API requests',
            labelnames=['operation', 'status', 'service']
        )
        
        self.custom_metrics['graph_api_latency'] = Histogram(
            f'{self.metric_namespace}_{self.metric_subsystem}_graph_api_duration_seconds',
            'Microsoft Graph API request duration',
            labelnames=['operation', 'service'],
            buckets=(0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 25.0, 50.0, 100.0)
        )
        
        # User activity metrics
        self.custom_metrics['user_activities'] = Counter(
            f'{self.metric_namespace}_{self.metric_subsystem}_user_activities_total',
            'Total user activities tracked',
            labelnames=['activity_type', 'service', 'user_type']
        )
        
        # License metrics
        self.custom_metrics['license_usage'] = Gauge(
            f'{self.metric_namespace}_{self.metric_subsystem}_license_usage_current',
            'Current license usage',
            labelnames=['license_type', 'status']
        )
        
        # System performance metrics
        self.custom_metrics['system_cpu'] = Gauge(
            f'{self.metric_namespace}_{self.metric_subsystem}_system_cpu_percent',
            'System CPU usage percentage'
        )
        
        self.custom_metrics['system_memory'] = Gauge(
            f'{self.metric_namespace}_{self.metric_subsystem}_system_memory_percent',
            'System memory usage percentage'
        )
        
        # GUI interaction metrics
        self.custom_metrics['gui_interactions'] = Counter(
            f'{self.metric_namespace}_{self.metric_subsystem}_gui_interactions_total',
            'Total GUI interactions',
            labelnames=['action', 'component', 'success']
        )
        
        # Report generation metrics
        self.custom_metrics['report_generation'] = Histogram(
            f'{self.metric_namespace}_{self.metric_subsystem}_report_generation_duration_seconds',
            'Report generation duration',
            labelnames=['report_type', 'format'],
            buckets=(1.0, 5.0, 10.0, 30.0, 60.0, 120.0, 300.0, 600.0)
        )
        
        # WebSocket connection metrics
        self.custom_metrics['websocket_connections'] = Gauge(
            f'{self.metric_namespace}_{self.metric_subsystem}_websocket_connections_active',
            'Active WebSocket connections'
        )
        
        logger.info(f"📊 Initialized {len(self.custom_metrics)} custom metrics")
    
    def setup_instrumentator(self):
        """Setup Prometheus instrumentator with custom metrics"""
        
        # Add default metrics with custom configuration
        self.instrumentator.add(
            metrics.latency(
                buckets=(0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 25.0, 50.0, 100.0),
                metric_namespace=self.metric_namespace,
                metric_subsystem=self.metric_subsystem
            )
        )
        
        self.instrumentator.add(
            metrics.request_size(
                should_include_handler=True,
                should_include_method=True,
                should_include_status=True,
                metric_namespace=self.metric_namespace,
                metric_subsystem=self.metric_subsystem,
                custom_labels={"service": "microsoft365_management"}
            )
        )
        
        self.instrumentator.add(
            metrics.response_size(
                should_include_handler=True,
                should_include_method=True,
                should_include_status=True,
                metric_namespace=self.metric_namespace,
                metric_subsystem=self.metric_subsystem,
                custom_labels={"service": "microsoft365_management"}
            )
        )
        
        # Add custom Microsoft 365 specific metrics
        self.instrumentator.add(self._microsoft_graph_metrics())
        self.instrumentator.add(self._user_activity_metrics())
        self.instrumentator.add(self._system_performance_metrics())
        
        logger.info("🔧 Prometheus instrumentator configured with custom metrics")
    
    def _microsoft_graph_metrics(self) -> Callable[[Info], None]:
        """Custom metric for Microsoft Graph API monitoring"""
        
        def instrumentation(info: Info) -> None:
            # Extract Microsoft Graph API operation from request path
            request_path = str(info.request.url.path)
            
            if "/graph/" in request_path:
                # Extract operation type from Graph API path
                path_parts = request_path.split("/")
                operation = "unknown"
                service = "graph"
                
                if "users" in path_parts:
                    operation = "users"
                elif "groups" in path_parts:
                    operation = "groups"
                elif "teams" in path_parts:
                    operation = "teams"
                    service = "teams"
                elif "sites" in path_parts:
                    operation = "sharepoint"
                    service = "sharepoint"
                elif "me" in path_parts:
                    operation = "profile"
                
                # Record API request
                status = "success" if info.response.status_code < 400 else "error"
                self.custom_metrics['graph_api_requests'].labels(
                    operation=operation,
                    status=status,
                    service=service
                ).inc()
                
                # Record latency if modified_duration is available
                if hasattr(info, 'modified_duration') and info.modified_duration:
                    self.custom_metrics['graph_api_latency'].labels(
                        operation=operation,
                        service=service
                    ).observe(info.modified_duration)
        
        return instrumentation
    
    def _user_activity_metrics(self) -> Callable[[Info], None]:
        """Custom metric for user activity tracking"""
        
        def instrumentation(info: Info) -> None:
            request_path = str(info.request.url.path)
            
            # Track different types of user activities
            if "/api/activities" in request_path:
                activity_type = "general"
                user_type = "standard"
                
                # Extract activity type from query parameters
                query_params = dict(info.request.query_params)
                if "type" in query_params:
                    activity_type = query_params["type"]
                if "user_type" in query_params:
                    user_type = query_params["user_type"]
                
                service = "microsoft365"
                if "teams" in request_path:
                    service = "teams"
                elif "sharepoint" in request_path:
                    service = "sharepoint"
                elif "onedrive" in request_path:
                    service = "onedrive"
                
                self.custom_metrics['user_activities'].labels(
                    activity_type=activity_type,
                    service=service,
                    user_type=user_type
                ).inc()
        
        return instrumentation
    
    def _system_performance_metrics(self) -> Callable[[Info], None]:
        """Custom metric for system performance monitoring"""
        
        def instrumentation(info: Info) -> None:
            # Update system metrics periodically (not on every request)
            if hasattr(self, '_last_system_update'):
                if time.time() - self._last_system_update < 30:  # Update every 30 seconds
                    return
            
            try:
                # CPU usage
                cpu_percent = psutil.cpu_percent(interval=None)
                self.custom_metrics['system_cpu'].set(cpu_percent)
                
                # Memory usage
                memory = psutil.virtual_memory()
                self.custom_metrics['system_memory'].set(memory.percent)
                
                self._last_system_update = time.time()
                
            except Exception as e:
                logger.error(f"Failed to update system metrics: {e}")
        
        return instrumentation
    
    def instrument_app(self):
        """Instrument FastAPI application with Prometheus metrics"""
        try:
            # Setup custom metrics first
            self.setup_instrumentator()
            
            # Instrument the app
            self.instrumentator.instrument(
                self.app,
                metric_namespace=self.metric_namespace,
                metric_subsystem=self.metric_subsystem
            )
            
            logger.info("🎯 FastAPI application instrumented successfully")
            
        except Exception as e:
            logger.error(f"Failed to instrument FastAPI app: {e}")
            raise
    
    def expose_metrics(self, 
                      endpoint: str = "/metrics",
                      include_in_schema: bool = False,
                      should_gzip: bool = True):
        """Expose Prometheus metrics endpoint"""
        try:
            self.instrumentator.expose(
                self.app,
                endpoint=endpoint,
                include_in_schema=include_in_schema,
                should_gzip=should_gzip
            )
            
            logger.info(f"📊 Prometheus metrics exposed at {endpoint}")
            
        except Exception as e:
            logger.error(f"Failed to expose metrics: {e}")
            raise
    
    def initialize_monitoring(self):
        """Initialize complete monitoring setup"""
        try:
            # Instrument application
            self.instrument_app()
            
            # Expose metrics endpoint
            self.expose_metrics()
            
            # Add startup event for additional initialization
            @self.app.on_event("startup")
            async def startup_monitoring():
                logger.info("🚀 Microsoft 365 Prometheus monitoring started")
                
                # Initialize system metrics
                self._last_system_update = 0
                
                # Start background monitoring tasks
                asyncio.create_task(self._background_metrics_collector())
            
            @self.app.on_event("shutdown")
            async def shutdown_monitoring():
                logger.info("🛑 Microsoft 365 Prometheus monitoring stopped")
            
            logger.info("✅ Complete monitoring setup initialized")
            
        except Exception as e:
            logger.error(f"Failed to initialize monitoring: {e}")
            raise
    
    async def _background_metrics_collector(self):
        """Background task for collecting periodic metrics"""
        while True:
            try:
                await asyncio.sleep(60)  # Collect every minute
                
                # Update system performance metrics
                cpu_percent = psutil.cpu_percent(interval=1)
                memory = psutil.virtual_memory()
                
                self.custom_metrics['system_cpu'].set(cpu_percent)
                self.custom_metrics['system_memory'].set(memory.percent)
                
                logger.debug(f"📊 System metrics updated: CPU={cpu_percent:.1f}%, Memory={memory.percent:.1f}%")
                
            except Exception as e:
                logger.error(f"Background metrics collection error: {e}")
    
    def record_graph_api_call(self, 
                             operation: str, 
                             service: str = "graph",
                             duration: float = None,
                             success: bool = True):
        """Record Microsoft Graph API call metrics"""
        try:
            status = "success" if success else "error"
            
            self.custom_metrics['graph_api_requests'].labels(
                operation=operation,
                status=status,
                service=service
            ).inc()
            
            if duration is not None:
                self.custom_metrics['graph_api_latency'].labels(
                    operation=operation,
                    service=service
                ).observe(duration)
            
            logger.debug(f"📊 Graph API call recorded: {operation} ({status})")
            
        except Exception as e:
            logger.error(f"Failed to record Graph API metrics: {e}")
    
    def record_user_activity(self, 
                           activity_type: str,
                           service: str = "microsoft365",
                           user_type: str = "standard"):
        """Record user activity metrics"""
        try:
            self.custom_metrics['user_activities'].labels(
                activity_type=activity_type,
                service=service,
                user_type=user_type
            ).inc()
            
            logger.debug(f"📊 User activity recorded: {activity_type} ({service})")
            
        except Exception as e:
            logger.error(f"Failed to record user activity metrics: {e}")
    
    def update_license_usage(self, 
                           license_type: str,
                           current_usage: int,
                           status: str = "active"):
        """Update license usage metrics"""
        try:
            self.custom_metrics['license_usage'].labels(
                license_type=license_type,
                status=status
            ).set(current_usage)
            
            logger.debug(f"📊 License usage updated: {license_type} = {current_usage}")
            
        except Exception as e:
            logger.error(f"Failed to update license metrics: {e}")
    
    def record_gui_interaction(self,
                             action: str,
                             component: str,
                             success: bool = True):
        """Record GUI interaction metrics"""
        try:
            success_label = "true" if success else "false"
            
            self.custom_metrics['gui_interactions'].labels(
                action=action,
                component=component,
                success=success_label
            ).inc()
            
            logger.debug(f"📊 GUI interaction recorded: {action} on {component}")
            
        except Exception as e:
            logger.error(f"Failed to record GUI interaction metrics: {e}")
    
    def record_report_generation(self,
                               report_type: str,
                               format: str,
                               duration: float):
        """Record report generation metrics"""
        try:
            self.custom_metrics['report_generation'].labels(
                report_type=report_type,
                format=format
            ).observe(duration)
            
            logger.debug(f"📊 Report generation recorded: {report_type} ({format}) - {duration:.2f}s")
            
        except Exception as e:
            logger.error(f"Failed to record report generation metrics: {e}")
    
    def update_websocket_connections(self, active_connections: int):
        """Update WebSocket connection count"""
        try:
            self.custom_metrics['websocket_connections'].set(active_connections)
            
            logger.debug(f"📊 WebSocket connections updated: {active_connections}")
            
        except Exception as e:
            logger.error(f"Failed to update WebSocket metrics: {e}")
    
    def get_metrics_summary(self) -> Dict[str, Any]:
        """Get summary of current metrics"""
        try:
            summary = {
                "timestamp": datetime.utcnow().isoformat(),
                "namespace": self.metric_namespace,
                "subsystem": self.metric_subsystem,
                "metrics_count": len(self.custom_metrics),
                "available_metrics": list(self.custom_metrics.keys()),
                "app_instrumented": self.instrumentator is not None
            }
            
            return summary
            
        except Exception as e:
            logger.error(f"Failed to get metrics summary: {e}")
            return {"error": str(e)}


# Global integration instance
prometheus_integration = Microsoft365PrometheusIntegration()


def create_monitored_app() -> FastAPI:
    """Create FastAPI app with full Prometheus monitoring"""
    integration = Microsoft365PrometheusIntegration(
        metric_namespace="microsoft365",
        metric_subsystem="enterprise"
    )
    
    integration.initialize_monitoring()
    
    return integration.app


async def run_prometheus_server(host: str = "0.0.0.0", port: int = 8000):
    """Run Prometheus metrics server"""
    app = create_monitored_app()
    
    config = uvicorn.Config(
        app,
        host=host,
        port=port,
        log_level="info",
        access_log=True
    )
    
    server = uvicorn.Server(config)
    
    logger.info(f"🚀 Starting Prometheus FastAPI server on {host}:{port}")
    await server.serve()


if __name__ == "__main__":
    print("🔧 Microsoft 365 Prometheus FastAPI Integration - CTO技術監督評価承認")
    print("Starting enterprise monitoring server...")
    
    try:
        asyncio.run(run_prometheus_server())
    except KeyboardInterrupt:
        print("\n⚠️ Server stopped by user")
    except Exception as e:
        print(f"❌ Server error: {e}")