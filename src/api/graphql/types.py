#!/usr/bin/env python3
"""
GraphQL Types - Phase 3 Advanced Integration
Strawberry GraphQL type definitions for Microsoft 365 entities
"""

import strawberry
from typing import List, Optional, Dict, Any
from datetime import datetime
from enum import Enum

from strawberry.scalars import JSON


@strawberry.enum
class UserStatus(Enum):
    """User account status"""
    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"
    DELETED = "deleted"


@strawberry.enum
class GroupType(Enum):
    """Microsoft 365 group types"""
    SECURITY = "security"
    DISTRIBUTION = "distribution"
    OFFICE_365 = "office365"
    DYNAMIC = "dynamic"


@strawberry.enum
class LicenseStatus(Enum):
    """License assignment status"""
    ASSIGNED = "assigned"
    UNASSIGNED = "unassigned"
    SUSPENDED = "suspended"
    WARNING = "warning"


@strawberry.type
class AssignedLicense:
    """Microsoft 365 license assignment"""
    sku_id: str
    disabled_plans: List[str] = strawberry.field(default_factory=list)
    
    @strawberry.field
    def display_name(self) -> Optional[str]:
        """Get human-readable license name"""
        license_names = {
            "6fd2c87f-b296-42f0-b197-1e91e994b900": "Office 365 E3",
            "c7df2760-2c81-4ef7-b578-5b5392b571df": "Office 365 E5",
            "18181a46-0d4e-45cd-891e-60aabd171b4e": "Office 365 E1",
            "6634e0ce-1a9f-428c-a498-f84ec7b8aa2e": "Microsoft 365 E5",
        }
        return license_names.get(self.sku_id, f"Unknown License ({self.sku_id})")


@strawberry.type
class UserType:
    """Microsoft 365 user type"""
    id: strawberry.ID
    user_principal_name: str
    display_name: Optional[str] = None
    mail: Optional[str] = None
    job_title: Optional[str] = None
    department: Optional[str] = None
    office_location: Optional[str] = None
    mobile_phone: Optional[str] = None
    business_phones: List[str] = strawberry.field(default_factory=list)
    account_enabled: bool = True
    created_date_time: Optional[datetime] = None
    last_sign_in_date_time: Optional[datetime] = None
    user_type: Optional[str] = None
    assigned_licenses: List[AssignedLicense] = strawberry.field(default_factory=list)
    
    @strawberry.field
    def status(self) -> UserStatus:
        """Get user status based on account state"""
        if not self.account_enabled:
            return UserStatus.INACTIVE
        return UserStatus.ACTIVE
    
    @strawberry.field
    def license_count(self) -> int:
        """Get number of assigned licenses"""
        return len(self.assigned_licenses)
    
    @strawberry.field
    async def groups(self, info: strawberry.Info) -> List["GroupTypeEntity"]:
        """Get groups user is member of"""
        # TODO: Implement group membership resolution
        return []


@strawberry.type
class GroupMember:
    """Group member information"""
    id: strawberry.ID
    user_principal_name: Optional[str] = None
    display_name: Optional[str] = None
    mail: Optional[str] = None
    user_type: Optional[str] = None


@strawberry.type
class GroupTypeEntity:
    """Microsoft 365 group type"""
    id: strawberry.ID
    display_name: Optional[str] = None
    description: Optional[str] = None
    mail: Optional[str] = None
    mail_enabled: bool = False
    security_enabled: bool = False
    group_types: List[str] = strawberry.field(default_factory=list)
    created_date_time: Optional[datetime] = None
    visibility: Optional[str] = None
    membership_rule: Optional[str] = None
    membership_rule_processing_state: Optional[str] = None
    
    @strawberry.field
    def group_type(self) -> GroupType:
        """Get primary group type"""
        if "Unified" in self.group_types:
            return GroupType.OFFICE_365
        elif self.security_enabled and self.mail_enabled:
            return GroupType.SECURITY
        elif self.mail_enabled:
            return GroupType.DISTRIBUTION
        elif self.membership_rule:
            return GroupType.DYNAMIC
        else:
            return GroupType.SECURITY
    
    @strawberry.field
    async def members(self, info: strawberry.Info, first: Optional[int] = 20) -> List[GroupMember]:
        """Get group members"""
        # TODO: Implement member resolution with pagination
        return []
    
    @strawberry.field
    async def member_count(self, info: strawberry.Info) -> int:
        """Get total member count"""
        # TODO: Implement member count resolution
        return 0


@strawberry.type
class TeamChannel:
    """Microsoft Teams channel"""
    id: strawberry.ID
    display_name: Optional[str] = None
    description: Optional[str] = None
    email: Optional[str] = None
    web_url: Optional[str] = None
    membership_type: Optional[str] = None
    created_date_time: Optional[datetime] = None


