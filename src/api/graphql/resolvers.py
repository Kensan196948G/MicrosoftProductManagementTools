#!/usr/bin/env python3
"""
GraphQL Resolvers - Phase 3 Advanced Integration
Strawberry GraphQL resolvers for Microsoft 365 data
"""

import asyncio
import logging
from typing import List, Optional, Dict, Any, Union
from datetime import datetime, timedelta
import json
import base64

import strawberry
from strawberry.types import Info
from strawberry.dataloader import DataLoader

from .types import (
    UserType, GroupTypeEntity, TeamType, DriveItem, Drive,
    MailMessage, CalendarEvent, Contact, SecurityAlert, AuditLogRecord,
    ServiceHealth, ServiceMessage, Subscription, ChangeNotification,
    UserInput, GroupInput, SubscriptionInput, FilterInput, SortInput, PaginationInput,
    UserConnection, GroupConnection, UserEdge, GroupEdge, PageInfo,
    AssignedLicense
)
from src.api.microsoft_graph_client import create_graph_client
from src.api.websocket.realtime_events import RealtimeEventManager, ResourceType, ChangeType
from src.core.auth.authenticator import get_current_user_from_token

logger = logging.getLogger(__name__)


class GraphQLContext:
    """GraphQL context with user information and services"""
    
    def __init__(self, user_id: str, tenant_id: str, permissions: List[str]):
        self.user_id = user_id
        self.tenant_id = tenant_id
        self.permissions = permissions
        self.graph_client = None
        self.event_manager = None
        self._user_loader = None
        self._group_loader = None
        
    async def get_graph_client(self):
        """Get Microsoft Graph client"""
        if not self.graph_client:
            self.graph_client = create_graph_client(async_mode=True)
        return self.graph_client
    
    async def get_event_manager(self):
        """Get realtime event manager"""
        if not self.event_manager:
            self.event_manager = RealtimeEventManager()
            await self.event_manager.initialize()
        return self.event_manager
    
    def get_user_loader(self) -> DataLoader:
        """Get user data loader for batching"""
        if not self._user_loader:
            self._user_loader = DataLoader(load_fn=self._load_users)
        return self._user_loader
    
    def get_group_loader(self) -> DataLoader:
        """Get group data loader for batching"""
        if not self._group_loader:
            self._group_loader = DataLoader(load_fn=self._load_groups)
        return self._group_loader
    
    async def _load_users(self, user_ids: List[str]) -> List[Optional[UserType]]:
        """Batch load users by IDs"""
        try:
            graph_client = await self.get_graph_client()
            users = []
            
            async with graph_client:
                for user_id in user_ids:
                    try:
                        user_data = await graph_client.get_user_by_id(user_id)
                        if user_data:
                            user = self._convert_user_data(user_data)
                            users.append(user)
                        else:
                            users.append(None)
                    except Exception as e:
                        logger.error(f"Error loading user {user_id}: {e}")
                        users.append(None)
            
            return users
        except Exception as e:
            logger.error(f"Error in batch user loading: {e}")
            return [None] * len(user_ids)
    
    async def _load_groups(self, group_ids: List[str]) -> List[Optional[GroupTypeEntity]]:
        """Batch load groups by IDs"""
        try:
            graph_client = await self.get_graph_client()
            groups = []
            
            async with graph_client:
                for group_id in group_ids:
                    try:
                        # TODO: Implement get_group_by_id in graph client
                        group_data = await self._get_group_by_id(graph_client, group_id)
                        if group_data:
                            group = self._convert_group_data(group_data)
                            groups.append(group)
                        else:
                            groups.append(None)
                    except Exception as e:
                        logger.error(f"Error loading group {group_id}: {e}")
                        groups.append(None)
            
            return groups
        except Exception as e:
            logger.error(f"Error in batch group loading: {e}")
            return [None] * len(group_ids)
    
    async def _get_group_by_id(self, graph_client, group_id: str) -> Optional[Dict[str, Any]]:
        """Get group by ID (placeholder implementation)"""
        # TODO: Implement actual group retrieval
        return None
    
    def _convert_user_data(self, user_data: Dict[str, Any]) -> UserType:
        """Convert raw user data to UserType"""
        assigned_licenses = []
        if user_data.get('assignedLicenses'):
            for license_data in user_data['assignedLicenses']:
                license_obj = AssignedLicense(
                    sku_id=license_data.get('skuId', ''),
                    disabled_plans=license_data.get('disabledPlans', [])
                )
                assigned_licenses.append(license_obj)
        
        return UserType(
            id=user_data['id'],
            user_principal_name=user_data.get('userPrincipalName', ''),
            display_name=user_data.get('displayName'),
            mail=user_data.get('mail'),
            job_title=user_data.get('jobTitle'),
            department=user_data.get('department'),
            office_location=user_data.get('officeLocation'),
            mobile_phone=user_data.get('mobilePhone'),
            business_phones=user_data.get('businessPhones', []),
            account_enabled=user_data.get('accountEnabled', True),
            created_date_time=self._parse_datetime(user_data.get('createdDateTime')),
            last_sign_in_date_time=self._parse_datetime(user_data.get('lastSignInDateTime')),
            user_type=user_data.get('userType'),
            assigned_licenses=assigned_licenses
        )
    
    def _convert_group_data(self, group_data: Dict[str, Any]) -> GroupTypeEntity:
        """Convert raw group data to GroupTypeEntity"""
        return GroupTypeEntity(
            id=group_data['id'],
            display_name=group_data.get('displayName'),
            description=group_data.get('description'),
            mail=group_data.get('mail'),
            mail_enabled=group_data.get('mailEnabled', False),
            security_enabled=group_data.get('securityEnabled', False),
            group_types=group_data.get('groupTypes', []),
            created_date_time=self._parse_datetime(group_data.get('createdDateTime')),
            visibility=group_data.get('visibility'),
            membership_rule=group_data.get('membershipRule'),
            membership_rule_processing_state=group_data.get('membershipRuleProcessingState')
        )
    
    def _parse_datetime(self, date_str: Optional[str]) -> Optional[datetime]:
        """Parse ISO datetime string"""
        if not date_str:
            return None
        try:
            return datetime.fromisoformat(date_str.replace('Z', '+00:00'))
        except (ValueError, AttributeError):
            return None


