from pydantic_settings import BaseSettings
from pathlib import Path


class Settings(BaseSettings):
    app_name: str = "Jumpology API"
    version: str = "0.1.0"
    debug: bool = False

    upload_dir: Path = Path("uploads")
    max_video_size_mb: int = 200
    max_video_duration_s: int = 30

    # Pose estimation
    pose_model_complexity: int = 1        # 0=lite, 1=full, 2=heavy
    pose_min_detection_confidence: float = 0.5
    pose_min_tracking_confidence: float = 0.5

    # Jump detection thresholds
    liftoff_ankle_rise_px: float = 15.0   # px above baseline to declare liftoff
    landing_ankle_threshold_px: float = 20.0
    min_jump_frames: int = 8              # ignore sub-8-frame blips (~267ms at 30fps)
    smoothing_min_cutoff: float = 1.0     # One-Euro filter params
    smoothing_beta: float = 0.007

    # Performance — skip frames to speed up processing
    frame_sample_rate: int = 2           # process every Nth frame (2 = 15fps at 30fps input)

    # Scaling — anthropometric constants
    leg_to_height_ratio: float = 0.47    # lower limb ≈ 47% of standing height

    class Config:
        env_file = ".env"


settings = Settings()
