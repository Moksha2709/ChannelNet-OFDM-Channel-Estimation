"""
Complete Performance Evaluation Pipeline (Stages 10 & 11)
Sweeps testing SNRs [0, 5, 10, 12, 15, 20, 22, 25] dB and evaluates:
1. LS Linear Interpolation
2. LS Cubic Interpolation
3. Ideal LMMSE
4. ChannelNet trained at 12 dB (Deep Low-SNR)
5. ChannelNet trained at 22 dB (Deep High-SNR)

Also evaluates pilot densities [24, 48, 72] at fixed SNR = 20 dB.
Saves CSV result tables and calls generate_plots to replicate Figures 3, 4, 5.
"""

import os
import sys
import numpy as np
import pandas as pd
import torch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from models.channelnet import ChannelNet
from estimation.interpolation import InterpolationEstimator
from estimation.mmse_estimation import MMSEEstimator
from ofdm.pilot_generation import PilotGenerator
from ofdm.ofdm_transmitter import OFDMTransmitter
from ofdm.ofdm_channel import OFDMChannel
from simulator.channel_generation import ChannelGenerator
from estimation.ls_estimation import LSEstimator
from data.normalization import ChannelNormalizer
from evaluation.calculate_mse import calculate_grid_mse, linear_to_db
from evaluation.generate_plots import plot_mse_vs_snr, plot_pilot_density

def evaluate_channel_model(
    channel_model: str,
    snr_list: list = [0.0, 5.0, 10.0, 12.0, 15.0, 20.0, 22.0, 25.0],
    num_test_frames: int = 200,
    num_pilots: int = 48,
    seed: int = 7777,
    checkpoint_dir: str = "ChannelNet_Assignment/checkpoints"
) -> pd.DataFrame:
    """
    Evaluates all estimators across testing SNRs on identical test channels.
    """
    pg = PilotGenerator()
    tx = OFDMTransmitter(seed=seed)
    ch_sim = OFDMChannel(seed=seed + 1)
    cg = ChannelGenerator(seed=seed + 2)
    ls_est = LSEstimator()
    interp_lin = InterpolationEstimator(method="linear")
    interp_cub = InterpolationEstimator(method="cubic")
    mmse = MMSEEstimator(channel_model=channel_model)

    mask = pg.get_pilot_mask(num_pilots)
    pilot_val = 1.0 + 0j

    # Load ChannelNet models
    sr_12_path = f"{checkpoint_dir}/sr/srcnn_{channel_model}_12dB_best.pth"
    dn_12_path = f"{checkpoint_dir}/dncnn/dncnn_{channel_model}_12dB_best.pth"
    cn_12 = ChannelNet.from_checkpoints(sr_12_path, dn_12_path)

    sr_22_path = f"{checkpoint_dir}/sr/srcnn_{channel_model}_22dB_best.pth"
    dn_22_path = f"{checkpoint_dir}/dncnn/dncnn_{channel_model}_22dB_best.pth"
    cn_22 = ChannelNet.from_checkpoints(sr_22_path, dn_22_path)

    # Pre-generate channels for fair, identical comparison
    channels = [cg.generate_single_channel(channel_model) for _ in range(num_test_frames)]

    # Fit a standard normalizer across true channels
    all_targets = np.stack([
        np.stack([h.real, h.imag], axis=0) for h in channels
    ], axis=0).astype(np.float32)

    norm_12 = ChannelNormalizer(mode="minmax")
    norm_12.fit(all_targets)
    norm_22 = ChannelNormalizer(mode="minmax")
    norm_22.fit(all_targets)

    records = []

    print(f"\n=======================================================")
    print(f"EVALUATING ALL ESTIMATORS FOR {channel_model} ({num_test_frames} FRAMES)")
    print(f"=======================================================")

    for snr in snr_list:
        mse_lin = []
        mse_cub = []
        mse_m = []
        mse_cn12 = []
        mse_cn22 = []

        for h_true in channels:
            data = tx.generate_random_qpsk()
            tx_grid = pg.insert_pilots(data, mask, pilot_value=pilot_val)
            y_grid, _ = ch_sim.apply_channel_2d(tx_grid, h_true, snr_db=snr)

            h_ls = ls_est.get_sparse_ls_grid(y_grid, tx_grid, mask, fill_value=0.0)

            # LS Linear
            h_lin = interp_lin.estimate(h_ls, mask)
            mse_lin.append(calculate_grid_mse(h_true, h_lin))

            # LS Cubic
            h_cub = interp_cub.estimate(h_ls, mask)
            mse_cub.append(calculate_grid_mse(h_true, h_cub))

            # MMSE
            h_mmse = mmse.estimate(h_ls, mask, snr_db=snr)
            mse_m.append(calculate_grid_mse(h_true, h_mmse))

            # ChannelNet 12 dB
            _, h_f12 = cn_12.estimate_complex(h_ls, mask, normalizer=norm_12)
            mse_cn12.append(calculate_grid_mse(h_true, h_f12))

            # ChannelNet 22 dB
            _, h_f22 = cn_22.estimate_complex(h_ls, mask, normalizer=norm_22)
            mse_cn22.append(calculate_grid_mse(h_true, h_f22))

        avg_lin = float(np.mean(mse_lin))
        avg_cub = float(np.mean(mse_cub))
        avg_mmse = float(np.mean(mse_m))
        avg_cn12 = float(np.mean(mse_cn12))
        avg_cn22 = float(np.mean(mse_cn22))

        print(f"SNR: {snr:4.1f} dB | LS-Lin: {avg_lin:.5f} | MMSE: {avg_mmse:.5f} | CN-12dB: {avg_cn12:.5f} | CN-22dB: {avg_cn22:.5f}")

        records.append({
            "SNR_dB": snr,
            "LS_Linear_MSE": avg_lin,
            "LS_Cubic_MSE": avg_cub,
            "MMSE_MSE": avg_mmse,
            "ChannelNet_12dB_MSE": avg_cn12,
            "ChannelNet_22dB_MSE": avg_cn22,
            "Channel_Model": channel_model,
            "Num_Pilots": num_pilots
        })

    return pd.DataFrame(records)

