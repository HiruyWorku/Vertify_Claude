from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum


class JumpPhase(str, Enum):
    GROUND = "ground"
    LIFTOFF = "liftoff"
    AIRBORNE = "airborne"
    LANDED = "landed"


class JumpResult(BaseModel):
    jump_detected: bool
    jump_height_cm: Optional[float] = None
    jump_height_inches: Optional[float] = None
    hang_time_ms: Optional[float] = None
    takeoff_frame: Optional[int] = None
    peak_frame: Optional[int] = None
    landing_frame: Optional[int] = None
    confidence: float = Field(ge=0.0, le=1.0)
    processing_notes: list[str] = []


class AnalysisRequest(BaseModel):
    user_height_cm: float = Field(gt=100, lt=250, description="Standing height in cm")
    unit: str = Field(default="cm", pattern="^(cm|inches)$")


class AnalysisResponse(BaseModel):
    job_id: str
    status: str
    result: Optional[JumpResult] = None
    error: Optional[str] = None
