from fastapi import APIRouter
from app.config import settings

router = APIRouter(tags=["ops"])


@router.get("/health")
async def health():
    return {"status": "ok", "version": settings.version}
