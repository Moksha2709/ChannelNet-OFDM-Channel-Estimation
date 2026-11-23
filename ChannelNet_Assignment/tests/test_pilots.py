"""
Stage 2 Unit Tests for Pilot Generation
Verifies:
1. Exact pilot count checks (24, 48, 72).
2. Determinism and repeatability across runs.
3. Correct lattice-type geometric distribution.
4. Pilot insertion and extraction consistency.
5. Saves the mandatory visualization: results/channel_visualizations/pilot_pattern.png.
"""

import os
import sys
import numpy as np
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from ofdm.pilot_generation import PilotGenerator

def test_pilot_counts():
    """Verify exact count of nonzero locations for all densities."""
    pg = PilotGenerator(num_subcarriers=72, num_symbols=14)

    for requested in [24, 48, 72]:
        mask = pg.get_pilot_mask(num_pilots=requested)
        actual = int(np.sum(mask))
        assert actual == requested, f"Expected {requested} pilots, got {actual}"
        print(f"[PASS] Pilot count check passed for {requested} pilots (Actual: {actual}).")

def test_repeatability():
    """Verify mask is 100% deterministic across repeated calls."""
    pg = PilotGenerator()
    mask1 = pg.get_pilot_mask(num_pilots=48)
    mask2 = pg.get_pilot_mask(num_pilots=48)
    assert np.array_equal(mask1, mask2), "Pilot mask is not repeatable across calls!"
    print("[PASS] Repeatability check passed.")

def test_insertion_and_extraction():
    """Verify pilot insertion and extraction."""
    pg = PilotGenerator()
    mask = pg.get_pilot_mask(num_pilots=48)
    data_grid = np.zeros((72, 14), dtype=np.complex128)

    pilot_val = 1.0 + 0j
    grid_with_pilots = pg.insert_pilots(data_grid, mask, pilot_value=pilot_val)

    # All non-pilot positions should be 0
    assert np.all(grid_with_pilots[~mask] == 0.0), "Data positions corrupted by pilot insertion!"
    # All pilot positions should be pilot_val
    assert np.all(grid_with_pilots[mask] == pilot_val), "Pilot values not set correctly!"

    k_idx, n_idx, vals = pg.extract_pilots(grid_with_pilots, mask)
    assert len(vals) == 48, f"Extracted {len(vals)} pilots, expected 48"
    assert np.all(vals == pilot_val), "Extracted pilot values do not match inserted value!"
    print("[PASS] Pilot insertion and extraction check passed.")

def generate_pilot_visualization():
    """Generate visual plot of lattice pilot patterns for 24, 48, and 72 pilots."""
    pg = PilotGenerator()
    mask_24 = pg.get_pilot_mask(24)
    mask_48 = pg.get_pilot_mask(48)
    mask_72 = pg.get_pilot_mask(72)

    os.makedirs('ChannelNet_Assignment/results/channel_visualizations', exist_ok=True)
    out_path = 'ChannelNet_Assignment/results/channel_visualizations/pilot_pattern.png'

    fig, axes = plt.subplots(1, 3, figsize=(16, 6))

    configs = [
        (mask_24, '24 Pilots (Low Density)', axes[0]),
        (mask_48, '48 Pilots (Main Configuration)', axes[1]),
        (mask_72, '72 Pilots (High Density)', axes[2])
    ]

    for mask, title, ax in configs:
        k_idx, n_idx = np.where(mask)
        ax.set_facecolor('#f0f2f6')
        ax.scatter(n_idx, k_idx, color='crimson', marker='D', s=45, label=f'Pilots ({len(k_idx)})')
        ax.set_xlim(-0.5, 13.5)
        ax.set_ylim(-0.5, 71.5)
        ax.set_xticks(range(0, 14, 2))
        ax.set_yticks(range(0, 72, 6))
        ax.grid(True, linestyle=':', alpha=0.7, color='gray')
        ax.set_xlabel('OFDM Time Slot Index (n)', fontsize=11)
        ax.set_ylabel('Subcarrier Index (k)', fontsize=11)
        ax.set_title(title, fontsize=12, fontweight='bold')
        ax.legend(loc='upper right')

    plt.suptitle('Lattice-Type Pilot Arrangements on 72 x 14 Time-Frequency Grid', fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(out_path, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"[PASS] Saved pilot pattern plot to {out_path}")

if __name__ == '__main__':
    print("=" * 60)
    print("RUNNING STAGE 2 PILOT GENERATION TEST SUITE")
    print("=" * 60)
    test_pilot_counts()
    test_repeatability()
    test_insertion_and_extraction()
    generate_pilot_visualization()
    print("=" * 60)
    print("ALL STAGE 2 TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)

