"""
Microsoft 365管理ツール Entra ID管理API
====================================

Entra ID管理機能 REST API実装 (4機能)
- ユーザー管理
- MFA状況管理
- 条件付きアクセス管理
- サインインログ分析
"""

from datetime import date, datetime, timedelta
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, and_, or_
from pydantic import BaseModel, Field
from uuid import UUID

from ...database.connection import get_async_session
from ...database.models import (
    User, MFAStatus, ConditionalAccessPolicy, SignInLog
)

router = APIRouter(prefix="/entra-id", tags=["Entra ID管理"])


# ========================================
# Pydanticモデル（レスポンス）
# ========================================

class UserResponse(BaseModel):
    """ユーザーレスポンス"""
    id: int
    display_name: str
    user_principal_name: str
    email: Optional[str]
    department: Optional[str]
    job_title: Optional[str]
    account_status: Optional[str]
    license_status: Optional[str]
    creation_date: Optional[date]
    last_sign_in: Optional[datetime]
    usage_location: Optional[str]
    azure_ad_id: Optional[UUID]
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class MFAStatusResponse(BaseModel):
    """MFA状況レスポンス"""
    id: int
    report_date: date
    user_principal_name: str
    display_name: Optional[str]
    department: Optional[str]
    mfa_status: Optional[str]
    mfa_default_method: Optional[str]
    phone_number: Optional[str]
    email: Optional[str]
    registration_date: Optional[datetime]
    last_verification: Optional[datetime]
    status: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


class ConditionalAccessPolicyResponse(BaseModel):
    """条件付きアクセスポリシーレスポンス"""
    id: int
    policy_name: str
    status: Optional[str]
    target_users: Optional[str]
    target_applications: Optional[str]
    conditions: Optional[str]
    access_controls: Optional[str]
    creation_date: Optional[date]
    last_updated: Optional[date]
    application_count: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class SignInLogResponse(BaseModel):
    """サインインログレスポンス"""
    id: int
    signin_datetime: datetime
    user_name: str
    user_principal_name: Optional[str]
    application: Optional[str]
    client_app: Optional[str]
    device_info: Optional[str]
    location_city: Optional[str]
    location_country: Optional[str]
    ip_address: Optional[str]
    status: Optional[str]
    error_code: Optional[str]
    failure_reason: Optional[str]
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


class UserCreateRequest(BaseModel):
    """ユーザー作成リクエスト"""
    display_name: str = Field(..., description="表示名")
    user_principal_name: str = Field(..., description="UPN")
    email: Optional[str] = Field(None, description="メールアドレス")
    department: Optional[str] = Field(None, description="部署")
    job_title: Optional[str] = Field(None, description="職位")
    usage_location: Optional[str] = Field("JP", description="使用場所")


class UserUpdateRequest(BaseModel):
    """ユーザー更新リクエスト"""
    display_name: Optional[str] = Field(None, description="表示名")
    email: Optional[str] = Field(None, description="メールアドレス")
    department: Optional[str] = Field(None, description="部署")
    job_title: Optional[str] = Field(None, description="職位")
    account_status: Optional[str] = Field(None, description="アカウント状態")
    license_status: Optional[str] = Field(None, description="ライセンス状態")


# ========================================
# ユーザー管理API
# ========================================

@router.get("/users",
           response_model=PaginatedResponse,
           summary="ユーザー一覧取得",
           description="Entra IDユーザー情報を取得（Microsoft Graph Users API互換）")
