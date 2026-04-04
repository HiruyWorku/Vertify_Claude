"""Unit tests for One-Euro filter."""

import math
import pytest
from app.core.detection.filters import OneEuroFilter


def test_passthrough_static_signal():
    """Static signal should converge to the true value."""
    f = OneEuroFilter(freq=30.0, min_cutoff=1.0, beta=0.007)
    value = 0.5
    out = None
    for _ in range(60):
        out = f(value)
    assert abs(out - value) < 0.01


def test_smoothing_reduces_noise():
    """Noisy signal should have lower variance after filtering."""
    import random
    random.seed(42)
    f = OneEuroFilter(freq=30.0, min_cutoff=1.0, beta=0.007)
    noisy = [0.5 + random.gauss(0, 0.05) for _ in range(100)]
    smoothed = [f(x) for x in noisy]
    assert math.sqrt(sum((x - 0.5) ** 2 for x in smoothed) / len(smoothed)) < \
           math.sqrt(sum((x - 0.5) ** 2 for x in noisy) / len(noisy))


def test_reset():
    f = OneEuroFilter(freq=30.0)
    f(0.5)
    f.reset()
    assert f._x is None
