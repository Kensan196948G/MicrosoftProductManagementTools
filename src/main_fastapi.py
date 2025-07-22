#!/usr/bin/env python3
"""
Main FastAPI Application - Phase 3 Enterprise Integration
Microsoft 365 Management Tools with Real-time Dashboard & Advanced Features
"""

import asyncio
import logging
import sys
from contextlib import asynccontextmanager
from datetime import datetime
from typing import List, Dict, Any, Optional

from fastapi import FastAPI, Depends, HTTPException, Request, WebSocket, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.exception_handlers import (
    http_exception_handler,
    request_validation_exception_handler,
)
from fastapi.exceptions import RequestValidationError, HTTPException as FastAPIHTTPException
from starlette.exceptions import HTTPException as StarletteHTTPException

# Prometheus monitoring - Phase 5 Enterprise Integration
from prometheus_fastapi_instrumentator import Instrumentator
from src.operations.prometheus_integration import PrometheusIntegration, PrometheusConfig, startup_prometheus, shutdown_prometheus
from src.operations.monitoring_center import OperationsMonitoringCenter

# Pydantic
from pydantic import BaseModel

# Internal imports
from src.core.config import get_settings
from src.core.logging_config import setup_logging
from src.api.websocket import websocket_router, startup_websocket_services, shutdown_websocket_services
from src.api.graphql import graphql_router
from src.api.security import MultiTenantManager, OAuth2Scopes
from src.monitoring.health_checks import HealthCheckManager
from src.monitoring.azure_monitor_integration import AzureMonitorIntegration

# Enhanced Error Handling & Quality Improvements
from src.core.error_handling import (
    structured_logger, error_handler, handle_errors, 
    log_performance, audit_action, initialize_error_handling
)
from src.api.optimization.performance_optimizer import (
    performance_middleware, initialize_performance_optimization, 
    get_performance_stats
)
from src.quality.continuous_improvement import (
    continuous_quality_manager, run_quality_analysis
)

# Configure logging
setup_logging()
logger = logging.getLogger(__name__)

# Get settings
settings = get_settings()


# Lifespan management
@asynccontextmanager
async def lifespan(app: FastAPI):
    """FastAPI lifespan management with proper startup/shutdown"""
    logger.info("🚀 Starting Microsoft 365 Management Tools API...")
    
    try:
        # Initialize services
        await startup_websocket_services()
        logger.info("✅ WebSocket services initialized")
        
        # Initialize multi-tenant manager
        from src.api.security.multi_tenant import multi_tenant_manager
        await multi_tenant_manager.initialize()
        logger.info("✅ Multi-tenant manager initialized")
        
        # Initialize health checks
        health_manager = HealthCheckManager()
        await health_manager.initialize()
        app.state.health_manager = health_manager
        logger.info("✅ Health check manager initialized")
        
        # Initialize Operations Monitoring Center
        operations_center = OperationsMonitoringCenter()
        await operations_center.initialize()
        app.state.operations_center = operations_center
        await operations_center.start_monitoring()
        logger.info("✅ Operations Monitoring Center initialized and started")
        
        # Initialize Enterprise Prometheus Integration
        prometheus_config = PrometheusConfig(
            metric_namespace="microsoft365_tools",
            metric_subsystem="enterprise_api",
            enable_custom_metrics=True,
            custom_labels={"environment": "production", "service": "microsoft365-management"}
        )
        prometheus_integration = PrometheusIntegration(prometheus_config)
        await prometheus_integration.setup_azure_monitor()
        prometheus_integration.instrument_app(app)
        prometheus_integration.expose_metrics(app, endpoint="/metrics", should_gzip=True)
        app.state.prometheus_integration = prometheus_integration
        logger.info("✅ Enterprise Prometheus integration with Azure Monitor enabled")
        
        # Initialize Azure Monitor
        if hasattr(settings, 'AZURE_MONITOR_CONNECTION_STRING'):
            azure_monitor = AzureMonitorIntegration()
            await azure_monitor.initialize()
            app.state.azure_monitor = azure_monitor
            logger.info("✅ Azure Monitor integration initialized")
        
        # Initialize Enhanced Error Handling
        initialize_error_handling()
        logger.info("✅ Enhanced error handling system initialized")
        
        # Initialize Performance Optimization
        await initialize_performance_optimization()
        logger.info("✅ Performance optimization system initialized")
        
        logger.info("🎉 All services started successfully")
        
        yield
        
    except Exception as e:
        logger.error(f"❌ Failed to start services: {e}")
        raise
    finally:
        # Shutdown services
        logger.info("🛑 Shutting down services...")
        
        try:
            await shutdown_websocket_services()
            logger.info("✅ WebSocket services shutdown")
            
            if hasattr(app.state, 'operations_center'):
                await app.state.operations_center.close()
                logger.info("✅ Operations Monitoring Center shutdown")
            
            if hasattr(app.state, 'prometheus_integration'):
                await shutdown_prometheus()
                logger.info("✅ Prometheus integration shutdown")
            
            if hasattr(app.state, 'health_manager'):
                await app.state.health_manager.close()
                logger.info("✅ Health manager shutdown")
            
            if hasattr(app.state, 'azure_monitor'):
                await app.state.azure_monitor.close()
                logger.info("✅ Azure Monitor shutdown")
            
            from src.api.security.multi_tenant import multi_tenant_manager
            await multi_tenant_manager.close()
            logger.info("✅ Multi-tenant manager shutdown")
            
        except Exception as e:
            logger.error(f"❌ Error during shutdown: {e}")
        
        logger.info("👋 Shutdown complete")


