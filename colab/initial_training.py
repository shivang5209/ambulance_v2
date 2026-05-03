"""
initial_training.py

Trains the first accident detection model from scratch.
Run in Google Colab after generate_training_data.py.

This trainer intentionally learns on the same already-normalized 38-float
vector that the Flutter app sends to TFLite at inference time.

Steps:
  1. Load training_data_initial.csv
  2. Build Dense(64) -> Dropout(0.2) -> Dense(32) -> Dense(3, softmax)
  3. Train with early stopping
  4. Prune to 50 percent sparsity
  5. Quantize to INT8
  6. Export accident_detector_v1.tflite
  7. Save a Keras checkpoint for future retraining
"""

import tensorflow as tf

print("TF version:", tf.__version__)
print("GPUs:", tf.config.list_physical_devices("GPU"))

import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from tensorflow import keras
from tensorflow.keras import layers

df = pd.read_csv("training_data_initial.csv")
feature_columns = [col for col in df.columns if col.startswith("f")]
feature_columns = sorted(feature_columns, key=lambda name: int(name[1:]))

X = df[feature_columns].values.astype(np.float32)
y = df["label"].values.astype(np.int32)

X_train, X_val, y_train, y_val = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

INPUT_DIM = X_train.shape[1]
EXPECTED_DIM = 38
if INPUT_DIM != EXPECTED_DIM:
    raise ValueError(f"Expected {EXPECTED_DIM} features, found {INPUT_DIM}")

print(f"Train: {X_train.shape}, Val: {X_val.shape}")
print(f"Input size: {INPUT_DIM}")


def build_model(input_dim: int) -> keras.Model:
    inp = keras.Input(shape=(input_dim,), name="sensor_window_with_context")
    x = layers.Dense(64, activation="relu")(inp)
    x = layers.Dropout(0.2)(x)
    x = layers.Dense(32, activation="relu")(x)
    out = layers.Dense(3, activation="softmax", name="class_probs")(x)
    model = keras.Model(inp, out)
    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


model = build_model(INPUT_DIM)
model.summary()

history = model.fit(
    X_train,
    y_train,
    validation_data=(X_val, y_val),
    epochs=50,
    batch_size=32,
    callbacks=[
        keras.callbacks.EarlyStopping(patience=8, restore_best_weights=True),
        keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=4),
    ],
    verbose=1,
)

val_acc = max(history.history["val_accuracy"])
print(f"\nBest val accuracy: {val_acc:.4f}")

import tensorflow_model_optimization as tfmot

prune_low_magnitude = tfmot.sparsity.keras.prune_low_magnitude
pruning_params = {
    "pruning_schedule": tfmot.sparsity.keras.PolynomialDecay(
        initial_sparsity=0.0,
        final_sparsity=0.50,
        begin_step=0,
        end_step=max(1, (len(X_train) // 32) * 5),
    )
}

pruned_model = prune_low_magnitude(model, **pruning_params)
pruned_model.compile(
    optimizer=keras.optimizers.Adam(1e-4),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)

pruned_model.fit(
    X_train,
    y_train,
    validation_data=(X_val, y_val),
    epochs=5,
    batch_size=32,
    callbacks=[tfmot.sparsity.keras.UpdatePruningStep()],
    verbose=1,
)

stripped_model = tfmot.sparsity.keras.strip_pruning(pruned_model)
print("Pruning complete")


def representative_dataset():
    for i in range(min(500, len(X_val))):
        yield [X_val[i : i + 1].astype(np.float32)]


converter = tf.lite.TFLiteConverter.from_keras_model(stripped_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.representative_dataset = representative_dataset
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type = tf.int8
converter.inference_output_type = tf.int8

tflite_model = converter.convert()

MODEL_FILENAME = "accident_detector_v1.tflite"
with open(MODEL_FILENAME, "wb") as f:
    f.write(tflite_model)

KERAS_FILENAME = "accident_detector_keras.keras"
stripped_model.save(KERAS_FILENAME)

size_kb = len(tflite_model) / 1024
print(f"Saved {MODEL_FILENAME} ({size_kb:.1f} KB)")
print(f"Saved {KERAS_FILENAME}")
print("Model file is ready:", MODEL_FILENAME)