@strawberry.type
class QueryResolver:
    """GraphQL Query resolver"""
    
    @strawberry.field
    async def users(
        self,
        info: Info[GraphQLContext, Any],
        first: Optional[int] = 20,
        after: Optional[str] = None,
        filters: Optional[List[FilterInput]] = None,
        sort: Optional[List[SortInput]] = None,
        search: Optional[str] = None
    ) -> UserConnection:
        """Get users with pagination and filtering"""
        try:
            context: GraphQLContext = info.context
            graph_client = await context.get_graph_client()
            
            # Build query parameters
            query_params = {
                'top': min(first or 20, 100),  # Limit max results
                'use_cache': True
            }
            
            # Add search
            if search:
                query_params['search'] = f'"{search}"'
            
            # Add filters
            if filters:
                filter_expressions = []
                for filter_input in filters:
                    expr = self._build_filter_expression(filter_input)
                    if expr:
                        filter_expressions.append(expr)
                
                if filter_expressions:
                    query_params['filter_expr'] = ' and '.join(filter_expressions)
            
            # Add sorting
            if sort:
                order_by_expressions = []
                for sort_input in sort:
                    direction = 'desc' if sort_input.direction.lower() == 'desc' else 'asc'
                    order_by_expressions.append(f"{sort_input.field} {direction}")
                
                if order_by_expressions:
                    query_params['order_by'] = ','.join(order_by_expressions)
            
            # Add pagination cursor
            if after:
                try:
                    skip = int(base64.b64decode(after).decode())
                    query_params['skip'] = skip
                except (ValueError, UnicodeDecodeError):
                    pass
            
            # Execute query
            async with graph_client:
                users_data = await graph_client.get_users(**query_params)
            
            # Convert to GraphQL types
            edges = []
            for i, user_data in enumerate(users_data.get('value', [])):
                user = context._convert_user_data(user_data)
                cursor = base64.b64encode(str(query_params.get('skip', 0) + i + 1).encode()).decode()
                edges.append(UserEdge(node=user, cursor=cursor))
            
            # Build page info
            has_next_page = len(edges) == query_params['top']
            has_previous_page = query_params.get('skip', 0) > 0
            start_cursor = edges[0].cursor if edges else None
            end_cursor = edges[-1].cursor if edges else None
            
            page_info = PageInfo(
                has_next_page=has_next_page,
                has_previous_page=has_previous_page,
                start_cursor=start_cursor,
                end_cursor=end_cursor
            )
            
            return UserConnection(
                edges=edges,
                page_info=page_info,
                total_count=len(edges)  # TODO: Get actual total count
            )
            
        except Exception as e:
            logger.error(f"Error resolving users: {e}")
            raise
    
    @strawberry.field
    async def user(
        self,
        info: Info[GraphQLContext, Any],
        id: strawberry.ID
    ) -> Optional[UserType]:
        """Get user by ID"""
        try:
            context: GraphQLContext = info.context
            user_loader = context.get_user_loader()
            return await user_loader.load(str(id))
        except Exception as e:
            logger.error(f"Error resolving user {id}: {e}")
            return None
    
    @strawberry.field
    async def groups(
        self,
        info: Info[GraphQLContext, Any],
        first: Optional[int] = 20,
        after: Optional[str] = None,
        filters: Optional[List[FilterInput]] = None,
        sort: Optional[List[SortInput]] = None,
        search: Optional[str] = None
    ) -> GroupConnection:
        """Get groups with pagination and filtering"""
        try:
            context: GraphQLContext = info.context
            graph_client = await context.get_graph_client()
            
            # Build query parameters
            query_params = {
                'top': min(first or 20, 100),
                'use_cache': True
            }
            
            if search:
                query_params['search'] = f'"{search}"'
            
            if filters:
                filter_expressions = []
                for filter_input in filters:
                    expr = self._build_filter_expression(filter_input)
                    if expr:
                        filter_expressions.append(expr)
                
                if filter_expressions:
                    query_params['filter_expr'] = ' and '.join(filter_expressions)
            
            if sort:
                order_by_expressions = []
                for sort_input in sort:
                    direction = 'desc' if sort_input.direction.lower() == 'desc' else 'asc'
                    order_by_expressions.append(f"{sort_input.field} {direction}")
                
                if order_by_expressions:
                    query_params['order_by'] = ','.join(order_by_expressions)
            
            if after:
                try:
                    skip = int(base64.b64decode(after).decode())
                    query_params['skip'] = skip
                except (ValueError, UnicodeDecodeError):
                    pass
            
            # Execute query
            async with graph_client:
                groups_data = await graph_client.get_groups(**query_params)
            
            # Convert to GraphQL types
            edges = []
            for i, group_data in enumerate(groups_data.get('value', [])):
                group = context._convert_group_data(group_data)
                cursor = base64.b64encode(str(query_params.get('skip', 0) + i + 1).encode()).decode()
                edges.append(GroupEdge(node=group, cursor=cursor))
            
            # Build page info
            has_next_page = len(edges) == query_params['top']
            has_previous_page = query_params.get('skip', 0) > 0
            start_cursor = edges[0].cursor if edges else None
            end_cursor = edges[-1].cursor if edges else None
            
            page_info = PageInfo(
                has_next_page=has_next_page,
                has_previous_page=has_previous_page,
                start_cursor=start_cursor,
                end_cursor=end_cursor
            )
            
            return GroupConnection(
                edges=edges,
                page_info=page_info,
                total_count=len(edges)
            )
            
        except Exception as e:
            logger.error(f"Error resolving groups: {e}")
            raise
    
    @strawberry.field
    async def group(
        self,
        info: Info[GraphQLContext, Any],
        id: strawberry.ID
    ) -> Optional[GroupTypeEntity]:
        """Get group by ID"""
        try:
            context: GraphQLContext = info.context
            group_loader = context.get_group_loader()
            return await group_loader.load(str(id))
        except Exception as e:
            logger.error(f"Error resolving group {id}: {e}")
            return None
    
    @strawberry.field
    async def me(self, info: Info[GraphQLContext, Any]) -> Optional[UserType]:
        """Get current user"""
        try:
            context: GraphQLContext = info.context
            user_loader = context.get_user_loader()
            return await user_loader.load(context.user_id)
        except Exception as e:
            logger.error(f"Error resolving current user: {e}")
            return None
    
    @strawberry.field
    async def service_health(
        self,
        info: Info[GraphQLContext, Any]
    ) -> List[ServiceHealth]:
        """Get service health status"""
        try:
            # TODO: Implement service health retrieval
            return [
                ServiceHealth(
                    service="Microsoft Graph",
                    status="healthy",
                    status_display_name="Service Available",
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
                    status="degraded",
                    status_display_name="Service Degradation",
                    status_time=datetime.utcnow()
                )
            ]
        except Exception as e:
            logger.error(f"Error resolving service health: {e}")
            return []
    
    @strawberry.field
    async def subscriptions(
        self,
        info: Info[GraphQLContext, Any]
    ) -> List[Subscription]:
        """Get Microsoft Graph subscriptions"""
        try:
            context: GraphQLContext = info.context
            event_manager = await context.get_event_manager()
            
            # Get subscriptions for current tenant
            tenant_subscriptions = [
                sub for sub in event_manager.subscriptions.values()
                if sub.tenant_id == context.tenant_id and sub.is_active
            ]
            
            result = []
            for sub in tenant_subscriptions:
                subscription = Subscription(
                    id=sub.id,
                    resource=sub.resource,
                    change_type=','.join([ct.value for ct in sub.change_type]),
                    client_state=sub.client_state,
                    notification_url=sub.notification_url,
                    expiration_date_time=sub.expiration_date_time
                )
                result.append(subscription)
            
            return result
            
        except Exception as e:
            logger.error(f"Error resolving subscriptions: {e}")
            return []
    
    def _build_filter_expression(self, filter_input: FilterInput) -> Optional[str]:
        """Build OData filter expression"""
        try:
            field = filter_input.field
            operator = filter_input.operator
            value = filter_input.value
            
            # Map operators to OData syntax
            if operator == "eq":
                return f"{field} eq '{value}'"
            elif operator == "ne":
                return f"{field} ne '{value}'"
            elif operator == "gt":
                return f"{field} gt '{value}'"
            elif operator == "lt":
                return f"{field} lt '{value}'"
            elif operator == "ge":
                return f"{field} ge '{value}'"
            elif operator == "le":
                return f"{field} le '{value}'"
            elif operator == "startsWith":
                return f"startsWith({field}, '{value}')"
            elif operator == "endsWith":
                return f"endsWith({field}, '{value}')"
            elif operator == "contains":
                return f"contains({field}, '{value}')"
            else:
                logger.warning(f"Unknown filter operator: {operator}")
                return None
                
        except Exception as e:
            logger.error(f"Error building filter expression: {e}")
            return None