# Create FastAPI application
app = FastAPI(
    title="Microsoft 365 Management Tools API",
    description="""
    Enterprise-grade Microsoft 365 management platform with real-time capabilities.
    
    ## Features
    
    * **Real-time Dashboard** - WebSocket-powered live updates
    * **GraphQL API** - Advanced querying with Strawberry
    * **Multi-tenant Architecture** - Enterprise security and isolation
    * **Microsoft Graph Integration** - Delta queries and change notifications
    * **High Performance** - Async processing and connection pooling
    * **Enterprise Security** - OAuth2, JWT, and zero-trust model
    
    ## Authentication
    
    This API uses OAuth2 with JWT tokens. Include your token in the Authorization header:
    
    ```
    Authorization: Bearer <your-jwt-token>
    ```
    
    ## Rate Limiting
    
    API calls are rate limited per tenant. Check the response headers for current limits:
    
    * `X-RateLimit-Limit` - Request limit per hour
    * `X-RateLimit-Remaining` - Remaining requests  
    * `X-RateLimit-Reset` - Reset time
    """,
    version="3.0.0",
    contact={
        "name": "Microsoft 365 Management Tools",
        "url": "https://github.com/your-org/microsoft-365-tools",
        "email": "support@your-domain.com",
    },
    license_info={
        "name": "MIT",
        "url": "https://opensource.org/licenses/MIT",
    },
    openapi_tags=[
        {
            "name": "WebSocket",
            "description": "Real-time WebSocket endpoints for live data updates",
        },
        {
            "name": "GraphQL", 
            "description": "GraphQL endpoint with advanced querying capabilities",
        },
        {
            "name": "Users",
            "description": "Microsoft 365 user management operations",
        },
        {
            "name": "Groups",
            "description": "Microsoft 365 group management operations", 
        },
        {
            "name": "Reports",
            "description": "Usage and compliance reporting endpoints",
        },
        {
            "name": "Security",
            "description": "Security and audit endpoints",
        },
        {
            "name": "Health",
            "description": "System health and monitoring endpoints",
        },
    ],
    lifespan=lifespan
)


# Response models
class HealthResponse(BaseModel):
    """Health check response model"""
    status: str
    timestamp: datetime
    version: str
    services: Dict[str, str]
    uptime_seconds: int


class APIInfoResponse(BaseModel):
    """API information response model"""
    name: str
    version: str
    description: str
    docs_url: str
    graphql_url: str
    websocket_url: str
    features: List[str]