@strawberry.type
class TeamType:
    """Microsoft Teams team"""
    id: strawberry.ID
    display_name: Optional[str] = None
    description: Optional[str] = None
    internal_id: Optional[str] = None
    classification: Optional[str] = None
    specialization: Optional[str] = None
    visibility: Optional[str] = None
    web_url: Optional[str] = None
    is_archived: bool = False
    created_date_time: Optional[datetime] = None
    
    @strawberry.field
    async def channels(self, info: strawberry.Info) -> List[TeamChannel]:
        """Get team channels"""
        # TODO: Implement channel resolution
        return []
    
    @strawberry.field
    async def primary_channel(self, info: strawberry.Info) -> Optional[TeamChannel]:
        """Get team primary channel"""
        # TODO: Implement primary channel resolution
        return None


@strawberry.type
class DriveItem:
    """OneDrive/SharePoint drive item"""
    id: strawberry.ID
    name: Optional[str] = None
    web_url: Optional[str] = None
    created_date_time: Optional[datetime] = None
    last_modified_date_time: Optional[datetime] = None
    size: Optional[int] = None
    parent_reference: Optional[JSON] = None
    file: Optional[JSON] = None
    folder: Optional[JSON] = None
    
    @strawberry.field
    def is_file(self) -> bool:
        """Check if item is a file"""
        return self.file is not None
    
    @strawberry.field
    def is_folder(self) -> bool:
        """Check if item is a folder"""
        return self.folder is not None


@strawberry.type
class Drive:
    """OneDrive/SharePoint drive"""
    id: strawberry.ID
    name: Optional[str] = None
    description: Optional[str] = None
    drive_type: Optional[str] = None
    created_date_time: Optional[datetime] = None
    last_modified_date_time: Optional[datetime] = None
    quota: Optional[JSON] = None
    
    @strawberry.field
    async def items(self, info: strawberry.Info, first: Optional[int] = 20) -> List[DriveItem]:
        """Get drive items"""
        # TODO: Implement drive items resolution
        return []


@strawberry.type
class MailMessage:
    """Exchange Online mail message"""
    id: strawberry.ID
    subject: Optional[str] = None
    body_preview: Optional[str] = None
    importance: Optional[str] = None
    is_read: bool = False
    is_draft: bool = False
    has_attachments: bool = False
    received_date_time: Optional[datetime] = None
    sent_date_time: Optional[datetime] = None
    from_: Optional[JSON] = strawberry.field(name="from")
    to_recipients: List[JSON] = strawberry.field(default_factory=list)
    cc_recipients: List[JSON] = strawberry.field(default_factory=list)
    categories: List[str] = strawberry.field(default_factory=list)


@strawberry.type
class CalendarEvent:
    """Calendar event"""
    id: strawberry.ID
    subject: Optional[str] = None
    body_preview: Optional[str] = None
    importance: Optional[str] = None
    sensitivity: Optional[str] = None
    show_as: Optional[str] = None
    is_all_day: bool = False
    is_cancelled: bool = False
    is_organizer: bool = False
    response_requested: bool = False
    start: Optional[JSON] = None
    end: Optional[JSON] = None
    location: Optional[JSON] = None
    attendees: List[JSON] = strawberry.field(default_factory=list)
    organizer: Optional[JSON] = None
    created_date_time: Optional[datetime] = None
    last_modified_date_time: Optional[datetime] = None


@strawberry.type
class Contact:
    """Outlook contact"""
    id: strawberry.ID
    display_name: Optional[str] = None
    given_name: Optional[str] = None
    surname: Optional[str] = None
    email_addresses: List[JSON] = strawberry.field(default_factory=list)
    phone_numbers: List[JSON] = strawberry.field(default_factory=list)
    job_title: Optional[str] = None
    company_name: Optional[str] = None
    department: Optional[str] = None
    office_location: Optional[str] = None
    created_date_time: Optional[datetime] = None
    last_modified_date_time: Optional[datetime] = None


@strawberry.type
class SecurityAlert:
    """Security alert information"""
    id: strawberry.ID
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    severity: Optional[str] = None
    status: Optional[str] = None
    created_date_time: Optional[datetime] = None
    last_updated_date_time: Optional[datetime] = None
    assigned_to: Optional[str] = None
    vendor_information: Optional[JSON] = None
    cloud_app_states: List[JSON] = strawberry.field(default_factory=list)
    file_states: List[JSON] = strawberry.field(default_factory=list)
    network_connections: List[JSON] = strawberry.field(default_factory=list)
    processes: List[JSON] = strawberry.field(default_factory=list)
    user_states: List[JSON] = strawberry.field(default_factory=list)


