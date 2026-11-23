"""
OFDM Channel Module
Simulates wireless propagation across the time-frequency grid:
Y(k, n) = H(k, n) * X(k, n) + N(k, n)
with properly calibrated Additive White Gaussian Noise (AWGN).
"""

import numpy as np
from typing import Optional, Tuple

class OFDMChannel:
    """
    SISO-OFDM Channel Simulator.
    Supports both frequency-domain multiplication and time-domain convolution.
    
    Parameters:
    -----------
    seed : Optional[int]
        Random seed for noise generation.
    """
    def __init__(self, seed: Optional[int] = None):
        self.rng = np.random.default_rng(seed)

    def add_awgn(
        self,
        signal: np.ndarray,
        snr_db: float,
        signal_power: Optional[float] = None
    ) -> Tuple[np.ndarray, float]:
        """
        Adds complex circular AWGN N ~ CN(0, sigma_n^2) for a specified SNR in dB.
        
        Parameters:
        -----------
        signal : np.ndarray
            Complex signal (frequency grid or time waveform).
        snr_db : float
            Signal-to-Noise Ratio in decibels.
        signal_power : Optional[float]
            Reference signal power E_s. If None, computed from signal.
            
        Returns:
        --------
        noisy_signal : np.ndarray
            Signal corrupted by AWGN.
        noise_var : float
            Theoretical noise variance sigma_n^2.
        """
        if signal_power is None:
            signal_power = float(np.mean(np.abs(signal) ** 2))

        snr_lin = 10.0 ** (snr_db / 10.0)
        noise_var = signal_power / snr_lin

        # Complex Gaussian noise: real and imag parts have variance noise_var / 2
        sigma_per_dim = np.sqrt(noise_var / 2.0)
        noise = sigma_per_dim * (
            self.rng.standard_normal(size=signal.shape) +
            1j * self.rng.standard_normal(size=signal.shape)
        )

        return signal + noise, noise_var

    def apply_channel_2d(
        self,
        x_grid: np.ndarray,
        h_grid: np.ndarray,
        snr_db: Optional[float] = None
    ) -> Tuple[np.ndarray, Optional[float]]:
        """
        Applies 2D channel transfer function in frequency domain:
        Y(k, n) = H(k, n) * X(k, n) + N(k, n)
        
        Parameters:
        -----------
        x_grid : np.ndarray
            Transmitted grid of shape (72, 14).
        h_grid : np.ndarray
            Channel frequency response of shape (72, 14).
        snr_db : Optional[float]
            If specified, adds AWGN for this SNR. If None, noiseless transmission.
            
        Returns:
        --------
        y_grid : np.ndarray
            Received frequency grid of shape (72, 14).
        noise_var : Optional[float]
            Computed noise variance (or None if noiseless).
        """
        if x_grid.shape != h_grid.shape:
            raise ValueError(f"Shape mismatch: X is {x_grid.shape}, H is {h_grid.shape}")

        y_clean = h_grid * x_grid

        if snr_db is None:
            return y_clean, None

        # Noise variance calibrated relative to average signal power (E_s = 1.0)
        return self.add_awgn(y_clean, snr_db=snr_db, signal_power=1.0)

