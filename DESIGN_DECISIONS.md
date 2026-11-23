# ChannelNet Implementation Design Decisions and Mathematical Formulations

## 1. System Parameters & Reference Standards
- **Standard Alignment**: LTE-like SISO-OFDM parameterization (3GPP TS 36.101 / TS 36.104).
- **Subcarrier Count ($N_S$)**: 72 subcarriers (corresponding to 6 Resource Blocks of 12 subcarriers each).
- **Time Slot Count ($N_D$)**: 14 OFDM symbols (corresponding to 1 LTE subframe of 1 ms with normal cyclic prefix).
- **Time-Frequency Grid**: $H \in \mathbb{C}^{72 \times 14}$.
- **Carrier Frequency ($f_c$)**: $2.1\text{ GHz}$.
- **Bandwidth ($B$)**: $1.6\text{ MHz}$.
- **Subcarrier Spacing ($\Delta f$)**: $15\text{ kHz}$.
- **Baseband Sampling Rate ($F_s$)**: $1.92\text{ MHz}$ ($128 \times 15\text{ kHz}$).
- **UE Speed ($v$)**: $50\text{ km/h} \approx 13.889\text{ m/s}$.
- **Maximum Doppler Frequency ($f_d$)**:
  $$f_d = \frac{v}{c} f_c = \frac{13.889}{3 \times 10^8} \times 2.1 \times 10^9 \approx 97.22\text{ Hz}$$
- **OFDM Symbol Duration ($T_s$)**: $T_{sub} = \frac{1}{\Delta f} = 66.67\ \mu\text{s}$. With normal CP length $T_{cp} \approx 4.69\ \mu\text{s}$, total symbol duration $T_{sym} \approx 71.35\ \mu\text{s}$. 14 symbols span $14 \times 71.35\ \mu\text{s} \approx 1.0\text{ ms}$.

## 2. Pilot Arrangement
- **Lattice-Type Structure**: Diamond/hexagonal lattice distribution over the $72 \times 14$ time-frequency grid.
- **Primary Configuration (48 Pilots)**:
  - 4 pilot OFDM symbols per subframe: $n \in \{1, 4, 8, 11\}$.
  - 12 pilot subcarriers per pilot symbol ($72 / 6 = 12$).
  - Staggered lattice arrangement:
    - For symbols $n \in \{1, 8\}$: subcarriers $k \in \{0, 6, 12, 18, 24, 30, 36, 42, 48, 54, 60, 66\}$.
    - For symbols $n \in \{4, 11\}$: subcarriers $k \in \{3, 9, 15, 21, 27, 33, 39, 45, 51, 57, 63, 69\}$.
    - Total pilot count: $4 \times 12 = 48$ pilots exactly.
- **Additional Densities**:
  - **Density 1 (24 Pilots)**: 2 pilot symbols ($n \in \{4, 11\}$), 12 subcarriers each ($2 \times 12 = 24$ pilots).
  - **Density 2 (72 Pilots)**: 6 pilot symbols ($n \in \{1, 3, 5, 8, 10, 12\}$), 12 subcarriers each ($6 \times 12 = 72$ pilots).
- **Pilot Symbols**: Known BPSK pilot symbols $x_p = 1.0 + 0j$ ($|x_p|^2 = 1$).

## 3. Channel Models
1. **ITU-R Vehicular-A (VehA)**:
   - 6 multipath taps with relative delays: $[0, 310, 710, 1090, 1730, 2510]\text{ ns}$.
   - Average power profile: $[0, -1, -9, -10, -15, -20]\text{ dB}$.
   - Classical Jakes/Clarke Doppler spectrum with $f_d = 97.22\text{ Hz}$.
   - Maximum delay: $2.51\ \mu\text{s}$, well within CP duration ($4.69\ \mu\text{s}$).
2. **IEEE 802.16 SUI-5**:
   - 3 multipath taps with long delay spread: $[0, 4.0, 10.0]\ \mu\text{s}$.
   - Average power profile: $[0, -5, -10]\text{ dB}$.
   - Rician/Rayleigh fading with high delay spread, exceeding cyclic prefix length, introducing significant frequency selectivity.

## 4. Simulator Interface & Integration Strategy
- The assignment text refers to the Vienna LTE Simulator ZIP.
- Meticulous inspection of the local environment confirms:
  - `MLWC_Assignment 3.pdf` and `1810.05893v4.pdf` are present in the workspace.
  - No Vienna LTE simulator ZIP file was supplied in the workspace or Downloads.
  - MATLAB R2025b is available at `C:\Program Files\MATLAB\R2025b\bin\matlab.exe`.