@strawberry.type
class AuditLogRecord:
    """Audit log record"""
    id: strawberry.ID
    creation_time: Optional[datetime] = None
    operation: Optional[str] = None
    organization_id: Optional[str] = None
    record_type: Optional[str] = None
    user_id: Optional[str] = None
    user_key: Optional[str] = None
    user_type: Optional[str] = None
    version: Optional[str] = None
    workload: Optional[str] = None
    client_ip: Optional[str] = None
    object_id: Optional[str] = None
    activity: Optional[str] = None
    actor: List[JSON] = strawberry.field(default_factory=list)
    target: List[JSON] = strawberry.field(default_factory=list)


@strawberry.type
class ServiceHealth:
    """Service health status"""
    service: str
    status: str
    status_display_name: Optional[str] = None
    status_time: Optional[datetime] = None
    incident_ids: List[str] = strawberry.field(default_factory=list)


@strawberry.type
class ServiceMessage:
    """Service message/announcement"""
    id: strawberry.ID
    title: Optional[str] = None
    body: Optional[JSON] = None
    category: Optional[str] = None
    severity: Optional[str] = None
    tags: List[str] = strawberry.field(default_factory=list)
    action_type: Optional[str] = None
    classification: Optional[str] = None
    start_date_time: Optional[datetime] = None
    end_date_time: Optional[datetime] = None
    last_modified_date_time: Optional[datetime] = None
    is_major_change: bool = False
    services: List[str] = strawberry.field(default_factory=list)


@strawberry.type
class Subscription:
    """Microsoft Graph subscription"""
    id: strawberry.ID
    resource: str
    change_type: str
    client_state: Optional[str] = None
    notification_url: str
    expiration_date_time: datetime
    application_id: Optional[str] = None
    creator_id: Optional[str] = None
    include_resource_data: bool = False
    lifecycle_notification_url: Optional[str] = None
    encryption_certificate: Optional[str] = None
    encryption_certificate_id: Optional[str] = None
    latest_supported_tls_version: Optional[str] = None


@strawberry.type
class ChangeNotification:
    """Microsoft Graph change notification"""
    id: strawberry.ID
    subscription_id: str
    subscription_expiration_date_time: datetime
    change_type: str
    resource: str
    resource_data: Optional[JSON] = None
    client_state: Optional[str] = None
    tenant_id: Optional[str] = None
    site_url: Optional[str] = None
    web_url: Optional[str] = None


# Input types for mutations

@strawberry.input
class UserInput:
    """Input for creating/updating users"""
    user_principal_name: str
    display_name: Optional[str] = None
    given_name: Optional[str] = None
    surname: Optional[str] = None
    job_title: Optional[str] = None
    department: Optional[str] = None
    office_location: Optional[str] = None
    mobile_phone: Optional[str] = None
    business_phones: List[str] = strawberry.field(default_factory=list)
    account_enabled: bool = True
    mail_nickname: Optional[str] = None
    password_profile: Optional[JSON] = None
    usage_location: Optional[str] = None


@strawberry.input
class GroupInput:
    """Input for creating/updating groups"""
    display_name: str
    description: Optional[str] = None
    mail_enabled: bool = False
    mail_nickname: Optional[str] = None
    security_enabled: bool = True
    group_types: List[str] = strawberry.field(default_factory=list)
    visibility: Optional[str] = None
    membership_rule: Optional[str] = None


@strawberry.input
class SubscriptionInput:
    """Input for creating subscriptions"""
    change_type: str
    notification_url: str
    resource: str
    expiration_date_time: datetime
    client_state: Optional[str] = None
    include_resource_data: bool = False
    lifecycle_notification_url: Optional[str] = None


@strawberry.input
class FilterInput:
    """Generic filter input"""
    field: str
    operator: str  # eq, ne, gt, lt, ge, le, startsWith, endsWith, contains
    value: str


@strawberry.input
class SortInput:
    """Generic sort input"""
    field: str
    direction: str = "asc"  # asc, desc


@strawberry.input
class PaginationInput:
    """Pagination input"""
    first: Optional[int] = 20
    after: Optional[str] = None
    last: Optional[int] = None
    before: Optional[str] = None


# Connection types for pagination

@strawberry.type
class PageInfo:
    """Page information for pagination"""
    has_next_page: bool
    has_previous_page: bool
    start_cursor: Optional[str] = None
    end_cursor: Optional[str] = None


@strawberry.type
class UserEdge:
    """User edge for pagination"""
    node: UserType
    cursor: str


@strawberry.type
class UserConnection:
    """User connection for pagination"""
    edges: List[UserEdge]
    page_info: PageInfo
    total_count: int


@strawberry.type
class GroupEdge:
    """Group edge for pagination"""
    node: GroupTypeEntity
    cursor: str


@strawberry.type
class GroupConnection:
    """Group connection for pagination"""
    edges: List[GroupEdge]
    page_info: PageInfo
    total_count: int


if __name__ == "__main__":
    # Test type definitions
    print("GraphQL Types loaded successfully")
    print("Available types:")
    for name, obj in globals().items():
        if hasattr(obj, '_strawberry_type') and obj._strawberry_type:
            print(f"  - {name}")