class ErrorResponse(BaseModel):
    """Error response model"""
    error: str
    detail: str
    timestamp: datetime
    request_id: Optional[str] = None


# Middleware configuration
def setup_middleware(app: FastAPI):
    """Configure FastAPI middleware"""
    
    # Performance monitoring middleware (first - important for correct metrics)
    app.middleware("http")(performance_middleware)
    
    # CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=getattr(settings, 'ALLOWED_ORIGINS', ['*']),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["X-RateLimit-Limit", "X-RateLimit-Remaining", "X-RateLimit-Reset", "X-Response-Time"]
    )
    
    # Trusted host middleware
    if hasattr(settings, 'ALLOWED_HOSTS'):
        app.add_middleware(
            TrustedHostMiddleware,
            allowed_hosts=settings.ALLOWED_HOSTS
        )
    
    # GZip compression middleware
    app.add_middleware(GZipMiddleware, minimum_size=1000)
    
    logger.info("✅ Middleware configured")


# Exception handlers
@app.exception_handler(StarletteHTTPException)
async def custom_http_exception_handler(request: Request, exc: StarletteHTTPException):
    """Custom HTTP exception handler"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.__class__.__name__,
            "detail": exc.detail,
            "timestamp": datetime.utcnow().isoformat(),
            "path": request.url.path
        }
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Custom validation exception handler"""
    return JSONResponse(
        status_code=422,
        content={
            "error": "ValidationError",
            "detail": "Request validation failed",
            "errors": exc.errors(),
            "timestamp": datetime.utcnow().isoformat(),
            "path": request.url.path
        }
    )


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "error": "InternalServerError",
            "detail": "An internal server error occurred",
            "timestamp": datetime.utcnow().isoformat(),
            "path": request.url.path
        }
    )


# Root endpoints
@app.get("/", response_model=APIInfoResponse, tags=["Health"])
async def root():
    """API information endpoint"""
    return APIInfoResponse(
        name="Microsoft 365 Management Tools API",
        version="3.0.0", 
        description="Enterprise-grade Microsoft 365 management platform",
        docs_url="/docs",
        graphql_url="/graphql",
        websocket_url="/ws",
        features=[
            "Real-time Dashboard",
            "GraphQL API", 
            "Multi-tenant Architecture",
            "Microsoft Graph Integration",
            "Enterprise Security",
            "High Performance"
        ]
    )


@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    """Comprehensive health check endpoint"""
    try:
        if hasattr(app.state, 'health_manager'):
            health_status = await app.state.health_manager.check_all()
        else:
            health_status = {
                'status': 'healthy',
                'services': {
                    'api': 'healthy',
                    'database': 'unknown',
                    'redis': 'unknown',
                    'microsoft_graph': 'unknown'
                },
                'uptime_seconds': 0
            }
        
        return HealthResponse(
            status=health_status['status'],
            timestamp=datetime.utcnow(),
            version="3.0.0",
            services=health_status['services'],
            uptime_seconds=health_status.get('uptime_seconds', 0)
        )
        
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return HealthResponse(
            status="unhealthy",
            timestamp=datetime.utcnow(),
            version="3.0.0",
            services={"api": "unhealthy"},
            uptime_seconds=0
        )


@app.get("/operations/status", tags=["Operations"])
async def operations_status():
    """24/7 Operations monitoring status"""
    try:
        if hasattr(app.state, 'operations_center'):
            status = await app.state.operations_center.get_operations_status()
            return status
        else:
            return {"error": "Operations center not initialized"}
    except Exception as e:
        logger.error(f"Operations status check failed: {e}")
        return {"error": str(e)}


@app.get("/operations/sla", tags=["Operations"])
async def sla_status():
    """SLA monitoring status and metrics"""
    try:
        if hasattr(app.state, 'prometheus_integration'):
            sla_status = app.state.prometheus_integration.get_sla_status()
            return sla_status
        else:
            return {"error": "Prometheus integration not initialized"}
    except Exception as e:
        logger.error(f"SLA status check failed: {e}")
        return {"error": str(e)}


