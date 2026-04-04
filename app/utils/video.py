"""
Video validation and preprocessing utilities.
"""

import os
import uuid
from pathlib import Path

import aiofiles
from fastapi import UploadFile, HTTPException

from app.config import settings

ALLOWED_CONTENT_TYPES = {
    "video/mp4",
    "video/quicktime",   # .mov (iOS default)
    "video/x-msvideo",   # .avi
    "video/webm",
}


async def save_upload(upload: UploadFile, dest_dir: Path) -> Path:
    """Save an uploaded video to disk, returning the saved path."""
    content_type = upload.content_type or ""
    if content_type not in ALLOWED_CONTENT_TYPES:
        # Try extension fallback (some clients send wrong MIME)
        ext = Path(upload.filename or "").suffix.lower()
        if ext not in {".mp4", ".mov", ".avi", ".webm"}:
            raise HTTPException(400, f"Unsupported video format: {content_type}")

    job_id = uuid.uuid4().hex
    ext = Path(upload.filename or "video.mp4").suffix or ".mp4"
    dest = dest_dir / f"{job_id}{ext}"
    dest_dir.mkdir(parents=True, exist_ok=True)

    async with aiofiles.open(dest, "wb") as out:
        # Stream in 1MB chunks — avoid loading full video into memory
        while chunk := await upload.read(1024 * 1024):
            size_mb = dest.stat().st_size / (1024 * 1024) if dest.exists() else 0
            if size_mb > settings.max_video_size_mb:
                dest.unlink(missing_ok=True)
                raise HTTPException(413, f"Video exceeds {settings.max_video_size_mb}MB limit")
            await out.write(chunk)

    return dest, job_id


def cleanup_video(path: Path) -> None:
    try:
        path.unlink(missing_ok=True)
    except OSError:
        pass
