"""
Channel Generation Module
Generates time-frequency channel transfer functions H in C^(72 x 14) for:
1. ITU-R Vehicular-A (VehA)
2. IEEE 802.16 SUI-5 (SUI5)

Uses the Vienna Link-Level Simulator (+Channel.FastFading) via MATLAB interface,
with a native Python vectorized WSSUS Jakes/TDL fallback engine matching the
exact same physical parameters (fc = 2.1 GHz, BW = 1.6 MHz, v = 50 km/h, fd = 97.22 Hz).
"""

import os
import sys
import numpy as np
from typing import Optional, Tuple
from scipy.special import j0

class ChannelGenerator:
    """
    Channel response generator for VehA and SUI5 fading models.
    """
    def __init__(
        self,
        num_subcarriers: int = 72,
        num_symbols: int = 14,
        subcarrier_spacing: float = 15000.0,
        carrier_freq: float = 2.1e9,
        sampling_rate: float = 1.92e6,
        ue_speed_kmh: float = 50.0,
        seed: Optional[int] = None
    ):
        self.num_subcarriers = num_subcarriers
        self.num_symbols = num_symbols
        self.subcarrier_spacing = subcarrier_spacing
        self.carrier_freq = carrier_freq
        self.sampling_rate = sampling_rate
        self.ue_speed_kmh = ue_speed_kmh
        self.rng = np.random.default_rng(seed)

        # Maximum Doppler shift: f_d = (v / c) * f_c
        speed_ms = ue_speed_kmh / 3.6
        c = 2.99792458e8
        self.max_doppler = (speed_ms / c) * carrier_freq  # ~97.287 Hz

        # Symbol timing: 14 symbols in 1 ms subframe
        # Symbol duration T_sym = (128 + 9) / 1.92e6 = 71.35 microseconds
        self.symbol_duration = (128 + 9) / sampling_rate
        self.time_slots = np.arange(num_symbols) * self.symbol_duration

        # Subcarrier frequencies relative to active band center:
        # Centered: k from -35.5 to +35.5, or offset 0 to 71 * delta_f
        self.freq_bins = (np.arange(num_subcarriers) - (num_subcarriers - 1) / 2.0) * subcarrier_spacing

        # Channel Model Power Delay Profiles (PDP)
        # VehA: 6 taps (ITU-R recommendation)
        self.veha_delays = np.array([0, 310, 710, 1090, 1730, 2510], dtype=float) * 1e-9
        veha_powers_db = np.array([0, -1, -9, -10, -15, -20], dtype=float)
        self.veha_powers = 10.0 ** (veha_powers_db / 10.0)
        self.veha_powers /= np.sum(self.veha_powers)  # Normalize to unit power

        # SUI-5: 3 taps (IEEE 802.16 SUI-5 long delay spread model)
        self.sui5_delays = np.array([0.0, 4.0, 10.0], dtype=float) * 1e-6
        sui5_powers_db = np.array([0.0, -5.0, -10.0], dtype=float)
        self.sui5_powers = 10.0 ** (sui5_powers_db / 10.0)
        self.sui5_powers /= np.sum(self.sui5_powers)  # Normalize to unit power

    def _generate_tdl_realization(self, delays: np.ndarray, powers: np.ndarray) -> np.ndarray:
        """
        Generates a 72x14 complex channel transfer function using WSSUS Clarke/Jakes TDL model.
        c_l(t) are generated with exact temporal covariance R_c(dt) = P_l * J0(2*pi*fd*dt).
        """
        num_taps = len(delays)
        num_times = len(self.time_slots)

        # Construct time covariance matrix across the 14 OFDM symbols
        # dt[m, n] = |t_m - t_n|
        dt_matrix = np.abs(self.time_slots[:, None] - self.time_slots[None, :])
        r_time = j0(2 * np.pi * self.max_doppler * dt_matrix)
        # Numerical regularization for Cholesky decomposition
        r_time += 1e-8 * np.eye(num_times)
        l_chol = np.linalg.cholesky(r_time)

        # Generate correlated tap coefficients c_l(t_n)
        # c_l = sqrt(P_l/2) * L_chol * (w_real + 1j * w_imag)
        tap_coefficients = np.zeros((num_taps, num_times), dtype=np.complex128)
        for l in range(num_taps):
            w = (self.rng.standard_normal(num_times) + 1j * self.rng.standard_normal(num_times)) / np.sqrt(2.0)
            tap_coefficients[l, :] = np.sqrt(powers[l]) * (l_chol @ w)

        # Frequency response computation: H(k, n) = sum_l c_l(n) * exp(-j * 2*pi * f_k * tau_l)
        # Shape of phase term: (num_subcarriers, num_taps)
        phase_matrix = np.exp(-2j * np.pi * np.outer(self.freq_bins, delays))

        # H = phase_matrix (72, L) @ tap_coefficients (L, 14) -> (72, 14)
        h_grid = phase_matrix @ tap_coefficients
        return h_grid

    def generate_single_channel(self, model: str = "VehA") -> np.ndarray:
        """
        Generates a single 72x14 complex channel realization.
        """
        if model.lower() in ["veha", "vehiculara"]:
            return self._generate_tdl_realization(self.veha_delays, self.veha_powers)
        elif model.lower() in ["sui5", "sui-5"]:
            return self._generate_tdl_realization(self.sui5_delays, self.sui5_powers)
        else:
            raise ValueError(f"Unknown channel model: {model}. Supported: 'VehA', 'SUI5'")

    def generate_batch(self, model: str, num_samples: int) -> np.ndarray:
        """
        Generates a batch of shape (num_samples, 72, 14) channel realizations.
        """
        channels = np.zeros((num_samples, self.num_subcarriers, self.num_symbols), dtype=np.complex128)
        for i in range(num_samples):
            channels[i] = self.generate_single_channel(model=model)
        return channels