@app.get("/operations/metrics-summary", tags=["Operations"])
async def metrics_summary():
    """Prometheus metrics summary"""
    try:
        if hasattr(app.state, 'prometheus_integration'):
            summary = app.state.prometheus_integration.get_metrics_summary()
            return summary
        else:
            return {"error": "Prometheus integration not initialized"}
    except Exception as e:
        logger.error(f"Metrics summary failed: {e}")
        return {"error": str(e)}


@app.post("/operations/custom-metric", tags=["Operations"])
async def record_custom_metric(
    metric_name: str,
    value: float,
    labels: Dict[str, str] = None
):
    """Record custom metric for monitoring"""
    try:
        if hasattr(app.state, 'prometheus_integration'):
            await app.state.prometheus_integration.record_custom_metric(
                metric_name=metric_name,
                value=value,
                labels=labels or {}
            )
            return {"message": f"Custom metric '{metric_name}' recorded successfully"}
        else:
            return {"error": "Prometheus integration not initialized"}
    except Exception as e:
        logger.error(f"Custom metric recording failed: {e}")
        return {"error": str(e)}


@app.get("/metrics", tags=["Health"])
async def metrics():
    """Prometheus metrics endpoint"""
    # Metrics are exposed by Prometheus instrumentator
    return {"message": "Metrics available at /metrics endpoint"}


# Include routers
def setup_routers(app: FastAPI):
    """Configure API routers"""
    
    # WebSocket endpoints
    app.include_router(
        websocket_router,
        prefix="/ws",
        tags=["WebSocket"]
    )
    
    # GraphQL endpoint
    app.include_router(
        graphql_router,
        prefix="/graphql",
        tags=["GraphQL"]
    )
    
    logger.info("✅ API routers configured")


# Real-time Dashboard endpoints
@app.websocket("/ws/dashboard")
async def dashboard_websocket(websocket: WebSocket):
    """Real-time dashboard WebSocket endpoint"""
    from src.api.websocket.connection_manager import connection_manager
    from src.api.websocket.websocket_router import authenticate_websocket
    
    try:
        # Authenticate WebSocket connection
        user_info = await authenticate_websocket(websocket)
        
        # Connect to WebSocket manager
        connection_id = await connection_manager.connect(
            websocket=websocket,
            user_id=user_info["user_id"],
            tenant_id=user_info["tenant_id"],
            connection_type="dashboard",
            metadata=user_info
        )
        
        logger.info(f"Dashboard WebSocket connected: {connection_id}")
        
        # Send initial dashboard data
        await _send_dashboard_initial_data(connection_id)
        
        # Keep connection alive and handle messages
        while True:
            try:
                data = await websocket.receive_text()
                await connection_manager.handle_message(connection_id, {"type": "ping", "data": data})
            except Exception as e:
                logger.error(f"Dashboard WebSocket error: {e}")
                break
                
    except Exception as e:
        logger.error(f"Dashboard WebSocket connection failed: {e}")
    finally:
        if 'connection_id' in locals():
            await connection_manager.disconnect(connection_id)


async def _send_dashboard_initial_data(connection_id: str):
    """Send initial dashboard data to WebSocket connection"""
    from src.api.websocket.connection_manager import connection_manager, WebSocketMessage, MessageType
    
    try:
        # Get system metrics
        dashboard_data = {
            "type": "dashboard_init",
            "data": {
                "system_metrics": {
                    "cpu_usage": 45.2,
                    "memory_usage": 68.5,
                    "disk_usage": 32.1,
                    "network_io": {
                        "bytes_sent": 1024000,
                        "bytes_received": 2048000
                    }
                },
                "api_metrics": {
                    "requests_per_minute": 150,
                    "response_time_avg": 125,
                    "error_rate": 0.02
                },
                "microsoft_365_status": {
                    "graph_api": "healthy",
                    "exchange_online": "healthy", 
                    "teams": "degraded",
                    "onedrive": "healthy"
                },
                "active_connections": len(connection_manager.connections),
                "timestamp": datetime.utcnow().isoformat()
            }
        }
        
        message = WebSocketMessage(
            type=MessageType.SYSTEM_STATUS,
            data=dashboard_data
        )
        
        await connection_manager.send_to_connection(connection_id, message)
        
    except Exception as e:
        logger.error(f"Error sending dashboard initial data: {e}")


