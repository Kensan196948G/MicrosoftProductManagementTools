"""
Licenses API Router - Microsoft 365 License Management
Provides CRUD operations for license data with PowerShell compatibility.
"""

from fastapi import APIRouter, HTTPException, Depends, Query, Path, status
from fastapi.responses import JSONResponse
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
import logging

from pydantic import BaseModel, Field, validator
from sqlalchemy import select, func, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.database import DatabaseManager, UserLicense, User, get_db_manager
from ..core.auth import get_auth_manager, AuthManager
from ..core.exceptions import M365Exception, ValidationError, NotFoundError
from ..dependencies.advanced_dependencies import get_authenticated_user, require_permissions, get_request_context

logger = logging.getLogger(__name__)

# Pydantic models
class LicenseBase(BaseModel):
    """Base license model."""
    sku_part_number: str = Field(..., max_length=100, description="SKU part number")
    display_name: str = Field(..., max_length=255, description="License display name")
    consumed_units: int = Field(0, ge=0, description="Consumed license units")
    enabled_units: int = Field(0, ge=0, description="Enabled license units")
    suspended_units: int = Field(0, ge=0, description="Suspended license units")
    warning_units: int = Field(0, ge=0, description="Warning license units")

class LicenseCreate(LicenseBase):
    """License creation model."""
    user_id: int = Field(..., description="User ID")
    sku_id: str = Field(..., max_length=100, description="SKU ID")
    assigned_datetime: Optional[datetime] = Field(None, description="Assignment datetime")

class LicenseUpdate(BaseModel):
    """License update model."""
    consumed_units: Optional[int] = Field(None, ge=0)
    enabled_units: Optional[int] = Field(None, ge=0)
    suspended_units: Optional[int] = Field(None, ge=0)
    warning_units: Optional[int] = Field(None, ge=0)
    assigned_datetime: Optional[datetime] = None

class LicenseResponse(LicenseBase):
    """License response model."""
    id: int
    user_id: int
    sku_id: str
    assigned_datetime: Optional[datetime]
    created_at: datetime
    updated_at: datetime
    
    # User information
    user_principal_name: Optional[str] = None
    user_display_name: Optional[str] = None
    
    class Config:
        from_attributes = True

class LicenseAnalysisResponse(BaseModel):
    """License analysis response."""
    sku_part_number: str
    display_name: str
    total_units: int
    consumed_units: int
    available_units: int
    utilization_percentage: float
    cost_per_unit: Optional[float] = None
    estimated_monthly_cost: Optional[float] = None
    assigned_users: int
    last_assignment: Optional[datetime] = None

class LicenseUsageResponse(BaseModel):
    """License usage statistics."""
    total_licenses: int
    active_licenses: int
    suspended_licenses: int
    warning_licenses: int
    total_users_licensed: int
    total_cost_estimate: Optional[float] = None
    top_used_licenses: List[LicenseAnalysisResponse]
    underutilized_licenses: List[LicenseAnalysisResponse]

# Router setup
router = APIRouter(
    prefix="/licenses",
    tags=["Licenses"],
    responses={
        404: {"description": "License not found"},
        422: {"description": "Validation error"},
        500: {"description": "Internal server error"}
    }
)

