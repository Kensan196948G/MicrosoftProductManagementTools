"""
Audit API Router - Microsoft 365 Audit Trail Management
Provides read-only access to audit logs with PowerShell compatibility.
"""

from fastapi import APIRouter, HTTPException, Depends, Query, Path, status
from fastapi.responses import JSONResponse, StreamingResponse
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
import logging
import json
import io
import csv

from pydantic import BaseModel, Field, validator
from sqlalchemy import select, func, and_, or_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.database import DatabaseManager, AuditLog, get_db_manager
from ..core.auth import get_auth_manager, AuthManager
from ..core.exceptions import M365Exception, ValidationError, NotFoundError
from ..dependencies.advanced_dependencies import get_authenticated_user, require_permissions, get_request_context

logger = logging.getLogger(__name__)

# Pydantic models
class AuditLogResponse(BaseModel):
    """Audit log response model."""
    id: int
    operation: str
    resource_type: str
    resource_id: Optional[str]
    user_principal_name: Optional[str]
    details: Optional[Dict[str, Any]] = None
    ip_address: Optional[str]
    user_agent: Optional[str]
    status: str
    error_message: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True

class AuditStats(BaseModel):
    """Audit statistics."""
    total_logs: int
    successful_operations: int
    failed_operations: int
    unique_users: int
    unique_operations: int
    operations_by_type: Dict[str, int]
    operations_by_resource: Dict[str, int]
    operations_by_status: Dict[str, int]
    operations_by_hour: Dict[str, int]
    top_users: List[Dict[str, Any]]
    recent_failures: List[AuditLogResponse]

class AuditExportRequest(BaseModel):
    """Audit export request."""
    start_date: Optional[datetime] = Field(None, description="Start date for export")
    end_date: Optional[datetime] = Field(None, description="End date for export")
    operation: Optional[str] = Field(None, description="Filter by operation")
    resource_type: Optional[str] = Field(None, description="Filter by resource type")
    user_principal_name: Optional[str] = Field(None, description="Filter by user")
    status: Optional[str] = Field(None, description="Filter by status")
    format: str = Field("csv", description="Export format (csv, json)")
    
    @validator('format')
    def validate_format(cls, v):
        if v.lower() not in ["csv", "json"]:
            raise ValueError("Format must be csv or json")
        return v.lower()

class AuditSearchRequest(BaseModel):
    """Audit search request."""
    query: str = Field(..., description="Search query")
    fields: List[str] = Field(["operation", "resource_type", "user_principal_name"], description="Fields to search")
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    limit: int = Field(100, ge=1, le=10000)

# Router setup
router = APIRouter(
    prefix="/audit",
    tags=["Audit"],
    responses={
        404: {"description": "Audit log not found"},
        422: {"description": "Validation error"},
        500: {"description": "Internal server error"}
    }
)

