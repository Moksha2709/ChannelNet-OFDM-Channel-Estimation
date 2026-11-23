"""
Unit and Verification Tests for LS Channel Estimation and AWGN (Stage 4)
Verifies:
1. LS estimates in noiseless known-channel case (MSE < 1e-24).
2. Theoretical vs. empirical MSE scaling across SNRs: E{|H_LS - H|^2} == sigma_n^2.
3. Proper sparsity and pilot-only existence in sparse grid.
4. Data shapes and complex values.
5. Generates visualization: results/channel_visualizations/sparse_ls_vs_ground_truth.png.
"""

import os
import sys
import numpy as np
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from ofdm.ofdm_transmitter import OFDMTransmitter
from ofdm.pilot_generation import PilotGenerator
from ofdm.ofdm_channel import OFDMChannel
from simulator.channel_generation import ChannelGenerator
from estimation.ls_estimation import LSEstimator

def test_noiseless_ls():
    """Verify that under noiseless transmission, LS estimates match ground truth exactly."""
    pg = PilotGenerator()
    tx = OFDMTransmitter(seed=12)
    ch_sim = OFDMChannel(seed=34)
    cg = ChannelGenerator(seed=56)
    ls_est = LSEstimator()

    mask = pg.get_pilot_mask(48)
    data = tx.generate_random_qpsk()
    tx_grid = pg.insert_pilots(data, mask, pilot_value=1.0 + 0j)

    h_true = cg.generate_single_channel('VehA')
    y_grid, _ = ch_sim.apply_channel_2d(tx_grid, h_true, snr_db=None)

    h_ls_vec = ls_est.estimate_at_pilots(y_grid, tx_grid, mask)
    h_true_vec = h_true[mask]

    max_err = float(np.max(np.abs(h_ls_vec - h_true_vec)))
    mse = float(np.mean(np.abs(h_ls_vec - h_true_vec) ** 2))
    print(f"Noiseless LS Max Error: {max_err:.2e}, MSE: {mse:.2e}")
    assert max_err < 1e-14, f"Noiseless LS error {max_err} too high!"
    print("[PASS] Noiseless LS estimation verified.")

def test_snr_scaling():
    """Verify that pilot-location LS MSE matches theoretical noise variance across SNRs."""
    pg = PilotGenerator()
    tx = OFDMTransmitter(seed=100)
    ch_sim = OFDMChannel(seed=200)
    cg = ChannelGenerator(seed=300)
    ls_est = LSEstimator()

    mask = pg.get_pilot_mask(48)
    data = tx.generate_random_qpsk()
    tx_grid = pg.insert_pilots(data, mask, pilot_value=1.0 + 0j)

    snr_list = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0]
    num_trials = 2000

    print("Testing LS MSE scaling across SNRs (2000 frames per SNR):")
    for snr in snr_list:
        expected_var = 1.0 / (10.0 ** (snr / 10.0))
        errs = []
        for _ in range(num_trials):
            h_true = cg.generate_single_channel('VehA')
            y_grid, _ = ch_sim.apply_channel_2d(tx_grid, h_true, snr_db=snr)
            h_ls_vec = ls_est.estimate_at_pilots(y_grid, tx_grid, mask)
            errs.append(np.mean(np.abs(h_ls_vec - h_true[mask]) ** 2))

        measured_mse = float(np.mean(errs))
        rel_err = abs(measured_mse - expected_var) / expected_var
        print(f"SNR: {snr:4.1f} dB | Theoretical: {expected_var:8.6f} | Measured MSE: {measured_mse:8.6f} | RelErr: {rel_err:.2%}")
        assert rel_err < 0.05, f"RelErr {rel_err:.2%} exceeds 5% tolerance at SNR {snr} dB!"

    print("[PASS] LS error scaling with SNR verified.")

def test_sparse_representation():
    """Verify sparse grid shapes, pilot locations, and zero/NaN fillings."""
    pg = PilotGenerator()
    ls_est = LSEstimator()

    mask = pg.get_pilot_mask(48)
    tx_grid = np.ones((72, 14), dtype=np.complex128)
    y_grid = 2.0 * np.ones((72, 14), dtype=np.complex128)

    sparse_zero = ls_est.get_sparse_ls_grid(y_grid, tx_grid, mask, fill_value=0.0)
    assert sparse_zero.shape == (72, 14)
    assert np.count_nonzero(sparse_zero) == 48
    assert np.all(sparse_zero[mask] == 2.0)
    assert np.all(sparse_zero[~mask] == 0.0)

    sparse_nan = ls_est.get_sparse_ls_grid(y_grid, tx_grid, mask, fill_value=np.nan)
    assert np.count_nonzero(np.isnan(sparse_nan)) == (72 * 14 - 48)
    print("[PASS] Sparse grid representation check passed.")