def evaluate_pilot_density_sweep(
    channel_model: str = "VehA",
    snr_fixed: float = 20.0,
    pilot_counts: list = [24, 48, 72],
    num_test_frames: int = 200,
    seed: int = 8888,
    checkpoint_dir: str = "ChannelNet_Assignment/checkpoints"
) -> dict:
    """
    Evaluates MSE vs Number of Pilots at SNR = 20 dB, replicating Fig. 5.
    """
    pg = PilotGenerator()
    tx = OFDMTransmitter(seed=seed)
    ch_sim = OFDMChannel(seed=seed + 1)
    cg = ChannelGenerator(seed=seed + 2)
    ls_est = LSEstimator()
    interp_lin = InterpolationEstimator(method="linear")
    mmse = MMSEEstimator(channel_model=channel_model)

    sr_path = f"{checkpoint_dir}/sr/srcnn_{channel_model}_22dB_best.pth"
    dn_path = f"{checkpoint_dir}/dncnn/dncnn_{channel_model}_22dB_best.pth"
    cn_model = ChannelNet.from_checkpoints(sr_path, dn_path)

    channels = [cg.generate_single_channel(channel_model) for _ in range(num_test_frames)]
    all_targets = np.stack([
        np.stack([h.real, h.imag], axis=0) for h in channels
    ], axis=0).astype(np.float32)
    norm = ChannelNormalizer(mode="minmax")
    norm.fit(all_targets)

    pilot_results = {}

    print(f"\n=======================================================")
    print(f"EVALUATING PILOT DENSITIES AT SNR = {snr_fixed} dB ({channel_model})")
    print(f"=======================================================")

    for p_count in pilot_counts:
        mask = pg.get_pilot_mask(p_count)
        mse_lin = []
        mse_m = []
        mse_cn = []

        for h_true in channels:
            data = tx.generate_random_qpsk()
            tx_grid = pg.insert_pilots(data, mask, pilot_value=1.0 + 0j)
            y_grid, _ = ch_sim.apply_channel_2d(tx_grid, h_true, snr_db=snr_fixed)

            h_ls = ls_est.get_sparse_ls_grid(y_grid, tx_grid, mask, fill_value=0.0)

            # LS Linear
            h_l = interp_lin.estimate(h_ls, mask)
            mse_lin.append(calculate_grid_mse(h_true, h_l))

            # MMSE
            h_mm = mmse.estimate(h_ls, mask, snr_db=snr_fixed)
            mse_m.append(calculate_grid_mse(h_true, h_mm))

            # ChannelNet
            _, h_f = cn_model.estimate_complex(h_ls, mask, normalizer=norm)
            mse_cn.append(calculate_grid_mse(h_true, h_f))

        avg_l = float(np.mean(mse_lin))
        avg_m = float(np.mean(mse_m))
        avg_c = float(np.mean(mse_cn))

        print(f"Pilots: {p_count:2d} | LS-Linear: {avg_l:.6f} | MMSE: {avg_m:.6f} | ChannelNet: {avg_c:.6f}")
        pilot_results[p_count] = {
            "LS": avg_l,
            "MMSE": avg_m,
            "ChannelNet": avg_c
        }

    return pilot_results

def run_all_evaluations_and_generate_plots():
    out_tables = "ChannelNet_Assignment/results/comparison_tables"
    out_plots = "ChannelNet_Assignment/results"
    os.makedirs(out_tables, exist_ok=True)

    # 1. Evaluate VehA
    df_veha = evaluate_channel_model("VehA", num_test_frames=200)
    csv_veha = f"{out_tables}/evaluation_summary_veha.csv"
    df_veha.to_csv(csv_veha, index=False)
    plot_mse_vs_snr(csv_veha, f"{out_plots}/mse_vs_snr/fig3_veha_mse_vs_snr.png", "VehA", fig_num=3)

    # 2. Evaluate SUI5
    df_sui5 = evaluate_channel_model("SUI5", num_test_frames=200)
    csv_sui5 = f"{out_tables}/evaluation_summary_sui5.csv"
    df_sui5.to_csv(csv_sui5, index=False)
    plot_mse_vs_snr(csv_sui5, f"{out_plots}/mse_vs_snr/fig4_sui5_mse_vs_snr.png", "SUI5", fig_num=4)

    # 3. Pilot density evaluation (VehA at 20 dB)
    pilot_res = evaluate_pilot_density_sweep("VehA", snr_fixed=20.0, pilot_counts=[24, 48, 72], num_test_frames=200)
    df_pilot = pd.DataFrame([
        {"Num_Pilots": p, "LS_MSE": pilot_res[p]["LS"], "MMSE_MSE": pilot_res[p]["MMSE"], "ChannelNet_MSE": pilot_res[p]["ChannelNet"]}
        for p in [24, 48, 72]
    ])
    df_pilot.to_csv(f"{out_tables}/pilot_density_evaluation.csv", index=False)
    plot_pilot_density(pilot_res, f"{out_plots}/pilot_density/fig5_mse_vs_pilots.png", snr_fixed=20.0)

    print("\nALL EVALUATIONS AND MANDATORY FIGURES COMPLETED SUCCESSFULLY!")

if __name__ == '__main__':
    run_all_evaluations_and_generate_plots()

