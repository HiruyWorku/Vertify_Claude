"""Unit tests for pixel-to-real scaling."""

import pytest
from app.models.pose import PoseFrame, Keypoint, LandmarkIndex
from app.core.scaling.pixel_to_real import (
    estimate_pixels_per_cm,
    compute_jump_height,
    hang_time_to_height,
)


def make_standing_frame(idx: int, hip_y: float, ankle_y: float) -> PoseFrame:
    f = PoseFrame(frame_idx=idx, timestamp_ms=0)
    for lm_idx in [LandmarkIndex.LEFT_HIP, LandmarkIndex.RIGHT_HIP]:
        f.landmarks[lm_idx] = Keypoint(x=0.5, y=hip_y, z=0, visibility=0.95)
    for lm_idx in [LandmarkIndex.LEFT_ANKLE, LandmarkIndex.RIGHT_ANKLE]:
        f.landmarks[lm_idx] = Keypoint(x=0.5, y=ankle_y, z=0, visibility=0.95)
    return f


def test_pixels_per_cm_reasonable():
    """
    Frame height = 1080px.
    Person 180cm tall. Leg = 180 * 0.47 = 84.6cm.
    Simulate hip_y=0.45, ankle_y=0.85 → 0.4 * 1080 = 432px leg length.
    Expected pixels_per_cm ≈ 432 / 84.6 ≈ 5.1
    """
    frames = [make_standing_frame(i, hip_y=0.45, ankle_y=0.85) for i in range(20)]
    ppc, conf = estimate_pixels_per_cm(frames, frame_height=1080, user_height_cm=180.0)
    assert 4.5 <= ppc <= 5.8
    assert conf > 0.8


def test_jump_height_calculation():
    # 50px jump on 5.0 pixels/cm → 10cm
    height_cm, height_in = compute_jump_height(
        delta_y_normalized=50 / 1080,
        frame_height=1080,
        pixels_per_cm=5.0,
    )
    assert abs(height_cm - 10.0) < 0.1
    assert abs(height_in - 3.94) < 0.1


def test_hang_time_physics():
    """A 0.8s hang time should give ~78.5cm jump (physics: h = g*t²/8)."""
    h = hang_time_to_height(0.8)
    assert 70 <= h <= 90
