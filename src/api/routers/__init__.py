"""
Microsoft 365管理ツール APIルーター
=================================

26機能別REST APIエンドポイント
- 定期レポート (5機能)
- 分析レポート (5機能)
- Entra ID管理 (4機能)
- Exchange Online管理 (4機能)
- Teams管理 (4機能)
- OneDrive管理 (4機能)
"""

from .periodic_reports import router as periodic_reports_router
from .analysis_reports import router as analysis_reports_router
from .entra_id import router as entra_id_router
from .exchange_online import router as exchange_online_router
from .teams import router as teams_router
from .onedrive import router as onedrive_router

__all__ = [
    'periodic_reports_router',
    'analysis_reports_router', 
    'entra_id_router',
    'exchange_online_router',
    'teams_router',
    'onedrive_router'
]