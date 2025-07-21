"""
Users API Router - Microsoft 365 User Management
Provides CRUD operations for user data with full PowerShell compatibility.
"""

from fastapi import APIRouter, HTTPException, Depends, Query, Path, status
from fastapi.responses import JSONResponse
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
import logging

from pydantic import BaseModel, Field, EmailStr, validator
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.database import DatabaseManager, User, UserLicense, get_db_manager
from ..core.auth import get_auth_manager, AuthManager
from ..core.exceptions import M365Exception, ValidationError, NotFoundError
from ..dependencies.advanced_dependencies import get_authenticated_user, require_permissions

# Simplified audit context
class AuditContext:
    async def log_operation(self, operation, resource_type, **kwargs):
        logger.info(f"Audit: {operation} on {resource_type}")

async def get_audit_context(**kwargs):
    return AuditContext()

def require_permission(permission):
    return require_permissions(permission)

logger = logging.getLogger(__name__)

# Pydantic models for request/response
class UserBase(BaseModel):
    """Base user model for requests."""
    display_name: Optional[str] = Field(None, max_length=255, description="User display name")
    mail: Optional[EmailStr] = Field(None, description="User email address")
    job_title: Optional[str] = Field(None, max_length=255, description="User job title")
    department: Optional[str] = Field(None, max_length=255, description="User department")
    office_location: Optional[str] = Field(None, max_length=255, description="Office location")
    country: Optional[str] = Field(None, max_length=100, description="Country")
    usage_location: Optional[str] = Field(None, max_length=10, description="Usage location code")
    account_enabled: bool = Field(True, description="Account enabled status")

class UserCreate(UserBase):
    """User creation model."""
    user_principal_name: str = Field(..., max_length=255, description="User Principal Name (UPN)")
    
    @validator('user_principal_name')
    def validate_upn(cls, v):
        if '@' not in v:
            raise ValueError('UPN must contain @ symbol')
        return v.lower()

class UserUpdate(UserBase):
    """User update model."""
    pass

class UserResponse(UserBase):
    """User response model."""
    id: int
    user_principal_name: str
    is_licensed: bool
    mfa_enabled: bool
    created_datetime: Optional[datetime]
    last_signin_datetime: Optional[datetime]
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class UserListResponse(BaseModel):
    """User list response with pagination."""
    users: List[UserResponse]
    total: int
    page: int
    size: int
    has_next: bool
    has_prev: bool

class UserStatsResponse(BaseModel):
    """User statistics response."""
    total_users: int
    licensed_users: int
    enabled_users: int
    mfa_enabled_users: int
    last_signin_7_days: int
    last_signin_30_days: int
    never_signed_in: int

# Router setup
router = APIRouter(
    prefix="/users",
    tags=["Users"],
    responses={
        404: {"description": "User not found"},
        422: {"description": "Validation error"},
        500: {"description": "Internal server error"}
    }
)

# CRUD Operations

