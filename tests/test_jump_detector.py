"""Unit tests for jump detector state machine."""

import pytest
from app.models.pose import PoseFrame, Keypoint, LandmarkIndex
from app.core.detection.jump_detector import JumpDetector, JumpState


def make_frame(idx: int, com_y: float, ankle_y: float, visibility: float = 0.95) -> PoseFrame:
    """Helper: create a PoseFrame with synthetic hip/ankle keypoints."""
    f = PoseFrame(frame_idx=idx, timestamp_ms=idx * (1000 / 30))
    f.landmarks[LandmarkIndex.LEFT_HIP] = Keypoint(x=0.5, y=com_y, z=0, visibility=visibility)
    f.landmarks[LandmarkIndex.RIGHT_HIP] = Keypoint(x=0.5, y=com_y, z=0, visibility=visibility)
    f.landmarks[LandmarkIndex.LEFT_ANKLE] = Keypoint(x=0.5, y=ankle_y, z=0, visibility=visibility)
    f.landmarks[LandmarkIndex.RIGHT_ANKLE] = Keypoint(x=0.5, y=ankle_y, z=0, visibility=visibility)
    return f


def simulate_jump(
    fps: float = 30.0,
    frame_height: int = 1080,
    ground_frames: int = 30,
    air_frames: int = 25,
    peak_rise: float = 0.15,  # normalized y
) -> list[PoseFrame]:
    """
    Simulate a jump sequence:
      - ground_frames at y=0.7 (com) / y=0.9 (ankle)
      - rises to y=0.55 at peak
      - returns to ground
    """
    frames = []
    idx = 0
    base_com = 0.70
    base_ankle = 0.90

    # Ground phase
    for _ in range(ground_frames):
        frames.append(make_frame(idx, base_com, base_ankle))
        idx += 1

    # Airborne phase: parabolic arc
    for i in range(air_frames):
        t = i / air_frames
        # parabola: peak at t=0.5
        arc = peak_rise * 4 * t * (1 - t)
        com_y = base_com - arc
        ankle_y = base_ankle - arc
        frames.append(make_frame(idx, com_y, ankle_y))
        idx += 1

    # Landing + post
    for _ in range(ground_frames):
        frames.append(make_frame(idx, base_com, base_ankle))
        idx += 1

    return frames


def test_detects_simulated_jump():
    frames = simulate_jump(fps=30.0, frame_height=1080, air_frames=25, peak_rise=0.12)
    detector = JumpDetector(fps=30.0, frame_height=1080)
    for f in frames:
        detector.process_frame(f)

    assert len(detector.events) == 1
    event = detector.events[0]
    assert event.takeoff_frame is not None
    assert event.peak_frame > event.takeoff_frame
    assert event.landing_frame > event.peak_frame
    assert event.confidence > 0.3


def test_no_jump_detected_on_static_sequence():
    frames = [make_frame(i, 0.70, 0.90) for i in range(60)]
    detector = JumpDetector(fps=30.0, frame_height=1080)
    for f in frames:
        detector.process_frame(f)
    assert len(detector.events) == 0


def test_ignores_micro_blip():
    """A 2-frame blip should not register as a jump."""
    frames = simulate_jump(fps=30.0, frame_height=1080, air_frames=3, peak_rise=0.10)
    detector = JumpDetector(fps=30.0, frame_height=1080)
    for f in frames:
        detector.process_frame(f)
    assert len(detector.events) == 0
