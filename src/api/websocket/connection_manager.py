#!/usr/bin/env python3
"""
WebSocket Connection Manager - Phase 3 Advanced Integration
Enterprise-grade connection management with multi-tenant support
"""

import asyncio
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Set, Optional, Any, Callable
from dataclasses import dataclass, field
from enum import Enum
import uuid
from contextlib import asynccontextmanager

from fastapi import WebSocket, WebSocketDisconnect, HTTPException
from fastapi.websockets import WebSocketState
import redis.asyncio as redis
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)


class ConnectionType(str, Enum):
    """WebSocket connection types"""
    DASHBOARD = "dashboard"
    REALTIME_UPDATES = "realtime_updates"
    NOTIFICATIONS = "notifications"
    MONITORING = "monitoring"
    ADMIN = "admin"


class MessageType(str, Enum):
    """WebSocket message types"""
    PING = "ping"
    PONG = "pong"
    DATA_UPDATE = "data_update"
    USER_UPDATE = "user_update"
    GROUP_UPDATE = "group_update"
    SECURITY_ALERT = "security_alert"
    SYSTEM_STATUS = "system_status"
    ERROR = "error"
    SUBSCRIPTION = "subscription"
    UNSUBSCRIPTION = "unsubscription"


@dataclass
class WebSocketConnection:
    """WebSocket connection wrapper"""
    websocket: WebSocket
    connection_id: str
    user_id: Optional[str] = None
    tenant_id: Optional[str] = None
    connection_type: ConnectionType = ConnectionType.DASHBOARD
    subscriptions: Set[str] = field(default_factory=set)
    metadata: Dict[str, Any] = field(default_factory=dict)
    connected_at: datetime = field(default_factory=datetime.utcnow)
    last_ping: datetime = field(default_factory=datetime.utcnow)
    
    @property
    def is_active(self) -> bool:
        """Check if connection is active"""
        return (
            self.websocket.client_state == WebSocketState.CONNECTED and
            datetime.utcnow() - self.last_ping < timedelta(minutes=5)
        )


class WebSocketMessage(BaseModel):
    """WebSocket message structure"""
    type: MessageType
    data: Any = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    correlation_id: Optional[str] = None
    source: Optional[str] = None
    target: Optional[str] = None


