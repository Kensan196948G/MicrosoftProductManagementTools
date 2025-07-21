"""
Reports API Router - Microsoft 365 Report Management
Provides CRUD operations for report generation with PowerShell compatibility.
"""

from fastapi import APIRouter, HTTPException, Depends, Query, Path, status, BackgroundTasks
from fastapi.responses import JSONResponse, FileResponse
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
import logging
import json
import os
from pathlib import Path as PathLib

from pydantic import BaseModel, Field, validator
from sqlalchemy import select, func, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.database import DatabaseManager, Report, get_db_manager
from ..core.auth import get_auth_manager, AuthManager
from ..core.exceptions import M365Exception, ValidationError, NotFoundError
from ..dependencies.advanced_dependencies import get_authenticated_user, require_permissions, get_request_context

logger = logging.getLogger(__name__)

# Pydantic models
class ReportBase(BaseModel):
    """Base report model."""
    report_type: str = Field(..., max_length=100, description="Report type")
    report_name: str = Field(..., max_length=255, description="Report name")
    description: Optional[str] = Field(None, description="Report description")
    file_format: str = Field("html", description="Output format (html, csv, pdf, excel)")
    
    @validator('file_format')
    def validate_format(cls, v):
        allowed_formats = ["html", "csv", "pdf", "excel", "json"]
        if v.lower() not in allowed_formats:
            raise ValueError(f"Format must be one of: {', '.join(allowed_formats)}")
        return v.lower()

class ReportCreate(ReportBase):
    """Report creation model."""
    parameters: Optional[Dict[str, Any]] = Field(None, description="Report parameters")

class ReportUpdate(BaseModel):
    """Report update model."""
    report_name: Optional[str] = Field(None, max_length=255)
    description: Optional[str] = None
    status: Optional[str] = Field(None, description="Report status")

class ReportResponse(ReportBase):
    """Report response model."""
    id: int
    parameters: Optional[Dict[str, Any]] = None
    file_path: Optional[str] = None
    file_size: Optional[int] = None
    record_count: Optional[int] = None
    generation_time: Optional[float] = None
    status: str
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class ReportStats(BaseModel):
    """Report statistics."""
    total_reports: int
    completed_reports: int
    pending_reports: int
    failed_reports: int
    average_generation_time: Optional[float] = None
    total_file_size: Optional[int] = None
    reports_by_type: Dict[str, int]
    reports_by_format: Dict[str, int]

class ReportSchedule(BaseModel):
    """Report schedule configuration."""
    report_type: str
    schedule_type: str = Field(..., description="daily, weekly, monthly, yearly")
    parameters: Optional[Dict[str, Any]] = None
    enabled: bool = True
    next_run: Optional[datetime] = None

# Router setup
router = APIRouter(
    prefix="/reports",
    tags=["Reports"],
    responses={
        404: {"description": "Report not found"},
        422: {"description": "Validation error"},
        500: {"description": "Internal server error"}
    }
)

