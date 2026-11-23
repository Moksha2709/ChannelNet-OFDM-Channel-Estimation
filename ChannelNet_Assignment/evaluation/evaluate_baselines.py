"""
Baseline Evaluation Script
Evaluates LS-Interpolation and LMMSE across SNR values and pilot densities
for both VehA and SUI5 channel models.
Saves numerical MSE results to CSV files.
"""

import os
import sys
import numpy as np
import pandas as pd
from typing import Dict, List

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from ofdm.ofdm_transmitter import OFDMTransmitter
from ofdm.pilot_generation import PilotGenerator
from ofdm.ofdm_channel import OFDMChannel
from simulator.channel_generation import ChannelGenerator
from estimation.ls_estimation import LSEstimator
from estimation.interpolation import InterpolationEstimator
from estimation.mmse_estimation import MMSEEstimator

def evaluate_model_snr_sweep(
    channel_model: str = "VehA",
    snr_list: List[float] = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0],
    num_frames: int = 200,
    num_pilots: int = 48,
    seed: int = 9999
) -> pd.DataFrame:
    """
    Evaluates LS-Linear, LS-Cubic, and Ideal LMMSE estimators over an SNR sweep.
    Returns DataFrame of average MSE per SNR.
    """
    pg = PilotGenerator()
    tx = OFDMTransmitter(seed=seed)
    ch_sim = OFDMChannel(seed=seed + 100)
    cg = ChannelGenerator(seed=seed + 200)
    ls_est = LSEstimator()
    interp_linear = InterpolationEstimator(method="linear")
    interp_cubic = InterpolationEstimator(method="cubic")
    mmse_est = MMSEEstimator(channel_model=channel_model)

    mask = pg.get_pilot_mask(num_pilots)
    pilot_val = 1.0 + 0j

    results = []

    # Pre-generate channels for fair, identical comparison
    channels = [cg.generate_single_channel(channel_model) for _ in range(num_frames)]

    for snr in snr_list:
        mse_ls_lin = []
        mse_ls_cub = []
        mse_mmse = []

        for h_true in channels:
            data = tx.generate_random_qpsk()
            tx_grid = pg.insert_pilots(data, mask, pilot_value=pilot_val)
            y_grid, _ = ch_sim.apply_channel_2d(tx_grid, h_true, snr_db=snr)

            h_ls = ls_est.get_sparse_ls_grid(y_grid, tx_grid, mask, fill_value=0.0)

            # 1. LS with Linear Interpolation
            h_lin = interp_linear.estimate(h_ls, mask)
            mse_ls_lin.append(np.mean(np.abs(h_true - h_lin) ** 2))

            # 2. LS with Cubic Interpolation
            h_cub = interp_cubic.estimate(h_ls, mask)
            mse_ls_cub.append(np.mean(np.abs(h_true - h_cub) ** 2))

            # 3. Ideal LMMSE
            h_m = mmse_est.estimate(h_ls, mask, snr_db=snr)
            mse_mmse.append(np.mean(np.abs(h_true - h_m) ** 2))

        avg_lin = float(np.mean(mse_ls_lin))
        avg_cub = float(np.mean(mse_ls_cub))
        avg_mmse = float(np.mean(mse_mmse))

        print(f"[{channel_model}] SNR: {snr:4.1f} dB | LS-Linear: {avg_lin:.6f} | LS-Cubic: {avg_cub:.6f} | Ideal MMSE: {avg_mmse:.6f}")
        results.append({
            "SNR_dB": snr,
            "LS_Linear_MSE": avg_lin,
            "LS_Cubic_MSE": avg_cub,
            "MMSE_MSE": avg_mmse,
            "Channel_Model": channel_model,
            "Num_Pilots": num_pilots
        })

    df = pd.DataFrame(results)
    return df

def run_all_baseline_evaluations():
    out_dir = "ChannelNet_Assignment/results/comparison_tables"
    os.makedirs(out_dir, exist_ok=True)

    print("=" * 60)
    print("RUNNING BASELINE EVALUATION FOR VehA (48 Pilots)...")
    print("=" * 60)
    df_veha = evaluate_model_snr_sweep("VehA", num_frames=200, num_pilots=48, seed=123)
    df_veha.to_csv(f"{out_dir}/baseline_mse_veha.csv", index=False)

    print("=" * 60)
    print("RUNNING BASELINE EVALUATION FOR SUI5 (48 Pilots)...")
    print("=" * 60)
    df_sui5 = evaluate_model_snr_sweep("SUI5", num_frames=200, num_pilots=48, seed=456)
    df_sui5.to_csv(f"{out_dir}/baseline_mse_sui5.csv", index=False)

    print("=" * 60)
    print("BASELINE EVALUATIONS COMPLETE. Results saved to:", out_dir)
    print("=" * 60)

if __name__ == '__main__':
    run_all_baseline_evaluations()
