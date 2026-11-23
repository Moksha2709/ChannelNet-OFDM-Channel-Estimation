STAGE: Stage 8 - DnCNN Image Restoration Network

STATUS: PASS

1. Implementation summary:
   - Implemented `dncnn.py` featuring a 20-layer residual convolutional neural network with Batch Normalization:
     * Layer 1: Conv2D(in_channels=2, out_channels=64, kernel_size=3, padding=1) + ReLU
     * Layers 2 to 19 (18 layers): Conv2D(64, 64, 3x3, padding=1, bias=False) + BatchNorm2D(64) + ReLU
     * Layer 20: Conv2D(in_channels=64, out_channels=2, kernel_size=3, padding=1)
     * Residual learning formulation: $\mathcal{R}(Z)$ estimates residual noise, outputting $\hat{H}_{final} = Z - \mathcal{R}(Z)$.
   - Implemented `train_dncnn.py` which passes training inputs through pre-trained, frozen SRCNN networks to yield intermediate super-resolved channels $Z$, and trains DnCNN to restore the complete clean channel.
   - Verified DnCNN forward pass, residual subtraction arithmetic ($x - \mathcal{R}(x) == \text{forward}(x)$), and autograd updates.
   - Successfully trained all 4 DnCNN models:
     * `dncnn_VehA_12dB_best.pth`
     * `dncnn_VehA_22dB_best.pth`
     * `dncnn_SUI5_12dB_best.pth`
     * `dncnn_SUI5_22dB_best.pth`
   - Generated training curves for all models in `ChannelNet_Assignment/results/training_curves/`.

2. Files created:
   - `ChannelNet_Assignment/models/dncnn.py`
   - `ChannelNet_Assignment/training/train_dncnn.py`
   - 4 trained DnCNN model checkpoints in `ChannelNet_Assignment/checkpoints/dncnn/`
   - 4 DnCNN loss curves in `ChannelNet_Assignment/results/training_curves/`
   - `reports/stage_08_report.md`

3. Files modified:
   - `ChannelNet_Assignment/tests/test_models.py`
   - `PROJECT_PROGRESS.md`

4. Execution:
   - `C:\Users\moksh\AppData\Local\Python\bin\python.exe ChannelNet_Assignment/tests/test_models.py`
   - `C:\Users\moksh\AppData\Local\Python\bin\python.exe ChannelNet_Assignment/training/train_dncnn.py`

5. Verification:
   - Forward pass dimensions: $(4, 2, 72, 14) \to (4, 2, 72, 14)$ verified; 0 NaNs and 0 Infs.
   - Residual subtraction verification: $\max |(x - \mathcal{R}(x)) - \text{output}| = 0.00\times 10^0$ (exact).
   - Loss convergence:
     * VehA @ 12 dB: Train loss converged to $0.001038$; Best Val loss $= 0.001067$ (improved from SRCNN alone).
     * VehA @ 22 dB: Train loss converged to $0.000285$; Best Val loss $= 0.000290$.
     * SUI5 @ 12 dB: Train loss converged from $0.050909 \to 0.001835$; Best Val loss $= 0.001861$ (massive improvement from SRCNN's 0.003566).
     * SUI5 @ 22 dB: Train loss converged from $0.045809 \to 0.001263$; Best Val loss $= 0.001236$ (improved from SRCNN's 0.001729).

6. Numerical results:
   - Best Val Loss (VehA, 12 dB): $0.001067$.
   - Best Val Loss (VehA, 22 dB): $0.000290$.
   - Best Val Loss (SUI5, 12 dB): $0.001861$.
   - Best Val Loss (SUI5, 22 dB): $0.001236$.

7. Visual results:
   - `dncnn_loss_VehA_12dB.png`, `dncnn_loss_VehA_22dB.png`, `dncnn_loss_SUI5_12dB.png`, `dncnn_loss_SUI5_22dB.png`.

8. Errors and Corrections:
   - Detached tensor before scalar conversion in unit test assertions.

9. Remaining issues:
   - None.

10. Next stage:
    - Stage 9 & 10 & 11: End-to-end ChannelNet Integration and Multi-SNR Performance Evaluation.

11. Stage approval:
    - Stage 8 is APPROVED with status PASS.
