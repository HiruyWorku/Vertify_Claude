"""
Quick smoke test — run the full pipeline against output.mp4.

Usage:
  python scripts/test_video.py --height 180
"""

import argparse
import sys
import json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.pipeline import analyze_jump


def main():
    parser = argparse.ArgumentParser(description="Test jump analysis on a local video")
    parser.add_argument("--video", default="output.mp4", help="Path to video file")
    parser.add_argument("--height", type=float, default=180.0, help="Athlete height in cm")
    args = parser.parse_args()

    video_path = Path(args.video)
    if not video_path.exists():
        print(f"Video not found: {video_path}")
        sys.exit(1)

    print(f"Analyzing: {video_path} (height={args.height}cm) ...")
    result = analyze_jump(video_path, args.height)
    print(json.dumps(result.model_dump(), indent=2))


if __name__ == "__main__":
    main()
