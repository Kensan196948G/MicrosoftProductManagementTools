#!/usr/bin/env python3
"""
Realtime Event Manager - Phase 3 Advanced Integration
Microsoft Graph Change Notifications and Delta Query integration
"""

import asyncio
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Callable, Set
from dataclasses import dataclass, field
from enum import Enum
import uuid
import hashlib

from fastapi import HTTPException
import redis.asyncio as redis
from azure.servicebus.aio import ServiceBusClient, ServiceBusMessage
from azure.servicebus import ServiceBusReceiveMode
import httpx

from .connection_manager import ConnectionManager, MessageType, WebSocketMessage
from src.api.microsoft_graph_client import create_graph_client
from src.core.config import get_settings

logger = logging.getLogger(__name__)


class ChangeType(str, Enum):
    """Microsoft Graph change types"""
    CREATED = "created"
    UPDATED = "updated"
    DELETED = "deleted"


class ResourceType(str, Enum):
    """Microsoft Graph resource types"""
    USER = "users"
    GROUP = "groups"
    TEAM = "teams"
    CHANNEL = "channels"
    MESSAGE = "messages"
    DRIVE_ITEM = "driveItems"
    MAIL = "messages"
    CALENDAR_EVENT = "events"
    CONTACT = "contacts"


@dataclass
class ChangeNotification:
    """Microsoft Graph change notification"""
    id: str
    subscription_id: str
    change_type: ChangeType
    resource: str
    resource_data: Dict[str, Any]
    client_state: Optional[str] = None
    encryption_certificate_id: Optional[str] = None
    encryption_certificate_thumbprint: Optional[str] = None
    encrypted_content: Optional[Dict[str, Any]] = None
    lifecycle_event: Optional[str] = None
    notification_url: str = ""
    subscription_expiration_date_time: Optional[datetime] = None
    tenant_id: Optional[str] = None


@dataclass
class DeltaToken:
    """Delta query token for tracking changes"""
    resource_type: ResourceType
    tenant_id: str
    token: str
    created_at: datetime
    last_used: datetime
    expires_at: Optional[datetime] = None


@dataclass
class Subscription:
    """Microsoft Graph subscription"""
    id: str
    resource: str
    change_type: List[ChangeType]
    notification_url: str
    expiration_date_time: datetime
    client_state: str
    tenant_id: str
    created_at: datetime = field(default_factory=datetime.utcnow)
    is_active: bool = True