@router.get("/", response_model=List[LicenseResponse], summary="Get all licenses")
async def get_licenses(
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(50, ge=1, le=1000, description="Page size"),
    sku_part_number: Optional[str] = Query(None, description="Filter by SKU part number"),
    user_id: Optional[int] = Query(None, description="Filter by user ID"),
    include_user_info: bool = Query(True, description="Include user information"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("licenses.read"))
) -> List[LicenseResponse]:
    """
    Retrieve licenses with advanced filtering and pagination.
    
    **PowerShell Equivalent**: `Get-M365LicenseAssignments`
    """
    try:
        async with db_manager.get_session() as session:
            # Build query with joins if user info requested
            if include_user_info:
                stmt = select(UserLicense, User.user_principal_name, User.display_name)\
                    .join(User, UserLicense.user_id == User.id)
            else:
                stmt = select(UserLicense)
            
            # Apply filters
            if sku_part_number:
                stmt = stmt.where(UserLicense.sku_part_number.ilike(f"%{sku_part_number}%"))
            
            if user_id:
                stmt = stmt.where(UserLicense.user_id == user_id)
            
            # Apply pagination
            offset = (page - 1) * size
            stmt = stmt.offset(offset).limit(size).order_by(UserLicense.created_at.desc())
            
            result = await session.execute(stmt)
            
            if include_user_info:
                licenses_data = []
                for license_obj, user_principal_name, user_display_name in result:
                    license_dict = {
                        **license_obj.__dict__,
                        "user_principal_name": user_principal_name,
                        "user_display_name": user_display_name
                    }
                    licenses_data.append(LicenseResponse(**license_dict))
                return licenses_data
            else:
                licenses = result.scalars().all()
                return [LicenseResponse.from_orm(license) for license in licenses]
            
    except Exception as e:
        logger.error(f"Failed to retrieve licenses: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve licenses: {str(e)}"
        )

@router.get("/analysis", response_model=List[LicenseAnalysisResponse], summary="Get license analysis")
async def get_license_analysis(
    top_n: int = Query(10, ge=1, le=100, description="Top N licenses to analyze"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("licenses.analyze"))
) -> List[LicenseAnalysisResponse]:
    """
    Get comprehensive license analysis.
    
    **PowerShell Equivalent**: `Get-M365LicenseAnalysis`
    """
    try:
        async with db_manager.get_session() as session:
            # Get license statistics
            stmt = select(
                UserLicense.sku_part_number,
                UserLicense.display_name,
                func.sum(UserLicense.enabled_units).label('total_units'),
                func.sum(UserLicense.consumed_units).label('consumed_units'),
                func.count(UserLicense.id).label('assigned_users'),
                func.max(UserLicense.assigned_datetime).label('last_assignment')
            ).group_by(
                UserLicense.sku_part_number,
                UserLicense.display_name
            ).order_by(
                func.sum(UserLicense.consumed_units).desc()
            ).limit(top_n)
            
            result = await session.execute(stmt)
            analysis_data = []
            
            for row in result:
                available_units = row.total_units - row.consumed_units
                utilization_percentage = (row.consumed_units / row.total_units * 100) if row.total_units > 0 else 0
                
                analysis_data.append(LicenseAnalysisResponse(
                    sku_part_number=row.sku_part_number,
                    display_name=row.display_name,
                    total_units=row.total_units,
                    consumed_units=row.consumed_units,
                    available_units=available_units,
                    utilization_percentage=round(utilization_percentage, 2),
                    assigned_users=row.assigned_users,
                    last_assignment=row.last_assignment
                ))
            
            return analysis_data
            
    except Exception as e:
        logger.error(f"Failed to get license analysis: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get license analysis: {str(e)}"
        )

