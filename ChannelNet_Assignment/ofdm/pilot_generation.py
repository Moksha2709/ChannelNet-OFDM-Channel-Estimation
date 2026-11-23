"""
Lattice-Type Pilot Generation Module
Implements diamond / lattice pilot arrangements on the 72 x 14 OFDM grid:
- Main configuration: 48 pilots per frame
- Additional densities: 24 pilots and 72 pilots per frame
Supports pilot mask generation, pilot insertion, and pilot extraction.
"""

import numpy as np
from typing import Tuple, Dict

class PilotGenerator:
    """
    Generates and manages lattice-type pilot patterns for OFDM grids.
    
    Parameters:
    -----------
    num_subcarriers : int
        Number of active subcarriers (72).
    num_symbols : int
        Number of OFDM symbols (14).
    """
    def __init__(self, num_subcarriers: int = 72, num_symbols: int = 14):
        self.num_subcarriers = num_subcarriers
        self.num_symbols = num_symbols

    def get_pilot_mask(self, num_pilots: int = 48) -> np.ndarray:
        """
        Generates a binary boolean mask of shape (num_subcarriers, num_symbols)
        where True indicates a pilot location in a diamond/lattice layout.
        
        Supported pilot counts: 48 (main), 24, 72.
        """
        mask = np.zeros((self.num_subcarriers, self.num_symbols), dtype=bool)

        if num_pilots == 48:
            # 4 pilot symbols: n in {1, 4, 8, 11}
            # 12 subcarriers per pilot symbol (subcarrier spacing = 6)
            # Staggered by 3 subcarriers between adjacent pilot symbols to form diamond lattice
            pilot_symbols_set1 = [1, 8]
            pilot_subcarriers_set1 = np.arange(0, self.num_subcarriers, 6)  # 0, 6, 12, ..., 66 (12 pilots)
            for n in pilot_symbols_set1:
                mask[pilot_subcarriers_set1, n] = True

            pilot_symbols_set2 = [4, 11]
            pilot_subcarriers_set2 = np.arange(3, self.num_subcarriers, 6)  # 3, 9, 15, ..., 69 (12 pilots)
            for n in pilot_symbols_set2:
                mask[pilot_subcarriers_set2, n] = True

        elif num_pilots == 24:
            # 2 pilot symbols: n in {4, 11}
            # 12 subcarriers per symbol
            pilot_symbols_set1 = [4]
            pilot_subcarriers_set1 = np.arange(0, self.num_subcarriers, 6)
            for n in pilot_symbols_set1:
                mask[pilot_subcarriers_set1, n] = True

            pilot_symbols_set2 = [11]
            pilot_subcarriers_set2 = np.arange(3, self.num_subcarriers, 6)
            for n in pilot_symbols_set2:
                mask[pilot_subcarriers_set2, n] = True

        elif num_pilots == 72:
            # 6 pilot symbols: n in {0, 2, 5, 7, 10, 12}
            # 12 subcarriers per symbol
            pilot_symbols_set1 = [0, 5, 10]
            pilot_subcarriers_set1 = np.arange(0, self.num_subcarriers, 6)
            for n in pilot_symbols_set1:
                mask[pilot_subcarriers_set1, n] = True

            pilot_symbols_set2 = [2, 7, 12]
            pilot_subcarriers_set2 = np.arange(3, self.num_subcarriers, 6)
            for n in pilot_symbols_set2:
                mask[pilot_subcarriers_set2, n] = True

        else:
            raise ValueError(
                f"Unsupported pilot count {num_pilots}. Supported counts: 24, 48, 72."
            )

        actual_count = int(np.sum(mask))
        if actual_count != num_pilots:
            raise RuntimeError(
                f"Generated mask pilot count ({actual_count}) does not match requested ({num_pilots})!"
            )

        return mask

    def insert_pilots(
        self,
        data_grid: np.ndarray,
        pilot_mask: np.ndarray,
        pilot_value: complex = 1.0 + 0j
    ) -> np.ndarray:
        """
        Inserts known pilot symbols into the OFDM frame at masked positions.
        """
        tx_grid = data_grid.copy()
        tx_grid[pilot_mask] = pilot_value
        return tx_grid

    def extract_pilots(
        self,
        rx_grid: np.ndarray,
        pilot_mask: np.ndarray
    ) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """
        Extracts pilot observations and their coordinate indices.
        
        Returns:
        --------
        subcarrier_indices : np.ndarray
            1D array of subcarrier indices (k_p).
        symbol_indices : np.ndarray
            1D array of OFDM symbol indices (n_p).
        pilot_observations : np.ndarray
            1D array of received values Y(k_p, n_p).
        """
        k_indices, n_indices = np.where(pilot_mask)
        pilot_values = rx_grid[pilot_mask]
        return k_indices, n_indices, pilot_values

