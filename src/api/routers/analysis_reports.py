"""
Microsoft 365管理ツール 分析レポートAPI
===================================

分析レポート機能 REST API実装 (5機能)
- ライセンス分析
- 使用状況分析
- パフォーマンス監視
- セキュリティ分析  
- 権限監査
"""

from datetime import date, datetime, timedelta
from typing import List, Optional, Dict, Any
from decimal import Decimal
from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, and_, or_
from pydantic import BaseModel, Field

from ...database.connection import get_async_session
from ...database.models import (
    LicenseAnalysis, ServiceUsageAnalysis, PerformanceMonitoring,
    SecurityAnalysis, PermissionAudit
)

router = APIRouter(prefix="/analysis-reports", tags=["分析レポート"])


# ========================================
# Pydanticモデル（レスポンス）
# ========================================

class LicenseAnalysisResponse(BaseModel):
    """ライセンス分析レスポンス"""
    id: int
    report_date: date
    license_type: str
    user_name: Optional[str]
    department: Optional[str]
    total_licenses: int
    assigned_licenses: int
    available_licenses: int
    utilization_rate: Optional[float]
    monthly_cost: Optional[float]
    expiration_date: Optional[date]
    created_at: datetime
    
    class Config:
        from_attributes = True


class ServiceUsageAnalysisResponse(BaseModel):
    """使用状況分析レスポンス"""
    id: int
    report_date: date
    service_name: str
    active_users: int
    total_users: int
    adoption_rate: Optional[float]
    daily_active_users: int
    weekly_active_users: int
    monthly_active_users: int
    trend_direction: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


class PerformanceMonitoringResponse(BaseModel):
    """パフォーマンス監視レスポンス"""
    id: int
    timestamp: datetime
    service_name: str
    response_time_ms: Optional[int]
    availability_percent: Optional[float]
    throughput_mbps: Optional[float]
    error_rate: Optional[float]
    status: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


class SecurityAnalysisResponse(BaseModel):
    """セキュリティ分析レスポンス"""
    id: int
    report_date: date
    security_item: str
    status: Optional[str]
    target_users: Optional[int]
    compliance_rate_percent: Optional[float]
    risk_level: Optional[str]
    last_check_date: Optional[datetime]
    recommended_action: Optional[str]
    details: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


class PermissionAuditResponse(BaseModel):
    """権限監査レスポンス"""
    id: int
    report_date: date
    user_name: str
    email: str
    department: Optional[str]
    admin_role: Optional[str]
    access_rights: Optional[str]
    last_login: Optional[datetime]
    mfa_status: Optional[str]
    status: Optional[str]
    audit_date: date
    created_at: datetime
    
    class Config:
        from_attributes = True


class PaginatedResponse(BaseModel):
    """ページネーションレスポンス"""
    items: List[Any]
    total: int
    page: int
    size: int
    pages: int


class AnalysisRequest(BaseModel):
    """分析リクエスト"""
    analysis_type: str = Field(..., description="分析種別")
    start_date: Optional[date] = Field(None, description="開始日")
    end_date: Optional[date] = Field(None, description="終了日")
    filters: Optional[Dict[str, Any]] = Field(None, description="フィルター条件")


# ========================================
# ライセンス分析API
# ========================================

@router.get("/license",
           response_model=PaginatedResponse,
           summary="ライセンス分析レポート一覧",
           description="ライセンス利用状況分析データを取得")
async def get_license_analysis(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    license_type: Optional[str] = Query(None, description="ライセンス種別"),
    department: Optional[str] = Query(None, description="部署"),
    low_utilization: bool = Query(False, description="低利用率のみ表示"),
    session: AsyncSession = Depends(get_async_session)
):
    """ライセンス分析データ一覧取得"""
    
    try:
        query = select(LicenseAnalysis)
        count_query = select(func.count(LicenseAnalysis.id))
        
        filters = []
        if license_type:
            filters.append(LicenseAnalysis.license_type.contains(license_type))
        if department:
            filters.append(LicenseAnalysis.department == department)
        if low_utilization:
            filters.append(LicenseAnalysis.utilization_rate < 50.0)
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        # 総件数
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        # ページネーション
        offset = (page - 1) * size
        query = query.order_by(desc(LicenseAnalysis.report_date)).offset(offset).limit(size)
        
        result = await session.execute(query)
        licenses = result.scalars().all()
        
        items = [LicenseAnalysisResponse.from_orm(license) for license in licenses]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ライセンス分析取得エラー: {str(e)}")


@router.get("/license/summary",
           summary="ライセンス分析サマリー",
           description="ライセンス全体の統計情報")