@router.get("/usage", response_model=LicenseUsageResponse, summary="Get license usage statistics")
async def get_license_usage(
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("licenses.read"))
) -> LicenseUsageResponse:
    """
    Get comprehensive license usage statistics.
    
    **PowerShell Equivalent**: `Get-M365LicenseUsage`
    """
    try:
        async with db_manager.get_session() as session:
            # Get total statistics
            total_licenses_result = await session.execute(select(func.count(UserLicense.id)))
            total_licenses = total_licenses_result.scalar_one()
            
            active_licenses_result = await session.execute(
                select(func.count(UserLicense.id)).where(UserLicense.consumed_units > 0)
            )
            active_licenses = active_licenses_result.scalar_one()
            
            suspended_licenses_result = await session.execute(
                select(func.count(UserLicense.id)).where(UserLicense.suspended_units > 0)
            )
            suspended_licenses = suspended_licenses_result.scalar_one()
            
            warning_licenses_result = await session.execute(
                select(func.count(UserLicense.id)).where(UserLicense.warning_units > 0)
            )
            warning_licenses = warning_licenses_result.scalar_one()
            
            # Get unique licensed users
            licensed_users_result = await session.execute(
                select(func.count(func.distinct(UserLicense.user_id)))
            )
            total_users_licensed = licensed_users_result.scalar_one()
            
            # Get top used licenses
            top_used_stmt = select(
                UserLicense.sku_part_number,
                UserLicense.display_name,
                func.sum(UserLicense.enabled_units).label('total_units'),
                func.sum(UserLicense.consumed_units).label('consumed_units'),
                func.count(UserLicense.id).label('assigned_users'),
                func.max(UserLicense.assigned_datetime).label('last_assignment')
            ).group_by(
                UserLicense.sku_part_number,
                UserLicense.display_name
            ).order_by(
                func.sum(UserLicense.consumed_units).desc()
            ).limit(5)
            
            top_used_result = await session.execute(top_used_stmt)
            top_used_licenses = []
            
            for row in top_used_result:
                available_units = row.total_units - row.consumed_units
                utilization_percentage = (row.consumed_units / row.total_units * 100) if row.total_units > 0 else 0
                
                top_used_licenses.append(LicenseAnalysisResponse(
                    sku_part_number=row.sku_part_number,
                    display_name=row.display_name,
                    total_units=row.total_units,
                    consumed_units=row.consumed_units,
                    available_units=available_units,
                    utilization_percentage=round(utilization_percentage, 2),
                    assigned_users=row.assigned_users,
                    last_assignment=row.last_assignment
                ))
            
            # Get underutilized licenses (utilization < 50%)
            underutilized_stmt = select(
                UserLicense.sku_part_number,
                UserLicense.display_name,
                func.sum(UserLicense.enabled_units).label('total_units'),
                func.sum(UserLicense.consumed_units).label('consumed_units'),
                func.count(UserLicense.id).label('assigned_users'),
                func.max(UserLicense.assigned_datetime).label('last_assignment')
            ).group_by(
                UserLicense.sku_part_number,
                UserLicense.display_name
            ).having(
                and_(
                    func.sum(UserLicense.enabled_units) > 0,
                    (func.sum(UserLicense.consumed_units) / func.sum(UserLicense.enabled_units)) < 0.5
                )
            ).order_by(
                (func.sum(UserLicense.consumed_units) / func.sum(UserLicense.enabled_units)).asc()
            ).limit(5)
            
            underutilized_result = await session.execute(underutilized_stmt)
            underutilized_licenses = []
            
            for row in underutilized_result:
                available_units = row.total_units - row.consumed_units
                utilization_percentage = (row.consumed_units / row.total_units * 100) if row.total_units > 0 else 0
                
                underutilized_licenses.append(LicenseAnalysisResponse(
                    sku_part_number=row.sku_part_number,
                    display_name=row.display_name,
                    total_units=row.total_units,
                    consumed_units=row.consumed_units,
                    available_units=available_units,
                    utilization_percentage=round(utilization_percentage, 2),
                    assigned_users=row.assigned_users,
                    last_assignment=row.last_assignment
                ))
            
            return LicenseUsageResponse(
                total_licenses=total_licenses,
                active_licenses=active_licenses,
                suspended_licenses=suspended_licenses,
                warning_licenses=warning_licenses,
                total_users_licensed=total_users_licensed,
                top_used_licenses=top_used_licenses,
                underutilized_licenses=underutilized_licenses
            )
            
    except Exception as e:
        logger.error(f"Failed to get license usage: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get license usage: {str(e)}"
        )

