"""
SISO-OFDM Transmitter Module
Generates QPSK / QAM data symbols, maps them onto active subcarriers,
applies normalized IFFT, inserts cyclic prefix (CP), and serializes time-domain waveform.
"""

import numpy as np
from typing import Tuple, Optional

class OFDMTransmitter:
    """
    SISO-OFDM Transmitter.
    
    Parameters:
    -----------
    num_subcarriers : int
        Number of active subcarriers (NS = 72 for 6 LTE Resource Blocks).
    num_symbols : int
        Number of OFDM symbols per frame (ND = 14 for 1 LTE subframe).
    fft_size : int
        FFT size (default: 128 for 1.92 MHz LTE sampling rate).
    cp_length : int
        Cyclic prefix length in samples (default: 9 samples ~ 4.69 microseconds).
    seed : Optional[int]
        Random seed for reproducibility.
    """
    def __init__(
        self,
        num_subcarriers: int = 72,
        num_symbols: int = 14,
        fft_size: int = 128,
        cp_length: int = 9,
        seed: Optional[int] = None
    ):
        self.num_subcarriers = num_subcarriers
        self.num_symbols = num_symbols
        self.fft_size = fft_size
        self.cp_length = cp_length
        self.rng = np.random.default_rng(seed)

        # Active subcarrier mapping: center the 72 subcarriers within 128 FFT bins
        # Subcarrier indices: 28 to 99 (inclusive of 28, exclusive of 100) -> 72 subcarriers
        start_idx = (fft_size - num_subcarriers) // 2
        self.active_indices = np.arange(start_idx, start_idx + num_subcarriers)

    def generate_random_qpsk(self) -> np.ndarray:
        """
        Generates random QPSK symbols of shape (num_subcarriers, num_symbols)
        with normalized unit average energy E_s = 1.
        """
        bits = self.rng.integers(0, 2, size=(self.num_subcarriers, self.num_symbols, 2))
        symbols = (2 * bits[:, :, 0] - 1) + 1j * (2 * bits[:, :, 1] - 1)
        return symbols / np.sqrt(2.0)

    def modulate(self, freq_grid: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """
        Transforms the 2D frequency-domain grid into time-domain OFDM waveform.
        
        Parameters:
        -----------
        freq_grid : np.ndarray
            Complex array of shape (num_subcarriers, num_symbols).
            
        Returns:
        --------
        time_waveform : np.ndarray
            1D serialized time-domain signal of length num_symbols * (fft_size + cp_length).
        ofdm_symbols_time : np.ndarray
            2D array of shape (fft_size + cp_length, num_symbols).
        """
        if freq_grid.shape != (self.num_subcarriers, self.num_symbols):
            raise ValueError(
                f"Expected freq_grid shape ({self.num_subcarriers}, {self.num_symbols}), "
                f"got {freq_grid.shape}"
            )

        # Allocate 128-point FFT grid
        fft_grid = np.zeros((self.fft_size, self.num_symbols), dtype=np.complex128)
        fft_grid[self.active_indices, :] = freq_grid

        # Orthonormal IFFT along subcarrier axis (axis=0)
        # Scaling by sqrt(N_fft) ensures energy conservation
        time_symbols = np.fft.ifft(fft_grid, axis=0) * np.sqrt(self.fft_size)

        # Cyclic prefix insertion: prepend last cp_length samples
        cp = time_symbols[-self.cp_length:, :]
        ofdm_symbols_with_cp = np.vstack([cp, time_symbols])

        # Serialize to 1D stream
        time_waveform = ofdm_symbols_with_cp.flatten(order='F')
        return time_waveform, ofdm_symbols_with_cp

