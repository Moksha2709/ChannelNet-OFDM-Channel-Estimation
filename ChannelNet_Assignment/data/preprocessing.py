"""
Channel Preprocessing Module
Provides 2D interpolation functions to convert sparse pilot observations
into initial low-resolution channel grids for the SR network, as specified in the paper.
"""

import numpy as np
from scipy.interpolate import griddata

def interpolate_sparse_pilots(
    sparse_ls_grid: np.ndarray,
    pilot_mask: np.ndarray,
    method: str = "linear"
) -> np.ndarray:
    """
    Interpolates sparse pilot observations onto the complete 72x14 grid.
    
    Parameters:
    -----------
    sparse_ls_grid : np.ndarray
        Complex array of shape (72, 14) containing LS estimates at pilot locations.
    pilot_mask : np.ndarray
        Boolean array of shape (72, 14) indicating pilot positions.
    method : str
        Interpolation method: 'linear' or 'cubic'.
        
    Returns:
    --------
    interpolated_grid : np.ndarray
        Complete complex array of shape (72, 14) with no NaN values.
    """
    num_subcarriers, num_symbols = sparse_ls_grid.shape

    # Known pilot coordinates
    k_pilots, n_pilots = np.where(pilot_mask)
    pilot_points = np.column_stack((k_pilots, n_pilots))
    pilot_values = sparse_ls_grid[pilot_mask]

    # Target grid coordinates
    grid_k, grid_n = np.mgrid[0:num_subcarriers, 0:num_symbols]
    target_points = (grid_k, grid_n)

    # Perform interpolation separately on real and imaginary parts
    real_interp = griddata(pilot_points, pilot_values.real, target_points, method=method)
    imag_interp = griddata(pilot_points, pilot_values.imag, target_points, method=method)

    # Fill boundary NaNs using nearest-neighbor interpolation
    if np.isnan(real_interp).any() or np.isnan(imag_interp).any():
        real_nearest = griddata(pilot_points, pilot_values.real, target_points, method='nearest')
        imag_nearest = griddata(pilot_points, pilot_values.imag, target_points, method='nearest')

        real_interp = np.where(np.isnan(real_interp), real_nearest, real_interp)
        imag_interp = np.where(np.isnan(imag_interp), imag_nearest, imag_interp)

    return real_interp + 1j * imag_interp

def complex_to_2channel_tensor(h_complex: np.ndarray) -> np.ndarray:
    """
    Converts a complex array of shape (..., 72, 14) into a 2-channel float32 array
    of shape (..., 2, 72, 14) containing [Real, Imag].
    """
    real_part = h_complex.real.astype(np.float32)
    imag_part = h_complex.imag.astype(np.float32)
    return np.stack([real_part, imag_part], axis=-3)

def tensor_2channel_to_complex(tensor_2ch: np.ndarray) -> np.ndarray:
    """
    Converts a 2-channel array of shape (..., 2, 72, 14) back to a complex array
    of shape (..., 72, 14).
    """
    return tensor_2ch[..., 0, :, :] + 1j * tensor_2ch[..., 1, :, :]