@router.get("/{license_id}", response_model=LicenseResponse, summary="Get license by ID")
async def get_license(
    license_id: int = Path(..., description="License ID"),
    include_user_info: bool = Query(True, description="Include user information"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("licenses.read"))
) -> LicenseResponse:
    """
    Retrieve a specific license by ID.
    
    **PowerShell Equivalent**: `Get-M365License -LicenseId {license_id}`
    """
    try:
        async with db_manager.get_session() as session:
            if include_user_info:
                stmt = select(UserLicense, User.user_principal_name, User.display_name)\
                    .join(User, UserLicense.user_id == User.id)\
                    .where(UserLicense.id == license_id)
                result = await session.execute(stmt)
                license_data = result.first()
                
                if not license_data:
                    raise NotFoundError(f"License with ID {license_id} not found")
                
                license_obj, user_principal_name, user_display_name = license_data
                license_dict = {
                    **license_obj.__dict__,
                    "user_principal_name": user_principal_name,
                    "user_display_name": user_display_name
                }
                return LicenseResponse(**license_dict)
            else:
                stmt = select(UserLicense).where(UserLicense.id == license_id)
                result = await session.execute(stmt)
                license_obj = result.scalar_one_or_none()
                
                if not license_obj:
                    raise NotFoundError(f"License with ID {license_id} not found")
                
                return LicenseResponse.from_orm(license_obj)
            
    except NotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"License with ID {license_id} not found"
        )
    except Exception as e:
        logger.error(f"Failed to retrieve license {license_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve license: {str(e)}"
        )

@router.post("/", response_model=LicenseResponse, status_code=status.HTTP_201_CREATED, summary="Create license assignment")
async def create_license(
    license_data: LicenseCreate,
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("licenses.create"))
) -> LicenseResponse:
    """
    Create a new license assignment.
    
    **PowerShell Equivalent**: `New-M365LicenseAssignment`
    """
    try:
        async with db_manager.get_session() as session:
            # Check if user exists
            user_stmt = select(User).where(User.id == license_data.user_id)
            user_result = await session.execute(user_stmt)
            user_obj = user_result.scalar_one_or_none()
            
            if not user_obj:
                raise ValidationError(f"User with ID {license_data.user_id} not found")
            
            # Check for duplicate assignment
            existing_stmt = select(UserLicense).where(
                and_(
                    UserLicense.user_id == license_data.user_id,
                    UserLicense.sku_part_number == license_data.sku_part_number
                )
            )
            existing_result = await session.execute(existing_stmt)
            existing_license = existing_result.scalar_one_or_none()
            
            if existing_license:
                raise ValidationError(
                    f"License {license_data.sku_part_number} already assigned to user {license_data.user_id}"
                )
            
            # Create license assignment
            license_obj = UserLicense(
                **license_data.dict(),
                assigned_datetime=license_data.assigned_datetime or datetime.utcnow()
            )
            session.add(license_obj)
            await session.commit()
            await session.refresh(license_obj)
            
            return LicenseResponse.from_orm(license_obj)
            
    except ValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Failed to create license: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create license: {str(e)}"
        )

