"""
Microsoft 365管理ツール 定期レポートAPI
===================================

定期レポート機能 REST API実装 (5機能)
- 日次セキュリティレポート
- 週次・月次・年次統合レポート  
- テスト実行結果
"""

from datetime import date, datetime, timedelta
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, and_, or_
from pydantic import BaseModel, Field

from ...database.connection import get_async_session
from ...database.models import (
    DailySecurityReport, PeriodicSummaryReport, TestExecutionResult
)

router = APIRouter(prefix="/periodic-reports", tags=["定期レポート"])


# ========================================
# Pydanticモデル（リクエスト・レスポンス）
# ========================================

class DailySecurityReportResponse(BaseModel):
    """日次セキュリティレポートレスポンス"""
    id: int
    report_date: date
    user_name: str
    email: str
    account_creation_date: Optional[date]
    last_password_change: Optional[date]
    days_since_password_change: Optional[int]
    activity_status: Optional[str]
    security_risk: Optional[str]
    recommended_action: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


class PeriodicSummaryReportResponse(BaseModel):
    """定期サマリーレポートレスポンス"""
    id: int
    report_type: str
    report_date: date
    period_start: date
    period_end: date
    active_users_count: int
    total_activity_count: int
    service_performance_score: Optional[float]
    created_at: datetime
    
    class Config:
        from_attributes = True


class TestExecutionResultResponse(BaseModel):
    """テスト実行結果レスポンス"""
    id: int
    test_id: str
    test_name: str
    category: Optional[str]
    execution_status: Optional[str]
    result: Optional[str]
    error_message: Optional[str]
    execution_time_ms: Optional[int]
    test_date: datetime
    
    class Config:
        from_attributes = True


class PaginatedResponse(BaseModel):
    """ページネーションレスポンス"""
    items: List[Any]
    total: int
    page: int
    size: int
    pages: int


class ReportGenerationRequest(BaseModel):
    """レポート生成リクエスト"""
    report_type: str = Field(..., description="レポート種別")
    start_date: Optional[date] = Field(None, description="開始日")
    end_date: Optional[date] = Field(None, description="終了日")
    departments: Optional[List[str]] = Field(None, description="対象部署")
    include_inactive: bool = Field(False, description="非アクティブユーザー含む")


# ========================================
# 日次セキュリティレポートAPI
# ========================================

@router.get("/daily-security", 
           response_model=PaginatedResponse,
           summary="日次セキュリティレポート一覧",
           description="日次セキュリティレポートデータを取得（PowerShell DailyReport互換）")
async def get_daily_security_reports(
    page: int = Query(1, ge=1, description="ページ番号"),
    size: int = Query(50, ge=1, le=1000, description="ページサイズ"),
    start_date: Optional[date] = Query(None, description="開始日"),
    end_date: Optional[date] = Query(None, description="終了日"),
    risk_level: Optional[str] = Query(None, description="リスクレベルフィルター"),
    department: Optional[str] = Query(None, description="部署フィルター"),
    session: AsyncSession = Depends(get_async_session)
):
    """日次セキュリティレポート一覧取得"""
    
    try:
        # ベースクエリ作成
        query = select(DailySecurityReport)
        count_query = select(func.count(DailySecurityReport.id))
        
        # フィルター適用
        filters = []
        
        if start_date:
            filters.append(DailySecurityReport.report_date >= start_date)
        if end_date:
            filters.append(DailySecurityReport.report_date <= end_date)
        if risk_level:
            filters.append(DailySecurityReport.security_risk == risk_level)
        if department:
            filters.append(DailySecurityReport.user_name.contains(department))
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        # 総件数取得
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        # ページネーション適用
        offset = (page - 1) * size
        query = query.order_by(desc(DailySecurityReport.report_date)).offset(offset).limit(size)
        
        # データ取得
        result = await session.execute(query)
        reports = result.scalars().all()
        
        # レスポンス形式に変換
        items = [DailySecurityReportResponse.from_orm(report) for report in reports]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"日次セキュリティレポート取得エラー: {str(e)}")


@router.get("/daily-security/{report_id}",
           response_model=DailySecurityReportResponse,
           summary="日次セキュリティレポート詳細")
async def get_daily_security_report(
    report_id: int,
    session: AsyncSession = Depends(get_async_session)
):
    """個別日次セキュリティレポート取得"""
    
    try:
        query = select(DailySecurityReport).where(DailySecurityReport.id == report_id)
        result = await session.execute(query)
        report = result.scalar_one_or_none()
        
        if not report:
            raise HTTPException(status_code=404, detail="レポートが見つかりません")
        
        return DailySecurityReportResponse.from_orm(report)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"レポート取得エラー: {str(e)}")


@router.post("/daily-security/generate",
            summary="日次セキュリティレポート生成",
            description="日次セキュリティレポートをバックグラウンドで生成")
async def generate_daily_security_report(
    request: ReportGenerationRequest,
    background_tasks: BackgroundTasks,
    session: AsyncSession = Depends(get_async_session)
):
    """日次セキュリティレポート生成"""
    
    try:
        # バックグラウンドタスクでレポート生成
        background_tasks.add_task(
            _generate_daily_security_report_task,
            request.start_date or date.today(),
            request.departments,
            request.include_inactive
        )
        
        return {
            "message": "日次セキュリティレポート生成を開始しました",
            "status": "processing",
            "estimated_time": "2-5分"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"レポート生成エラー: {str(e)}")


# ========================================
# 定期サマリーレポートAPI
# ========================================

@router.get("/summary/{report_type}",
           response_model=PaginatedResponse,
           summary="定期サマリーレポート一覧")