@router.get("/", response_model=List[AuditLogResponse], summary="Get audit logs")
async def get_audit_logs(
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(50, ge=1, le=1000, description="Page size"),
    operation: Optional[str] = Query(None, description="Filter by operation"),
    resource_type: Optional[str] = Query(None, description="Filter by resource type"),
    user_principal_name: Optional[str] = Query(None, description="Filter by user"),
    status: Optional[str] = Query(None, description="Filter by status (success, error)"),
    start_date: Optional[datetime] = Query(None, description="Start date filter"),
    end_date: Optional[datetime] = Query(None, description="End date filter"),
    ip_address: Optional[str] = Query(None, description="Filter by IP address"),
    sort_by: str = Query("created_at", description="Sort field"),
    sort_order: str = Query("desc", description="Sort order (asc, desc)"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("audit.read"))
) -> List[AuditLogResponse]:
    """
    Retrieve audit logs with advanced filtering and pagination.
    
    **PowerShell Equivalent**: `Get-M365AuditLogs`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(AuditLog)
            
            # Apply filters
            if operation:
                stmt = stmt.where(AuditLog.operation.ilike(f"%{operation}%"))
            
            if resource_type:
                stmt = stmt.where(AuditLog.resource_type.ilike(f"%{resource_type}%"))
            
            if user_principal_name:
                stmt = stmt.where(AuditLog.user_principal_name.ilike(f"%{user_principal_name}%"))
            
            if status:
                stmt = stmt.where(AuditLog.status == status)
            
            if start_date:
                stmt = stmt.where(AuditLog.created_at >= start_date)
            
            if end_date:
                stmt = stmt.where(AuditLog.created_at <= end_date)
            
            if ip_address:
                stmt = stmt.where(AuditLog.ip_address == ip_address)
            
            # Apply sorting
            sort_column = getattr(AuditLog, sort_by, AuditLog.created_at)
            if sort_order.lower() == "desc":
                stmt = stmt.order_by(desc(sort_column))
            else:
                stmt = stmt.order_by(sort_column)
            
            # Apply pagination
            offset = (page - 1) * size
            stmt = stmt.offset(offset).limit(size)
            
            result = await session.execute(stmt)
            audit_logs = result.scalars().all()
            
            # Convert details JSON string to dict
            audit_responses = []
            for log in audit_logs:
                log_dict = log.__dict__.copy()
                if log.details:
                    try:
                        log_dict['details'] = json.loads(log.details)
                    except:
                        log_dict['details'] = None
                audit_responses.append(AuditLogResponse(**log_dict))
            
            return audit_responses
            
    except Exception as e:
        logger.error(f"Failed to retrieve audit logs: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve audit logs: {str(e)}"
        )

@router.get("/stats", response_model=AuditStats, summary="Get audit statistics")
async def get_audit_stats(
    start_date: Optional[datetime] = Query(None, description="Start date for stats"),
    end_date: Optional[datetime] = Query(None, description="End date for stats"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("audit.read"))
) -> AuditStats:
    """
    Get comprehensive audit statistics.
    
    **PowerShell Equivalent**: `Get-M365AuditStats`
    """
    try:
        async with db_manager.get_session() as session:
            # Base query with optional date filtering
            base_filter = []
            if start_date:
                base_filter.append(AuditLog.created_at >= start_date)
            if end_date:
                base_filter.append(AuditLog.created_at <= end_date)
            
            # Total logs
            total_stmt = select(func.count(AuditLog.id))
            if base_filter:
                total_stmt = total_stmt.where(and_(*base_filter))
            total_result = await session.execute(total_stmt)
            total_logs = total_result.scalar_one()
            
            # Successful operations
            success_stmt = select(func.count(AuditLog.id)).where(AuditLog.status == "success")
            if base_filter:
                success_stmt = success_stmt.where(and_(*base_filter))
            success_result = await session.execute(success_stmt)
            successful_operations = success_result.scalar_one()
            
            # Failed operations
            failed_stmt = select(func.count(AuditLog.id)).where(AuditLog.status == "error")
            if base_filter:
                failed_stmt = failed_stmt.where(and_(*base_filter))
            failed_result = await session.execute(failed_stmt)
            failed_operations = failed_result.scalar_one()
            
            # Unique users
            unique_users_stmt = select(func.count(func.distinct(AuditLog.user_principal_name)))
            if base_filter:
                unique_users_stmt = unique_users_stmt.where(and_(*base_filter))
            unique_users_result = await session.execute(unique_users_stmt)
            unique_users = unique_users_result.scalar_one()
            
            # Unique operations
            unique_ops_stmt = select(func.count(func.distinct(AuditLog.operation)))
            if base_filter:
                unique_ops_stmt = unique_ops_stmt.where(and_(*base_filter))
            unique_ops_result = await session.execute(unique_ops_stmt)
            unique_operations = unique_ops_result.scalar_one()
            
            # Operations by type
            ops_by_type_stmt = select(AuditLog.operation, func.count(AuditLog.id)).group_by(AuditLog.operation)
            if base_filter:
                ops_by_type_stmt = ops_by_type_stmt.where(and_(*base_filter))
            ops_by_type_result = await session.execute(ops_by_type_stmt)
            operations_by_type = {row[0]: row[1] for row in ops_by_type_result}
            
            # Operations by resource
            ops_by_resource_stmt = select(AuditLog.resource_type, func.count(AuditLog.id)).group_by(AuditLog.resource_type)
            if base_filter:
                ops_by_resource_stmt = ops_by_resource_stmt.where(and_(*base_filter))
            ops_by_resource_result = await session.execute(ops_by_resource_stmt)
            operations_by_resource = {row[0]: row[1] for row in ops_by_resource_result}
            
            # Operations by status
            ops_by_status_stmt = select(AuditLog.status, func.count(AuditLog.id)).group_by(AuditLog.status)
            if base_filter:
                ops_by_status_stmt = ops_by_status_stmt.where(and_(*base_filter))
            ops_by_status_result = await session.execute(ops_by_status_stmt)
            operations_by_status = {row[0]: row[1] for row in ops_by_status_result}
            
            # Operations by hour (last 24 hours)
            from sqlalchemy import extract
            hour_stmt = select(
                extract('hour', AuditLog.created_at).label('hour'),
                func.count(AuditLog.id)
            ).where(
                AuditLog.created_at >= datetime.utcnow() - timedelta(hours=24)
            ).group_by(extract('hour', AuditLog.created_at))
            hour_result = await session.execute(hour_stmt)
            operations_by_hour = {f"{int(row[0]):02d}:00": row[1] for row in hour_result}
            
            # Top users by activity
            top_users_stmt = select(
                AuditLog.user_principal_name,
                func.count(AuditLog.id).label('activity_count')
            ).where(
                AuditLog.user_principal_name.is_not(None)
            ).group_by(
                AuditLog.user_principal_name
            ).order_by(
                desc(func.count(AuditLog.id))
            ).limit(10)
            
            if base_filter:
                top_users_stmt = top_users_stmt.where(and_(*base_filter))
            
            top_users_result = await session.execute(top_users_stmt)
            top_users = [
                {"user": row[0], "activity_count": row[1]} 
                for row in top_users_result
            ]
            
            # Recent failures (last 10)
            recent_failures_stmt = select(AuditLog).where(
                AuditLog.status == "error"
            ).order_by(
                desc(AuditLog.created_at)
            ).limit(10)
            
            recent_failures_result = await session.execute(recent_failures_stmt)
            recent_failures_logs = recent_failures_result.scalars().all()
            
            recent_failures = []
            for log in recent_failures_logs:
                log_dict = log.__dict__.copy()
                if log.details:
                    try:
                        log_dict['details'] = json.loads(log.details)
                    except:
                        log_dict['details'] = None
                recent_failures.append(AuditLogResponse(**log_dict))
            
            return AuditStats(
                total_logs=total_logs,
                successful_operations=successful_operations,
                failed_operations=failed_operations,
                unique_users=unique_users,
                unique_operations=unique_operations,
                operations_by_type=operations_by_type,
                operations_by_resource=operations_by_resource,
                operations_by_status=operations_by_status,
                operations_by_hour=operations_by_hour,
                top_users=top_users,
                recent_failures=recent_failures
            )
            
    except Exception as e:
        logger.error(f"Failed to get audit statistics: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get audit statistics: {str(e)}"
        )

@router.get("/{audit_id}", response_model=AuditLogResponse, summary="Get audit log by ID")
async def get_audit_log(
    audit_id: int = Path(..., description="Audit log ID"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("audit.read"))
) -> AuditLogResponse:
    """
    Retrieve a specific audit log by ID.
    
    **PowerShell Equivalent**: `Get-M365AuditLog -AuditId {audit_id}`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(AuditLog).where(AuditLog.id == audit_id)
            result = await session.execute(stmt)
            audit_log = result.scalar_one_or_none()
            
            if not audit_log:
                raise NotFoundError(f"Audit log with ID {audit_id} not found")
            
            # Convert details JSON string to dict
            log_dict = audit_log.__dict__.copy()
            if audit_log.details:
                try:
                    log_dict['details'] = json.loads(audit_log.details)
                except:
                    log_dict['details'] = None
            
            return AuditLogResponse(**log_dict)
            
    except NotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Audit log with ID {audit_id} not found"
        )
    except Exception as e:
        logger.error(f"Failed to retrieve audit log {audit_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve audit log: {str(e)}"
        )