class ConnectionManager:
    """
    Advanced WebSocket Connection Manager
    Features:
    - Multi-tenant connection management
    - Real-time broadcasting
    - Redis-based scaling
    - Connection health monitoring
    - Message routing and filtering
    """
    
    def __init__(self, 
                 redis_url: Optional[str] = None,
                 heartbeat_interval: int = 30,
                 max_connections_per_tenant: int = 100,
                 enable_redis_scaling: bool = True):
        """
        Initialize Connection Manager
        
        Args:
            redis_url: Redis connection URL for scaling
            heartbeat_interval: Heartbeat interval in seconds
            max_connections_per_tenant: Maximum connections per tenant
            enable_redis_scaling: Enable Redis for multi-instance scaling
        """
        self.connections: Dict[str, WebSocketConnection] = {}
        self.tenant_connections: Dict[str, Set[str]] = {}
        self.user_connections: Dict[str, Set[str]] = {}
        self.subscription_connections: Dict[str, Set[str]] = {}
        
        self.redis_url = redis_url
        self.heartbeat_interval = heartbeat_interval
        self.max_connections_per_tenant = max_connections_per_tenant
        self.enable_redis_scaling = enable_redis_scaling
        
        # Redis client for scaling
        self.redis_client: Optional[redis.Redis] = None
        
        # Message handlers
        self.message_handlers: Dict[MessageType, List[Callable]] = {}
        
        # Statistics
        self.stats = {
            'total_connections': 0,
            'active_connections': 0,
            'messages_sent': 0,
            'messages_received': 0,
            'disconnections': 0,
            'errors': 0
        }
        
        # Background tasks
        self._heartbeat_task: Optional[asyncio.Task] = None
        self._cleanup_task: Optional[asyncio.Task] = None
        
        logger.info(f"ConnectionManager initialized with Redis: {bool(redis_url)}")
    
    async def initialize(self):
        """Initialize Redis and background tasks"""
        if self.enable_redis_scaling and self.redis_url:
            try:
                self.redis_client = redis.from_url(self.redis_url)
                await self.redis_client.ping()
                logger.info("Redis connection established for WebSocket scaling")
            except Exception as e:
                logger.warning(f"Failed to connect to Redis: {e}")
                self.enable_redis_scaling = False
        
        # Start background tasks
        self._heartbeat_task = asyncio.create_task(self._heartbeat_loop())
        self._cleanup_task = asyncio.create_task(self._cleanup_loop())
        
        logger.info("ConnectionManager initialized successfully")
    
    async def connect(self, 
                     websocket: WebSocket,
                     user_id: Optional[str] = None,
                     tenant_id: Optional[str] = None,
                     connection_type: ConnectionType = ConnectionType.DASHBOARD,
                     metadata: Optional[Dict[str, Any]] = None) -> str:
        """
        Accept new WebSocket connection
        
        Args:
            websocket: FastAPI WebSocket instance
            user_id: User identifier
            tenant_id: Tenant identifier
            connection_type: Type of connection
            metadata: Additional connection metadata
            
        Returns:
            Connection ID
            
        Raises:
            HTTPException: If connection limit exceeded
        """
        # Check tenant connection limits
        if tenant_id and len(self.tenant_connections.get(tenant_id, set())) >= self.max_connections_per_tenant:
            raise HTTPException(status_code=429, detail="Too many connections for tenant")
        
        # Accept WebSocket connection
        await websocket.accept()
        
        # Generate connection ID
        connection_id = str(uuid.uuid4())
        
        # Create connection wrapper
        connection = WebSocketConnection(
            websocket=websocket,
            connection_id=connection_id,
            user_id=user_id,
            tenant_id=tenant_id,
            connection_type=connection_type,
            metadata=metadata or {}
        )
        
        # Store connection
        self.connections[connection_id] = connection
        
        # Update indexes
        if tenant_id:
            if tenant_id not in self.tenant_connections:
                self.tenant_connections[tenant_id] = set()
            self.tenant_connections[tenant_id].add(connection_id)
        
        if user_id:
            if user_id not in self.user_connections:
                self.user_connections[user_id] = set()
            self.user_connections[user_id].add(connection_id)
        
        # Update statistics
        self.stats['total_connections'] += 1
        self.stats['active_connections'] += 1
        
        # Send welcome message
        welcome_message = WebSocketMessage(
            type=MessageType.SYSTEM_STATUS,
            data={
                "status": "connected",
                "connection_id": connection_id,
                "server_time": datetime.utcnow().isoformat()
            }
        )
        await self._send_to_connection(connection_id, welcome_message)
        
        # Publish connection event to Redis
        if self.enable_redis_scaling:
            await self._publish_to_redis("connection_established", {
                "connection_id": connection_id,
                "user_id": user_id,
                "tenant_id": tenant_id,
                "connection_type": connection_type.value
            })
        
        logger.info(f"WebSocket connected: {connection_id} (user: {user_id}, tenant: {tenant_id})")
        return connection_id
    
    async def disconnect(self, connection_id: str):
        """
        Disconnect WebSocket connection
        
        Args:
            connection_id: Connection identifier
        """
        connection = self.connections.get(connection_id)
        if not connection:
            return
        
        try:
            # Close WebSocket if still connected
            if connection.websocket.client_state == WebSocketState.CONNECTED:
                await connection.websocket.close()
        except Exception as e:
            logger.warning(f"Error closing WebSocket {connection_id}: {e}")
        
        # Remove from indexes
        if connection.tenant_id and connection.tenant_id in self.tenant_connections:
            self.tenant_connections[connection.tenant_id].discard(connection_id)
            if not self.tenant_connections[connection.tenant_id]:
                del self.tenant_connections[connection.tenant_id]
        
        if connection.user_id and connection.user_id in self.user_connections:
            self.user_connections[connection.user_id].discard(connection_id)
            if not self.user_connections[connection.user_id]:
                del self.user_connections[connection.user_id]
        
        # Remove from subscriptions
        for topic in connection.subscriptions:
            if topic in self.subscription_connections:
                self.subscription_connections[topic].discard(connection_id)
                if not self.subscription_connections[topic]:
                    del self.subscription_connections[topic]
        
        # Remove connection
        del self.connections[connection_id]
        
        # Update statistics
        self.stats['active_connections'] -= 1
        self.stats['disconnections'] += 1
        
        # Publish disconnection event to Redis
        if self.enable_redis_scaling:
            await self._publish_to_redis("connection_closed", {
                "connection_id": connection_id,
                "user_id": connection.user_id,
                "tenant_id": connection.tenant_id
            })
        
        logger.info(f"WebSocket disconnected: {connection_id}")
    
    async def send_to_connection(self, connection_id: str, message: WebSocketMessage):
        """
        Send message to specific connection
        
        Args:
            connection_id: Target connection ID
            message: Message to send
        """
        await self._send_to_connection(connection_id, message)
    
    async def send_to_user(self, user_id: str, message: WebSocketMessage):
        """
        Send message to all connections of a user
        
        Args:
            user_id: Target user ID
            message: Message to send
        """
        connection_ids = self.user_connections.get(user_id, set())
        await asyncio.gather(
            *[self._send_to_connection(conn_id, message) for conn_id in connection_ids],
            return_exceptions=True
        )
    
    async def send_to_tenant(self, tenant_id: str, message: WebSocketMessage):
        """
        Send message to all connections of a tenant
        
        Args:
            tenant_id: Target tenant ID
            message: Message to send
        """
        connection_ids = self.tenant_connections.get(tenant_id, set())
        await asyncio.gather(
            *[self._send_to_connection(conn_id, message) for conn_id in connection_ids],
            return_exceptions=True
        )
    
    async def broadcast(self, message: WebSocketMessage, 
                      connection_type: Optional[ConnectionType] = None,
                      tenant_filter: Optional[str] = None):
        """
        Broadcast message to all or filtered connections
        
        Args:
            message: Message to broadcast
            connection_type: Filter by connection type
            tenant_filter: Filter by tenant ID
        """
        target_connections = []
        
        for connection in self.connections.values():
            if not connection.is_active:
                continue
            
            if connection_type and connection.connection_type != connection_type:
                continue
            
            if tenant_filter and connection.tenant_id != tenant_filter:
                continue
            
            target_connections.append(connection.connection_id)
        
        await asyncio.gather(
            *[self._send_to_connection(conn_id, message) for conn_id in target_connections],
            return_exceptions=True
        )
    
    async def subscribe(self, connection_id: str, topic: str):
        """
        Subscribe connection to topic
        
        Args:
            connection_id: Connection ID
            topic: Topic to subscribe to
        """
        connection = self.connections.get(connection_id)
        if not connection:
            return
        
        connection.subscriptions.add(topic)
        
        if topic not in self.subscription_connections:
            self.subscription_connections[topic] = set()
        self.subscription_connections[topic].add(connection_id)
        
        logger.debug(f"Connection {connection_id} subscribed to {topic}")
    
    async def unsubscribe(self, connection_id: str, topic: str):
        """
        Unsubscribe connection from topic
        
        Args:
            connection_id: Connection ID
            topic: Topic to unsubscribe from
        """
        connection = self.connections.get(connection_id)
        if not connection:
            return
        
        connection.subscriptions.discard(topic)
        
        if topic in self.subscription_connections:
            self.subscription_connections[topic].discard(connection_id)
            if not self.subscription_connections[topic]:
                del self.subscription_connections[topic]
        
        logger.debug(f"Connection {connection_id} unsubscribed from {topic}")
    
    async def publish_to_topic(self, topic: str, message: WebSocketMessage):
        """
        Publish message to all subscribers of a topic
        
        Args:
            topic: Topic to publish to
            message: Message to publish
        """
        connection_ids = self.subscription_connections.get(topic, set())
        await asyncio.gather(
            *[self._send_to_connection(conn_id, message) for conn_id in connection_ids],
            return_exceptions=True
        )
    
    async def handle_message(self, connection_id: str, message_data: dict):
        """
        Handle incoming WebSocket message
        
        Args:
            connection_id: Source connection ID
            message_data: Raw message data
        """
        try:
            message = WebSocketMessage(**message_data)
            
            # Update connection ping time
            connection = self.connections.get(connection_id)
            if connection:
                connection.last_ping = datetime.utcnow()
            
            # Handle ping/pong
            if message.type == MessageType.PING:
                pong_message = WebSocketMessage(
                    type=MessageType.PONG,
                    correlation_id=message.correlation_id
                )
                await self._send_to_connection(connection_id, pong_message)
                return
            
            # Handle subscription requests
            if message.type == MessageType.SUBSCRIPTION:
                topic = message.data.get("topic")
                if topic:
                    await self.subscribe(connection_id, topic)
                return
            
            if message.type == MessageType.UNSUBSCRIPTION:
                topic = message.data.get("topic")
                if topic:
                    await self.unsubscribe(connection_id, topic)
                return
            
            # Call registered message handlers
            handlers = self.message_handlers.get(message.type, [])
            for handler in handlers:
                try:
                    await handler(connection_id, message)
                except Exception as e:
                    logger.error(f"Message handler error: {e}")
            
            self.stats['messages_received'] += 1
            
        except Exception as e:
            logger.error(f"Error handling message from {connection_id}: {e}")
            self.stats['errors'] += 1
            
            # Send error response
            error_message = WebSocketMessage(
                type=MessageType.ERROR,
                data={"error": "Invalid message format"}
            )
            await self._send_to_connection(connection_id, error_message)
    
    def register_message_handler(self, message_type: MessageType, handler: Callable):
        """
        Register message handler for specific message type
        
        Args:
            message_type: Type of message to handle
            handler: Async handler function
        """
        if message_type not in self.message_handlers:
            self.message_handlers[message_type] = []
        self.message_handlers[message_type].append(handler)
    
    def get_connection_stats(self) -> Dict[str, Any]:
        """Get connection statistics"""
        return {
            **self.stats,
            'connections_by_tenant': {
                tenant: len(connections) 
                for tenant, connections in self.tenant_connections.items()
            },
            'connections_by_type': {
                conn_type.value: len([
                    c for c in self.connections.values() 
                    if c.connection_type == conn_type
                ])
                for conn_type in ConnectionType
            },
            'active_subscriptions': len(self.subscription_connections)
        }
    
    async def _send_to_connection(self, connection_id: str, message: WebSocketMessage):
        """Internal method to send message to connection"""
        connection = self.connections.get(connection_id)
        if not connection or not connection.is_active:
            return
        
        try:
            await connection.websocket.send_text(message.model_dump_json())
            self.stats['messages_sent'] += 1
        except WebSocketDisconnect:
            await self.disconnect(connection_id)
        except Exception as e:
            logger.error(f"Error sending message to {connection_id}: {e}")
            self.stats['errors'] += 1
            await self.disconnect(connection_id)
    
    async def _publish_to_redis(self, event_type: str, data: dict):
        """Publish event to Redis for multi-instance coordination"""
        if not self.redis_client:
            return
        
        try:
            event_data = {
                "event_type": event_type,
                "data": data,
                "timestamp": datetime.utcnow().isoformat(),
                "instance_id": id(self)
            }
            await self.redis_client.publish("websocket_events", json.dumps(event_data))
        except Exception as e:
            logger.warning(f"Failed to publish to Redis: {e}")
    
    async def _heartbeat_loop(self):
        """Background task for connection health monitoring"""
        while True:
            try:
                await asyncio.sleep(self.heartbeat_interval)
                
                # Send ping to all connections
                ping_message = WebSocketMessage(type=MessageType.PING)
                
                for connection_id in list(self.connections.keys()):
                    connection = self.connections.get(connection_id)
                    if connection and connection.is_active:
                        # Check if connection is stale
                        if datetime.utcnow() - connection.last_ping > timedelta(minutes=5):
                            logger.warning(f"Stale connection detected: {connection_id}")
                            await self.disconnect(connection_id)
                        else:
                            await self._send_to_connection(connection_id, ping_message)
                
            except Exception as e:
                logger.error(f"Heartbeat loop error: {e}")
    
    async def _cleanup_loop(self):
        """Background task for connection cleanup"""
        while True:
            try:
                await asyncio.sleep(60)  # Run every minute
                
                # Clean up disconnected connections
                disconnected_connections = [
                    conn_id for conn_id, conn in self.connections.items()
                    if not conn.is_active
                ]
                
                for connection_id in disconnected_connections:
                    await self.disconnect(connection_id)
                
                if disconnected_connections:
                    logger.info(f"Cleaned up {len(disconnected_connections)} stale connections")
                
            except Exception as e:
                logger.error(f"Cleanup loop error: {e}")
    
    async def close(self):
        """Close connection manager and all connections"""
        # Cancel background tasks
        if self._heartbeat_task:
            self._heartbeat_task.cancel()
        if self._cleanup_task:
            self._cleanup_task.cancel()
        
        # Close all connections
        for connection_id in list(self.connections.keys()):
            await self.disconnect(connection_id)
        
        # Close Redis client
        if self.redis_client:
            await self.redis_client.close()
        
        logger.info("ConnectionManager closed")
    
    @asynccontextmanager
    async def lifespan(self):
        """Async context manager for connection manager lifecycle"""
        await self.initialize()
        try:
            yield self
        finally:
            await self.close()


# Global connection manager instance
connection_manager = ConnectionManager()


if __name__ == "__main__":
    # Test connection manager
    import asyncio
    
    async def test_connection_manager():
        """Test connection manager functionality"""
        print("Testing ConnectionManager...")
        
        async with connection_manager.lifespan():
            # Test statistics
            stats = connection_manager.get_connection_stats()
            print(f"Initial stats: {stats}")
            
            # Test message handling
            async def test_handler(conn_id: str, message: WebSocketMessage):
                print(f"Received message from {conn_id}: {message.type}")
            
            connection_manager.register_message_handler(MessageType.DATA_UPDATE, test_handler)
            
            print("ConnectionManager test completed")
    
    asyncio.run(test_connection_manager())