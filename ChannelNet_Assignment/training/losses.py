"""
Loss Functions Module for ChannelNet
Implements Mean Squared Error (MSE) and Normalized Mean Squared Error (NMSE)
for channel frequency response grids.
"""

import torch
import torch.nn as nn

class ChannelMSELoss(nn.Module):
    """
    Standard Mean Squared Error Loss across real and imaginary channel grids:
    L = (1 / N) * sum |H_hat - H_true|^2
    """
    def __init__(self):
        super(ChannelMSELoss, self).__init__()
        self.mse = nn.MSELoss(reduction='mean')

    def forward(self, pred: torch.Tensor, target: torch.Tensor) -> torch.Tensor:
        return self.mse(pred, target)

class ChannelNMSELoss(nn.Module):
    """
    Normalized Mean Squared Error Loss:
    NMSE = E{ ||H_true - H_hat||_F^2 / ||H_true||_F^2 }
    """
    def __init__(self):
        super(ChannelNMSELoss, self).__init__()

    def forward(self, pred: torch.Tensor, target: torch.Tensor) -> torch.Tensor:
        err = torch.sum((pred - target) ** 2, dim=(1, 2, 3))
        pwr = torch.sum(target ** 2, dim=(1, 2, 3)) + 1e-12
        return torch.mean(err / pwr)

