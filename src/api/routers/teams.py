"""
Microsoft 365管理ツール Teams管理API
==================================

Teams管理機能 REST API実装 (4機能)
- Teams使用状況分析
- Teams設定・ポリシー分析
- 会議品質分析
- Teamsアプリ分析
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
    TeamsUsage, TeamsSettingsAnalysis, MeetingQualityAnalysis, TeamsAppAnalysis
)

router = APIRouter(prefix="/teams", tags=["Teams管理"])


# ========================================
# Pydanticモデル（レスポンス）
# ========================================

class TeamsUsageResponse(BaseModel):
    """Teams使用状況レスポンス"""
    id: int
    report_date: date
    user_name: str
    user_principal_name: Optional[str]
    department: Optional[str]
    last_access: Optional[datetime]
    chat_messages_count: int
    meetings_organized: int
    meetings_attended: int
    calls_count: int
    files_shared: int
    activity_score: Optional[float]
    created_at: datetime
    
    class Config:
        from_attributes = True


class TeamsSettingsAnalysisResponse(BaseModel):
    """Teams設定分析レスポンス"""
    id: int
    policy_name: str
    policy_type: Optional[str]
    target_users_count: int
    status: Optional[str]
    messaging_permission: Optional[str]
    file_sharing_permission: Optional[str]
    meeting_recording_permission: Optional[str]
    last_updated: Optional[date]
    compliance: Optional[str]
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class MeetingQualityAnalysisResponse(BaseModel):
    """会議品質分析レスポンス"""
    id: int
    meeting_id: str
    meeting_name: Optional[str]
    datetime: datetime
    participant_count: int
    duration_minutes: Optional[int]
    audio_quality: Optional[str]
    video_quality: Optional[str]
    network_quality: Optional[str]
    overall_quality_score: Optional[float]
    quality_rating: Optional[str]
    issues_reported: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


class TeamsAppAnalysisResponse(BaseModel):
    """Teamsアプリ分析レスポンス"""
    id: int
    app_name: str
    version: Optional[str]
    publisher: Optional[str]
    installation_count: int
    active_users_count: int
    last_used_date: Optional[date]
    app_status: Optional[str]
    permission_status: Optional[str]
    security_score: Optional[float]
    risk_level: Optional[str]
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


class TeamsUsageCreateRequest(BaseModel):
    """Teams使用状況作成リクエスト"""
    user_name: str = Field(..., description="ユーザー名")
    user_principal_name: str = Field(..., description="UPN")
    department: Optional[str] = Field(None, description="部署")
    chat_messages_count: int = Field(0, description="チャットメッセージ数")
    meetings_organized: int = Field(0, description="主催会議数")
    meetings_attended: int = Field(0, description="参加会議数")
    calls_count: int = Field(0, description="通話数")
    files_shared: int = Field(0, description="共有ファイル数")


# ========================================
# Teams使用状況分析API
# ========================================

@router.get("/usage",
           response_model=PaginatedResponse,
           summary="Teams使用状況一覧取得",
           description="Teams利用状況分析データを取得")
async def get_teams_usage(
    page: int = Query(1, ge=1, description="ページ番号"),
    size: int = Query(50, ge=1, le=1000, description="ページサイズ"),
    department: Optional[str] = Query(None, description="部署フィルター"),
    days: int = Query(30, ge=1, le=365, description="分析期間（日数）"),
    active_only: bool = Query(False, description="アクティブユーザーのみ"),
    sort_by: str = Query("activity_score", description="ソート項目"),
    sort_order: str = Query("desc", regex="^(asc|desc)$", description="ソート順序"),
    session: AsyncSession = Depends(get_async_session)
):
    """Teams使用状況一覧取得"""
    
    try:
        cutoff_date = date.today() - timedelta(days=days)
        
        query = select(TeamsUsage).where(TeamsUsage.report_date >= cutoff_date)
        count_query = select(func.count(TeamsUsage.id)).where(TeamsUsage.report_date >= cutoff_date)
        
        # フィルター適用
        filters = []
        if department:
            filters.append(TeamsUsage.department == department)
        if active_only:
            filters.append(or_(
                TeamsUsage.chat_messages_count > 0,
                TeamsUsage.meetings_organized > 0,
                TeamsUsage.meetings_attended > 0,
                TeamsUsage.calls_count > 0
            ))
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        # 総件数取得
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        # ソート適用
        sort_column = getattr(TeamsUsage, sort_by, TeamsUsage.activity_score)
        if sort_order == "desc":
            query = query.order_by(desc(sort_column))
        else:
            query = query.order_by(sort_column)
        
        # ページネーション適用
        offset = (page - 1) * size
        query = query.offset(offset).limit(size)
        
        # データ取得
        result = await session.execute(query)
        usage_data = result.scalars().all()
        
        # レスポンス形式に変換
        items = [TeamsUsageResponse.from_orm(usage) for usage in usage_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Teams使用状況取得エラー: {str(e)}")


@router.get("/usage/{usage_id}",
           response_model=TeamsUsageResponse,
           summary="Teams使用状況詳細取得")
async def get_teams_usage_detail(
    usage_id: int,
    session: AsyncSession = Depends(get_async_session)
):
    """個別Teams使用状況取得"""
    
    try:
        query = select(TeamsUsage).where(TeamsUsage.id == usage_id)
        result = await session.execute(query)
        usage = result.scalar_one_or_none()
        
        if not usage:
            raise HTTPException(status_code=404, detail="使用状況データが見つかりません")
        
        return TeamsUsageResponse.from_orm(usage)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"使用状況取得エラー: {str(e)}")


@router.post("/usage",
            response_model=TeamsUsageResponse,
            summary="Teams使用状況登録",
            status_code=201)
async def create_teams_usage(
    usage_data: TeamsUsageCreateRequest,
    session: AsyncSession = Depends(get_async_session)
):
    """Teams使用状況データ登録"""
    
    try:
        # 活動スコア計算
        activity_score = (
            usage_data.chat_messages_count * 0.3 +
            usage_data.meetings_organized * 0.4 +
            usage_data.calls_count * 0.3
        )
        
        new_usage = TeamsUsage(
            user_name=usage_data.user_name,
            user_principal_name=usage_data.user_principal_name,
            department=usage_data.department,
            chat_messages_count=usage_data.chat_messages_count,
            meetings_organized=usage_data.meetings_organized,
            meetings_attended=usage_data.meetings_attended,
            calls_count=usage_data.calls_count,
            files_shared=usage_data.files_shared,
            activity_score=Decimal(str(round(activity_score, 2))),
            report_date=date.today(),
            last_access=datetime.utcnow()
        )
        
        session.add(new_usage)
        await session.commit()
        await session.refresh(new_usage)
        
        return TeamsUsageResponse.from_orm(new_usage)
        
    except Exception as e:
        await session.rollback()
        raise HTTPException(status_code=500, detail=f"使用状況登録エラー: {str(e)}")


@router.get("/usage/statistics",
           summary="Teams使用状況統計")
async def get_teams_usage_statistics(
    days: int = Query(30, ge=1, le=365),
    department: Optional[str] = Query(None),
    session: AsyncSession = Depends(get_async_session)
):
    """Teams使用状況統計取得"""
    
    try:
        cutoff_date = date.today() - timedelta(days=days)
        
        base_query = select(TeamsUsage).where(TeamsUsage.report_date >= cutoff_date)
        if department:
            base_query = base_query.where(TeamsUsage.department == department)
        
        # 基本統計
        stats_query = select(
            func.count(TeamsUsage.id).label('total_users'),
            func.count(TeamsUsage.id).filter(
                or_(
                    TeamsUsage.chat_messages_count > 0,
                    TeamsUsage.meetings_organized > 0,
                    TeamsUsage.meetings_attended > 0
                )
            ).label('active_users'),
            func.sum(TeamsUsage.chat_messages_count).label('total_messages'),
            func.sum(TeamsUsage.meetings_organized).label('total_meetings_organized'),
            func.sum(TeamsUsage.meetings_attended).label('total_meetings_attended'),
            func.sum(TeamsUsage.calls_count).label('total_calls'),
            func.avg(TeamsUsage.activity_score).label('avg_activity_score')
        ).where(TeamsUsage.report_date >= cutoff_date)
        
        if department:
            stats_query = stats_query.where(TeamsUsage.department == department)
        
        result = await session.execute(stats_query)
        stats = result.first()
        
        # 部署別統計
        dept_query = select(
            TeamsUsage.department,
            func.count(TeamsUsage.id).label('user_count'),
            func.avg(TeamsUsage.activity_score).label('avg_score'),
            func.sum(TeamsUsage.chat_messages_count).label('total_messages')
        ).where(
            TeamsUsage.report_date >= cutoff_date
        ).group_by(TeamsUsage.department).order_by(func.avg(TeamsUsage.activity_score).desc())
        
        dept_result = await session.execute(dept_query)
        departments = [
            {
                "department": row[0] or "未設定",
                "user_count": row[1],
                "average_activity_score": float(row[2]) if row[2] else 0,
                "total_messages": row[3] or 0
            }
            for row in dept_result.all()
        ]
        
        # アクティブ率計算
        total_users = stats[0] or 1
        active_rate = (stats[1] or 0) / total_users * 100
        
        return {
            "period_days": days,
            "department_filter": department,
            "summary": {
                "total_users": stats[0],
                "active_users": stats[1],
                "active_rate_percent": round(active_rate, 2),
                "total_chat_messages": stats[2] or 0,
                "total_meetings_organized": stats[3] or 0,
                "total_meetings_attended": stats[4] or 0,
                "total_calls": stats[5] or 0,
                "average_activity_score": float(stats[6]) if stats[6] else 0
            },
            "by_department": departments
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"使用状況統計取得エラー: {str(e)}")


# ========================================
# Teams設定・ポリシー分析API
# ========================================

@router.get("/settings",
           response_model=PaginatedResponse,
           summary="Teams設定・ポリシー一覧")
async def get_teams_settings(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    policy_type: Optional[str] = Query(None, description="ポリシー種別フィルター"),
    compliance: Optional[str] = Query(None, description="コンプライアンス状態フィルター"),
    session: AsyncSession = Depends(get_async_session)
):
    """Teams設定・ポリシー一覧取得"""
    
    try:
        query = select(TeamsSettingsAnalysis)
        count_query = select(func.count(TeamsSettingsAnalysis.id))
        
        filters = []
        if policy_type:
            filters.append(TeamsSettingsAnalysis.policy_type == policy_type)
        if compliance:
            filters.append(TeamsSettingsAnalysis.compliance == compliance)
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(TeamsSettingsAnalysis.last_updated)).offset(offset).limit(size)
        
        result = await session.execute(query)
        settings_data = result.scalars().all()
        
        items = [TeamsSettingsAnalysisResponse.from_orm(setting) for setting in settings_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Teams設定取得エラー: {str(e)}")


@router.get("/settings/compliance-summary",
           summary="コンプライアンス状況サマリー")
async def get_compliance_summary(
    session: AsyncSession = Depends(get_async_session)
):
    """コンプライアンス状況サマリー取得"""
    
    try:
        # コンプライアンス統計
        compliance_query = select(
            TeamsSettingsAnalysis.compliance,
            func.count(TeamsSettingsAnalysis.id).label('count'),
            func.sum(TeamsSettingsAnalysis.target_users_count).label('affected_users')
        ).group_by(TeamsSettingsAnalysis.compliance).order_by(func.count(TeamsSettingsAnalysis.id).desc())
        
        result = await session.execute(compliance_query)
        compliance_data = [
            {
                "compliance_status": row[0] or "不明",
                "policy_count": row[1],
                "affected_users": row[2] or 0
            }
            for row in result.all()
        ]
        
        # ポリシー種別統計
        policy_query = select(
            TeamsSettingsAnalysis.policy_type,
            func.count(TeamsSettingsAnalysis.id).label('count'),
            func.count(TeamsSettingsAnalysis.id).filter(TeamsSettingsAnalysis.compliance == '準拠').label('compliant')
        ).group_by(TeamsSettingsAnalysis.policy_type).order_by(func.count(TeamsSettingsAnalysis.id).desc())
        
        policy_result = await session.execute(policy_query)
        policy_types = [
            {
                "policy_type": row[0] or "未分類",
                "total_policies": row[1],
                "compliant_policies": row[2],
                "compliance_rate": round((row[2] / row[1] * 100) if row[1] > 0 else 0, 2)
            }
            for row in policy_result.all()
        ]
        
        return {
            "compliance_overview": compliance_data,
            "by_policy_type": policy_types
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"コンプライアンスサマリー取得エラー: {str(e)}")


# ========================================
# 会議品質分析API
# ========================================

@router.get("/meeting-quality",
           response_model=PaginatedResponse,
           summary="会議品質分析データ取得")
async def get_meeting_quality(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    days: int = Query(7, ge=1, le=30, description="分析期間（日数）"),
    quality_rating: Optional[str] = Query(None, description="品質評価フィルター"),
    min_participants: int = Query(2, ge=1, description="最小参加者数"),
    session: AsyncSession = Depends(get_async_session)
):
    """会議品質分析データ取得"""
    
    try:
        cutoff_date = datetime.utcnow() - timedelta(days=days)
        
        query = select(MeetingQualityAnalysis).where(
            and_(
                MeetingQualityAnalysis.datetime >= cutoff_date,
                MeetingQualityAnalysis.participant_count >= min_participants
            )
        )
        count_query = select(func.count(MeetingQualityAnalysis.id)).where(
            and_(
                MeetingQualityAnalysis.datetime >= cutoff_date,
                MeetingQualityAnalysis.participant_count >= min_participants
            )
        )
        
        if quality_rating:
            query = query.where(MeetingQualityAnalysis.quality_rating == quality_rating)
            count_query = count_query.where(MeetingQualityAnalysis.quality_rating == quality_rating)
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(MeetingQualityAnalysis.datetime)).offset(offset).limit(size)
        
        result = await session.execute(query)
        quality_data = result.scalars().all()
        
        items = [MeetingQualityAnalysisResponse.from_orm(quality) for quality in quality_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"会議品質分析取得エラー: {str(e)}")


@router.get("/meeting-quality/statistics",
           summary="会議品質統計情報")
async def get_meeting_quality_statistics(
    days: int = Query(7, ge=1, le=30),
    session: AsyncSession = Depends(get_async_session)
):
    """会議品質統計情報取得"""
    
    try:
        cutoff_date = datetime.utcnow() - timedelta(days=days)
        
        # 基本統計
        stats_query = select(
            func.count(MeetingQualityAnalysis.id).label('total_meetings'),
            func.avg(MeetingQualityAnalysis.overall_quality_score).label('avg_quality_score'),
            func.avg(MeetingQualityAnalysis.participant_count).label('avg_participants'),
            func.avg(MeetingQualityAnalysis.duration_minutes).label('avg_duration')
        ).where(MeetingQualityAnalysis.datetime >= cutoff_date)
        
        result = await session.execute(stats_query)
        stats = result.first()
        
        # 品質評価別統計
        rating_query = select(
            MeetingQualityAnalysis.quality_rating,
            func.count(MeetingQualityAnalysis.id).label('count')
        ).where(
            MeetingQualityAnalysis.datetime >= cutoff_date
        ).group_by(MeetingQualityAnalysis.quality_rating).order_by(func.count(MeetingQualityAnalysis.id).desc())
        
        rating_result = await session.execute(rating_query)
        quality_ratings = [
            {
                "rating": row[0] or "未評価",
                "meeting_count": row[1]
            }
            for row in rating_result.all()
        ]
        
        # 品質要素別統計
        quality_elements = []
        for element in ['audio_quality', 'video_quality', 'network_quality']:
            element_query = select(
                getattr(MeetingQualityAnalysis, element).label('quality_level'),
                func.count(MeetingQualityAnalysis.id).label('count')
            ).where(
                MeetingQualityAnalysis.datetime >= cutoff_date
            ).group_by(getattr(MeetingQualityAnalysis, element))
            
            element_result = await session.execute(element_query)
            element_data = [
                {
                    "quality_level": row[0] or "不明",
                    "count": row[1]
                }
                for row in element_result.all()
            ]
            
            quality_elements.append({
                "element": element,
                "distribution": element_data
            })
        
        return {
            "period_days": days,
            "summary": {
                "total_meetings": stats[0],
                "average_quality_score": float(stats[1]) if stats[1] else 0,
                "average_participants": float(stats[2]) if stats[2] else 0,
                "average_duration_minutes": float(stats[3]) if stats[3] else 0
            },
            "by_quality_rating": quality_ratings,
            "quality_elements": quality_elements
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"会議品質統計取得エラー: {str(e)}")


# ========================================
# Teamsアプリ分析API
# ========================================

@router.get("/apps",
           response_model=PaginatedResponse,
           summary="Teamsアプリ分析データ取得")
async def get_teams_apps(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    app_status: Optional[str] = Query(None, description="アプリ状態フィルター"),
    risk_level: Optional[str] = Query(None, description="リスクレベルフィルター"),
    min_users: int = Query(1, ge=0, description="最小利用ユーザー数"),
    session: AsyncSession = Depends(get_async_session)
):
    """Teamsアプリ分析データ取得"""
    
    try:
        query = select(TeamsAppAnalysis).where(TeamsAppAnalysis.active_users_count >= min_users)
        count_query = select(func.count(TeamsAppAnalysis.id)).where(TeamsAppAnalysis.active_users_count >= min_users)
        
        filters = []
        if app_status:
            filters.append(TeamsAppAnalysis.app_status == app_status)
        if risk_level:
            filters.append(TeamsAppAnalysis.risk_level == risk_level)
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(TeamsAppAnalysis.active_users_count)).offset(offset).limit(size)
        
        result = await session.execute(query)
        apps_data = result.scalars().all()
        
        items = [TeamsAppAnalysisResponse.from_orm(app) for app in apps_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Teamsアプリ分析取得エラー: {str(e)}")


@router.get("/apps/security-summary",
           summary="アプリセキュリティサマリー")
async def get_app_security_summary(
    session: AsyncSession = Depends(get_async_session)
):
    """アプリセキュリティサマリー取得"""
    
    try:
        # リスクレベル別統計
        risk_query = select(
            TeamsAppAnalysis.risk_level,
            func.count(TeamsAppAnalysis.id).label('app_count'),
            func.sum(TeamsAppAnalysis.active_users_count).label('total_users'),
            func.avg(TeamsAppAnalysis.security_score).label('avg_security_score')
        ).group_by(TeamsAppAnalysis.risk_level).order_by(func.count(TeamsAppAnalysis.id).desc())
        
        risk_result = await session.execute(risk_query)
        risk_levels = [
            {
                "risk_level": row[0] or "未評価",
                "app_count": row[1],
                "affected_users": row[2] or 0,
                "average_security_score": float(row[3]) if row[3] else 0
            }
            for row in risk_result.all()
        ]
        
        # 権限ステータス別統計
        permission_query = select(
            TeamsAppAnalysis.permission_status,
            func.count(TeamsAppAnalysis.id).label('count')
        ).group_by(TeamsAppAnalysis.permission_status).order_by(func.count(TeamsAppAnalysis.id).desc())
        
        permission_result = await session.execute(permission_query)
        permission_statuses = [
            {
                "permission_status": row[0] or "不明",
                "app_count": row[1]
            }
            for row in permission_result.all()
        ]
        
        # 高リスクアプリTop10
        high_risk_query = select(
            TeamsAppAnalysis.app_name,
            TeamsAppAnalysis.risk_level,
            TeamsAppAnalysis.active_users_count,
            TeamsAppAnalysis.security_score
        ).where(
            TeamsAppAnalysis.risk_level == '高'
        ).order_by(desc(TeamsAppAnalysis.active_users_count)).limit(10)
        
        high_risk_result = await session.execute(high_risk_query)
        high_risk_apps = [
            {
                "app_name": row[0],
                "risk_level": row[1],
                "active_users": row[2],
                "security_score": float(row[3]) if row[3] else 0
            }
            for row in high_risk_result.all()
        ]
        
        return {
            "risk_level_distribution": risk_levels,
            "permission_status_distribution": permission_statuses,
            "high_risk_apps": high_risk_apps
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"アプリセキュリティサマリー取得エラー: {str(e)}")


# ========================================
# データ同期API
# ========================================

@router.post("/sync/usage",
            summary="Teams使用状況同期",
            description="Microsoft Graph APIからTeams使用状況データを同期")
async def sync_teams_usage(
    background_tasks: BackgroundTasks,
    days: int = Query(30, ge=1, le=365, description="同期期間（日数）"),
    session: AsyncSession = Depends(get_async_session)
):
    """Teams使用状況同期"""
    
    try:
        background_tasks.add_task(
            _sync_teams_usage_task,
            days
        )
        
        return {
            "message": "Teams使用状況同期を開始しました",
            "sync_period_days": days,
            "status": "processing"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Teams使用状況同期エラー: {str(e)}")


@router.post("/sync/meeting-quality",
            summary="会議品質データ同期")
async def sync_meeting_quality(
    background_tasks: BackgroundTasks,
    days: int = Query(7, ge=1, le=30),
    session: AsyncSession = Depends(get_async_session)
):
    """会議品質データ同期"""
    
    try:
        background_tasks.add_task(
            _sync_meeting_quality_task,
            days
        )
        
        return {
            "message": "会議品質データ同期を開始しました",
            "sync_period_days": days,
            "status": "processing"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"会議品質同期エラー: {str(e)}")


# ========================================
# バックグラウンドタスク
# ========================================

async def _sync_teams_usage_task(days: int):
    """Teams使用状況同期タスク"""
    # Microsoft Graph Teams API 呼び出し実装
    pass


async def _sync_meeting_quality_task(days: int):
    """会議品質同期タスク"""
    # Microsoft Graph Teams API 呼び出し実装
    pass