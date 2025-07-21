"""
OneDrive API Router - Placeholder  
Basic structure for OneDrive management endpoints.
"""

from fastapi import APIRouter, Depends
from typing import Dict, Any
from ..dependencies.advanced_dependencies import require_permissions

router = APIRouter(
    prefix="/onedrive",
    tags=["OneDrive"],
)

@router.get("/", summary="Get OneDrive info")
async def get_onedrive_info(
    user: Dict[str, Any] = Depends(require_permissions("users.read"))
):
    """Get OneDrive information."""
    return {"message": "OneDrive API - Coming Soon", "status": "placeholder"}