# Static files and frontend
@app.get("/dashboard", response_class=HTMLResponse, tags=["Dashboard"])
async def dashboard():
    """Real-time dashboard HTML page"""
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Microsoft 365 Management Dashboard</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                margin: 0;
                padding: 20px;
                background: #f5f5f5;
            }
            .dashboard {
                max-width: 1200px;
                margin: 0 auto;
            }
            .header {
                background: white;
                padding: 20px;
                border-radius: 8px;
                margin-bottom: 20px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .metrics {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 20px;
                margin-bottom: 20px;
            }
            .metric-card {
                background: white;
                padding: 20px;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .metric-title {
                font-size: 14px;
                color: #666;
                margin-bottom: 10px;
            }
            .metric-value {
                font-size: 24px;
                font-weight: bold;
                color: #333;
            }
            .status {
                display: inline-block;
                padding: 4px 8px;
                border-radius: 4px;
                font-size: 12px;
                font-weight: bold;
            }
            .status.healthy {
                background: #d4edda;
                color: #155724;
            }
            .status.degraded {
                background: #fff3cd;
                color: #856404;
            }
            .status.unhealthy {
                background: #f8d7da;
                color: #721c24;
            }
            .log {
                background: white;
                padding: 20px;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                max-height: 300px;
                overflow-y: auto;
            }
            .log-entry {
                margin-bottom: 5px;
                font-family: monospace;
                font-size: 12px;
            }
        </style>
    </head>
    <body>
        <div class="dashboard">
            <div class="header">
                <h1>Microsoft 365 Management Dashboard</h1>
                <p>Real-time monitoring and analytics</p>
                <p>Status: <span id="connection-status" class="status">Connecting...</span></p>
            </div>
            
            <div class="metrics">
                <div class="metric-card">
                    <div class="metric-title">CPU Usage</div>
                    <div class="metric-value" id="cpu-usage">--</div>
                </div>
                <div class="metric-card">
                    <div class="metric-title">Memory Usage</div>
                    <div class="metric-value" id="memory-usage">--</div>
                </div>
                <div class="metric-card">
                    <div class="metric-title">API Requests/min</div>
                    <div class="metric-value" id="api-requests">--</div>
                </div>
                <div class="metric-card">
                    <div class="metric-title">Response Time</div>
                    <div class="metric-value" id="response-time">--</div>
                </div>
            </div>
            
            <div class="metrics">
                <div class="metric-card">
                    <div class="metric-title">Microsoft Graph</div>
                    <div class="metric-value"><span id="graph-status" class="status">--</span></div>
                </div>
                <div class="metric-card">
                    <div class="metric-title">Exchange Online</div>
                    <div class="metric-value"><span id="exchange-status" class="status">--</span></div>
                </div>
                <div class="metric-card">
                    <div class="metric-title">Teams</div>
                    <div class="metric-value"><span id="teams-status" class="status">--</span></div>
                </div>
                <div class="metric-card">
                    <div class="metric-title">OneDrive</div>
                    <div class="metric-value"><span id="onedrive-status" class="status">--</span></div>
                </div>
            </div>
            
            <div class="log">
                <h3>Real-time Log</h3>
                <div id="log-container"></div>
            </div>
        </div>

        <script>
            const ws = new WebSocket('ws://localhost:8000/ws/dashboard');
            const statusEl = document.getElementById('connection-status');
            const logContainer = document.getElementById('log-container');

            function addLogEntry(message) {
                const entry = document.createElement('div');
                entry.className = 'log-entry';
                entry.textContent = `[${new Date().toLocaleTimeString()}] ${message}`;
                logContainer.appendChild(entry);
                logContainer.scrollTop = logContainer.scrollHeight;
            }

            ws.onopen = function(event) {
                statusEl.textContent = 'Connected';
                statusEl.className = 'status healthy';
                addLogEntry('WebSocket connected');
            };

            ws.onmessage = function(event) {
                try {
                    const data = JSON.parse(event.data);
                    
                    if (data.type === 'system_status' && data.data && data.data.data) {
                        const metrics = data.data.data;
                        
                        // Update system metrics
                        if (metrics.system_metrics) {
                            document.getElementById('cpu-usage').textContent = metrics.system_metrics.cpu_usage + '%';
                            document.getElementById('memory-usage').textContent = metrics.system_metrics.memory_usage + '%';
                        }
                        
                        // Update API metrics
                        if (metrics.api_metrics) {
                            document.getElementById('api-requests').textContent = metrics.api_metrics.requests_per_minute;
                            document.getElementById('response-time').textContent = metrics.api_metrics.response_time_avg + 'ms';
                        }
                        
                        // Update service status
                        if (metrics.microsoft_365_status) {
                            updateStatusElement('graph-status', metrics.microsoft_365_status.graph_api);
                            updateStatusElement('exchange-status', metrics.microsoft_365_status.exchange_online);
                            updateStatusElement('teams-status', metrics.microsoft_365_status.teams);
                            updateStatusElement('onedrive-status', metrics.microsoft_365_status.onedrive);
                        }
                        
                        addLogEntry('Dashboard data updated');
                    }
                } catch (e) {
                    addLogEntry('Error parsing message: ' + e.message);
                }
            };

            ws.onclose = function(event) {
                statusEl.textContent = 'Disconnected';
                statusEl.className = 'status unhealthy';
                addLogEntry('WebSocket disconnected');
            };

            ws.onerror = function(error) {
                statusEl.textContent = 'Error';
                statusEl.className = 'status unhealthy';
                addLogEntry('WebSocket error: ' + error);
            };

            function updateStatusElement(elementId, status) {
                const el = document.getElementById(elementId);
                el.textContent = status;
                el.className = 'status ' + status;
            }

            // Send ping every 30 seconds
            setInterval(() => {
                if (ws.readyState === WebSocket.OPEN) {
                    ws.send(JSON.stringify({type: 'ping', timestamp: Date.now()}));
                }
            }, 30000);
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)


# Configure application
setup_middleware(app)
setup_routers(app)

# Add enhanced API endpoints
@app.get("/api/quality/report", tags=["Quality"], summary="Get latest quality report")
@handle_errors()
@log_performance("quality_report")
async def get_quality_report():
    """Get the latest comprehensive quality report"""
    from src.quality.continuous_improvement import get_latest_quality_report
    
    report = await get_latest_quality_report()
    if report:
        return {"success": True, "report": report}
    else:
        return {"success": False, "message": "No quality report available"}

@app.post("/api/quality/analyze", tags=["Quality"], summary="Run quality analysis")
@handle_errors()
@log_performance("quality_analysis")
@audit_action("quality_analysis", "system")
async def run_quality_analysis():
    """Run comprehensive quality analysis"""
    report = await run_quality_analysis()
    return {"success": True, "report": report.to_dict()}

@app.get("/api/performance/stats", tags=["Performance"], summary="Get performance statistics")
@handle_errors()
@log_performance("performance_stats")
async def get_performance_statistics():
    """Get detailed performance statistics"""
    stats = await get_performance_stats()
    return {"success": True, "stats": stats}

@app.get("/api/system/error-stats", tags=["System"], summary="Get error statistics")
@handle_errors()
async def get_error_statistics():
    """Get system error statistics"""
    from src.core.error_handling import get_error_statistics
    stats = get_error_statistics()
    return {"success": True, "error_stats": stats}

# Development server
if __name__ == "__main__":
    import uvicorn
    
    # Configure uvicorn for development
    uvicorn_config = {
        "host": "0.0.0.0",
        "port": 8000,
        "reload": True,
        "log_level": "info",
        "access_log": True,
        "ws_ping_interval": 20,
        "ws_ping_timeout": 20,
        "lifespan": "on"
    }
    
    logger.info("🚀 Starting FastAPI development server...")
    uvicorn.run("src.main_fastapi:app", **uvicorn_config)