@router.get("/", response_model=List[ReportResponse], summary="Get all reports")
async def get_reports(
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(50, ge=1, le=1000, description="Page size"),
    report_type: Optional[str] = Query(None, description="Filter by report type"),
    status: Optional[str] = Query(None, description="Filter by status"),
    file_format: Optional[str] = Query(None, description="Filter by file format"),
    start_date: Optional[datetime] = Query(None, description="Filter by creation date (start)"),
    end_date: Optional[datetime] = Query(None, description="Filter by creation date (end)"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("reports.read"))
) -> List[ReportResponse]:
    """
    Retrieve reports with advanced filtering and pagination.
    
    **PowerShell Equivalent**: `Get-M365Reports`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(Report)
            
            # Apply filters
            if report_type:
                stmt = stmt.where(Report.report_type.ilike(f"%{report_type}%"))
            
            if status:
                stmt = stmt.where(Report.status == status)
            
            if file_format:
                stmt = stmt.where(Report.file_format == file_format.lower())
            
            if start_date:
                stmt = stmt.where(Report.created_at >= start_date)
            
            if end_date:
                stmt = stmt.where(Report.created_at <= end_date)
            
            # Apply pagination
            offset = (page - 1) * size
            stmt = stmt.offset(offset).limit(size).order_by(Report.created_at.desc())
            
            result = await session.execute(stmt)
            reports = result.scalars().all()
            
            # Convert parameters JSON string to dict
            report_responses = []
            for report in reports:
                report_dict = report.__dict__.copy()
                if report.parameters:
                    try:
                        report_dict['parameters'] = json.loads(report.parameters)
                    except:
                        report_dict['parameters'] = None
                report_responses.append(ReportResponse(**report_dict))
            
            return report_responses
            
    except Exception as e:
        logger.error(f"Failed to retrieve reports: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve reports: {str(e)}"
        )

@router.get("/stats", response_model=ReportStats, summary="Get report statistics")
async def get_report_stats(
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("reports.read"))
) -> ReportStats:
    """
    Get comprehensive report statistics.
    
    **PowerShell Equivalent**: `Get-M365ReportStats`
    """
    try:
        async with db_manager.get_session() as session:
            # Total reports
            total_reports_result = await session.execute(select(func.count(Report.id)))
            total_reports = total_reports_result.scalar_one()
            
            # Reports by status
            completed_reports_result = await session.execute(
                select(func.count(Report.id)).where(Report.status == "completed")
            )
            completed_reports = completed_reports_result.scalar_one()
            
            pending_reports_result = await session.execute(
                select(func.count(Report.id)).where(Report.status == "pending")
            )
            pending_reports = pending_reports_result.scalar_one()
            
            failed_reports_result = await session.execute(
                select(func.count(Report.id)).where(Report.status == "failed")
            )
            failed_reports = failed_reports_result.scalar_one()
            
            # Average generation time
            avg_time_result = await session.execute(
                select(func.avg(Report.generation_time)).where(Report.generation_time.is_not(None))
            )
            average_generation_time = avg_time_result.scalar_one()
            
            # Total file size
            total_size_result = await session.execute(
                select(func.sum(Report.file_size)).where(Report.file_size.is_not(None))
            )
            total_file_size = total_size_result.scalar_one()
            
            # Reports by type
            type_stats_result = await session.execute(
                select(Report.report_type, func.count(Report.id)).group_by(Report.report_type)
            )
            reports_by_type = {row[0]: row[1] for row in type_stats_result}
            
            # Reports by format
            format_stats_result = await session.execute(
                select(Report.file_format, func.count(Report.id)).group_by(Report.file_format)
            )
            reports_by_format = {row[0]: row[1] for row in format_stats_result}
            
            return ReportStats(
                total_reports=total_reports,
                completed_reports=completed_reports,
                pending_reports=pending_reports,
                failed_reports=failed_reports,
                average_generation_time=round(average_generation_time, 2) if average_generation_time else None,
                total_file_size=total_file_size,
                reports_by_type=reports_by_type,
                reports_by_format=reports_by_format
            )
            
    except Exception as e:
        logger.error(f"Failed to get report statistics: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get report statistics: {str(e)}"
        )

@router.get("/{report_id}", response_model=ReportResponse, summary="Get report by ID")
async def get_report(
    report_id: int = Path(..., description="Report ID"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("reports.read"))
) -> ReportResponse:
    """
    Retrieve a specific report by ID.
    
    **PowerShell Equivalent**: `Get-M365Report -ReportId {report_id}`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(Report).where(Report.id == report_id)
            result = await session.execute(stmt)
            report = result.scalar_one_or_none()
            
            if not report:
                raise NotFoundError(f"Report with ID {report_id} not found")
            
            # Convert parameters JSON string to dict
            report_dict = report.__dict__.copy()
            if report.parameters:
                try:
                    report_dict['parameters'] = json.loads(report.parameters)
                except:
                    report_dict['parameters'] = None
            
            return ReportResponse(**report_dict)
            
    except NotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Report with ID {report_id} not found"
        )
    except Exception as e:
        logger.error(f"Failed to retrieve report {report_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve report: {str(e)}"
        )

@router.post("/", response_model=ReportResponse, status_code=status.HTTP_201_CREATED, summary="Create report")
async def create_report(
    report_data: ReportCreate,
    background_tasks: BackgroundTasks,
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("reports.create"))
) -> ReportResponse:
    """
    Create a new report generation request.
    
    **PowerShell Equivalent**: `New-M365Report`
    """
    try:
        async with db_manager.get_session() as session:
            # Create report record
            report = Report(
                report_type=report_data.report_type,
                report_name=report_data.report_name,
                description=report_data.description,
                parameters=json.dumps(report_data.parameters) if report_data.parameters else None,
                file_format=report_data.file_format,
                status="pending"
            )
            session.add(report)
            await session.commit()
            await session.refresh(report)
            
            # Schedule background report generation
            background_tasks.add_task(generate_report_background, report.id, db_manager)
            
            # Convert for response
            report_dict = report.__dict__.copy()
            if report.parameters:
                try:
                    report_dict['parameters'] = json.loads(report.parameters)
                except:
                    report_dict['parameters'] = None
            
            return ReportResponse(**report_dict)
            
    except Exception as e:
        logger.error(f"Failed to create report: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create report: {str(e)}"
        )

