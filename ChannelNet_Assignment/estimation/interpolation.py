"""
2D Channel Interpolation Module
Implements pilot-aided channel estimation using 2D interpolation (linear and cubic)
across the 72x14 time-frequency grid.
"""

import numpy as np
from scipy.interpolate import griddata
from typing import Tuple

class InterpolationEstimator:
    """
    2D Channel Interpolator from sparse pilot estimates.
    """
    def __init__(self, num_subcarriers: int = 72, num_symbols: int = 14, method: str = "linear"):
        self.num_subcarriers = num_subcarriers
        self.num_symbols = num_symbols
        self.method = method

        grid_k, grid_n = np.mgrid[0:num_subcarriers, 0:num_symbols]
        self.target_points = (grid_k, grid_n)

    def estimate(self, sparse_ls_grid: np.ndarray, pilot_mask: np.ndarray) -> np.ndarray:
        """
        Reconstructs the complete 72x14 channel grid by 2D interpolation.
        
        Parameters:
        -----------
        sparse_ls_grid : np.ndarray
            (72, 14) complex grid with LS estimates at pilot locations.
        pilot_mask : np.ndarray
            (72, 14) boolean mask of pilot locations.
            
        Returns:
        --------
        h_interp : np.ndarray
            (72, 14) complex interpolated channel estimate.
        """
        k_pilots, n_pilots = np.where(pilot_mask)
        pilot_points = np.column_stack((k_pilots, n_pilots))
        pilot_vals = sparse_ls_grid[pilot_mask]

        # Interpolate real and imaginary parts separately
        real_interp = griddata(pilot_points, pilot_vals.real, self.target_points, method=self.method)
        imag_interp = griddata(pilot_points, pilot_vals.imag, self.target_points, method=self.method)

        # Boundary extrapolation with nearest neighbor to prevent NaNs
        if np.isnan(real_interp).any() or np.isnan(imag_interp).any():
            real_nearest = griddata(pilot_points, pilot_vals.real, self.target_points, method='nearest')
            imag_nearest = griddata(pilot_points, pilot_vals.imag, self.target_points, method='nearest')
            real_interp = np.where(np.isnan(real_interp), real_nearest, real_interp)
            imag_interp = np.where(np.isnan(imag_interp), imag_nearest, imag_interp)

        return (real_interp + 1j * imag_interp).astype(np.complex128)