@router.put("/{license_id}", response_model=LicenseResponse, summary="Update license")
async def update_license(
    license_id: int = Path(..., description="License ID"),
    license_data: LicenseUpdate = ...,
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("licenses.update"))
) -> LicenseResponse:
    """
    Update an existing license.
    
    **PowerShell Equivalent**: `Set-M365License -LicenseId {license_id}`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(UserLicense).where(UserLicense.id == license_id)
            result = await session.execute(stmt)
            license_obj = result.scalar_one_or_none()
            
            if not license_obj:
                raise NotFoundError(f"License with ID {license_id} not found")
            
            # Update license fields
            update_data = license_data.dict(exclude_unset=True)
            for field, value in update_data.items():
                setattr(license_obj, field, value)
            
            license_obj.updated_at = datetime.utcnow()
            await session.commit()
            await session.refresh(license_obj)
            
            return LicenseResponse.from_orm(license_obj)
            
    except NotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"License with ID {license_id} not found"
        )
    except Exception as e:
        logger.error(f"Failed to update license {license_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update license: {str(e)}"
        )

@router.delete("/{license_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete license assignment")
async def delete_license(
    license_id: int = Path(..., description="License ID"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("licenses.delete"))
):
    """
    Delete a license assignment.
    
    **PowerShell Equivalent**: `Remove-M365LicenseAssignment -LicenseId {license_id}`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(UserLicense).where(UserLicense.id == license_id)
            result = await session.execute(stmt)
            license_obj = result.scalar_one_or_none()
            
            if not license_obj:
                raise NotFoundError(f"License with ID {license_id} not found")
            
            await session.delete(license_obj)
            await session.commit()
            
    except NotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"License with ID {license_id} not found"
        )
    except Exception as e:
        logger.error(f"Failed to delete license {license_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete license: {str(e)}"
        )

# Bulk operations
@router.post("/bulk/assign", response_model=List[LicenseResponse], summary="Bulk assign licenses")
async def bulk_assign_licenses(
    assignments: List[LicenseCreate],
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("licenses.create"))
) -> List[LicenseResponse]:
    """
    Assign licenses to multiple users in bulk.
    
    **PowerShell Equivalent**: `Import-M365LicenseAssignments`
    """
    try:
        if len(assignments) > 1000:
            raise ValidationError("Bulk assignment limited to 1000 licenses at a time")
        
        async with db_manager.get_session() as session:
            created_licenses = []
            
            for assignment in assignments:
                # Check if user exists
                user_stmt = select(User).where(User.id == assignment.user_id)
                user_result = await session.execute(user_stmt)
                user_obj = user_result.scalar_one_or_none()
                
                if not user_obj:
                    logger.warning(f"Skipping assignment: User {assignment.user_id} not found")
                    continue
                
                # Check for duplicate
                existing_stmt = select(UserLicense).where(
                    and_(
                        UserLicense.user_id == assignment.user_id,
                        UserLicense.sku_part_number == assignment.sku_part_number
                    )
                )
                existing_result = await session.execute(existing_stmt)
                existing_license = existing_result.scalar_one_or_none()
                
                if existing_license:
                    logger.warning(f"Skipping duplicate assignment: {assignment.sku_part_number} for user {assignment.user_id}")
                    continue
                
                license_obj = UserLicense(
                    **assignment.dict(),
                    assigned_datetime=assignment.assigned_datetime or datetime.utcnow()
                )
                session.add(license_obj)
                created_licenses.append(license_obj)
            
            await session.commit()
            
            # Refresh all created licenses
            for license_obj in created_licenses:
                await session.refresh(license_obj)
            
            return [LicenseResponse.from_orm(license_obj) for license_obj in created_licenses]
            
    except ValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Failed to bulk assign licenses: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to bulk assign licenses: {str(e)}"
        )

# Microsoft Graph integration endpoint
@router.post("/sync", summary="Sync licenses from Microsoft Graph")
async def sync_licenses_from_graph(
    force_refresh: bool = Query(False, description="Force refresh from Graph API"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    auth_manager: AuthManager = Depends(get_auth_manager),
    user: Dict[str, Any] = Depends(require_permissions("licenses.sync"))
):
    """
    Synchronize licenses from Microsoft Graph API.
    
    **PowerShell Equivalent**: `Sync-M365Licenses`
    """
    try:
        # TODO: Implement Microsoft Graph sync logic
        # This will be implemented in the Graph integration phase
        
        return JSONResponse(
            status_code=status.HTTP_202_ACCEPTED,
            content={
                "message": "License synchronization initiated",
                "status": "processing",
                "force_refresh": force_refresh
            }
        )
        
    except Exception as e:
        logger.error(f"Failed to sync licenses from Graph: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to sync licenses: {str(e)}"
        )