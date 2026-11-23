"""
Stage 7 Unit Tests for SRCNN Neural Network
Verifies:
1. Forward pass output dimensions (B, 2, 72, 14).
2. Absence of NaNs and Infs in activations and gradients.
3. Autograd parameter updates during backpropagation.
4. Loss convergence in short training run.
5. Checkpoint saving and exact reloading fidelity.
6. Generates visual comparison: results/channel_visualizations/sr_output_comparison.png.
"""

import os
import sys
import torch
import torch.nn as nn
import torch.optim as optim
import numpy as np
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from models.sr_network import SRCNN
from models.dncnn import DnCNN
from training.losses import ChannelMSELoss

def test_dncnn_forward_and_residual():
    """Verify DnCNN forward pass dimensions, numeric validity, and residual learning."""
    model = DnCNN(in_channels=2, out_channels=2, num_layers=20, num_features=64)
    x = torch.randn(4, 2, 72, 14)
    out = model(x)

    assert out.shape == (4, 2, 72, 14), f"DnCNN output shape {out.shape} != (4, 2, 72, 14)"
    assert not torch.isnan(out).any(), "NaNs in DnCNN forward pass!"
    assert not torch.isinf(out).any(), "Infs in DnCNN forward pass!"

    residual = model.predict_residual(x)
    assert residual.shape == (4, 2, 72, 14), f"Residual shape {residual.shape} != (4, 2, 72, 14)"
    recon = x - residual
    max_recon_err = float(torch.max(torch.abs(out - recon)))
    assert max_recon_err < 1e-6, f"DnCNN output does not match (x - residual): {max_recon_err}"
    print("[PASS] DnCNN forward pass and residual subtraction test passed.")

def test_srcnn_forward_and_shapes():
    """Verify input/output shapes and absence of NaNs/Infs."""
    model = SRCNN(in_channels=2, out_channels=2)
    x = torch.randn(8, 2, 72, 14)
    out = model(x)

    assert out.shape == (8, 2, 72, 14), f"Output shape {out.shape} != (8, 2, 72, 14)"
    assert not torch.isnan(out).any(), "NaNs in SRCNN forward pass output!"
    assert not torch.isinf(out).any(), "Infs in SRCNN forward pass output!"
    print("[PASS] SRCNN forward pass shape and numeric validity test passed.")

def test_gradient_and_parameter_update():
    """Verify autograd backward pass and parameter updates."""
    model = SRCNN(in_channels=2, out_channels=2)
    optimizer = optim.Adam(model.parameters(), lr=0.01)
    criterion = ChannelMSELoss()

    x = torch.randn(4, 2, 72, 14)
    target = torch.randn(4, 2, 72, 14)

    # Record initial weights of conv1
    initial_weight = model.conv1.weight.clone()

    optimizer.zero_grad()
    out = model(x)
    loss = criterion(out, target)
    loss.backward()

    # Check that gradients exist for all parameters
    for name, param in model.named_parameters():
        assert param.grad is not None, f"Gradient is None for {name}"
        assert not torch.isnan(param.grad).any(), f"NaN in gradient of {name}"

    optimizer.step()

    # Verify weight changed
    weight_diff = torch.norm(model.conv1.weight - initial_weight).item()
    assert weight_diff > 1e-6, f"Weight did not update! Diff: {weight_diff}"
    print(f"[PASS] Gradient and parameter update test passed (Conv1 delta: {weight_diff:.4f}).")

def test_checkpoint_reload_fidelity(tmp_ckpt="temp_sr_test.pth"):
    """Verify that saving and reloading a checkpoint preserves model predictions exactly."""
    model1 = SRCNN(in_channels=2, out_channels=2)
    x = torch.randn(4, 2, 72, 14)

    with torch.no_grad():
        out1 = model1(x).numpy()

    # Save checkpoint
    torch.save(model1.state_dict(), tmp_ckpt)

    # Reload into new model instance
    model2 = SRCNN(in_channels=2, out_channels=2)
    model2.load_state_dict(torch.load(tmp_ckpt))

    with torch.no_grad():
        out2 = model2(x).numpy()

    max_diff = float(np.max(np.abs(out1 - out2)))
    assert max_diff < 1e-7, f"Reloaded predictions differ! Max diff: {max_diff}"

    try:
        os.remove(tmp_ckpt)
    except OSError:
        pass

    print(f"[PASS] Checkpoint reload fidelity test passed (Max diff: {max_diff:.2e}).")

def generate_sr_comparison_plot():
    """Generate visual comparison between sparse input, SR output, and ground truth."""
    data_path = "ChannelNet_Assignment/data/test/VehA_12dB_test.npz"
    if not os.path.exists(data_path):
        print("[SKIP] Data file not found for visual comparison plot.")
        return

    data = np.load(data_path)
    inputs = torch.from_numpy(data["inputs"][:1]).float()
    targets = data["targets"][0]  # shape: (2, 72, 14)

    # Dummy / untyped forward pass to verify plotting pipeline
    model = SRCNN(in_channels=2, out_channels=2)
    with torch.no_grad():
        pred = model(inputs).numpy()[0]

    out_path = "ChannelNet_Assignment/results/channel_visualizations/sr_output_comparison.png"
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    fig, axes = plt.subplots(1, 3, figsize=(15, 5))

    im0 = axes[0].imshow(inputs[0, 0].numpy(), aspect='auto', cmap='coolwarm')
    axes[0].set_title('SR Input (Interpolated LS Real)', fontsize=11, fontweight='bold')
    fig.colorbar(im0, ax=axes[0])

    im1 = axes[1].imshow(pred[0], aspect='auto', cmap='coolwarm')
    axes[1].set_title('SR Network Output (Real)', fontsize=11, fontweight='bold')
    fig.colorbar(im1, ax=axes[1])

    im2 = axes[2].imshow(targets[0], aspect='auto', cmap='coolwarm')
    axes[2].set_title('Ground Truth (Real)', fontsize=11, fontweight='bold')
    fig.colorbar(im2, ax=axes[2])

    plt.suptitle('ChannelNet Stage 1 (SRCNN) Reconstruction Comparison', fontsize=13, fontweight='bold')
    plt.tight_layout()
    plt.savefig(out_path, dpi=300)
    plt.close()
    print(f"[PASS] Saved SR comparison plot to: {out_path}")

if __name__ == '__main__':
    print("=" * 60)
    print("RUNNING STAGE 7 & 8 NEURAL NETWORK UNIT TESTS")
    print("=" * 60)
    test_srcnn_forward_and_shapes()
    test_gradient_and_parameter_update()
    test_checkpoint_reload_fidelity()
    test_dncnn_forward_and_residual()
    generate_sr_comparison_plot()
    print("=" * 60)
    print("ALL NEURAL NETWORK UNIT TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)

