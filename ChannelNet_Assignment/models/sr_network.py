"""
Super-Resolution Convolutional Neural Network (SRCNN) for ChannelNet (Stage 1)
Follows Dong et al. / Soltani et al. reference paper architecture:
- Layer 1: Conv2D(in_channels=2, out_channels=64, kernel_size=9, padding=4) + ReLU
- Layer 2: Conv2D(in_channels=64, out_channels=32, kernel_size=1, padding=0) + ReLU
- Layer 3: Conv2D(in_channels=32, out_channels=2, kernel_size=5, padding=2)
Processes Real and Imaginary channel components jointly (2 channels).
"""

import torch
import torch.nn as nn

class SRCNN(nn.Module):
    """
    SRCNN architecture for Channel Super-Resolution.
    Takes 2D interpolated channel tensor (B, 2, 72, 14) and enhances resolution to (B, 2, 72, 14).
    """
    def __init__(self, in_channels: int = 2, out_channels: int = 2):
        super(SRCNN, self).__init__()

        # Patch extraction and representation
        self.conv1 = nn.Conv2d(in_channels, 64, kernel_size=9, padding=4)
        self.relu1 = nn.ReLU(inplace=True)

        # Non-linear mapping
        self.conv2 = nn.Conv2d(64, 32, kernel_size=1, padding=0)
        self.relu2 = nn.ReLU(inplace=True)

        # High-resolution channel reconstruction
        self.conv3 = nn.Conv2d(32, out_channels, kernel_size=5, padding=2)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Forward pass.
        x: (B, 2, 72, 14)
        Returns: (B, 2, 72, 14)
        """
        out = self.relu1(self.conv1(x))
        out = self.relu2(self.conv2(out))
        out = self.conv3(out)
        return out

