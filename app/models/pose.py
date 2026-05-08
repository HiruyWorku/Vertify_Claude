from dataclasses import dataclass, field
from typing import Optional


# MediaPipe Pose landmark indices we care about
class LandmarkIndex:
    NOSE = 0
    LEFT_SHOULDER = 11
    RIGHT_SHOULDER = 12
    LEFT_HIP = 23
    RIGHT_HIP = 24
    LEFT_KNEE = 25
    RIGHT_KNEE = 26
    LEFT_ANKLE = 27
    RIGHT_ANKLE = 28
    LEFT_HEEL = 29
    RIGHT_HEEL = 30
    LEFT_FOOT_INDEX = 31
    RIGHT_FOOT_INDEX = 32


@dataclass
class Keypoint:
    x: float          # normalized [0,1]
    y: float          # normalized [0,1], 0=top
    z: float          # depth (relative)
    visibility: float # confidence [0,1]


@dataclass
class PoseFrame:
    frame_idx: int
    timestamp_ms: float
    landmarks: dict[int, Keypoint] = field(default_factory=dict)

    @property
    def left_hip(self) -> Optional[Keypoint]:
        return self.landmarks.get(LandmarkIndex.LEFT_HIP)

    @property
    def right_hip(self) -> Optional[Keypoint]:
        return self.landmarks.get(LandmarkIndex.RIGHT_HIP)

    @property
    def left_ankle(self) -> Optional[Keypoint]:
        return self.landmarks.get(LandmarkIndex.LEFT_ANKLE)

    @property
    def right_ankle(self) -> Optional[Keypoint]:
        return self.landmarks.get(LandmarkIndex.RIGHT_ANKLE)

    @property
    def com_y(self) -> Optional[float]:
        """Center of mass proxy: average of both hips (normalized y)."""
        lh = self.left_hip
        rh = self.right_hip
        if lh and rh and lh.visibility > 0.3 and rh.visibility > 0.3:
            return (lh.y + rh.y) / 2
        if lh and lh.visibility > 0.3:
            return lh.y
        if rh and rh.visibility > 0.3:
            return rh.y
        return None

    @property
    def ankle_y(self) -> Optional[float]:
        """Average visible ankle y (normalized)."""
        la = self.left_ankle
        ra = self.right_ankle
        ys = [
            kp.y for kp in [la, ra]
            if kp and kp.visibility > 0.3
        ]
        return sum(ys) / len(ys) if ys else None
