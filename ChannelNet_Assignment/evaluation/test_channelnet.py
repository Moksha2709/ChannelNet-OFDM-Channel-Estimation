"""
ChannelNet Test and Evaluation Module
Evaluates integrated ChannelNet models against baselines on test datasets.
Calculates MSE in linear and dB scales.
"""

import os
import sys
import numpy as np
import pandas as pd
import torch
from typing import Dict, List, Tuple

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from models.channelnet import ChannelNet
from estimation.interpolation import InterpolationEstimator
from estimation.mmse_estimation import MMSEEstimator
from data.normalization import ChannelNormalizer
from data.preprocessing import interpolate_sparse_pilots
from evaluation.calculate_mse import calculate_grid_mse, linear_to_db

def evaluate_test_split(
    test_npz_path: str,
    channelnet_model: ChannelNet,
    channel_model: str,
    snr_eval: float
) -> Dict[str, float]:
    """
    Evaluates LS-Interpolation, Ideal MMSE, SR-Only, and Complete ChannelNet
    on an identical test dataset split.
    """
    data = np.load(test_npz_path)
    h_true = data["h_true_complex"]      # (N, 72, 14)
    h_ls_sparse = data["h_ls_sparse"]    # (N, 72, 14)
    pilot_mask = data["pilot_mask"]      # (72, 14)
    norm_min = float(data["norm_min"])
    norm_max = float(data["norm_max"])

    normalizer = ChannelNormalizer(mode="minmax")
    normalizer.stats["min"] = norm_min
    normalizer.stats["max"] = norm_max

    interp_estimator = InterpolationEstimator(method="linear")
    mmse_estimator = MMSEEstimator(channel_model=channel_model)

    num_samples = len(h_true)
    mse_ls = []
    mse_mmse = []
    mse_sr = []
    mse_channelnet = []

    for i in range(num_samples):
        # 1. LS with 2D Interpolation
        h_interp = interp_estimator.estimate(h_ls_sparse[i], pilot_mask)
        mse_ls.append(calculate_grid_mse(h_true[i], h_interp))

        # 2. Ideal MMSE
        h_m = mmse_estimator.estimate(h_ls_sparse[i], pilot_mask, snr_db=snr_eval)
        mse_mmse.append(calculate_grid_mse(h_true[i], h_m))

        # 3. ChannelNet (SR-only and Complete)
        h_sr, h_final = channelnet_model.estimate_complex(h_ls_sparse[i], pilot_mask, normalizer=normalizer)
        mse_sr.append(calculate_grid_mse(h_true[i], h_sr))
        mse_channelnet.append(calculate_grid_mse(h_true[i], h_final))

    return {
        "LS_MSE": float(np.mean(mse_ls)),
        "MMSE_MSE": float(np.mean(mse_mmse)),
        "SR_Only_MSE": float(np.mean(mse_sr)),
        "ChannelNet_MSE": float(np.mean(mse_channelnet)),
        "LS_MSE_dB": linear_to_db(float(np.mean(mse_ls))),
        "MMSE_MSE_dB": linear_to_db(float(np.mean(mse_mmse))),
        "SR_MSE_dB": linear_to_db(float(np.mean(mse_sr))),
        "ChannelNet_MSE_dB": linear_to_db(float(np.mean(mse_channelnet)))
    }