@strawberry.type
class MutationResolver:
    """GraphQL Mutation resolver"""
    
    @strawberry.mutation
    async def create_user(
        self,
        info: Info[GraphQLContext, Any],
        input: UserInput
    ) -> UserType:
        """Create new user"""
        try:
            context: GraphQLContext = info.context
            
            # Check permissions
            if "user.create" not in context.permissions:
                raise Exception("Insufficient permissions to create user")
            
            graph_client = await context.get_graph_client()
            
            # TODO: Implement user creation via Graph API
            user_data = {
                'userPrincipalName': input.user_principal_name,
                'displayName': input.display_name,
                'givenName': input.given_name,
                'surname': input.surname,
                'jobTitle': input.job_title,
                'department': input.department,
                'officeLocation': input.office_location,
                'mobilePhone': input.mobile_phone,
                'businessPhones': input.business_phones,
                'accountEnabled': input.account_enabled,
                'mailNickname': input.mail_nickname,
                'passwordProfile': input.password_profile,
                'usageLocation': input.usage_location
            }
            
            # Create user via Graph API (placeholder)
            created_user_data = await self._create_user_via_graph(graph_client, user_data)
            
            # Convert to GraphQL type
            return context._convert_user_data(created_user_data)
            
        except Exception as e:
            logger.error(f"Error creating user: {e}")
            raise
    
    @strawberry.mutation
    async def update_user(
        self,
        info: Info[GraphQLContext, Any],
        id: strawberry.ID,
        input: UserInput
    ) -> UserType:
        """Update existing user"""
        try:
            context: GraphQLContext = info.context
            
            # Check permissions
            if "user.update" not in context.permissions:
                raise Exception("Insufficient permissions to update user")
            
            graph_client = await context.get_graph_client()
            
            # TODO: Implement user update via Graph API
            update_data = {
                'displayName': input.display_name,
                'givenName': input.given_name,
                'surname': input.surname,
                'jobTitle': input.job_title,
                'department': input.department,
                'officeLocation': input.office_location,
                'mobilePhone': input.mobile_phone,
                'businessPhones': input.business_phones,
                'accountEnabled': input.account_enabled,
                'usageLocation': input.usage_location
            }
            
            # Update user via Graph API (placeholder)
            updated_user_data = await self._update_user_via_graph(graph_client, str(id), update_data)
            
            # Convert to GraphQL type
            return context._convert_user_data(updated_user_data)
            
        except Exception as e:
            logger.error(f"Error updating user {id}: {e}")
            raise
    
    @strawberry.mutation
    async def delete_user(
        self,
        info: Info[GraphQLContext, Any],
        id: strawberry.ID
    ) -> bool:
        """Delete user"""
        try:
            context: GraphQLContext = info.context
            
            # Check permissions
            if "user.delete" not in context.permissions:
                raise Exception("Insufficient permissions to delete user")
            
            graph_client = await context.get_graph_client()
            
            # TODO: Implement user deletion via Graph API
            await self._delete_user_via_graph(graph_client, str(id))
            
            return True
            
        except Exception as e:
            logger.error(f"Error deleting user {id}: {e}")
            raise
    
    @strawberry.mutation
    async def create_subscription(
        self,
        info: Info[GraphQLContext, Any],
        input: SubscriptionInput
    ) -> Subscription:
        """Create Microsoft Graph subscription"""
        try:
            context: GraphQLContext = info.context
            
            # Check permissions
            if "subscription.create" not in context.permissions:
                raise Exception("Insufficient permissions to create subscription")
            
            event_manager = await context.get_event_manager()
            
            # Parse change types
            change_types = [ChangeType(ct.strip()) for ct in input.change_type.split(',')]
            
            # Create subscription
            subscription_id = await event_manager.create_subscription(
                resource=input.resource,
                change_types=change_types,
                tenant_id=context.tenant_id,
                expiration_hours=24  # Default 24 hours
            )
            
            # Return created subscription
            return Subscription(
                id=subscription_id,
                resource=input.resource,
                change_type=input.change_type,
                client_state=input.client_state,
                notification_url=input.notification_url,
                expiration_date_time=input.expiration_date_time,
                include_resource_data=input.include_resource_data,
                lifecycle_notification_url=input.lifecycle_notification_url
            )
            
        except Exception as e:
            logger.error(f"Error creating subscription: {e}")
            raise
    
    @strawberry.mutation
    async def delete_subscription(
        self,
        info: Info[GraphQLContext, Any],
        id: strawberry.ID
    ) -> bool:
        """Delete Microsoft Graph subscription"""
        try:
            context: GraphQLContext = info.context
            
            # Check permissions
            if "subscription.delete" not in context.permissions:
                raise Exception("Insufficient permissions to delete subscription")
            
            event_manager = await context.get_event_manager()
            
            # Delete subscription
            await event_manager.delete_subscription(str(id))
            
            return True
            
        except Exception as e:
            logger.error(f"Error deleting subscription {id}: {e}")
            raise
    
    # Placeholder methods for Graph API operations
    async def _create_user_via_graph(self, graph_client, user_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create user via Microsoft Graph API (placeholder)"""
        # TODO: Implement actual Graph API call
        return {
            'id': 'new-user-id',
            **user_data,
            'createdDateTime': datetime.utcnow().isoformat()
        }
    
    async def _update_user_via_graph(self, graph_client, user_id: str, update_data: Dict[str, Any]) -> Dict[str, Any]:
        """Update user via Microsoft Graph API (placeholder)"""
        # TODO: Implement actual Graph API call
        return {
            'id': user_id,
            **update_data,
            'lastModifiedDateTime': datetime.utcnow().isoformat()
        }
    
    async def _delete_user_via_graph(self, graph_client, user_id: str):
        """Delete user via Microsoft Graph API (placeholder)"""
        # TODO: Implement actual Graph API call
        pass


if __name__ == "__main__":
    # Test resolvers
    print("GraphQL Resolvers loaded successfully")
    print("Available resolvers:")
    print("  - QueryResolver")
    print("  - MutationResolver")