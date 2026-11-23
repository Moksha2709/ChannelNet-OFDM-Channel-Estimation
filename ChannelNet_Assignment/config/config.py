"""
System configuration parameters for OFDM system, channel modeling,
ChannelNet architecture, and performance evaluation.
"""

import os
from dataclasses import dataclass, field
from typing import List, Tuple
import yaml

@dataclass
class OFDMConfig:
    num_subcarriers: int = 72       # NS = 72 subcarriers
    num_symbols: int = 14           # ND = 14 OFDM time slots (1 LTE subframe)
    carrier_frequency: float = 2.1e9 # 2.1 GHz
    bandwidth: float = 1.6e6        # 1.6 MHz
    subcarrier_spacing: float = 15000.0 # 15 kHz
    sampling_rate: float = 1.92e6   # 1.92 MHz baseband sampling rate
    fft_size: int = 128
    cp_length: int = 9              # Cyclic prefix samples (~4.69 us)
    ue_speed_kmh: float = 50.0      # 50 km/h

@dataclass
class PilotConfig:
    primary_count: int = 48
    additional_counts: List[int] = field(default_factory=lambda: [24, 72])
    pilot_type: str = "lattice"
    pilot_value: complex = 1.0 + 0.0j

@dataclass
class ChannelModelConfig:
    models: List[str] = field(default_factory=lambda: ["VehA", "SUI5"])
    carrier_frequency: float = 2.1e9
    ue_speed_kmh: float = 50.0

@dataclass
class DatasetConfig:
    train_samples: int = 32000
    val_samples: int = 4000
    test_samples: int = 4000
    training_snrs_db: List[float] = field(default_factory=lambda: [12.0, 22.0])
    eval_snrs_db: List[float] = field(default_factory=lambda: [0.0, 5.0, 10.0, 12.0, 15.0, 20.0, 22.0, 25.0])
    seed: int = 42

@dataclass
class TrainingConfig:
    batch_size: int = 128
    learning_rate: float = 0.001
    max_epochs: int = 50
    optimizer: str = "adam"
    sr_loss: str = "mse"
    dncnn_loss: str = "mse"

class GlobalConfig:
    def __init__(self, config_yaml_path: str = None):
        if config_yaml_path and os.path.exists(config_yaml_path):
            with open(config_yaml_path, "r") as f:
                raw_cfg = yaml.safe_load(f)
            self.ofdm = OFDMConfig(**raw_cfg.get("ofdm", {}))
            self.pilots = PilotConfig(**raw_cfg.get("pilots", {}))
            self.dataset = DatasetConfig(**raw_cfg.get("dataset", {}))
            self.training = TrainingConfig(**raw_cfg.get("training", {}))
        else:
            self.ofdm = OFDMConfig()
            self.pilots = PilotConfig()
            self.dataset = DatasetConfig()
            self.training = TrainingConfig()

    @property
    def grid_shape(self) -> Tuple[int, int]:
        return (self.ofdm.num_subcarriers, self.ofdm.num_symbols)

# Default configuration instance
default_config = GlobalConfig()

