"""
Stage 1 Unit and Regression Tests for OFDM System
Verifies:
1. Transmitter output dimensions (frequency and time domain).
2. Receiver output dimensions.
3. Noiseless round-trip reconstruction accuracy (MSE < 1e-24).
4. Known channel response verification: Y(k, n) = H(k, n) * X(k, n).
5. AWGN noise variance and SNR calibration accuracy.
6. Visual generation of transmitted vs. received constellation and grids.
"""

import os
import sys
import numpy as np
import matplotlib.pyplot as plt

# Ensure parent directory is in python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from ofdm.ofdm_transmitter import OFDMTransmitter
from ofdm.ofdm_receiver import OFDMReceiver
from ofdm.ofdm_channel import OFDMChannel

def test_dimensions():
    """Verify transmitter and receiver output dimensions."""
    tx = OFDMTransmitter(num_subcarriers=72, num_symbols=14, fft_size=128, cp_length=9, seed=42)
    rx = OFDMReceiver(num_subcarriers=72, num_symbols=14, fft_size=128, cp_length=9)

    x = tx.generate_random_qpsk()
    assert x.shape == (72, 14), f"Unexpected QPSK shape: {x.shape}"

    waveform, symbols_cp = tx.modulate(x)
    expected_waveform_len = 14 * (128 + 9)  # 1918 samples
    assert len(waveform) == expected_waveform_len, f"Waveform length {len(waveform)} != {expected_waveform_len}"
    assert symbols_cp.shape == (137, 14), f"Symbols with CP shape {symbols_cp.shape} != (137, 14)"

    y = rx.demodulate(waveform)
    assert y.shape == (72, 14), f"Recovered grid shape {y.shape} != (72, 14)"
    print("[PASS] Dimension test succeeded.")

def test_noiseless_roundtrip():
    """Verify that in noiseless back-to-back transmission, Y == X with numerical precision."""
    tx = OFDMTransmitter(num_subcarriers=72, num_symbols=14, fft_size=128, cp_length=9, seed=123)
    rx = OFDMReceiver(num_subcarriers=72, num_symbols=14, fft_size=128, cp_length=9)

    x = tx.generate_random_qpsk()
    waveform, _ = tx.modulate(x)
    y = rx.demodulate(waveform)

    max_err = float(np.max(np.abs(y - x)))
    mse = float(np.mean(np.abs(y - x) ** 2))

    print(f"Noiseless roundtrip max error: {max_err:.2e}, MSE: {mse:.2e}")
    assert max_err < 1e-12, f"Noiseless max error {max_err} too high!"
    assert mse < 1e-24, f"Noiseless MSE {mse} too high!"
    print("[PASS] Noiseless round-trip test succeeded.")

def test_known_channel():
    """Verify Y(k, n) = H(k, n) * X(k, n) across all subcarriers and symbols."""
    tx = OFDMTransmitter(seed=456)
    channel = OFDMChannel(seed=789)

    x = tx.generate_random_qpsk()
    # Create deterministic known channel
    h = np.exp(1j * np.linspace(0, 2 * np.pi, 72)[:, None]) * np.linspace(0.5, 1.5, 14)[None, :]
    y, _ = channel.apply_channel_2d(x, h, snr_db=None)

    # Recover channel by zero-forcing division
    h_recovered = y / x
    max_err = float(np.max(np.abs(h_recovered - h)))
    assert max_err < 1e-14, f"Known channel recovery error {max_err:.2e} too high!"
    print(f"[PASS] Known channel test succeeded (Max Error: {max_err:.2e}).")

