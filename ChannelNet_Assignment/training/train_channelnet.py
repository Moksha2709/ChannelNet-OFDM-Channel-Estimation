"""
Master ChannelNet Training Orchestrator
Executes Stage 1 (SRCNN) and Stage 2 (DnCNN) training in sequence
according to the reference paper (Soltani et al., arXiv:1810.05893v4).
"""

import sys
import os

# Add project root to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from training.train_sr import train_srcnn
from training.train_dncnn import train_dncnn_model

def train_complete_channelnet(
    channel_type: str = "VehA",
    snr_db: float = 12.0,
    sr_epochs: int = 100,
    dncnn_epochs: int = 100,
    batch_size: int = 128,
    lr: float = 1e-3
):
    """
    Trains the complete ChannelNet pipeline in two stages:
    1. Super-Resolution (SRCNN) on pre-interpolated LS inputs.
    2. Image Restoration (DnCNN) on frozen SRCNN outputs.
    """
    print(f"\n========================================================")
    print(f"STARTING CHANNELNET TRAINING: {channel_type} at {int(snr_db)} dB")
    print(f"========================================================")

    # Stage 1: SRCNN
    print("\n--- STAGE 1: Training SRCNN ---")
    sr_ckpt = train_srcnn(
        channel_type=channel_type,
        snr_db=snr_db,
        epochs=sr_epochs,
        batch_size=batch_size,
        lr=lr
    )
    print(f"[STAGE 1 COMPLETE] SRCNN checkpoint saved to: {sr_ckpt}")

    # Stage 2: DnCNN
    print("\n--- STAGE 2: Training DnCNN (Residual Denoiser) ---")
    dncnn_ckpt = train_dncnn_model(
        channel_type=channel_type,
        snr_db=snr_db,
        epochs=dncnn_epochs,
        batch_size=batch_size,
        lr=lr
    )
    print(f"[STAGE 2 COMPLETE] DnCNN checkpoint saved to: {dncnn_ckpt}")

    print(f"\n[PASS] ChannelNet training successfully completed for {channel_type} at {int(snr_db)} dB!")
    return sr_ckpt, dncnn_ckpt

if __name__ == '__main__':
    train_complete_channelnet("VehA", 12.0, sr_epochs=1, dncnn_epochs=1)