def generate_visualization():
    """Generates visual comparison between sparse LS estimates and true channel."""
    pg = PilotGenerator()
    tx = OFDMTransmitter(seed=42)
    ch_sim = OFDMChannel(seed=42)
    cg = ChannelGenerator(seed=42)
    ls_est = LSEstimator()

    mask = pg.get_pilot_mask(48)
    data = tx.generate_random_qpsk()
    tx_grid = pg.insert_pilots(data, mask, pilot_value=1.0 + 0j)

    h_true = cg.generate_single_channel('VehA')
    snr_db = 15.0
    y_grid, _ = ch_sim.apply_channel_2d(tx_grid, h_true, snr_db=snr_db)
    h_ls_sparse = ls_est.get_sparse_ls_grid(y_grid, tx_grid, mask, fill_value=0.0)

    out_path = 'ChannelNet_Assignment/results/channel_visualizations/sparse_ls_vs_ground_truth.png'
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    # True Real
    im0 = axes[0, 0].imshow(h_true.real, aspect='auto', cmap='coolwarm')
    axes[0, 0].set_title('Ground-Truth Real Channel H_true', fontsize=12, fontweight='bold')
    axes[0, 0].set_xlabel('OFDM Symbol Index n')
    axes[0, 0].set_ylabel('Subcarrier Index k')
    fig.colorbar(im0, ax=axes[0, 0])

    # Sparse LS Real
    # Show pilots with non-zero values against a neutral background
    sparse_disp_real = np.ma.masked_where(~mask, h_ls_sparse.real)
    axes[0, 1].set_facecolor('#dcdcdc')
    im1 = axes[0, 1].imshow(sparse_disp_real, aspect='auto', cmap='coolwarm')
    axes[0, 1].set_title(f'Sparse LS Estimates (Real Part, SNR = {snr_db} dB, 48 Pilots)', fontsize=12, fontweight='bold')
    axes[0, 1].set_xlabel('OFDM Symbol Index n')
    axes[0, 1].set_ylabel('Subcarrier Index k')
    fig.colorbar(im1, ax=axes[0, 1])

    # True Imag
    im2 = axes[1, 0].imshow(h_true.imag, aspect='auto', cmap='coolwarm')
    axes[1, 0].set_title('Ground-Truth Imaginary Channel H_true', fontsize=12, fontweight='bold')
    axes[1, 0].set_xlabel('OFDM Symbol Index n')
    axes[1, 0].set_ylabel('Subcarrier Index k')
    fig.colorbar(im2, ax=axes[1, 0])

    # Sparse LS Imag
    sparse_disp_imag = np.ma.masked_where(~mask, h_ls_sparse.imag)
    axes[1, 1].set_facecolor('#dcdcdc')
    im3 = axes[1, 1].imshow(sparse_disp_imag, aspect='auto', cmap='coolwarm')
    axes[1, 1].set_title(f'Sparse LS Estimates (Imag Part, SNR = {snr_db} dB, 48 Pilots)', fontsize=12, fontweight='bold')
    axes[1, 1].set_xlabel('OFDM Symbol Index n')
    axes[1, 1].set_ylabel('Subcarrier Index k')
    fig.colorbar(im3, ax=axes[1, 1])

    plt.suptitle('Sparse LS Channel Observations vs. Ground Truth (Stage 4)', fontsize=14, fontweight='bold')
    plt.tight_layout()
    plt.savefig(out_path, dpi=300)
    plt.close()
    print(f"[PASS] Saved sparse LS visualization to {out_path}")

if __name__ == '__main__':
    print("=" * 60)
    print("RUNNING STAGE 4 LS ESTIMATION TEST SUITE")
    print("=" * 60)
    test_noiseless_ls()
    test_snr_scaling()
    test_sparse_representation()
    generate_visualization()
    print("=" * 60)
    print("ALL STAGE 4 TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)

