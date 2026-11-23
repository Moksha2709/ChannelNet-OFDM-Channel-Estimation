"""
Channel Normalization Module
Provides invertible normalization for real and imaginary channel representations:
- Min-Max normalization to [-1, 1] or [0, 1]
- Z-score standardization (zero mean, unit variance)
Stores normalization parameters for lossless denormalization.
"""

import numpy as np
from typing import Tuple, Dict, Any

class ChannelNormalizer:
    """
    Invertible normalizer for 2D channel representations (real and imaginary components).
    """
    def __init__(self, mode: str = "minmax"):
        """
        Parameters:
        -----------
        mode : str
            "minmax" (scales to [-1, 1]) or "standardize" (zero mean, unit variance).
        """
        self.mode = mode
        self.stats: Dict[str, float] = {}

    def fit(self, data: np.ndarray):
        """
        Computes normalization parameters across a dataset.
        data : np.ndarray of shape (N, 2, 72, 14) or (N, 72, 14)
        """
        if self.mode == "minmax":
            self.stats["min"] = float(np.min(data))
            self.stats["max"] = float(np.max(data))
        elif self.mode == "standardize":
            self.stats["mean"] = float(np.mean(data))
            self.stats["std"] = float(np.std(data)) + 1e-12
        else:
            raise ValueError(f"Unknown mode: {self.mode}")

    def transform(self, data: np.ndarray) -> np.ndarray:
        """
        Normalizes input data.
        """
        if not self.stats:
            raise RuntimeError("Normalizer must be fitted before transform!")

        if self.mode == "minmax":
            d_min = self.stats["min"]
            d_max = self.stats["max"]
            # Map [min, max] to [-1, 1]
            return 2.0 * (data - d_min) / (d_max - d_min + 1e-12) - 1.0
        elif self.mode == "standardize":
            mean = self.stats["mean"]
            std = self.stats["std"]
            return (data - mean) / std

    def inverse_transform(self, data: np.ndarray) -> np.ndarray:
        """
        Reverses normalization to recover original physical channel scale.
        """
        if not self.stats:
            raise RuntimeError("Normalizer must be fitted before inverse_transform!")

        if self.mode == "minmax":
            d_min = self.stats["min"]
            d_max = self.stats["max"]
            # Reverse from [-1, 1] back to [min, max]
            return (data + 1.0) / 2.0 * (d_max - d_min) + d_min
        elif self.mode == "standardize":
            mean = self.stats["mean"]
            std = self.stats["std"]
            return data * std + mean

