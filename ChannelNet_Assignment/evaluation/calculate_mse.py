"""
MSE and Performance Metrics Calculation Module
Implements accurate physical channel metrics across the 72x14 time-frequency grid:
- Linear MSE
- dB MSE (10 * log10(MSE))
- Normalized MSE (NMSE)
"""

import numpy as np

def calculate_grid_mse(h_true: np.ndarray, h_est: np.ndarray) -> float:
    """
    Computes per-frame Mean Squared Error across all 72x14 complex channel coefficients:
    MSE = (1 / (72 * 14)) * sum_{k=0}^{71} sum_{n=0}^{13} |H_true(k, n) - H_est(k, n)|^2
    """
    if h_true.shape != h_est.shape:
        raise ValueError(f"Shape mismatch: {h_true.shape} vs {h_est.shape}")
    return float(np.mean(np.abs(h_true - h_est) ** 2))

def calculate_grid_nmse(h_true: np.ndarray, h_est: np.ndarray) -> float:
    """
    Computes Normalized Mean Squared Error:
    NMSE = sum |H_true - H_est|^2 / sum |H_true|^2
    """
    numerator = np.sum(np.abs(h_true - h_est) ** 2)
    denominator = np.sum(np.abs(h_true) ** 2) + 1e-12
    return float(numerator / denominator)

def linear_to_db(val_linear: float) -> float:
    """
    Converts linear MSE to decibels: 10 * log10(MSE).
    """
    return float(10.0 * np.log10(max(val_linear, 1e-15)))

def batch_calculate_mse(h_true_batch: np.ndarray, h_est_batch: np.ndarray) -> np.ndarray:
    """
    Computes per-frame MSE across a batch of shape (N, 72, 14).
    Returns 1D array of length N.
    """
    return np.mean(np.abs(h_true_batch - h_est_batch) ** 2, axis=(1, 2))

