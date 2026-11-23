# Simulator Interface & Channel Generation

This folder contains the channel simulation interfaces for ITU-R Vehicular-A (VehA) and IEEE 802.16 SUI-5 models.

## Components
1. `simulator_interface.py`: MATLAB execution harness interfacing with the Vienna 5G Link-Level Simulator (+Channel.FastFading).
2. `channel_generation.py`: Native, vectorized Python channel engine implementing the exact WSSUS Clarke/Jakes Doppler spectrum and tapped delay line multipath fading.

## Channel Model Specifications
* **Vehicular-A (VehA):** 6 taps, delays = [0, 310, 710, 1090, 1730, 2510] ns, powers = [0, -1, -9, -10, -15, -20] dB, max Doppler = 97.287 Hz (50 km/h at 2.1 GHz).
* **SUI-5:** 3 taps, delays = [0, 4.0, 10.0] µs, powers = [0, -5, -10] dB, max Doppler = 97.287 Hz. Coherence bandwidth ~ 120 kHz.
