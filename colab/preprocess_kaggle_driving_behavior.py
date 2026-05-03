"""
preprocess_kaggle_driving_behavior.py

Convert a driving-behavior CSV (for example the Kaggle "Driving Behavior"
dataset) into the same 38-feature window format used by the Flutter app:

  5 samples x 6 sensor features = 30 floats
  1 location-context slice x 8 floats = 8 floats
  Total = 38 floats

Output:
  driving_behavior_38f.csv

Columns:
  f0 ... f37, label

Target labels:
  0 = normal
  1 = near_miss
  2 = accident_proxy

Important:
This dataset usually does not include real crash labels or GPS context.
So this script:
  - uses neutral/default location features for the final 8 floats
  - maps AGGRESSIVE windows into near_miss / accident_proxy using a
    severity heuristic based on acceleration + gyro intensity
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable

import numpy as np
import pandas as pd

WINDOW = 5
LOCATION_DEFAULTS = [
    0.0,        # is_hotspot
    0.0,        # hotspotSeverityAvg
    4.0,        # roadTypeEncoded = other
    50.0 / 120.0,  # speedLimit / 120
    1.0,        # timeOfDayEncoded = afternoon
    0.0,        # dayOfWeekEncoded = Monday
    0.0,        # weatherEncoded = clear
    0.0,        # gridCell norm
]


def _find_column(columns: Iterable[str], aliases: list[str]) -> str | None:
    lowered = {c.lower(): c for c in columns}
    for alias in aliases:
        if alias.lower() in lowered:
            return lowered[alias.lower()]
    return None


def _resolve_columns(df: pd.DataFrame) -> dict[str, str]:
    cols = list(df.columns)
    mapping = {
        "acc_x": _find_column(cols, ["accx", "acc_x", "x", "acceleration_x"]),
        "acc_y": _find_column(cols, ["accy", "acc_y", "y", "acceleration_y"]),
        "acc_z": _find_column(cols, ["accz", "acc_z", "z", "acceleration_z"]),
        "gyro_x": _find_column(cols, ["gyrox", "gyro_x", "rotationx", "rot_x"]),
        "gyro_y": _find_column(cols, ["gyroy", "gyro_y", "rotationy", "rot_y"]),
        "gyro_z": _find_column(cols, ["gyroz", "gyro_z", "rotationz", "rot_z"]),
        "label": _find_column(
            cols,
            ["class", "label", "classification", "behavior", "driving_style"],
        ),
        "timestamp": _find_column(cols, ["timestamp", "time", "seconds"]),
    }

    required = ["acc_x", "acc_y", "acc_z", "label"]
    missing = [name for name in required if mapping[name] is None]
    if missing:
        raise ValueError(
            f"Missing required columns: {missing}. Found columns: {list(df.columns)}"
        )

    return {k: v for k, v in mapping.items() if v is not None}


def _normalize_label(raw: str) -> str:
    value = str(raw).strip().lower()
    if value in {"slow", "normal", "safe"}:
        return "normal"
    if value in {"aggressive", "rash", "dangerous"}:
        return "aggressive"
    return value


def _prepare_frame(df: pd.DataFrame) -> pd.DataFrame:
    mapping = _resolve_columns(df)
    out = pd.DataFrame()

    out["acc_x_raw"] = pd.to_numeric(df[mapping["acc_x"]], errors="coerce")
    out["acc_y_raw"] = pd.to_numeric(df[mapping["acc_y"]], errors="coerce")
    out["acc_z_raw"] = pd.to_numeric(df[mapping["acc_z"]], errors="coerce")

    if "gyro_x" in mapping:
        out["gyro_x_raw"] = pd.to_numeric(df[mapping["gyro_x"]], errors="coerce")
    else:
        out["gyro_x_raw"] = 0.0
    if "gyro_y" in mapping:
        out["gyro_y_raw"] = pd.to_numeric(df[mapping["gyro_y"]], errors="coerce")
    else:
        out["gyro_y_raw"] = 0.0
    if "gyro_z" in mapping:
        out["gyro_z_raw"] = pd.to_numeric(df[mapping["gyro_z"]], errors="coerce")
    else:
        out["gyro_z_raw"] = 0.0

    out["label_raw"] = df[mapping["label"]].map(_normalize_label)

    if "timestamp" in mapping:
        out["timestamp"] = pd.to_numeric(df[mapping["timestamp"]], errors="coerce")
        out = out.sort_values("timestamp")

    out = out.dropna().reset_index(drop=True)

    # Match the app's 6 per-sample features:
    # [accelX, accelY, accelZ, speed_norm, impactForce, orientation_norm]
    out["f_acc_x"] = (out["acc_x_raw"] / 10.0).clip(-1.5, 1.5)
    out["f_acc_y"] = (out["acc_y_raw"] / 10.0).clip(-1.5, 1.5)
    out["f_acc_z"] = (out["acc_z_raw"] / 10.0).clip(-1.5, 1.5)

    accel_mag = np.sqrt(
        out["acc_x_raw"] ** 2 + out["acc_y_raw"] ** 2 + out["acc_z_raw"] ** 2
    )
    gyro_mag = np.sqrt(
        out["gyro_x_raw"] ** 2 + out["gyro_y_raw"] ** 2 + out["gyro_z_raw"] ** 2
    )

    # Kaggle behavior datasets often lack actual speed. This creates a proxy.
    speed_proxy = (
        out["label_raw"].map({"normal": 0.35, "aggressive": 0.65}).fillna(0.40)
        + (gyro_mag / max(gyro_mag.max(), 1.0)) * 0.15
    )
    out["f_speed"] = speed_proxy.clip(0.0, 1.0)

    # Impact proxy from acceleration spikes.
    impact_proxy = ((accel_mag - 9.8).abs() / 10.0).clip(0.0, 1.0)
    out["f_impact"] = impact_proxy

    # Orientation proxy from XY direction.
    orientation = np.arctan2(out["acc_y_raw"], out["acc_x_raw"])
    out["f_orientation"] = ((orientation + np.pi) / (2 * np.pi)).clip(0.0, 1.0)

    out["severity_score"] = (
        impact_proxy * 0.55 + (gyro_mag / max(gyro_mag.max(), 1.0)) * 0.45
    ).clip(0.0, 1.0)

    return out


def _window_to_features(window: pd.DataFrame) -> list[float]:
    sensor_values = window[
        [
            "f_acc_x",
            "f_acc_y",
            "f_acc_z",
            "f_speed",
            "f_impact",
            "f_orientation",
        ]
    ].to_numpy(dtype=np.float32)
    flat = sensor_values.reshape(-1).tolist()
    return flat + LOCATION_DEFAULTS


def _window_to_label(window: pd.DataFrame, aggressive_threshold: float) -> int:
    last_label = window["label_raw"].iloc[-1]
    max_severity = float(window["severity_score"].max())

    if last_label == "normal":
        return 0

    if last_label == "aggressive":
        return 2 if max_severity >= aggressive_threshold else 1

    # Unknown labels fall back to severity-based grouping.
    return 2 if max_severity >= aggressive_threshold else 1


def build_dataset(input_csv: Path, output_csv: Path) -> None:
    raw_df = pd.read_csv(input_csv)
    df = _prepare_frame(raw_df)

    if len(df) < WINDOW:
        raise ValueError(f"Need at least {WINDOW} rows, found {len(df)}")

    aggressive_rows = df.loc[df["label_raw"] == "aggressive", "severity_score"]
    if len(aggressive_rows) > 0:
        aggressive_threshold = float(np.quantile(aggressive_rows, 0.80))
    else:
        aggressive_threshold = 0.65

    rows: list[dict[str, float | int]] = []
    for start in range(0, len(df) - WINDOW + 1):
        window = df.iloc[start : start + WINDOW]
        features = _window_to_features(window)
        label = _window_to_label(window, aggressive_threshold)
        row = {f"f{i}": value for i, value in enumerate(features)}
        row["label"] = label
        rows.append(row)

    out_df = pd.DataFrame(rows)
    out_df.to_csv(output_csv, index=False)

    print(f"Saved {len(out_df)} windows to {output_csv}")
    print(out_df["label"].value_counts().sort_index())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        required=True,
        help="Path to the Kaggle CSV file, for example train_motion_data.csv",
    )
    parser.add_argument(
        "--output",
        default="driving_behavior_38f.csv",
        help="Output CSV path",
    )
    args = parser.parse_args()

    build_dataset(Path(args.input), Path(args.output))


if __name__ == "__main__":
    main()
