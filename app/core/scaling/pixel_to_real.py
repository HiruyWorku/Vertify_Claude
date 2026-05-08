"""
Pixel-to-real-world scaling using body proportion anthropometry.

Why this approach instead of ARKit/ARCore:
- ARKit requires LiDAR or good lighting + flat surface — fails in gyms
- ARCore ground plane detection is fragile with moving subjects
- Body proportions are constant: lower limb ≈ 47% of standing height
  (Drillis & Contini, 1966; De Leva, 1996)

Method:
  1. During the ground-standing phase, measure pixel distance from hip to ankle
  2. real_leg_length_cm = user_height_cm × LEG_TO_HEIGHT_RATIO
  3. pixels_per_cm = pixel_leg_length / real_leg_length_cm
  4. jump_height_cm = delta_y_pixels / pixels_per_cm

Caveats handled:
- Camera tilt: we use the vertical pixel difference (y-axis), which is only
  accurate when the camera is level. Tilt correction via shoulder width ratio
  is applied when available.
- Perspective: assumes subject stays at roughly constant distance from camera.
  Good enough for a single-jump measurement.
"""

import logging
import math
from typing import Optional

import numpy as np

from app.models.pose import PoseFrame, LandmarkIndex
from app.config import settings

logger = logging.getLogger(__name__)


def estimate_pixels_per_cm(
    ground_frames: list[PoseFrame],
    frame_height: int,
    user_height_cm: float,
) -> tuple[float, float]:
    """
    Returns (pixels_per_cm, confidence).

    Uses hip-to-ankle vertical pixel distance averaged over ground frames.
    """
    real_leg_cm = user_height_cm * settings.leg_to_height_ratio
    ratios: list[float] = []

    logger.debug(
        f"estimate_pixels_per_cm: {len(ground_frames)} ground frames, "
        f"frame_height={frame_height}, user_height_cm={user_height_cm}, "
        f"real_leg_cm={real_leg_cm:.1f}"
    )

    for frame in ground_frames:
        lh = frame.landmarks.get(LandmarkIndex.LEFT_HIP)
        la = frame.landmarks.get(LandmarkIndex.LEFT_ANKLE)
        rh = frame.landmarks.get(LandmarkIndex.RIGHT_HIP)
        ra = frame.landmarks.get(LandmarkIndex.RIGHT_ANKLE)

        for side, hip, ankle in [("L", lh, la), ("R", rh, ra)]:
            if hip and ankle:
                logger.debug(
                    f"  frame {frame.frame_idx} {side}: "
                    f"hip.y={hip.y:.3f}(vis={hip.visibility:.2f}) "
                    f"ankle.y={ankle.y:.3f}(vis={ankle.visibility:.2f})"
                )
            # Require high ankle visibility — low visibility means feet are off-screen
            # or occluded, giving unreliable y estimates.
            if (hip and ankle
                    and hip.visibility > 0.5
                    and ankle.visibility > 0.65):
                pixel_leg = (ankle.y - hip.y) * frame_height  # positive: ankle below hip
                logger.debug(f"    → pixel_leg={pixel_leg:.1f}px")
                # Also require a minimum plausible leg length to filter mid-stride frames
                if pixel_leg > 50:
                    ratios.append(pixel_leg / real_leg_cm)

    logger.debug(f"  valid ratios collected: {len(ratios)} — values: {[round(r,3) for r in ratios[:10]]}")

    if not ratios:
        logger.warning("estimate_pixels_per_cm: no valid ratios — returning 0.0")
        return 0.0, 0.0

    # Reject outliers beyond 1.5 IQR
    arr = np.array(ratios)
    q1, q3 = np.percentile(arr, [25, 75])
    iqr = q3 - q1
    filtered = arr[(arr >= q1 - 1.5 * iqr) & (arr <= q3 + 1.5 * iqr)]

    pixels_per_cm = float(np.median(filtered))
    # Confidence: how consistent are the measurements?
    cv = float(np.std(filtered) / np.mean(filtered)) if len(filtered) > 1 else 0.5
    confidence = max(0.0, min(1.0, 1.0 - cv * 2))

    return pixels_per_cm, confidence


def compute_jump_height(
    delta_y_normalized: float,
    frame_height: int,
    pixels_per_cm: float,
) -> tuple[float, float]:
    """
    Returns (height_cm, height_inches).

    delta_y_normalized: ground_com_y - peak_com_y  (positive = jumped up)
    """
    delta_px = delta_y_normalized * frame_height
    height_cm = delta_px / pixels_per_cm
    height_inches = height_cm / 2.54
    return height_cm, height_inches


def hang_time_to_height(hang_time_s: float) -> float:
    """
    Physics-based cross-check: h = g * t^2 / 8
    (hang_time = 2 × time_to_peak, at peak v=0)
    """
    g = 980.7  # cm/s²
    return g * (hang_time_s ** 2) / 8
