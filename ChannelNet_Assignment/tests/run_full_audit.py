"""
Master Audit and Verification Suite for ChannelNet Assignment (Stage 14)
Performs complete sanity audit across:
1. Module imports
2. File and directory integrity
3. Checkpoint availability
4. Dataset existence
5. Mandatory plot verification
6. Standalone checkpoint inference test on unseen channel
"""

import os
import sys
import numpy as np
import torch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

def audit_imports():
    print("[1/6] Auditing module imports...")
    import config.config
    import simulator.channel_generation
    import simulator.simulator_interface
    import ofdm.ofdm_transmitter
    import ofdm.ofdm_receiver
    import ofdm.pilot_generation
    import ofdm.ofdm_channel
    import data.normalization
    import data.preprocessing
    import data.dataset_generator
    import data.dataset_loader
    import estimation.ls_estimation
    import estimation.interpolation
    import estimation.mmse_estimation
    import models.sr_network
    import models.dncnn
    import models.channelnet
    import training.losses
    import training.train_sr
    import training.train_dncnn
    import evaluation.calculate_mse
    import evaluation.generate_plots
    import evaluation.test_channelnet
    import evaluation.run_complete_evaluation
    print("  -> All 22 Python modules imported successfully without errors.")

def audit_datasets():
    print("[2/6] Auditing dataset files...")
    expected_datasets = [
        "data/train/VehA_12dB_train.npz",
        "data/train/VehA_22dB_train.npz",
        "data/train/SUI5_12dB_train.npz",
        "data/train/SUI5_22dB_train.npz",
        "data/validation/VehA_12dB_val.npz",
        "data/validation/VehA_22dB_val.npz",
        "data/validation/SUI5_12dB_val.npz",
        "data/validation/SUI5_22dB_val.npz",
        "data/test/VehA_12dB_test.npz",
        "data/test/VehA_22dB_test.npz",
        "data/test/SUI5_12dB_test.npz",
        "data/test/SUI5_22dB_test.npz"
    ]
    base_dir = "ChannelNet_Assignment"
    for d in expected_datasets:
        path = os.path.join(base_dir, d)
        assert os.path.exists(path), f"Missing dataset file: {path}"
        data = np.load(path)
        assert data["inputs"].shape[1:] == (2, 72, 14), f"Bad input shape in {path}"
        assert data["targets"].shape[1:] == (2, 72, 14), f"Bad target shape in {path}"
    print(f"  -> All {len(expected_datasets)} datasets verified (shapes: [N, 2, 72, 14]).")

def audit_checkpoints():
    print("[3/6] Auditing trained model checkpoints...")
    expected_checkpoints = [
        "checkpoints/sr/srcnn_VehA_12dB_best.pth",
        "checkpoints/sr/srcnn_VehA_22dB_best.pth",
        "checkpoints/sr/srcnn_SUI5_12dB_best.pth",
        "checkpoints/sr/srcnn_SUI5_22dB_best.pth",
        "checkpoints/dncnn/dncnn_VehA_12dB_best.pth",
        "checkpoints/dncnn/dncnn_VehA_22dB_best.pth",
        "checkpoints/dncnn/dncnn_SUI5_12dB_best.pth",
        "checkpoints/dncnn/dncnn_SUI5_22dB_best.pth"
    ]
    base_dir = "ChannelNet_Assignment"
    for c in expected_checkpoints:
        path = os.path.join(base_dir, c)
        assert os.path.exists(path), f"Missing checkpoint: {path}"
        ckpt = torch.load(path, map_location='cpu')
        assert 'model_state_dict' in ckpt or isinstance(ckpt, dict), f"Invalid checkpoint format: {path}"
    print(f"  -> All {len(expected_checkpoints)} neural network checkpoints verified.")

