#!/usr/bin/env python3
"""
WebSocket Router - Phase 3 Advanced Integration
FastAPI WebSocket endpoints with authentication and real-time features
"""

import asyncio
import json
import logging
from typing import Optional, Dict, Any
from datetime import datetime

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
import redis.asyncio as redis

from .connection_manager import ConnectionManager, ConnectionType, MessageType, WebSocketMessage
from .realtime_events import RealtimeEventManager
from src.core.auth.authenticator import get_current_user_from_token
from src.core.config import get_settings

logger = logging.getLogger(__name__)

# Router instance
websocket_router = APIRouter(prefix="/ws", tags=["websocket"])

# Global instances
connection_manager = ConnectionManager()
event_manager = RealtimeEventManager()

# Security
security = HTTPBearer(auto_error=False)


async def authenticate_websocket(websocket: WebSocket, token: Optional[str] = None):
    """
    Authenticate WebSocket connection
    
    Args:
        websocket: WebSocket instance
        token: JWT token from query parameter or header
        
    Returns:
        User information dictionary
        
    Raises:
        WebSocketDisconnect: If authentication fails
    """
    if not token:
        # Try to get token from query parameters
        token = websocket.query_params.get("token")
    
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Missing authentication token")
        raise WebSocketDisconnect(code=status.WS_1008_POLICY_VIOLATION, reason="Authentication required")
    
    try:
        # Verify JWT token
        settings = get_settings()
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id = payload.get("sub")
        tenant_id = payload.get("tenant_id")
        
        if not user_id:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Invalid token")
            raise WebSocketDisconnect(code=status.WS_1008_POLICY_VIOLATION, reason="Invalid token")
        
        return {
            "user_id": user_id,
            "tenant_id": tenant_id,
            "username": payload.get("username"),
            "permissions": payload.get("permissions", []),
            "roles": payload.get("roles", [])
        }
        
    except JWTError as e:
        logger.warning(f"WebSocket authentication failed: {e}")
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Invalid token")
        raise WebSocketDisconnect(code=status.WS_1008_POLICY_VIOLATION, reason="Authentication failed")


@websocket_router.websocket("/realtime")
async def websocket_realtime_endpoint(websocket: WebSocket, token: Optional[str] = None):
    """
    Real-time data updates WebSocket endpoint
    
    Features:
    - Microsoft 365 data updates
    - Delta query change notifications
    - Multi-tenant support
    - Subscription-based filtering
    """
    connection_id = None
    
    try:
        # Authenticate user
        user_info = await authenticate_websocket(websocket, token)
        user_id = user_info["user_id"]
        tenant_id = user_info["tenant_id"]
        
        # Connect to WebSocket
        connection_id = await connection_manager.connect(
            websocket=websocket,
            user_id=user_id,
            tenant_id=tenant_id,
            connection_type=ConnectionType.REALTIME_UPDATES,
            metadata=user_info
        )
        
        logger.info(f"Real-time WebSocket connected: {connection_id}")
        
        # Send initial data
        await _send_initial_data(connection_id, user_info)
        
        # Handle incoming messages
        while True:
            try:
                data = await websocket.receive_text()
                message_data = json.loads(data)
                await connection_manager.handle_message(connection_id, message_data)
                
            except WebSocketDisconnect:
                break
            except json.JSONDecodeError as e:
                logger.warning(f"Invalid JSON from {connection_id}: {e}")
                error_message = WebSocketMessage(
                    type=MessageType.ERROR,
                    data={"error": "Invalid JSON format"}
                )
                await connection_manager.send_to_connection(connection_id, error_message)
            except Exception as e:
                logger.error(f"Error in realtime WebSocket {connection_id}: {e}")
                error_message = WebSocketMessage(
                    type=MessageType.ERROR,
                    data={"error": str(e)}
                )
                await connection_manager.send_to_connection(connection_id, error_message)
    
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.error(f"Unexpected error in realtime WebSocket: {e}")
    finally:
        if connection_id:
            await connection_manager.disconnect(connection_id)


@websocket_router.websocket("/dashboard")
async def websocket_dashboard_endpoint(websocket: WebSocket, token: Optional[str] = None):
    """
    Dashboard WebSocket endpoint for real-time monitoring
    
    Features:
    - System status updates
    - Performance metrics
    - Security alerts
    - Administrative notifications
    """
    connection_id = None
    
    try:
        # Authenticate user
        user_info = await authenticate_websocket(websocket, token)
        user_id = user_info["user_id"]
        tenant_id = user_info["tenant_id"]
        
        # Check dashboard permissions
        if "dashboard.view" not in user_info.get("permissions", []):
            await websocket.close(code=status.WS_1003_UNSUPPORTED_DATA, reason="Insufficient permissions")
            return
        
        # Connect to WebSocket
        connection_id = await connection_manager.connect(
            websocket=websocket,
            user_id=user_id,
            tenant_id=tenant_id,
            connection_type=ConnectionType.DASHBOARD,
            metadata=user_info
        )
        
        logger.info(f"Dashboard WebSocket connected: {connection_id}")
        
        # Send dashboard data
        await _send_dashboard_data(connection_id, user_info)
        
        # Handle incoming messages
        while True:
            try:
                data = await websocket.receive_text()
                message_data = json.loads(data)
                await connection_manager.handle_message(connection_id, message_data)
                
            except WebSocketDisconnect:
                break
            except Exception as e:
                logger.error(f"Error in dashboard WebSocket {connection_id}: {e}")
    
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.error(f"Unexpected error in dashboard WebSocket: {e}")
    finally:
        if connection_id:
            await connection_manager.disconnect(connection_id)