class RealtimeEventManager:
    """
    Realtime Event Manager for Microsoft Graph
    
    Features:
    - Change Notifications subscription
    - Delta Query processing
    - Event filtering and routing
    - Multi-tenant support
    - Webhook validation
    """
    
    def __init__(self, 
                 connection_manager: Optional[ConnectionManager] = None,
                 redis_url: Optional[str] = None,
                 servicebus_connection_string: Optional[str] = None,
                 notification_queue: str = "graph-notifications"):
        """
        Initialize Realtime Event Manager
        
        Args:
            connection_manager: WebSocket connection manager
            redis_url: Redis connection URL
            servicebus_connection_string: Azure Service Bus connection string
            notification_queue: Service Bus queue name for notifications
        """
        self.connection_manager = connection_manager
        self.redis_url = redis_url
        self.servicebus_connection_string = servicebus_connection_string
        self.notification_queue = notification_queue
        
        # Storage
        self.subscriptions: Dict[str, Subscription] = {}
        self.delta_tokens: Dict[str, DeltaToken] = {}
        self.change_handlers: Dict[ResourceType, List[Callable]] = {}
        
        # Clients
        self.redis_client: Optional[redis.Redis] = None
        self.servicebus_client: Optional[ServiceBusClient] = None
        self.graph_client = None
        
        # Background tasks
        self._subscription_renewal_task: Optional[asyncio.Task] = None
        self._delta_sync_task: Optional[asyncio.Task] = None
        self._notification_processor_task: Optional[asyncio.Task] = None
        
        # Settings
        self.settings = get_settings()
        self.webhook_base_url = getattr(self.settings, 'WEBHOOK_BASE_URL', 'https://localhost:8000')
        self.webhook_secret = getattr(self.settings, 'WEBHOOK_SECRET', 'default-secret')
        
        # Statistics
        self.stats = {
            'notifications_received': 0,
            'notifications_processed': 0,
            'notifications_failed': 0,
            'delta_syncs_completed': 0,
            'subscriptions_renewed': 0,
            'errors': 0
        }
        
        logger.info("RealtimeEventManager initialized")
    
    async def initialize(self):
        """Initialize event manager services"""
        try:
            # Initialize Redis client
            if self.redis_url:
                self.redis_client = redis.from_url(self.redis_url)
                await self.redis_client.ping()
                logger.info("Redis connected for realtime events")
            
            # Initialize Service Bus client
            if self.servicebus_connection_string:
                self.servicebus_client = ServiceBusClient.from_connection_string(
                    self.servicebus_connection_string
                )
                logger.info("Service Bus connected for notifications")
            
            # Initialize Graph client
            self.graph_client = create_graph_client(async_mode=True)
            
            # Load existing subscriptions from storage
            await self._load_subscriptions()
            
            # Start background tasks
            self._subscription_renewal_task = asyncio.create_task(self._subscription_renewal_loop())
            self._delta_sync_task = asyncio.create_task(self._delta_sync_loop())
            
            if self.servicebus_client:
                self._notification_processor_task = asyncio.create_task(self._notification_processor_loop())
            
            logger.info("RealtimeEventManager initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize RealtimeEventManager: {e}")
            raise
    
    async def create_subscription(self, 
                                 resource: str,
                                 change_types: List[ChangeType],
                                 tenant_id: str,
                                 expiration_hours: int = 4320) -> str:  # 180 days max
        """
        Create Microsoft Graph subscription
        
        Args:
            resource: Resource to monitor (e.g., 'users', 'groups')
            change_types: Types of changes to monitor
            tenant_id: Tenant identifier
            expiration_hours: Subscription expiration in hours
            
        Returns:
            Subscription ID
        """
        try:
            # Calculate expiration time (max 4320 hours for most resources)
            expiration_date = datetime.utcnow() + timedelta(hours=min(expiration_hours, 4320))
            
            # Generate client state for validation
            client_state = self._generate_client_state(tenant_id)
            
            # Construct notification URL
            notification_url = f"{self.webhook_base_url}/api/webhooks/graph/notifications"
            
            # Create subscription via Microsoft Graph
            subscription_data = {
                "changeType": ",".join([ct.value for ct in change_types]),
                "notificationUrl": notification_url,
                "resource": resource,
                "expirationDateTime": expiration_date.isoformat() + "Z",
                "clientState": client_state,
                "includeResourceData": True,
                "encryptionCertificate": None,  # TODO: Implement certificate-based encryption
                "encryptionCertificateId": None
            }
            
            # Call Microsoft Graph to create subscription
            async with self.graph_client as client:
                # Note: This is a simplified implementation
                # In real implementation, use Graph SDK subscription endpoints
                subscription_response = await self._create_graph_subscription(subscription_data)
                
                subscription_id = subscription_response.get("id")
                if not subscription_id:
                    raise HTTPException(status_code=500, detail="Failed to create subscription")
                
                # Store subscription
                subscription = Subscription(
                    id=subscription_id,
                    resource=resource,
                    change_type=change_types,
                    notification_url=notification_url,
                    expiration_date_time=expiration_date,
                    client_state=client_state,
                    tenant_id=tenant_id
                )
                
                self.subscriptions[subscription_id] = subscription
                
                # Save to persistent storage
                await self._save_subscription(subscription)
                
                logger.info(f"Created subscription {subscription_id} for {resource}")
                return subscription_id
                
        except Exception as e:
            logger.error(f"Failed to create subscription: {e}")
            self.stats['errors'] += 1
            raise
    
    async def delete_subscription(self, subscription_id: str):
        """Delete Microsoft Graph subscription"""
        try:
            subscription = self.subscriptions.get(subscription_id)
            if not subscription:
                raise HTTPException(status_code=404, detail="Subscription not found")
            
            # Delete from Microsoft Graph
            async with self.graph_client as client:
                await self._delete_graph_subscription(subscription_id)
            
            # Remove from local storage
            subscription.is_active = False
            del self.subscriptions[subscription_id]
            
            # Remove from persistent storage
            await self._delete_stored_subscription(subscription_id)
            
            logger.info(f"Deleted subscription {subscription_id}")
            
        except Exception as e:
            logger.error(f"Failed to delete subscription {subscription_id}: {e}")
            self.stats['errors'] += 1
            raise
    
    async def process_change_notification(self, notification_data: Dict[str, Any]):
        """
        Process incoming change notification from Microsoft Graph
        
        Args:
            notification_data: Raw notification data from webhook
        """
        try:
            # Validate notification
            if not self._validate_notification(notification_data):
                logger.warning("Invalid notification received")
                return
            
            # Parse notifications
            notifications = []
            for value in notification_data.get("value", []):
                notification = ChangeNotification(
                    id=value.get("id"),
                    subscription_id=value.get("subscriptionId"),
                    change_type=ChangeType(value.get("changeType")),
                    resource=value.get("resource"),
                    resource_data=value.get("resourceData", {}),
                    client_state=value.get("clientState"),
                    notification_url=value.get("notificationUrl", ""),
                    tenant_id=value.get("tenantId")
                )
                notifications.append(notification)
            
            # Process each notification
            for notification in notifications:
                await self._process_single_notification(notification)
            
            self.stats['notifications_received'] += len(notifications)
            self.stats['notifications_processed'] += len(notifications)
            
        except Exception as e:
            logger.error(f"Failed to process change notification: {e}")
            self.stats['notifications_failed'] += 1
            self.stats['errors'] += 1
    
    async def start_delta_sync(self, 
                              resource_type: ResourceType,
                              tenant_id: str,
                              initial_sync: bool = False) -> str:
        """
        Start delta synchronization for a resource type
        
        Args:
            resource_type: Type of resource to sync
            tenant_id: Tenant identifier
            initial_sync: Whether this is an initial sync
            
        Returns:
            Delta token for next sync
        """
        try:
            # Get existing delta token
            token_key = f"{tenant_id}:{resource_type.value}"
            existing_token = self.delta_tokens.get(token_key)
            
            # Perform delta query
            if initial_sync or not existing_token:
                delta_data = await self._perform_initial_delta_query(resource_type, tenant_id)
            else:
                delta_data = await self._perform_delta_query(resource_type, tenant_id, existing_token.token)
            
            # Process delta changes
            changes = delta_data.get("value", [])
            next_token = self._extract_delta_token(delta_data)
            
            # Store new delta token
            if next_token:
                delta_token = DeltaToken(
                    resource_type=resource_type,
                    tenant_id=tenant_id,
                    token=next_token,
                    created_at=datetime.utcnow(),
                    last_used=datetime.utcnow()
                )
                self.delta_tokens[token_key] = delta_token
                await self._save_delta_token(delta_token)
            
            # Broadcast changes to WebSocket connections
            if changes:
                await self._broadcast_delta_changes(resource_type, tenant_id, changes)
            
            self.stats['delta_syncs_completed'] += 1
            logger.info(f"Delta sync completed for {resource_type.value}: {len(changes)} changes")
            
            return next_token
            
        except Exception as e:
            logger.error(f"Failed to perform delta sync: {e}")
            self.stats['errors'] += 1
            raise
    
    def register_change_handler(self, resource_type: ResourceType, handler: Callable):
        """
        Register change handler for specific resource type
        
        Args:
            resource_type: Type of resource
            handler: Async handler function
        """
        if resource_type not in self.change_handlers:
            self.change_handlers[resource_type] = []
        self.change_handlers[resource_type].append(handler)
        logger.info(f"Registered change handler for {resource_type.value}")
    
    async def _process_single_notification(self, notification: ChangeNotification):
        """Process a single change notification"""
        try:
            # Verify subscription exists
            subscription = self.subscriptions.get(notification.subscription_id)
            if not subscription or not subscription.is_active:
                logger.warning(f"Notification for unknown subscription: {notification.subscription_id}")
                return
            
            # Extract resource type
            resource_type = self._extract_resource_type(notification.resource)
            if not resource_type:
                logger.warning(f"Unknown resource type: {notification.resource}")
                return
            
            # Call registered handlers
            handlers = self.change_handlers.get(resource_type, [])
            for handler in handlers:
                try:
                    await handler(notification)
                except Exception as e:
                    logger.error(f"Change handler error: {e}")
            
            # Broadcast to WebSocket connections
            await self._broadcast_change_notification(notification)
            
            # Store notification in queue for processing
            if self.redis_client:
                await self._store_notification_in_queue(notification)
            
        except Exception as e:
            logger.error(f"Failed to process notification: {e}")
    
    async def _broadcast_change_notification(self, notification: ChangeNotification):
        """Broadcast change notification to WebSocket connections"""
        if not self.connection_manager:
            return
        
        try:
            message = WebSocketMessage(
                type=MessageType.DATA_UPDATE,
                data={
                    "change_type": notification.change_type.value,
                    "resource": notification.resource,
                    "resource_data": notification.resource_data,
                    "timestamp": datetime.utcnow().isoformat(),
                    "subscription_id": notification.subscription_id
                }
            )
            
            # Send to specific tenant
            if notification.tenant_id:
                await self.connection_manager.send_to_tenant(notification.tenant_id, message)
            else:
                # Broadcast to all real-time connections
                await self.connection_manager.broadcast(
                    message, 
                    connection_type=ConnectionType.REALTIME_UPDATES
                )
            
        except Exception as e:
            logger.error(f"Failed to broadcast change notification: {e}")
    
    async def _broadcast_delta_changes(self, 
                                     resource_type: ResourceType,
                                     tenant_id: str,
                                     changes: List[Dict[str, Any]]):
        """Broadcast delta changes to WebSocket connections"""
        if not self.connection_manager:
            return
        
        try:
            message = WebSocketMessage(
                type=MessageType.DATA_UPDATE,
                data={
                    "delta_sync": True,
                    "resource_type": resource_type.value,
                    "changes": changes,
                    "timestamp": datetime.utcnow().isoformat(),
                    "tenant_id": tenant_id
                }
            )
            
            await self.connection_manager.send_to_tenant(tenant_id, message)
            
        except Exception as e:
            logger.error(f"Failed to broadcast delta changes: {e}")
    
    def _generate_client_state(self, tenant_id: str) -> str:
        """Generate client state for subscription validation"""
        data = f"{tenant_id}:{self.webhook_secret}:{datetime.utcnow().isoformat()}"
        return hashlib.sha256(data.encode()).hexdigest()[:32]
    
    def _validate_notification(self, notification_data: Dict[str, Any]) -> bool:
        """Validate incoming notification"""
        # Basic validation
        if not notification_data.get("value"):
            return False
        
        # Validate each notification in the batch
        for value in notification_data["value"]:
            subscription_id = value.get("subscriptionId")
            client_state = value.get("clientState")
            
            # Check if subscription exists
            subscription = self.subscriptions.get(subscription_id)
            if not subscription:
                continue
            
            # Validate client state
            if subscription.client_state != client_state:
                logger.warning(f"Invalid client state for subscription {subscription_id}")
                return False
        
        return True
    
    def _extract_resource_type(self, resource: str) -> Optional[ResourceType]:
        """Extract resource type from resource string"""
        try:
            # Extract base resource type (e.g., 'users' from 'users/12345')
            base_resource = resource.split('/')[0]
            return ResourceType(base_resource)
        except ValueError:
            return None
    
    def _extract_delta_token(self, delta_data: Dict[str, Any]) -> Optional[str]:
        """Extract delta token from delta query response"""
        # Look for @odata.deltaLink
        delta_link = delta_data.get("@odata.deltaLink")
        if delta_link:
            # Extract token from URL
            if "$deltatoken=" in delta_link:
                return delta_link.split("$deltatoken=")[1].split("&")[0]
        
        # Look for @odata.nextLink with delta token
        next_link = delta_data.get("@odata.nextLink")
        if next_link and "$deltatoken=" in next_link:
            return next_link.split("$deltatoken=")[1].split("&")[0]
        
        return None
    
    async def _subscription_renewal_loop(self):
        """Background task to renew expiring subscriptions"""
        while True:
            try:
                await asyncio.sleep(3600)  # Check every hour
                
                now = datetime.utcnow()
                expiring_soon = now + timedelta(hours=24)  # Renew 24 hours before expiration
                
                for subscription_id, subscription in list(self.subscriptions.items()):
                    if (subscription.is_active and 
                        subscription.expiration_date_time <= expiring_soon):
                        
                        try:
                            await self._renew_subscription(subscription)
                            self.stats['subscriptions_renewed'] += 1
                        except Exception as e:
                            logger.error(f"Failed to renew subscription {subscription_id}: {e}")
                            subscription.is_active = False
                
            except Exception as e:
                logger.error(f"Subscription renewal loop error: {e}")
    
    async def _delta_sync_loop(self):
        """Background task for periodic delta synchronization"""
        while True:
            try:
                await asyncio.sleep(300)  # Run every 5 minutes
                
                # Perform delta sync for all resource types
                for resource_type in ResourceType:
                    for tenant_id in set(sub.tenant_id for sub in self.subscriptions.values()):
                        try:
                            await self.start_delta_sync(resource_type, tenant_id)
                        except Exception as e:
                            logger.error(f"Delta sync error for {resource_type.value}: {e}")
                
            except Exception as e:
                logger.error(f"Delta sync loop error: {e}")
    
    async def _notification_processor_loop(self):
        """Background task to process notifications from Service Bus"""
        if not self.servicebus_client:
            return
        
        try:
            async with self.servicebus_client:
                receiver = self.servicebus_client.get_queue_receiver(
                    queue_name=self.notification_queue,
                    receive_mode=ServiceBusReceiveMode.PEEK_LOCK
                )
                
                async with receiver:
                    while True:
                        messages = await receiver.receive_messages(max_message_count=10)
                        
                        for message in messages:
                            try:
                                notification_data = json.loads(str(message))
                                await self.process_change_notification(notification_data)
                                await receiver.complete_message(message)
                            except Exception as e:
                                logger.error(f"Failed to process Service Bus message: {e}")
                                await receiver.abandon_message(message)
                        
                        if not messages:
                            await asyncio.sleep(1)
        
        except Exception as e:
            logger.error(f"Notification processor loop error: {e}")
    
    # Placeholder methods for Microsoft Graph operations
    async def _create_graph_subscription(self, subscription_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create subscription via Microsoft Graph API"""
        # TODO: Implement actual Graph API call
        return {"id": str(uuid.uuid4())}
    
    async def _delete_graph_subscription(self, subscription_id: str):
        """Delete subscription via Microsoft Graph API"""
        # TODO: Implement actual Graph API call
        pass
    
    async def _renew_subscription(self, subscription: Subscription):
        """Renew subscription via Microsoft Graph API"""
        # TODO: Implement actual Graph API call
        subscription.expiration_date_time = datetime.utcnow() + timedelta(hours=4320)
    
    async def _perform_initial_delta_query(self, resource_type: ResourceType, tenant_id: str) -> Dict[str, Any]:
        """Perform initial delta query"""
        # TODO: Implement actual Graph API delta query
        return {"value": [], "@odata.deltaLink": f"delta_token_{uuid.uuid4()}"}
    
    async def _perform_delta_query(self, resource_type: ResourceType, tenant_id: str, delta_token: str) -> Dict[str, Any]:
        """Perform delta query with existing token"""
        # TODO: Implement actual Graph API delta query
        return {"value": [], "@odata.deltaLink": f"delta_token_{uuid.uuid4()}"}
    
    # Storage methods (placeholder implementations)
    async def _load_subscriptions(self):
        """Load subscriptions from persistent storage"""
        # TODO: Implement storage loading
        pass
    
    async def _save_subscription(self, subscription: Subscription):
        """Save subscription to persistent storage"""
        # TODO: Implement storage saving
        pass
    
    async def _delete_stored_subscription(self, subscription_id: str):
        """Delete subscription from persistent storage"""
        # TODO: Implement storage deletion
        pass
    
    async def _save_delta_token(self, delta_token: DeltaToken):
        """Save delta token to persistent storage"""
        # TODO: Implement storage saving
        pass
    
    async def _store_notification_in_queue(self, notification: ChangeNotification):
        """Store notification in Redis queue for processing"""
        if not self.redis_client:
            return
        
        try:
            notification_data = {
                "id": notification.id,
                "subscription_id": notification.subscription_id,
                "change_type": notification.change_type.value,
                "resource": notification.resource,
                "resource_data": notification.resource_data,
                "timestamp": datetime.utcnow().isoformat()
            }
            
            await self.redis_client.lpush(
                "graph_notifications",
                json.dumps(notification_data)
            )
            
        except Exception as e:
            logger.error(f"Failed to store notification in queue: {e}")
    
    def get_stats(self) -> Dict[str, Any]:
        """Get event manager statistics"""
        return {
            **self.stats,
            'active_subscriptions': len([s for s in self.subscriptions.values() if s.is_active]),
            'delta_tokens': len(self.delta_tokens),
            'registered_handlers': sum(len(handlers) for handlers in self.change_handlers.values())
        }
    
    async def close(self):
        """Close event manager and cleanup resources"""
        # Cancel background tasks
        if self._subscription_renewal_task:
            self._subscription_renewal_task.cancel()
        if self._delta_sync_task:
            self._delta_sync_task.cancel()
        if self._notification_processor_task:
            self._notification_processor_task.cancel()
        
        # Close clients
        if self.redis_client:
            await self.redis_client.close()
        if self.servicebus_client:
            await self.servicebus_client.close()
        if self.graph_client:
            await self.graph_client.close()
        
        logger.info("RealtimeEventManager closed")


if __name__ == "__main__":
    # Test event manager
    import asyncio
    
    async def test_event_manager():
        """Test event manager functionality"""
        print("Testing RealtimeEventManager...")
        
        event_manager = RealtimeEventManager()
        await event_manager.initialize()
        
        # Test statistics
        stats = event_manager.get_stats()
        print(f"Event manager stats: {stats}")
        
        await event_manager.close()
        print("RealtimeEventManager test completed")
    
    asyncio.run(test_event_manager())