async def get_periodic_summary_reports(
    report_type: str = Query(..., description="レポート種別（週次/月次/年次）"),
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    session: AsyncSession = Depends(get_async_session)
):
    """定期サマリーレポート一覧取得"""
    
    try:
        # ベースクエリ
        query = select(PeriodicSummaryReport).where(
            PeriodicSummaryReport.report_type == report_type
        )
        count_query = select(func.count(PeriodicSummaryReport.id)).where(
            PeriodicSummaryReport.report_type == report_type
        )
        
        # 日付フィルター
        filters = []
        if start_date:
            filters.append(PeriodicSummaryReport.period_start >= start_date)
        if end_date:
            filters.append(PeriodicSummaryReport.period_end <= end_date)
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        # 総件数
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        # ページネーション
        offset = (page - 1) * size
        query = query.order_by(desc(PeriodicSummaryReport.period_end)).offset(offset).limit(size)
        
        result = await session.execute(query)
        reports = result.scalars().all()
        
        items = [PeriodicSummaryReportResponse.from_orm(report) for report in reports]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"サマリーレポート取得エラー: {str(e)}")


@router.get("/summary/statistics/{report_type}",
           summary="定期レポート統計情報")
async def get_report_statistics(
    report_type: str,
    period_months: int = Query(12, ge=1, le=36, description="統計期間（月数）"),
    session: AsyncSession = Depends(get_async_session)
):
    """定期レポート統計情報取得"""
    
    try:
        cutoff_date = date.today() - timedelta(days=period_months * 30)
        
        # 統計クエリ
        stats_query = select(
            func.count(PeriodicSummaryReport.id).label('total_reports'),
            func.avg(PeriodicSummaryReport.active_users_count).label('avg_users'),
            func.max(PeriodicSummaryReport.active_users_count).label('max_users'),
            func.avg(PeriodicSummaryReport.service_performance_score).label('avg_performance')
        ).where(
            and_(
                PeriodicSummaryReport.report_type == report_type,
                PeriodicSummaryReport.period_start >= cutoff_date
            )
        )
        
        result = await session.execute(stats_query)
        stats = result.first()
        
        # トレンドデータ
        trend_query = select(
            PeriodicSummaryReport.period_end,
            PeriodicSummaryReport.active_users_count,
            PeriodicSummaryReport.service_performance_score
        ).where(
            and_(
                PeriodicSummaryReport.report_type == report_type,
                PeriodicSummaryReport.period_start >= cutoff_date
            )
        ).order_by(PeriodicSummaryReport.period_end)
        
        trend_result = await session.execute(trend_query)
        trend_data = [
            {
                "date": row[0].isoformat(),
                "users": row[1],
                "performance": float(row[2]) if row[2] else None
            }
            for row in trend_result.all()
        ]
        
        return {
            "report_type": report_type,
            "period_months": period_months,
            "statistics": {
                "total_reports": stats[0],
                "average_users": float(stats[1]) if stats[1] else 0,
                "max_users": stats[2] or 0,
                "average_performance": float(stats[3]) if stats[3] else 0
            },
            "trend_data": trend_data
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"統計情報取得エラー: {str(e)}")


# ========================================
# テスト実行結果API
# ========================================

@router.get("/test-results",
           response_model=PaginatedResponse,
           summary="テスト実行結果一覧")
async def get_test_execution_results(
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=1000),
    category: Optional[str] = Query(None, description="テストカテゴリ"),
    status: Optional[str] = Query(None, description="実行ステータス"),
    session: AsyncSession = Depends(get_async_session)
):
    """テスト実行結果一覧取得"""
    
    try:
        query = select(TestExecutionResult)
        count_query = select(func.count(TestExecutionResult.id))
        
        filters = []
        if category:
            filters.append(TestExecutionResult.category == category)
        if status:
            filters.append(TestExecutionResult.execution_status == status)
        
        if filters:
            query = query.where(and_(*filters))
            count_query = count_query.where(and_(*filters))
        
        # 総件数
        total_result = await session.execute(count_query)
        total = total_result.scalar()
        
        # ページネーション
        offset = (page - 1) * size
        query = query.order_by(desc(TestExecutionResult.test_date)).offset(offset).limit(size)
        
        result = await session.execute(query)
        tests = result.scalars().all()
        
        items = [TestExecutionResultResponse.from_orm(test) for test in tests]
        
        return PaginatedResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=(total + size - 1) // size
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"テスト結果取得エラー: {str(e)}")


@router.post("/test-results/execute",
            summary="テスト実行",
            description="システムテストを実行し結果を記録")
async def execute_system_test(
    test_categories: List[str] = Query(["基本機能"], description="実行するテストカテゴリ"),
    background_tasks: BackgroundTasks,
    session: AsyncSession = Depends(get_async_session)
):
    """システムテスト実行"""
    
    try:
        # バックグラウンドでテスト実行
        background_tasks.add_task(
            _execute_system_test_task,
            test_categories
        )
        
        return {
            "message": "システムテスト実行を開始しました",
            "test_categories": test_categories,
            "status": "processing"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"テスト実行エラー: {str(e)}")


# ========================================
# バックグラウンドタスク
# ========================================

async def _generate_daily_security_report_task(
    target_date: date,
    departments: Optional[List[str]],
    include_inactive: bool
):
    """日次セキュリティレポート生成タスク"""
    # 実際の実装ではMicrosoft Graphからデータ取得し、レポート生成
    # ここでは処理の骨格のみ
    pass


async def _execute_system_test_task(test_categories: List[str]):
    """システムテスト実行タスク"""
    # 実際のテスト実行ロジック
    pass