@router.get("/", response_model=UserListResponse, summary="Get all users")
async def get_users(
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(50, ge=1, le=1000, description="Page size"),
    search: Optional[str] = Query(None, description="Search term for display name or UPN"),
    department: Optional[str] = Query(None, description="Filter by department"),
    licensed_only: bool = Query(False, description="Show only licensed users"),
    enabled_only: bool = Query(False, description="Show only enabled users"),
    mfa_enabled_only: bool = Query(False, description="Show only MFA enabled users"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    audit_context = Depends(get_audit_context),
    _permission_check = Depends(require_permission("users.read"))
) -> UserListResponse:
    """
    Retrieve users with advanced filtering and pagination.
    
    **PowerShell Equivalent**: `Get-M365AllUsers`
    
    Features:
    - Pagination support
    - Search by name/UPN
    - Filter by department, license, enabled status, MFA status
    - Statistics included
    """
    try:
        async with db_manager.get_session() as session:
            # Build query
            stmt = select(User)
            count_stmt = select(func.count(User.id))
            
            # Apply filters
            if search:
                search_filter = func.lower(User.display_name).contains(search.lower()) | \
                               func.lower(User.user_principal_name).contains(search.lower())
                stmt = stmt.where(search_filter)
                count_stmt = count_stmt.where(search_filter)
            
            if department:
                dept_filter = func.lower(User.department) == department.lower()
                stmt = stmt.where(dept_filter)
                count_stmt = count_stmt.where(dept_filter)
            
            if licensed_only:
                stmt = stmt.where(User.is_licensed == True)
                count_stmt = count_stmt.where(User.is_licensed == True)
            
            if enabled_only:
                stmt = stmt.where(User.account_enabled == True)
                count_stmt = count_stmt.where(User.account_enabled == True)
                
            if mfa_enabled_only:
                stmt = stmt.where(User.mfa_enabled == True)
                count_stmt = count_stmt.where(User.mfa_enabled == True)
            
            # Get total count
            total_result = await session.execute(count_stmt)
            total = total_result.scalar_one()
            
            # Apply pagination
            offset = (page - 1) * size
            stmt = stmt.offset(offset).limit(size).order_by(User.display_name)
            
            # Execute query
            result = await session.execute(stmt)
            users = result.scalars().all()
            
            # Calculate pagination info
            has_next = offset + size < total
            has_prev = page > 1
            
            # Log audit
            await audit_context.log_operation(
                operation="users.list",
                resource_type="users",
                details={
                    "page": page,
                    "size": size,
                    "total": total,
                    "filters": {
                        "search": search,
                        "department": department,
                        "licensed_only": licensed_only,
                        "enabled_only": enabled_only,
                        "mfa_enabled_only": mfa_enabled_only
                    }
                }
            )
            
            return UserListResponse(
                users=[UserResponse.from_orm(user) for user in users],
                total=total,
                page=page,
                size=size,
                has_next=has_next,
                has_prev=has_prev
            )
            
    except Exception as e:
        logger.error(f"Failed to retrieve users: {str(e)}")
        await audit_context.log_operation(
            operation="users.list",
            resource_type="users",
            status="error",
            error_message=str(e)
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve users: {str(e)}"
        )

@router.get("/stats", response_model=UserStatsResponse, summary="Get user statistics")
async def get_user_stats(
    db_manager: DatabaseManager = Depends(get_db_manager),
    audit_context = Depends(get_audit_context),
    _permission_check = Depends(require_permission("users.read"))
) -> UserStatsResponse:
    """
    Get comprehensive user statistics.
    
    **PowerShell Equivalent**: `Get-M365UserStats`
    """
    try:
        async with db_manager.get_session() as session:
            # Calculate statistics
            total_users_result = await session.execute(select(func.count(User.id)))
            total_users = total_users_result.scalar_one()
            
            licensed_users_result = await session.execute(
                select(func.count(User.id)).where(User.is_licensed == True)
            )
            licensed_users = licensed_users_result.scalar_one()
            
            enabled_users_result = await session.execute(
                select(func.count(User.id)).where(User.account_enabled == True)
            )
            enabled_users = enabled_users_result.scalar_one()
            
            mfa_enabled_users_result = await session.execute(
                select(func.count(User.id)).where(User.mfa_enabled == True)
            )
            mfa_enabled_users = mfa_enabled_users_result.scalar_one()
            
            # Recent signin statistics
            seven_days_ago = datetime.utcnow() - timedelta(days=7)
            thirty_days_ago = datetime.utcnow() - timedelta(days=30)
            
            recent_7_days_result = await session.execute(
                select(func.count(User.id)).where(User.last_signin_datetime >= seven_days_ago)
            )
            last_signin_7_days = recent_7_days_result.scalar_one()
            
            recent_30_days_result = await session.execute(
                select(func.count(User.id)).where(User.last_signin_datetime >= thirty_days_ago)
            )
            last_signin_30_days = recent_30_days_result.scalar_one()
            
            never_signed_in_result = await session.execute(
                select(func.count(User.id)).where(User.last_signin_datetime.is_(None))
            )
            never_signed_in = never_signed_in_result.scalar_one()
            
            stats = UserStatsResponse(
                total_users=total_users,
                licensed_users=licensed_users,
                enabled_users=enabled_users,
                mfa_enabled_users=mfa_enabled_users,
                last_signin_7_days=last_signin_7_days,
                last_signin_30_days=last_signin_30_days,
                never_signed_in=never_signed_in
            )
            
            await audit_context.log_operation(
                operation="users.stats",
                resource_type="users",
                details=stats.dict()
            )
            
            return stats
            
    except Exception as e:
        logger.error(f"Failed to get user statistics: {str(e)}")
        await audit_context.log_operation(
            operation="users.stats",
            resource_type="users",
            status="error",
            error_message=str(e)
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get user statistics: {str(e)}"
        )

@router.get("/{user_id}", response_model=UserResponse, summary="Get user by ID")
async def get_user(
    user_id: int = Path(..., description="User ID"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    audit_context = Depends(get_audit_context),
    _permission_check = Depends(require_permission("users.read"))
) -> UserResponse:
    """
    Retrieve a specific user by ID.
    
    **PowerShell Equivalent**: `Get-M365User -UserId {user_id}`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(User).where(User.id == user_id)
            result = await session.execute(stmt)
            user = result.scalar_one_or_none()
            
            if not user:
                raise NotFoundError(f"User with ID {user_id} not found")
            
            await audit_context.log_operation(
                operation="users.get",
                resource_type="user",
                resource_id=str(user_id)
            )
            
            return UserResponse.from_orm(user)
            
    except NotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with ID {user_id} not found"
        )
    except Exception as e:
        logger.error(f"Failed to retrieve user {user_id}: {str(e)}")
        await audit_context.log_operation(
            operation="users.get",
            resource_type="user",
            resource_id=str(user_id),
            status="error",
            error_message=str(e)
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve user: {str(e)}"
        )

@router.get("/upn/{user_principal_name}", response_model=UserResponse, summary="Get user by UPN")
async def get_user_by_upn(
    user_principal_name: str = Path(..., description="User Principal Name"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    audit_context = Depends(get_audit_context),
    _permission_check = Depends(require_permission("users.read"))
) -> UserResponse:
    """
    Retrieve a specific user by User Principal Name (UPN).
    
    **PowerShell Equivalent**: `Get-M365User -UserPrincipalName {upn}`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(User).where(User.user_principal_name == user_principal_name.lower())
            result = await session.execute(stmt)
            user = result.scalar_one_or_none()
            
            if not user:
                raise NotFoundError(f"User with UPN {user_principal_name} not found")
            
            await audit_context.log_operation(
                operation="users.get_by_upn",
                resource_type="user",
                resource_id=user_principal_name
            )
            
            return UserResponse.from_orm(user)
            
    except NotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with UPN {user_principal_name} not found"
        )
    except Exception as e:
        logger.error(f"Failed to retrieve user {user_principal_name}: {str(e)}")
        await audit_context.log_operation(
            operation="users.get_by_upn",
            resource_type="user",
            resource_id=user_principal_name,
            status="error",
            error_message=str(e)
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve user: {str(e)}"
        )

@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED, summary="Create new user")
async def create_user(
    user_data: UserCreate,
    db_manager: DatabaseManager = Depends(get_db_manager),
    audit_context = Depends(get_audit_context),
    _permission_check = Depends(require_permission("users.create"))
) -> UserResponse:
    """
    Create a new user.
    
    **PowerShell Equivalent**: `New-M365User`
    """
    try:
        async with db_manager.get_session() as session:
            # Check if UPN already exists
            existing_stmt = select(User).where(User.user_principal_name == user_data.user_principal_name)
            existing_result = await session.execute(existing_stmt)
            existing_user = existing_result.scalar_one_or_none()
            
            if existing_user:
                raise ValidationError(f"User with UPN {user_data.user_principal_name} already exists")
            
            # Create user
            user = User(
                **user_data.dict(),
                created_datetime=datetime.utcnow()
            )
            session.add(user)
            await session.commit()
            await session.refresh(user)
            
            await audit_context.log_operation(
                operation="users.create",
                resource_type="user",
                resource_id=str(user.id),
                details=user_data.dict()
            )
            
            return UserResponse.from_orm(user)
            
    except ValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Failed to create user: {str(e)}")
        await audit_context.log_operation(
            operation="users.create",
            resource_type="user",
            status="error",
            error_message=str(e),
            details=user_data.dict()
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create user: {str(e)}"
        )

