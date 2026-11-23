"""
Denoising Convolutional Neural Network (DnCNN) for ChannelNet (Stage 2)
Follows Zhang et al. / Soltani et al. reference paper architecture:
- 20 Convolutional Layers with Residual Learning:
  * Layer 1: Conv2D(2, 64, kernel=3x3, padding=1) + ReLU
  * Layers 2-19 (18 layers): Conv2D(64, 64, 3x3, padding=1, bias=False) + BatchNorm2D(64) + ReLU
  * Layer 20: Conv2D(64, 2, kernel=3x3, padding=1)
Residual formulation:
R(Z) = residual noise estimate
H_final = Z - R(Z)
"""

import torch
import torch.nn as nn

class DnCNN(nn.Module):
    """
    20-Layer Residual Denoising Convolutional Neural Network.
    """
    def __init__(self, in_channels: int = 2, out_channels: int = 2, num_layers: int = 20, num_features: int = 64):
        super(DnCNN, self).__init__()
        self.num_layers = num_layers

        layers = []
        # Layer 1: Conv + ReLU
        layers.append(nn.Conv2d(in_channels, num_features, kernel_size=3, padding=1, bias=True))
        layers.append(nn.ReLU(inplace=True))

        # Layers 2 to 19: Conv + BatchNorm + ReLU
        for _ in range(num_layers - 2):
            layers.append(nn.Conv2d(num_features, num_features, kernel_size=3, padding=1, bias=False))
            layers.append(nn.BatchNorm2d(num_features))
            layers.append(nn.ReLU(inplace=True))

        # Layer 20: Conv (Reconstruction of residual noise)
        layers.append(nn.Conv2d(num_features, out_channels, kernel_size=3, padding=1, bias=True))

        self.dncnn = nn.Sequential(*layers)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Forward pass with residual subtraction:
        Residual noise: R(x) = self.dncnn(x)
        Denoised channel: out = x - R(x)
        """
        residual = self.dncnn(x)
        return x - residual

    def predict_residual(self, x: torch.Tensor) -> torch.Tensor:
        """
        Returns estimated residual noise directly.
        """
        return self.dncnn(x)

