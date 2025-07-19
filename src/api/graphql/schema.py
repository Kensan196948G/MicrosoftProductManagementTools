#!/usr/bin/env python3
"""
GraphQL Schema - Phase 3 Advanced Integration
Strawberry GraphQL schema definition with Microsoft 365 integration
"""

import strawberry
from typing import List, Optional, AsyncIterator
import asyncio
import logging
from datetime import datetime

from strawberry.types import Info
from strawberry.tools import merge_types

from .resolvers import QueryResolver, MutationResolver, GraphQLContext
from .types import (
    UserType, GroupTypeEntity, TeamType, ServiceHealth, ChangeNotification,
    UserConnection, GroupConnection, FilterInput, SortInput
)

logger = logging.getLogger(__name__)


@strawberry.type
class Query(QueryResolver):
    """GraphQL Query root"""
    
    @strawberry.field
    def hello(self) -> str:
        """Test query"""
        return "Hello from Microsoft 365 Management Tools GraphQL API!"
    
    @strawberry.field
    def version(self) -> str:
        """API version"""
        return "3.0.0"
    
    @strawberry.field
    def server_time(self) -> datetime:
        """Current server time"""
        return datetime.utcnow()


@strawberry.type 
class Mutation(MutationResolver):
    """GraphQL Mutation root"""
    
    @strawberry.mutation
    def ping(self) -> str:
        """Test mutation"""
        return "pong"


@strawberry.type
class Subscription:
    """GraphQL Subscription root for real-time updates"""
    
    @strawberry.subscription
    async def user_updates(
        self,
        info: Info[GraphQLContext, None],
        user_id: Optional[strawberry.ID] = None
    ) -> AsyncIterator[UserType]:
        """Subscribe to user updates"""
        try:
            context: GraphQLContext = info.context
            
            # Set up subscription
            count = 0
            while count < 100:  # Limit for demo
                await asyncio.sleep(5)  # Send update every 5 seconds
                
                # Get updated user data
                if user_id:
                    user_loader = context.get_user_loader()
                    user = await user_loader.load(str(user_id))
                    if user:
                        yield user
                else:
                    # Yield a sample user update
                    sample_user = UserType(
                        id=strawberry.ID("sample-user"),
                        user_principal_name="sample@example.com",
                        display_name=f"Sample User {count}",
                        account_enabled=True
                    )
                    yield sample_user
                
                count += 1
                
        except Exception as e:
            logger.error(f"Error in user_updates subscription: {e}")
    
    @strawberry.subscription
    async def group_updates(
        self,
        info: Info[GraphQLContext, None],
        group_id: Optional[strawberry.ID] = None
    ) -> AsyncIterator[GroupTypeEntity]:
        """Subscribe to group updates"""
        try:
            context: GraphQLContext = info.context
            
            count = 0
            while count < 100:  # Limit for demo
                await asyncio.sleep(10)  # Send update every 10 seconds
                
                # Get updated group data
                if group_id:
                    group_loader = context.get_group_loader()
                    group = await group_loader.load(str(group_id))
                    if group:
                        yield group
                else:
                    # Yield a sample group update
                    sample_group = GroupTypeEntity(
                        id=strawberry.ID("sample-group"),
                        display_name=f"Sample Group {count}",
                        description="Sample group for testing",
                        mail_enabled=False,
                        security_enabled=True
                    )
                    yield sample_group
                
                count += 1
                
        except Exception as e:
            logger.error(f"Error in group_updates subscription: {e}")
    
    @strawberry.subscription
    async def service_health_updates(
        self,
        info: Info[GraphQLContext, None]
    ) -> AsyncIterator[List[ServiceHealth]]:
        """Subscribe to service health updates"""
        try:
            count = 0
            while count < 50:  # Limit for demo
                await asyncio.sleep(30)  # Send update every 30 seconds
                
                # Generate sample service health data
                services = [
                    ServiceHealth(
                        service="Microsoft Graph",
                        status="healthy" if count % 3 != 0 else "degraded",
                        status_display_name="Service Available" if count % 3 != 0 else "Service Degradation",
                        status_time=datetime.utcnow()
                    ),
                    ServiceHealth(
                        service="Exchange Online", 
                        status="healthy",
                        status_display_name="Service Available",
                        status_time=datetime.utcnow()
                    ),
                    ServiceHealth(
                        service="Microsoft Teams",
                        status="healthy" if count % 5 != 0 else "outage",
                        status_display_name="Service Available" if count % 5 != 0 else "Service Outage",
                        status_time=datetime.utcnow()
                    )
                ]
                
                yield services
                count += 1
                
        except Exception as e:
            logger.error(f"Error in service_health_updates subscription: {e}")
    
    @strawberry.subscription 
    async def change_notifications(
        self,
        info: Info[GraphQLContext, None],
        resource_types: Optional[List[str]] = None
    ) -> AsyncIterator[ChangeNotification]:
        """Subscribe to Microsoft Graph change notifications"""
        try:
            context: GraphQLContext = info.context
            event_manager = await context.get_event_manager()
            
            # This is a simplified implementation
            # In production, this would listen to actual change notifications
            count = 0
            while count < 100:  # Limit for demo
                await asyncio.sleep(15)  # Send notification every 15 seconds
                
                # Generate sample change notification
                notification = ChangeNotification(
                    id=strawberry.ID(f"notification-{count}"),
                    subscription_id=f"subscription-{count % 3}",
                    subscription_expiration_date_time=datetime.utcnow(),
                    change_type="updated",
                    resource=f"users/user-{count}",
                    tenant_id=context.tenant_id
                )
                
                yield notification
                count += 1
                
        except Exception as e:
            logger.error(f"Error in change_notifications subscription: {e}")
    
    @strawberry.subscription
    async def real_time_metrics(
        self,
        info: Info[GraphQLContext, None]
    ) -> AsyncIterator[str]:
        """Subscribe to real-time system metrics"""
        try:
            import json
            import random
            
            count = 0
            while count < 200:  # Limit for demo
                await asyncio.sleep(2)  # Send metrics every 2 seconds
                
                # Generate sample metrics
                metrics = {
                    "timestamp": datetime.utcnow().isoformat(),
                    "cpu_usage": round(random.uniform(20, 80), 2),
                    "memory_usage": round(random.uniform(40, 90), 2),
                    "api_requests_per_minute": random.randint(100, 1000),
                    "active_connections": random.randint(50, 500),
                    "response_time_ms": round(random.uniform(50, 300), 2)
                }
                
                yield json.dumps(metrics)
                count += 1
                
        except Exception as e:
            logger.error(f"Error in real_time_metrics subscription: {e}")


