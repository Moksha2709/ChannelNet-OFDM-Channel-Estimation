# ChannelNet: Autonomous Deep Learning-Based OFDM Channel Estimation

**Course:** COM 837 — Machine Learning for Wireless Communication (Assignment 3)  
**Implementation:** Complete Autonomous Implementation of ChannelNet based on Soltani et al. (arXiv:1810.05893v4 / IEEE Communications Letters 2019).

---

## 1. Project Overview
This repository contains the complete, modular, and fully verified Python/PyTorch implementation of the **ChannelNet** deep learning channel estimator for SISO-OFDM systems. 

ChannelNet models the 2D time–frequency channel response ($72 \text{ subcarriers} \times 14 \text{ OFDM symbols}$) as an image and reconstructs the complete channel from noisy, sparse pilot observations using a cascaded deep learning pipeline:
1. **Stage 1 (SRCNN):** Image Super-Resolution network enhancing sparse pilot observations.
2. **Stage 2 (DnCNN):** 20-layer residual convolutional network with Batch Normalization removing residual noise.

---

## 2. Directory Structure
```
ChannelNet_Assignment/
    config/
        config.py                     # Dataclasses & default global configurations
        experiment_config.yaml        # YAML experiment hyperparameter definitions
    simulator/
        simulator_interface.py        # Vienna 5G Link-Level Simulator MATLAB interface
        channel_generation.py         # ITU-R VehA & IEEE SUI-5 TDL fading generator
    ofdm/
        ofdm_transmitter.py           # 128-point IFFT, cyclic prefix insertion, QPSK mapper
        ofdm_receiver.py              # Cyclic prefix removal, 128-point FFT, subcarrier extractor
        pilot_generation.py           # Diamond/lattice pilot masks (24, 48, 72 pilots)
        ofdm_channel.py               # AWGN calibration & 2D multiplicative fading
    data/
        normalization.py              # Invertible Min-Max and Z-score normalizer
        preprocessing.py              # 2D cubic/linear interpolation & tensor conversion
        dataset_generator.py          # Script generating train/val/test splits
        dataset_loader.py             # PyTorch Dataset and DataLoader streaming wrapper
        train/                        # 12dB & 22dB training datasets (VehA & SUI5)
        validation/                   # Validation datasets
        test/                         # Test datasets
    estimation/
        ls_estimation.py              # Pilot-based Least Squares (LS) estimator
        interpolation.py              # 2D Linear & Cubic spline interpolation
        mmse_estimation.py            # Exact Ideal LMMSE estimator with analytic covariance
    models/
        sr_network.py                 # 3-layer SRCNN architecture
        dncnn.py                      # 20-layer residual DnCNN architecture
        channelnet.py                 # Integrated ChannelNet pipeline
    training/
        losses.py                     # ChannelMSELoss and ChannelNMSELoss
        train_sr.py                   # Sequential training script for SRCNN
        train_dncnn.py                # Sequential training script for DnCNN
    evaluation/
        calculate_mse.py              # Physical linear & dB MSE metrics
        generate_plots.py             # Plotting utilities for Figures 2, 3, 4, 5
        test_channelnet.py            # Model evaluation utilities
        run_complete_evaluation.py    # Master multi-SNR & pilot density evaluation pipeline
    checkpoints/
        sr/                           # Trained SRCNN model weights (.pth)
        dncnn/                        # Trained DnCNN model weights (.pth)
    results/
        channel_visualizations/       # Fig 2, pilot patterns, sparse LS vs ground truth
        training_curves/              # Training & validation loss curves
        mse_vs_snr/                   # Fig 3 (VehA) and Fig 4 (SUI5) MSE vs SNR curves
        pilot_density/                # Fig 5 MSE vs Number of Pilots curve
        comparison_tables/            # Quantitative CSV benchmark results
    report/
        final_report.pdf              # 6-page comprehensive technical report PDF
        generate_final_report.py      # ReportLab PDF compiler script
    tests/
        test_ofdm.py                  # Stage 1 transceiver unit tests
        test_pilots.py                # Stage 2 pilot arrangement verification
        test_channel.py               # Stage 3 channel statistics & Vienna integration
        test_estimators.py            # Stage 4 LS estimator verification
        test_dataset.py               # Stage 5 dataset & normalization verification
        test_baselines.py             # Stage 6 interpolation & MMSE verification
        test_models.py                # Stage 7 & 8 neural network unit tests
        run_full_audit.py             # Stage 14 master audit & verification suite
    requirements.txt                  # Python dependencies
```