async def generate_report_background(report_id: int, db_manager: DatabaseManager):
    """Background task for report generation."""
    start_time = datetime.utcnow()
    
    try:
        async with db_manager.get_session() as session:
            # Get report
            stmt = select(Report).where(Report.id == report_id)
            result = await session.execute(stmt)
            report = result.scalar_one_or_none()
            
            if not report:
                logger.error(f"Report {report_id} not found for generation")
                return
            
            # Update status to processing
            report.status = "processing"
            await session.commit()
            
            # Generate report based on type
            file_path, record_count = await generate_report_by_type(
                report.report_type, 
                json.loads(report.parameters) if report.parameters else {},
                report.file_format
            )
            
            # Calculate file size
            file_size = os.path.getsize(file_path) if os.path.exists(file_path) else 0
            
            # Update report with results
            generation_time = (datetime.utcnow() - start_time).total_seconds()
            report.file_path = file_path
            report.file_size = file_size
            report.record_count = record_count
            report.generation_time = generation_time
            report.status = "completed"
            report.updated_at = datetime.utcnow()
            
            await session.commit()
            logger.info(f"Report {report_id} generated successfully in {generation_time:.2f}s")
            
    except Exception as e:
        logger.error(f"Failed to generate report {report_id}: {str(e)}")
        
        # Update report with error
        try:
            async with db_manager.get_session() as session:
                stmt = select(Report).where(Report.id == report_id)
                result = await session.execute(stmt)
                report = result.scalar_one_or_none()
                
                if report:
                    report.status = "failed"
                    report.error_message = str(e)
                    report.updated_at = datetime.utcnow()
                    await session.commit()
        except Exception as inner_e:
            logger.error(f"Failed to update report error status: {str(inner_e)}")

async def generate_report_by_type(report_type: str, parameters: Dict[str, Any], file_format: str) -> tuple:
    """Generate report based on type."""
    # TODO: Implement actual report generation logic
    # This is a placeholder that creates sample data
    
    import tempfile
    import csv
    
    # Create temporary file
    temp_dir = tempfile.gettempdir()
    file_name = f"report_{report_type}_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.{file_format}"
    file_path = os.path.join(temp_dir, file_name)
    
    # Sample data generation
    sample_data = []
    record_count = parameters.get('limit', 100)
    
    for i in range(record_count):
        if report_type == "daily":
            sample_data.append({
                "date": datetime.utcnow() - timedelta(days=i),
                "users_active": 150 + i,
                "sign_ins": 450 + i * 3,
                "failures": 2 + (i % 5)
            })
        elif report_type == "license":
            sample_data.append({
                "sku": f"Office365_E{(i % 3) + 1}",
                "assigned": 100 + i,
                "available": 50 + i,
                "cost": (25.0 + i) * (100 + i)
            })
        else:
            sample_data.append({
                "id": i + 1,
                "name": f"Item {i + 1}",
                "value": 100 + i,
                "timestamp": datetime.utcnow()
            })
    
    # Write file based on format
    if file_format == "csv":
        with open(file_path, 'w', newline='', encoding='utf-8') as csvfile:
            if sample_data:
                writer = csv.DictWriter(csvfile, fieldnames=sample_data[0].keys())
                writer.writeheader()
                writer.writerows(sample_data)
    elif file_format == "json":
        with open(file_path, 'w', encoding='utf-8') as jsonfile:
            json.dump(sample_data, jsonfile, indent=2, default=str)
    else:  # html
        html_content = f"""
        <html>
        <head><title>{report_type.title()} Report</title></head>
        <body>
        <h1>{report_type.title()} Report</h1>
        <p>Generated: {datetime.utcnow()}</p>
        <p>Records: {len(sample_data)}</p>
        <table border="1">
        """
        if sample_data:
            html_content += "<tr>"
            for key in sample_data[0].keys():
                html_content += f"<th>{key}</th>"
            html_content += "</tr>"
            
            for row in sample_data:
                html_content += "<tr>"
                for value in row.values():
                    html_content += f"<td>{value}</td>"
                html_content += "</tr>"
        
        html_content += "</table></body></html>"
        
        with open(file_path, 'w', encoding='utf-8') as htmlfile:
            htmlfile.write(html_content)
    
    return file_path, len(sample_data)