@router.post("/search", response_model=List[AuditLogResponse], summary="Search audit logs")
async def search_audit_logs(
    search_request: AuditSearchRequest,
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("audit.read"))
) -> List[AuditLogResponse]:
    """
    Search audit logs with advanced text search.
    
    **PowerShell Equivalent**: `Search-M365AuditLogs`
    """
    try:
        async with db_manager.get_session() as session:
            # Build search conditions
            search_conditions = []
            query = f"%{search_request.query}%"
            
            if "operation" in search_request.fields:
                search_conditions.append(AuditLog.operation.ilike(query))
            if "resource_type" in search_request.fields:
                search_conditions.append(AuditLog.resource_type.ilike(query))
            if "user_principal_name" in search_request.fields:
                search_conditions.append(AuditLog.user_principal_name.ilike(query))
            if "resource_id" in search_request.fields:
                search_conditions.append(AuditLog.resource_id.ilike(query))
            if "details" in search_request.fields:
                search_conditions.append(AuditLog.details.ilike(query))
            if "error_message" in search_request.fields:
                search_conditions.append(AuditLog.error_message.ilike(query))
            
            if not search_conditions:
                raise ValidationError("No valid search fields specified")
            
            stmt = select(AuditLog).where(or_(*search_conditions))
            
            # Apply date filters
            if search_request.start_date:
                stmt = stmt.where(AuditLog.created_at >= search_request.start_date)
            
            if search_request.end_date:
                stmt = stmt.where(AuditLog.created_at <= search_request.end_date)
            
            # Apply limit and ordering
            stmt = stmt.order_by(desc(AuditLog.created_at)).limit(search_request.limit)
            
            result = await session.execute(stmt)
            audit_logs = result.scalars().all()
            
            # Convert details JSON string to dict
            audit_responses = []
            for log in audit_logs:
                log_dict = log.__dict__.copy()
                if log.details:
                    try:
                        log_dict['details'] = json.loads(log.details)
                    except:
                        log_dict['details'] = None
                audit_responses.append(AuditLogResponse(**log_dict))
            
            return audit_responses
            
    except ValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Failed to search audit logs: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to search audit logs: {str(e)}"
        )