---

## 3. Quickstart & Execution Guide

### Step 1: Environment Setup
Ensure Python 3.10+ (or Python 3.14) is active:
```bash
python -m pip install -r requirements.txt
```

### Step 2: Run Full System Audit & Unit Tests
Run the master audit to verify that all 22 modules, datasets, checkpoints, and figures are intact:
```bash
python ChannelNet_Assignment/tests/run_full_audit.py
```

### Step 3: Run Baseline & Model Evaluation
To reproduce Figures 3, 4, and 5 and generate the benchmark CSV files:
```bash
python ChannelNet_Assignment/evaluation/run_complete_evaluation.py
```

### Step 4: Re-generate Technical Report PDF
To recompile the 6-page technical report with updated figures and tables:
```bash
python ChannelNet_Assignment/report/generate_final_report.py
```
Output is generated at `ChannelNet_Assignment/report/final_report.pdf`.

---

## 4. Summary of Experimental Results

### Vehicular-A (48 Pilots) — Replicating Paper Fig. 3:
| SNR (dB) | LS Linear MSE (dB) | Ideal MMSE MSE (dB) | ChannelNet (12 dB) | ChannelNet (22 dB) |
|:---:|:---:|:---:|:---:|:---:|
| **0**  | -1.89 dB  | -11.59 dB | **-5.37 dB**  | -3.60 dB  |
| **5**  | -6.77 dB  | -14.93 dB | **-11.13 dB** | -8.85 dB  |
| **10** | -11.74 dB | -18.95 dB | **-16.04 dB** | -13.90 dB |
| **15** | -16.46 dB | -23.15 dB | **-19.31 dB** | -18.40 dB |
| **20** | -20.70 dB | -27.57 dB | -20.99 dB     | **-21.73 dB** |
| **25** | -23.88 dB | -31.54 dB | -21.59 dB     | **-23.50 dB** |

### SUI-5 (Severe Multipath Delay Spread) — Replicating Paper Fig. 4:
| SNR (dB) | LS Linear MSE (dB) | Ideal MMSE MSE (dB) | ChannelNet (12 dB) | ChannelNet (22 dB) |
|:---:|:---:|:---:|:---:|:---:|
| **0**  | -1.08 dB | -11.89 dB | **-4.26 dB**  | -2.96 dB  |
| **5**  | -4.65 dB | -15.51 dB | **-8.90 dB**  | -7.12 dB  |
| **10** | -7.01 dB | -19.84 dB | **-12.96 dB** | -11.08 dB |
| **15** | -8.09 dB | -24.05 dB | **-15.53 dB** | -14.05 dB |
| **20** | -8.51 dB | -28.79 dB | -16.75 dB     | **-16.07 dB** |
| **25** | -8.65 dB | -33.57 dB | -17.23 dB     | **-16.98 dB** |

*Key finding:* In SUI-5, LS interpolation exhibits an error floor at -8.6 dB due to frequency-domain aliasing. ChannelNet achieves -17.2 dB, delivering over **8.6 dB improvement** over conventional interpolation.

---

## 5. Deliverables & Submission Artifacts
1. **Source Code**: Clean, modular, fully executable Python modules in `ChannelNet_Assignment/`.
2. **Model Checkpoints**: All 8 pre-trained model weights in `ChannelNet_Assignment/checkpoints/`.
3. **Mandatory Figures**: High-resolution PNG figures in `ChannelNet_Assignment/results/`.
4. **CSV Tables**: Raw numerical data in `ChannelNet_Assignment/results/comparison_tables/`.
5. **Technical Report**: Publication-quality 6-page PDF at [ChannelNet_Assignment/report/final_report.pdf](file:///c:/Users/moksh/Downloads/mlwc/ChannelNet_Assignment/report/final_report.pdf).