def test_awgn_variance():
    """Verify that AWGN noise variance matches theoretical SNR across 100,000 samples."""
    channel = OFDMChannel(seed=42)
    snr_db = 15.0
    signal = np.ones((1000, 100), dtype=np.complex128)  # E_s = 1.0

    noisy, noise_var = channel.add_awgn(signal, snr_db=snr_db, signal_power=1.0)
    measured_noise = noisy - signal
    measured_var = float(np.mean(np.abs(measured_noise) ** 2))

    expected_var = 1.0 / (10.0 ** (snr_db / 10.0))
    rel_error = abs(measured_var - expected_var) / expected_var
    print(f"AWGN Test at {snr_db} dB -> Expected var: {expected_var:.6f}, Measured: {measured_var:.6f}, RelErr: {rel_error:.2%}")
    assert rel_error < 0.02, f"Noise variance relative error {rel_error:.2%} exceeds 2% tolerance!"
    print("[PASS] AWGN variance calibration test succeeded.")

def generate_visualization():
    """Generate transmitted and received frequency grid and constellation plot."""
    tx = OFDMTransmitter(seed=999)
    rx = OFDMReceiver()
    channel = OFDMChannel(seed=999)

    x = tx.generate_random_qpsk()
    waveform, _ = tx.modulate(x)

    # Channel with multipath fading + noise at 20 dB
    h = np.exp(1j * np.linspace(0, 3 * np.pi, 72)[:, None]) * np.linspace(0.8, 1.2, 14)[None, :]
    y_freq, _ = channel.apply_channel_2d(x, h, snr_db=20.0)

    os.makedirs('ChannelNet_Assignment/results/channel_visualizations', exist_ok=True)
    out_path = 'ChannelNet_Assignment/results/channel_visualizations/ofdm_grid_validation.png'

    fig, axes = plt.subplots(2, 2, figsize=(12, 10))

    # Transmitted grid magnitude
    im0 = axes[0, 0].imshow(np.abs(x), aspect='auto', cmap='viridis')
    axes[0, 0].set_title('Transmitted Frequency Grid |X(k, n)|')
    axes[0, 0].set_xlabel('OFDM Symbol Index n')
    axes[0, 0].set_ylabel('Subcarrier Index k')
    fig.colorbar(im0, ax=axes[0, 0])

    # Received grid magnitude
    im1 = axes[0, 1].imshow(np.abs(y_freq), aspect='auto', cmap='plasma')
    axes[0, 1].set_title('Received Frequency Grid |Y(k, n)| (SNR = 20 dB)')
    axes[0, 1].set_xlabel('OFDM Symbol Index n')
    axes[0, 1].set_ylabel('Subcarrier Index k')
    fig.colorbar(im1, ax=axes[0, 1])

    # Transmitted constellation
    axes[1, 0].scatter(x.real.flatten(), x.imag.flatten(), color='blue', alpha=0.5, s=15)
    axes[1, 0].set_title('Transmitted QPSK Constellation (Es = 1)')
    axes[1, 0].set_xlabel('In-Phase (I)')
    axes[1, 0].set_ylabel('Quadrature (Q)')
    axes[1, 0].grid(True, linestyle='--', alpha=0.6)
    axes[1, 0].set_xlim(-1.5, 1.5)
    axes[1, 0].set_ylim(-1.5, 1.5)

    # Equalized constellation (Zero-Forcing: Y / H)
    x_hat = y_freq / h
    axes[1, 1].scatter(x_hat.real.flatten(), x_hat.imag.flatten(), color='red', alpha=0.5, s=15)
    axes[1, 1].set_title('Equalized Constellation (ZF with ideal H, SNR = 20 dB)')
    axes[1, 1].set_xlabel('In-Phase (I)')
    axes[1, 1].set_ylabel('Quadrature (Q)')
    axes[1, 1].grid(True, linestyle='--', alpha=0.6)
    axes[1, 1].set_xlim(-1.5, 1.5)
    axes[1, 1].set_ylim(-1.5, 1.5)

    plt.tight_layout()
    plt.savefig(out_path, dpi=300)
    plt.close()
    print(f"[PASS] Saved OFDM visualization to {out_path}")

if __name__ == '__main__':
    print("=" * 60)
    print("RUNNING STAGE 1 OFDM VERIFICATION SUITE")
    print("=" * 60)
    test_dimensions()
    test_noiseless_roundtrip()
    test_known_channel()
    test_awgn_variance()
    generate_visualization()
    print("=" * 60)
    print("ALL STAGE 1 TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)