async def get_users(
    page: int = Query(1, ge=1, description="ページ番号"),
    size: int = Query(50, ge=1, le=1000, description="ページサイズ"),
    department: Optional[str] = Query(None, description="部署フィルター"),
    account_status: Optional[str] = Query(None, description="アカウント状態フィルター"),
    search: Optional[str] = Query(None, description="ユーザー名・メール検索"),
    sort_by: str = Query("created_at", description="ソート項目"),
    sort_order: str = Query("desc", regex="^(asc|desc)$", description="ソート順序"),
    session: AsyncSession = Depends(get_async_session)
):
    """ユーザー一覧取得"""
    
    try:
        query = select(User)
        count_query = select(func.count(User.id))
        
        # フィルター適用
        filters = []
        if department:
            filters.append(User.department == department)
        if account_status:
            filters.append(User.account_status == account_status)
        if search:
            search_filter = or_(
                User.display_name.contains(search),
                User.user_principal_name.contains(search),
                User.email.contains(search)
            )
            filters.append(search_filter)
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        # 総件数取得
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        # ソート適用
        sort_column = getattr(User, sort_by, User.created_at)
        if sort_order == "desc":
            query = query.order_by(desc(sort_column))
        else:
            query = query.order_by(sort_column)
        
        # ページネーション適用
        offset = (page - 1) * size
        query = query.offset(offset).limit(size)
        
        # データ取得
        result = await session.execute(query)
        users = result.scalars().all()
        
        # レスポンス形式に変換
        items = [UserResponse.from_orm(user) for user in users]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ユーザー一覧取得エラー: {str(e)}")


@router.get("/users/{user_id}",
           response_model=UserResponse,
           summary="ユーザー詳細取得")
async def get_user(
    user_id: int,
    session: AsyncSession = Depends(get_async_session)
):
    """個別ユーザー情報取得"""
    
    try:
        query = select(User).where(User.id == user_id)
        result = await session.execute(query)
        user = result.scalar_one_or_none()
        
        if not user:
            raise HTTPException(status_code=404, detail="ユーザーが見つかりません")
        
        return UserResponse.from_orm(user)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ユーザー取得エラー: {str(e)}")


@router.post("/users",
            response_model=UserResponse,
            summary="ユーザー作成",
            status_code=201)
async def create_user(
    user_data: UserCreateRequest,
    session: AsyncSession = Depends(get_async_session)
):
    """新規ユーザー作成"""
    
    try:
        # UPN重複チェック
        existing_query = select(User).where(User.user_principal_name == user_data.user_principal_name)
        existing_result = await session.execute(existing_query)
        if existing_result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="UPNが既に存在します")
        
        # 新規ユーザー作成
        new_user = User(
            display_name=user_data.display_name,
            user_principal_name=user_data.user_principal_name,
            email=user_data.email,
            department=user_data.department,
            job_title=user_data.job_title,
            account_status="有効",
            usage_location=user_data.usage_location,
            creation_date=date.today()
        )
        
        session.add(new_user)
        await session.commit()
        await session.refresh(new_user)
        
        return UserResponse.from_orm(new_user)
        
    except HTTPException:
        raise
    except Exception as e:
        await session.rollback()
        raise HTTPException(status_code=500, detail=f"ユーザー作成エラー: {str(e)}")


@router.put("/users/{user_id}",
           response_model=UserResponse,
           summary="ユーザー更新")
async def update_user(
    user_id: int,
    user_data: UserUpdateRequest,
    session: AsyncSession = Depends(get_async_session)
):
    """ユーザー情報更新"""
    
    try:
        # ユーザー存在確認
        query = select(User).where(User.id == user_id)
        result = await session.execute(query)
        user = result.scalar_one_or_none()
        
        if not user:
            raise HTTPException(status_code=404, detail="ユーザーが見つかりません")
        
        # 更新データ適用
        update_data = user_data.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(user, field, value)
        
        await session.commit()
        await session.refresh(user)
        
        return UserResponse.from_orm(user)
        
    except HTTPException:
        raise
    except Exception as e:
        await session.rollback()
        raise HTTPException(status_code=500, detail=f"ユーザー更新エラー: {str(e)}")


@router.delete("/users/{user_id}",
              summary="ユーザー削除",
              status_code=204)