async def get_license_summary(
    department: Optional[str] = Query(None),
    session: AsyncSession = Depends(get_async_session)
):
    """ライセンス分析サマリー取得"""
    
    try:
        # 基本統計
        base_query = select(LicenseAnalysis)
        if department:
            base_query = base_query.where(LicenseAnalysis.department == department)
        
        stats_query = select(
            func.count(LicenseAnalysis.id).label('total_records'),
            func.sum(LicenseAnalysis.total_licenses).label('total_licenses'),
            func.sum(LicenseAnalysis.assigned_licenses).label('assigned_licenses'),
            func.avg(LicenseAnalysis.utilization_rate).label('avg_utilization'),
            func.sum(LicenseAnalysis.monthly_cost).label('total_monthly_cost')
        ).select_from(base_query.subquery())
        
        result = await session.execute(stats_query)
        stats = result.first()
        
        # ライセンス種別別統計
        type_query = select(
            LicenseAnalysis.license_type,
            func.sum(LicenseAnalysis.total_licenses).label('total'),
            func.sum(LicenseAnalysis.assigned_licenses).label('assigned'),
            func.avg(LicenseAnalysis.utilization_rate).label('utilization')
        ).group_by(LicenseAnalysis.license_type)
        
        if department:
            type_query = type_query.where(LicenseAnalysis.department == department)
        
        type_result = await session.execute(type_query)
        license_types = [
            {
                "license_type": row[0],
                "total_licenses": row[1],
                "assigned_licenses": row[2], 
                "utilization_rate": float(row[3]) if row[3] else 0
            }
            for row in type_result.all()
        ]
        
        return {
            "summary": {
                "total_records": stats[0],
                "total_licenses": stats[1] or 0,
                "assigned_licenses": stats[2] or 0,
                "available_licenses": (stats[1] or 0) - (stats[2] or 0),
                "average_utilization": float(stats[3]) if stats[3] else 0,
                "total_monthly_cost": float(stats[4]) if stats[4] else 0
            },
            "by_license_type": license_types,
            "department_filter": department
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ライセンスサマリー取得エラー: {str(e)}")


# ========================================
# 使用状況分析API
# ========================================

@router.get("/usage",
           response_model=PaginatedResponse,
           summary="使用状況分析レポート一覧")
async def get_service_usage_analysis(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    service_name: Optional[str] = Query(None, description="サービス名"),
    trend_direction: Optional[str] = Query(None, description="トレンド方向"),
    session: AsyncSession = Depends(get_async_session)
):
    """サービス使用状況分析データ取得"""
    
    try:
        query = select(ServiceUsageAnalysis)
        count_query = select(func.count(ServiceUsageAnalysis.id))
        
        filters = []
        if service_name:
            filters.append(ServiceUsageAnalysis.service_name.contains(service_name))
        if trend_direction:
            filters.append(ServiceUsageAnalysis.trend_direction == trend_direction)
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(ServiceUsageAnalysis.report_date)).offset(offset).limit(size)
        
        result = await session.execute(query)
        usage_data = result.scalars().all()
        
        items = [ServiceUsageAnalysisResponse.from_orm(usage) for usage in usage_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"使用状況分析取得エラー: {str(e)}")


@router.get("/usage/trends",
           summary="使用状況トレンド分析")
async def get_usage_trends(
    service_name: Optional[str] = Query(None),
    days: int = Query(30, ge=7, le=365, description="分析期間（日数）"),
    session: AsyncSession = Depends(get_async_session)
):
    """使用状況トレンド分析"""
    
    try:
        cutoff_date = date.today() - timedelta(days=days)
        
        query = select(
            ServiceUsageAnalysis.report_date,
            ServiceUsageAnalysis.service_name,
            ServiceUsageAnalysis.daily_active_users,
            ServiceUsageAnalysis.adoption_rate
        ).where(
            ServiceUsageAnalysis.report_date >= cutoff_date
        )
        
        if service_name:
            query = query.where(ServiceUsageAnalysis.service_name == service_name)
        
        query = query.order_by(ServiceUsageAnalysis.report_date, ServiceUsageAnalysis.service_name)
        
        result = await session.execute(query)
        trend_data = {}
        
        for row in result.all():
            service = row[1]
            if service not in trend_data:
                trend_data[service] = []
            
            trend_data[service].append({
                "date": row[0].isoformat(),
                "daily_active_users": row[2],
                "adoption_rate": float(row[3]) if row[3] else 0
            })
        
        return {
            "period_days": days,
            "service_filter": service_name,
            "trend_data": trend_data
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"トレンド分析エラー: {str(e)}")


# ========================================
# パフォーマンス監視API
# ========================================

@router.get("/performance",
           response_model=PaginatedResponse,
           summary="パフォーマンス監視データ一覧")
async def get_performance_monitoring(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    service_name: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    hours: int = Query(24, ge=1, le=168, description="監視期間（時間）"),
    session: AsyncSession = Depends(get_async_session)
):
    """パフォーマンス監視データ取得"""
    
    try:
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        query = select(PerformanceMonitoring).where(
            PerformanceMonitoring.timestamp >= cutoff_time
        )
        count_query = select(func.count(PerformanceMonitoring.id)).where(
            PerformanceMonitoring.timestamp >= cutoff_time
        )
        
        filters = []
        if service_name:
            filters.append(PerformanceMonitoring.service_name.contains(service_name))
        if status:
            filters.append(PerformanceMonitoring.status == status)
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(PerformanceMonitoring.timestamp)).offset(offset).limit(size)
        
        result = await session.execute(query)
        performance_data = result.scalars().all()
        
        items = [PerformanceMonitoringResponse.from_orm(perf) for perf in performance_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"パフォーマンスデータ取得エラー: {str(e)}")