@router.put("/{user_id}", response_model=UserResponse, summary="Update user")
async def update_user(
    user_id: int = Path(..., description="User ID"),
    user_data: UserUpdate = ...,
    db_manager: DatabaseManager = Depends(get_db_manager),
    audit_context = Depends(get_audit_context),
    _permission_check = Depends(require_permission("users.update"))
) -> UserResponse:
    """
    Update an existing user.
    
    **PowerShell Equivalent**: `Set-M365User -UserId {user_id}`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(User).where(User.id == user_id)
            result = await session.execute(stmt)
            user = result.scalar_one_or_none()
            
            if not user:
                raise NotFoundError(f"User with ID {user_id} not found")
            
            # Update user fields
            update_data = user_data.dict(exclude_unset=True)
            for field, value in update_data.items():
                setattr(user, field, value)
            
            user.updated_at = datetime.utcnow()
            await session.commit()
            await session.refresh(user)
            
            await audit_context.log_operation(
                operation="users.update",
                resource_type="user",
                resource_id=str(user_id),
                details=update_data
            )
            
            return UserResponse.from_orm(user)
            
    except NotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with ID {user_id} not found"
        )
    except Exception as e:
        logger.error(f"Failed to update user {user_id}: {str(e)}")
        await audit_context.log_operation(
            operation="users.update",
            resource_type="user",
            resource_id=str(user_id),
            status="error",
            error_message=str(e)
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update user: {str(e)}"
        )

@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete user")
async def delete_user(
    user_id: int = Path(..., description="User ID"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    audit_context = Depends(get_audit_context),
    _permission_check = Depends(require_permission("users.delete"))
):
    """
    Delete a user.
    
    **PowerShell Equivalent**: `Remove-M365User -UserId {user_id}`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(User).where(User.id == user_id)
            result = await session.execute(stmt)
            user = result.scalar_one_or_none()
            
            if not user:
                raise NotFoundError(f"User with ID {user_id} not found")
            
            await session.delete(user)
            await session.commit()
            
            await audit_context.log_operation(
                operation="users.delete",
                resource_type="user",
                resource_id=str(user_id),
                details={"user_principal_name": user.user_principal_name}
            )
            
    except NotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with ID {user_id} not found"
        )
    except Exception as e:
        logger.error(f"Failed to delete user {user_id}: {str(e)}")
        await audit_context.log_operation(
            operation="users.delete",
            resource_type="user",
            resource_id=str(user_id),
            status="error",
            error_message=str(e)
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete user: {str(e)}"
        )

