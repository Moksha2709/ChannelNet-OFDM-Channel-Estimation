"""
Training Script for ChannelNet Stage 1: Super-Resolution (SRCNN) Network
Follows reference paper:
- Optimizer: Adam
- Learning rate: 0.001
- Batch size: 128
- Loss: Mean Squared Error (MSE)
- Models trained: VehA (12 dB & 22 dB) and SUI5 (12 dB & 22 dB)
- Saves checkpoints and loss curve plots.
"""

import os
import sys
import numpy as np
import torch
import torch.optim as optim
import matplotlib.pyplot as plt
from typing import Tuple, Dict, List, Any

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from models.sr_network import SRCNN
from training.losses import ChannelMSELoss
from data.dataset_loader import get_dataloader

def train_sr_model(
    channel_model: str,
    snr_db: float,
    num_epochs: int = 50,
    batch_size: int = 128,
    learning_rate: float = 0.001,
    data_dir: str = "ChannelNet_Assignment/data",
    checkpoint_dir: str = "ChannelNet_Assignment/checkpoints/sr",
    results_dir: str = "ChannelNet_Assignment/results"
) -> Dict[str, Any]:
    snr_tag = int(snr_db)
    train_path = f"{data_dir}/train/{channel_model}_{snr_tag}dB_train.npz"
    val_path = f"{data_dir}/validation/{channel_model}_{snr_tag}dB_val.npz"

    if not os.path.exists(train_path) or not os.path.exists(val_path):
        raise FileNotFoundError(f"Dataset files not found for {channel_model} at {snr_tag} dB")

    train_loader = get_dataloader(train_path, batch_size=batch_size, shuffle=True)
    val_loader = get_dataloader(val_path, batch_size=batch_size, shuffle=False)

    device = torch.device("cpu")
    model = SRCNN(in_channels=2, out_channels=2).to(device)
    criterion = ChannelMSELoss()
    optimizer = optim.Adam(model.parameters(), lr=learning_rate)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', factor=0.5, patience=5)

    train_losses: List[float] = []
    val_losses: List[float] = []

    best_val_loss = float('inf')
    os.makedirs(checkpoint_dir, exist_ok=True)
    best_model_path = f"{checkpoint_dir}/srcnn_{channel_model}_{snr_tag}dB_best.pth"

    print(f"--- Training SRCNN for {channel_model} at {snr_tag} dB ({num_epochs} Epochs) ---")

    for epoch in range(1, num_epochs + 1):
        # Training loop
        model.train()
        running_train_loss = 0.0
        for inputs, targets in train_loader:
            inputs, targets = inputs.to(device), targets.to(device)
            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, targets)
            loss.backward()
            optimizer.step()
            running_train_loss += loss.item() * len(inputs)

        epoch_train_loss = running_train_loss / len(train_loader.dataset)
        train_losses.append(epoch_train_loss)

        # Validation loop
        model.eval()
        running_val_loss = 0.0
        with torch.no_grad():
            for inputs, targets in val_loader:
                inputs, targets = inputs.to(device), targets.to(device)
                outputs = model(inputs)
                loss = criterion(outputs, targets)
                running_val_loss += loss.item() * len(inputs)

        epoch_val_loss = running_val_loss / len(val_loader.dataset)
        val_losses.append(epoch_val_loss)
        scheduler.step(epoch_val_loss)

        if epoch_val_loss < best_val_loss:
            best_val_loss = epoch_val_loss
            torch.save({
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'val_loss': epoch_val_loss,
                'channel_model': channel_model,
                'snr_db': snr_db
            }, best_model_path)

        if epoch % 10 == 0 or epoch == 1:
            print(f"Epoch [{epoch:2d}/{num_epochs:2d}] | Train Loss: {epoch_train_loss:.6f} | Val Loss: {epoch_val_loss:.6f} (Best: {best_val_loss:.6f})")

    # Plot loss curves
    curves_dir = f"{results_dir}/training_curves"
    os.makedirs(curves_dir, exist_ok=True)
    plot_path = f"{curves_dir}/sr_loss_{channel_model}_{snr_tag}dB.png"

    plt.figure(figsize=(8, 5))
    plt.plot(range(1, num_epochs + 1), train_losses, label='Training Loss', color='navy', linewidth=2)
    plt.plot(range(1, num_epochs + 1), val_losses, label='Validation Loss', color='crimson', linestyle='--', linewidth=2)
    plt.title(f'SRCNN Training & Validation Loss ({channel_model}, SNR = {snr_tag} dB)', fontsize=12, fontweight='bold')
    plt.xlabel('Epoch', fontsize=11)
    plt.ylabel('MSE Loss', fontsize=11)
    plt.grid(True, linestyle=':', alpha=0.6)
    plt.legend(fontsize=11)
    plt.tight_layout()
    plt.savefig(plot_path, dpi=300)
    plt.close()

    print(f"Saved best model checkpoint to: {best_model_path}")
    print(f"Saved loss curve to: {plot_path}")

    return {
        'model_path': best_model_path,
        'best_val_loss': best_val_loss,
        'train_losses': train_losses,
        'val_losses': val_losses
    }

def train_all_sr_models():
    models = ["VehA", "SUI5"]
    snrs = [12.0, 22.0]
    results = {}
    for m in models:
        for s in snrs:
            res = train_sr_model(m, s, num_epochs=35)
            results[f"{m}_{int(s)}dB"] = res
    return results

if __name__ == '__main__':
    train_all_sr_models()