async def delete_user(
    user_id: int,
    session: AsyncSession = Depends(get_async_session)
):
    """ユーザー削除"""
    
    try:
        query = select(User).where(User.id == user_id)
        result = await session.execute(query)
        user = result.scalar_one_or_none()
        
        if not user:
            raise HTTPException(status_code=404, detail="ユーザーが見つかりません")
        
        await session.delete(user)
        await session.commit()
        
    except HTTPException:
        raise
    except Exception as e:
        await session.rollback()
        raise HTTPException(status_code=500, detail=f"ユーザー削除エラー: {str(e)}")


@router.get("/users/statistics",
           summary="ユーザー統計情報")
async def get_user_statistics(
    department: Optional[str] = Query(None),
    session: AsyncSession = Depends(get_async_session)
):
    """ユーザー統計情報取得"""
    
    try:
        base_query = select(User)
        if department:
            base_query = base_query.where(User.department == department)
        
        # 基本統計
        stats_query = select(
            func.count(User.id).label('total_users'),
            func.count(User.id).filter(User.account_status == '有効').label('active_users'),
            func.count(User.id).filter(User.last_sign_in >= datetime.utcnow() - timedelta(days=30)).label('recent_active'),
            func.count(func.distinct(User.department)).label('departments')
        )
        
        if department:
            stats_query = stats_query.where(User.department == department)
        
        result = await session.execute(stats_query)
        stats = result.first()
        
        # 部署別統計
        dept_query = select(
            User.department,
            func.count(User.id).label('user_count'),
            func.count(User.id).filter(User.account_status == '有効').label('active_count')
        ).group_by(User.department).order_by(func.count(User.id).desc())
        
        dept_result = await session.execute(dept_query)
        departments = [
            {
                "department": row[0] or "未設定",
                "total_users": row[1],
                "active_users": row[2]
            }
            for row in dept_result.all()
        ]
        
        return {
            "summary": {
                "total_users": stats[0],
                "active_users": stats[1], 
                "recently_active_users": stats[2],
                "total_departments": stats[3]
            },
            "by_department": departments,
            "department_filter": department
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ユーザー統計取得エラー: {str(e)}")


# ========================================
# MFA状況管理API
# ========================================

@router.get("/mfa-status",
           response_model=PaginatedResponse,
           summary="MFA状況一覧取得")
async def get_mfa_status(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    mfa_status: Optional[str] = Query(None, description="MFA状態フィルター"),
    department: Optional[str] = Query(None, description="部署フィルター"),
    session: AsyncSession = Depends(get_async_session)
):
    """MFA状況一覧取得"""
    
    try:
        query = select(MFAStatus)
        count_query = select(func.count(MFAStatus.id))
        
        filters = []
        if mfa_status:
            filters.append(MFAStatus.mfa_status == mfa_status)
        if department:
            filters.append(MFAStatus.department == department)
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(MFAStatus.report_date)).offset(offset).limit(size)
        
        result = await session.execute(query)
        mfa_data = result.scalars().all()
        
        items = [MFAStatusResponse.from_orm(mfa) for mfa in mfa_data]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"MFA状況取得エラー: {str(e)}")


@router.get("/mfa-status/summary",
           summary="MFA状況サマリー")