@websocket_router.websocket("/notifications")
async def websocket_notifications_endpoint(websocket: WebSocket, token: Optional[str] = None):
    """
    Notifications WebSocket endpoint
    
    Features:
    - User-specific notifications
    - System alerts
    - Change notifications
    - Push notifications
    """
    connection_id = None
    
    try:
        # Authenticate user
        user_info = await authenticate_websocket(websocket, token)
        user_id = user_info["user_id"]
        tenant_id = user_info["tenant_id"]
        
        # Connect to WebSocket
        connection_id = await connection_manager.connect(
            websocket=websocket,
            user_id=user_id,
            tenant_id=tenant_id,
            connection_type=ConnectionType.NOTIFICATIONS,
            metadata=user_info
        )
        
        logger.info(f"Notifications WebSocket connected: {connection_id}")
        
        # Subscribe to user-specific notifications
        await connection_manager.subscribe(connection_id, f"user:{user_id}")
        if tenant_id:
            await connection_manager.subscribe(connection_id, f"tenant:{tenant_id}")
        
        # Send notification history
        await _send_notification_history(connection_id, user_info)
        
        # Handle incoming messages
        while True:
            try:
                data = await websocket.receive_text()
                message_data = json.loads(data)
                await connection_manager.handle_message(connection_id, message_data)
                
            except WebSocketDisconnect:
                break
            except Exception as e:
                logger.error(f"Error in notifications WebSocket {connection_id}: {e}")
    
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.error(f"Unexpected error in notifications WebSocket: {e}")
    finally:
        if connection_id:
            await connection_manager.disconnect(connection_id)


@websocket_router.websocket("/monitoring")
async def websocket_monitoring_endpoint(websocket: WebSocket, token: Optional[str] = None):
    """
    System monitoring WebSocket endpoint
    
    Features:
    - Performance metrics
    - Health checks
    - Resource usage
    - Error monitoring
    """
    connection_id = None
    
    try:
        # Authenticate user
        user_info = await authenticate_websocket(websocket, token)
        user_id = user_info["user_id"]
        tenant_id = user_info["tenant_id"]
        
        # Check monitoring permissions
        if "system.monitor" not in user_info.get("permissions", []):
            await websocket.close(code=status.WS_1003_UNSUPPORTED_DATA, reason="Insufficient permissions")
            return
        
        # Connect to WebSocket
        connection_id = await connection_manager.connect(
            websocket=websocket,
            user_id=user_id,
            tenant_id=tenant_id,
            connection_type=ConnectionType.MONITORING,
            metadata=user_info
        )
        
        logger.info(f"Monitoring WebSocket connected: {connection_id}")
        
        # Subscribe to monitoring data
        await connection_manager.subscribe(connection_id, "system:monitoring")
        await connection_manager.subscribe(connection_id, "performance:metrics")
        
        # Send current system status
        await _send_system_status(connection_id, user_info)
        
        # Handle incoming messages
        while True:
            try:
                data = await websocket.receive_text()
                message_data = json.loads(data)
                await connection_manager.handle_message(connection_id, message_data)
                
            except WebSocketDisconnect:
                break
            except Exception as e:
                logger.error(f"Error in monitoring WebSocket {connection_id}: {e}")
    
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.error(f"Unexpected error in monitoring WebSocket: {e}")
    finally:
        if connection_id:
            await connection_manager.disconnect(connection_id)


# Helper functions

async def _send_initial_data(connection_id: str, user_info: Dict[str, Any]):
    """Send initial data to real-time connection"""
    try:
        # Get recent Microsoft 365 data
        from src.api.microsoft_graph_client import create_graph_client
        
        async with create_graph_client(async_mode=True) as graph_client:
            # Get user data
            users_data = await graph_client.get_users_async(top=10)
            
            # Get groups data
            groups_data = await graph_client.get_groups_async(top=10)
            
            initial_data = {
                "users": users_data,
                "groups": groups_data,
                "last_updated": datetime.utcnow().isoformat(),
                "connection_info": {
                    "connection_id": connection_id,
                    "user_id": user_info["user_id"],
                    "tenant_id": user_info["tenant_id"]
                }
            }
            
            message = WebSocketMessage(
                type=MessageType.DATA_UPDATE,
                data=initial_data
            )
            
            await connection_manager.send_to_connection(connection_id, message)
            
    except Exception as e:
        logger.error(f"Error sending initial data: {e}")


