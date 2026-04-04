"""
MediaPipe Pose estimator wrapper.

Why MediaPipe over MoveNet for the backend:
- 33 landmarks (vs MoveNet's 17) — full foot/ankle detail
- Z-depth estimate useful for perspective correction
- Segmentation mask available for future green-screen replay feature
- Runs efficiently on CPU for server-side batch processing

For on-device (Flutter), the mobile team should use google_ml_kit which
wraps the same MediaPipe model. This ensures parity between on-device
and server results.
"""

import mediapipe as mp
import cv2
import numpy as np
from typing import Iterator

from app.models.pose import PoseFrame, Keypoint
from app.config import settings


class MediaPipeEstimator:
    def __init__(
        self,
        model_complexity: int = 1,
        min_detection_confidence: float = 0.5,
        min_tracking_confidence: float = 0.5,
    ):
        self._mp_pose = mp.solutions.pose
        self._pose = self._mp_pose.Pose(
            static_image_mode=False,
            model_complexity=model_complexity,
            enable_segmentation=False,
            min_detection_confidence=min_detection_confidence,
            min_tracking_confidence=min_tracking_confidence,
        )

    def process_video(self, video_path: str) -> tuple[list[PoseFrame], float, int, int]:
        """
        Process a video file and return (frames, fps, width, height).
        Frames with no detected pose are included with empty landmarks.
        """
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            raise ValueError(f"Cannot open video: {video_path}")

        fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

        frames: list[PoseFrame] = []
        frame_idx = 0

        sample_rate = settings.frame_sample_rate
        raw_idx = 0

        while True:
            ret, bgr = cap.read()
            if not ret:
                break

            # Skip frames to hit target processing rate
            if raw_idx % sample_rate != 0:
                raw_idx += 1
                continue

            timestamp_ms = cap.get(cv2.CAP_PROP_POS_MSEC)
            rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            results = self._pose.process(rgb)

            pose_frame = PoseFrame(frame_idx=frame_idx, timestamp_ms=timestamp_ms)

            if results.pose_landmarks:
                for idx, lm in enumerate(results.pose_landmarks.landmark):
                    pose_frame.landmarks[idx] = Keypoint(
                        x=lm.x,
                        y=lm.y,
                        z=lm.z,
                        visibility=lm.visibility,
                    )

            frames.append(pose_frame)
            frame_idx += 1
            raw_idx += 1

        cap.release()
        return frames, fps, width, height

    def close(self) -> None:
        self._pose.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()