@router.get("/performance/metrics",
           summary="パフォーマンス指標サマリー")
async def get_performance_metrics(
    service_name: Optional[str] = Query(None),
    hours: int = Query(24, ge=1, le=168),
    session: AsyncSession = Depends(get_async_session)
):
    """パフォーマンス指標サマリー取得"""
    
    try:
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        query = select(
            func.avg(PerformanceMonitoring.response_time_ms).label('avg_response_time'),
            func.max(PerformanceMonitoring.response_time_ms).label('max_response_time'),
            func.avg(PerformanceMonitoring.availability_percent).label('avg_availability'),
            func.min(PerformanceMonitoring.availability_percent).label('min_availability'),
            func.avg(PerformanceMonitoring.error_rate).label('avg_error_rate'),
            func.max(PerformanceMonitoring.error_rate).label('max_error_rate')
        ).where(PerformanceMonitoring.timestamp >= cutoff_time)
        
        if service_name:
            query = query.where(PerformanceMonitoring.service_name == service_name)
        
        result = await session.execute(query)
        metrics = result.first()
        
        return {
            "period_hours": hours,
            "service_filter": service_name,
            "metrics": {
                "response_time": {
                    "average_ms": float(metrics[0]) if metrics[0] else 0,
                    "max_ms": metrics[1] or 0
                },
                "availability": {
                    "average_percent": float(metrics[2]) if metrics[2] else 0,
                    "min_percent": float(metrics[3]) if metrics[3] else 0
                },
                "error_rate": {
                    "average_percent": float(metrics[4]) if metrics[4] else 0,
                    "max_percent": float(metrics[5]) if metrics[5] else 0
                }
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"パフォーマンス指標取得エラー: {str(e)}")


# ========================================
# セキュリティ分析API
# ========================================

@router.get("/security",
           response_model=PaginatedResponse,
           summary="セキュリティ分析レポート一覧")
async def get_security_analysis(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    risk_level: Optional[str] = Query(None),
    security_item: Optional[str] = Query(None),
    session: AsyncSession = Depends(get_async_session)
):
    """セキュリティ分析データ取得"""
    
    try:
        query = select(SecurityAnalysis)
        count_query = select(func.count(SecurityAnalysis.id))
        
        filters = []
        if risk_level:
            filters.append(SecurityAnalysis.risk_level == risk_level)
        if security_item:
            filters.append(SecurityAnalysis.security_item.contains(security_item))
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(SecurityAnalysis.report_date)).offset(offset).limit(size)
        
        result = await session.execute(query)
        security_data = result.scalars().all()
        
        items = [SecurityAnalysisResponse.from_orm(sec) for sec in security_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"セキュリティ分析取得エラー: {str(e)}")


# ========================================
# 権限監査API
# ========================================

@router.get("/permissions",
           response_model=PaginatedResponse,
           summary="権限監査レポート一覧")
async def get_permission_audit(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    department: Optional[str] = Query(None),
    admin_only: bool = Query(False, description="管理者権限のみ"),
    session: AsyncSession = Depends(get_async_session)
):
    """権限監査データ取得"""
    
    try:
        query = select(PermissionAudit)
        count_query = select(func.count(PermissionAudit.id))
        
        filters = []
        if department:
            filters.append(PermissionAudit.department == department)
        if admin_only:
            filters.append(PermissionAudit.admin_role.isnot(None))
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(PermissionAudit.audit_date)).offset(offset).limit(size)
        
        result = await session.execute(query)
        audit_data = result.scalars().all()
        
        items = [PermissionAuditResponse.from_orm(audit) for audit in audit_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"権限監査取得エラー: {str(e)}")


# ========================================
# 分析実行API
# ========================================

@router.post("/generate",
            summary="分析レポート生成",
            description="指定された分析をバックグラウンドで実行")
async def generate_analysis_report(
    request: AnalysisRequest,
    background_tasks: BackgroundTasks,
    session: AsyncSession = Depends(get_async_session)
):
    """分析レポート生成"""
    
    try:
        # バックグラウンドタスクで分析実行
        background_tasks.add_task(
            _generate_analysis_task,
            request.analysis_type,
            request.start_date,
            request.end_date,
            request.filters
        )
        
        return {
            "message": f"{request.analysis_type}分析レポート生成を開始しました",
            "analysis_type": request.analysis_type,
            "status": "processing",
            "estimated_time": "5-15分"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"分析レポート生成エラー: {str(e)}")


async def _generate_analysis_task(
    analysis_type: str,
    start_date: Optional[date],
    end_date: Optional[date], 
    filters: Optional[Dict[str, Any]]
):
    """分析レポート生成タスク"""
    # 実際の分析処理実装
    pass