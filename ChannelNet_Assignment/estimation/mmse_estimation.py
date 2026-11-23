"""
Minimum Mean Square Error (MMSE) Channel Estimation Module
Implements:
1. Ideal Linear MMSE (LMMSE) with exact analytic channel autocorrelation R_hh.
2. Estimated MMSE using sample covariance.
Formula:
h_hat_MMSE = R_hd_hp @ inv(R_hp_hp + sigma_n^2 * I) @ h_ls_p
"""

import numpy as np
from scipy.special import j0
from typing import Tuple, Optional

class MMSEEstimator:
    """
    Linear MMSE channel estimator for 72x14 OFDM grids.
    """
    def __init__(
        self,
        channel_model: str = "VehA",
        num_subcarriers: int = 72,
        num_symbols: int = 14,
        subcarrier_spacing: float = 15000.0,
        carrier_freq: float = 2.1e9,
        sampling_rate: float = 1.92e6,
        ue_speed_kmh: float = 50.0
    ):
        self.channel_model = channel_model
        self.num_subcarriers = num_subcarriers
        self.num_symbols = num_symbols
        self.total_elements = num_subcarriers * num_symbols  # 1008

        # Timing and Doppler
        c = 2.99792458e8
        speed_ms = ue_speed_kmh / 3.6
        self.max_doppler = (speed_ms / c) * carrier_freq
        self.t_sym = (128 + 9) / sampling_rate
        self.delta_f = subcarrier_spacing

        # Power Delay Profiles
        if channel_model.lower() in ["veha", "vehiculara"]:
            self.delays = np.array([0, 310, 710, 1090, 1730, 2510], dtype=float) * 1e-9
            powers_db = np.array([0, -1, -9, -10, -15, -20], dtype=float)
        elif channel_model.lower() in ["sui5", "sui-5"]:
            self.delays = np.array([0.0, 4.0, 10.0], dtype=float) * 1e-6
            powers_db = np.array([0.0, -5.0, -10.0], dtype=float)
        else:
            raise ValueError(f"Unknown channel model: {channel_model}")

        self.powers = 10.0 ** (powers_db / 10.0)
        self.powers /= np.sum(self.powers)
        self._filter_cache = {}

    def compute_analytic_correlation(
        self,
        k1: np.ndarray,
        n1: np.ndarray,
        k2: np.ndarray,
        n2: np.ndarray
    ) -> np.ndarray:
        """
        Computes exact theoretical 2D WSSUS channel correlation matrix:
        R(k1-k2, n1-n2) = J0(2*pi*fd*(n1-n2)*T_sym) * sum_l P_l * exp(-j*2*pi*(k1-k2)*delta_f*tau_l)
        """
        dk = k1[:, None] - k2[None, :]
        dn = n1[:, None] - n2[None, :]

        # Time correlation (Jakes Bessel function)
        r_time = j0(2 * np.pi * self.max_doppler * np.abs(dn) * self.t_sym)

        # Frequency correlation
        # phase: (len(k1), len(k2), len(taps))
        r_freq = np.zeros(dk.shape, dtype=np.complex128)
        for l in range(len(self.delays)):
            r_freq += self.powers[l] * np.exp(-2j * np.pi * dk * self.delta_f * self.delays[l])

        return r_time * r_freq

    def estimate(
        self,
        sparse_ls_grid: np.ndarray,
        pilot_mask: np.ndarray,
        snr_db: float
    ) -> np.ndarray:
        """
        Computes LMMSE channel estimate across all 72x14 resource elements.
        
        Parameters:
        -----------
        sparse_ls_grid : np.ndarray
            (72, 14) complex grid with LS estimates at pilot locations.
        pilot_mask : np.ndarray
            (72, 14) boolean mask of pilot locations.
        snr_db : float
            Current SNR in decibels.
            
        Returns:
        --------
        h_hat_mmse : np.ndarray
            (72, 14) complex LMMSE channel estimate.
        """
        cache_key = (pilot_mask.tobytes(), round(float(snr_db), 2))
        if cache_key in self._filter_cache:
            w_mmse = self._filter_cache[cache_key]
        else:
            # All target grid coordinates (vectorized in row-major order)
            all_k, all_n = np.mgrid[0:self.num_subcarriers, 0:self.num_symbols]
            all_k = all_k.flatten()
            all_n = all_n.flatten()

            # Pilot coordinates
            p_k, p_n = np.where(pilot_mask)

            # Compute theoretical covariance matrices
            r_hd_hp = self.compute_analytic_correlation(all_k, all_n, p_k, p_n)  # (1008, N_p)
            r_hp_hp = self.compute_analytic_correlation(p_k, p_n, p_k, p_n)      # (N_p, N_p)

            # Noise variance
            sigma_n2 = 1.0 / (10.0 ** (snr_db / 10.0))

            # LMMSE filtering matrix: W = R_hd_hp @ inv(R_hp_hp + sigma_n^2 * I)
            reg_matrix = r_hp_hp + sigma_n2 * np.eye(len(p_k), dtype=np.complex128)
            w_mmse = np.linalg.solve(reg_matrix.T, r_hd_hp.T).T
            self._filter_cache[cache_key] = w_mmse

        # Pilot observations
        h_ls_p = sparse_ls_grid[pilot_mask]  # 1D vector of pilot observations

        # Vectorized estimate
        h_hat_vec = w_mmse @ h_ls_p
        return h_hat_vec.reshape((self.num_subcarriers, self.num_symbols))