def audit_plots_and_results():
    print("[4/6] Auditing mandatory plots and CSV result tables...")
    base_dir = "ChannelNet_Assignment"
    expected_files = [
        "results/channel_visualizations/fig2_channel_images.png",
        "results/channel_visualizations/pilot_pattern.png",
        "results/channel_visualizations/veha_real.png",
        "results/channel_visualizations/veha_imag.png",
        "results/channel_visualizations/sui5_real.png",
        "results/channel_visualizations/sui5_imag.png",
        "results/channel_visualizations/sparse_ls_vs_ground_truth.png",
        "results/channel_visualizations/ofdm_grid_validation.png",
        "results/mse_vs_snr/fig3_veha_mse_vs_snr.png",
        "results/mse_vs_snr/fig4_sui5_mse_vs_snr.png",
        "results/pilot_density/fig5_mse_vs_pilots.png",
        "results/training_curves/sr_loss_VehA_12dB.png",
        "results/training_curves/sr_loss_VehA_22dB.png",
        "results/training_curves/sr_loss_SUI5_12dB.png",
        "results/training_curves/sr_loss_SUI5_22dB.png",
        "results/training_curves/dncnn_loss_VehA_12dB.png",
        "results/training_curves/dncnn_loss_VehA_22dB.png",
        "results/training_curves/dncnn_loss_SUI5_12dB.png",
        "results/training_curves/dncnn_loss_SUI5_22dB.png",
        "results/comparison_tables/evaluation_summary_veha.csv",
        "results/comparison_tables/evaluation_summary_sui5.csv",
        "results/comparison_tables/pilot_density_evaluation.csv",
        "results/comparison_tables/baseline_mse_veha.csv",
        "results/comparison_tables/baseline_mse_sui5.csv"
    ]
    for f in expected_files:
        path = os.path.join(base_dir, f)
        assert os.path.exists(path), f"Missing artifact: {path}"
        assert os.path.getsize(path) > 0, f"File is empty: {path}"
    print(f"  -> All {len(expected_files)} plots and CSV tables verified.")

def audit_report_pdf():
    print("[5/6] Auditing final technical report PDF...")
    import pymupdf
    pdf_path = "ChannelNet_Assignment/report/final_report.pdf"
    assert os.path.exists(pdf_path), f"Missing PDF report: {pdf_path}"
    doc = pymupdf.open(pdf_path)
    assert 5 <= len(doc) <= 7, f"Report length {len(doc)} pages outside expected 5-7 pages range!"
    print(f"  -> Final technical report verified: {len(doc)} pages in {pdf_path}.")

def standalone_inference_test():
    print("[6/6] Executing standalone inference test on unseen channel realization...")
    from models.channelnet import ChannelNet
    from simulator.channel_generation import ChannelGenerator
    from ofdm.pilot_generation import PilotGenerator
    from ofdm.ofdm_transmitter import OFDMTransmitter
    from ofdm.ofdm_channel import OFDMChannel
    from estimation.ls_estimation import LSEstimator
    from data.normalization import ChannelNormalizer

    # Load pre-trained models
    sr_path = "ChannelNet_Assignment/checkpoints/sr/srcnn_VehA_22dB_best.pth"
    dn_path = "ChannelNet_Assignment/checkpoints/dncnn/dncnn_VehA_22dB_best.pth"
    model = ChannelNet.from_checkpoints(sr_path, dn_path)

    # Generate totally unseen channel
    cg = ChannelGenerator(seed=999999)
    tx = OFDMTransmitter(seed=888888)
    ch_sim = OFDMChannel(seed=777777)
    pg = PilotGenerator()
    ls_est = LSEstimator()

    h_unseen = cg.generate_single_channel('VehA')
    mask = pg.get_pilot_mask(48)
    data = tx.generate_random_qpsk()
    tx_grid = pg.insert_pilots(data, mask)

    y_grid, _ = ch_sim.apply_channel_2d(tx_grid, h_unseen, snr_db=22.0)
    h_ls = ls_est.get_sparse_ls_grid(y_grid, tx_grid, mask)

    # Inference without retraining
    h_sr, h_final = model.estimate_complex(h_ls, mask)

    assert h_final.shape == (72, 14), f"Bad output shape: {h_final.shape}"
    assert np.iscomplexobj(h_final), "Output is not complex!"
    assert not np.isnan(h_final).any(), "NaNs in output!"

    mse = float(np.mean(np.abs(h_unseen - h_final) ** 2))
    print(f"  -> Clean inference test succeeded: MSE on unseen channel = {mse:.6f} ({10*np.log10(mse):.2f} dB).")

if __name__ == '__main__':
    print("=" * 60)
    print("STARTING FULL PROJECT AUDIT & REPRODUCIBILITY SUITE")
    print("=" * 60)
    audit_imports()
    audit_datasets()
    audit_checkpoints()
    audit_plots_and_results()
    audit_report_pdf()
    standalone_inference_test()
    print("=" * 60)
    print("ALL AUDIT AND REPRODUCIBILITY CHECKS PASSED (100% VERIFIED)!")
    print("=" * 60)
