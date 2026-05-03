"""
generate_training_data.py

Generates an initial synthetic training dataset for the accident detection
model. The generated feature shape matches the Flutter inference path:

  5 sensor samples x 6 floats each = 30 floats
  1 location context slice x 8 floats = 8 floats
  Total = 38 floats

Output:
  training_data_initial.csv

Columns:
  f0 ... f37, label

Labels:
  0 = normal
  1 = near_miss
  2 = accident
"""

from __future__ import annotations

import pandas as pd
import numpy as np
from numpy.random import default_rng

rng = default_rng(42)
N = 10_000
WINDOW = 5
SENSOR_FEATURES = 6
LOCATION_FEATURES = 8


def _normal_sensor_sample() -> list[float]:
    """One normalized sensor sample following VehicleParameters.toFeatureVector."""
    return [
        float(rng.normal(0.0, 0.12)),          # accel_x / 10
        float(rng.normal(0.0, 0.10)),          # accel_y / 10
        float(rng.normal(0.98, 0.04)),         # accel_z / 10
        float(rng.uniform(0.10, 0.45)),        # speed / 200
        float(rng.uniform(0.00, 0.10)),        # impact / 10
        float(rng.uniform(0.0, 1.0)),          # orientation / 360
    ]


def _location_features(label: int) -> list[float]:
    """One normalized location slice following LocationContext.toFeatureSlice."""
    if label == 2:
        is_hotspot = 1.0 if rng.random() < 0.65 else 0.0
        hotspot_severity = float(rng.uniform(0.55, 1.0))
        weather = float(rng.choice([1, 2, 3], p=[0.50, 0.20, 0.30]))
    elif label == 1:
        is_hotspot = 1.0 if rng.random() < 0.35 else 0.0
        hotspot_severity = float(rng.uniform(0.20, 0.75))
        weather = float(rng.choice([0, 1, 2, 3], p=[0.45, 0.30, 0.15, 0.10]))
    else:
        is_hotspot = 1.0 if rng.random() < 0.15 else 0.0
        hotspot_severity = float(rng.uniform(0.0, 0.35))
        weather = float(rng.choice([0, 1, 2], p=[0.70, 0.20, 0.10]))

    road_type = float(rng.integers(0, 5))
    speed_limit_norm = float(rng.choice([30.0, 40.0, 50.0, 100.0]) / 120.0)
    time_of_day = float(rng.integers(0, 4))
    day_of_week = float(rng.integers(0, 7))
    grid_cell_norm = float(rng.uniform(0.0, 1.0))

    return [
        is_hotspot,
        hotspot_severity,
        road_type,
        speed_limit_norm,
        time_of_day,
        day_of_week,
        weather,
        grid_cell_norm,
    ]


def _build_window(label: int) -> list[float]:
    """
    Build one 38-float training sample:
    30 sensor floats (5 x 6) + 8 location floats.
    """
    window = [_normal_sensor_sample() for _ in range(WINDOW)]

    if label == 1:
        event_step = int(rng.integers(3, 5))
        step = window[event_step]
        step[0] += float(rng.choice([-1.0, 1.0]) * rng.uniform(0.30, 0.65))
        step[1] += float(rng.choice([-1.0, 1.0]) * rng.uniform(0.15, 0.40))
        step[2] = float(rng.uniform(0.70, 1.15))
        step[3] = float(rng.uniform(0.35, 0.70))
        step[4] = float(rng.uniform(0.15, 0.35))

        if event_step > 0:
            prev = window[event_step - 1]
            prev[0] += step[0] * 0.45
            prev[1] += step[1] * 0.35
            prev[4] = max(prev[4], step[4] * 0.55)

    elif label == 2:
        event_step = int(rng.integers(3, 5))
        step = window[event_step]
        dominant_axis = int(rng.integers(0, 3))
        spike = float(rng.uniform(0.65, 1.30))

        if dominant_axis == 0:
            step[0] += float(rng.choice([-1.0, 1.0]) * spike)
        elif dominant_axis == 1:
            step[1] += float(rng.choice([-1.0, 1.0]) * spike)
        else:
            step[2] = float(rng.choice([-1.0, 1.0]) * rng.uniform(0.65, 1.25))

        step[3] = float(rng.uniform(0.30, 0.85))
        step[4] = float(rng.uniform(0.35, 1.00))
        step[5] = float(rng.uniform(0.0, 1.0))

        if event_step > 0:
            prev = window[event_step - 1]
            prev[0] += step[0] * 0.55
            prev[1] += step[1] * 0.55
            prev[2] = prev[2] * 0.6 + step[2] * 0.4
            prev[4] = max(prev[4], step[4] * 0.65)

    sensor = np.array(window, dtype=np.float32).reshape(WINDOW * SENSOR_FEATURES)
    sensor += rng.normal(0.0, 0.01, sensor.shape[0]).astype(np.float32)
    sensor = np.clip(sensor, -1.5, 1.5)

    location = np.array(_location_features(label), dtype=np.float32)
    features = np.concatenate([sensor, location], axis=0)
    return features.tolist()


splits = {0: 6500, 1: 2000, 2: 1500}
rows: list[dict[str, float | int]] = []

for label, count in splits.items():
    for _ in range(count):
        features = _build_window(label)
        row = {f"f{i}": value for i, value in enumerate(features)}
        row["label"] = label
        rows.append(row)

df = pd.DataFrame(rows).sample(frac=1.0, random_state=42).reset_index(drop=True)
df.to_csv("training_data_initial.csv", index=False)

print(f"Saved {len(df)} samples to training_data_initial.csv")
print(df["label"].value_counts().sort_index())