# Create the schema
schema = strawberry.Schema(
    query=Query,
    mutation=Mutation,
    subscription=Subscription,
    description="Microsoft 365 Management Tools GraphQL API - Phase 3 Advanced Integration"
)


# Schema introspection helpers

def get_schema_sdl() -> str:
    """Get Schema Definition Language (SDL) representation"""
    return str(schema)


def get_schema_info() -> dict:
    """Get schema information"""
    return {
        "types": len(schema.schema_converter.type_map),
        "queries": len([field for field in schema.query_type.fields]),
        "mutations": len([field for field in schema.mutation_type.fields]) if schema.mutation_type else 0,
        "subscriptions": len([field for field in schema.subscription_type.fields]) if schema.subscription_type else 0,
        "description": schema.description
    }


if __name__ == "__main__":
    # Test schema
    print("GraphQL Schema loaded successfully")
    print("Schema info:", get_schema_info())
    
    # Print available operations
    print("\nAvailable Operations:")
    
    print("\nQueries:")
    for field_name, field in schema.query_type.fields.items():
        print(f"  - {field_name}: {field.type}")
    
    if schema.mutation_type:
        print("\nMutations:")
        for field_name, field in schema.mutation_type.fields.items():
            print(f"  - {field_name}: {field.type}")
    
    if schema.subscription_type:
        print("\nSubscriptions:")
        for field_name, field in schema.subscription_type.fields.items():
            print(f"  - {field_name}: {field.type}")
    
    print(f"\nSchema has {get_schema_info()['types']} types total")