"""
Jump detection state machine.

Algorithm:
  - Track CoM (hip midpoint) and ankle y-positions over time (normalized coords)
  - Screen y: 0 = top, 1 = bottom — so rising = y decreasing
  - States: GROUND → AIRBORNE → LANDED

Ground baseline is established from the first N stable frames.
Liftoff is detected when both ankles rise above baseline by a threshold.
Peak is the frame where smoothed CoM_y is at its minimum.
Landing is when ankles return to within threshold of baseline.

Jump height is computed as:
  delta_y_normalized = ground_com_y - peak_com_y   (positive because screen is inverted)
  delta_y_pixels = delta_y_normalized * frame_height
  jump_height_cm = delta_y_pixels / pixels_per_cm
"""

from collections import deque
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Optional

import numpy as np

from app.models.pose import PoseFrame
from app.core.detection.filters import OneEuroFilter
from app.config import settings


class JumpState(Enum):
    GROUND = auto()
    AIRBORNE = auto()
    LANDED = auto()


@dataclass
class JumpEvent:
    takeoff_frame: int
    peak_frame: int
    landing_frame: int
    ground_com_y: float       # normalized
    peak_com_y: float         # normalized
    ground_ankle_y: float     # normalized baseline
    hang_time_frames: int
    confidence: float


@dataclass
class DetectorState:
    state: JumpState = JumpState.GROUND
    baseline_ankle_ys: deque = field(default_factory=lambda: deque(maxlen=30))
    baseline_com_ys: deque = field(default_factory=lambda: deque(maxlen=30))
    ground_ankle_y: Optional[float] = None
    ground_com_y: Optional[float] = None
    takeoff_frame: Optional[int] = None
    peak_com_y: Optional[float] = None
    peak_frame: Optional[int] = None
    airborne_frames: int = 0


class JumpDetector:
    def __init__(self, fps: float, frame_height: int):
        self.fps = fps
        self.frame_height = frame_height
        self._com_filter = OneEuroFilter(
            freq=fps,
            min_cutoff=settings.smoothing_min_cutoff,
            beta=settings.smoothing_beta,
        )
        self._ankle_filter = OneEuroFilter(
            freq=fps,
            min_cutoff=settings.smoothing_min_cutoff,
            beta=settings.smoothing_beta,
        )
        self._state = DetectorState()
        self._events: list[JumpEvent] = []

    def process_frame(self, frame: PoseFrame) -> JumpState:
        com_y = frame.com_y
        ankle_y = frame.ankle_y

        if com_y is None or ankle_y is None:
            # Missing pose data — stay in current state, don't corrupt baseline
            return self._state.state

        com_y_s = self._com_filter(com_y)
        ankle_y_s = self._ankle_filter(ankle_y)

        s = self._state

        if s.state == JumpState.GROUND:
            # Accumulate baseline
            s.baseline_ankle_ys.append(ankle_y_s)
            s.baseline_com_ys.append(com_y_s)

            if len(s.baseline_ankle_ys) >= 10:
                s.ground_ankle_y = float(np.median(s.baseline_ankle_ys))
                s.ground_com_y = float(np.median(s.baseline_com_ys))

            # Liftoff check: ankle rises above baseline (y decreases)
            if s.ground_ankle_y is not None:
                rise_px = (s.ground_ankle_y - ankle_y_s) * self.frame_height
                if rise_px > settings.liftoff_ankle_rise_px:
                    s.state = JumpState.AIRBORNE
                    s.takeoff_frame = frame.frame_idx
                    s.peak_com_y = com_y_s
                    s.peak_frame = frame.frame_idx
                    s.airborne_frames = 1

        elif s.state == JumpState.AIRBORNE:
            s.airborne_frames += 1

            # Track peak (minimum y = highest point)
            if com_y_s < s.peak_com_y:
                s.peak_com_y = com_y_s
                s.peak_frame = frame.frame_idx

            # Landing check: ankles return near baseline
            if s.ground_ankle_y is not None:
                rise_px = (s.ground_ankle_y - ankle_y_s) * self.frame_height
                if rise_px < settings.landing_ankle_threshold_px:
                    if s.airborne_frames >= settings.min_jump_frames:
                        confidence = self._compute_confidence(frame, s)
                        event = JumpEvent(
                            takeoff_frame=s.takeoff_frame,
                            peak_frame=s.peak_frame,
                            landing_frame=frame.frame_idx,
                            ground_com_y=s.ground_com_y,
                            peak_com_y=s.peak_com_y,
                            ground_ankle_y=s.ground_ankle_y,
                            hang_time_frames=s.airborne_frames,
                            confidence=confidence,
                        )
                        self._events.append(event)
                    # Reset for next jump
                    s.state = JumpState.GROUND
                    s.airborne_frames = 0
                    # Carry current ankle position as new baseline seed
                    s.baseline_ankle_ys.clear()
                    s.baseline_com_ys.clear()
                    s.baseline_ankle_ys.append(ankle_y_s)
                    s.baseline_com_ys.append(com_y_s)
                    s.ground_ankle_y = ankle_y_s
                    s.ground_com_y = com_y_s

        return s.state

    def _compute_confidence(self, frame: PoseFrame, s: DetectorState) -> float:
        """
        Confidence heuristic based on:
        - Visibility of key landmarks
        - Consistency of the jump arc (peak was clearly above baseline)
        """
        scores = []

        # Landmark visibility
        for kp in [frame.left_hip, frame.right_hip, frame.left_ankle, frame.right_ankle]:
            if kp:
                scores.append(kp.visibility)

        vis_score = float(np.mean(scores)) if scores else 0.3

        # Arc quality: did the CoM actually rise meaningfully?
        delta_y_normalized = s.ground_com_y - s.peak_com_y
        delta_px = delta_y_normalized * self.frame_height
        arc_score = min(1.0, delta_px / 50.0)  # normalize: 50px = full confidence

        # Hang time plausibility (between 10–80 frames at 30fps ≈ 0.33–2.67s)
        expected_min = 0.2 * self.fps
        expected_max = 3.0 * self.fps
        hang_ok = expected_min <= s.airborne_frames <= expected_max
        hang_score = 1.0 if hang_ok else 0.5

        return float(vis_score * 0.3 + arc_score * 0.5 + hang_score * 0.2)

    @property
    def events(self) -> list[JumpEvent]:
        return self._events

    def best_jump(self) -> Optional[JumpEvent]:
        if not self._events:
            return None
        return max(self._events, key=lambda e: (e.ground_com_y - e.peak_com_y))
