"""
One-Euro Filter — low-latency, low-noise signal smoother.
Reference: Casiez et al., "1€ Filter: A Simple Speed-based Low-pass Filter
           for Noisy Input in Interactive Systems", CHI 2012.

Chosen over Kalman because:
- No motion model needed (works for any signal shape)
- Single-pass, O(1) per frame
- Beta param intuitively controls speed-dependent cutoff
"""

import math


def _smoothing_factor(te: float, cutoff: float) -> float:
    r = 2 * math.pi * cutoff * te
    return r / (r + 1)


def _exponential_smoothing(a: float, x: float, x_prev: float) -> float:
    return a * x + (1 - a) * x_prev


class OneEuroFilter:
    def __init__(self, freq: float, min_cutoff: float = 1.0, beta: float = 0.007, d_cutoff: float = 1.0):
        """
        freq:       estimated input frequency (fps)
        min_cutoff: lower = smoother at rest, higher = more responsive
        beta:       higher = less lag during fast movement
        d_cutoff:   cutoff for derivative (usually 1.0)
        """
        self.freq = freq
        self.min_cutoff = min_cutoff
        self.beta = beta
        self.d_cutoff = d_cutoff
        self._x: float | None = None
        self._dx: float = 0.0

    def __call__(self, x: float) -> float:
        if self._x is None:
            self._x = x
            return x

        te = 1.0 / self.freq
        # Filtered derivative
        a_d = _smoothing_factor(te, self.d_cutoff)
        dx = (x - self._x) * self.freq
        dx_hat = _exponential_smoothing(a_d, dx, self._dx)

        # Adaptive cutoff
        cutoff = self.min_cutoff + self.beta * abs(dx_hat)
        a = _smoothing_factor(te, cutoff)
        x_hat = _exponential_smoothing(a, x, self._x)

        self._x = x_hat
        self._dx = dx_hat
        return x_hat

    def reset(self) -> None:
        self._x = None
        self._dx = 0.0
