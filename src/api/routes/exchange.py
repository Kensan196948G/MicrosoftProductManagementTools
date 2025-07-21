"""
Exchange Online API Router - Placeholder
Basic structure for Exchange Online management endpoints.
"""

from fastapi import APIRouter, Depends
from typing import Dict, Any
from ..dependencies.advanced_dependencies import require_permissions

router = APIRouter(
    prefix="/exchange",
    tags=["Exchange"],
)

@router.get("/", summary="Get Exchange info")
async def get_exchange_info(
    user: Dict[str, Any] = Depends(require_permissions("users.read"))
):
    """Get Exchange Online information."""
    return {"message": "Exchange Online API - Coming Soon", "status": "placeholder"}