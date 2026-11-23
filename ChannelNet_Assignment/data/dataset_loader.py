"""
PyTorch Dataset and DataLoader Wrapper
Enables efficient streaming and batch loading of ChannelNet datasets.
"""

import numpy as np
import torch
from torch.utils.data import Dataset, DataLoader
from typing import Tuple, Dict, Any, Optional

class ChannelDataset(Dataset):
    """
    PyTorch Dataset for ChannelNet.
    Yields (inputs, targets) of shape (2, 72, 14) where channel 0 is Real and channel 1 is Imag.
    """
    def __init__(self, npz_path: str):
        self.npz_path = npz_path
        data = np.load(npz_path)
        self.inputs = torch.from_numpy(data["inputs"]).float()
        self.targets = torch.from_numpy(data["targets"]).float()
        self.h_true_complex = data["h_true_complex"]
        self.h_ls_sparse = data["h_ls_sparse"]
        self.pilot_mask = data["pilot_mask"]
        self.norm_min = float(data["norm_min"])
        self.norm_max = float(data["norm_max"])

    def __len__(self) -> int:
        return len(self.inputs)

    def __getitem__(self, idx: int) -> Tuple[torch.Tensor, torch.Tensor]:
        return self.inputs[idx], self.targets[idx]

def get_dataloader(
    npz_path: str,
    batch_size: int = 128,
    shuffle: bool = True,
    num_workers: int = 0
) -> DataLoader:
    """
    Factory function returning a DataLoader for a given .npz dataset path.
    """
    dataset = ChannelDataset(npz_path)
    return DataLoader(
        dataset,
        batch_size=batch_size,
        shuffle=shuffle,
        num_workers=num_workers,
        pin_memory=False
    )

