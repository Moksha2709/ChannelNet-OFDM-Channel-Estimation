"""
Vienna LTE/5G Simulator Interface Module
Wraps the Vienna 5GLLSimulator Channel.FastFading class.
Executes MATLAB batch commands to generate authentic Vienna simulator channel realizations,
and converts results into NumPy matrices.
"""

import os
import subprocess
import tempfile
import numpy as np
from typing import Optional, Tuple
from scipy.io import loadmat, savemat

class ViennaSimulatorInterface:
    """
    Interface to the Vienna 5G Link-Level Simulator (+Channel.FastFading).
    """
    def __init__(
        self,
        matlab_path: str = r"C:\Program Files\MATLAB\R2025b\bin\matlab.exe",
        simulator_dir: Optional[str] = None
    ):
        self.matlab_path = matlab_path
        if simulator_dir is None:
            # Default location in workspace
            curr_dir = os.path.dirname(os.path.abspath(__file__))
            self.simulator_dir = os.path.abspath(os.path.join(curr_dir, '..', '..', '5GLLSimulator', '5GLLSimulator'))
        else:
            self.simulator_dir = os.path.abspath(simulator_dir)

    def generate_channels_matlab(
        self,
        channel_model: str,
        num_frames: int,
        carrier_freq: float = 2.1e9,
        sampling_rate: float = 1.92e6,
        ue_speed_kmh: float = 50.0,
        seed: int = 42
    ) -> np.ndarray:
        """
        Generates channel transfer functions using MATLAB Vienna FastFading class.
        
        Parameters:
        -----------
        channel_model : str
            'VehA' (or 'VehicularA') or 'SUI5'.
        num_frames : int
            Number of independent 72x14 channel subframes to generate.
            
        Returns:
        --------
        channels : np.ndarray
            Array of shape (num_frames, 72, 14) with complex dtype np.complex128.
        """
        sim_dir_clean = self.simulator_dir.replace('\\', '/')
        temp_mat_path = os.path.join(tempfile.gettempdir(), f"vienna_out_{channel_model}_{seed}.mat").replace('\\', '/')
        
        # Format MATLAB script for batch execution
        matlab_cmd = f"""
        rng({seed});
        addpath(genpath('{sim_dir_clean}'));
        Fs = {sampling_rate};
        fc = {carrier_freq};
        v = {ue_speed_kmh};
        fd = v / 3.6 * fc / 2.998e8;
        nSamples = 1920;
        dummy.spatialChannelModel = false;
        
        modelName = '{channel_model}';
        if strcmpi(modelName, 'VehA') || strcmpi(modelName, 'VehicularA')
            pdp = 'VehicularA';
        elseif strcmpi(modelName, 'SUI5')
            sui5_delays = round([0, 4e-6, 10e-6] * Fs) + 1;
            sui5_powers = 10.^([0, -5, -10] / 10);
            pdp = zeros(1, max(sui5_delays));
            pdp(sui5_delays) = sui5_powers;
            pdp = pdp / sum(pdp);
        else
            error('Unknown model');
        end
        
        timePos = round(linspace(73, 1920-73, 14));
        N = {num_frames};
        H_all = zeros(72, 14, N);
        
        for i = 1:N
            chan = Channel.FastFading(Fs, pdp, nSamples, fd, 'Jakes', 200, false, 'none', 0, 0, 1, 1, false, 0, 1, dummy, [1 1], [1 1], fc, 1);
            H_all(:, :, i) = chan.GetTransferFunction(timePos, 128, 1:72);
        end
        
        save('{temp_mat_path}', 'H_all', '-v7');
        """

        # Execute MATLAB in batch mode
        cmd = [self.matlab_path, "-batch", matlab_cmd]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            raise RuntimeError(f"MATLAB execution failed:\n{res.stderr}\n{res.stdout}")

        # Load generated MAT file
        mat_data = loadmat(temp_mat_path)
        h_all = mat_data['H_all']  # Shape in MATLAB: (72, 14, num_frames)

        # Transpose to Python shape: (num_frames, 72, 14)
        h_all_py = np.transpose(h_all, (2, 0, 1)).astype(np.complex128)

        # Cleanup
        try:
            os.remove(temp_mat_path)
        except OSError:
            pass

        return h_all_py

