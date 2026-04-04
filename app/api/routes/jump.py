"""
Jump analysis endpoints.

POST /analyze    — upload video + height, get synchronous result
                   (fine for MVP; swap for async job queue in production)

Design decision: sync for MVP.
  - Typical video: 10s @ 30fps = 300 frames, ~2–4s processing on CPU
  - FastAPI runs this in a thread pool via run_in_executor so the event
    loop is never blocked
  - When we need async (large queues, long videos), add Celery + Redis
    without changing the public API contract
"""

import asyncio
import logging
from pathlib import Path
from functools import partial

from fastapi import APIRouter, File, Form, UploadFile, HTTPException, BackgroundTasks

from app.core.pipeline import analyze_jump
from app.models.jump import AnalysisResponse
from app.utils.video import save_upload, cleanup_video
from app.config import settings

router = APIRouter(prefix="/jump", tags=["jump"])
logger = logging.getLogger(__name__)


@router.post("/analyze", response_model=AnalysisResponse)
async def analyze_jump_endpoint(
    background_tasks: BackgroundTasks,
    video: UploadFile = File(..., description="Video of the jump (mp4/mov, max 200MB)"),
    user_height_cm: float = Form(..., gt=100, lt=250, description="User standing height in cm"),
):
    """
    Upload a jump video and receive the measured jump height.

    - **video**: MP4 or MOV, full body visible, camera stationary
    - **user_height_cm**: standing height for pixel-to-real scaling
    """
    upload_dir = settings.upload_dir
    video_path, job_id = await save_upload(video, upload_dir)

    # Schedule cleanup regardless of outcome
    background_tasks.add_task(cleanup_video, video_path)

    try:
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(
            None,
            partial(analyze_jump, video_path, user_height_cm),
        )
    except Exception as exc:
        logger.exception(f"Pipeline error for job {job_id}")
        raise HTTPException(500, f"Analysis failed: {exc}") from exc

    return AnalysisResponse(
        job_id=job_id,
        status="completed",
        result=result,
    )
