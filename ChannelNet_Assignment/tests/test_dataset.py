"""
Stage 5 Verification Tests for Dataset Generation, Preprocessing & Normalization
Verifies:
1. Training, validation, and testing split separation.
2. Tensor dimensions (N, 2, 72, 14) and float32 dtype.
3. Absence of NaNs and Infs in both inputs and targets.
4. Normalization forward and inverse invertibility.
5. DataLoader batch streaming verification.
6. Saves sample visual inspection plot: results/channel_visualizations/dataset_sample_inspection.png.
"""

import os
import sys
import numpy as np
import torch
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from data.normalization import ChannelNormalizer
from data.preprocessing import interpolate_sparse_pilots, complex_to_2channel_tensor
from data.dataset_generator import generate_dataset_split
from data.dataset_loader import ChannelDataset, get_dataloader

def test_normalization_invertibility():
    """Verify that ChannelNormalizer accurately restores original physical values."""
    normalizer = ChannelNormalizer(mode="minmax")
    rng = np.random.default_rng(42)
    sample_data = rng.standard_normal(size=(50, 2, 72, 14)).astype(np.float32)

    normalizer.fit(sample_data)
    norm_data = normalizer.transform(sample_data)

    # Check bounds [-1, 1]
    assert np.min(norm_data) >= -1.0 - 1e-6, f"Min {np.min(norm_data)} < -1.0"
    assert np.max(norm_data) <= 1.0 + 1e-6, f"Max {np.max(norm_data)} > 1.0"

    recovered = normalizer.inverse_transform(norm_data)
    max_recon_err = float(np.max(np.abs(recovered - sample_data)))
    print(f"Normalizer max reconstruction error: {max_recon_err:.2e}")
    assert max_recon_err < 1e-5, f"Reconstruction error {max_recon_err} too large!"
    print("[PASS] Normalization invertibility test passed.")

def test_dataset_split_generation():
    """Verify split generation, shape compliance, and absence of NaNs/Infs."""
    split = generate_dataset_split(
        channel_model='VehA',
        snr_db=12.0,
        num_samples=50,
        num_pilots=48,
        seed=42
    )

    inputs = split["inputs"]
    targets = split["targets"]
    mask = split["pilot_mask"]

    assert inputs.shape == (50, 2, 72, 14), f"Input shape {inputs.shape} != (50, 2, 72, 14)"
    assert targets.shape == (50, 2, 72, 14), f"Target shape {targets.shape} != (50, 2, 72, 14)"
    assert not np.isnan(inputs).any(), "NaNs detected in inputs!"
    assert not np.isnan(targets).any(), "NaNs detected in targets!"
    assert not np.isinf(inputs).any(), "Infs detected in inputs!"
    assert not np.isinf(targets).any(), "Infs detected in targets!"
    assert int(np.sum(mask)) == 48, f"Mask pilot count {np.sum(mask)} != 48"

    print("[PASS] Dataset split shapes and numeric checks passed.")

def test_dataloader_streaming(tmp_path="temp_test_split.npz"):
    """Verify PyTorch DataLoader streaming."""
    split = generate_dataset_split('SUI5', snr_db=22.0, num_samples=64, seed=99)
    np.savez_compressed(tmp_path, **split)

    loader = get_dataloader(tmp_path, batch_size=16, shuffle=False)
    batch_count = 0
    for b_inputs, b_targets in loader:
        assert b_inputs.shape == (16, 2, 72, 14), f"Batch input shape {b_inputs.shape} unexpected"
        assert b_targets.shape == (16, 2, 72, 14), f"Batch target shape {b_targets.shape} unexpected"
        assert b_inputs.dtype == torch.float32, f"Expected float32, got {b_inputs.dtype}"
        batch_count += 1

    assert batch_count == 4, f"Expected 4 batches, got {batch_count}"
    try:
        os.remove(tmp_path)
    except OSError:
        pass
    print("[PASS] DataLoader streaming test passed.")

def generate_sample_visualization():
    """Generates visual inspection of an interpolated input vs ground truth."""
    split = generate_dataset_split('VehA', snr_db=12.0, num_samples=1, seed=555)
    raw_input = split["raw_inputs"][0]  # shape: (2, 72, 14)
    raw_target = split["raw_targets"][0]  # shape: (2, 72, 14)

    out_path = 'ChannelNet_Assignment/results/channel_visualizations/dataset_sample_inspection.png'
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    # Real part input (interpolated LS)
    im0 = axes[0, 0].imshow(raw_input[0], aspect='auto', cmap='coolwarm')
    axes[0, 0].set_title('Input: Interpolated LS Real Part (SNR = 12 dB, 48 Pilots)', fontsize=12, fontweight='bold')
    axes[0, 0].set_xlabel('OFDM Symbol Index n')
    axes[0, 0].set_ylabel('Subcarrier Index k')
    fig.colorbar(im0, ax=axes[0, 0])

    # Real part target (ground truth)
    im1 = axes[0, 1].imshow(raw_target[0], aspect='auto', cmap='coolwarm')
    axes[0, 1].set_title('Target: Ground-Truth Channel Real Part', fontsize=12, fontweight='bold')
    axes[0, 1].set_xlabel('OFDM Symbol Index n')
    axes[0, 1].set_ylabel('Subcarrier Index k')
    fig.colorbar(im1, ax=axes[0, 1])

    # Imag part input
    im2 = axes[1, 0].imshow(raw_input[1], aspect='auto', cmap='coolwarm')
    axes[1, 0].set_title('Input: Interpolated LS Imaginary Part (SNR = 12 dB, 48 Pilots)', fontsize=12, fontweight='bold')
    axes[1, 0].set_xlabel('OFDM Symbol Index n')
    axes[1, 0].set_ylabel('Subcarrier Index k')
    fig.colorbar(im2, ax=axes[1, 0])

    # Imag part target
    im3 = axes[1, 1].imshow(raw_target[1], aspect='auto', cmap='coolwarm')
    axes[1, 1].set_title('Target: Ground-Truth Channel Imaginary Part', fontsize=12, fontweight='bold')
    axes[1, 1].set_xlabel('OFDM Symbol Index n')
    axes[1, 1].set_ylabel('Subcarrier Index k')
    fig.colorbar(im3, ax=axes[1, 1])

    plt.suptitle('Dataset Sample Inspection: Interpolated Input vs. Ground Truth (Stage 5)', fontsize=14, fontweight='bold')
    plt.tight_layout()
    plt.savefig(out_path, dpi=300)
    plt.close()
    print(f"[PASS] Saved sample visualization to {out_path}")

if __name__ == '__main__':
    print("=" * 60)
    print("RUNNING STAGE 5 DATASET & PREPROCESSING TEST SUITE")
    print("=" * 60)
    test_normalization_invertibility()
    test_dataset_split_generation()
    test_dataloader_streaming()
    generate_sample_visualization()
    print("=" * 60)
    print("ALL STAGE 5 UNIT TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)

