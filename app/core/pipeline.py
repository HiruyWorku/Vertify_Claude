"""
Main analysis pipeline.

Data flow:
  Video file
    → MediaPipe pose estimation (per frame)
    → One-Euro filtered CoM + ankle trajectories
    → Jump state machine (GROUND → AIRBORNE → LANDED)
    → Best jump event selected
    → Body proportion scaling → cm / inches
    → Physics cross-check (hang time validation)
    → JumpResult
"""

import logging
from pathlib import Path

from app.core.pose.mediapipe_estimator import MediaPipeEstimator
from app.core.detection.jump_detector import JumpDetector
from app.core.scaling.pixel_to_real import (
    estimate_pixels_per_cm,
    compute_jump_height,
    hang_time_to_height,
)
from app.models.jump import JumpResult
from app.models.pose import PoseFrame
from app.config import settings

logger = logging.getLogger(__name__)


def analyze_jump(video_path: str | Path, user_height_cm: float) -> JumpResult:
    """
    Full synchronous pipeline. Call from a thread pool in async endpoints.
    """
    notes: list[str] = []
    video_path = str(video_path)

    with MediaPipeEstimator(
        model_complexity=settings.pose_model_complexity,
        min_detection_confidence=settings.pose_min_detection_confidence,
        min_tracking_confidence=settings.pose_min_tracking_confidence,
    ) as estimator:
        pose_frames, fps, width, height = estimator.process_video(video_path)

    logger.info(f"Processed {len(pose_frames)} frames at {fps:.1f}fps ({width}×{height})")

    if not pose_frames:
        return JumpResult(jump_detected=False, confidence=0.0, processing_notes=["No frames extracted"])

    # Pose coverage check
    detected = sum(1 for f in pose_frames if f.landmarks)
    coverage = detected / len(pose_frames)
    if coverage < 0.5:
        notes.append(f"Low pose coverage: {coverage:.0%} — consider better lighting/framing")

    # Run jump detector
    detector = JumpDetector(fps=fps, frame_height=height)
    for frame in pose_frames:
        detector.process_frame(frame)

    best = detector.best_jump()

    if best is None:
        return JumpResult(
            jump_detected=False,
            confidence=0.0,
            processing_notes=notes + ["No jump detected — ensure full body is visible and jump is performed"],
        )

    # Gather ground frames for scaling calibration
    ground_frames: list[PoseFrame] = [
        f for f in pose_frames
        if best.takeoff_frame is not None and f.frame_idx < best.takeoff_frame
    ]
    if not ground_frames:
        ground_frames = pose_frames[:min(30, len(pose_frames))]

    pixels_per_cm, scale_confidence = estimate_pixels_per_cm(
        ground_frames, height, user_height_cm
    )

    if pixels_per_cm <= 0:
        notes.append("Could not calibrate scale — defaulting to hang-time estimate")
        hang_time_s = best.hang_time_frames / fps
        height_cm = hang_time_to_height(hang_time_s)
        height_inches = height_cm / 2.54
        confidence = best.confidence * 0.4  # lower confidence for physics-only estimate
    else:
        delta_y = best.ground_com_y - best.peak_com_y
        height_cm, height_inches = compute_jump_height(delta_y, height, pixels_per_cm)

        # Cross-check with hang time
        hang_time_s = best.hang_time_frames / fps
        physics_height_cm = hang_time_to_height(hang_time_s)
        ratio = height_cm / physics_height_cm if physics_height_cm > 0 else 1.0

        if not (0.5 <= ratio <= 2.0):
            notes.append(
                f"Vision height ({height_cm:.1f}cm) vs hang-time ({physics_height_cm:.1f}cm) "
                f"differ significantly — result may be inaccurate"
            )
            # Blend the two estimates, weight by confidence
            blended_cm = height_cm * 0.6 + physics_height_cm * 0.4
            logger.warning(f"Blending estimates: vision={height_cm:.1f}cm hang={physics_height_cm:.1f}cm → {blended_cm:.1f}cm")
            height_cm = blended_cm
            height_inches = height_cm / 2.54

        confidence = best.confidence * (0.7 + 0.3 * scale_confidence)

    hang_time_ms = (best.hang_time_frames / fps) * 1000

    logger.info(
        f"Jump: {height_cm:.1f}cm ({height_inches:.1f}in), "
        f"hang={hang_time_ms:.0f}ms, confidence={confidence:.2f}"
    )

    return JumpResult(
        jump_detected=True,
        jump_height_cm=round(height_cm, 1),
        jump_height_inches=round(height_inches, 1),
        hang_time_ms=round(hang_time_ms, 0),
        takeoff_frame=best.takeoff_frame,
        peak_frame=best.peak_frame,
        landing_frame=best.landing_frame,
        confidence=round(confidence, 2),
        processing_notes=notes,
    )
