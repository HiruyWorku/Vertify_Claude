"""
Run the full pipeline on a local video file with DEBUG logging enabled.
Usage: python scripts/debug_pipeline.py [video_path] [height_cm]
"""
import logging
import sys
from pathlib import Path

# Enable DEBUG for all our modules
logging.basicConfig(
    level=logging.DEBUG,
    format="%(name)s — %(levelname)s — %(message)s",
)
# Silence noisy third-party loggers
logging.getLogger("mediapipe").setLevel(logging.WARNING)
logging.getLogger("absl").setLevel(logging.WARNING)

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.pipeline import analyze_jump

video = sys.argv[1] if len(sys.argv) > 1 else "output.mp4"
height_cm = float(sys.argv[2]) if len(sys.argv) > 2 else 175.0

print(f"\n{'='*60}")
print(f"Video: {video}  |  User height: {height_cm}cm")
print('='*60)

result = analyze_jump(video, height_cm)

print(f"\n{'='*60}")
print(f"RESULT:")
print(f"  jump_detected:    {result.jump_detected}")
print(f"  jump_height_cm:   {result.jump_height_cm}")
print(f"  jump_height_in:   {result.jump_height_inches}")
print(f"  hang_time_ms:     {result.hang_time_ms}")
print(f"  confidence:       {result.confidence}")
print(f"  notes:            {result.processing_notes}")
print('='*60)
