"""
Health Check API Router - System Health Monitoring
Provides comprehensive health checks for all system components.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from typing import Dict, Any, List
from datetime import datetime
import logging
import psutil
import os

from ..core.database import DatabaseManager, get_db_manager
from ..core.auth import AuthManager, get_auth_manager
from ..dependencies.advanced_dependencies import get_authenticated_user

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/health",
    tags=["Health"],
    responses={
        503: {"description": "Service unavailable"}
    }
)

@router.get("/", summary="Basic health check")
async def health_check():
    """Basic health check endpoint."""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "Microsoft 365 Management Tools API",
        "version": "2.0.0"
    }

@router.get("/detailed", summary="Detailed health check")
async def detailed_health_check(
    db_manager: DatabaseManager = Depends(get_db_manager),
    auth_manager: AuthManager = Depends(get_auth_manager)
):
    """Comprehensive health check with all system components."""
    health_status = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "checks": {}
    }
    
    overall_healthy = True
    
    # Database health
    try:
        db_health = await db_manager.health_check()
        health_status["checks"]["database"] = db_health
        if db_health["status"] != "healthy":
            overall_healthy = False
    except Exception as e:
        health_status["checks"]["database"] = {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }
        overall_healthy = False
    
    # Authentication health
    try:
        auth_health = {
            "status": "healthy" if auth_manager else "unhealthy",
            "timestamp": datetime.utcnow().isoformat()
        }
        health_status["checks"]["authentication"] = auth_health
        if not auth_manager:
            overall_healthy = False
    except Exception as e:
        health_status["checks"]["authentication"] = {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }
        overall_healthy = False
    
    # System resources
    try:
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        system_health = {
            "status": "healthy",
            "cpu_percent": cpu_percent,
            "memory_percent": memory.percent,
            "disk_percent": (disk.used / disk.total) * 100,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Check thresholds
        if cpu_percent > 90 or memory.percent > 90 or (disk.used / disk.total) * 100 > 90:
            system_health["status"] = "warning"
        
        health_status["checks"]["system"] = system_health
    except Exception as e:
        health_status["checks"]["system"] = {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }
        overall_healthy = False
    
    # Set overall status
    health_status["status"] = "healthy" if overall_healthy else "unhealthy"
    
    if not overall_healthy:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=health_status
        )
    
    return health_status

@router.get("/readiness", summary="Readiness probe")
async def readiness_check(
    db_manager: DatabaseManager = Depends(get_db_manager)
):
    """Kubernetes readiness probe."""
    try:
        # Check database connectivity
        db_health = await db_manager.health_check()
        if db_health["status"] != "healthy":
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Database not ready"
            )
        
        return {"status": "ready", "timestamp": datetime.utcnow().isoformat()}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Service not ready: {str(e)}"
        )

@router.get("/liveness", summary="Liveness probe")
async def liveness_check():
    """Kubernetes liveness probe."""
    return {"status": "alive", "timestamp": datetime.utcnow().isoformat()}