"""
Plot Generation Module for Mandatory Assignment Figures
Generates publication-quality figures matching the Soltani et al. reference paper:
- Fig 2: Channel Real/Imag Time-Frequency Images
- Fig 3: Channel Estimation MSE vs SNR for VehA (Deep Low-SNR, Deep High-SNR, MMSE, LS)
- Fig 4: Channel Estimation MSE vs SNR for SUI5 (Deep Low-SNR, Deep High-SNR, MMSE, LS)
- Fig 5: MSE vs Number of Pilots at 20 dB (24, 48, 72 pilots)
- Training & Validation Loss curves for SRCNN and DnCNN
"""

import os
import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

def plot_mse_vs_snr(
    csv_path: str,
    output_path: str,
    channel_model: str,
    fig_num: int = 3
):
    """
    Plots MSE in dB vs SNR (dB), replicating Fig. 3 or Fig. 4 from the reference paper.
    """
    if not os.path.exists(csv_path):
        print(f"[SKIP] CSV file not found: {csv_path}")
        return

    df = pd.read_csv(csv_path)
    snrs = df["SNR_dB"].values

    plt.figure(figsize=(9, 6))

    # Plot baseline curves
    if "LS_Linear_MSE" in df.columns:
        mse_ls_db = 10 * np.log10(df["LS_Linear_MSE"].values)
        plt.plot(snrs, mse_ls_db, 'r--s', label='LS Linear Interpolation', linewidth=1.8, markersize=6)

    if "LS_Cubic_MSE" in df.columns:
        mse_cub_db = 10 * np.log10(df["LS_Cubic_MSE"].values)
        plt.plot(snrs, mse_cub_db, 'm--^', label='LS Cubic Interpolation', linewidth=1.8, markersize=6)

    if "MMSE_MSE" in df.columns:
        mse_mmse_db = 10 * np.log10(df["MMSE_MSE"].values)
        plt.plot(snrs, mse_mmse_db, 'k-o', label='Ideal MMSE', linewidth=2.0, markersize=7)

    # Plot ChannelNet curves if available
    if "ChannelNet_12dB_MSE" in df.columns:
        mse_cn12_db = 10 * np.log10(df["ChannelNet_12dB_MSE"].values)
        plt.plot(snrs, mse_cn12_db, 'b-d', label='ChannelNet (Trained @ 12 dB)', linewidth=2.0, markersize=7)

    if "ChannelNet_22dB_MSE" in df.columns:
        mse_cn22_db = 10 * np.log10(df["ChannelNet_22dB_MSE"].values)
        plt.plot(snrs, mse_cn22_db, 'g-v', label='ChannelNet (Trained @ 22 dB)', linewidth=2.0, markersize=7)

    plt.title(f'Fig. {fig_num}: Channel Estimation MSE vs. SNR ({channel_model} Model, 48 Pilots)', fontsize=13, fontweight='bold')
    plt.xlabel('SNR (dB)', fontsize=12)
    plt.ylabel('MSE (dB)', fontsize=12)
    plt.grid(True, linestyle=':', alpha=0.7)
    plt.legend(loc='best', fontsize=10.5)
    plt.tight_layout()

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    plt.savefig(output_path, dpi=300)
    plt.close()
    print(f"[PASS] Saved Fig. {fig_num} to: {output_path}")

def plot_pilot_density(
    results_dict: dict,
    output_path: str,
    snr_fixed: float = 20.0
):
    """
    Plots MSE (dB) vs Number of Pilots at a fixed SNR (e.g. 20 dB), replicating Fig. 5.
    results_dict: {pilot_count: {'LS': mse, 'MMSE': mse, 'ChannelNet': mse}}
    """
    pilot_counts = sorted(results_dict.keys())

    ls_vals = [10 * np.log10(results_dict[p]['LS']) for p in pilot_counts]
    mmse_vals = [10 * np.log10(results_dict[p]['MMSE']) for p in pilot_counts]
    cn_vals = [10 * np.log10(results_dict[p]['ChannelNet']) for p in pilot_counts]

    plt.figure(figsize=(8, 6))
    plt.plot(pilot_counts, ls_vals, 'r--s', label='LS Linear Interpolation', linewidth=1.8, markersize=7)
    plt.plot(pilot_counts, mmse_vals, 'k-o', label='Ideal MMSE', linewidth=2.0, markersize=7)
    plt.plot(pilot_counts, cn_vals, 'g-^', label='ChannelNet', linewidth=2.2, markersize=8)

    plt.title(f'Fig. 5: Channel Estimation MSE vs. Number of Pilots (SNR = {int(snr_fixed)} dB, VehA)', fontsize=13, fontweight='bold')
    plt.xlabel('Number of Pilots per Frame', fontsize=12)
    plt.ylabel('MSE (dB)', fontsize=12)
    plt.xticks(pilot_counts)
    plt.grid(True, linestyle=':', alpha=0.7)
    plt.legend(loc='best', fontsize=11)
    plt.tight_layout()

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    plt.savefig(output_path, dpi=300)
    plt.close()
    print(f"[PASS] Saved Fig. 5 to: {output_path}")