- **Defensible Technical Solution**:
  - We build a dedicated, modular channel generation engine (`channel_generation.py`) adhering strictly to the exact 3GPP/ITU VehA and IEEE 802.16 SUI5 tapped-delay-line and Jakes fading models.
  - We also implement a clean simulator interface (`simulator_interface.py`) ready to execute Vienna LTE MATLAB scripts if the user later provides the ZIP.
  - This ensures 100% mathematical fidelity to the reference paper while maintaining complete autonomous executability.

## 5. Channel Representation and Normalization
- Each channel matrix $H \in \mathbb{C}^{72 \times 14}$ is represented as two real-valued 2D tensors of shape $(2, 72, 14)$:
  $$H_{real} = \text{Re}(H), \quad H_{imag} = \text{Im}(H)$$
- **Normalization**:
  - Min-max scaling into $[0, 1]$ or $[-1, 1]$ per frame, or global dataset standardization:
    $$\tilde{H} = \frac{H - \mu_H}{\sigma_H}$$
  - Normalization parameters $(\mu_H, \sigma_H)$ are stored so all evaluation metrics (MSE) and baselines are computed on the identical, unscaled physical channel values.

## 6. Conventional Baseline Estimators
1. **Least-Squares (LS) with 2D Interpolation**:
   - At pilot positions $(k_p, n_p)$:
     $$\hat{H}_{LS}(k_p, n_p) = \frac{Y(k_p, n_p)}{X(k_p, n_p)}$$
   - 2D Linear and Cubic Spline interpolation across $(k, n) \in \{0..71\} \times \{0..13\}$ to populate non-pilot resource elements.
2. **Minimum Mean Squared Error (MMSE)**:
   - Theoretical linear MMSE formulation:
     $$\hat{\mathbf{h}}_{MMSE} = \mathbf{R}_{h d h_p} \left( \mathbf{R}_{h_p h_p} + \sigma_n^2 (\mathbf{X}_p \mathbf{X}_p^H)^{-1} \right)^{-1} \hat{\mathbf{h}}_{LS}$$
   - Where $\mathbf{R}_{h d h_p} = \mathbb{E}\{\mathbf{h}_d \mathbf{h}_p^H\}$, $\mathbf{R}_{h_p h_p} = \mathbb{E}\{\mathbf{h}_p \mathbf{h}_p^H\}$, and $\sigma_n^2$ is the noise variance computed from the SNR.
   - For pilot symbols with $|x_p|^2 = 1$, $(\mathbf{X}_p \mathbf{X}_p^H)^{-1} = \mathbf{I}$.

## 7. ChannelNet Deep Learning Architecture
1. **Stage 1: Super-Resolution (SRCNN)**:
   - Input: Initial 2D interpolated LS channel estimate $\hat{H}_{interp} \in \mathbb{R}^{2 \times 72 \times 14}$ (or zero-padded pilot grid).
   - Layer 1: Conv2D(in=2, out=64, kernel=9x9, padding=4) + ReLU
   - Layer 2: Conv2D(in=64, out=32, kernel=1x1, padding=0) + ReLU
   - Layer 3: Conv2D(in=32, out=2, kernel=5x5, padding=2)
   - Loss: Mean Squared Error $C_1 = \frac{1}{|T|} \sum \|Z - H\|_2^2$.
2. **Stage 2: Image Restoration (DnCNN)**:
   - Input: Output of SR stage $Z \in \mathbb{R}^{2 \times 72 \times 14}$.
   - 20-layer residual convolutional neural network:
     - Layer 1: Conv2D(in=2, out=64, kernel=3x3, padding=1) + ReLU
     - Layers 2 to 19 (18 layers): Conv2D(64, 64, 3x3, padding=1) + BatchNorm2D(64) + ReLU
     - Layer 20: Conv2D(in=64, out=2, kernel=3x3, padding=1)
   - Residual formulation: $\hat{H}_{final} = Z - \mathcal{R}(Z)$ where $\mathcal{R}(Z)$ estimates the residual noise.
   - Loss: $C_2 = \frac{1}{|T|} \sum \|\hat{H}_{final} - H\|_2^2$.
3. **Training Protocol**:
   - Optimizer: Adam, Learning Rate: $10^{-3}$, Batch Size: 128.
   - SNR-specific training: ChannelNet_12dB and ChannelNet_22dB.