@router.put("/{report_id}", response_model=ReportResponse, summary="Update report")
async def update_report(
    report_id: int = Path(..., description="Report ID"),
    report_data: ReportUpdate = ...,
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("reports.update"))
) -> ReportResponse:
    """
    Update an existing report.
    
    **PowerShell Equivalent**: `Set-M365Report -ReportId {report_id}`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(Report).where(Report.id == report_id)
            result = await session.execute(stmt)
            report = result.scalar_one_or_none()
            
            if not report:
                raise NotFoundError(f"Report with ID {report_id} not found")
            
            # Update report fields
            update_data = report_data.dict(exclude_unset=True)
            for field, value in update_data.items():
                setattr(report, field, value)
            
            report.updated_at = datetime.utcnow()
            await session.commit()
            await session.refresh(report)
            
            # Convert for response
            report_dict = report.__dict__.copy()
            if report.parameters:
                try:
                    report_dict['parameters'] = json.loads(report.parameters)
                except:
                    report_dict['parameters'] = None
            
            return ReportResponse(**report_dict)
            
    except NotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Report with ID {report_id} not found"
        )
    except Exception as e:
        logger.error(f"Failed to update report {report_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update report: {str(e)}"
        )

@router.delete("/{report_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete report")
async def delete_report(
    report_id: int = Path(..., description="Report ID"),
    delete_file: bool = Query(True, description="Also delete the generated file"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("reports.delete"))
):
    """
    Delete a report.
    
    **PowerShell Equivalent**: `Remove-M365Report -ReportId {report_id}`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(Report).where(Report.id == report_id)
            result = await session.execute(stmt)
            report = result.scalar_one_or_none()
            
            if not report:
                raise NotFoundError(f"Report with ID {report_id} not found")
            
            # Delete file if requested and exists
            if delete_file and report.file_path and os.path.exists(report.file_path):
                try:
                    os.remove(report.file_path)
                    logger.info(f"Deleted report file: {report.file_path}")
                except Exception as e:
                    logger.warning(f"Failed to delete report file {report.file_path}: {str(e)}")
            
            await session.delete(report)
            await session.commit()
            
    except NotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Report with ID {report_id} not found"
        )
    except Exception as e:
        logger.error(f"Failed to delete report {report_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete report: {str(e)}"
        )

@router.get("/{report_id}/download", summary="Download report file")
async def download_report(
    report_id: int = Path(..., description="Report ID"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("reports.export"))
):
    """
    Download the generated report file.
    
    **PowerShell Equivalent**: `Export-M365Report -ReportId {report_id}`
    """
    try:
        async with db_manager.get_session() as session:
            stmt = select(Report).where(Report.id == report_id)
            result = await session.execute(stmt)
            report = result.scalar_one_or_none()
            
            if not report:
                raise NotFoundError(f"Report with ID {report_id} not found")
            
            if not report.file_path or not os.path.exists(report.file_path):
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Report file not found"
                )
            
            if report.status != "completed":
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Report is not ready for download. Status: {report.status}"
                )
            
            # Determine media type
            media_type_map = {
                "csv": "text/csv",
                "html": "text/html", 
                "json": "application/json",
                "pdf": "application/pdf",
                "excel": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            }
            media_type = media_type_map.get(report.file_format, "application/octet-stream")
            
            return FileResponse(
                path=report.file_path,
                media_type=media_type,
                filename=f"{report.report_name}_{report.id}.{report.file_format}"
            )
            
    except NotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Report with ID {report_id} not found"
        )
    except Exception as e:
        logger.error(f"Failed to download report {report_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to download report: {str(e)}"
        )

# Predefined report types
@router.post("/generate/daily", response_model=ReportResponse, summary="Generate daily report")
async def generate_daily_report(
    background_tasks: BackgroundTasks,
    date: Optional[datetime] = Query(None, description="Report date (default: yesterday)"),
    file_format: str = Query("html", description="Output format"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("reports.create"))
) -> ReportResponse:
    """
    Generate daily activity report.
    
    **PowerShell Equivalent**: `New-M365DailyReport`
    """
    report_date = date or (datetime.utcnow() - timedelta(days=1))
    
    report_data = ReportCreate(
        report_type="daily",
        report_name=f"Daily Report - {report_date.strftime('%Y-%m-%d')}",
        description=f"Daily activity report for {report_date.strftime('%Y-%m-%d')}",
        file_format=file_format,
        parameters={"date": report_date.isoformat(), "limit": 1000}
    )
    
    return await create_report(report_data, background_tasks, db_manager, user)

@router.post("/generate/license-analysis", response_model=ReportResponse, summary="Generate license analysis report")
async def generate_license_analysis_report(
    background_tasks: BackgroundTasks,
    include_costs: bool = Query(False, description="Include cost analysis"),
    file_format: str = Query("html", description="Output format"),
    db_manager: DatabaseManager = Depends(get_db_manager),
    user: Dict[str, Any] = Depends(require_permissions("reports.create"))
) -> ReportResponse:
    """
    Generate license analysis report.
    
    **PowerShell Equivalent**: `New-M365LicenseAnalysisReport`
    """
    report_data = ReportCreate(
        report_type="license",
        report_name=f"License Analysis - {datetime.utcnow().strftime('%Y-%m-%d')}",
        description="Comprehensive license usage and cost analysis",
        file_format=file_format,
        parameters={"include_costs": include_costs, "limit": 500}
    )
    
    return await create_report(report_data, background_tasks, db_manager, user)