@router.post("/export", summary="Export audit logs")
async def export_audit_logs(
    export_request: AuditExportRequest,
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("audit.export"))
):
    """
    Export audit logs to CSV or JSON format.
    
    **PowerShell Equivalent**: `Export-M365AuditLogs`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(AuditLog)
            
            # Apply filters
            filters = []
            if export_request.start_date:
                filters.append(AuditLog.created_at >= export_request.start_date)
            
            if export_request.end_date:
                filters.append(AuditLog.created_at <= export_request.end_date)
            
            if export_request.operation:
                filters.append(AuditLog.operation.ilike(f"%{export_request.operation}%"))
            
            if export_request.resource_type:
                filters.append(AuditLog.resource_type.ilike(f"%{export_request.resource_type}%"))
            
            if export_request.user_principal_name:
                filters.append(AuditLog.user_principal_name.ilike(f"%{export_request.user_principal_name}%"))
            
            if export_request.status:
                filters.append(AuditLog.status == export_request.status)
            
            if filters:
                stmt = stmt.where(and_(*filters))
            
            stmt = stmt.order_by(desc(AuditLog.created_at))
            
            result = await session.execute(stmt)
            audit_logs = result.scalars().all()
            
            # Prepare data for export
            export_data = []
            for log in audit_logs:
                log_data = {
                    "id": log.id,
                    "operation": log.operation,
                    "resource_type": log.resource_type,
                    "resource_id": log.resource_id,
                    "user_principal_name": log.user_principal_name,
                    "ip_address": log.ip_address,
                    "user_agent": log.user_agent,
                    "status": log.status,
                    "error_message": log.error_message,
                    "created_at": log.created_at.isoformat() if log.created_at else None
                }
                
                # Parse details if JSON
                if log.details:
                    try:
                        details = json.loads(log.details)
                        log_data["details"] = details
                    except:
                        log_data["details"] = log.details
                else:
                    log_data["details"] = None
                
                export_data.append(log_data)
            
            # Generate export file
            if export_request.format == "csv":
                output = io.StringIO()
                if export_data:
                    # Flatten details for CSV
                    flattened_data = []
                    for row in export_data:
                        flat_row = row.copy()
                        if row["details"] and isinstance(row["details"], dict):
                            # Add details as separate columns
                            for key, value in row["details"].items():
                                flat_row[f"details_{key}"] = str(value) if value is not None else ""
                        flat_row["details"] = str(row["details"]) if row["details"] else ""
                        flattened_data.append(flat_row)
                    
                    writer = csv.DictWriter(output, fieldnames=flattened_data[0].keys())
                    writer.writeheader()
                    writer.writerows(flattened_data)
                
                content = output.getvalue()
                output.close()
                
                filename = f"audit_logs_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.csv"
                media_type = "text/csv"
                
            else:  # JSON
                content = json.dumps(export_data, indent=2, default=str)
                filename = f"audit_logs_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json"
                media_type = "application/json"
            
            # Return as streaming response
            return StreamingResponse(
                io.BytesIO(content.encode('utf-8')),
                media_type=media_type,
                headers={"Content-Disposition": f"attachment; filename={filename}"}
            )
            
    except Exception as e:
        logger.error(f"Failed to export audit logs: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to export audit logs: {str(e)}"
        )

@router.get("/operations/types", summary="Get available operation types")
async def get_operation_types(
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("audit.read"))
) -> List[str]:
    """
    Get list of available operation types.
    
    **PowerShell Equivalent**: `Get-M365AuditOperationTypes`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(func.distinct(AuditLog.operation)).order_by(AuditLog.operation)
            result = await session.execute(stmt)
            operations = [row[0] for row in result if row[0] is not None]
            
            return operations
            
    except Exception as e:
        logger.error(f"Failed to get operation types: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get operation types: {str(e)}"
        )

