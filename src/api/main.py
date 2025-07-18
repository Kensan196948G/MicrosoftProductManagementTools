"""
Microsoft 365 Management Tools - FastAPI Backend
PowerShell → Python Migration

FastAPI backend for Microsoft 365 management tools with full PowerShell compatibility.
Supports Microsoft Graph API, Exchange Online, and enterprise-grade features.
"""

from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from contextlib import asynccontextmanager
import uvicorn
import logging
from typing import Dict, Any, Optional, List
import asyncio
from datetime import datetime
import json

# Core imports
from .core.config import Settings, get_settings
from .core.database import DatabaseManager
from .core.auth import AuthManager
from .core.logging_config import setup_logging
from .core.exceptions import M365Exception, AuthenticationError, APIError

# API routes
from .routes import (
    auth_router,
    users_router,
    reports_router,
    exchange_router,
    teams_router,
    onedrive_router,
    entra_router,
    analytics_router,
    health_router
)

# Initialize logging
logger = logging.getLogger(__name__)

# Global managers
auth_manager: Optional[AuthManager] = None
db_manager: Optional[DatabaseManager] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI lifespan event handler for startup and shutdown.
    Initializes core services and ensures proper cleanup.
    """
    global auth_manager, db_manager
    
    # Startup
    logger.info("Starting Microsoft 365 Management Tools API")
    
    try:
        # Initialize settings
        settings = get_settings()
        
        # Initialize database
        db_manager = DatabaseManager(settings)
        await db_manager.initialize()
        
        # Initialize authentication
        auth_manager = AuthManager(settings)
        await auth_manager.initialize()
        
        # Test Microsoft Graph connectivity
        await auth_manager.test_graph_connection()
        
        logger.info("All services initialized successfully")
        
        yield
        
    except Exception as e:
        logger.error(f"Failed to initialize services: {str(e)}")
        raise
    
    finally:
        # Shutdown
        logger.info("Shutting down Microsoft 365 Management Tools API")
        
        if db_manager:
            await db_manager.close()
        
        if auth_manager:
            await auth_manager.close()


def create_app() -> FastAPI:
    """
    Create and configure the FastAPI application.
    
    Returns:
        FastAPI: Configured application instance
    """
    settings = get_settings()
    
    # Setup logging
    setup_logging(settings)
    
    # Create FastAPI app
    app = FastAPI(
        title="Microsoft 365 Management Tools API",
        description="""
        Enterprise-grade Microsoft 365 management and monitoring API.
        
        ## Features
        - **Real-time Microsoft Graph API integration**
        - **Exchange Online management**
        - **Teams analytics and reporting**
        - **OneDrive monitoring**
        - **Entra ID user management**
        - **Automated report generation**
        - **PowerShell script compatibility**
        
        ## Authentication
        Uses OAuth2 with Microsoft Graph API and certificate-based authentication.
        
        ## Compliance
        - ISO/IEC 20000 (ITSM) compliant
        - ISO/IEC 27001 security standards
        - ISO/IEC 27002 security controls
        """,
        version="2.0.0",
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
        lifespan=lifespan,
        contact={
            "name": "Microsoft 365 Management Tools",
            "url": "https://github.com/your-org/microsoft-365-tools",
            "email": "admin@your-org.com"
        },
        license_info={
            "name": "MIT License",
            "url": "https://opensource.org/licenses/MIT"
        }
    )
    
    # Add CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["*"],
    )
    
    # Add custom exception handlers
    @app.exception_handler(M365Exception)
    async def m365_exception_handler(request: Request, exc: M365Exception):
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": exc.error_code,
                "message": exc.message,
                "details": exc.details,
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    @app.exception_handler(AuthenticationError)
    async def auth_exception_handler(request: Request, exc: AuthenticationError):
        return JSONResponse(
            status_code=401,
            content={
                "error": "authentication_failed",
                "message": str(exc),
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    @app.exception_handler(APIError)
    async def api_exception_handler(request: Request, exc: APIError):
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": "api_error",
                "message": str(exc),
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    # Include API routers
    app.include_router(health_router, prefix="/health", tags=["Health"])
    app.include_router(auth_router, prefix="/auth", tags=["Authentication"])
    app.include_router(users_router, prefix="/users", tags=["Users"])
    app.include_router(reports_router, prefix="/reports", tags=["Reports"])
    app.include_router(exchange_router, prefix="/exchange", tags=["Exchange"])
    app.include_router(teams_router, prefix="/teams", tags=["Teams"])
    app.include_router(onedrive_router, prefix="/onedrive", tags=["OneDrive"])
    app.include_router(entra_router, prefix="/entra", tags=["Entra ID"])
    app.include_router(analytics_router, prefix="/analytics", tags=["Analytics"])
    
    # Root endpoint
    @app.get("/", tags=["Root"])
    async def root():
        """
        Root endpoint providing API information and health status.
        """
        return {
            "name": "Microsoft 365 Management Tools API",
            "version": "2.0.0",
            "status": "healthy",
            "description": "Enterprise Microsoft 365 management and monitoring API",
            "features": [
                "Microsoft Graph API integration",
                "Exchange Online management",
                "Teams analytics",
                "OneDrive monitoring",
                "Entra ID management",
                "Automated reporting",
                "PowerShell compatibility"
            ],
            "endpoints": {
                "health": "/health",
                "docs": "/docs",
                "openapi": "/openapi.json",
                "authentication": "/auth",
                "users": "/users",
                "reports": "/reports",
                "exchange": "/exchange",
                "teams": "/teams",
                "onedrive": "/onedrive",
                "entra": "/entra",
                "analytics": "/analytics"
            },
            "timestamp": datetime.utcnow().isoformat()
        }
    
    # PowerShell compatibility endpoint
    @app.get("/powershell/compatibility", tags=["PowerShell"])
    async def powershell_compatibility():
        """
        PowerShell compatibility information and migration status.
        """
        return {
            "migration_status": "active",
            "compatibility_level": "100%",
            "supported_modules": [
                "RealM365DataProvider",
                "Authentication",
                "ReportGenerator",
                "Common",
                "Logging",
                "ErrorHandling"
            ],
            "api_mapping": {
                "Get-M365AllUsers": "/users",
                "Get-M365LicenseAnalysis": "/analytics/licenses",
                "Get-M365UsageAnalysis": "/analytics/usage",
                "Get-M365DailyReport": "/reports/daily",
                "Get-M365WeeklyReport": "/reports/weekly",
                "Get-M365MonthlyReport": "/reports/monthly",
                "Get-M365YearlyReport": "/reports/yearly"
            },
            "migration_notes": "Full feature parity with PowerShell implementation"
        }
    
    return app


# Dependency injection
def get_auth_manager() -> AuthManager:
    """Get the global authentication manager."""
    if auth_manager is None:
        raise HTTPException(
            status_code=500,
            detail="Authentication manager not initialized"
        )
    return auth_manager


def get_db_manager() -> DatabaseManager:
    """Get the global database manager."""
    if db_manager is None:
        raise HTTPException(
            status_code=500,
            detail="Database manager not initialized"
        )
    return db_manager


# Create the application instance
app = create_app()


if __name__ == "__main__":
    """
    Development server entry point.
    For production, use: uvicorn src.api.main:app --host 0.0.0.0 --port 8000
    """
    settings = get_settings()
    
    uvicorn.run(
        "src.api.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level="info" if not settings.DEBUG else "debug",
        workers=1 if settings.DEBUG else 4
    )