async def get_mfa_summary(
    department: Optional[str] = Query(None),
    session: AsyncSession = Depends(get_async_session)
):
    """MFA状況サマリー取得"""
    
    try:
        base_query = select(MFAStatus)
        if department:
            base_query = base_query.where(MFAStatus.department == department)
        
        # MFA統計
        stats_query = select(
            func.count(MFAStatus.id).label('total_users'),
            func.count(MFAStatus.id).filter(MFAStatus.mfa_status == '有効').label('mfa_enabled'),
            func.count(MFAStatus.id).filter(MFAStatus.mfa_status == '無効').label('mfa_disabled'),
            func.count(MFAStatus.id).filter(MFAStatus.mfa_status == '強制').label('mfa_enforced')
        )
        
        if department:
            stats_query = stats_query.where(MFAStatus.department == department)
        
        result = await session.execute(stats_query)
        stats = result.first()
        
        # 認証方法別統計
        method_query = select(
            MFAStatus.mfa_default_method,
            func.count(MFAStatus.id).label('count')
        ).group_by(MFAStatus.mfa_default_method)
        
        if department:
            method_query = method_query.where(MFAStatus.department == department)
        
        method_result = await session.execute(method_query)
        methods = [
            {
                "method": row[0] or "未設定",
                "user_count": row[1]
            }
            for row in method_result.all()
        ]
        
        # 有効率計算
        total = stats[0] or 1
        enabled_rate = (stats[1] or 0) / total * 100
        
        return {
            "summary": {
                "total_users": stats[0],
                "mfa_enabled": stats[1],
                "mfa_disabled": stats[2],
                "mfa_enforced": stats[3],
                "enabled_rate_percent": round(enabled_rate, 2)
            },
            "by_method": methods,
            "department_filter": department
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"MFAサマリー取得エラー: {str(e)}")


# ========================================
# 条件付きアクセスポリシーAPI
# ========================================

@router.get("/conditional-access",
           response_model=PaginatedResponse,
           summary="条件付きアクセスポリシー一覧")
async def get_conditional_access_policies(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    status: Optional[str] = Query(None, description="ポリシー状態フィルター"),
    session: AsyncSession = Depends(get_async_session)
):
    """条件付きアクセスポリシー一覧取得"""
    
    try:
        query = select(ConditionalAccessPolicy)
        count_query = select(func.count(ConditionalAccessPolicy.id))
        
        if status:
            query = query.where(ConditionalAccessPolicy.status == status)
            count_query = count_query.where(ConditionalAccessPolicy.status == status)
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(ConditionalAccessPolicy.last_updated)).offset(offset).limit(size)
        
        result = await session.execute(query)
        policies = result.scalars().all()
        
        items = [ConditionalAccessPolicyResponse.from_orm(policy) for policy in policies]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"条件付きアクセスポリシー取得エラー: {str(e)}")


# ========================================
# サインインログAPI
# ========================================

@router.get("/signin-logs",
           response_model=PaginatedResponse,
           summary="サインインログ一覧取得")
async def get_signin_logs(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    hours: int = Query(24, ge=1, le=168, description="ログ期間（時間）"),
    status: Optional[str] = Query(None, description="サインイン状態フィルター"),
    risk_level: Optional[str] = Query(None, description="リスクレベルフィルター"),
    user_search: Optional[str] = Query(None, description="ユーザー検索"),
    session: AsyncSession = Depends(get_async_session)
):
    """サインインログ一覧取得"""
    
    try:
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        query = select(SignInLog).where(SignInLog.signin_datetime >= cutoff_time)
        count_query = select(func.count(SignInLog.id)).where(SignInLog.signin_datetime >= cutoff_time)
        
        filters = []
        if status:
            filters.append(SignInLog.status == status)
        if risk_level:
            filters.append(SignInLog.risk_level == risk_level)
        if user_search:
            filters.append(or_(
                SignInLog.user_name.contains(user_search),
                SignInLog.user_principal_name.contains(user_search)
            ))
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        offset = (page - 1) * size
        query = query.order_by(desc(SignInLog.signin_datetime)).offset(offset).limit(size)
        
        result = await session.execute(query)
        logs = result.scalars().all()
        
        items = [SignInLogResponse.from_orm(log) for log in logs]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"サインインログ取得エラー: {str(e)}")


@router.get("/signin-logs/analytics",
           summary="サインインログ分析")