@router.get("/resources/types", summary="Get available resource types")
async def get_resource_types(
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("audit.read"))
) -> List[str]:
    """
    Get list of available resource types.
    
    **PowerShell Equivalent**: `Get-M365AuditResourceTypes`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(func.distinct(AuditLog.resource_type)).order_by(AuditLog.resource_type)
            result = await session.execute(stmt)
            resource_types = [row[0] for row in result if row[0] is not None]
            
            return resource_types
            
    except Exception as e:
        logger.error(f"Failed to get resource types: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get resource types: {str(e)}"
        )

@router.delete("/cleanup", summary="Cleanup old audit logs")
async def cleanup_audit_logs(
    days: int = Query(90, ge=1, le=365, description="Delete logs older than N days"),
    dry_run: bool = Query(True, description="Dry run mode (don't actually delete)"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("admin.full"))
):
    """
    Cleanup old audit logs (admin only).
    
    **PowerShell Equivalent**: `Clear-M365AuditLogs`
    """
    try:
        cutoff_date = datetime.utcnow() - timedelta(days=days)
        
        async with db_manager.get_session() as session:
            # Count logs to be deleted
            count_stmt = select(func.count(AuditLog.id)).where(AuditLog.created_at < cutoff_date)
            count_result = await session.execute(count_stmt)
            logs_to_delete = count_result.scalar_one()
            
            if dry_run:
                return JSONResponse(
                    content={
                        "message": f"Dry run: Would delete {logs_to_delete} audit logs older than {days} days",
                        "cutoff_date": cutoff_date.isoformat(),
                        "logs_to_delete": logs_to_delete,
                        "dry_run": True
                    }
                )
            
            # Actually delete logs
            deleted_count = await db_manager.cleanup_old_audit_logs(days)
            
            return JSONResponse(
                content={
                    "message": f"Successfully deleted {deleted_count} audit logs older than {days} days",
                    "cutoff_date": cutoff_date.isoformat(),
                    "deleted_count": deleted_count,
                    "dry_run": False
                }
            )
            
    except Exception as e:
        logger.error(f"Failed to cleanup audit logs: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to cleanup audit logs: {str(e)}"
        )