async def _send_dashboard_data(connection_id: str, user_info: Dict[str, Any]):
    """Send dashboard data"""
    try:
        # Get connection statistics
        stats = connection_manager.get_connection_stats()
        
        # Get system metrics (simulated)
        dashboard_data = {
            "connection_stats": stats,
            "system_metrics": {
                "cpu_usage": 45.2,
                "memory_usage": 62.8,
                "disk_usage": 38.5,
                "network_io": {
                    "bytes_sent": 1024000,
                    "bytes_received": 2048000
                }
            },
            "microsoft_365_status": {
                "graph_api": "healthy",
                "exchange_online": "healthy",
                "teams": "healthy",
                "onedrive": "degraded"
            },
            "last_updated": datetime.utcnow().isoformat()
        }
        
        message = WebSocketMessage(
            type=MessageType.SYSTEM_STATUS,
            data=dashboard_data
        )
        
        await connection_manager.send_to_connection(connection_id, message)
        
    except Exception as e:
        logger.error(f"Error sending dashboard data: {e}")


async def _send_notification_history(connection_id: str, user_info: Dict[str, Any]):
    """Send recent notification history"""
    try:
        # Simulated notification history
        notifications = [
            {
                "id": "notif_001",
                "type": "user_created",
                "title": "New user created",
                "message": "User john.doe@example.com has been created",
                "timestamp": datetime.utcnow().isoformat(),
                "read": False
            },
            {
                "id": "notif_002",
                "type": "security_alert",
                "title": "Security Alert",
                "message": "Multiple failed login attempts detected",
                "timestamp": datetime.utcnow().isoformat(),
                "read": True
            }
        ]
        
        message = WebSocketMessage(
            type=MessageType.DATA_UPDATE,
            data={"notifications": notifications}
        )
        
        await connection_manager.send_to_connection(connection_id, message)
        
    except Exception as e:
        logger.error(f"Error sending notification history: {e}")


async def _send_system_status(connection_id: str, user_info: Dict[str, Any]):
    """Send current system status"""
    try:
        system_status = {
            "status": "healthy",
            "services": {
                "microsoft_graph": {"status": "up", "response_time": 120},
                "exchange_online": {"status": "up", "response_time": 89},
                "teams": {"status": "up", "response_time": 156},
                "onedrive": {"status": "degraded", "response_time": 2340}
            },
            "performance": {
                "requests_per_minute": 1250,
                "error_rate": 0.02,
                "average_response_time": 145
            },
            "last_health_check": datetime.utcnow().isoformat()
        }
        
        message = WebSocketMessage(
            type=MessageType.SYSTEM_STATUS,
            data=system_status
        )
        
        await connection_manager.send_to_connection(connection_id, message)
        
    except Exception as e:
        logger.error(f"Error sending system status: {e}")


# Message handlers registration

async def handle_user_update(connection_id: str, message: WebSocketMessage):
    """Handle user update message"""
    logger.info(f"User update from {connection_id}: {message.data}")
    
    # Broadcast to other connections in the same tenant
    connection = connection_manager.connections.get(connection_id)
    if connection and connection.tenant_id:
        await connection_manager.send_to_tenant(
            connection.tenant_id,
            WebSocketMessage(
                type=MessageType.USER_UPDATE,
                data=message.data,
                source=connection_id
            )
        )


async def handle_subscription_request(connection_id: str, message: WebSocketMessage):
    """Handle subscription request"""
    topic = message.data.get("topic")
    action = message.data.get("action", "subscribe")
    
    if action == "subscribe" and topic:
        await connection_manager.subscribe(connection_id, topic)
        logger.info(f"Connection {connection_id} subscribed to {topic}")
    elif action == "unsubscribe" and topic:
        await connection_manager.unsubscribe(connection_id, topic)
        logger.info(f"Connection {connection_id} unsubscribed from {topic}")


# Register message handlers
connection_manager.register_message_handler(MessageType.USER_UPDATE, handle_user_update)
connection_manager.register_message_handler(MessageType.SUBSCRIPTION, handle_subscription_request)


# Startup and shutdown events

async def startup_websocket_services():
    """Initialize WebSocket services"""
    await connection_manager.initialize()
    await event_manager.initialize()
    logger.info("WebSocket services initialized")


async def shutdown_websocket_services():
    """Shutdown WebSocket services"""
    await connection_manager.close()
    await event_manager.close()
    logger.info("WebSocket services shutdown")


if __name__ == "__main__":
    # Test WebSocket router
    print("WebSocket Router module loaded successfully")
    print("Available endpoints:")
    for route in websocket_router.routes:
        print(f"  {route.path} - {route.__class__.__name__}")