"""
Microsoft 365管理ツール OneDrive管理API
====================================

OneDrive管理機能 REST API実装 (4機能)
- OneDriveストレージ分析
- OneDrive共有分析
- OneDrive同期エラー分析
- OneDrive外部共有分析
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
    OneDriveStorageAnalysis, OneDriveSharingAnalysis, 
    OneDriveSyncError, OneDriveExternalSharing
)

router = APIRouter(prefix="/onedrive", tags=["OneDrive管理"])


# ========================================
# Pydanticモデル（レスポンス）
# ========================================

class OneDriveStorageResponse(BaseModel):
    """OneDriveストレージレスポンス"""
    id: int
    report_date: date
    user_name: str
    user_principal_name: Optional[str]
    department: Optional[str]
    total_storage_gb: Optional[float]
    used_storage_gb: Optional[float]
    usage_percent: Optional[float]
    file_count: int
    folder_count: int
    last_activity: Optional[datetime]
    sync_status: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


class OneDriveSharingResponse(BaseModel):
    """OneDrive共有分析レスポンス"""
    id: int
    file_name: str
    owner: Optional[str]
    file_size_mb: Optional[float]
    share_type: Optional[str]
    shared_with: Optional[str]
    access_permission: Optional[str]
    share_date: Optional[datetime]
    last_access: Optional[datetime]
    risk_level: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


class OneDriveSyncErrorResponse(BaseModel):
    """OneDrive同期エラーレスポンス"""
    id: int
    occurrence_date: datetime
    user_name: Optional[str]
    user_principal_name: Optional[str]
    file_path: Optional[str]
    error_type: Optional[str]
    error_code: Optional[str]
    error_message: Optional[str]
    affected_files_count: int
    status: Optional[str]
    resolution_date: Optional[date]
    created_at: datetime
    
    class Config:
        from_attributes = True


class OneDriveExternalSharingResponse(BaseModel):
    """OneDrive外部共有レスポンス"""
    id: int
    file_name: str
    owner: Optional[str]
    external_domain: Optional[str]
    shared_email: Optional[str]
    access_permission: Optional[str]
    share_url: Optional[str]
    share_start_date: Optional[date]
    last_access: Optional[datetime]
    risk_level: Optional[str]
    expiration_date: Optional[date]
    download_count: int
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


class StorageAnalysisFilter(BaseModel):
    """ストレージ分析フィルター"""
    department: Optional[str] = None
    high_usage_only: bool = False
    sync_status: Optional[str] = None
    days: int = Field(30, ge=1, le=365)


# ========================================
# OneDriveストレージ分析API
# ========================================

@router.get("/storage",
           response_model=PaginatedResponse,
           summary="OneDriveストレージ分析一覧取得",
           description="OneDriveストレージ利用状況分析データを取得")
async def get_onedrive_storage(
    page: int = Query(1, ge=1, description="ページ番号"),
    size: int = Query(50, ge=1, le=1000, description="ページサイズ"),
    department: Optional[str] = Query(None, description="部署フィルター"),
    high_usage_only: bool = Query(False, description="高使用率のみ表示（80%以上）"),
    sync_status: Optional[str] = Query(None, description="同期ステータスフィルター"),
    days: int = Query(30, ge=1, le=365, description="分析期間（日数）"),
    sort_by: str = Query("usage_percent", description="ソート項目"),
    sort_order: str = Query("desc", regex="^(asc|desc)$", description="ソート順序"),
    session: AsyncSession = Depends(get_async_session)
):
    """OneDriveストレージ分析データ一覧取得"""
    
    try:
        cutoff_date = date.today() - timedelta(days=days)
        
        query = select(OneDriveStorageAnalysis).where(OneDriveStorageAnalysis.report_date >= cutoff_date)
        count_query = select(func.count(OneDriveStorageAnalysis.id)).where(OneDriveStorageAnalysis.report_date >= cutoff_date)
        
        # フィルター適用
        filters = []
        if department:
            filters.append(OneDriveStorageAnalysis.department == department)
        if high_usage_only:
            filters.append(OneDriveStorageAnalysis.usage_percent >= 80.0)
        if sync_status:
            filters.append(OneDriveStorageAnalysis.sync_status == sync_status)
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        # 総件数取得
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        # ソート適用
        sort_column = getattr(OneDriveStorageAnalysis, sort_by, OneDriveStorageAnalysis.usage_percent)
        if sort_order == "desc":
            query = query.order_by(desc(sort_column))
        else:
            query = query.order_by(sort_column)
        
        # ページネーション適用
        offset = (page - 1) * size
        query = query.offset(offset).limit(size)
        
        # データ取得
        result = await session.execute(query)
        storage_data = result.scalars().all()
        
        # レスポンス形式に変換
        items = [OneDriveStorageResponse.from_orm(storage) for storage in storage_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OneDriveストレージ分析取得エラー: {str(e)}")


@router.get("/storage/{storage_id}",
           response_model=OneDriveStorageResponse,
           summary="OneDriveストレージ詳細取得")
async def get_onedrive_storage_detail(
    storage_id: int,
    session: AsyncSession = Depends(get_async_session)
):
    """個別OneDriveストレージ情報取得"""
    
    try:
        query = select(OneDriveStorageAnalysis).where(OneDriveStorageAnalysis.id == storage_id)
        result = await session.execute(query)
        storage = result.scalar_one_or_none()
        
        if not storage:
            raise HTTPException(status_code=404, detail="ストレージデータが見つかりません")
        
        return OneDriveStorageResponse.from_orm(storage)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ストレージデータ取得エラー: {str(e)}")


@router.get("/storage/statistics",
           summary="OneDriveストレージ統計情報")
async def get_storage_statistics(
    department: Optional[str] = Query(None),
    days: int = Query(30, ge=1, le=365),
    session: AsyncSession = Depends(get_async_session)
):
    """OneDriveストレージ統計情報取得"""
    
    try:
        cutoff_date = date.today() - timedelta(days=days)
        
        base_query = select(OneDriveStorageAnalysis).where(OneDriveStorageAnalysis.report_date >= cutoff_date)
        if department:
            base_query = base_query.where(OneDriveStorageAnalysis.department == department)
        
        # 基本統計
        stats_query = select(
            func.count(OneDriveStorageAnalysis.id).label('total_users'),
            func.avg(OneDriveStorageAnalysis.usage_percent).label('avg_usage_percent'),
            func.sum(OneDriveStorageAnalysis.total_storage_gb).label('total_storage_gb'),
            func.sum(OneDriveStorageAnalysis.used_storage_gb).label('total_used_gb'),
            func.count(OneDriveStorageAnalysis.id).filter(OneDriveStorageAnalysis.usage_percent >= 80).label('high_usage_count'),
            func.count(OneDriveStorageAnalysis.id).filter(OneDriveStorageAnalysis.sync_status != '同期済み').label('sync_issues_count'),
            func.sum(OneDriveStorageAnalysis.file_count).label('total_files')
        ).where(OneDriveStorageAnalysis.report_date >= cutoff_date)
        
        if department:
            stats_query = stats_query.where(OneDriveStorageAnalysis.department == department)
        
        result = await session.execute(stats_query)
        stats = result.first()
        
        # 部署別統計
        dept_query = select(
            OneDriveStorageAnalysis.department,
            func.count(OneDriveStorageAnalysis.id).label('user_count'),
            func.avg(OneDriveStorageAnalysis.usage_percent).label('avg_usage'),
            func.sum(OneDriveStorageAnalysis.used_storage_gb).label('total_used')
        ).where(
            OneDriveStorageAnalysis.report_date >= cutoff_date
        ).group_by(OneDriveStorageAnalysis.department).order_by(func.sum(OneDriveStorageAnalysis.used_storage_gb).desc())
        
        dept_result = await session.execute(dept_query)
        departments = [
            {
                "department": row[0] or "未設定",
                "user_count": row[1],
                "average_usage_percent": float(row[2]) if row[2] else 0,
                "total_used_gb": float(row[3]) if row[3] else 0
            }
            for row in dept_result.all()
        ]
        
        # 同期ステータス別統計
        sync_query = select(
            OneDriveStorageAnalysis.sync_status,
            func.count(OneDriveStorageAnalysis.id).label('count')
        ).where(
            OneDriveStorageAnalysis.report_date >= cutoff_date
        ).group_by(OneDriveStorageAnalysis.sync_status).order_by(func.count(OneDriveStorageAnalysis.id).desc())
        
        sync_result = await session.execute(sync_query)
        sync_statuses = [
            {
                "sync_status": row[0] or "不明",
                "user_count": row[1]
            }
            for row in sync_result.all()
        ]
        
        return {
            "period_days": days,
            "department_filter": department,
            "summary": {
                "total_users": stats[0],
                "average_usage_percent": float(stats[1]) if stats[1] else 0,
                "total_allocated_storage_gb": float(stats[2]) if stats[2] else 0,
                "total_used_storage_gb": float(stats[3]) if stats[3] else 0,
                "high_usage_users": stats[4],
                "users_with_sync_issues": stats[5],
                "total_files": stats[6] or 0
            },
            "by_department": departments,
            "by_sync_status": sync_statuses
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ストレージ統計取得エラー: {str(e)}")


# ========================================
# OneDrive共有分析API
# ========================================

@router.get("/sharing",
           response_model=PaginatedResponse,
           summary="OneDrive共有分析データ取得")
async def get_onedrive_sharing(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    share_type: Optional[str] = Query(None, description="共有種別フィルター"),
    risk_level: Optional[str] = Query(None, description="リスクレベルフィルター"),
    owner: Optional[str] = Query(None, description="所有者フィルター"),
    session: AsyncSession = Depends(get_async_session)
):
    """OneDrive共有分析データ取得"""
    
    try:
        query = select(OneDriveSharingAnalysis)
        count_query = select(func.count(OneDriveSharingAnalysis.id))
        
        filters = []
        if share_type:
            filters.append(OneDriveSharingAnalysis.share_type == share_type)
        if risk_level:
            filters.append(OneDriveSharingAnalysis.risk_level == risk_level)
        if owner:
            filters.append(OneDriveSharingAnalysis.owner.contains(owner))
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(OneDriveSharingAnalysis.share_date)).offset(offset).limit(size)
        
        result = await session.execute(query)
        sharing_data = result.scalars().all()
        
        items = [OneDriveSharingResponse.from_orm(sharing) for sharing in sharing_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OneDrive共有分析取得エラー: {str(e)}")


@router.get("/sharing/risk-analysis",
           summary="共有リスク分析")
async def get_sharing_risk_analysis(
    session: AsyncSession = Depends(get_async_session)
):
    """OneDrive共有リスク分析"""
    
    try:
        # リスクレベル別統計
        risk_query = select(
            OneDriveSharingAnalysis.risk_level,
            func.count(OneDriveSharingAnalysis.id).label('file_count'),
            func.avg(OneDriveSharingAnalysis.file_size_mb).label('avg_file_size')
        ).group_by(OneDriveSharingAnalysis.risk_level).order_by(func.count(OneDriveSharingAnalysis.id).desc())
        
        risk_result = await session.execute(risk_query)
        risk_levels = [
            {
                "risk_level": row[0] or "未評価",
                "file_count": row[1],
                "average_file_size_mb": float(row[2]) if row[2] else 0
            }
            for row in risk_result.all()
        ]
        
        # 共有種別統計
        type_query = select(
            OneDriveSharingAnalysis.share_type,
            func.count(OneDriveSharingAnalysis.id).label('count'),
            func.count(OneDriveSharingAnalysis.id).filter(OneDriveSharingAnalysis.risk_level == '高').label('high_risk_count')
        ).group_by(OneDriveSharingAnalysis.share_type).order_by(func.count(OneDriveSharingAnalysis.id).desc())
        
        type_result = await session.execute(type_query)
        share_types = [
            {
                "share_type": row[0] or "不明",
                "total_files": row[1],
                "high_risk_files": row[2],
                "risk_percentage": round((row[2] / row[1] * 100) if row[1] > 0 else 0, 2)
            }
            for row in type_result.all()
        ]
        
        # 高リスクファイルTop20
        high_risk_query = select(
            OneDriveSharingAnalysis.file_name,
            OneDriveSharingAnalysis.owner,
            OneDriveSharingAnalysis.risk_level,
            OneDriveSharingAnalysis.file_size_mb,
            OneDriveSharingAnalysis.share_type
        ).where(
            OneDriveSharingAnalysis.risk_level == '高'
        ).order_by(desc(OneDriveSharingAnalysis.file_size_mb)).limit(20)
        
        high_risk_result = await session.execute(high_risk_query)
        high_risk_files = [
            {
                "file_name": row[0],
                "owner": row[1],
                "risk_level": row[2],
                "file_size_mb": float(row[3]) if row[3] else 0,
                "share_type": row[4]
            }
            for row in high_risk_result.all()
        ]
        
        return {
            "risk_level_distribution": risk_levels,
            "by_share_type": share_types,
            "high_risk_files": high_risk_files
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"共有リスク分析エラー: {str(e)}")


# ========================================
# OneDrive同期エラー分析API
# ========================================

@router.get("/sync-errors",
           response_model=PaginatedResponse,
           summary="OneDrive同期エラー分析データ取得")
async def get_sync_errors(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    hours: int = Query(168, ge=1, le=720, description="分析期間（時間）"),  # デフォルト1週間
    error_type: Optional[str] = Query(None, description="エラー種別フィルター"),
    status: Optional[str] = Query(None, description="ステータスフィルター"),
    user_search: Optional[str] = Query(None, description="ユーザー検索"),
    session: AsyncSession = Depends(get_async_session)
):
    """OneDrive同期エラー分析データ取得"""
    
    try:
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        query = select(OneDriveSyncError).where(OneDriveSyncError.occurrence_date >= cutoff_time)
        count_query = select(func.count(OneDriveSyncError.id)).where(OneDriveSyncError.occurrence_date >= cutoff_time)
        
        filters = []
        if error_type:
            filters.append(OneDriveSyncError.error_type == error_type)
        if status:
            filters.append(OneDriveSyncError.status == status)
        if user_search:
            filters.append(or_(
                OneDriveSyncError.user_name.contains(user_search),
                OneDriveSyncError.user_principal_name.contains(user_search)
            ))
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(OneDriveSyncError.occurrence_date)).offset(offset).limit(size)
        
        result = await session.execute(query)
        error_data = result.scalars().all()
        
        items = [OneDriveSyncErrorResponse.from_orm(error) for error in error_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"同期エラー分析取得エラー: {str(e)}")


@router.get("/sync-errors/statistics",
           summary="同期エラー統計情報")
async def get_sync_error_statistics(
    hours: int = Query(168, ge=1, le=720),
    session: AsyncSession = Depends(get_async_session)
):
    """同期エラー統計情報取得"""
    
    try:
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        # 基本統計
        stats_query = select(
            func.count(OneDriveSyncError.id).label('total_errors'),
            func.count(OneDriveSyncError.id).filter(OneDriveSyncError.status == '解決済み').label('resolved_errors'),
            func.count(OneDriveSyncError.id).filter(OneDriveSyncError.status == '未解決').label('unresolved_errors'),
            func.sum(OneDriveSyncError.affected_files_count).label('total_affected_files'),
            func.count(func.distinct(OneDriveSyncError.user_principal_name)).label('affected_users')
        ).where(OneDriveSyncError.occurrence_date >= cutoff_time)
        
        result = await session.execute(stats_query)
        stats = result.first()
        
        # エラー種別統計
        error_type_query = select(
            OneDriveSyncError.error_type,
            func.count(OneDriveSyncError.id).label('count'),
            func.sum(OneDriveSyncError.affected_files_count).label('affected_files')
        ).where(
            OneDriveSyncError.occurrence_date >= cutoff_time
        ).group_by(OneDriveSyncError.error_type).order_by(func.count(OneDriveSyncError.id).desc())
        
        error_type_result = await session.execute(error_type_query)
        error_types = [
            {
                "error_type": row[0] or "不明",
                "occurrence_count": row[1],
                "affected_files": row[2] or 0
            }
            for row in error_type_result.all()
        ]
        
        # 解決率計算
        total_errors = stats[0] or 1
        resolution_rate = (stats[1] or 0) / total_errors * 100
        
        return {
            "period_hours": hours,
            "summary": {
                "total_errors": stats[0],
                "resolved_errors": stats[1],
                "unresolved_errors": stats[2],
                "resolution_rate_percent": round(resolution_rate, 2),
                "total_affected_files": stats[3] or 0,
                "affected_users": stats[4]
            },
            "by_error_type": error_types
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"同期エラー統計取得エラー: {str(e)}")


# ========================================
# OneDrive外部共有分析API
# ========================================

@router.get("/external-sharing",
           response_model=PaginatedResponse,
           summary="OneDrive外部共有分析データ取得")
async def get_external_sharing(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    risk_level: Optional[str] = Query(None, description="リスクレベルフィルター"),
    external_domain: Optional[str] = Query(None, description="外部ドメインフィルター"),
    expiring_soon: bool = Query(False, description="期限切れ間近のみ（30日以内）"),
    session: AsyncSession = Depends(get_async_session)
):
    """OneDrive外部共有分析データ取得"""
    
    try:
        query = select(OneDriveExternalSharing)
        count_query = select(func.count(OneDriveExternalSharing.id))
        
        filters = []
        if risk_level:
            filters.append(OneDriveExternalSharing.risk_level == risk_level)
        if external_domain:
            filters.append(OneDriveExternalSharing.external_domain.contains(external_domain))
        if expiring_soon:
            expiry_cutoff = date.today() + timedelta(days=30)
            filters.append(and_(
                OneDriveExternalSharing.expiration_date.isnot(None),
                OneDriveExternalSharing.expiration_date <= expiry_cutoff
            ))
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(OneDriveExternalSharing.share_start_date)).offset(offset).limit(size)
        
        result = await session.execute(query)
        external_data = result.scalars().all()
        
        items = [OneDriveExternalSharingResponse.from_orm(external) for external in external_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"外部共有分析取得エラー: {str(e)}")


@router.get("/external-sharing/security-report",
           summary="外部共有セキュリティレポート")
async def get_external_sharing_security_report(
    session: AsyncSession = Depends(get_async_session)
):
    """外部共有セキュリティレポート取得"""
    
    try:
        # リスクレベル別統計
        risk_query = select(
            OneDriveExternalSharing.risk_level,
            func.count(OneDriveExternalSharing.id).label('share_count'),
            func.sum(OneDriveExternalSharing.download_count).label('total_downloads')
        ).group_by(OneDriveExternalSharing.risk_level).order_by(func.count(OneDriveExternalSharing.id).desc())
        
        risk_result = await session.execute(risk_query)
        risk_levels = [
            {
                "risk_level": row[0] or "未評価",
                "share_count": row[1],
                "total_downloads": row[2] or 0
            }
            for row in risk_result.all()
        ]
        
        # 外部ドメイン別統計
        domain_query = select(
            OneDriveExternalSharing.external_domain,
            func.count(OneDriveExternalSharing.id).label('share_count'),
            func.count(OneDriveExternalSharing.id).filter(OneDriveExternalSharing.risk_level == '高').label('high_risk_count')
        ).group_by(OneDriveExternalSharing.external_domain).order_by(func.count(OneDriveExternalSharing.id).desc()).limit(20)
        
        domain_result = await session.execute(domain_query)
        external_domains = [
            {
                "domain": row[0] or "不明",
                "share_count": row[1],
                "high_risk_count": row[2]
            }
            for row in domain_result.all()
        ]
        
        # 期限切れ間近の共有
        expiry_cutoff = date.today() + timedelta(days=30)
        expiring_query = select(
            OneDriveExternalSharing.file_name,
            OneDriveExternalSharing.owner,
            OneDriveExternalSharing.external_domain,
            OneDriveExternalSharing.expiration_date,
            OneDriveExternalSharing.risk_level
        ).where(
            and_(
                OneDriveExternalSharing.expiration_date.isnot(None),
                OneDriveExternalSharing.expiration_date <= expiry_cutoff
            )
        ).order_by(OneDriveExternalSharing.expiration_date).limit(50)
        
        expiring_result = await session.execute(expiring_query)
        expiring_shares = [
            {
                "file_name": row[0],
                "owner": row[1],
                "external_domain": row[2],
                "expiration_date": row[3].isoformat() if row[3] else None,
                "risk_level": row[4]
            }
            for row in expiring_result.all()
        ]
        
        # 全体統計
        total_query = select(
            func.count(OneDriveExternalSharing.id).label('total_shares'),
            func.count(func.distinct(OneDriveExternalSharing.external_domain)).label('unique_domains'),
            func.sum(OneDriveExternalSharing.download_count).label('total_downloads')
        )
        
        total_result = await session.execute(total_query)
        totals = total_result.first()
        
        return {
            "summary": {
                "total_external_shares": totals[0],
                "unique_external_domains": totals[1],
                "total_downloads": totals[2] or 0
            },
            "risk_level_distribution": risk_levels,
            "top_external_domains": external_domains,
            "expiring_soon": {
                "count": len(expiring_shares),
                "shares": expiring_shares
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"外部共有セキュリティレポート取得エラー: {str(e)}")


# ========================================
# データ同期API
# ========================================

@router.post("/sync/storage",
            summary="OneDriveストレージデータ同期",
            description="Microsoft Graph APIからOneDriveストレージ情報を同期")
async def sync_onedrive_storage(
    background_tasks: BackgroundTasks,
    force_full_sync: bool = Query(False, description="完全同期実行"),
    session: AsyncSession = Depends(get_async_session)
):
    """OneDriveストレージデータ同期"""
    
    try:
        background_tasks.add_task(
            _sync_onedrive_storage_task,
            force_full_sync
        )
        
        return {
            "message": "OneDriveストレージデータ同期を開始しました",
            "sync_type": "完全同期" if force_full_sync else "差分同期",
            "status": "processing"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ストレージデータ同期エラー: {str(e)}")


@router.post("/sync/sharing",
            summary="OneDrive共有データ同期")
async def sync_onedrive_sharing(
    background_tasks: BackgroundTasks,
    include_external: bool = Query(True, description="外部共有も含める"),
    session: AsyncSession = Depends(get_async_session)
):
    """OneDrive共有データ同期"""
    
    try:
        background_tasks.add_task(
            _sync_onedrive_sharing_task,
            include_external
        )
        
        return {
            "message": "OneDrive共有データ同期を開始しました",
            "include_external_sharing": include_external,
            "status": "processing"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"共有データ同期エラー: {str(e)}")


# ========================================
# バックグラウンドタスク
# ========================================

async def _sync_onedrive_storage_task(force_full_sync: bool):
    """OneDriveストレージ同期タスク"""
    # Microsoft Graph OneDrive API 呼び出し実装
    pass


async def _sync_onedrive_sharing_task(include_external: bool):
    """OneDrive共有同期タスク"""
    # Microsoft Graph OneDrive API 呼び出し実装
    pass