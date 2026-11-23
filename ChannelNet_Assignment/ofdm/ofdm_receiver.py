"""
SISO-OFDM Receiver Module
Performs deserialization, cyclic prefix (CP) removal, normalized FFT,
and extraction of active subcarriers.
"""

import numpy as np

class OFDMReceiver:
    """
    SISO-OFDM Receiver.
    
    Parameters:
    -----------
    num_subcarriers : int
        Number of active subcarriers (NS = 72).
    num_symbols : int
        Number of OFDM symbols per frame (ND = 14).
    fft_size : int
        FFT size (128).
    cp_length : int
        Cyclic prefix length in samples (9).
    """
    def __init__(
        self,
        num_subcarriers: int = 72,
        num_symbols: int = 14,
        fft_size: int = 128,
        cp_length: int = 9
    ):
        self.num_subcarriers = num_subcarriers
        self.num_symbols = num_symbols
        self.fft_size = fft_size
        self.cp_length = cp_length
        self.symbol_length = fft_size + cp_length

        start_idx = (fft_size - num_subcarriers) // 2
        self.active_indices = np.arange(start_idx, start_idx + num_subcarriers)

    def demodulate(self, time_waveform: np.ndarray) -> np.ndarray:
        """
        Demodulates 1D time-domain waveform back to 2D frequency grid (72 x 14).
        
        Parameters:
        -----------
        time_waveform : np.ndarray
            1D array of length num_symbols * (fft_size + cp_length).
            
        Returns:
        --------
        rx_grid : np.ndarray
            Recovered frequency-domain grid of shape (num_subcarriers, num_symbols).
        """
        expected_len = self.num_symbols * self.symbol_length
        if len(time_waveform) != expected_len:
            raise ValueError(
                f"Expected time_waveform length {expected_len}, got {len(time_waveform)}"
            )

        # Reshape to 2D matrix of shape (symbol_length, num_symbols)
        symbols_with_cp = time_waveform.reshape((self.symbol_length, self.num_symbols), order='F')

        # Remove cyclic prefix (discard first cp_length samples)
        time_symbols = symbols_with_cp[self.cp_length:, :]

        # Orthonormal FFT along axis 0
        fft_grid = np.fft.fft(time_symbols, axis=0) / np.sqrt(self.fft_size)

        # Extract active subcarriers
        rx_grid = fft_grid[self.active_indices, :]
        return rx_grid

