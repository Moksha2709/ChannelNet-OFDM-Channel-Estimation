"""
Dataset Generator Module
Generates training, validation, and test datasets for VehA and SUI5 channels
at specific SNR levels (12 dB and 22 dB) and across multiple pilot densities.
Stores data in compressed .npz format.
"""

import os
import sys
import numpy as np
from typing import Optional, Dict

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from ofdm.ofdm_transmitter import OFDMTransmitter
from ofdm.pilot_generation import PilotGenerator
from ofdm.ofdm_channel import OFDMChannel
from simulator.channel_generation import ChannelGenerator
from estimation.ls_estimation import LSEstimator
from data.preprocessing import interpolate_sparse_pilots, complex_to_2channel_tensor
from data.normalization import ChannelNormalizer

def generate_dataset_split(
    channel_model: str,
    snr_db: float,
    num_samples: int,
    num_pilots: int = 48,
    seed: int = 42,
    normalizer: Optional[ChannelNormalizer] = None
) -> Dict[str, np.ndarray]:
    """
    Generates a dataset split consisting of:
    - inputs: (N, 2, 72, 14) [2D interpolated LS estimates]
    - targets: (N, 2, 72, 14) [Ground-truth channel]
    - h_true_complex: (N, 72, 14)
    - h_ls_sparse: (N, 72, 14)
    - pilot_mask: (72, 14)
    """
    pg = PilotGenerator()
    tx = OFDMTransmitter(seed=seed)
    ch_sim = OFDMChannel(seed=seed + 1000)
    cg = ChannelGenerator(seed=seed + 2000)
    ls_est = LSEstimator()

    mask = pg.get_pilot_mask(num_pilots)
    pilot_val = 1.0 + 0j

    inputs = np.zeros((num_samples, 2, 72, 14), dtype=np.float32)
    targets = np.zeros((num_samples, 2, 72, 14), dtype=np.float32)
    h_true_complex = np.zeros((num_samples, 72, 14), dtype=np.complex128)
    h_ls_sparse = np.zeros((num_samples, 72, 14), dtype=np.complex128)

    for i in range(num_samples):
        # Generate true channel realization
        h_true = cg.generate_single_channel(model=channel_model)
        h_true_complex[i] = h_true

        # Transmit frame with pilots
        data = tx.generate_random_qpsk()
        tx_grid = pg.insert_pilots(data, mask, pilot_value=pilot_val)

        # Apply channel + AWGN
        y_grid, _ = ch_sim.apply_channel_2d(tx_grid, h_true, snr_db=snr_db)

        # LS estimation at pilots
        h_ls = ls_est.get_sparse_ls_grid(y_grid, tx_grid, mask, fill_value=0.0)
        h_ls_sparse[i] = h_ls

        # Pre-interpolation for SR input
        h_interp = interpolate_sparse_pilots(h_ls, mask, method="linear")

        # Convert to 2-channel tensors [Real, Imag]
        inputs[i] = complex_to_2channel_tensor(h_interp)
        targets[i] = complex_to_2channel_tensor(h_true)

    # Fit normalizer on targets if not provided
    if normalizer is None:
        normalizer = ChannelNormalizer(mode="minmax")
        normalizer.fit(targets)

    # Normalize inputs and targets
    norm_inputs = normalizer.transform(inputs)
    norm_targets = normalizer.transform(targets)

    return {
        "inputs": norm_inputs.astype(np.float32),
        "targets": norm_targets.astype(np.float32),
        "raw_inputs": inputs,
        "raw_targets": targets,
        "h_true_complex": h_true_complex,
        "h_ls_sparse": h_ls_sparse,
        "pilot_mask": mask,
        "snr_db": np.array(snr_db, dtype=np.float32),
        "model": channel_model,
        "norm_min": normalizer.stats.get("min", 0.0),
        "norm_max": normalizer.stats.get("max", 1.0)
    }

def build_all_datasets(
    output_dir: str = "ChannelNet_Assignment/data",
    train_count: int = 2000,
    val_count: int = 400,
    test_count: int = 400
):
    """
    Builds and saves train, validation, and test datasets for VehA and SUI5
    at 12 dB and 22 dB, as well as test sets across multiple SNRs and pilot counts.
    """
    os.makedirs(f"{output_dir}/train", exist_ok=True)
    os.makedirs(f"{output_dir}/validation", exist_ok=True)
    os.makedirs(f"{output_dir}/test", exist_ok=True)

    models = ["VehA", "SUI5"]
    training_snrs = [12.0, 22.0]

    for model in models:
        for snr in training_snrs:
            snr_tag = int(snr)
            print(f"Generating datasets for {model} at {snr_tag} dB...")

            # 1. Training split
            train_data = generate_dataset_split(
                channel_model=model,
                snr_db=snr,
                num_samples=train_count,
                num_pilots=48,
                seed=42
            )
            # Normalizer fitted on training split
            normalizer = ChannelNormalizer(mode="minmax")
            normalizer.stats["min"] = train_data["norm_min"]
            normalizer.stats["max"] = train_data["norm_max"]

            train_path = f"{output_dir}/train/{model}_{snr_tag}dB_train.npz"
            np.savez_compressed(train_path, **train_data)
            print(f"Saved: {train_path} ({train_count} samples)")

            # 2. Validation split (different seed, no leakage)
            val_data = generate_dataset_split(
                channel_model=model,
                snr_db=snr,
                num_samples=val_count,
                num_pilots=48,
                seed=1042,
                normalizer=normalizer
            )
            val_path = f"{output_dir}/validation/{model}_{snr_tag}dB_val.npz"
            np.savez_compressed(val_path, **val_data)
            print(f"Saved: {val_path} ({val_count} samples)")

            # 3. Test split (different seed, no leakage)
            test_data = generate_dataset_split(
                channel_model=model,
                snr_db=snr,
                num_samples=test_count,
                num_pilots=48,
                seed=2042,
                normalizer=normalizer
            )
            test_path = f"{output_dir}/test/{model}_{snr_tag}dB_test.npz"
            np.savez_compressed(test_path, **test_data)
            print(f"Saved: {test_path} ({test_count} samples)")

    print("Dataset generation completed successfully.")

if __name__ == '__main__':
    build_all_datasets()

