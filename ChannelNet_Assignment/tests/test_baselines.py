"""
Stage 6 Unit Tests for Conventional Baseline Estimators
Verifies:
1. Interpolation estimator dimensions and lack of NaNs.
2. MMSE estimator dimensions, numerical stability, and lack of NaNs.
3. Superiority of Ideal MMSE over LS interpolation at low-to-mid SNR.
4. Evaluation across full 72x14 time-frequency grid.
"""

import os
import sys
import numpy as np

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from ofdm.pilot_generation import PilotGenerator
from ofdm.ofdm_transmitter import OFDMTransmitter
from ofdm.ofdm_channel import OFDMChannel
from simulator.channel_generation import ChannelGenerator
from estimation.ls_estimation import LSEstimator
from estimation.interpolation import InterpolationEstimator
from estimation.mmse_estimation import MMSEEstimator

def test_interpolation_estimator():
    """Verify interpolation estimator output shapes and no NaNs."""
    pg = PilotGenerator()
    tx = OFDMTransmitter(seed=1)
    ch_sim = OFDMChannel(seed=2)
    cg = ChannelGenerator(seed=3)
    ls_est = LSEstimator()
    interp = InterpolationEstimator(method="linear")

    mask = pg.get_pilot_mask(48)
    data = tx.generate_random_qpsk()
    tx_grid = pg.insert_pilots(data, mask)

    h_true = cg.generate_single_channel('VehA')
    y_grid, _ = ch_sim.apply_channel_2d(tx_grid, h_true, snr_db=15.0)

    h_ls = ls_est.get_sparse_ls_grid(y_grid, tx_grid, mask, fill_value=0.0)
    h_est = interp.estimate(h_ls, mask)

    assert h_est.shape == (72, 14), f"Interpolated shape {h_est.shape} != (72, 14)"
    assert not np.isnan(h_est).any(), "NaNs found in interpolated grid!"
    assert not np.isinf(h_est).any(), "Infs found in interpolated grid!"
    print("[PASS] Interpolation estimator test passed.")

def test_mmse_estimator():
    """Verify MMSE estimator output shapes, numerical stability, and lack of NaNs."""
    pg = PilotGenerator()
    tx = OFDMTransmitter(seed=10)
    ch_sim = OFDMChannel(seed=20)
    cg = ChannelGenerator(seed=30)
    ls_est = LSEstimator()
    mmse = MMSEEstimator(channel_model='VehA')

    mask = pg.get_pilot_mask(48)
    data = tx.generate_random_qpsk()
    tx_grid = pg.insert_pilots(data, mask)

    h_true = cg.generate_single_channel('VehA')
    y_grid, _ = ch_sim.apply_channel_2d(tx_grid, h_true, snr_db=10.0)

    h_ls = ls_est.get_sparse_ls_grid(y_grid, tx_grid, mask, fill_value=0.0)
    h_est = mmse.estimate(h_ls, mask, snr_db=10.0)

    assert h_est.shape == (72, 14), f"MMSE shape {h_est.shape} != (72, 14)"
    assert not np.isnan(h_est).any(), "NaNs found in MMSE grid!"
    assert not np.isinf(h_est).any(), "Infs found in MMSE grid!"
    print("[PASS] MMSE estimator numerical stability and dimension test passed.")

def test_mmse_vs_ls_superiority():
    """Verify that Ideal MMSE achieves strictly lower MSE than LS interpolation at low SNR (e.g. 5 dB)."""
    pg = PilotGenerator()
    tx = OFDMTransmitter(seed=42)
    ch_sim = OFDMChannel(seed=43)
    cg = ChannelGenerator(seed=44)
    ls_est = LSEstimator()
    interp = InterpolationEstimator(method="linear")
    mmse = MMSEEstimator(channel_model='VehA')

    mask = pg.get_pilot_mask(48)
    snr_db = 5.0

    mse_ls = []
    mse_mmse = []

    for _ in range(50):
        h_true = cg.generate_single_channel('VehA')
        data = tx.generate_random_qpsk()
        tx_grid = pg.insert_pilots(data, mask)
        y_grid, _ = ch_sim.apply_channel_2d(tx_grid, h_true, snr_db=snr_db)

        h_ls = ls_est.get_sparse_ls_grid(y_grid, tx_grid, mask, fill_value=0.0)
        h_interp = interp.estimate(h_ls, mask)
        h_m = mmse.estimate(h_ls, mask, snr_db=snr_db)

        mse_ls.append(np.mean(np.abs(h_true - h_interp) ** 2))
        mse_mmse.append(np.mean(np.abs(h_true - h_m) ** 2))

    avg_mse_ls = float(np.mean(mse_ls))
    avg_mse_mmse = float(np.mean(mse_mmse))

    print(f"At SNR = {snr_db} dB: Average LS-Interp MSE = {avg_mse_ls:.5f}, Ideal MMSE MSE = {avg_mse_mmse:.5f}")
    assert avg_mse_mmse < avg_mse_ls, f"Expected MMSE ({avg_mse_mmse}) < LS ({avg_mse_ls})"
    print("[PASS] Ideal MMSE superiority over LS interpolation confirmed.")

if __name__ == '__main__':
    print("=" * 60)
    print("RUNNING STAGE 6 BASELINE ESTIMATOR TEST SUITE")
    print("=" * 60)
    test_interpolation_estimator()
    test_mmse_estimator()
    test_mmse_vs_ls_superiority()
    print("=" * 60)
    print("ALL STAGE 6 TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)

