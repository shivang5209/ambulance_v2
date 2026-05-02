"""
generate_training_data.py
─────────────────────────
Generates an initial synthetic training dataset (10,000 samples) for the
accident detection model. Run this in Google Colab before initial_training.py.

Output: training_data_initial.csv
Columns: accel_x, accel_y, accel_z, speed_norm, impact, orientation_norm,
          is_hotspot, hotspot_severity, road_type, speed_limit_norm,
          time_of_day, day_of_week, weather, grid_cell_norm, label

Labels:  0=normal, 1=near_miss, 2=accident
"""

import numpy as np
import pandas as pd
from numpy.random import default_rng

rng = default_rng(42)
N = 10_000

# ── Sensor features (normalised, matching VehicleParameters.toFeatureVector) ──

def generate_normal(n):
    """Normal driving: low G, moderate speed, small impact."""
    return {
        "accel_x":          rng.normal(0.0, 0.15, n),
        "accel_y":          rng.normal(0.0, 0.10, n),
        "accel_z":          rng.normal(0.98, 0.05, n) / 10.0,  # gravity ~0.098
        "speed_norm":       rng.uniform(0.1, 0.6, n),
        "impact":           rng.uniform(0.0, 0.15, n),
        "orientation_norm": rng.uniform(0.0, 1.0, n),
    }

def generate_near_miss(n):
    """Hard braking / sudden swerve — high accel but no crash."""
    return {
        "accel_x":          rng.uniform(-0.5, 0.5, n) + rng.choice([-1, 1], n) * rng.uniform(0.3, 0.6, n),
        "accel_y":          rng.uniform(-0.4, 0.4, n),
        "accel_z":          rng.normal(0.1, 0.08, n),
        "speed_norm":       rng.uniform(0.3, 0.8, n),
        "impact":           rng.uniform(0.15, 0.35, n),
        "orientation_norm": rng.uniform(0.0, 1.0, n),
    }

def generate_accident(n):
    """High-G impact event — large acceleration spike + high impact force."""
    return {
        "accel_x":          rng.uniform(-1.0, 1.0, n) + rng.choice([-1, 1], n) * rng.uniform(0.4, 1.0, n),
        "accel_y":          rng.uniform(-0.8, 0.8, n),
        "accel_z":          rng.uniform(-0.8, 0.8, n),
        "speed_norm":       rng.uniform(0.2, 0.9, n),
        "impact":           rng.uniform(0.35, 1.0, n),
        "orientation_norm": rng.uniform(0.0, 1.0, n),
    }

# ── Location context features ──────────────────────────────────────────────────

def generate_location_features(n):
    return {
        "is_hotspot":         rng.choice([0.0, 1.0], n, p=[0.8, 0.2]),
        "hotspot_severity":   rng.uniform(0.0, 1.0, n),
        "road_type":          rng.integers(0, 5, n).astype(float),
        "speed_limit_norm":   rng.choice([0.25, 0.33, 0.42, 0.83], n),  # 30/40/50/100 km/h ÷ 120
        "time_of_day":        rng.integers(0, 4, n).astype(float),
        "day_of_week":        rng.integers(0, 7, n).astype(float),
        "weather":            rng.integers(0, 4, n).astype(float),
        "grid_cell_norm":     rng.uniform(0.0, 1.0, n),
    }

# ── Assemble dataset ───────────────────────────────────────────────────────────

splits = {0: 6500, 1: 2000, 2: 1500}  # class distribution
rows = []

for label, count in splits.items():
    if label == 0:   sensor = generate_normal(count)
    elif label == 1: sensor = generate_near_miss(count)
    else:            sensor = generate_accident(count)

    loc = generate_location_features(count)

    # Add noise
    for k in sensor:
        sensor[k] += rng.normal(0, 0.01, count)

    chunk = pd.DataFrame({**sensor, **loc})
    chunk["label"] = label
    rows.append(chunk)

df = pd.concat(rows, ignore_index=True).sample(frac=1, random_state=42)

# Clip normalised features to valid ranges
for col in ["accel_x", "accel_y", "accel_z", "speed_norm", "impact", "orientation_norm"]:
    df[col] = df[col].clip(-1.5, 1.5)

df.to_csv("training_data_initial.csv", index=False)
print(f"✅ Saved {len(df)} samples to training_data_initial.csv")
print(df["label"].value_counts())
