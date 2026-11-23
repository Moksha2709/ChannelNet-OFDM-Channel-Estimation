"""
Integrated ChannelNet Architecture (Stage 9)
Cascades the Stage 1 Super-Resolution Network (SRCNN) with the
Stage 2 Image Restoration Network (DnCNN):
ChannelNet(X) = DnCNN(SRCNN(X))
Provides clean interfaces for end-to-end inference and evaluation.
"""

import os
import torch
import torch.nn as nn
import numpy as np
from typing import Optional, Tuple

from models.sr_network import SRCNN
from models.dncnn import DnCNN
from data.preprocessing import interpolate_sparse_pilots, complex_to_2channel_tensor, tensor_2channel_to_complex
from data.normalization import ChannelNormalizer

class ChannelNet(nn.Module):
    """
    Two-stage Deep Learning Channel Estimation Pipeline.
    """
    def __init__(self, srcnn: Optional[SRCNN] = None, dncnn: Optional[DnCNN] = None):
        super(ChannelNet, self).__init__()
        self.srcnn = srcnn if srcnn is not None else SRCNN(in_channels=2, out_channels=2)
        self.dncnn = dncnn if dncnn is not None else DnCNN(in_channels=2, out_channels=2)

    def forward(self, x: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor]:
        """
        End-to-end forward pass.
        Parameters:
        -----------
        x : torch.Tensor of shape (B, 2, 72, 14)
            Interpolated LS channel estimate.
            
        Returns:
        --------
        z_sr : torch.Tensor of shape (B, 2, 72, 14)
            Intermediate super-resolved channel response.
        h_final : torch.Tensor of shape (B, 2, 72, 14)
            Final restored channel response.
        """
        z_sr = self.srcnn(x)
        h_final = self.dncnn(z_sr)
        return z_sr, h_final

    @classmethod
    def from_checkpoints(
        cls,
        sr_checkpoint_path: str,
        dncnn_checkpoint_path: str,
        device: str = "cpu"
    ) -> "ChannelNet":
        """
        Factory method to construct an integrated ChannelNet model from saved checkpoints.
        """
        srcnn = SRCNN(in_channels=2, out_channels=2).to(device)
        sr_data = torch.load(sr_checkpoint_path, map_location=device)
        srcnn.load_state_dict(sr_data['model_state_dict'] if 'model_state_dict' in sr_data else sr_data)
        srcnn.eval()

        dncnn = DnCNN(in_channels=2, out_channels=2).to(device)
        dn_data = torch.load(dncnn_checkpoint_path, map_location=device)
        dncnn.load_state_dict(dn_data['model_state_dict'] if 'model_state_dict' in dn_data else dn_data)
        dncnn.eval()

        model = cls(srcnn=srcnn, dncnn=dncnn).to(device)
        model.eval()
        return model

    def estimate_complex(
        self,
        sparse_ls_grid: np.ndarray,
        pilot_mask: np.ndarray,
        normalizer: Optional[ChannelNormalizer] = None,
        device: str = "cpu"
    ) -> Tuple[np.ndarray, np.ndarray]:
        """
        High-level inference method for raw physical observations.
        
        Parameters:
        -----------
        sparse_ls_grid : np.ndarray (72, 14) complex
        pilot_mask : np.ndarray (72, 14) bool
        normalizer : Optional[ChannelNormalizer]
        
        Returns:
        --------
        h_sr_complex : np.ndarray (72, 14) complex
        h_final_complex : np.ndarray (72, 14) complex
        """
        self.eval()

        # 1. Pre-interpolation
        h_interp = interpolate_sparse_pilots(sparse_ls_grid, pilot_mask, method="linear")

        # 2. Convert to 2-channel float32
        x_2ch = complex_to_2channel_tensor(h_interp)[None, ...]  # shape: (1, 2, 72, 14)

        # 3. Normalize if normalizer provided
        if normalizer is not None:
            x_norm = normalizer.transform(x_2ch)
        else:
            x_norm = x_2ch

        # 4. Torch forward pass
        x_tensor = torch.from_numpy(x_norm).float().to(device)
        with torch.no_grad():
            z_sr_tensor, h_final_tensor = self.forward(x_tensor)

        z_sr_np = z_sr_tensor.cpu().numpy()
        h_final_np = h_final_tensor.cpu().numpy()

        # 5. Denormalize
        if normalizer is not None:
            z_sr_denorm = normalizer.inverse_transform(z_sr_np)
            h_final_denorm = normalizer.inverse_transform(h_final_np)
        else:
            z_sr_denorm = z_sr_np
            h_final_denorm = h_final_np

        # 6. Convert back to complex (72, 14)
        h_sr_complex = tensor_2channel_to_complex(z_sr_denorm[0])
        h_final_complex = tensor_2channel_to_complex(h_final_denorm[0])

        return h_sr_complex, h_final_complex

