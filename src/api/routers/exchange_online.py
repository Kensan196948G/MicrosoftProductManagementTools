"""
Microsoft 365管理ツール Exchange Online管理API
=========================================

Exchange Online管理機能 REST API実装 (4機能)
- メールボックス管理
- メールフロー分析
- スパム対策分析
- メール配信分析
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
    Mailbox, MailFlowAnalysis, SpamProtectionAnalysis, MailDeliveryAnalysis
)

router = APIRouter(prefix="/exchange-online", tags=["Exchange Online管理"])


# ========================================
# Pydanticモデル（レスポンス）
# ========================================

class MailboxResponse(BaseModel):
    """メールボックスレスポンス"""
    id: int
    email: str
    display_name: Optional[str]
    user_principal_name: Optional[str]
    mailbox_type: Optional[str]
    total_size_mb: Optional[float]
    quota_mb: Optional[float]
    usage_percent: Optional[float]
    message_count: int
    last_access: Optional[datetime]
    forwarding_enabled: Optional[bool]
    forwarding_address: Optional[str]
    auto_reply_enabled: Optional[bool]
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class MailFlowAnalysisResponse(BaseModel):
    """メールフロー分析レスポンス"""
    id: int
    datetime: datetime
    sender: Optional[str]
    recipient: Optional[str]
    recipient_mailbox_id: Optional[int]
    subject: Optional[str]
    message_size_kb: Optional[float]
    status: Optional[str]
    connector: Optional[str]
    event_type: Optional[str]
    details: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


class SpamProtectionAnalysisResponse(BaseModel):
    """スパム対策分析レスポンス"""
    id: int
    datetime: datetime
    sender: Optional[str]
    recipient: Optional[str]
    subject: Optional[str]
    threat_type: Optional[str]
    spam_score: Optional[float]
    action: Optional[str]
    policy_name: Optional[str]
    details: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


class MailDeliveryAnalysisResponse(BaseModel):
    """メール配信分析レスポンス"""
    id: int
    send_datetime: datetime
    sender: Optional[str]
    recipient: Optional[str]
    subject: Optional[str]
    message_id: Optional[str]
    delivery_status: Optional[str]
    latest_event: Optional[str]
    delay_reason: Optional[str]
    recipient_server: Optional[str]
    bounce_type: Optional[str]
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


class MailboxUpdateRequest(BaseModel):
    """メールボックス更新リクエスト"""
    display_name: Optional[str] = Field(None, description="表示名")
    quota_mb: Optional[float] = Field(None, description="クォータ(MB)")
    forwarding_enabled: Optional[bool] = Field(None, description="転送有効化")
    forwarding_address: Optional[str] = Field(None, description="転送先アドレス")
    auto_reply_enabled: Optional[bool] = Field(None, description="自動応答有効化")


# ========================================
# メールボックス管理API
# ========================================

@router.get("/mailboxes",
           response_model=PaginatedResponse,
           summary="メールボックス一覧取得",
           description="Exchange Onlineメールボックス情報を取得")
async def get_mailboxes(
    page: int = Query(1, ge=1, description="ページ番号"),
    size: int = Query(50, ge=1, le=1000, description="ページサイズ"),
    mailbox_type: Optional[str] = Query(None, description="メールボックス種別フィルター"),
    high_usage: bool = Query(False, description="高使用率のみ表示（80%以上）"),
    search: Optional[str] = Query(None, description="メールアドレス・表示名検索"),
    sort_by: str = Query("total_size_mb", description="ソート項目"),
    sort_order: str = Query("desc", regex="^(asc|desc)$", description="ソート順序"),
    session: AsyncSession = Depends(get_async_session)
):
    """メールボックス一覧取得"""
    
    try:
        query = select(Mailbox)
        count_query = select(func.count(Mailbox.id))
        
        # フィルター適用
        filters = []
        if mailbox_type:
            filters.append(Mailbox.mailbox_type == mailbox_type)
        if high_usage:
            filters.append(Mailbox.usage_percent >= 80.0)
        if search:
            search_filter = or_(
                Mailbox.email.contains(search),
                Mailbox.display_name.contains(search),
                Mailbox.user_principal_name.contains(search)
            )
            filters.append(search_filter)
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        # 総件数取得
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        # ソート適用
        sort_column = getattr(Mailbox, sort_by, Mailbox.total_size_mb)
        if sort_order == "desc":
            query = query.order_by(desc(sort_column))
        else:
            query = query.order_by(sort_column)
        
        # ページネーション適用
        offset = (page - 1) * size
        query = query.offset(offset).limit(size)
        
        # データ取得
        result = await session.execute(query)
        mailboxes = result.scalars().all()
        
        # レスポンス形式に変換
        items = [MailboxResponse.from_orm(mailbox) for mailbox in mailboxes]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"メールボックス一覧取得エラー: {str(e)}")


@router.get("/mailboxes/{mailbox_id}",
           response_model=MailboxResponse,
           summary="メールボックス詳細取得")
async def get_mailbox(
    mailbox_id: int,
    session: AsyncSession = Depends(get_async_session)
):
    """個別メールボックス情報取得"""
    
    try:
        query = select(Mailbox).where(Mailbox.id == mailbox_id)
        result = await session.execute(query)
        mailbox = result.scalar_one_or_none()
        
        if not mailbox:
            raise HTTPException(status_code=404, detail="メールボックスが見つかりません")
        
        return MailboxResponse.from_orm(mailbox)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"メールボックス取得エラー: {str(e)}")


@router.put("/mailboxes/{mailbox_id}",
           response_model=MailboxResponse,
           summary="メールボックス更新")
async def update_mailbox(
    mailbox_id: int,
    mailbox_data: MailboxUpdateRequest,
    session: AsyncSession = Depends(get_async_session)
):
    """メールボックス設定更新"""
    
    try:
        # メールボックス存在確認
        query = select(Mailbox).where(Mailbox.id == mailbox_id)
        result = await session.execute(query)
        mailbox = result.scalar_one_or_none()
        
        if not mailbox:
            raise HTTPException(status_code=404, detail="メールボックスが見つかりません")
        
        # 更新データ適用
        update_data = mailbox_data.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(mailbox, field, value)
        
        # 使用率再計算
        if mailbox.total_size_mb and mailbox.quota_mb:
            mailbox.usage_percent = Decimal(str(mailbox.total_size_mb / mailbox.quota_mb * 100))
        
        await session.commit()
        await session.refresh(mailbox)
        
        return MailboxResponse.from_orm(mailbox)
        
    except HTTPException:
        raise
    except Exception as e:
        await session.rollback()
        raise HTTPException(status_code=500, detail=f"メールボックス更新エラー: {str(e)}")


@router.get("/mailboxes/statistics",
           summary="メールボックス統計情報")
async def get_mailbox_statistics(
    mailbox_type: Optional[str] = Query(None),
    session: AsyncSession = Depends(get_async_session)
):
    """メールボックス統計情報取得"""
    
    try:
        base_query = select(Mailbox)
        if mailbox_type:
            base_query = base_query.where(Mailbox.mailbox_type == mailbox_type)
        
        # 基本統計
        stats_query = select(
            func.count(Mailbox.id).label('total_mailboxes'),
            func.avg(Mailbox.total_size_mb).label('avg_size_mb'),
            func.sum(Mailbox.total_size_mb).label('total_size_mb'),
            func.avg(Mailbox.usage_percent).label('avg_usage_percent'),
            func.count(Mailbox.id).filter(Mailbox.usage_percent >= 80).label('high_usage_count'),
            func.count(Mailbox.id).filter(Mailbox.forwarding_enabled == True).label('forwarding_enabled_count')
        )
        
        if mailbox_type:
            stats_query = stats_query.where(Mailbox.mailbox_type == mailbox_type)
        
        result = await session.execute(stats_query)
        stats = result.first()
        
        # 種別別統計
        type_query = select(
            Mailbox.mailbox_type,
            func.count(Mailbox.id).label('count'),
            func.avg(Mailbox.total_size_mb).label('avg_size'),
            func.avg(Mailbox.usage_percent).label('avg_usage')
        ).group_by(Mailbox.mailbox_type).order_by(func.count(Mailbox.id).desc())
        
        type_result = await session.execute(type_query)
        mailbox_types = [
            {
                "mailbox_type": row[0] or "未分類",
                "count": row[1],
                "average_size_mb": float(row[2]) if row[2] else 0,
                "average_usage_percent": float(row[3]) if row[3] else 0
            }
            for row in type_result.all()
        ]
        
        return {
            "summary": {
                "total_mailboxes": stats[0],
                "average_size_mb": float(stats[1]) if stats[1] else 0,
                "total_size_gb": float(stats[2] / 1024) if stats[2] else 0,
                "average_usage_percent": float(stats[3]) if stats[3] else 0,
                "high_usage_mailboxes": stats[4],
                "forwarding_enabled_count": stats[5]
            },
            "by_type": mailbox_types,
            "type_filter": mailbox_type
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"メールボックス統計取得エラー: {str(e)}")


# ========================================
# メールフロー分析API
# ========================================

@router.get("/mail-flow",
           response_model=PaginatedResponse,
           summary="メールフロー分析データ取得")
async def get_mail_flow_analysis(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    hours: int = Query(24, ge=1, le=168, description="分析期間（時間）"),
    event_type: Optional[str] = Query(None, description="イベント種別フィルター"),
    status: Optional[str] = Query(None, description="ステータスフィルター"),
    session: AsyncSession = Depends(get_async_session)
):
    """メールフロー分析データ取得"""
    
    try:
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        query = select(MailFlowAnalysis).where(MailFlowAnalysis.datetime >= cutoff_time)
        count_query = select(func.count(MailFlowAnalysis.id)).where(MailFlowAnalysis.datetime >= cutoff_time)
        
        filters = []
        if event_type:
            filters.append(MailFlowAnalysis.event_type == event_type)
        if status:
            filters.append(MailFlowAnalysis.status == status)
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(MailFlowAnalysis.datetime)).offset(offset).limit(size)
        
        result = await session.execute(query)
        mail_flow_data = result.scalars().all()
        
        items = [MailFlowAnalysisResponse.from_orm(flow) for flow in mail_flow_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"メールフロー分析取得エラー: {str(e)}")


@router.get("/mail-flow/statistics",
           summary="メールフロー統計情報")
async def get_mail_flow_statistics(
    hours: int = Query(24, ge=1, le=168),
    session: AsyncSession = Depends(get_async_session)
):
    """メールフロー統計情報取得"""
    
    try:
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        # 基本統計
        stats_query = select(
            func.count(MailFlowAnalysis.id).label('total_messages'),
            func.count(MailFlowAnalysis.id).filter(MailFlowAnalysis.status == '配信済み').label('delivered'),
            func.count(MailFlowAnalysis.id).filter(MailFlowAnalysis.status == '失敗').label('failed'),
            func.count(MailFlowAnalysis.id).filter(MailFlowAnalysis.status == '遅延').label('delayed'),
            func.avg(MailFlowAnalysis.message_size_kb).label('avg_message_size')
        ).where(MailFlowAnalysis.datetime >= cutoff_time)
        
        result = await session.execute(stats_query)
        stats = result.first()
        
        # イベント種別統計
        event_query = select(
            MailFlowAnalysis.event_type,
            func.count(MailFlowAnalysis.id).label('count')
        ).where(
            MailFlowAnalysis.datetime >= cutoff_time
        ).group_by(MailFlowAnalysis.event_type).order_by(func.count(MailFlowAnalysis.id).desc())
        
        event_result = await session.execute(event_query)
        event_types = [
            {
                "event_type": row[0] or "不明",
                "message_count": row[1]
            }
            for row in event_result.all()
        ]
        
        # 配信率計算
        total = stats[0] or 1
        delivery_rate = (stats[1] or 0) / total * 100
        
        return {
            "period_hours": hours,
            "summary": {
                "total_messages": stats[0],
                "delivered_messages": stats[1],
                "failed_messages": stats[2],
                "delayed_messages": stats[3],
                "delivery_rate_percent": round(delivery_rate, 2),
                "average_message_size_kb": float(stats[4]) if stats[4] else 0
            },
            "by_event_type": event_types
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"メールフロー統計取得エラー: {str(e)}")


# ========================================
# スパム対策分析API
# ========================================

@router.get("/spam-protection",
           response_model=PaginatedResponse,
           summary="スパム対策分析データ取得")
async def get_spam_protection_analysis(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    hours: int = Query(24, ge=1, le=168),
    threat_type: Optional[str] = Query(None, description="脅威種別フィルター"),
    action: Optional[str] = Query(None, description="対処アクションフィルター"),
    session: AsyncSession = Depends(get_async_session)
):
    """スパム対策分析データ取得"""
    
    try:
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        query = select(SpamProtectionAnalysis).where(SpamProtectionAnalysis.datetime >= cutoff_time)
        count_query = select(func.count(SpamProtectionAnalysis.id)).where(SpamProtectionAnalysis.datetime >= cutoff_time)
        
        filters = []
        if threat_type:
            filters.append(SpamProtectionAnalysis.threat_type == threat_type)
        if action:
            filters.append(SpamProtectionAnalysis.action == action)
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(SpamProtectionAnalysis.datetime)).offset(offset).limit(size)
        
        result = await session.execute(query)
        spam_data = result.scalars().all()
        
        items = [SpamProtectionAnalysisResponse.from_orm(spam) for spam in spam_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"スパム対策分析取得エラー: {str(e)}")


@router.get("/spam-protection/statistics",
           summary="スパム対策統計情報")
async def get_spam_protection_statistics(
    hours: int = Query(24, ge=1, le=168),
    session: AsyncSession = Depends(get_async_session)
):
    """スパム対策統計情報取得"""
    
    try:
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        # 脅威統計
        threat_query = select(
            SpamProtectionAnalysis.threat_type,
            func.count(SpamProtectionAnalysis.id).label('count'),
            func.avg(SpamProtectionAnalysis.spam_score).label('avg_score')
        ).where(
            SpamProtectionAnalysis.datetime >= cutoff_time
        ).group_by(SpamProtectionAnalysis.threat_type).order_by(func.count(SpamProtectionAnalysis.id).desc())
        
        threat_result = await session.execute(threat_query)
        threat_types = [
            {
                "threat_type": row[0] or "不明",
                "detection_count": row[1],
                "average_spam_score": float(row[2]) if row[2] else 0
            }
            for row in threat_result.all()
        ]
        
        # アクション統計
        action_query = select(
            SpamProtectionAnalysis.action,
            func.count(SpamProtectionAnalysis.id).label('count')
        ).where(
            SpamProtectionAnalysis.datetime >= cutoff_time
        ).group_by(SpamProtectionAnalysis.action).order_by(func.count(SpamProtectionAnalysis.id).desc())
        
        action_result = await session.execute(action_query)
        actions = [
            {
                "action": row[0] or "不明",
                "count": row[1]
            }
            for row in action_result.all()
        ]
        
        # 全体統計
        total_result = await session.execute(
            select(func.count(SpamProtectionAnalysis.id)).where(SpamProtectionAnalysis.datetime >= cutoff_time)
        )
        total_detections = total_result.scalar()
        
        return {
            "period_hours": hours,
            "summary": {
                "total_detections": total_detections,
                "threat_types_count": len(threat_types)
            },
            "by_threat_type": threat_types,
            "by_action": actions
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"スパム対策統計取得エラー: {str(e)}")


# ========================================
# メール配信分析API
# ========================================

@router.get("/mail-delivery",
           response_model=PaginatedResponse,
           summary="メール配信分析データ取得")
async def get_mail_delivery_analysis(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    hours: int = Query(24, ge=1, le=168),
    delivery_status: Optional[str] = Query(None, description="配信ステータスフィルター"),
    session: AsyncSession = Depends(get_async_session)
):
    """メール配信分析データ取得"""
    
    try:
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        query = select(MailDeliveryAnalysis).where(MailDeliveryAnalysis.send_datetime >= cutoff_time)
        count_query = select(func.count(MailDeliveryAnalysis.id)).where(MailDeliveryAnalysis.send_datetime >= cutoff_time)
        
        if delivery_status:
            query = query.where(MailDeliveryAnalysis.delivery_status == delivery_status)
            count_query = count_query.where(MailDeliveryAnalysis.delivery_status == delivery_status)
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(MailDeliveryAnalysis.send_datetime)).offset(offset).limit(size)
        
        result = await session.execute(query)
        delivery_data = result.scalars().all()
        
        items = [MailDeliveryAnalysisResponse.from_orm(delivery) for delivery in delivery_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"メール配信分析取得エラー: {str(e)}")


@router.get("/mail-delivery/statistics",
           summary="メール配信統計情報")
async def get_mail_delivery_statistics(
    hours: int = Query(24, ge=1, le=168),
    session: AsyncSession = Depends(get_async_session)
):
    """メール配信統計情報取得"""
    
    try:
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        # 配信ステータス統計
        status_query = select(
            MailDeliveryAnalysis.delivery_status,
            func.count(MailDeliveryAnalysis.id).label('count')
        ).where(
            MailDeliveryAnalysis.send_datetime >= cutoff_time
        ).group_by(MailDeliveryAnalysis.delivery_status).order_by(func.count(MailDeliveryAnalysis.id).desc())
        
        status_result = await session.execute(status_query)
        delivery_statuses = [
            {
                "status": row[0] or "不明",
                "count": row[1]
            }
            for row in status_result.all()
        ]
        
        # 遅延理由統計
        delay_query = select(
            MailDeliveryAnalysis.delay_reason,
            func.count(MailDeliveryAnalysis.id).label('count')
        ).where(
            and_(
                MailDeliveryAnalysis.send_datetime >= cutoff_time,
                MailDeliveryAnalysis.delivery_status == '遅延',
                MailDeliveryAnalysis.delay_reason.isnot(None)
            )
        ).group_by(MailDeliveryAnalysis.delay_reason).order_by(func.count(MailDeliveryAnalysis.id).desc()).limit(10)
        
        delay_result = await session.execute(delay_query)
        delay_reasons = [
            {
                "reason": row[0],
                "count": row[1]
            }
            for row in delay_result.all()
        ]
        
        # 全体統計
        total_result = await session.execute(
            select(func.count(MailDeliveryAnalysis.id)).where(MailDeliveryAnalysis.send_datetime >= cutoff_time)
        )
        total_messages = total_result.scalar()
        
        return {
            "period_hours": hours,
            "summary": {
                "total_messages": total_messages
            },
            "by_delivery_status": delivery_statuses,
            "delay_reasons": delay_reasons
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"メール配信統計取得エラー: {str(e)}")


# ========================================
# データ同期API
# ========================================

@router.post("/sync/mailboxes",
            summary="メールボックス同期",
            description="Exchange Onlineからメールボックス情報を同期")
async def sync_mailboxes(
    background_tasks: BackgroundTasks,
    force_full_sync: bool = Query(False, description="完全同期実行"),
    session: AsyncSession = Depends(get_async_session)
):
    """メールボックスデータ同期"""
    
    try:
        background_tasks.add_task(
            _sync_mailboxes_task,
            force_full_sync
        )
        
        return {
            "message": "メールボックスデータ同期を開始しました",
            "sync_type": "完全同期" if force_full_sync else "差分同期",
            "status": "processing"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"メールボックス同期エラー: {str(e)}")


@router.post("/sync/mail-flow",
            summary="メールフロー同期")
async def sync_mail_flow(
    background_tasks: BackgroundTasks,
    hours: int = Query(24, ge=1, le=168),
    session: AsyncSession = Depends(get_async_session)
):
    """メールフローデータ同期"""
    
    try:
        background_tasks.add_task(
            _sync_mail_flow_task,
            hours
        )
        
        return {
            "message": "メールフローデータ同期を開始しました",
            "sync_period_hours": hours,
            "status": "processing"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"メールフロー同期エラー: {str(e)}")


# ========================================
# バックグラウンドタスク
# ========================================

async def _sync_mailboxes_task(force_full_sync: bool):
    """メールボックス同期タスク"""
    # Exchange Online PowerShell/Graph API 呼び出し実装
    pass


async def _sync_mail_flow_task(hours: int):
    """メールフロー同期タスク"""
    # Exchange Online PowerShell 呼び出し実装
    pass