# Bulk operations
@router.post("/bulk/create", response_model=List[UserResponse], summary="Bulk create users")
async def bulk_create_users(
    users_data: List[UserCreate],
    db_manager: DatabaseManager = Depends(get_db_manager),
    audit_context = Depends(get_audit_context),
    _permission_check = Depends(require_permission("users.bulk_create"))
) -> List[UserResponse]:
    """
    Create multiple users in bulk.
    
    **PowerShell Equivalent**: `Import-M365Users`
    """
    try:
        if len(users_data) > 1000:
            raise ValidationError("Bulk creation limited to 1000 users at a time")
        
        async with db_manager.get_session() as session:
            created_users = []
            
            for user_data in users_data:
                # Check for duplicates
                existing_stmt = select(User).where(User.user_principal_name == user_data.user_principal_name)
                existing_result = await session.execute(existing_stmt)
                existing_user = existing_result.scalar_one_or_none()
                
                if existing_user:
                    logger.warning(f"Skipping duplicate UPN: {user_data.user_principal_name}")
                    continue
                
                user = User(
                    **user_data.dict(),
                    created_datetime=datetime.utcnow()
                )
                session.add(user)
                created_users.append(user)
            
            await session.commit()
            
            # Refresh all created users
            for user in created_users:
                await session.refresh(user)
            
            await audit_context.log_operation(
                operation="users.bulk_create",
                resource_type="users",
                details={
                    "total_submitted": len(users_data),
                    "total_created": len(created_users)
                }
            )
            
            return [UserResponse.from_orm(user) for user in created_users]
            
    except ValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Failed to bulk create users: {str(e)}")
        await audit_context.log_operation(
            operation="users.bulk_create",
            resource_type="users",
            status="error",
            error_message=str(e)
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to bulk create users: {str(e)}"
        )

# Microsoft Graph integration endpoint
@router.post("/sync", summary="Sync users from Microsoft Graph")
async def sync_users_from_graph(
    force_refresh: bool = Query(False, description="Force refresh from Graph API"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    auth_manager: AuthManager = Depends(get_auth_manager),
    audit_context = Depends(get_audit_context),
    _permission_check = Depends(require_permission("users.sync"))
):
    """
    Synchronize users from Microsoft Graph API.
    
    **PowerShell Equivalent**: `Sync-M365Users`
    """
    try:
        # TODO: Implement Microsoft Graph sync logic
        # This will be implemented in the Graph integration phase
        
        await audit_context.log_operation(
            operation="users.sync",
            resource_type="users",
            details={"force_refresh": force_refresh}
        )
        
        return JSONResponse(
            status_code=status.HTTP_202_ACCEPTED,
            content={
                "message": "User synchronization initiated",
                "status": "processing"
            }
        )
        
    except Exception as e:
        logger.error(f"Failed to sync users from Graph: {str(e)}")
        await audit_context.log_operation(
            operation="users.sync",
            resource_type="users",
            status="error",
            error_message=str(e)
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to sync users: {str(e)}"
        )