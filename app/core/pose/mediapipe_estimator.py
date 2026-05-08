"""
MediaPipe Pose estimator using the Tasks API (mediapipe >= 0.10).

Uses PoseLandmarker in VIDEO running mode, which shares tracking state
across frames for better temporal consistency than per-image detection.
"""

import cv2
from pathlib import Path

import mediapipe as mp
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision as mp_vision

from app.models.pose import PoseFrame, Keypoint
from app.config import settings

_DEFAULT_MODEL = Path(__file__).parent.parent.parent.parent / "models" / "pose_landmarker_full.task"


class MediaPipeEstimator:
    def __init__(
        self,
        model_complexity: int = 1,
        min_detection_confidence: float = 0.5,
        min_tracking_confidence: float = 0.5,
        model_path: str | Path | None = None,
    ):
        model_path = Path(model_path) if model_path else _DEFAULT_MODEL
        if not model_path.exists():
            raise FileNotFoundError(
                f"Mediapipe model not found at {model_path}. "
                "Download it with: python scripts/download_model.py"
            )

        base_options = mp_python.BaseOptions(model_asset_path=str(model_path))
        options = mp_vision.PoseLandmarkerOptions(
            base_options=base_options,
            running_mode=mp_vision.RunningMode.VIDEO,
            num_poses=1,
            min_pose_detection_confidence=min_detection_confidence,
            min_pose_presence_confidence=min_detection_confidence,
            min_tracking_confidence=min_tracking_confidence,
            output_segmentation_masks=False,
        )
        self._landmarker = mp_vision.PoseLandmarker.create_from_options(options)

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

            if raw_idx % sample_rate != 0:
                raw_idx += 1
                continue

            timestamp_ms = cap.get(cv2.CAP_PROP_POS_MSEC)
            rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

            result = self._landmarker.detect_for_video(mp_image, int(timestamp_ms))

            pose_frame = PoseFrame(frame_idx=frame_idx, timestamp_ms=timestamp_ms)

            if result.pose_landmarks:
                for idx, lm in enumerate(result.pose_landmarks[0]):
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
        self._landmarker.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()