async def get_signin_analytics(
    hours: int = Query(24, ge=1, le=168),
    session: AsyncSession = Depends(get_async_session)
):
    """サインインログ分析"""
    
    try:
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        # サインイン統計
        stats_query = select(
            func.count(SignInLog.id).label('total_signins'),
            func.count(SignInLog.id).filter(SignInLog.status == '成功').label('successful_signins'),
            func.count(SignInLog.id).filter(SignInLog.status == '失敗').label('failed_signins'),
            func.count(func.distinct(SignInLog.user_name)).label('unique_users')
        ).where(SignInLog.signin_datetime >= cutoff_time)
        
        result = await session.execute(stats_query)
        stats = result.first()
        
        # アプリケーション別統計
        app_query = select(
            SignInLog.application,
            func.count(SignInLog.id).label('signin_count')
        ).where(
            SignInLog.signin_datetime >= cutoff_time
        ).group_by(SignInLog.application).order_by(func.count(SignInLog.id).desc()).limit(10)
        
        app_result = await session.execute(app_query)
        top_applications = [
            {
                "application": row[0] or "不明",
                "signin_count": row[1]
            }
            for row in app_result.all()
        ]
        
        # 失敗理由別統計
        error_query = select(
            SignInLog.failure_reason,
            func.count(SignInLog.id).label('error_count')
        ).where(
            and_(
                SignInLog.signin_datetime >= cutoff_time,
                SignInLog.status == '失敗',
                SignInLog.failure_reason.isnot(None)
            )
        ).group_by(SignInLog.failure_reason).order_by(func.count(SignInLog.id).desc()).limit(10)
        
        error_result = await session.execute(error_query)
        failure_reasons = [
            {
                "reason": row[0],
                "count": row[1]
            }
            for row in error_result.all()
        ]
        
        # 成功率計算
        total_signins = stats[0] or 1
        success_rate = (stats[1] or 0) / total_signins * 100
        
        return {
            "period_hours": hours,
            "summary": {
                "total_signins": stats[0],
                "successful_signins": stats[1],
                "failed_signins": stats[2],
                "unique_users": stats[3],
                "success_rate_percent": round(success_rate, 2)
            },
            "top_applications": top_applications,
            "failure_reasons": failure_reasons
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"サインインログ分析エラー: {str(e)}")


# ========================================
# データ同期API
# ========================================

@router.post("/sync/users",
            summary="ユーザーデータ同期",
            description="Microsoft Graph APIからユーザーデータを同期")
async def sync_users_from_graph(
    background_tasks: BackgroundTasks,
    force_full_sync: bool = Query(False, description="完全同期実行"),
    session: AsyncSession = Depends(get_async_session)
):
    """Microsoft Graphからユーザーデータ同期"""
    
    try:
        # バックグラウンドタスクで同期実行
        background_tasks.add_task(
            _sync_users_task,
            force_full_sync
        )
        
        return {
            "message": "ユーザーデータ同期を開始しました",
            "sync_type": "完全同期" if force_full_sync else "差分同期",
            "status": "processing"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ユーザー同期エラー: {str(e)}")


@router.post("/sync/signin-logs",
            summary="サインインログ同期")
async def sync_signin_logs(
    background_tasks: BackgroundTasks,
    hours: int = Query(24, ge=1, le=168, description="同期期間（時間）"),
    session: AsyncSession = Depends(get_async_session)
):
    """サインインログ同期"""
    
    try:
        background_tasks.add_task(
            _sync_signin_logs_task,
            hours
        )
        
        return {
            "message": "サインインログ同期を開始しました",
            "sync_period_hours": hours,
            "status": "processing"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"サインインログ同期エラー: {str(e)}")


# ========================================
# バックグラウンドタスク
# ========================================

async def _sync_users_task(force_full_sync: bool):
    """ユーザーデータ同期タスク"""
    # 実際のMicrosoft Graph API呼び出し実装
    pass


async def _sync_signin_logs_task(hours: int):
    """サインインログ同期タスク"""
    # 実際のMicrosoft Graph API呼び出し実装
    pass