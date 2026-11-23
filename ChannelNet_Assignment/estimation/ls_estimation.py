"""
Least Squares (LS) Channel Estimation Module
Computes pilot-based LS estimates:
H_LS(k_p, n_p) = Y(k_p, n_p) / X(k_p, n_p)
and manages sparse grid representations.
"""

import numpy as np
from typing import Tuple, Optional

class LSEstimator:
    """
    Least Squares channel estimator for OFDM grids.
    """
    def __init__(self, num_subcarriers: int = 72, num_symbols: int = 14):
        self.num_subcarriers = num_subcarriers
        self.num_symbols = num_symbols

    def estimate_at_pilots(
        self,
        y_grid: np.ndarray,
        x_grid: np.ndarray,
        pilot_mask: np.ndarray
    ) -> np.ndarray:
        """
        Computes 1D vector of LS channel estimates at pilot locations.
        h_ls = y_p / x_p
        
        Parameters:
        -----------
        y_grid : np.ndarray
            Received frequency grid (72, 14).
        x_grid : np.ndarray
            Transmitted grid with pilots (72, 14).
        pilot_mask : np.ndarray
            Boolean mask of pilot locations.
            
        Returns:
        --------
        h_ls_vector : np.ndarray
            1D complex array of LS estimates at pilot positions.
        """
        y_pilots = y_grid[pilot_mask]
        x_pilots = x_grid[pilot_mask]
        return y_pilots / x_pilots

    def get_sparse_ls_grid(
        self,
        y_grid: np.ndarray,
        x_grid: np.ndarray,
        pilot_mask: np.ndarray,
        fill_value: complex = 0.0 + 0j
    ) -> np.ndarray:
        """
        Returns a (72, 14) grid with LS estimates at pilot locations and
        fill_value (e.g. 0.0 or np.nan) at non-pilot locations.
        """
        sparse_grid = np.full((self.num_subcarriers, self.num_symbols), fill_value, dtype=np.complex128)
        sparse_grid[pilot_mask] = y_grid[pilot_mask] / x_grid[pilot_mask]
        return sparse_grid

    def compute_pilot_mse(
        self,
        h_ls_sparse: np.ndarray,
        h_true: np.ndarray,
        pilot_mask: np.ndarray
    ) -> float:
        """
        Computes Mean Squared Error strictly at pilot positions.
        MSE = (1 / N_p) * sum |H_true(k_p, n_p) - H_LS(k_p, n_p)|^2
        """
        diff = h_true[pilot_mask] - h_ls_sparse[pilot_mask]
        return float(np.mean(np.abs(diff) ** 2))

